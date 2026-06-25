import Testing
@testable import VPStudio

#if os(visionOS)
@Suite("PlayerEnvironmentMenuPolicy Additional Coverage")
struct PlayerEnvironmentMenuPolicyAdditionalCoverageTests {
    @Test
    func cinemaIconNameUsesCheckmarkOnlyForOpenCinemaEnvironment() {
        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: true
            ) == "checkmark"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: false
            ) == "theatermasks"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: .hdriSkybox,
                isImmersiveSpaceOpen: true
            ) == "theatermasks"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ) == "theatermasks"
        )
    }

    @Test
    func menuAssetIconNameUsesSelectionAndSourceSpecificGlyphs() {
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                assetID: "selected",
                selectedAssetID: "selected",
                activeEnvironment: .hdriSkybox,
                sourceType: .bundled
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
    }

    @Test
    func compactAssetIconNameCoversKnownAndUnknownPaths() {
        #expect(PlayerEnvironmentMenuPolicy.compactAssetIconName(forAssetPath: "scene.hdr") == "pano")
        #expect(PlayerEnvironmentMenuPolicy.compactAssetIconName(forAssetPath: "room.usdz") == "cube.transparent")
        #expect(PlayerEnvironmentMenuPolicy.compactAssetIconName(forAssetPath: "scene.unknown") == "cube.transparent")
    }

    @Test
    func triggerAndVisibilityFlagsTrackImmersiveMode() {
        #expect(PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: true) == "mountain.2.fill")
        #expect(PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: false) == "mountain.2")
        #expect(PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: true))
        #expect(!PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: false))
        #expect(PlayerEnvironmentMenuPolicy.showsEmptyAssetMessage(assetCount: 0))
        #expect(!PlayerEnvironmentMenuPolicy.showsEmptyAssetMessage(assetCount: 2))
    }
}
#endif

@Suite("PlayerSettingsPolicy Additional Coverage")
struct PlayerSettingsPolicyAdditionalCoverageTests {
    @Test
    func resolvedPreferredQualityFallsBackTo1080pForMissingOrUnknownRawValues() {
        #expect(PlayerSettingsPolicy.resolvedPreferredQuality(rawValue: nil) == .hd1080p)
        #expect(PlayerSettingsPolicy.resolvedPreferredQuality(rawValue: "invalid-quality") == .hd1080p)
        #expect(PlayerSettingsPolicy.resolvedPreferredQuality(rawValue: VideoQuality.hd720p.rawValue) == .hd720p)
    }

    @Test
    func resolvedToggleUsesStoredValueWhenPresentAndFallbackOtherwise() {
        #expect(PlayerSettingsPolicy.resolvedToggle(storedValue: true, fallback: false))
        #expect(!PlayerSettingsPolicy.resolvedToggle(storedValue: false, fallback: true))
        #expect(PlayerSettingsPolicy.resolvedToggle(storedValue: nil, fallback: true))
        #expect(!PlayerSettingsPolicy.resolvedToggle(storedValue: nil, fallback: false))
    }

