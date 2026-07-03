import Foundation
import ImageIO
import Testing
@testable import VPStudio

struct AppIconAssetTests {
    private static let appIconCandidatePaths: [String] = [
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialApertureV5.imageset/vpstudio-logo-spatial-aperture-v5-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialLensV4.imageset/vpstudio-logo-spatial-lens-v4-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialOrbitV2.imageset/vpstudio-logo-spatial-orbit-v2-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialOrbitV3.imageset/vpstudio-logo-spatial-orbit-v3-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialPlay.imageset/vpstudio-logo-spatial-play-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialPrismApertureV9.imageset/vpstudio-logo-spatial-prism-aperture-v9-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialPrismV6.imageset/vpstudio-logo-spatial-prism-v6-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialPrismLensV7.imageset/vpstudio-logo-spatial-prism-lens-v7-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialPrismLensV8.imageset/vpstudio-logo-spatial-prism-lens-v8-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialVertexV10.imageset/vpstudio-logo-spatial-vertex-v10-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialViewportV11.imageset/vpstudio-logo-spatial-viewport-v11-1024.png",
        "VPStudio/Assets.xcassets/AppIconCandidate-SpatialViewportPlayV12.imageset/vpstudio-logo-spatial-viewport-play-v12-1024.png",
    ]
    private static let flatAppIconPaths: [String] = [
        "VPStudio/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
    ] + appIconCandidatePaths
    private static let iconLayerPaths: [String] = [
        "VPStudio/Assets.xcassets/AppIcon.solidimagestack/Front.solidimagestacklayer/Content.imageset/front.png",
        "VPStudio/Assets.xcassets/AppIcon.solidimagestack/Middle.solidimagestacklayer/Content.imageset/middle.png",
        "VPStudio/Assets.xcassets/AppIcon.solidimagestack/Back.solidimagestacklayer/Content.imageset/back.png",
    ]
    private static let transparentDepthIconLayerPaths: [String] = [
        "VPStudio/Assets.xcassets/AppIcon.solidimagestack/Front.solidimagestacklayer/Content.imageset/front.png",
        "VPStudio/Assets.xcassets/AppIcon.solidimagestack/Middle.solidimagestacklayer/Content.imageset/middle.png",
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
    private static let deepGenreArtworkPaths: [String] = [
        "VPStudio/Assets.xcassets/GenreArtwork/genre-art-deep.imageset/genre-art-deep.png",
        "VPStudio/Assets.xcassets/GenreArtwork/genre-art-deep.imageset/genre-art-deep@2x.png",
        "VPStudio/Assets.xcassets/GenreArtwork/genre-art-deep.imageset/genre-art-deep@3x.png",
    ]

    @Test(arguments: flatAppIconPaths)
    func flatAppIconsExistAndAreExpectedSize(relativePath: String) {
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

    @Test(arguments: appIconCandidatePaths)
    func appIconCandidatesDoNotShipOpaqueBlackMattes(relativePath: String) {
        let fileURL = repoRootURL().appendingPathComponent(relativePath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let averageLuminance = averageOuterEdgeLuminance(in: image, edgeWidth: 16) else {
            Issue.record("Could not inspect outer edge luminance for \(relativePath)")
            return
        }

        #expect(averageLuminance > 2)
    }

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

    @Test(arguments: transparentDepthIconLayerPaths)
    func appIconDepthLayersHaveVisibleContent(relativePath: String) {
        let fileURL = repoRootURL().appendingPathComponent(relativePath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            Issue.record("Could not load depth icon layer \(relativePath)")
            return
        }

        let alphaInfo = image.alphaInfo
        #expect(alphaInfo != .none)
        #expect(alphaInfo != .noneSkipFirst)
        #expect(alphaInfo != .noneSkipLast)

        guard let bounds = visibleAlphaBounds(in: image, threshold: 8) else {
            Issue.record("Depth icon layer \(relativePath) has no visible alpha content")
            return
        }

        #expect(bounds.width > 240)
        #expect(bounds.height > 240)
    }

    @Test(arguments: transparentDepthIconLayerPaths)
    func appIconDepthLayersDoNotCarryHiddenTransparentRGBMattes(relativePath: String) {
        let fileURL = repoRootURL().appendingPathComponent(relativePath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let maxHiddenRGB = maxRGBInTransparentPixels(in: image, alphaThreshold: 0) else {
            Issue.record("Could not inspect transparent RGB data for \(relativePath)")
            return
        }

        #expect(maxHiddenRGB <= 2)
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

    @Test(arguments: ["", "@2x", "@3x"])
    func roundedReferenceGenreTilesShareOneAlphaMask(suffix: String) {
        let rootURL = repoRootURL()
        let referenceURL = rootURL.appendingPathComponent(
            "VPStudio/Assets.xcassets/ReferenceGenreTiles/genre-ref-action.imageset/genre-ref-action\(suffix).png"
        )

        guard let referenceSource = CGImageSourceCreateWithURL(referenceURL as CFURL, nil),
              let referenceImage = CGImageSourceCreateImageAtIndex(referenceSource, 0, nil),
              let referenceMask = alphaMask(in: referenceImage) else {
            Issue.record("Could not load reference genre tile alpha mask for suffix \(suffix)")
            return
        }

        for basePath in Self.roundedReferenceGenreTilePrefixes {
            let fileURL = rootURL.appendingPathComponent("\(basePath)\(suffix).png")
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let mask = alphaMask(in: image) else {
                Issue.record("Could not load reference genre tile alpha mask for \(basePath)\(suffix).png")
                continue
            }

            #expect(image.width == referenceImage.width)
            #expect(image.height == referenceImage.height)
            #expect(mask.count == referenceMask.count)

            guard mask.count == referenceMask.count else { continue }
            for index in mask.indices where mask[index] != referenceMask[index] {
                Issue.record("\(basePath)\(suffix).png alpha mask differs from the shared rounded tile mask at byte \(index)")
                break
            }
        }
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

    @Test(arguments: deepGenreArtworkPaths)
    func deepGenreArtworkDoesNotShipBottomCenterBlobArtifact(relativePath: String) {
        let fileURL = repoRootURL().appendingPathComponent(relativePath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            Issue.record("Could not load deep genre artwork \(relativePath)")
            return
        }

        let region = CGRect(
            x: CGFloat(image.width) * 0.468,
            y: CGFloat(image.height) * 0.96,
            width: CGFloat(image.width) * 0.064,
            height: CGFloat(image.height) * 0.04
        ).integral
        #expect(nearBlackPixelCount(in: image, region: region) == 0)
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

    @Test
    func backLayerKeepsVisibleAmbientDepth() {
        let backLayer = repoRootURL()
            .appendingPathComponent("VPStudio/Assets.xcassets/AppIcon.solidimagestack/Back.solidimagestacklayer/Content.imageset/back.png")
        #expect(FileManager.default.fileExists(atPath: backLayer.path))

        guard let source = CGImageSourceCreateWithURL(backLayer as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let stats = luminanceStats(in: image) else {
            Issue.record("Could not inspect back icon layer luminance")
            return
        }

        #expect(stats.average > 12)
        #expect(stats.standardDeviation > 4)
    }

    @Test
    func backLayerDoesNotDuplicateFlatAppIconForeground() {
        let rootURL = repoRootURL()
        let flatIconURL = rootURL.appendingPathComponent("VPStudio/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
        let backLayerURL = rootURL
            .appendingPathComponent("VPStudio/Assets.xcassets/AppIcon.solidimagestack/Back.solidimagestacklayer/Content.imageset/back.png")

        guard let flatSource = CGImageSourceCreateWithURL(flatIconURL as CFURL, nil),
              let flatIcon = CGImageSourceCreateImageAtIndex(flatSource, 0, nil),
              let backSource = CGImageSourceCreateWithURL(backLayerURL as CFURL, nil),
              let backLayer = CGImageSourceCreateImageAtIndex(backSource, 0, nil),
              let averageDifference = averageAbsoluteRGBDifference(flatIcon, backLayer) else {
            Issue.record("Could not compare flat app icon and stack back layer")
            return
        }

        #expect(averageDifference > 12)
    }

    @Test
    func frontDepthLayerDoesNotDuplicateMiddleApertureLayer() {
        let rootURL = repoRootURL()
        let frontLayerURL = rootURL
            .appendingPathComponent("VPStudio/Assets.xcassets/AppIcon.solidimagestack/Front.solidimagestacklayer/Content.imageset/front.png")
        let middleLayerURL = rootURL
            .appendingPathComponent("VPStudio/Assets.xcassets/AppIcon.solidimagestack/Middle.solidimagestacklayer/Content.imageset/middle.png")

        guard let frontSource = CGImageSourceCreateWithURL(frontLayerURL as CFURL, nil),
              let frontLayer = CGImageSourceCreateImageAtIndex(frontSource, 0, nil),
              let middleSource = CGImageSourceCreateWithURL(middleLayerURL as CFURL, nil),
              let middleLayer = CGImageSourceCreateImageAtIndex(middleSource, 0, nil),
              let frontBounds = visibleAlphaBounds(in: frontLayer, threshold: 8),
              let middleBounds = visibleAlphaBounds(in: middleLayer, threshold: 8),
              let frontAlphaFraction = visibleAlphaFraction(in: frontLayer, threshold: 8),
              let middleAlphaFraction = visibleAlphaFraction(in: middleLayer, threshold: 8) else {
            Issue.record("Could not compare front and middle icon layer alpha coverage")
            return
        }

        #expect(frontAlphaFraction > 0.02)
        #expect(frontAlphaFraction < middleAlphaFraction * 0.35)
        #expect(middleAlphaFraction > 0.20)
        #expect(frontBounds.width < middleBounds.width * 0.70)
        #expect(frontBounds.height < middleBounds.height * 0.70)
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

    private func maxRGBInTransparentPixels(in image: CGImage, alphaThreshold: UInt8) -> UInt8? {
        guard let providerData = image.dataProvider?.data,
              let bytePointer = CFDataGetBytePtr(providerData) else {
            return nil
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel >= 4 else { return nil }

        let dataLength = CFDataGetLength(providerData)
        let alphaOffset = image.alphaInfo == .premultipliedFirst || image.alphaInfo == .first ? 0 : 3
        let rgbOffsets = alphaOffset == 0 ? [1, 2, 3] : [0, 1, 2]
        var maxValue: UInt8 = 0
        var inspectedPixels = 0

        for y in 0..<image.height {
            let rowStart = y * image.bytesPerRow
            for x in 0..<image.width {
                let pixelStart = rowStart + x * bytesPerPixel
                let lastRGBIndex = pixelStart + (rgbOffsets.max() ?? 0)
                guard pixelStart + alphaOffset < dataLength, lastRGBIndex < dataLength else {
                    return nil
                }

                let alpha = bytePointer[pixelStart + alphaOffset]
                guard alpha <= alphaThreshold else { continue }

                inspectedPixels += 1
                for offset in rgbOffsets {
                    maxValue = max(maxValue, bytePointer[pixelStart + offset])
                }
            }
        }

        return inspectedPixels > 0 ? maxValue : nil
    }

    private func alphaMask(in image: CGImage) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
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

    private func visibleAlphaFraction(in image: CGImage, threshold: UInt8) -> Double? {
        guard let providerData = image.dataProvider?.data,
              let bytePointer = CFDataGetBytePtr(providerData) else {
            return nil
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel >= 4 else { return nil }

        let alphaOffset = image.alphaInfo == .premultipliedFirst || image.alphaInfo == .first ? 0 : 3
        var visiblePixels = 0

        for y in 0..<image.height {
            let rowStart = y * image.bytesPerRow
            for x in 0..<image.width {
                let alpha = bytePointer[rowStart + x * bytesPerPixel + alphaOffset]
                if alpha > threshold {
                    visiblePixels += 1
                }
            }
        }

        return Double(visiblePixels) / Double(image.width * image.height)
    }

    private func averageOuterEdgeLuminance(in image: CGImage, edgeWidth: Int) -> Double? {
        guard image.width > 0, image.height > 0, edgeWidth > 0 else { return nil }

        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        let clampedEdgeWidth = min(edgeWidth, image.width, image.height)
        var total: Double = 0
        var count = 0

        func appendPixel(x: Int, y: Int) {
            let index = (y * image.width + x) * 4
            let red = Double(pixels[index])
            let green = Double(pixels[index + 1])
            let blue = Double(pixels[index + 2])
            total += (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
            count += 1
        }

        for y in 0..<image.height {
            for x in 0..<image.width where
                x < clampedEdgeWidth
                || x >= image.width - clampedEdgeWidth
                || y < clampedEdgeWidth
                || y >= image.height - clampedEdgeWidth {
                appendPixel(x: x, y: y)
            }
        }

        guard count > 0 else { return nil }
        return total / Double(count)
    }

    private func nearBlackPixelCount(in image: CGImage, region: CGRect) -> Int {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Int.max
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        let minX = max(0, Int(region.minX))
        let maxX = min(image.width - 1, Int(region.maxX))
        let minY = max(0, Int(region.minY))
        let maxY = min(image.height - 1, Int(region.maxY))
        guard minX <= maxX, minY <= maxY else { return Int.max }

        var count = 0
        for y in minY...maxY {
            for x in minX...maxX {
                let index = (y * image.width + x) * 4
                let red = pixels[index]
                let green = pixels[index + 1]
                let blue = pixels[index + 2]
                let alpha = pixels[index + 3]
                if alpha > 8, red < 20, green < 35, blue < 45 {
                    count += 1
                }
            }
        }
        return count
    }

    private func averageAbsoluteRGBDifference(_ lhs: CGImage, _ rhs: CGImage) -> Double? {
        guard lhs.width == rhs.width, lhs.height == rhs.height,
              let lhsPixels = rgbaPixels(in: lhs),
              let rhsPixels = rgbaPixels(in: rhs),
              lhsPixels.count == rhsPixels.count else {
            return nil
        }

        var total: Double = 0
        var count = 0
        var index = 0
        while index < lhsPixels.count {
            total += abs(Double(lhsPixels[index]) - Double(rhsPixels[index]))
            total += abs(Double(lhsPixels[index + 1]) - Double(rhsPixels[index + 1]))
            total += abs(Double(lhsPixels[index + 2]) - Double(rhsPixels[index + 2]))
            count += 3
            index += 4
        }
        guard count > 0 else { return nil }
        return total / Double(count)
    }

    private func luminanceStats(in image: CGImage) -> (average: Double, standardDeviation: Double)? {
        guard let pixels = rgbaPixels(in: image) else { return nil }

        var total: Double = 0
        var totalSquared: Double = 0
        var count = 0
        var index = 0
        while index < pixels.count {
            let red = Double(pixels[index])
            let green = Double(pixels[index + 1])
            let blue = Double(pixels[index + 2])
            let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
            total += luminance
            totalSquared += luminance * luminance
            count += 1
            index += 4
        }

        guard count > 0 else { return nil }
        let average = total / Double(count)
        let variance = max(0, (totalSquared / Double(count)) - (average * average))
        return (average, sqrt(variance))
    }

    private func rgbaPixels(in image: CGImage) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
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
