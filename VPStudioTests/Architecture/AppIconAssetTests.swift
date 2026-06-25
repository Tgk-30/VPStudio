import Foundation
import ImageIO
import Testing
@testable import VPStudio

struct AppIconAssetTests {
    private static let iconLayerPaths: [String] = [
        "VPStudio/Assets.xcassets/AppIcon.solidimagestack/Front.solidimagestacklayer/Content.imageset/front.png",
        "VPStudio/Assets.xcassets/AppIcon.solidimagestack/Middle.solidimagestacklayer/Content.imageset/middle.png",
        "VPStudio/Assets.xcassets/AppIcon.solidimagestack/Back.solidimagestacklayer/Content.imageset/back.png",
    ]
    private static let roundedReferenceGenreTilePaths: [String] = {
        let names = [
            "action", "animation", "chill", "classics", "comedy", "deep", "docs",
            "drama", "fantasy", "horror", "mystery", "new",
            "scifi", "upcoming",
        ]
        return names.flatMap { name in
            [
                "VPStudio/Assets.xcassets/ReferenceGenreTiles/genre-ref-\(name).imageset/genre-ref-\(name).png",
                "VPStudio/Assets.xcassets/ReferenceGenreTiles/genre-ref-\(name).imageset/genre-ref-\(name)@2x.png",
                "VPStudio/Assets.xcassets/ReferenceGenreTiles/genre-ref-\(name).imageset/genre-ref-\(name)@3x.png",
            ]
        }
    }()
    private static let roundedReferenceGenreTilePrefixes: [String] = {
        let names = [
            "action", "animation", "chill", "classics", "comedy", "deep", "docs",
            "drama", "fantasy", "horror", "mystery", "new",
            "scifi", "upcoming",
        ]
        return names.map { name in
            "VPStudio/Assets.xcassets/ReferenceGenreTiles/genre-ref-\(name).imageset/genre-ref-\(name)"
        }
    }()
    private static let scaleCheckedRasterPrefixes: [String] = {
        let genreArtworkNames = [
            "action", "animation", "chill", "classics", "comedy", "deep", "docs",
            "drama", "fantasy", "horror", "mystery", "new", "scifi", "upcoming",
        ]
        let genreArtwork = genreArtworkNames.map { name in
            "VPStudio/Assets.xcassets/GenreArtwork/genre-art-\(name).imageset/genre-art-\(name)"
        }
        let referenceArtwork = genreArtworkNames.map { name in
            "VPStudio/Assets.xcassets/ReferenceGenreTiles/genre-ref-\(name).imageset/genre-ref-\(name)"
        }
        return genreArtwork + referenceArtwork
    }()
    private static let fullBleedGenreArtworkPaths: [String] = {
        let names = [
            "action", "animation", "chill", "classics", "comedy", "deep", "docs",
            "drama", "fantasy", "horror", "mystery", "new", "scifi", "upcoming",
        ]
        return names.flatMap { name in
            [
                "VPStudio/Assets.xcassets/GenreArtwork/genre-art-\(name).imageset/genre-art-\(name).png",
                "VPStudio/Assets.xcassets/GenreArtwork/genre-art-\(name).imageset/genre-art-\(name)@2x.png",
                "VPStudio/Assets.xcassets/GenreArtwork/genre-art-\(name).imageset/genre-art-\(name)@3x.png",
            ]
        }
    }()

    @Test(arguments: iconLayerPaths)
    func appIconLayersExistAndAreExpectedSize(relativePath: String) {
        let fileURL = repoRootURL().appendingPathComponent(relativePath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            Issue.record("Could not read image properties for \(relativePath)")
            return
        }

        #expect(width == 1024)
        #expect(height == 1024)
    }

    @Test
    func duplicateResourceAssetCatalogIsRemoved() {
        let duplicateCatalog = repoRootURL().appendingPathComponent("VPStudio/Resources/Assets.xcassets")
        #expect(FileManager.default.fileExists(atPath: duplicateCatalog.path) == false)
    }

    @Test
    func referenceGenreTileCatalogOnlyShipsLiveExploreCards() throws {
        let catalogURL = repoRootURL().appendingPathComponent("VPStudio/Assets.xcassets/ReferenceGenreTiles")
        let children = try FileManager.default.contentsOfDirectory(
            at: catalogURL,
            includingPropertiesForKeys: nil
        )
        let imagesetIDs = Set(children.compactMap { url -> String? in
            guard url.pathExtension == "imageset" else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("genre-ref-") else { return nil }
            return String(name.dropFirst("genre-ref-".count))
        })
        let liveIDs = Set(ExploreGenreCatalog.cards.map(\.id))

        #expect(imagesetIDs == liveIDs)
    }

