#if os(visionOS)
import Foundation
import Testing
@testable import VPStudio

@Suite("Environment Preview Row Policy")
struct EnvironmentPreviewRowPolicyTests {
    @Test
    func importPromptAppearsUntilUserHasImportedAssets() {
        let bundled = EnvironmentAsset(
            id: "bundled",
            name: "Sky Dome",
            sourceType: .bundled,
            assetPath: "bundle://SkyDome.usdz"
        )
        let imported = EnvironmentAsset(
            id: "imported",
            name: "Imported Sky",
            sourceType: .imported,
            assetPath: "/tmp/imported-sky.hdr"
        )

        #expect(EnvironmentPreviewRowPolicy.shouldShowImportPrompt(environments: []))
        #expect(EnvironmentPreviewRowPolicy.shouldShowImportPrompt(environments: [bundled]))
        #expect(!EnvironmentPreviewRowPolicy.shouldShowImportPrompt(environments: [bundled, imported]))
    }

    @Test
    func providerIconsUseNeutralPublicationSafeSymbols() throws {
        #expect(EnvironmentPreviewRowPolicy.providerIconName(for: .official) == "checkmark.seal")
        #expect(EnvironmentPreviewRowPolicy.providerIconName(for: .github) == "shippingbox")
        #expect(EnvironmentPreviewRowPolicy.providerIconName(for: .polyHaven) == "pano")

        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        #expect(!source.contains("apple.logo"))
    }

    @Test
    func detectsHdriAssetsByExtensionCaseInsensitively() {
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/sky.hdr"))
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/sky.EXR"))
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/sky.PNG"))
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/sky.jpeg"))
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/folder/scene.HdR"))
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/scene.usdz") == false)
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/scene") == false)
    }

    @Test
    func distinguishesHdrPanoramasFromLdrPanoramasForLabels() {
        #expect(EnvironmentPreviewRowPolicy.isHDRAsset(assetPath: "/assets/sky.hdr"))
        #expect(EnvironmentPreviewRowPolicy.isHDRAsset(assetPath: "/assets/sky.exr"))
        #expect(!EnvironmentPreviewRowPolicy.isHDRAsset(assetPath: "/assets/sky.png"))
    }

    @Test
    func picksHdriAndSceneIconsFromAssetPath() {
        #expect(EnvironmentPreviewRowPolicy.assetTypeIconName(forAssetPath: "/assets/sky.hdr") == "pano")
        #expect(EnvironmentPreviewRowPolicy.assetTypeIconName(forAssetPath: "/assets/room.usdz") == "cube.transparent")
    }

