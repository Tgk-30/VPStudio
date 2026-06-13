import CoreGraphics
import Foundation
import ImageIO

/// Analyzes an equirectangular HDRI panorama to find the yaw offset that
/// brings the most prominent screen-like region (the cinema screen) to face
/// the viewer at 0°.
///
/// ## How it works
///
/// An equirectangular image maps the full sphere to a 2:1 rectangle:
/// - Horizontal axis → longitude (yaw).  x=0 → −180°, x=W/2 → 0°, x=W → +180°
/// - Vertical axis   → latitude (pitch). y=0 → +90° (top), y=H/2 → 0° (equator)
///
/// Cinema screens are large, very bright, rectangular features located above the
/// equator in the panorama.  The algorithm:
///   1. Decodes a small tone-mapped LDR thumbnail (512 px wide) — safe because
///      CGImageSource applies Reinhard-style tone mapping automatically when
///      `kCGImageSourceShouldAllowFloat` is false.
///   2. Accumulates luminance per column across the vertical band that
///      corresponds to ~+5° – +55° latitude (where screens appear in
///      cinema panoramas, not the ceiling or floor).
///   3. Applies a box-smoothing pass (wrapping at the panorama seam) to suppress
///      individual light fixtures and reflections in favour of the large bright
///      rectangle of the screen.
///   4. Finds the peak column, converts its x position to a yaw angle, and
///      returns the negated value so the skybox rotation brings the screen to 0°.
///
/// Because each HDRI is different, the detection is run once on import and the
/// result is persisted in `EnvironmentAsset.hdriYawOffset`.
struct HDRIOrientationAnalyzer {

    // MARK: - Public API

    /// Detects the yaw offset (degrees) needed to front-face the main bright
    /// region of the HDRI.  Runs the heavy image decode off the main actor.
    /// Returns `nil` if the image cannot be read or analysed.
    static func detectScreenYaw(at url: URL) async -> Float? {
        await Task.detached(priority: .userInitiated) {
            analyzeSync(url: url)
        }.value
    }

    // MARK: - Core analysis (nonisolated, safe to run on any thread)

    nonisolated private static func analyzeSync(url: URL) -> Float? {
        guard fileLooksDecodableByImageIO(url: url) else {
            return nil
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        guard imageSourceHasReadableImage(at: source, index: 0) else {
            return nil
        }

        // Request a small LDR thumbnail.  CGImageSource applies tone-mapping
        // when kCGImageSourceShouldAllowFloat is false, giving a sensible 8-bit
        // representation of the HDR values.
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldAllowFloat: false,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbOptions as CFDictionary
        ) else { return nil }

        return screenYaw(in: thumb)
    }

    nonisolated private static func fileLooksDecodableByImageIO(url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: url.path) else {
            return false
        }

        let fileSize = fileSize(at: url)
        guard fileSize > 0,
              let header = readPrefix(at: url, count: 512),
              !header.isEmpty else {
            return false
        }

        if header.starts(with: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
            guard fileSize >= 12,
                  let trailer = readSuffix(at: url, count: 12),
                  trailer.count == 12 else {
                return false
            }
            let chunkType = trailer[
                trailer.index(trailer.startIndex, offsetBy: 4)..<trailer.index(trailer.startIndex, offsetBy: 8)
            ]
            return Data(chunkType) == Data("IEND".utf8)
        }

        if header.starts(with: Data([0xFF, 0xD8])) {
            guard let trailer = readSuffix(at: url, count: 2),
                  trailer.count == 2 else {
                return false
            }
            return trailer.starts(with: Data([0xFF, 0xD9]))
        }

        if header.starts(with: Data([0x76, 0x2F, 0x31, 0x01])) {
            return fileSize > 32
        }

        if let asciiHeader = String(data: header, encoding: .ascii),
           asciiHeader.hasPrefix("#?RADIANCE") || asciiHeader.hasPrefix("#?RGBE") {
            return asciiHeader.contains("FORMAT=")
        }

