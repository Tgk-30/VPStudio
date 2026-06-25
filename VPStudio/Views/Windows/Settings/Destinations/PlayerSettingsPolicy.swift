enum PlayerSettingsPolicy {
    struct LoadedSettings: Equatable {
        let preferredQuality: VideoQuality
        let autoPlay: Bool
        let hardwareDecoding: Bool
        let playerEngineStrategy: PlayerEngineStrategy
        let externalPlayerTemplate: String
        let preferCached: Bool
        let preferAtmos: Bool
        let hdrPreference: HDRPreference
        let sourceFilterOptions: SourceFilterOptions
        let runtimeDiagnosticsEnabled: Bool
        let guestModeEnabled: Bool
        let navigationLayout: NavigationLayout
    }

    enum PersistenceWrite: Equatable {
        case bool(key: String, value: Bool)
        case string(key: String, value: String?)
    }

    enum AppStateMirrorUpdate: Equatable {
        case runtimeDiagnosticsEnabled(Bool)
        case navigationLayout(NavigationLayout)
    }

    static func resolvedEngineStrategy(rawValue: String?) -> PlayerEngineStrategy {
        guard let rawValue else { return .compatibility }
        return PlayerEngineStrategy(rawValue: rawValue) ?? .compatibility
    }

    static func resolvedPreferredQuality(rawValue: String?) -> VideoQuality {
        guard let rawValue else { return .hd1080p }
        return VideoQuality(rawValue: rawValue) ?? .hd1080p
    }

    static func resolvedHDRPreference(rawValue: String?) -> HDRPreference {
        guard let rawValue else { return .auto }
        return HDRPreference(rawValue: rawValue) ?? .auto
    }

    static func resolvedNavigationLayout(rawValue: String?, fallback: NavigationLayout) -> NavigationLayout {
        guard let rawValue else { return fallback }
        return NavigationLayout(rawValue: rawValue) ?? fallback
    }

    static func resolvedToggle(storedValue: Bool?, fallback: Bool) -> Bool {
        storedValue ?? fallback
    }

    static func resolvedRuntimeDiagnosticsEnabled(storedValue: Bool?, fallback: Bool) -> Bool {
        resolvedToggle(storedValue: storedValue, fallback: fallback)
    }

    static func normalizedExternalPlayerTemplate(_ template: String?) -> String {
        ExternalPlayerRouting.normalizedCustomTemplate(template) ?? ""
    }

    static func loadedSettings(
        preferredQualityRawValue: String?,
        autoPlayStoredValue: Bool?,
        hardwareDecodingStoredValue: Bool?,
        playerEngineStrategyRawValue: String?,
        externalPlayerTemplateRawValue: String?,
        preferCachedStoredValue: Bool?,
        preferAtmosStoredValue: Bool?,
        hdrPreferenceRawValue: String?,
        sourceFilterPresetRawValue: String?,
        sourceFilterHideDownloadsStoredValue: Bool?,
        sourceFilterHideCamStoredValue: Bool?,
        sourceFilterMinimumSeedersRawValue: String?,
        sourceFilterMaximumSizeGBRawValue: String?,
        sourceFilterMinimumQualityRawValue: String?,
        runtimeDiagnosticsStoredValue: Bool?,
        runtimeDiagnosticsFallback: Bool,
        guestModeStoredValue: Bool?,
        navigationLayoutRawValue: String?,
        navigationFallback: NavigationLayout
    ) -> LoadedSettings {
        LoadedSettings(
            preferredQuality: resolvedPreferredQuality(rawValue: preferredQualityRawValue),
            autoPlay: resolvedToggle(storedValue: autoPlayStoredValue, fallback: true),
            hardwareDecoding: resolvedToggle(storedValue: hardwareDecodingStoredValue, fallback: true),
            playerEngineStrategy: resolvedEngineStrategy(rawValue: playerEngineStrategyRawValue),
            externalPlayerTemplate: normalizedExternalPlayerTemplate(externalPlayerTemplateRawValue),
            preferCached: resolvedToggle(storedValue: preferCachedStoredValue, fallback: true),
            preferAtmos: resolvedToggle(storedValue: preferAtmosStoredValue, fallback: true),
            hdrPreference: resolvedHDRPreference(rawValue: hdrPreferenceRawValue),
            sourceFilterOptions: SourceFilterOptions.fromStoredValues(
                presetRawValue: sourceFilterPresetRawValue,
                hideConfirmedDownloads: sourceFilterHideDownloadsStoredValue,
                hideCamSources: sourceFilterHideCamStoredValue,
                minimumSeedersRawValue: sourceFilterMinimumSeedersRawValue,
                maximumSizeGBRawValue: sourceFilterMaximumSizeGBRawValue,
                minimumQualityRawValue: sourceFilterMinimumQualityRawValue
            ),
            runtimeDiagnosticsEnabled: resolvedRuntimeDiagnosticsEnabled(
                storedValue: runtimeDiagnosticsStoredValue,
                fallback: runtimeDiagnosticsFallback
            ),
            guestModeEnabled: resolvedToggle(storedValue: guestModeStoredValue, fallback: false),
            navigationLayout: resolvedNavigationLayout(
                rawValue: navigationLayoutRawValue,
                fallback: navigationFallback
            )
        )
    }

    static func preferredQualityWrite(_ value: VideoQuality) -> PersistenceWrite {
        .string(key: SettingsKeys.preferredQuality, value: value.rawValue)
    }

    static func autoPlayWrite(_ value: Bool) -> PersistenceWrite {
        .bool(key: SettingsKeys.autoPlayNext, value: value)
    }

    static func hardwareDecodingWrite(_ value: Bool) -> PersistenceWrite {
        .bool(key: SettingsKeys.hardwareDecoding, value: value)
    }

    static func playerEngineStrategyWrite(_ value: PlayerEngineStrategy) -> PersistenceWrite {
        .string(key: SettingsKeys.playerEngineStrategy, value: value.rawValue)
    }

    static func externalPlayerAppWrite(_ value: ExternalPlayerApp) -> PersistenceWrite {
        .string(key: SettingsKeys.externalPlayerApp, value: value.rawValue)
    }

    static func externalPlayerTemplateWrite(_ value: String) -> PersistenceWrite {
        .string(
            key: SettingsKeys.externalPlayerURLTemplate,
            value: ExternalPlayerRouting.normalizedCustomTemplate(value)
        )
    }

    static func preferCachedWrite(_ value: Bool) -> PersistenceWrite {
        .bool(key: SettingsKeys.preferCachedStreams, value: value)
    }

    static func preferAtmosWrite(_ value: Bool) -> PersistenceWrite {
        .bool(key: SettingsKeys.preferAtmosAudio, value: value)
    }

    static func hdrPreferenceWrite(_ value: HDRPreference) -> PersistenceWrite {
        .string(key: SettingsKeys.preferredHDRFormat, value: value.rawValue)
    }

    static func sourceFilterPresetWrite(_ value: SourceFilterPreset) -> PersistenceWrite {
        .string(key: SettingsKeys.sourceFilterPreset, value: value.rawValue)
    }

    static func sourceFilterHideDownloadsWrite(_ value: Bool) -> PersistenceWrite {
        .bool(key: SettingsKeys.sourceFilterHideDownloads, value: value)
    }

    static func sourceFilterHideCamWrite(_ value: Bool) -> PersistenceWrite {
        .bool(key: SettingsKeys.sourceFilterHideCam, value: value)
    }

    static func sourceFilterMinimumSeedersWrite(_ value: Int) -> PersistenceWrite {
        .string(key: SettingsKeys.sourceFilterMinimumSeeders, value: String(max(0, min(500, value))))
    }

    static func sourceFilterMaximumSizeWrite(_ value: Double) -> PersistenceWrite {
        let clamped = max(0, min(SourceFilterOptions.maximumSizeLimitGB, value))
        return .string(
            key: SettingsKeys.sourceFilterMaximumSizeGB,
            value: clamped > 0 ? String(Int(clamped.rounded())) : nil
        )
    }

    static func sourceFilterMinimumQualityWrite(_ value: VideoQuality?) -> PersistenceWrite {
        .string(key: SettingsKeys.sourceFilterMinimumQuality, value: value?.rawValue)
    }

    static func runtimeDiagnosticsWrite(_ value: Bool) -> PersistenceWrite {
        .bool(key: SettingsKeys.runtimeDiagnosticsEnabled, value: value)
    }

    static func guestModeWrite(_ value: Bool) -> PersistenceWrite {
        .bool(key: SettingsKeys.guestModeEnabled, value: value)
    }

    static func navigationLayoutWrite(_ value: NavigationLayout) -> PersistenceWrite {
        .string(key: SettingsKeys.navigationLayout, value: value.rawValue)
    }

    static func appStateMirrorUpdate(for write: PersistenceWrite) -> AppStateMirrorUpdate? {
        switch write {
        case .bool(let key, let value) where key == SettingsKeys.runtimeDiagnosticsEnabled:
            return .runtimeDiagnosticsEnabled(value)
        case .string(let key, let value) where key == SettingsKeys.navigationLayout:
            guard let value, let navigationLayout = NavigationLayout(rawValue: value) else { return nil }
            return .navigationLayout(navigationLayout)
        default:
            return nil
        }
    }
}