    @Test(arguments: roundedReferenceGenreTilePrefixes)
    func referenceGenreTilesHaveExpectedRasterDimensions(basePath: String) {
        let rootURL = repoRootURL()
        let expectedDimensions: [(suffix: String, width: CGFloat, height: CGFloat)] = [
            ("", 128, 142),
            ("@2x", 256, 284),
            ("@3x", 384, 426),
        ]

        for expected in expectedDimensions {
            let fileURL = rootURL.appendingPathComponent("\(basePath)\(expected.suffix).png")
            guard let dimensions = imageDimensions(for: fileURL) else {
                Issue.record("Could not read image dimensions for \(basePath)\(expected.suffix).png")
                continue
            }

            #expect(dimensions.width == expected.width)
            #expect(dimensions.height == expected.height)
        }
    }

    @Test(arguments: scaleCheckedRasterPrefixes)
    func rasterImagesetsHaveConsistentScaleDimensions(basePath: String) {
        let rootURL = repoRootURL()
        let baseURL = rootURL.appendingPathComponent("\(basePath).png")
        guard let baseDimensions = imageDimensions(for: baseURL) else {
            Issue.record("Could not read base image dimensions for \(basePath).png")
            return
        }

        for scale in [2, 3] {
            let scaledURL = rootURL.appendingPathComponent("\(basePath)@\(scale)x.png")
            guard let scaledDimensions = imageDimensions(for: scaledURL) else {
                Issue.record("Could not read scaled image dimensions for \(basePath)@\(scale)x.png")
                continue
            }

            #expect(scaledDimensions.width == baseDimensions.width * CGFloat(scale))
            #expect(scaledDimensions.height == baseDimensions.height * CGFloat(scale))
        }
    }

    @Test(arguments: roundedReferenceGenreTilePaths)
    func roundedReferenceGenreTilesHaveTransparentCorners(relativePath: String) {
        let fileURL = repoRootURL().appendingPathComponent(relativePath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            Issue.record("Could not load reference genre tile \(relativePath)")
            return
        }

        let alphaInfo = image.alphaInfo
        #expect(alphaInfo != .none)
        #expect(alphaInfo != .noneSkipFirst)
        #expect(alphaInfo != .noneSkipLast)

        guard let topLeftAlpha = alphaValue(atX: 0, y: 0, in: image),
              let topRightAlpha = alphaValue(atX: image.width - 1, y: 0, in: image),
              let bottomLeftAlpha = alphaValue(atX: 0, y: image.height - 1, in: image),
              let bottomRightAlpha = alphaValue(atX: image.width - 1, y: image.height - 1, in: image) else {
            Issue.record("Could not inspect corner alpha for \(relativePath)")
            return
        }

        #expect(topLeftAlpha <= 4)
        #expect(topRightAlpha <= 4)
        #expect(bottomLeftAlpha <= 4)
        #expect(bottomRightAlpha <= 4)
    }

    @Test(arguments: roundedReferenceGenreTilePaths)
    func roundedReferenceGenreTilesKeepTransparentOuterEdge(relativePath: String) {
        let fileURL = repoRootURL().appendingPathComponent(relativePath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let maxAlpha = maxOuterEdgeAlpha(in: image) else {
            Issue.record("Could not inspect outer edge alpha for \(relativePath)")
            return
        }

        #expect(maxAlpha <= 4)
    }

    @Test(arguments: roundedReferenceGenreTilePrefixes)
    func roundedReferenceGenreTilesHaveConsistentVisibleBoundsAcrossScales(basePath: String) {
        let rootURL = repoRootURL()
        let suffixes = ["", "@2x", "@3x"]
        let normalizedBounds = suffixes.compactMap { suffix -> CGRect? in
            let fileURL = rootURL.appendingPathComponent("\(basePath)\(suffix).png")
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                Issue.record("Could not load reference genre tile \(basePath)\(suffix).png")
                return nil
            }
            guard let bounds = visibleAlphaBounds(in: image, threshold: 16) else {
                Issue.record("Could not inspect visible alpha bounds for \(basePath)\(suffix).png")
                return nil
            }
            return CGRect(
                x: bounds.minX / CGFloat(image.width),
                y: bounds.minY / CGFloat(image.height),
                width: bounds.width / CGFloat(image.width),
                height: bounds.height / CGFloat(image.height)
            )
        }

        #expect(normalizedBounds.count == suffixes.count)
        guard normalizedBounds.count == suffixes.count else { return }

        let maxDrift = max(
            drift(normalizedBounds.map(\.minX)),
            drift(normalizedBounds.map(\.minY)),
            drift(normalizedBounds.map(\.maxX)),
            drift(normalizedBounds.map(\.maxY))
        )
        #expect(maxDrift <= 0.02)
    }

