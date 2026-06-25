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
        #expect(PlayerEnvironmentMenuPolicy.standardRoomIconName(isSelected: false) == "rectangle.dashed")
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
        #expect(selected.title == "Standard Room")
        #expect(selected.leadingSystemImage == "checkmark")
        #expect(selected.subtitle == "Active now")
        #expect(selected.menuTitle == "Standard Room - Active now")
        #expect(unselected.leadingSystemImage == "rectangle.dashed")
        #expect(unselected.subtitle == nil)
        #expect(unselected.menuTitle == "Standard Room")
    }

    @Test
    func playerEnvironmentMenuStateTextDifferentiatesActiveAndSelectedAssets() {
        #expect(PlayerEnvironmentMenuPolicy.standardRoomStateText(
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == "Active now")
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
        #expect(PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: true) == "mountain.2.fill")
        #expect(PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: false) == "mountain.2")
        #expect(PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: true))
        #expect(!PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: false))
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
            assets: [active]
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
    func playerEnvironmentSurfacesUseEffectiveCatalogSelection() throws {
        let menuSource = try playerEnvironmentMenuPolicyFileContents(
            of: "VPStudio/Views/Windows/Player/PlayerEnvironmentMenu.swift"
        )
        let playerSource = try playerEnvironmentMenuPolicyFileContents(
            of: "VPStudio/Views/Windows/Player/PlayerView.swift"
        )

        #expect(menuSource.contains("private var effectiveSelectedAssetID"))
        #expect(playerSource.contains("private var effectiveEnvironmentAssetID"))
        #expect(playerSource.contains("selectedAssetID: effectiveEnvironmentAssetID"))
        #expect(playerSource.contains("let selectedAsset = effectiveEnvironmentAsset"))
        #expect(playerSource.contains("PlayerEnvironmentMenuPolicy.effectiveSelectedAssetName"))
    }

    @Test
    func playerEnvironmentChromeStatusSummarizesSelectionAndActiveRoom() {
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == "Standard Room")
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: "Cinema Hall",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ) == "Cinema Hall Selected")
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: nil,
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true
        ) == "Cinema Active")
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: "Northern Sky",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ) == "Northern Sky Active")
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: "HDR Dome",
            activeEnvironment: .hdriSkybox,
            isImmersiveSpaceOpen: true
        ) == "HDR Dome Active")
        #expect(PlayerEnvironmentMenuPolicy.chromeStatusText(
            selectedAssetName: "   ",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ) == "Environment Active")
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
        #expect(unavailableSpec.menuTitle == "Cinema Environment - \(PlayerCinemaEnvironmentPolicy.unavailableMessage)")
        #expect(unavailableSpec.leadingSystemImage == "theatermasks")
        #expect(activeSpec.subtitle == "Active now")
        #expect(activeSpec.menuTitle == "Cinema Environment - Active now")
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
