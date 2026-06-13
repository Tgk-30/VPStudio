import SwiftUI

// MARK: - Player Settings

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
        let runtimeDiagnosticsEnabled: Bool
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
        runtimeDiagnosticsStoredValue: Bool?,
        runtimeDiagnosticsFallback: Bool,
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
            runtimeDiagnosticsEnabled: resolvedRuntimeDiagnosticsEnabled(
                storedValue: runtimeDiagnosticsStoredValue,
                fallback: runtimeDiagnosticsFallback
            ),
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

    static func runtimeDiagnosticsWrite(_ value: Bool) -> PersistenceWrite {
        .bool(key: SettingsKeys.runtimeDiagnosticsEnabled, value: value)
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

struct PlayerSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var preferredQuality: VideoQuality = .hd1080p
    @State private var autoPlay = true
    @State private var hardwareDecoding = true
    @State private var playerEngineStrategy: PlayerEngineStrategy = .compatibility
    @State private var externalPlayerApp: ExternalPlayerApp = .builtIn
    @State private var externalPlayerTemplate = ""
    @State private var preferCached = true
    @State private var preferAtmos = true
    @State private var hdrPreference: HDRPreference = .auto
    @State private var runtimeDiagnosticsEnabled = false
    @State private var navigationLayout: NavigationLayout = .bottomTabBar
    @State private var surfaceError: AppError?
    private let disablesAutomaticTasks: Bool

    init(
        initialPreferredQuality: VideoQuality = .hd1080p,
        initialAutoPlay: Bool = true,
        initialHardwareDecoding: Bool = true,
        initialPlayerEngineStrategy: PlayerEngineStrategy = .compatibility,
        initialExternalPlayerApp: ExternalPlayerApp = .builtIn,
        initialExternalPlayerTemplate: String = "",
        initialPreferCached: Bool = true,
        initialPreferAtmos: Bool = true,
        initialHDRPreference: HDRPreference = .auto,
        initialRuntimeDiagnosticsEnabled: Bool = false,
        initialNavigationLayout: NavigationLayout = .bottomTabBar,
        initialSurfaceError: AppError? = nil,
        disablesAutomaticTasks: Bool = false
    ) {
        _preferredQuality = State(initialValue: initialPreferredQuality)
        _autoPlay = State(initialValue: initialAutoPlay)
        _hardwareDecoding = State(initialValue: initialHardwareDecoding)
        _playerEngineStrategy = State(initialValue: initialPlayerEngineStrategy)
        _externalPlayerApp = State(initialValue: initialExternalPlayerApp)
        _externalPlayerTemplate = State(initialValue: initialExternalPlayerTemplate)
        _preferCached = State(initialValue: initialPreferCached)
        _preferAtmos = State(initialValue: initialPreferAtmos)
        _hdrPreference = State(initialValue: initialHDRPreference)
        _runtimeDiagnosticsEnabled = State(initialValue: initialRuntimeDiagnosticsEnabled)
        _navigationLayout = State(initialValue: initialNavigationLayout)
        _surfaceError = State(initialValue: initialSurfaceError)
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    var body: some View {
        Form {
            if let surfaceError {
                Section {
                    SettingsErrorBanner(error: surfaceError)
                }
            }

            quickStartSection
            navigationSection
            qualitySection
            playbackSection
            engineSection
            playerAppSection
            highFidelitySection
            diagnosticsSection
        }
        .navigationTitle("Playback")
        .task {
            guard !disablesAutomaticTasks else { return }
            await loadSettings()
        }
        .onChange(of: preferredQuality) { _, newValue in
            savePreferredQuality(newValue)
        }
        .onChange(of: autoPlay) { _, newValue in
            saveAutoPlay(newValue)
        }
        .onChange(of: hardwareDecoding) { _, newValue in
            saveHardwareDecoding(newValue)
        }
        .onChange(of: playerEngineStrategy) { _, newValue in
            savePlayerEngineStrategy(newValue)
        }
        .onChange(of: externalPlayerApp) { _, newValue in
            saveExternalPlayerApp(newValue)
        }
        .onChange(of: externalPlayerTemplate) { _, newValue in
            saveExternalPlayerTemplate(newValue)
        }
        .onChange(of: preferCached) { _, newValue in
            savePreferCached(newValue)
        }
        .onChange(of: preferAtmos) { _, newValue in
            savePreferAtmos(newValue)
        }
        .onChange(of: hdrPreference) { _, newValue in
            saveHDRPreference(newValue)
        }
        .onChange(of: runtimeDiagnosticsEnabled) { _, newValue in
            saveRuntimeDiagnosticsEnabled(newValue)
        }
        .onChange(of: navigationLayout) { _, newValue in
            saveNavigationLayout(newValue)
        }
    }

    private var quickStartSection: some View {
        Section("Quick Start") {
            Text("Recommended defaults: Engine Mode = Compatibility, Prefer Cached Streams = On, Quality = 1080p.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("If playback fails, switch Engine Mode to Adaptive and retry the same title.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var navigationSection: some View {
        Section("Navigation") {
            Picker("Layout", selection: $navigationLayout) {
                ForEach(NavigationLayout.allCases, id: \.self) { layout in
                    Text(layout.displayName).tag(layout)
                }
            }

            Text("Choose between a bottom tab bar or a left sidebar for navigation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var qualitySection: some View {
        Section("Quality") {
            Picker("Preferred Quality", selection: $preferredQuality) {
                Text("4K").tag(VideoQuality.uhd4k)
                Text("1080p").tag(VideoQuality.hd1080p)
                Text("720p").tag(VideoQuality.hd720p)
            }

            Toggle("Prefer Cached Streams", isOn: $preferCached)
        }
    }

    private var playbackSection: some View {
        Section("Playback") {
            Toggle("Auto-Play", isOn: $autoPlay)
            Toggle("Hardware Decoding", isOn: $hardwareDecoding)
        }
    }

    private var engineSection: some View {
        Section("Engine") {
            Picker("Player Engine Mode", selection: $playerEngineStrategy) {
                ForEach(PlayerEngineStrategy.allCases) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }

            Text(playerEngineStrategy.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Tip: Compatibility is the safest. Adaptive is best when you want automatic fallback between engines.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var playerAppSection: some View {
        Section("Player App") {
            Picker("Open Streams With", selection: $externalPlayerApp) {
                ForEach(ExternalPlayerApp.allCases) { app in
                    Text(app.displayName).tag(app)
                }
            }

            if externalPlayerApp == .custom {
                TextField(
                    "Custom URL Template",
                    text: $externalPlayerTemplate,
                    prompt: Text("player://open?url={url}")
                )

                switch ExternalPlayerRouting.validationResult(forCustomTemplate: externalPlayerTemplate) {
                case .empty:
                    EmptyView()
                case .valid:
                    Text("Use {url} for the stream URL. VPStudio percent-encodes it before launch.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                case .invalid(let message):
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Text(externalPlayerApp.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Custom templates should include {url}. Example: vlc-x-callback://x-callback-url/stream?url={url}")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var highFidelitySection: some View {
        Section("High-Fidelity AV") {
            Toggle("Prefer Atmos / Spatial Audio", isOn: $preferAtmos)

            Picker("Preferred HDR", selection: $hdrPreference) {
                ForEach(HDRPreference.allCases, id: \.self) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }

            Text("Playback automatically falls back when stream profile exceeds runtime capabilities.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            Toggle("Enable Runtime Diagnostics", isOn: $runtimeDiagnosticsEnabled)
            Text("When enabled, the app logs resident-memory snapshots around tab switches, library reloads, and player lifecycle transitions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func loadSettings() async {
        let externalPreference = await ExternalPlayerSettings.loadPreference(from: appState.settingsManager)
        let loadedSettings = PlayerSettingsPolicy.loadedSettings(
            preferredQualityRawValue: try? await appState.settingsManager.getString(key: SettingsKeys.preferredQuality),
            autoPlayStoredValue: try? await appState.settingsManager.getBool(key: SettingsKeys.autoPlayNext, default: true),
            hardwareDecodingStoredValue: try? await appState.settingsManager.getBool(key: SettingsKeys.hardwareDecoding, default: true),
            playerEngineStrategyRawValue: try? await appState.settingsManager.getString(key: SettingsKeys.playerEngineStrategy),
            externalPlayerTemplateRawValue: externalPreference.customURLTemplate,
            preferCachedStoredValue: try? await appState.settingsManager.getBool(key: SettingsKeys.preferCachedStreams, default: true),
            preferAtmosStoredValue: try? await appState.settingsManager.getBool(key: SettingsKeys.preferAtmosAudio, default: true),
            hdrPreferenceRawValue: try? await appState.settingsManager.getString(key: SettingsKeys.preferredHDRFormat),
            runtimeDiagnosticsStoredValue: try? await appState.settingsManager.getBool(
                key: SettingsKeys.runtimeDiagnosticsEnabled,
                default: false
            ),
            runtimeDiagnosticsFallback: appState.runtimeDiagnosticsEnabled,
            navigationLayoutRawValue: try? await appState.settingsManager.getString(key: SettingsKeys.navigationLayout),
            navigationFallback: appState.navigationLayout
        )

        preferredQuality = loadedSettings.preferredQuality
        autoPlay = loadedSettings.autoPlay
        hardwareDecoding = loadedSettings.hardwareDecoding
        playerEngineStrategy = loadedSettings.playerEngineStrategy
        externalPlayerApp = externalPreference.app
        externalPlayerTemplate = loadedSettings.externalPlayerTemplate
        preferCached = loadedSettings.preferCached
        preferAtmos = loadedSettings.preferAtmos
        hdrPreference = loadedSettings.hdrPreference
        runtimeDiagnosticsEnabled = loadedSettings.runtimeDiagnosticsEnabled
        appState.runtimeDiagnosticsEnabled = runtimeDiagnosticsEnabled
        navigationLayout = loadedSettings.navigationLayout
        appState.navigationLayout = navigationLayout
    }

    private func savePreferredQuality(_ value: VideoQuality) {
        persist(PlayerSettingsPolicy.preferredQualityWrite(value))
    }

    private func saveAutoPlay(_ value: Bool) {
        persist(PlayerSettingsPolicy.autoPlayWrite(value))
    }

    private func saveHardwareDecoding(_ value: Bool) {
        persist(PlayerSettingsPolicy.hardwareDecodingWrite(value))
    }

    private func savePlayerEngineStrategy(_ value: PlayerEngineStrategy) {
        persist(PlayerSettingsPolicy.playerEngineStrategyWrite(value))
    }

    private func saveExternalPlayerApp(_ value: ExternalPlayerApp) {
        persist(PlayerSettingsPolicy.externalPlayerAppWrite(value))
    }

    private func saveExternalPlayerTemplate(_ value: String) {
        persist(PlayerSettingsPolicy.externalPlayerTemplateWrite(value))
    }

    private func savePreferCached(_ value: Bool) {
        persist(PlayerSettingsPolicy.preferCachedWrite(value))
    }

    private func savePreferAtmos(_ value: Bool) {
        persist(PlayerSettingsPolicy.preferAtmosWrite(value))
    }

    private func saveHDRPreference(_ value: HDRPreference) {
        persist(PlayerSettingsPolicy.hdrPreferenceWrite(value))
    }

    private func saveRuntimeDiagnosticsEnabled(_ value: Bool) {
        persist(PlayerSettingsPolicy.runtimeDiagnosticsWrite(value))
    }

    private func saveNavigationLayout(_ value: NavigationLayout) {
        persist(PlayerSettingsPolicy.navigationLayoutWrite(value))
    }

    private func persist(_ write: PlayerSettingsPolicy.PersistenceWrite) {
        Task {
            do {
                try await performPersistence(write)
                await MainActor.run {
                    applyAppStateMirrorUpdate(for: write)
                    surfaceError = nil
                }
            } catch {
                await MainActor.run {
                    surfaceError = AppError(error)
                }
            }
        }
    }

    private func performPersistence(_ write: PlayerSettingsPolicy.PersistenceWrite) async throws {
        switch write {
        case .bool(let key, let value):
            try await appState.settingsManager.setBool(key: key, value: value)
        case .string(let key, let value):
            try await appState.settingsManager.setString(key: key, value: value)
        }
    }

    private func applyAppStateMirrorUpdate(for write: PlayerSettingsPolicy.PersistenceWrite) {
        guard let update = PlayerSettingsPolicy.appStateMirrorUpdate(for: write) else { return }

        switch update {
        case .runtimeDiagnosticsEnabled(let value):
            appState.runtimeDiagnosticsEnabled = value
        case .navigationLayout(let value):
            appState.navigationLayout = value
        }
    }

    private func persistBoolSetting(key: String, value: Bool) {
        persist(.bool(key: key, value: value))
    }

    private func persistStringSetting(key: String, value: String?) {
        persist(.string(key: key, value: value))
    }
}
