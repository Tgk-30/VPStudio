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
    func playerEnvironmentMenuAssetIconsDistinguishActiveBundledAndImportedAssets() {
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                isActive: true,
                sourceType: .imported
            ) == "checkmark"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                isActive: false,
                sourceType: .bundled
            ) == "circle.fill"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                isActive: false,
                sourceType: .imported
            ) == "pano"
        )
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
}
#endif