        return false
    }

    nonisolated private static func fileSize(at url: URL) -> UInt64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(max(values?.fileSize ?? 0, 0))
    }

    nonisolated private static func readPrefix(at url: URL, count: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: count) ?? Data()
    }

    nonisolated private static func readSuffix(at url: URL, count: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd() else { return nil }
        let offset = end > UInt64(count) ? end - UInt64(count) : 0
        do {
            try handle.seek(toOffset: offset)
            return try handle.read(upToCount: count) ?? Data()
        } catch {
            return nil
        }
    }

    nonisolated private static func imageSourceHasReadableImage(
        at source: CGImageSource,
        index: Int
    ) -> Bool {
        guard CGImageSourceGetCount(source) > index else { return false }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return false
        }

        let width = imageDimension(from: properties[kCGImagePropertyPixelWidth])
        let height = imageDimension(from: properties[kCGImagePropertyPixelHeight])
        return width > 0 && height > 0
    }

    nonisolated private static func imageDimension(from value: Any?) -> Int {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let intValue as Int:
            return intValue
        default:
            return 0
        }
    }

    // MARK: - Pixel analysis

    private static func screenYaw(in image: CGImage) -> Float? {
        let w = image.width
        let h = image.height
        guard w > 2, h > 2 else { return nil }

        // Render into an RGBA8 bitmap so we can read pixel values safely.
        let bytesPerRow = w * 4
        var pixels = [UInt8](repeating: 0, count: h * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))

        // Vertical analysis band.
        //
        // Equirectangular latitude formula: lat = (0.5 − y/H) × 180°
        //   +55° latitude → y ≈ H × (0.5 − 55/180) ≈ H × 0.194
        //   + 5° latitude → y ≈ H × (0.5 − 5/180)  ≈ H × 0.472
        //
        // This band covers the portion of the sphere where the cinema screen
        // faces you — well above the floor and below the ceiling.
        let topY    = Int(Double(h) * 0.19)
        let bottomY = Int(Double(h) * 0.50)

        // Accumulate luminance per column inside the band.
        var columnLuminance = [Float](repeating: 0, count: w)
        for y in topY ..< bottomY {
            let rowBase = y * bytesPerRow
            for x in 0 ..< w {
                let p = rowBase + x * 4
                let r = Float(pixels[p])
                let g = Float(pixels[p + 1])
                let b = Float(pixels[p + 2])
                // ITU-R BT.709 luminance
                columnLuminance[x] += 0.2126 * r + 0.7152 * g + 0.0722 * b
            }
        }

        // Box-smooth with a seam-aware filter to suppress point lights and reflections
        // while preserving the broad bright rectangle of the screen.
        // Window ≈ 1/10 of image width.
        let smoothed = boxSmooth(columnLuminance, halfWidth: max(1, w / 10))
        let peakColumn = dominantColumn(from: smoothed, rawColumns: columnLuminance)

        let screenYawDeg: Float
        switch peakColumn {
        case .front:
            screenYawDeg = 0
        case .back:
            screenYawDeg = -180
        case .value(let peakCol):
            // Convert peak column → longitude (yaw angle of the screen centre).
            // x=0 → −180°, x=W/2 → 0°, x=W−1 → +180°
            screenYawDeg = (Float(peakCol) / Float(w - 1) - 0.5) * 360.0
        }

        // Convert peak column → longitude (yaw angle of the screen centre).
        // Negate: the skybox `hdriYawOffset` rotates the sphere, so we need to
        // rotate by the opposite angle to bring the screen to face the user at 0°.
        return -screenYawDeg
    }

    private enum PeakColumn {
        case front
        case back
        case value(Int)
    }

    // MARK: - Peak and smoothing helpers

    private static func dominantColumn(
        from smoothed: [Float],
        rawColumns: [Float]
    ) -> PeakColumn {
        guard !smoothed.isEmpty else { return .value(0) }
        let n = smoothed.count

        guard let maxValue = smoothed.max(), maxValue > 0 else {
            return .value(0)
        }

        let indices = smoothed.indices.filter { smoothed[$0] == maxValue }
        let edgeBand = max(1, n / 20)
        if let first = indices.first,
           let last = indices.last,
           (first == 0 || last == n - 1),
           let rawPeak = rawColumns.indices.max(
            by: { lhs, rhs in
                let lhsValue = rawColumns[lhs]
                let rhsValue = rawColumns[rhs]
                if lhsValue == rhsValue {
                    return lhs < rhs
                }
                return lhsValue < rhsValue
            }
           ) {
            if rawPeak < edgeBand {
                return .front
            }
            if rawPeak >= n - edgeBand {
                return .back
            }
        }

        let baseline = smoothed.min() ?? 0
        var vectorX = 0.0
        var vectorY = 0.0
        var totalWeight = 0.0
        let fullTurn = Double.pi * 2

        for (index, value) in smoothed.enumerated() {
            let weight = max(0.0, Double(value - baseline))
            guard weight > 0 else { continue }

            let angle = Double(index) / Double(n) * fullTurn
            vectorX += cos(angle) * weight
            vectorY += sin(angle) * weight
            totalWeight += weight
        }

        if totalWeight > 0 {
            let magnitude = hypot(vectorX, vectorY)
            if magnitude > 0.0001 {
                var angle = atan2(vectorY, vectorX)
                if angle < 0 { angle += fullTurn }
                let normalized = angle / fullTurn
                let peakIndex = Int((normalized * Double(n)).rounded(.toNearestOrAwayFromZero)) % n
                return .value(peakIndex)
            }
        }

        guard let first = indices.first, let last = indices.last else { return .value(0) }

        if first == 0 && last == n - 1,
           let rawPeak = rawColumns.indices.max(
            by: { lhs, rhs in
                let lhsValue = rawColumns[lhs]
                let rhsValue = rawColumns[rhs]
                if lhsValue == rhsValue {
                    return lhs < rhs
                }
                return lhsValue < rhsValue
            }
        ) {
            return rawPeak < n / 2 ? .front : .back
        }

        if indices.count == 1 { return .value(first) }
        return .value(indices[indices.count / 2])
    }

    // MARK: - Box smooth (panorama-edge aware)

    /// Edge-aware box filter that keeps a fixed kernel width while preventing
    /// seam artifacts from a circular wrap for narrow windows.
    private static func boxSmooth(_ values: [Float], halfWidth h: Int) -> [Float] {
        let n = values.count
        guard n > 0, h > 0 else { return values }

        let windowCount = 2 * h + 1
        if windowCount >= n {
            let average = values.reduce(0, +) / Float(n)
            return [Float](repeating: average, count: n)
        }

        var out = [Float](repeating: 0, count: n)
        for i in 0 ..< n {
            let center = min(max(i, h), n - h - 1)
            var sum: Float = 0
            for index in (center - h)...(center + h) {
                sum += values[index]
            }
            out[i] = sum / Float(windowCount)
        }
        return out
    }
}
