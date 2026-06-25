import Testing
@testable import VPStudio

@Suite("Premium Settings Policies")
struct PremiumSettingsPolicyTests {
    @Test
    func playerSettingsLoadsSourceFiltersAndGuestMode() {
        let loaded = PlayerSettingsPolicy.loadedSettings(
            preferredQualityRawValue: VideoQuality.uhd4k.rawValue,
            autoPlayStoredValue: true,
            hardwareDecodingStoredValue: true,
            playerEngineStrategyRawValue: PlayerEngineStrategy.performance.rawValue,
            externalPlayerTemplateRawValue: nil,
            preferCachedStoredValue: true,
            preferAtmosStoredValue: true,
            hdrPreferenceRawValue: HDRPreference.auto.rawValue,
            sourceFilterPresetRawValue: SourceFilterPreset.custom.rawValue,
            sourceFilterHideDownloadsStoredValue: true,
            sourceFilterHideCamStoredValue: false,
            sourceFilterMinimumSeedersRawValue: "7",
            sourceFilterMaximumSizeGBRawValue: "42",
            sourceFilterMinimumQualityRawValue: VideoQuality.hd1080p.rawValue,
            runtimeDiagnosticsStoredValue: false,
            runtimeDiagnosticsFallback: true,
            guestModeStoredValue: true,
            navigationLayoutRawValue: NavigationLayout.leftSidebar.rawValue,
            navigationFallback: .bottomTabBar
        )

        #expect(loaded.sourceFilterOptions.preset == .custom)
        #expect(loaded.sourceFilterOptions.hideConfirmedDownloads)
        #expect(loaded.sourceFilterOptions.hideCamSources == false)
        #expect(loaded.sourceFilterOptions.minimumSeeders == 7)
        #expect(loaded.sourceFilterOptions.maximumSizeGB == 42)
        #expect(loaded.sourceFilterOptions.minimumQuality == .hd1080p)
        #expect(loaded.guestModeEnabled)
    }

    @Test
    func playerSettingsSourceFilterWritesNormalizeValues() {
        #expect(PlayerSettingsPolicy.sourceFilterMinimumSeedersWrite(-4) == .string(
            key: SettingsKeys.sourceFilterMinimumSeeders,
            value: "0"
        ))
        #expect(PlayerSettingsPolicy.sourceFilterMaximumSizeWrite(0) == .string(
            key: SettingsKeys.sourceFilterMaximumSizeGB,
            value: nil
        ))
        #expect(PlayerSettingsPolicy.sourceFilterMaximumSizeWrite(251) == .string(
            key: SettingsKeys.sourceFilterMaximumSizeGB,
            value: "250"
        ))
        #expect(PlayerSettingsPolicy.guestModeWrite(true) == .bool(
            key: SettingsKeys.guestModeEnabled,
            value: true
        ))
    }

    @Test
    func subtitleOffsetClampsAndFormatsValues() {
        #expect(SubtitleSettingsPolicy.resolvedOffsetMilliseconds(nil) == 0)
        #expect(SubtitleSettingsPolicy.resolvedOffsetMilliseconds("8000") == 5_000)
        #expect(SubtitleSettingsPolicy.resolvedOffsetMilliseconds("-8000") == -5_000)
        #expect(SubtitleSettingsPolicy.formattedOffset(0) == "In Sync")
        #expect(SubtitleSettingsPolicy.formattedOffset(1_250) == "1.2s late")
        #expect(SubtitleSettingsPolicy.formattedOffset(-2_500) == "2.5s early")
    }
}