    @Test
    func labelsBundledAssetsAsBuiltInRegardlessOfExtension() {
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .bundled,
                assetPath: "/assets/anything.hdr"
            ) == "Built-in"
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .bundled,
                assetPath: "/assets/anything.usdz"
            ) == "Built-in"
        )
    }

    @Test
    func labelsImportedAssetsByClassification() {
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .imported,
                assetPath: "/assets/anything.hdr"
            ) == "HDRI"
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .imported,
                assetPath: "/assets/anything.png"
            ) == "Panorama"
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .imported,
                assetPath: "/assets/anything.reality"
            ) == "3D Scene"
        )
    }

    @Test
    func importedAssetDetailLabelUsesTypeAndDecodedFileNameWithoutFullPath() {
        let asset = EnvironmentAsset(
            id: "asset",
            name: "Cinema Hall",
            sourceType: .imported,
            assetPath: "/Users/test/Library/Application Support/VPStudio/Environments/Cinema%20Hall.hdr"
        )

        let label = EnvironmentPreviewRowPolicy.assetDetailLabel(for: asset)

        #expect(label == "HDRI • Cinema Hall.hdr")
        #expect(!label.contains("/Users/test"))
        #expect(!label.contains("Application Support"))
    }

    @Test
    func bundledAssetDetailLabelUsesTypeOnly() {
        let asset = EnvironmentAsset(
            id: "bundled",
            name: "Sky Dome",
            sourceType: .bundled,
            assetPath: "bundle://SkyDome.usdz"
        )

        #expect(EnvironmentPreviewRowPolicy.assetDetailLabel(for: asset) == "Built-in")
    }

    @Test
    func standardRoomStatusIsCurrentOnlyForClosedUnselectedPlayback() {
        #expect(
            EnvironmentPreviewRowPolicy.standardRoomStatus(
                selectedAssetID: nil,
                isImmersiveSpaceOpen: false
            ) == .current
        )
        #expect(
            EnvironmentPreviewRowPolicy.standardRoomStatus(
                selectedAssetID: "imported-hdri",
                isImmersiveSpaceOpen: false
            ) == .inactive
        )
        #expect(
            EnvironmentPreviewRowPolicy.standardRoomStatus(
                selectedAssetID: nil,
                isImmersiveSpaceOpen: true
            ) == .inactive
        )
    }

    @Test
    func effectiveSelectedAssetIDFallsBackToActiveCatalogAsset() {
        let activeAsset = EnvironmentAsset(
            id: "catalog-active-hdri",
            name: "Active HDRI",
            sourceType: .imported,
            assetPath: "/tmp/active.hdr",
            isActive: true
        )
        let inactiveAsset = EnvironmentAsset(
            id: "inactive-hdri",
            name: "Inactive HDRI",
            sourceType: .imported,
            assetPath: "/tmp/inactive.hdr"
        )

        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: " app-state-selection ",
            assets: [activeAsset]
        ) == "app-state-selection")
        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: nil,
            assets: [inactiveAsset, activeAsset]
        ) == "catalog-active-hdri")
        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: "  ",
            assets: [inactiveAsset]
        ) == nil)
    }

    @Test
    func activeCatalogFallbackKeepsStandardRoomInactive() {
        let activeAsset = EnvironmentAsset(
            id: "catalog-active-hdri",
            name: "Active HDRI",
            sourceType: .imported,
            assetPath: "/tmp/active.hdr",
            isActive: true
        )
        let selectedAssetID = EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: nil,
            assets: [activeAsset]
        )

        #expect(
            EnvironmentPreviewRowPolicy.standardRoomStatus(
                selectedAssetID: selectedAssetID,
                isImmersiveSpaceOpen: false
            ) == .inactive
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetStatus(
                assetID: "catalog-active-hdri",
                selectedAssetID: selectedAssetID,
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ) == .selected
        )
    }

    @Test
    func cinemaStatusRequiresTheCinemaImmersiveSpaceToBeOpen() {
        #expect(
            EnvironmentPreviewRowPolicy.cinemaStatus(
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: true
            ) == .active
        )
        #expect(
            EnvironmentPreviewRowPolicy.cinemaStatus(
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: false
            ) == .inactive
        )
        #expect(
            EnvironmentPreviewRowPolicy.cinemaStatus(
                activeEnvironment: .hdriSkybox,
                isImmersiveSpaceOpen: true
            ) == .inactive
        )
    }

    @Test
    func assetStatusDistinguishesSelectedFromOpenCustomEnvironment() {
        #expect(
            EnvironmentPreviewRowPolicy.assetStatus(
                assetID: "imported-hdri",
                selectedAssetID: "imported-hdri",
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ) == .selected
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetStatus(
                assetID: "imported-hdri",
                selectedAssetID: "imported-hdri",
                activeEnvironment: .hdriSkybox,
                isImmersiveSpaceOpen: true
            ) == .active
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetStatus(
                assetID: "imported-hdri",
                selectedAssetID: "other-hdri",
                activeEnvironment: .hdriSkybox,
                isImmersiveSpaceOpen: true
            ) == .inactive
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetStatus(
                assetID: "imported-hdri",
                selectedAssetID: "imported-hdri",
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: true
            ) == .selected
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetStatus(
                assetID: "imported-hdri",
                selectedAssetID: "imported-hdri",
                activeEnvironment: nil,
                isImmersiveSpaceOpen: true
            ) == .selected
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetStatus(
                assetID: "imported-hdri",
                selectedAssetID: "imported-hdri",
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: true
            ) == .active
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetStatus(
                assetID: "   ",
                selectedAssetID: nil,
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ) == .inactive
        )
    }

    @Test
    func thumbnailSourcesPreferExplicitPreviewThenDecodablePanorama() {
        let bundled = EnvironmentAsset(
            id: "builtin",
            name: "Built In",
            sourceType: .bundled,
            assetPath: "bundle://SkyDome.usdz",
            previewImagePath: "bundle://SkyDomePreview.png"
        )
        let importedPanorama = EnvironmentAsset(
            id: "pano",
            name: "Imported",
            sourceType: .imported,
            assetPath: "/tmp/pano.jpg"
        )
        let importedScene = EnvironmentAsset(
            id: "scene",
            name: "Scene",
            sourceType: .imported,
            assetPath: "/tmp/scene.usdz"
        )

        #expect(EnvironmentPreviewRowPolicy.thumbnailSourcePaths(for: bundled) == ["bundle://SkyDomePreview.png"])
        #expect(EnvironmentPreviewRowPolicy.thumbnailSourcePaths(for: importedPanorama) == ["/tmp/pano.jpg"])
        #expect(EnvironmentPreviewRowPolicy.thumbnailSourcePaths(for: importedScene).isEmpty)
    }

    @Test
    func thumbnailDecodePolicyUsesToneMappedLDRPreviewOutput() {
        #expect(EnvironmentThumbnailDecodePolicy.shouldAllowFloatForPreview == false)
    }

    @Test
    func thumbnailDecodeForcesSizedPreviewInsteadOfEmbeddedCameraThumbnail() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let optionsStart = try #require(source.range(of: "let thumbOptions: [CFString: Any] = ["))
        let optionsEnd = try #require(source.range(of: "]", range: optionsStart.upperBound..<source.endIndex))
        let optionsSource = String(source[optionsStart.lowerBound...optionsEnd.lowerBound])

        #expect(optionsSource.contains("kCGImageSourceThumbnailMaxPixelSize: maxDimension"))
        #expect(optionsSource.contains("kCGImageSourceCreateThumbnailFromImageAlways: true"))
        #expect(!optionsSource.contains("kCGImageSourceCreateThumbnailFromImageIfAbsent"))
    }

    @Test
    func thumbnailDecodePolicyRecognizesCompleteJPEGFiles() {
        #expect(EnvironmentThumbnailDecodePolicy.looksLikeCompleteJPEG(
            header: Data([0xFF, 0xD8, 0xFF, 0xE0]),
            trailer: Data([0xFF, 0xD9]),
            fileSize: 4
        ))
        #expect(EnvironmentThumbnailDecodePolicy.looksLikeCompleteJPEG(
            header: Data([0xFF, 0xD8, 0xFF, 0xE0]),
            trailer: Data([0x00, 0x00]),
            fileSize: 4
        ) == false)
        #expect(EnvironmentThumbnailDecodePolicy.looksLikeCompleteJPEG(
            header: Data([0x89, 0x50, 0x4E, 0x47]),
            trailer: Data([0xFF, 0xD9]),
            fileSize: 4
        ) == false)
    }

    @Test
    func clearsSelectionWhenDeletingSelectedAsset() {
        let asset = EnvironmentAsset(
            id: "selected-hdri",
            name: "Selected HDRI",
            sourceType: .imported,
            assetPath: "/tmp/selected.hdr"
        )

        #expect(EnvironmentPreviewRowPolicy.shouldClearActiveSelection(
            deleting: "selected-hdri",
            selectedAssetID: "selected-hdri",
            assets: [asset]
        ))
    }

    @Test
    func clearsSelectionWhenCatalogStillMarksDeletedAssetActive() {
        let activeAsset = EnvironmentAsset(
            id: "catalog-active-hdri",
            name: "Catalog Active HDRI",
            sourceType: .imported,
            assetPath: "/tmp/catalog-active.hdr",
            isActive: true
        )

        #expect(EnvironmentPreviewRowPolicy.shouldClearActiveSelection(
            deleting: "catalog-active-hdri",
            selectedAssetID: nil,
            assets: [activeAsset]
        ))
    }

    @Test
    func keepsSelectionWhenDeletingInactiveUnselectedAsset() {
        let inactiveAsset = EnvironmentAsset(
            id: "inactive-hdri",
            name: "Inactive HDRI",
            sourceType: .imported,
            assetPath: "/tmp/inactive.hdr"
        )

        #expect(EnvironmentPreviewRowPolicy.shouldClearActiveSelection(
            deleting: "inactive-hdri",
            selectedAssetID: "other-hdri",
            assets: [inactiveAsset]
        ) == false)
    }

    @Test
    func ignoresBlankDeletionIDsWhenCheckingActiveSelection() {
        let activeAsset = EnvironmentAsset(
            id: "active-hdri",
            name: "Active HDRI",
            sourceType: .imported,
            assetPath: "/tmp/active.hdr",
            isActive: true
        )

        #expect(EnvironmentPreviewRowPolicy.shouldClearActiveSelection(
            deleting: "   ",
            selectedAssetID: "active-hdri",
            assets: [activeAsset]
        ) == false)
    }

    @Test
    func importedEnvironmentCardAvoidsCompoundedHoverScalingAndThumbnailFlash() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let cardStart = try #require(source.range(of: "struct EnvironmentPreviewCard: View {"))
        let cardEnd = try #require(source.range(of: "enum EnvironmentPreviewCardStatus", range: cardStart.upperBound..<source.endIndex))
        let cardSource = String(source[cardStart.lowerBound..<cardEnd.lowerBound])

        #expect(!cardSource.contains("@State private var isHovered"))
        #expect(!cardSource.contains(".onHover"))
        #expect(!cardSource.contains(".scaleEffect(isHovered"))
        #expect(cardSource.contains(".hoverEffect(.lift)"))
        #expect(cardSource.contains("@State private var thumbnailImageAssetPath: String?"))
        #expect(cardSource.contains("if thumbnailImageAssetPath != asset.assetPath"))
        #expect(!cardSource.contains("thumbnailImage = nil\n        thumbnailFailed = false"))
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
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
#endif
