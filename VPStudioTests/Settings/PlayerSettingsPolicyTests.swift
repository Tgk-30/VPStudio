import Testing
@testable import VPStudio

@Suite("PlayerSettingsPolicy")
struct PlayerSettingsPolicyTests {
    @Test
    func resolvedEngineStrategyFallsBackToCompatibilityForMissingOrUnknownRawValue() {
        #expect(PlayerSettingsPolicy.resolvedEngineStrategy(rawValue: nil) == .compatibility)
        #expect(PlayerSettingsPolicy.resolvedEngineStrategy(rawValue: "") == .compatibility)
        #expect(PlayerSettingsPolicy.resolvedEngineStrategy(rawValue: "turbo") == .compatibility)
    }

    @Test
    func resolvedEngineStrategyPreservesValidRawValue() {
        #expect(PlayerSettingsPolicy.resolvedEngineStrategy(rawValue: PlayerEngineStrategy.adaptive.rawValue) == .adaptive)
        #expect(PlayerSettingsPolicy.resolvedEngineStrategy(rawValue: PlayerEngineStrategy.performance.rawValue) == .performance)
    }

    @Test
    func resolvedHDRPreferenceFallsBackToAutoForMissingOrUnknownRawValue() {
        #expect(PlayerSettingsPolicy.resolvedHDRPreference(rawValue: nil) == .auto)
        #expect(PlayerSettingsPolicy.resolvedHDRPreference(rawValue: "") == .auto)
        #expect(PlayerSettingsPolicy.resolvedHDRPreference(rawValue: "super_hdr") == .auto)
    }

    @Test
    func resolvedHDRPreferencePreservesValidRawValue() {
        #expect(PlayerSettingsPolicy.resolvedHDRPreference(rawValue: HDRPreference.hdr10.rawValue) == .hdr10)
        #expect(PlayerSettingsPolicy.resolvedHDRPreference(rawValue: HDRPreference.dolbyVision.rawValue) == .dolbyVision)
    }

