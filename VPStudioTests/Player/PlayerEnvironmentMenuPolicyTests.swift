#if os(visionOS)
import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerEnvironmentMenu Policy Requirements")
struct PlayerEnvironmentMenuPolicyTests {

    @Test
    func cinemaEnvironmentPolicyMenuDismissalDelay() {
        #expect(PlayerCinemaEnvironmentPolicy.menuDismissalDelay == .milliseconds(180))
    }

    @Test
    func cinemaEnvironmentPolicyUnavailableMessage() {
        #expect(PlayerCinemaEnvironmentPolicy.unavailableMessage == "Cinema Environment requires AVPlayer playback.")
    }

    @Test
    func cinemaEnvironmentPolicyCanOpenWithAVPlayer() {
        #expect(PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: .avPlayer, hasAVPlayer: true))
    }

    @Test
    func cinemaEnvironmentPolicyCannotOpenWithKSPlayer() {
        #expect(!PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: .ksPlayer, hasAVPlayer: true))
    }

    @Test
    func cinemaEnvironmentPolicyCannotOpenWithoutPlayer() {
        #expect(!PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: .avPlayer, hasAVPlayer: false))
    }

    @Test
    func cinemaEnvironmentPolicyIconForHDRExtension() {
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "scene.hdr") == "pano")
    }

    @Test
    func cinemaEnvironmentPolicyIconForEXRExtension() {
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "scene.exr") == "pano")
    }

    @Test
    func cinemaEnvironmentPolicyIconForUSDZExtension() {
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "model.usdz") == "cube.transparent")
    }

    @Test
    func cinemaEnvironmentPolicyIconForUnknownExtension() {
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "scene.unknown") == "cube.transparent")
    }

    @Test
    func playerEnvironmentMenuCinemaIconReflectsActiveCinemaOnlyWhenImmersive() {
        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: true
            ) == "checkmark"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: true
            ) == "theatermasks"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: false
            ) == "theatermasks"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: nil,
                isImmersiveSpaceOpen: true
            ) == "theatermasks"
        )
    }

    @Test
    func playerEnvironmentMenuAssetIconsUseLiveSelectionAndFallbackSourceGlyphs() {
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                assetID: "selected",
                selectedAssetID: "selected",
                activeEnvironment: .customEnvironment,
                sourceType: .imported
            ) == "checkmark"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                assetID: "bundled",
                selectedAssetID: "selected",
                activeEnvironment: .customEnvironment,
                sourceType: .bundled
            ) == "circle.fill"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                assetID: "imported",
                selectedAssetID: nil,
                activeEnvironment: nil,
                sourceType: .imported
            ) == "pano"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                assetID: "selected",
                selectedAssetID: "selected",
                activeEnvironment: .cinemaEnvironment,
                sourceType: .imported
            ) == "pano"
        )
    }

    @Test
    func playerEnvironmentMenuKeepsAssetSelectionVisibleWhileCinemaIsActive() {
        #expect(PlayerEnvironmentMenuPolicy.assetStateText(
            assetID: "env",
            selectedAssetID: "env",
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true
        ) == "Selected")
        #expect(PlayerEnvironmentMenuPolicy.compactAssetTrailingIconName(
            assetID: "env",
            selectedAssetID: "env",
            activeEnvironment: .cinemaEnvironment
        ) == "checkmark")
    }

    @Test
    func playerEnvironmentMenuStandardRoomReflectsClearedSelection() {
        #expect(PlayerEnvironmentMenuPolicy.standardRoomIconName(isSelected: true) == "checkmark")
        #expect(PlayerEnvironmentMenuPolicy.standardRoomIconName(isSelected: false) == "visionpro")
        #expect(PlayerEnvironmentMenuPolicy.isStandardRoomSelected(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ))
        #expect(!PlayerEnvironmentMenuPolicy.isStandardRoomSelected(
            selectedAssetID: "env-1",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ))
        #expect(!PlayerEnvironmentMenuPolicy.isStandardRoomSelected(
            selectedAssetID: nil,
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true
        ))
        #expect(!PlayerEnvironmentMenuPolicy.isStandardRoomSelected(
            selectedAssetID: nil,
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ))
        #expect(PlayerEnvironmentMenuPolicy.isStandardRoomSelected(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: true
        ))
    }

    @Test
    func playerEnvironmentMenuStandardLabelUsesPolicy() {
        let selected = PlayerEnvironmentMenuLabelSpec.standardRoom(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        )
        let unselected = PlayerEnvironmentMenuLabelSpec.standardRoom(
            selectedAssetID: "env-1",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        )
        let unavailableSystemSurface = PlayerEnvironmentMenuLabelSpec.standardRoom(
            selectedAssetID: "env-1",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false,
            canUseSystemVideoSurface: false
        )
        let pendingExpansion = PlayerEnvironmentMenuLabelSpec.standardRoom(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false,
            canUseSystemVideoSurface: false,
            isExpansionPending: true
        )
        #expect(selected.title == "Apple Environment")
        #expect(selected.leadingSystemImage == "checkmark")
        #expect(selected.subtitle == "Active now")
        #expect(selected.menuTitle == "Apple Environment")
        #expect(unselected.leadingSystemImage == "visionpro")
        #expect(unselected.subtitle == PlayerEnvironmentMenuPolicy.appleEnvironmentMenuBenefit)
        #expect(unselected.menuTitle == "Apple Environment - System expansion when available")
        #expect(unavailableSystemSurface.leadingSystemImage == "visionpro")
        #expect(unavailableSystemSurface.subtitle == PlayerEnvironmentMenuPolicy.appleEnvironmentFallbackBenefit)
        #expect(unavailableSystemSurface.menuTitle == "Apple Environment - Standard window until supported playback is active")
        #expect(pendingExpansion.leadingSystemImage == "checkmark")
        #expect(pendingExpansion.subtitle == PlayerEnvironmentMenuPolicy.appleEnvironmentPendingBenefit)
        #expect(pendingExpansion.menuTitle == "Apple Environment - Expansion queued until supported playback is active")
    }

    @Test
    func playerEnvironmentMenuStateTextDifferentiatesActiveAndSelectedAssets() {
        #expect(PlayerEnvironmentMenuPolicy.standardRoomStateText(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == "Active now")
        #expect(PlayerEnvironmentMenuPolicy.standardRoomStateText(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false,
            isExpansionPending: true
        ) == PlayerEnvironmentMenuPolicy.appleEnvironmentPendingBenefit)
        #expect(PlayerEnvironmentMenuPolicy.standardRoomStateText(
            selectedAssetID: "env",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == PlayerEnvironmentMenuPolicy.appleEnvironmentMenuBenefit)
        #expect(PlayerEnvironmentMenuPolicy.standardRoomStateText(
            selectedAssetID: "env",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false,
            canUseSystemVideoSurface: false
        ) == PlayerEnvironmentMenuPolicy.appleEnvironmentFallbackBenefit)
        #expect(PlayerEnvironmentMenuPolicy.cinemaStateText(
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true
        ) == "Active now")
        #expect(PlayerEnvironmentMenuPolicy.cinemaStateText(
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false,
            canOpenCinema: false
        ) == PlayerCinemaEnvironmentPolicy.unavailableMessage)
        #expect(PlayerEnvironmentMenuPolicy.cinemaStateText(
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true,
            canOpenCinema: false
        ) == "Active now")
        #expect(PlayerEnvironmentMenuPolicy.cinemaStateText(
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: false
        ) == nil)
        #expect(PlayerEnvironmentMenuPolicy.assetStateText(
            assetID: "env",
            selectedAssetID: "env",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ) == "Active now")
        #expect(PlayerEnvironmentMenuPolicy.assetStateText(
            assetID: "env",
            selectedAssetID: "env",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: false
        ) == "Selected")
        #expect(PlayerEnvironmentMenuPolicy.assetStateText(
            assetID: "env",
            selectedAssetID: "other",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ) == nil)
    }

    @Test
    func playerEnvironmentMenuCompactAssetIconReusesCinemaEnvironmentPolicy() {
        #expect(PlayerEnvironmentMenuPolicy.compactAssetIconName(forAssetPath: "scene.hdr") == "pano")
        #expect(PlayerEnvironmentMenuPolicy.compactAssetIconName(forAssetPath: "room.usdz") == "cube.transparent")
    }

    @Test
    func playerEnvironmentMenuTriggerAndVisibilityState() {
        #expect(PlayerEnvironmentMenuPolicy.triggerDisclosureIconName == "chevron.down")
        #expect(PlayerEnvironmentMenuPolicy.appleEnvironmentMenuBenefit == "System expansion when available")
        #expect(PlayerEnvironmentMenuPolicy.appleEnvironmentMenuBenefit.localizedCaseInsensitiveContains("reflections") == false)
        #expect(PlayerEnvironmentMenuPolicy.appleEnvironmentFallbackBenefit == "Standard window until supported playback is active")
        #expect(PlayerEnvironmentMenuPolicy.appleEnvironmentPendingBenefit == "Expansion queued until supported playback is active")
        #expect(PlayerEnvironmentMenuPolicy.appleEnvironmentChromeStatus == "Apple Environment")
        #expect(PlayerEnvironmentMenuPolicy.appleEnvironmentExpandTitle == "Expand Apple Environment")
        #expect(PlayerEnvironmentMenuPolicy.appleEnvironmentExpandIconName == "arrow.up.left.and.arrow.down.right")
        #expect(PlayerEnvironmentMenuPolicy.compactTriggerMinWidth == 170)
        #expect(PlayerEnvironmentMenuPolicy.compactTriggerMaxWidth == 328)
        #expect(PlayerEnvironmentMenuPolicy.compactTriggerMinHeight == PlayerCinematicChromePolicy.quickActionPillMinHeight)
        #expect(PlayerEnvironmentMenuPolicy.compactTriggerMinimumScaleFactor == 0.88)
        #expect(PlayerEnvironmentMenuPolicy.menuRowMinimumScaleFactor == 0.78)
        #expect(PlayerEnvironmentMenuPolicy.compactTriggerMinWidth < PlayerEnvironmentMenuPolicy.compactTriggerMaxWidth)
        #expect(PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: true) == "mountain.2.fill")
        #expect(PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: false) == "mountain.2")
        #expect(PlayerEnvironmentMenuPolicy.triggerIconName(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == "visionpro")
        #expect(PlayerEnvironmentMenuPolicy.triggerTitle(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == "Apple Environment")
        #expect(PlayerEnvironmentMenuPolicy.triggerTitle(
            selectedAssetID: "env",
            selectedAssetName: "Starlight Cinema",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == "Starlight Cinema")
        #expect(PlayerEnvironmentMenuPolicy.triggerTitle(
            selectedAssetID: "env",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == "Environment Selected")
        #expect(PlayerEnvironmentMenuPolicy.triggerTitle(
            selectedAssetID: "env",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ) == "Environment On")
        #expect(PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: true))
        #expect(!PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: false))
        #expect(PlayerEnvironmentMenuPolicy.showsAppleEnvironmentExpandAction(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ))
        #expect(PlayerEnvironmentMenuPolicy.showsAppleEnvironmentExpandAction(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: true
        ))
        #expect(!PlayerEnvironmentMenuPolicy.showsAppleEnvironmentExpandAction(
            selectedAssetID: "env",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ))
        #expect(!PlayerEnvironmentMenuPolicy.showsAppleEnvironmentExpandAction(
            selectedAssetID: nil,
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true
        ))
        #expect(PlayerEnvironmentMenuPolicy.showsEmptyAssetMessage(assetCount: 0))
        #expect(!PlayerEnvironmentMenuPolicy.showsEmptyAssetMessage(assetCount: 1))
    }

    @Test
    func playerEnvironmentMenuEmptyImportedMessageIgnoresBundledAssets() {
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

        #expect(PlayerEnvironmentMenuPolicy.showsEmptyImportedAssetMessage(assets: []))
        #expect(PlayerEnvironmentMenuPolicy.showsEmptyImportedAssetMessage(assets: [bundled]))
        #expect(!PlayerEnvironmentMenuPolicy.showsEmptyImportedAssetMessage(assets: [bundled, imported]))
    }

    @Test
    func playerEnvironmentMenuEffectiveSelectionFallsBackToActiveCatalogAsset() {
        let appStateAsset = EnvironmentAsset(
            id: "app-state-selection",
            name: "App State Selection",
            sourceType: .imported,
            assetPath: "/tmp/app-state.hdr"
        )
        let inactive = EnvironmentAsset(
            id: "inactive-hdri",
            name: "Inactive HDRI",
            sourceType: .imported,
            assetPath: "/tmp/inactive.hdr"
        )
        let active = EnvironmentAsset(
            id: "catalog-active-hdri",
            name: "Northern Sky",
            sourceType: .imported,
            assetPath: "/tmp/northern.hdr",
            isActive: true
        )

        #expect(PlayerEnvironmentMenuPolicy.effectiveSelectedAssetID(
            appStateSelectedID: " app-state-selection ",
            assets: [appStateAsset, active]
        ) == "app-state-selection")
        #expect(PlayerEnvironmentMenuPolicy.effectiveSelectedAssetID(
            appStateSelectedID: nil,
            assets: [inactive, active]
        ) == "catalog-active-hdri")
        #expect(PlayerEnvironmentMenuPolicy.effectiveSelectedAsset(
            appStateSelectedAsset: nil,
            assets: [inactive, active]
        )?.id == "catalog-active-hdri")
        #expect(PlayerEnvironmentMenuPolicy.effectiveSelectedAssetName(
            appStateSelectedAsset: nil,
            assets: [inactive, active]
        ) == "Northern Sky")
    }

    @Test
    func playerEnvironmentMenuDropsStaleSelectedNameAfterCatalogLoads() {
        let stale = EnvironmentAsset(
            id: "deleted-environment",
            name: "Deleted Environment",
            sourceType: .imported,
            assetPath: "/tmp/deleted.hdr"
        )
        let active = EnvironmentAsset(
            id: "catalog-active-hdri",
            name: "Northern Sky",
            sourceType: .imported,
            assetPath: "/tmp/northern.hdr",
            isActive: true
        )
        let inactive = EnvironmentAsset(
            id: "inactive-hdri",
            name: "Inactive HDRI",
            sourceType: .imported,
            assetPath: "/tmp/inactive.hdr"
        )

        #expect(PlayerEnvironmentMenuPolicy.effectiveSelectedAssetID(
            appStateSelectedID: stale.id,
            assets: [inactive, active]
        ) == active.id)
        #expect(PlayerEnvironmentMenuPolicy.effectiveSelectedAssetName(
            appStateSelectedAsset: stale,
            assets: [inactive, active]
        ) == active.name)
        #expect(PlayerEnvironmentMenuPolicy.effectiveSelectedAssetID(
            appStateSelectedID: stale.id,
            assets: [inactive]
        ) == nil)
        #expect(PlayerEnvironmentMenuPolicy.effectiveSelectedAssetName(
            appStateSelectedAsset: stale,
            assets: [inactive]
        ) == nil)
    }

    @Test
    func playerEnvironmentSurfacesUseEffectiveCatalogSelection() throws {
        let menuSource = try playerEnvironmentMenuPolicyFileContents(
            of: "VPStudio/Views/Windows/Player/PlayerEnvironmentMenu.swift"
        )
        let playerSource = try playerEnvironmentMenuPolicyFileContents(
            of: "VPStudio/Views/Windows/Player/PlayerView.swift"
        )

        #expect(menuSource.contains("private var effectiveSelectedAssetID"))
        #expect(menuSource.contains("private var effectiveSelectedAssetName"))
        #expect(menuSource.contains("PlayerEnvironmentMenuPolicy.triggerIconName(\n                selectedAssetID: selectedAssetID"))
        #expect(menuSource.contains(".accessibilityLabel(PlayerEnvironmentMenuPolicy.triggerTitle("))
        #expect(playerSource.contains("private var effectiveEnvironmentAssetID"))
        #expect(playerSource.contains("selectedAssetID: effectiveEnvironmentAssetID"))
        #expect(playerSource.contains("let selectedAsset = effectiveEnvironmentAsset"))
        #expect(playerSource.contains("PlayerEnvironmentMenuPolicy.effectiveSelectedAssetName"))
    }

    @Test
    func playerEnvironmentChromeStatusSummarizesSelectionAndActiveRoom() {
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: nil,
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == PlayerEnvironmentMenuPolicy.appleEnvironmentChromeStatus)
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: "Cinema Hall",
            selectedAssetID: "cinema-hall",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == "")
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: nil,
            selectedAssetID: "cinema-hall",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == "")
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: nil,
            selectedAssetID: nil,
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true
        ) == "Cinema Active")
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: "Northern Sky",
            selectedAssetID: "northern-sky",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ) == "Northern Sky Active")
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: "HDR Dome",
            selectedAssetID: "hdr-dome",
            activeEnvironment: .hdriSkybox,
            isImmersiveSpaceOpen: true
        ) == "HDR Dome Active")
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: "   ",
            selectedAssetID: "hdr-dome",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ) == "Environment Active")
    }

    @Test
    func playerEnvironmentMenuAppleEnvironmentModeTracksClearedSelection() {
        #expect(PlayerEnvironmentMenuPolicy.usesAppleEnvironmentMode(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ))
        #expect(!PlayerEnvironmentMenuPolicy.usesAppleEnvironmentMode(
            selectedAssetID: "env",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ))
        #expect(!PlayerEnvironmentMenuPolicy.usesAppleEnvironmentMode(
            selectedAssetID: nil,
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true
        ))
        #expect(PlayerEnvironmentMenuPolicy.usesAppleEnvironmentMode(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: true
        ))
    }

    @Test
    func playerEnvironmentMenuCinemaLabelExplainsUnavailablePlayback() {
        let unavailableSpec = PlayerEnvironmentMenuLabelSpec.cinema(
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false,
            canOpenCinema: false
        )
        let activeSpec = PlayerEnvironmentMenuLabelSpec.cinema(
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true,
            canOpenCinema: false
        )

        #expect(unavailableSpec.title == "Cinema Environment")
        #expect(unavailableSpec.subtitle == PlayerCinemaEnvironmentPolicy.unavailableMessage)
        #expect(unavailableSpec.menuTitle == "Cinema Environment - Requires supported playback")
        #expect(unavailableSpec.leadingSystemImage == "theatermasks")
        #expect(activeSpec.subtitle == "Active now")
        #expect(activeSpec.menuTitle == "Cinema Environment")
        #expect(activeSpec.leadingSystemImage == "checkmark")
    }
}

private func playerEnvironmentMenuPolicyFileContents(of relativePath: String) throws -> String {
    let absolutePath = playerEnvironmentMenuPolicyRepoRoot()
        .appendingPathComponent(relativePath)
        .path
    return try String(contentsOfFile: absolutePath, encoding: .utf8)
}

private func playerEnvironmentMenuPolicyRepoRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
        let parent = url.deletingLastPathComponent()
        if parent.path == url.path { break }
        url = parent
    }
    return url
}
#endif