    @Test
    func appStateMirrorUpdateIgnoresNonMirroredWritesAndInvalidNavigationValues() {
        #expect(
            PlayerSettingsPolicy.appStateMirrorUpdate(
                for: .bool(key: SettingsKeys.preferAtmosAudio, value: true)
            ) == nil
        )
        #expect(
            PlayerSettingsPolicy.appStateMirrorUpdate(
                for: .string(key: SettingsKeys.navigationLayout, value: nil)
            ) == nil
        )
        #expect(
            PlayerSettingsPolicy.appStateMirrorUpdate(
                for: .string(key: SettingsKeys.navigationLayout, value: "invalid")
            ) == nil
        )
        #expect(
            PlayerSettingsPolicy.appStateMirrorUpdate(
                for: PlayerSettingsPolicy.runtimeDiagnosticsWrite(true)
            ) == .runtimeDiagnosticsEnabled(true)
        )
        #expect(
            PlayerSettingsPolicy.appStateMirrorUpdate(
                for: PlayerSettingsPolicy.navigationLayoutWrite(.leftSidebar)
            ) == .navigationLayout(.leftSidebar)
        )
    }

    @Test
    func loadedSettingsUsesFallbackDefaultsWhenStoredValuesAreMissing() {
        let loaded = PlayerSettingsPolicy.loadedSettings(
            preferredQualityRawValue: nil,
            autoPlayStoredValue: nil,
            hardwareDecodingStoredValue: nil,
            playerEngineStrategyRawValue: nil,
            externalPlayerTemplateRawValue: nil,
            preferCachedStoredValue: nil,
            preferAtmosStoredValue: nil,
            hdrPreferenceRawValue: nil,
            sourceFilterPresetRawValue: nil,
            sourceFilterHideDownloadsStoredValue: nil,
            sourceFilterHideCamStoredValue: nil,
            sourceFilterMinimumSeedersRawValue: nil,
            sourceFilterMaximumSizeGBRawValue: nil,
            sourceFilterMinimumQualityRawValue: nil,
            runtimeDiagnosticsStoredValue: nil,
            runtimeDiagnosticsFallback: false,
            guestModeStoredValue: nil,
            navigationLayoutRawValue: nil,
            navigationFallback: .bottomTabBar
        )

        #expect(
            loaded == .init(
                preferredQuality: .hd1080p,
                autoPlay: true,
                hardwareDecoding: true,
                playerEngineStrategy: .compatibility,
                externalPlayerTemplate: "",
                preferCached: true,
                preferAtmos: true,
                hdrPreference: .auto,
                sourceFilterOptions: SourceFilterPreset.balanced.defaultOptions,
                runtimeDiagnosticsEnabled: false,
                guestModeEnabled: false,
                navigationLayout: .bottomTabBar
            )
        )
    }

    @Test
    func loadedSettingsNormalizesTemplateAndAppliesFallbacks() {
        let loaded = PlayerSettingsPolicy.loadedSettings(
            preferredQualityRawValue: VideoQuality.uhd4k.rawValue,
            autoPlayStoredValue: false,
            hardwareDecodingStoredValue: true,
            playerEngineStrategyRawValue: PlayerEngineStrategy.adaptive.rawValue,
            externalPlayerTemplateRawValue: "  custom://open?url={raw_url}  ",
            preferCachedStoredValue: nil,
            preferAtmosStoredValue: false,
            hdrPreferenceRawValue: HDRPreference.hdr10.rawValue,
            sourceFilterPresetRawValue: SourceFilterPreset.custom.rawValue,
            sourceFilterHideDownloadsStoredValue: true,
            sourceFilterHideCamStoredValue: true,
            sourceFilterMinimumSeedersRawValue: "2",
            sourceFilterMaximumSizeGBRawValue: "10",
            sourceFilterMinimumQualityRawValue: VideoQuality.hd1080p.rawValue,
            runtimeDiagnosticsStoredValue: nil,
            runtimeDiagnosticsFallback: false,
            guestModeStoredValue: false,
            navigationLayoutRawValue: nil,
            navigationFallback: .leftSidebar
        )

        #expect(
            loaded == .init(
                preferredQuality: .uhd4k,
                autoPlay: false,
                hardwareDecoding: true,
                playerEngineStrategy: .adaptive,
                externalPlayerTemplate: "custom://open?url={url}",
                preferCached: true,
                preferAtmos: false,
                hdrPreference: .hdr10,
                sourceFilterOptions: SourceFilterOptions(
                    preset: .custom,
                    hideConfirmedDownloads: true,
                    hideCamSources: true,
                    minimumSeeders: 2,
                    maximumSizeGB: 10,
                    minimumQuality: .hd1080p
                ),
                runtimeDiagnosticsEnabled: false,
                guestModeEnabled: false,
                navigationLayout: .leftSidebar
            )
        )
    }
}