    @Test(arguments: fullBleedGenreArtworkPaths)
    func fullBleedGenreArtworkIsOpaque(relativePath: String) {
        let fileURL = repoRootURL().appendingPathComponent(relativePath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            Issue.record("Could not load genre artwork \(relativePath)")
            return
        }

        assertImageIsFullyOpaque(image, description: relativePath)
    }

    @Test
    func backLayerIsFullyOpaque() {
        let backLayer = repoRootURL()
            .appendingPathComponent("VPStudio/Assets.xcassets/AppIcon.solidimagestack/Back.solidimagestacklayer/Content.imageset/back.png")
        #expect(FileManager.default.fileExists(atPath: backLayer.path))

        guard let source = CGImageSourceCreateWithURL(backLayer as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            Issue.record("Could not load back icon layer data")
            return
        }

        assertImageIsFullyOpaque(image, description: "Back icon layer")
    }

    private func assertImageIsFullyOpaque(_ image: CGImage, description: String) {
        let alphaInfo = image.alphaInfo
        if alphaInfo == .none || alphaInfo == .noneSkipFirst || alphaInfo == .noneSkipLast {
            return
        }

        guard let providerData = image.dataProvider?.data,
              let bytePointer = CFDataGetBytePtr(providerData) else {
            Issue.record("Could not load pixel data for \(description)")
            return
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel >= 4 else {
            Issue.record("Unexpected pixel format for \(description)")
            return
        }

        let dataLength = CFDataGetLength(providerData)
        let alphaOffset = alphaInfo == .premultipliedFirst || alphaInfo == .first ? 0 : 3
        var index = alphaOffset
        while index < dataLength {
            let alpha = bytePointer[index]
            if alpha != 255 {
                Issue.record("\(description) contains a non-opaque pixel (alpha=\(alpha))")
                return
            }
            index += bytesPerPixel
        }
    }

    private func alphaValue(atX x: Int, y: Int, in image: CGImage) -> UInt8? {
        guard x >= 0, y >= 0, x < image.width, y < image.height else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.translateBy(x: CGFloat(-x), y: CGFloat(y - image.height + 1))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixel[3]
    }

    private func maxOuterEdgeAlpha(in image: CGImage) -> UInt8? {
        guard let providerData = image.dataProvider?.data,
              let bytePointer = CFDataGetBytePtr(providerData) else {
            return nil
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel >= 4 else { return nil }

        let alphaOffset = image.alphaInfo == .premultipliedFirst || image.alphaInfo == .first ? 0 : 3
        var maxAlpha: UInt8 = 0

        for x in 0..<image.width {
            let topIndex = x * bytesPerPixel + alphaOffset
            let bottomIndex = (image.height - 1) * image.bytesPerRow + x * bytesPerPixel + alphaOffset
            maxAlpha = max(max(maxAlpha, bytePointer[topIndex]), bytePointer[bottomIndex])
        }

        for y in 1..<max(1, image.height - 1) {
            let rowStart = y * image.bytesPerRow
            let leftIndex = rowStart + alphaOffset
            let rightIndex = rowStart + (image.width - 1) * bytesPerPixel + alphaOffset
            maxAlpha = max(max(maxAlpha, bytePointer[leftIndex]), bytePointer[rightIndex])
        }

        return maxAlpha
    }

    private func visibleAlphaBounds(in image: CGImage, threshold: UInt8) -> CGRect? {
        guard let providerData = image.dataProvider?.data,
              let bytePointer = CFDataGetBytePtr(providerData) else {
            return nil
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel >= 4 else { return nil }

        let alphaOffset = image.alphaInfo == .premultipliedFirst || image.alphaInfo == .first ? 0 : 3
        var minX = image.width
        var minY = image.height
        var maxX = -1
        var maxY = -1

        for y in 0..<image.height {
            let rowStart = y * image.bytesPerRow
            for x in 0..<image.width {
                let alpha = bytePointer[rowStart + x * bytesPerPixel + alphaOffset]
                guard alpha > threshold else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxX - minX + 1),
            height: CGFloat(maxY - minY + 1)
        )
    }

    private func drift(_ values: [CGFloat]) -> CGFloat {
        guard let minValue = values.min(), let maxValue = values.max() else { return 0 }
        return maxValue - minValue
    }

    private func imageDimensions(for fileURL: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }
        return CGSize(width: width.doubleValue, height: height.doubleValue)
    }

    private func repoRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }
}
