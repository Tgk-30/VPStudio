import SwiftUI

// MARK: - Player Settings

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
    @State private var sourceFilterPreset: SourceFilterPreset = .balanced
    @State private var sourceFilterHideDownloads = false
    @State private var sourceFilterHideCam = true
    @State private var sourceFilterMinimumSeeders = 0
    @State private var sourceFilterMaximumSizeGB: Double = 0
    @State private var sourceFilterMinimumQuality: VideoQuality = .unknown
    @State private var runtimeDiagnosticsEnabled = false
    @State private var guestModeEnabled = false
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
            sourceFiltersSection
            privacySection
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
        .onChange(of: sourceFilterPreset) { _, newValue in
            applySourceFilterPreset(newValue)
            saveSourceFilterPreset(newValue)
        }
        .onChange(of: sourceFilterHideDownloads) { _, newValue in
            saveSourceFilterHideDownloads(newValue)
        }
        .onChange(of: sourceFilterHideCam) { _, newValue in
            saveSourceFilterHideCam(newValue)
        }
        .onChange(of: sourceFilterMinimumSeeders) { _, newValue in
            saveSourceFilterMinimumSeeders(newValue)
        }
        .onChange(of: sourceFilterMaximumSizeGB) { _, newValue in
            saveSourceFilterMaximumSize(newValue)
        }
        .onChange(of: sourceFilterMinimumQuality) { _, newValue in
            saveSourceFilterMinimumQuality(newValue == .unknown ? nil : newValue)
        }
        .onChange(of: runtimeDiagnosticsEnabled) { _, newValue in
            saveRuntimeDiagnosticsEnabled(newValue)
        }
        .onChange(of: guestModeEnabled) { _, newValue in
            saveGuestModeEnabled(newValue)
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

    private var sourceFiltersSection: some View {
        Section("Source Filters") {
            Picker("Filter Preset", selection: $sourceFilterPreset) {
                ForEach(SourceFilterPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            Text(sourceFilterPreset.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if sourceFilterPreset == .custom {
                Toggle("Hide Confirmed Downloads", isOn: $sourceFilterHideDownloads)
                Toggle("Hide CAM Sources", isOn: $sourceFilterHideCam)

                Stepper(
                    "Minimum Seeders: \(sourceFilterMinimumSeeders)",
                    value: $sourceFilterMinimumSeeders,
                    in: 0...500,
                    step: 5
                )

                HStack {
                    Text("Maximum Size")
                    Spacer()
                    Text(sourceFilterMaximumSizeGB <= 0 ? "Off" : "\(Int(sourceFilterMaximumSizeGB)) GB")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $sourceFilterMaximumSizeGB, in: 0...SourceFilterOptions.maximumSizeLimitGB, step: 1)
                    .accessibilityLabel("Maximum source size")
                    .accessibilityValue(sourceFilterMaximumSizeGB <= 0 ? "Off" : "\(Int(sourceFilterMaximumSizeGB)) gigabytes")

                Picker("Minimum Quality", selection: $sourceFilterMinimumQuality) {
                    Text("Any").tag(VideoQuality.unknown)
                    Text("720p").tag(VideoQuality.hd720p)
                    Text("1080p").tag(VideoQuality.hd1080p)
                    Text("4K").tag(VideoQuality.uhd4k)
                }
            } else {
                let activeDescriptions = sourceFilterPreset.defaultOptions.activeDescriptions
                if !activeDescriptions.isEmpty {
                    Text(activeDescriptions.joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
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

    private var privacySection: some View {
        Section("Privacy") {
            Toggle("Guest Mode", isOn: $guestModeEnabled)
            Text("Guest Mode pauses local watch-progress saves and Trakt scrobbling for playback sessions.")
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
            sourceFilterPresetRawValue: try? await appState.settingsManager.getString(key: SettingsKeys.sourceFilterPreset),
            sourceFilterHideDownloadsStoredValue: try? await appState.settingsManager.getBool(
                key: SettingsKeys.sourceFilterHideDownloads,
                default: false
            ),
            sourceFilterHideCamStoredValue: try? await appState.settingsManager.getBool(
                key: SettingsKeys.sourceFilterHideCam,
                default: true
            ),
            sourceFilterMinimumSeedersRawValue: try? await appState.settingsManager.getString(
                key: SettingsKeys.sourceFilterMinimumSeeders
            ),
            sourceFilterMaximumSizeGBRawValue: try? await appState.settingsManager.getString(
                key: SettingsKeys.sourceFilterMaximumSizeGB
            ),
            sourceFilterMinimumQualityRawValue: try? await appState.settingsManager.getString(
                key: SettingsKeys.sourceFilterMinimumQuality
            ),
            runtimeDiagnosticsStoredValue: try? await appState.settingsManager.getBool(
                key: SettingsKeys.runtimeDiagnosticsEnabled,
                default: false
            ),
            runtimeDiagnosticsFallback: appState.runtimeDiagnosticsEnabled,
            guestModeStoredValue: try? await appState.settingsManager.getBool(
                key: SettingsKeys.guestModeEnabled,
                default: false
            ),
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
        sourceFilterPreset = loadedSettings.sourceFilterOptions.preset
        sourceFilterHideDownloads = loadedSettings.sourceFilterOptions.hideConfirmedDownloads
        sourceFilterHideCam = loadedSettings.sourceFilterOptions.hideCamSources
        sourceFilterMinimumSeeders = loadedSettings.sourceFilterOptions.minimumSeeders
        sourceFilterMaximumSizeGB = loadedSettings.sourceFilterOptions.maximumSizeGB ?? 0
        sourceFilterMinimumQuality = loadedSettings.sourceFilterOptions.minimumQuality ?? .unknown
        runtimeDiagnosticsEnabled = loadedSettings.runtimeDiagnosticsEnabled
        guestModeEnabled = loadedSettings.guestModeEnabled
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

    private func saveSourceFilterPreset(_ value: SourceFilterPreset) {
        persist(PlayerSettingsPolicy.sourceFilterPresetWrite(value))
    }

    private func saveSourceFilterHideDownloads(_ value: Bool) {
        persist(PlayerSettingsPolicy.sourceFilterHideDownloadsWrite(value))
    }

    private func saveSourceFilterHideCam(_ value: Bool) {
        persist(PlayerSettingsPolicy.sourceFilterHideCamWrite(value))
    }

    private func saveSourceFilterMinimumSeeders(_ value: Int) {
        persist(PlayerSettingsPolicy.sourceFilterMinimumSeedersWrite(value))
    }

    private func saveSourceFilterMaximumSize(_ value: Double) {
        persist(PlayerSettingsPolicy.sourceFilterMaximumSizeWrite(value))
    }

    private func saveSourceFilterMinimumQuality(_ value: VideoQuality?) {
        persist(PlayerSettingsPolicy.sourceFilterMinimumQualityWrite(value))
    }

    private func applySourceFilterPreset(_ preset: SourceFilterPreset) {
        guard preset != .custom else { return }
        let options = preset.defaultOptions
        sourceFilterHideDownloads = options.hideConfirmedDownloads
        sourceFilterHideCam = options.hideCamSources
        sourceFilterMinimumSeeders = options.minimumSeeders
        sourceFilterMaximumSizeGB = options.maximumSizeGB ?? 0
        sourceFilterMinimumQuality = options.minimumQuality ?? .unknown
    }

    private func saveRuntimeDiagnosticsEnabled(_ value: Bool) {
        persist(PlayerSettingsPolicy.runtimeDiagnosticsWrite(value))
    }

    private func saveGuestModeEnabled(_ value: Bool) {
        persist(PlayerSettingsPolicy.guestModeWrite(value))
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
