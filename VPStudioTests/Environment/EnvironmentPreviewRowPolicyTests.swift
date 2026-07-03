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
    func onlinePresetRowsUseExplicitOnGlassTextTokens() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let rowSource = try #require(source.range(of: "private func onlinePresetRow"))
        let rowBody = String(source[rowSource.lowerBound...])

        #expect(rowBody.contains(".foregroundStyle(VPColor.textPrimary)"))
        #expect(rowBody.contains(".foregroundStyle(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText)"))
        #expect(!rowBody.contains(".foregroundStyle(VPColor.textTertiary)"))
        #expect(rowBody.contains(".font(.body.weight(.semibold))"))
        #expect(rowBody.contains(".font(.subheadline)"))
        #expect(rowBody.contains("EnvironmentPreviewLayoutPolicy.roomLegibilityRowOpacity"))
        #expect(rowBody.contains("EnvironmentPreviewLayoutPolicy.roomLegibilityStrokeOpacity"))
        #expect(!rowBody.contains(".foregroundStyle(.tertiary)"))
    }

    @Test
    func pickerImportAndErrorSurfacesUseBrightRoomLegibilityTokens() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let promptSource = try section(
            from: "private var importPrompt: some View {",
            to: "@ViewBuilder\n    private var importButtonLabel",
            in: source
        )
        let errorSource = try section(
            from: "private func importErrorBanner",
            to: "// MARK: - Actions",
            in: source
        )

        for sectionSource in [promptSource, errorSource] {
            #expect(sectionSource.contains("EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText"))
            #expect(sectionSource.contains("EnvironmentPreviewLayoutPolicy.roomLegibilityRowOpacity"))
            #expect(sectionSource.contains("EnvironmentPreviewLayoutPolicy.roomLegibilityStrokeOpacity"))
            #expect(!sectionSource.contains(".foregroundStyle(.secondary)"))
            #expect(!sectionSource.contains(".background(.ultraThinMaterial"))
        }
    }

    @Test
    func brightRoomPickerSurfacesStayLegibleWithoutBecomingOpaquePanels() {
        #expect(EnvironmentPreviewLayoutPolicy.roomLegibilityBackdropOpacity >= 0.16)
        #expect(EnvironmentPreviewLayoutPolicy.roomLegibilityBackdropOpacity <= 0.20)
        #expect(EnvironmentPreviewLayoutPolicy.roomLegibilityPanelOpacity >= 0.62)
        #expect(EnvironmentPreviewLayoutPolicy.roomLegibilityPanelOpacity <= 0.66)
        #expect(EnvironmentPreviewLayoutPolicy.roomLegibilityRowOpacity >= 0.58)
        #expect(EnvironmentPreviewLayoutPolicy.roomLegibilityRowOpacity <= 0.62)
        #expect(EnvironmentPreviewLayoutPolicy.roomLegibilityStrokeOpacity >= 0.28)
        #expect(EnvironmentPreviewLayoutPolicy.roomLegibilityStrokeOpacity <= 0.32)
        #expect(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryTextOpacity >= 0.92)
        #expect(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryTextOpacity <= 0.96)
    }

    @Test
    func onlinePresetOpenDismissesPickerAfterSelection() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let rowBody = try section(
            from: "private func onlinePresetRow",
            to: "private func importErrorBanner",
            in: source
        )

        #expect(rowBody.contains("Button {"))
        #expect(rowBody.contains("onSelect(installedAsset)\n                        dismiss()"))
        #expect(rowBody.contains("Label(\"Open\", systemImage: \"play.circle\")"))
    }

    @Test
    func environmentPickerErrorsUseSharedRedactionPolicy() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")

        #expect(source.contains("EnvironmentErrorPresentationPolicy.displayMessage(for: error)"))
        #expect(source.contains("EnvironmentErrorPresentationPolicy.deleteFailureMessage(for: error)"))
        #expect(!source.contains("importError = error.localizedDescription"))
        #expect(!source.contains("\"Failed to delete: \\(error.localizedDescription)\""))
    }

    @Test
    func appleEnvironmentCopyMentionsSystemWindowAndGatesSystemExpansion() {
        #expect(EnvironmentPreviewRowPolicy.appleEnvironmentTitle == "Apple Environment")
        #expect(EnvironmentPreviewRowPolicy.appleEnvironmentTypeLabel == "System window")
        #expect(EnvironmentPreviewRowPolicy.appleEnvironmentDetailText.contains("system"))
        #expect(EnvironmentPreviewRowPolicy.appleEnvironmentBenefitLabel == "System expansion when available")
        #expect(EnvironmentPreviewRowPolicy.appleEnvironmentPickerSubtitle.contains("system window"))
        #expect(EnvironmentPreviewRowPolicy.appleEnvironmentPickerSubtitle.contains("system video surface"))
        #expect(EnvironmentPreviewRowPolicy.appleEnvironmentPickerSubtitle.contains("room effects"))
        #expect(!EnvironmentPreviewRowPolicy.appleEnvironmentPickerSubtitle.localizedCaseInsensitiveContains("reflections"))
        #expect(EnvironmentPreviewRowPolicy.appleEnvironmentSelectedBody.contains("system-owned window"))
        #expect(EnvironmentPreviewRowPolicy.appleEnvironmentSelectedBody.contains("supported playback"))
        #expect(EnvironmentPreviewRowPolicy.appleEnvironmentSelectedBody.contains("room effects"))
        #expect(!EnvironmentPreviewRowPolicy.appleEnvironmentSelectedBody.localizedCaseInsensitiveContains("reflections"))
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
    func fallbackArtworkIconsStayVisibleOnDarkEnvironmentCards() throws {
        #expect(EnvironmentPreviewFallbackArtworkKind.standardRoom.iconName == "visionpro")
        #expect(EnvironmentPreviewFallbackArtworkKind.cinema.iconName == "theatermasks.fill")
        #expect(EnvironmentPreviewFallbackArtworkKind.bundledEnvironment.iconName == "sparkles")
        #expect(EnvironmentPreviewFallbackArtworkKind.panorama.iconName == "pano.fill")
        #expect(EnvironmentPreviewFallbackArtworkKind.scene.iconName == "cube.transparent.fill")
        #expect(EnvironmentPreviewFallbackArtworkKind.standardRoom.iconOpacity >= 0.62)
        #expect(EnvironmentPreviewFallbackArtworkKind.cinema.iconOpacity >= 0.66)
        #expect(EnvironmentPreviewFallbackArtworkKind.bundledEnvironment.iconOpacity >= 0.68)
        #expect(EnvironmentPreviewFallbackArtworkKind.panorama.iconOpacity >= 0.70)
        #expect(EnvironmentPreviewFallbackArtworkKind.scene.iconOpacity >= 0.66)

        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        #expect(source.contains(".shadow(color: .black.opacity(0.55), radius: 2, y: 1)"))
        #expect(!source.contains(".shadow(color: accent.opacity(0.26), radius: 16"))
    }

    @Test
    func environmentCardCaptionsStayLegibleOverFallbackArtwork() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let cardSource = try section(
            from: "struct EnvironmentPreviewCard: View {",
            to: "struct CinemaEnvironmentPreviewCard: View {",
            in: source
        )
        let cinemaSource = try section(
            from: "struct CinemaEnvironmentPreviewCard: View {",
            to: "struct NoEnvironmentPreviewCard: View {",
            in: source
        )
        let appleSource = try section(
            from: "struct NoEnvironmentPreviewCard: View {",
            to: "private struct EnvironmentStatusChip: View {",
            in: source
        )

        for cardBody in [cardSource, cinemaSource, appleSource] {
            #expect(cardBody.contains(".foregroundStyle(.white.opacity(0.86))"))
            #expect(cardBody.contains(".shadow(color: .black.opacity(0.55), radius: 2, y: 1)"))
        }
        #expect(!cardSource.contains(".foregroundStyle(.white.opacity(0.75))"))
        #expect(!cinemaSource.contains(".foregroundStyle(.white.opacity(0.75))"))
        #expect(!appleSource.contains(".foregroundStyle(.white.opacity(0.75))"))
    }

    @Test
    func fallbackArtworkDifferentiatesBuiltInPanoramaAndSceneCards() throws {
        #expect(
            EnvironmentPreviewRowPolicy.fallbackArtworkKind(
                sourceType: .bundled,
                assetPath: "/assets/anything.usdz"
            ) == .bundledEnvironment
        )
        #expect(
            EnvironmentPreviewRowPolicy.fallbackArtworkKind(
                sourceType: .imported,
                assetPath: "/assets/sky.hdr"
            ) == .panorama
        )
        #expect(
            EnvironmentPreviewRowPolicy.fallbackArtworkKind(
                sourceType: .imported,
                assetPath: "/assets/room.usdz"
            ) == .scene
        )

        let asset = EnvironmentAsset(
            id: "asset-a",
            name: "Starlight Cinema",
            sourceType: .bundled,
            assetPath: "bundle://Starlight.usdz"
        )
        let paletteIndex = EnvironmentPreviewRowPolicy.fallbackPaletteIndex(for: asset, paletteCount: 4)
        #expect(paletteIndex >= 0)
        #expect(paletteIndex < 4)
        #expect(paletteIndex == EnvironmentPreviewRowPolicy.fallbackPaletteIndex(for: asset, paletteCount: 4))
        #expect(EnvironmentPreviewRowPolicy.fallbackPaletteIndex(for: asset, paletteCount: 0) == 0)

        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        #expect(source.contains("EnvironmentPreviewFallbackArtworkView(kind: .standardRoom"))
        #expect(source.contains("EnvironmentPreviewFallbackArtworkView(kind: .cinema"))
        #expect(source.contains("EnvironmentPreviewRowPolicy.fallbackArtworkKind("))
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
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ) == .current
        )
        #expect(
            EnvironmentPreviewRowPolicy.standardRoomStatus(
                selectedAssetID: "imported-hdri",
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ) == .inactive
        )
        #expect(
            EnvironmentPreviewRowPolicy.standardRoomStatus(
                selectedAssetID: nil,
                activeEnvironment: nil,
                isImmersiveSpaceOpen: true
            ) == .inactive
        )
        #expect(
            EnvironmentPreviewRowPolicy.standardRoomStatus(
                selectedAssetID: nil,
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: false
            ) == .inactive
        )
        #expect(
            EnvironmentPreviewRowPolicy.standardRoomStatus(
                selectedAssetID: nil,
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: false
            ) == .inactive
        )
    }

    @Test
    func effectiveSelectedAssetIDFallsBackToActiveCatalogAsset() {
        let appStateAsset = EnvironmentAsset(
            id: "app-state-selection",
            name: "App State Selection",
            sourceType: .imported,
            assetPath: "/tmp/app-state.hdr"
        )
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
            assets: [appStateAsset, activeAsset]
        ) == "app-state-selection")
        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: nil,
            assets: [inactiveAsset, activeAsset]
        ) == "catalog-active-hdri")
        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: "  ",
            assets: [inactiveAsset]
        ) == nil)
        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAsset(
            appStateSelectedAsset: nil,
            assets: [inactiveAsset, activeAsset]
        )?.id == "catalog-active-hdri")
        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAsset(
            appStateSelectedAsset: appStateAsset,
            assets: [appStateAsset, activeAsset]
        )?.id == "app-state-selection")
    }

    @Test
    func staleAppStateSelectionFallsBackToLoadedCatalogState() {
        let staleAppStateAsset = EnvironmentAsset(
            id: "missing-selection",
            name: "Deleted Environment",
            sourceType: .imported,
            assetPath: "/tmp/deleted.hdr"
        )
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
            appStateSelectedID: staleAppStateAsset.id,
            assets: [inactiveAsset, activeAsset]
        ) == activeAsset.id)
        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAsset(
            appStateSelectedAsset: staleAppStateAsset,
            assets: [inactiveAsset, activeAsset]
        )?.id == activeAsset.id)
        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: staleAppStateAsset.id,
            assets: [inactiveAsset]
        ) == nil)
        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAsset(
            appStateSelectedAsset: staleAppStateAsset,
            assets: [inactiveAsset]
        ) == nil)
        #expect(EnvironmentPreviewRowPolicy.standardRoomStatus(
            selectedAssetID: EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
                appStateSelectedID: staleAppStateAsset.id,
                assets: [inactiveAsset]
            ),
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == .current)
        #expect(EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: staleAppStateAsset.id,
            assets: []
        ) == staleAppStateAsset.id)
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
                activeEnvironment: nil,
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
    func statusChipsDistinguishCurrentSelectedAndActiveStates() throws {
        #expect(EnvironmentPreviewCardStatus.inactive.chip?.title == nil)
        #expect(EnvironmentPreviewCardStatus.current.chip?.title == "Current")
        #expect(EnvironmentPreviewCardStatus.current.chip?.systemImage == "checkmark.circle.fill")
        #expect(EnvironmentPreviewCardStatus.selected.chip?.title == "Selected")
        #expect(EnvironmentPreviewCardStatus.selected.chip?.systemImage == "checkmark.circle")
        #expect(EnvironmentPreviewCardStatus.active.chip?.title == "Active")
        #expect(EnvironmentPreviewCardStatus.active.chip?.systemImage == "play.circle.fill")

        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let statusStart = try #require(source.range(of: "enum EnvironmentPreviewCardStatus"))
        let statusEnd = try #require(source.range(of: "enum EnvironmentPreviewFallbackArtworkKind", range: statusStart.upperBound..<source.endIndex))
        let statusSource = String(source[statusStart.lowerBound..<statusEnd.lowerBound])
        #expect(statusSource.contains("VPColor.info"))
        #expect(statusSource.contains("VPColor.success"))
        #expect(!statusSource.contains(".blue"))
        #expect(!statusSource.contains(".green"))
    }

    @Test
    func thumbnailSourcesPreferExplicitPreviewThenThumbnailThenDecodablePanorama() {
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
            assetPath: "/tmp/pano.jpg",
            thumbnailPath: "/tmp/pano-thumb.jpg",
            previewImagePath: "/tmp/pano-preview.jpg"
        )
        let importedScene = EnvironmentAsset(
            id: "scene",
            name: "Scene",
            sourceType: .imported,
            assetPath: "/tmp/scene.usdz",
            thumbnailPath: "/tmp/scene-thumb.jpg"
        )
        let duplicatedSources = EnvironmentAsset(
            id: "duplicate",
            name: "Duplicate",
            sourceType: .imported,
            assetPath: "/tmp/duplicate.jpg",
            thumbnailPath: " /tmp/duplicate.jpg ",
            previewImagePath: "/tmp/duplicate.jpg"
        )

        #expect(EnvironmentPreviewRowPolicy.thumbnailSourcePaths(for: bundled) == ["bundle://SkyDomePreview.png"])
        #expect(EnvironmentPreviewRowPolicy.thumbnailSourcePaths(for: importedPanorama) == [
            "/tmp/pano-preview.jpg",
            "/tmp/pano-thumb.jpg",
            "/tmp/pano.jpg",
        ])
        #expect(EnvironmentPreviewRowPolicy.thumbnailSourcePaths(for: importedScene) == ["/tmp/scene-thumb.jpg"])
        #expect(EnvironmentPreviewRowPolicy.thumbnailSourcePaths(for: duplicatedSources) == ["/tmp/duplicate.jpg"])
    }

    @Test
    func thumbnailLoadIdentityTracksPreviewThumbnailAndAssetSources() {
        let withPreview = EnvironmentAsset(
            id: "pano",
            name: "Imported",
            sourceType: .imported,
            assetPath: "/tmp/pano.jpg",
            thumbnailPath: "/tmp/pano-thumb.jpg",
            previewImagePath: "/tmp/pano-preview.jpg"
        )
        let updatedPreview = EnvironmentAsset(
            id: "pano",
            name: "Imported",
            sourceType: .imported,
            assetPath: "/tmp/pano.jpg",
            thumbnailPath: "/tmp/pano-thumb.jpg",
            previewImagePath: "/tmp/pano-preview-v2.jpg"
        )
        let sceneWithoutThumbnail = EnvironmentAsset(
            id: "scene",
            name: "Scene",
            sourceType: .imported,
            assetPath: " /tmp/scene.usdz "
        )

        #expect(EnvironmentPreviewRowPolicy.thumbnailLoadID(for: withPreview) == [
            "/tmp/pano-preview.jpg",
            "/tmp/pano-thumb.jpg",
            "/tmp/pano.jpg",
        ].joined(separator: "\u{1F}"))
        #expect(EnvironmentPreviewRowPolicy.thumbnailLoadID(for: withPreview) != EnvironmentPreviewRowPolicy.thumbnailLoadID(for: updatedPreview))
        #expect(EnvironmentPreviewRowPolicy.thumbnailLoadID(for: sceneWithoutThumbnail) == "/tmp/scene.usdz")
    }

    @Test
    func thumbnailReadabilityRejectsDirectoriesSymlinksAndMissingFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("env-preview-thumbnail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("preview.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: file)

        let directory = root.appendingPathComponent("preview-directory.jpg", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let symlink = root.appendingPathComponent("preview-link.jpg")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: file)

        #expect(EnvironmentPreviewRowPolicy.isReadableThumbnailFile(file))
        #expect(!EnvironmentPreviewRowPolicy.isReadableThumbnailFile(directory))
        #expect(!EnvironmentPreviewRowPolicy.isReadableThumbnailFile(symlink))
        #expect(!EnvironmentPreviewRowPolicy.isReadableThumbnailFile(root.appendingPathComponent("missing.jpg")))
    }

    @Test
    func thumbnailDecodePolicyUsesToneMappedLDRPreviewOutput() {
        #expect(EnvironmentThumbnailDecodePolicy.shouldAllowFloatForPreview == false)
    }

    @Test
    func thumbnailArtworkCrossfadesFromFallbackInsteadOfPoppingIn() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let cardSource = try section(
            from: "struct EnvironmentPreviewCard: View {",
            to: "enum EnvironmentPreviewCardStatus",
            in: source
        )
        let previewBody = try section(
            from: "private var previewBackground: some View {",
            to: "private var placeholderGradient: some View {",
            in: cardSource
        )

        #expect(cardSource.contains(".animation(.easeInOut(duration: 0.18), value: thumbnailImageSourceID)"))
        #expect(previewBody.contains(".transition(.opacity)"))
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
        #expect(cardSource.contains("@State private var thumbnailImageSourceID: String?"))
        #expect(cardSource.contains(".task(id: EnvironmentPreviewRowPolicy.thumbnailLoadID(for: asset))"))
        #expect(cardSource.contains("let loadID = EnvironmentPreviewRowPolicy.thumbnailLoadID(for: asset)"))
        #expect(cardSource.contains("if thumbnailImageSourceID != loadID"))
        #expect(!cardSource.contains(".task(id: asset.assetPath)"))
        #expect(!cardSource.contains("thumbnailImage = nil\n        thumbnailFailed = false"))
    }

    @Test
    func environmentCardTitlesWrapInsteadOfHardTruncatingImportedNames() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let titleStart = try #require(source.range(of: "struct EnvironmentPreviewCardTitleText: View {"))
        let titleSource = String(source[titleStart.lowerBound..<source.endIndex])

        #expect(source.contains("EnvironmentPreviewCardTitleText(asset.name)"))
        #expect(source.contains("EnvironmentPreviewCardTitleText(\"Cinema Environment\")"))
        #expect(source.contains("EnvironmentPreviewCardTitleText(EnvironmentPreviewRowPolicy.appleEnvironmentTitle)"))
        #expect(titleSource.contains(".lineLimit(2)"))
        #expect(titleSource.contains(".minimumScaleFactor(0.82)"))
        #expect(titleSource.contains(".allowsTightening(true)"))
        #expect(titleSource.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(source.contains(".init(color: .black.opacity(0.62), location: 0.64)"))
        #expect(source.contains(".init(color: .black.opacity(0.88), location: 1.0)"))
        #expect(!source.contains("Text(asset.name)\n                        .font(.subheadline)"))
    }

    @Test
    func environmentPreviewGridCellsDoNotStretchBeyondCardWidth() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")

        #expect(EnvironmentPreviewLayoutPolicy.cardWidth == 286)
        #expect(EnvironmentPreviewLayoutPolicy.cardHeight == 158)
        #expect(EnvironmentPreviewLayoutPolicy.gridSpacing == 18)
        #expect(EnvironmentPreviewLayoutPolicy.maximumCenteredColumns == 4)
        #expect(EnvironmentPreviewLayoutPolicy.contentSpacing == 24)
        #expect(EnvironmentPreviewLayoutPolicy.contentHorizontalPadding == 24)
        #expect(EnvironmentPreviewLayoutPolicy.contentTopPadding == 24)
        #expect(EnvironmentPreviewLayoutPolicy.bottomContentPadding == 12)
        #expect(EnvironmentPreviewLayoutPolicy.gridContentMaxWidth(itemCount: 1) == 286)
        #expect(EnvironmentPreviewLayoutPolicy.gridContentMaxWidth(itemCount: 4) == 1_198)
        #expect(EnvironmentPreviewLayoutPolicy.gridContentMaxWidth(itemCount: 8) == 1_198)
        #expect(EnvironmentPreviewLayoutPolicy.pickerMinWidth == 720)
        #expect(EnvironmentPreviewLayoutPolicy.pickerPreferredWidth == 1_180)
        #expect(EnvironmentPreviewLayoutPolicy.pickerMinHeight == 456)
        #expect(EnvironmentPreviewLayoutPolicy.pickerMinWidth <= 980)
        #expect(EnvironmentPreviewLayoutPolicy.pickerPreferredWidth >= EnvironmentPreviewLayoutPolicy.gridContentMaxWidth(itemCount: 3))
        #expect(source.contains(".adaptive(minimum: cardWidth, maximum: cardWidth)"))
        #expect(source.contains("columns: EnvironmentPreviewLayoutPolicy.gridColumns()"))
        #expect(source.contains(".frame(maxWidth: EnvironmentPreviewLayoutPolicy.gridContentMaxWidth(itemCount: itemCount))"))
        #expect(source.contains(".frame(maxWidth: .infinity, alignment: .center)"))
        #expect(!source.contains(".adaptive(minimum: 286, maximum: 340)"))
        #expect(!source.contains("private let cardWidth: CGFloat = 286"))
        #expect(!source.contains("private let cardHeight: CGFloat = 168"))
        #expect(!source.contains("VStack(alignment: .leading, spacing: 28)"))
        #expect(!source.contains(".padding(.horizontal, 28)"))
        #expect(!source.contains(".padding(.top, 28)"))
    }

    @Test
    func environmentsTabOwnsFullWindowBackground() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        let viewStart = try #require(source.range(of: "struct EnvironmentsTabView: View {"))
        let viewSource = String(source[viewStart.lowerBound..<source.endIndex])

        #expect(EnvironmentsTabPresentationPolicy.contentMaxWidth == EnvironmentPreviewLayoutPolicy.gridContentMaxWidth(itemCount: 4))
        #expect(viewSource.contains("ZStack(alignment: .topLeading)"))
        #expect(viewSource.contains("VPEnvironmentBackdrop()\n                .ignoresSafeArea()"))
        #expect(viewSource.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)"))
        #expect(viewSource.contains(".frame(maxWidth: EnvironmentsTabPresentationPolicy.contentMaxWidth, alignment: .leading)"))
        #expect(viewSource.contains(".frame(maxWidth: EnvironmentPreviewLayoutPolicy.gridContentMaxWidth(itemCount: itemCount), alignment: .leading)"))
        #expect(viewSource.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        #expect(viewSource.contains(".foregroundStyle(VPColor.textPrimary)"))
        #expect(viewSource.contains(".foregroundStyle(VPColor.textSecondary)"))
        #expect(!viewSource.contains(".foregroundStyle(VPColor.textTertiary)"))
        #expect(viewSource.contains("EnvironmentPreviewLayoutPolicy.roomLegibilityPanelOpacity"))
        #expect(viewSource.contains("EnvironmentPreviewLayoutPolicy.roomLegibilityRowOpacity"))
        #expect(viewSource.contains("EnvironmentPreviewLayoutPolicy.roomLegibilityStrokeOpacity"))
        #expect(viewSource.contains(".foregroundStyle(appState.isImmersiveSpaceOpen ? VPColor.success : VPColor.info)"))
        #expect(viewSource.contains("VPColor.contentPlane.opacity(0.56)"))
        #expect(viewSource.contains("private var effectiveSelectedEnvironmentAssetID: String?"))
        #expect(viewSource.contains("private var effectiveSelectedEnvironmentAsset: EnvironmentAsset?"))
        #expect(viewSource.contains("selectedAssetID: selectedAssetID"))
        #expect(viewSource.contains("if appState.isImmersiveSpaceOpen || effectiveSelectedEnvironmentAssetID != nil"))
        #expect(viewSource.contains("if EnvironmentPreviewRowPolicy.assetStatus("))
        #expect(viewSource.contains("selectedAssetID: effectiveSelectedEnvironmentAssetID"))
        #expect(viewSource.contains("return \"visionpro\""))
        #expect(!viewSource.contains("if asset.id == effectiveSelectedEnvironmentAssetID, appState.isImmersiveSpaceOpen"))
        #expect(!viewSource.contains(".frame(maxWidth: 900, alignment: .leading)"))

        let headerSource = try section(
            from: "private var environmentHeader: some View {",
            to: "private var environmentGrid: some View {",
            in: viewSource
        )
        #expect(!headerSource.contains("VPBadge("))
        #expect(!headerSource.contains("environmentStatusBadgeText"))
        #expect(!viewSource.contains("private var environmentStatusBadgeText: String"))
    }

    @Test
    func environmentPickerShowsSelectedStatusPanelBelowCards() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let pickerSource = try section(
            from: "struct EnvironmentPickerSheet: View {",
            to: "private var exitButton: some View {",
            in: source
        )

        #expect(pickerSource.contains("ViewThatFits(in: .vertical)"))
        #expect(pickerSource.contains("pickerContent\n            ScrollView"))
        #expect(pickerSource.contains("private var pickerContent: some View"))
        #expect(pickerSource.contains("EnvironmentPreviewLayoutPolicy.roomLegibilityBackdropOpacity"))
        let pickerContentSource = try section(
            from: "private var pickerContent: some View {",
            to: "private var header: some View {",
            in: pickerSource
        )
        let gridRange = try #require(pickerContentSource.range(of: "environmentGrid"))
        let statusPanelRange = try #require(pickerContentSource.range(of: "environmentStatusPanel"))
        #expect(gridRange.upperBound <= statusPanelRange.lowerBound)
        #expect(pickerSource.contains(".presentationSizing(.fitted)"))
        #expect(pickerSource.contains("EnvironmentPreviewLayoutPolicy.pickerMinWidth"))
        #expect(pickerSource.contains("EnvironmentPreviewLayoutPolicy.pickerPreferredWidth"))
        #expect(pickerSource.contains("EnvironmentPreviewLayoutPolicy.pickerMinHeight"))
        #expect(pickerSource.contains("idealWidth: EnvironmentPreviewLayoutPolicy.pickerPreferredWidth"))
        #expect(pickerSource.contains("maxWidth: EnvironmentPreviewLayoutPolicy.pickerPreferredWidth"))
        #expect(pickerSource.contains("ViewThatFits(in: .horizontal)"))
        #expect(pickerSource.contains("private var headerTitleBlock: some View"))
        #expect(pickerSource.contains("private var headerActions: some View"))
        #expect(pickerSource.contains("private var closeButton: some View"))
        #expect(pickerSource.contains("Image(systemName: \"xmark.circle.fill\")"))
        #expect(pickerSource.contains("EnvironmentPreviewLayoutPolicy.closeButtonSize"))
        #expect(pickerSource.contains(".accessibilityLabel(\"Close environments\")"))
        #expect(!pickerSource.contains("Button(\"Done\")"))
        #expect(pickerSource.contains("EnvironmentPreviewLayoutPolicy.contentSpacing"))
        #expect(pickerSource.contains("EnvironmentPreviewLayoutPolicy.contentHorizontalPadding"))
        #expect(pickerSource.contains("EnvironmentPreviewLayoutPolicy.contentTopPadding"))
        #expect(pickerSource.contains("EnvironmentPreviewLayoutPolicy.bottomContentPadding"))
        #expect(pickerSource.contains("private var environmentStatusPanel: some View"))
        #expect(pickerSource.contains("Text(environmentStatusTitle)"))
        #expect(pickerSource.contains("Text(environmentStatusDescription)"))
        #expect(pickerSource.contains("Label(\n                        appState.isImmersiveSpaceOpen ? \"Exit Environment\" : \"Use Apple Environment\""))
        #expect(pickerSource.contains("if appState.isImmersiveSpaceOpen || (effectiveSelectedEnvironmentAssetID != nil && onClear != nil)"))
        #expect(pickerSource.contains(".frame(maxWidth: EnvironmentPreviewLayoutPolicy.gridContentMaxWidth(itemCount: 4))"))
        #expect(source.contains("private var effectiveSelectedEnvironmentAssetID: String?"))
        #expect(source.contains("private var environmentStatusIconName: String"))
        #expect(source.contains("return EnvironmentPreviewRowPolicy.appleEnvironmentSelectedBody"))
    }

    @Test
    func rootEnvironmentPickerDismissesOnlyActuallyActiveAssetSelection() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        let bodyStart = try #require(source.range(of: "private func openEnvironment(_ asset: EnvironmentAsset) async {"))
        let bodyEnd = try #require(source.range(of: "private func ensureEnvironmentAssetExists", range: bodyStart.upperBound..<source.endIndex))
        let openEnvironmentSource = String(source[bodyStart.lowerBound..<bodyEnd.lowerBound])

        #expect(openEnvironmentSource.contains("let selectedAssetID = appState.selectedEnvironmentAsset?.id ?? (asset.isActive ? asset.id : nil)"))
        #expect(openEnvironmentSource.contains("EnvironmentPreviewRowPolicy.assetStatus("))
        #expect(openEnvironmentSource.contains("guard await ensureEnvironmentAssetExists(asset) else {"))
        #expect(openEnvironmentSource.contains("activeEnvironment: appState.activeEnvironment"))
        #expect(openEnvironmentSource.contains("isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen"))
        #expect(!openEnvironmentSource.contains("if asset.id == appState.selectedEnvironmentAsset?.id, appState.isImmersiveSpaceOpen"))
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
    }

    private func section(from startToken: String, to endToken: String, in source: String) throws -> String {
        let start = try #require(source.range(of: startToken))
        let end = try #require(source.range(of: endToken, range: start.upperBound..<source.endIndex))
        return String(source[start.lowerBound..<end.lowerBound])
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