    @Test
    func resolvedNavigationLayoutFallsBackToAppStateLayoutForMissingOrUnknownRawValue() {
        #expect(
            PlayerSettingsPolicy.resolvedNavigationLayout(
                rawValue: nil,
                fallback: .leftSidebar
            ) == .leftSidebar
        )
        #expect(
            PlayerSettingsPolicy.resolvedNavigationLayout(
                rawValue: "top-nav",
                fallback: .bottomTabBar
            ) == .bottomTabBar
        )
    }

    @Test
    func resolvedNavigationLayoutPreservesValidRawValue() {
        #expect(
            PlayerSettingsPolicy.resolvedNavigationLayout(
                rawValue: NavigationLayout.leftSidebar.rawValue,
                fallback: .bottomTabBar
            ) == .leftSidebar
        )
    }

    @Test
    func resolvedRuntimeDiagnosticsUsesStoredValueWhenPresentOtherwiseFallback() {
        #expect(
            PlayerSettingsPolicy.resolvedRuntimeDiagnosticsEnabled(
                storedValue: true,
                fallback: false
            )
        )
        #expect(
            PlayerSettingsPolicy.resolvedRuntimeDiagnosticsEnabled(
                storedValue: false,
                fallback: true
            ) == false
        )
        #expect(
            PlayerSettingsPolicy.resolvedRuntimeDiagnosticsEnabled(
                storedValue: nil,
                fallback: true
            )
        )
    }

    @Test
    func loadedSettingsUsesExpectedFallbacksForMissingOrInvalidStoredValues() {
        let loaded = PlayerSettingsPolicy.loadedSettings(
            preferredQualityRawValue: nil,
            autoPlayStoredValue: nil,
            hardwareDecodingStoredValue: nil,
            playerEngineStrategyRawValue: "turbo",
            externalPlayerTemplateRawValue: "   ",
            preferCachedStoredValue: nil,
            preferAtmosStoredValue: nil,
            hdrPreferenceRawValue: "super_hdr",
            sourceFilterPresetRawValue: nil,
            sourceFilterHideDownloadsStoredValue: nil,
            sourceFilterHideCamStoredValue: nil,
            sourceFilterMinimumSeedersRawValue: nil,
            sourceFilterMaximumSizeGBRawValue: nil,
            sourceFilterMinimumQualityRawValue: nil,
            runtimeDiagnosticsStoredValue: nil,
            runtimeDiagnosticsFallback: true,
            guestModeStoredValue: nil,
            navigationLayoutRawValue: "top-nav",
            navigationFallback: .leftSidebar
        )

        #expect(
            loaded
                == .init(
                    preferredQuality: .hd1080p,
                    autoPlay: true,
                    hardwareDecoding: true,
                    playerEngineStrategy: .compatibility,
                    externalPlayerTemplate: "",
                    preferCached: true,
                    preferAtmos: true,
                    hdrPreference: .auto,
                    sourceFilterOptions: SourceFilterPreset.balanced.defaultOptions,
                    runtimeDiagnosticsEnabled: true,
                    guestModeEnabled: false,
                    navigationLayout: .leftSidebar
                )
        )
    }

    @Test
    func loadedSettingsPreservesValidValuesAndNormalizesTemplate() {
        let loaded = PlayerSettingsPolicy.loadedSettings(
            preferredQualityRawValue: VideoQuality.hd720p.rawValue,
            autoPlayStoredValue: false,
            hardwareDecodingStoredValue: false,
            playerEngineStrategyRawValue: PlayerEngineStrategy.performance.rawValue,
            externalPlayerTemplateRawValue: "  player://open?url={raw_url}  ",
            preferCachedStoredValue: false,
            preferAtmosStoredValue: false,
            hdrPreferenceRawValue: HDRPreference.dolbyVision.rawValue,
            sourceFilterPresetRawValue: SourceFilterPreset.instant.rawValue,
            sourceFilterHideDownloadsStoredValue: false,
            sourceFilterHideCamStoredValue: false,
            sourceFilterMinimumSeedersRawValue: "20",
            sourceFilterMaximumSizeGBRawValue: "5",
            sourceFilterMinimumQualityRawValue: VideoQuality.uhd4k.rawValue,
            runtimeDiagnosticsStoredValue: false,
            runtimeDiagnosticsFallback: true,
            guestModeStoredValue: true,
            navigationLayoutRawValue: NavigationLayout.bottomTabBar.rawValue,
            navigationFallback: .leftSidebar
        )

        #expect(
            loaded
                == .init(
                    preferredQuality: .hd720p,
                    autoPlay: false,
                    hardwareDecoding: false,
                    playerEngineStrategy: .performance,
                    externalPlayerTemplate: "player://open?url={url}",
                    preferCached: false,
                    preferAtmos: false,
                    hdrPreference: .dolbyVision,
                    sourceFilterOptions: SourceFilterPreset.instant.defaultOptions,
                    runtimeDiagnosticsEnabled: false,
                    guestModeEnabled: true,
                    navigationLayout: .bottomTabBar
                )
        )
    }

    @Test
    func persistenceWritesUseExpectedKeysAndValues() {
        #expect(
            PlayerSettingsPolicy.preferredQualityWrite(.hd720p)
                == .string(key: SettingsKeys.preferredQuality, value: VideoQuality.hd720p.rawValue)
        )
        #expect(
            PlayerSettingsPolicy.autoPlayWrite(true)
                == .bool(key: SettingsKeys.autoPlayNext, value: true)
        )
        #expect(
            PlayerSettingsPolicy.hardwareDecodingWrite(false)
                == .bool(key: SettingsKeys.hardwareDecoding, value: false)
        )
        #expect(
            PlayerSettingsPolicy.playerEngineStrategyWrite(.adaptive)
                == .string(key: SettingsKeys.playerEngineStrategy, value: PlayerEngineStrategy.adaptive.rawValue)
        )
        #expect(
            PlayerSettingsPolicy.externalPlayerAppWrite(.custom)
                == .string(key: SettingsKeys.externalPlayerApp, value: ExternalPlayerApp.custom.rawValue)
        )
        #expect(
            PlayerSettingsPolicy.externalPlayerTemplateWrite("  player://open?url={raw_url}  ")
                == .string(
                    key: SettingsKeys.externalPlayerURLTemplate,
                    value: "player://open?url={url}"
                )
        )
        #expect(
            PlayerSettingsPolicy.preferCachedWrite(true)
                == .bool(key: SettingsKeys.preferCachedStreams, value: true)
        )
        #expect(
            PlayerSettingsPolicy.preferAtmosWrite(false)
                == .bool(key: SettingsKeys.preferAtmosAudio, value: false)
        )
        #expect(
            PlayerSettingsPolicy.hdrPreferenceWrite(.hdr10)
                == .string(key: SettingsKeys.preferredHDRFormat, value: HDRPreference.hdr10.rawValue)
        )
        #expect(
            PlayerSettingsPolicy.runtimeDiagnosticsWrite(true)
                == .bool(key: SettingsKeys.runtimeDiagnosticsEnabled, value: true)
        )
        #expect(
            PlayerSettingsPolicy.navigationLayoutWrite(.leftSidebar)
                == .string(key: SettingsKeys.navigationLayout, value: NavigationLayout.leftSidebar.rawValue)
        )
    }

    @Test
    func sourceFilterPersistenceWritesUseExpectedKeysAndValues() {
        #expect(
            PlayerSettingsPolicy.sourceFilterPresetWrite(.instant)
                == .string(key: SettingsKeys.sourceFilterPreset, value: SourceFilterPreset.instant.rawValue)
        )
        #expect(
            PlayerSettingsPolicy.sourceFilterHideDownloadsWrite(true)
                == .bool(key: SettingsKeys.sourceFilterHideDownloads, value: true)
        )
        #expect(
            PlayerSettingsPolicy.sourceFilterHideCamWrite(false)
                == .bool(key: SettingsKeys.sourceFilterHideCam, value: false)
        )
        #expect(
            PlayerSettingsPolicy.sourceFilterMinimumQualityWrite(.hd1080p)
                == .string(key: SettingsKeys.sourceFilterMinimumQuality, value: VideoQuality.hd1080p.rawValue)
        )
        #expect(
            PlayerSettingsPolicy.sourceFilterMinimumQualityWrite(nil)
                == .string(key: SettingsKeys.sourceFilterMinimumQuality, value: nil)
        )
    }

    @Test
    func appStateMirrorUpdateOnlyTracksThePlayerSettingsThatNeedLocalStateMirrors() {
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
        #expect(
            PlayerSettingsPolicy.appStateMirrorUpdate(
                for: PlayerSettingsPolicy.preferAtmosWrite(false)
            ) == nil
        )
    }

    @Test
    func normalizedExternalPlayerTemplateTrimsOrClearsStoredTemplate() {
        #expect(PlayerSettingsPolicy.normalizedExternalPlayerTemplate(nil) == "")
        #expect(PlayerSettingsPolicy.normalizedExternalPlayerTemplate("   ") == "")
        #expect(
            PlayerSettingsPolicy.normalizedExternalPlayerTemplate(
                "  player://open?url={raw_url}  "
            ) == "player://open?url={url}"
        )
    }
}
