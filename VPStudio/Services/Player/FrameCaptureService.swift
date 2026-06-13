import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Captures and stores the "last frame" thumbnails shown on Continue Watching tiles.
///
/// Every capture is best-effort: callers MUST have a fallback (e.g. the TMDB backdrop)
/// because the caches directory can be evicted by the OS, some streams can't be decoded
/// to a still, and stereo/3D frames are intentionally skipped (a raw side-by-side frame
/// would look squished as a thumbnail).
///
/// Frames are encoded to JPEG `Data` at the capture site so that no non-`Sendable`
/// `CGImage` ever crosses a concurrency boundary.
enum FrameCaptureService {
    private static let subdirectory = "VPStudio/frames"
    private static let maxPixelWidth = 960
    private static let jpegQuality = 0.7

    // MARK: - Paths

    static func framesDirectory() -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = caches.appendingPathComponent(subdirectory, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func fileName(mediaId: String, episodeId: String?) -> String {
        let base = episodeId.map { "\(mediaId)-\($0)" } ?? mediaId
        let allowed = CharacterSet.alphanumerics
        let sanitized = String(String.UnicodeScalarView(base.unicodeScalars.map { scalar in
            allowed.contains(scalar) || scalar == "-" || scalar == "_" ? scalar : "_"
        }))
        return sanitized + ".jpg"
    }

    static func fileURL(mediaId: String, episodeId: String?) -> URL? {
        framesDirectory()?.appendingPathComponent(fileName(mediaId: mediaId, episodeId: episodeId))
    }

    // MARK: - Capture

    /// Generates a still (as JPEG data) from a raw `AVPlayer`'s asset at the given time.
    /// Uses `AVAssetImageGenerator`, which works for the standard `AVPlayer` engine.
    /// Encoding happens inside the completion handler so only `Data` crosses back.
    static func captureAVPlayerFrameJPEG(asset: AVAsset, at time: CMTime) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: maxPixelWidth, height: maxPixelWidth)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
                continuation.resume(returning: image.flatMap(encodeJPEG))
            }
        }
    }

    /// Encodes a CGImage to downscaled JPEG `Data`. Safe to call from any isolation domain.
    static func encodeJPEG(_ image: CGImage) -> Data? {
        let scaled = downscaled(image) ?? image
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, scaled, [
            kCGImageDestinationLossyCompressionQuality: jpegQuality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - Storage

    /// Writes JPEG data to disk keyed by media/episode. Returns the file path on success.
    @discardableResult
    static func store(jpegData: Data, mediaId: String, episodeId: String?) -> String? {
        guard let url = fileURL(mediaId: mediaId, episodeId: episodeId) else { return nil }
        do {
            try jpegData.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }

    static func removeFrame(mediaId: String, episodeId: String?) {
        guard let url = fileURL(mediaId: mediaId, episodeId: episodeId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Helpers

    private static func downscaled(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > maxPixelWidth, width > 0, height > 0 else { return nil }
        let scale = Double(maxPixelWidth) / Double(width)
        let newWidth = Int(Double(width) * scale)
        let newHeight = Int(Double(height) * scale)
        guard newWidth > 0, newHeight > 0,
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }
}
