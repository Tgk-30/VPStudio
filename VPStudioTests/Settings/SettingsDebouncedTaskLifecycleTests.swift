import Foundation
import Testing
@testable import VPStudio

@Suite("Settings Debounced Task Lifecycle")
struct SettingsDebouncedTaskLifecycleTests {
    @Test
    func aiSettingsCancelsDebouncedSaveTasksOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")
        #expect(source.contains(".onDisappear"))
        #expect(source.contains("flushPendingCloudKeySaves()"))
        #expect(source.contains("anthropicSaveTask?.cancel()"))
        #expect(source.contains("openAISaveTask?.cancel()"))
        #expect(source.contains("feedbackReloadTask?.cancel()"))
        #expect(source.contains("settingsReloadTask?.cancel()"))
        #expect(source.contains("modelPresetSaveTasks.removeAll()"))
    }

    @Test
    func aiSettingsFlushesOnlyPendingCloudKeySavesOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")
        let body = try section(
            from: "private func flushPendingCloudKeySaves()",
            to: "    @MainActor\n    private func scheduleCloudKeySave",
            in: source
        )

        #expect(body.contains("let shouldFlushAnthropic = anthropicSaveTask != nil"))
        #expect(body.contains("let shouldFlushOpenAI = openAISaveTask != nil"))
        #expect(body.contains("let shouldFlushGemini = geminiSaveTask != nil"))
        #expect(body.contains("let shouldFlushOpenRouter = openRouterSaveTask != nil"))
        #expect(body.contains("let shouldFlushMistral = mistralSaveTask != nil"))
        #expect(body.contains("let shouldFlushMiniMax = minimaxSaveTask != nil"))
        #expect(body.contains("if shouldFlushAnthropic"))
        #expect(body.contains("if shouldFlushMiniMax"))
    }

    @Test
    func aiSettingsCoalescesTasteProfileReloadNotifications() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")
        #expect(source.contains("@State private var feedbackReloadTask: Task<Void, Never>?"))
        #expect(source.contains(".onReceive(NotificationCenter.default.publisher(for: .tasteProfileDidChange))"))
        #expect(source.contains("feedbackReloadTask?.cancel()"))
        #expect(source.contains("feedbackReloadTask = Task { await loadFeedbackState() }"))
    }

    @Test
    func aiSettingsCoalescesProviderModelRefreshesAndIgnoresCanceledResults() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")
        let selectedProviderBody = try section(
            from: ".onChange(of: selectedProvider)",
            to: ".onChange(of: preferredProvider)",
            in: source
        )
        let refreshBody = try section(
            from: "private func refreshModels(for provider: AIProviderKind) async",
            to: "    @MainActor\n    private func scheduleModelRefresh",
            in: source
        )
        let scheduleBody = try section(
            from: "private func scheduleModelRefresh(for provider: AIProviderKind)",
            to: "    // MARK: - Usage & Costs Section",
            in: source
        )

        #expect(source.contains("@State private var modelRefreshTask: Task<Void, Never>?"))
        #expect(selectedProviderBody.contains("scheduleModelRefresh(for: newValue)"))
        #expect(scheduleBody.contains("modelRefreshTask?.cancel()"))
        #expect(scheduleBody.contains("modelRefreshTask = Task { await refreshModels(for: provider) }"))
        #expect(refreshBody.contains("guard !Task.isCancelled else { return }"))
        #expect(refreshBody.contains("if !Task.isCancelled"))
        #expect(source.contains("modelRefreshTask?.cancel()"))
        #expect(source.contains("modelRefreshTask = nil"))
    }

    @Test
    func aiSettingsDebouncedCloudKeySaveHandlesCancellationAndSurfacesRealErrors() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")
        let functionRange = try requiredRange(of: "private func scheduleCloudKeySave(", in: source)
        let body = String(source[functionRange.lowerBound...])

        #expect(body.contains("try await Task.sleep(for: .milliseconds(500))"))
        #expect(body.contains("guard !Task.isCancelled else { return }"))
        #expect(body.contains("catch is CancellationError"))
        #expect(body.contains("surfaceError = AppError(error)"))
    }

    @Test
    func aiSettingsRefreshesWhenSettingsOrResetNotificationsArrive() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")
        let settingsBody = try section(
            from: ".onReceive(NotificationCenter.default.publisher(for: .settingsDidChange))",
            to: ".onReceive(NotificationCenter.default.publisher(for: .appDidResetAllData))",
            in: source
        )
        let resetBody = try section(
            from: ".onReceive(NotificationCenter.default.publisher(for: .appDidResetAllData))",
            to: ".onDisappear",
            in: source
        )
        #expect(settingsBody.contains("guard !disablesAutomaticTasks else { return }"))
        #expect(settingsBody.contains("schedulePersistedStateReload(refreshRemoteModels: false)"))
        #expect(resetBody.contains("guard !disablesAutomaticTasks else { return }"))
        #expect(resetBody.contains("schedulePersistedStateReload(refreshRemoteModels: false)"))
    }

    @Test
    func aiSettingsCoalescesModelPresetSavesBySettingKey() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")
        let formBody = try section(
            from: "private var formWithKeyHandlers: some View",
            to: ".onChange(of: discoverAIEnabled)",
            in: source
        )
        let helperBody = try section(
            from: "private func scheduleModelPresetSave(key: String, value: String)",
            to: "    @MainActor\n    private func persistCloudKey",
            in: source
        )

        #expect(source.contains("@State private var modelPresetSaveTasks: [String: Task<Void, Never>] = [:]"))
        #expect(source.contains("scheduleModelPresetSave(key: SettingsKeys.localModelPreset, value: newValue)"))
        #expect(formBody.contains("scheduleModelPresetSave(key: SettingsKeys.anthropicModelPreset, value: newValue)"))
        #expect(formBody.contains("scheduleModelPresetSave(key: SettingsKeys.openAIModelPreset, value: newValue)"))
        #expect(formBody.contains("scheduleModelPresetSave(key: SettingsKeys.geminiModelPreset, value: newValue)"))
        #expect(formBody.contains("scheduleModelPresetSave(key: SettingsKeys.openRouterModelPreset, value: newValue)"))
        #expect(formBody.contains("scheduleModelPresetSave(key: SettingsKeys.mistralModelPreset, value: newValue)"))
        #expect(formBody.contains("scheduleModelPresetSave(key: SettingsKeys.minimaxModelPreset, value: newValue)"))
        #expect(formBody.contains("scheduleModelPresetSave(key: SettingsKeys.ollamaModelPreset, value: newValue)"))
        #expect(helperBody.contains("modelPresetSaveTasks[key]?.cancel()"))
        #expect(helperBody.contains("try await Task.sleep(for: .milliseconds(150))"))
        #expect(helperBody.contains("guard !Task.isCancelled else { return }"))
        #expect(helperBody.contains("await refreshAIProviders()"))
        #expect(helperBody.contains("modelPresetSaveTasks[key] = nil"))
    }

    @Test
    func aiSettingsNotificationReloadsAreSingleFlightAndCanceledOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")
        let helperBody = try section(
            from: "private func schedulePersistedStateReload(refreshRemoteModels: Bool)",
            to: "    // MARK: - Usage & Costs Section",
            in: source
        )
        let reloadBody = try section(
            from: "private func reloadPersistedState(refreshRemoteModels: Bool) async",
            to: "    @MainActor\n    private func resetUsageStats",
            in: source
        )

        #expect(source.contains("@State private var settingsReloadTask: Task<Void, Never>?"))
        #expect(helperBody.contains("settingsReloadTask?.cancel()"))
        #expect(helperBody.contains("settingsReloadTask = Task"))
        #expect(helperBody.contains("await reloadPersistedState(refreshRemoteModels: refreshRemoteModels)"))
        #expect(source.contains("settingsReloadTask?.cancel()"))
        #expect(source.contains("settingsReloadTask = nil"))
        #expect(reloadBody.contains("guard !Task.isCancelled else { return }"))
        #expect(reloadBody.contains("await reloadLocalModels(syncProvider: true)"))
        #expect(reloadBody.contains("await loadFeedbackState()"))
        #expect(reloadBody.contains("await loadUsageStats()"))
    }

    @Test
    func aiSettingsCredentialAndDefaultProviderModelRefreshesUseSharedScheduler() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")
        let preferredBody = try section(
            from: ".onChange(of: preferredProvider)",
            to: ".onChange(of: discoverAIEnabled)",
            in: source
        )
        let credentialBody = try section(
            from: "private func persistCloudKey(",
            to: "    @MainActor\n    private func persistOllamaEndpoint",
            in: source
        )
        let deleteBody = try section(
            from: "private func deleteCloudCredential(for provider: AIProviderKind) async",
            to: "    @ViewBuilder\n    private var discoverIntegrationSection",
            in: source
        )

        #expect(preferredBody.contains("scheduleModelRefresh(for: newValue)"))
        #expect(!preferredBody.contains("await refreshModels(for: newValue)"))
        #expect(credentialBody.contains("scheduleModelRefresh(for: provider)"))
        #expect(!credentialBody.contains("await refreshModels(for: provider)"))
        #expect(deleteBody.contains("scheduleModelRefresh(for: reconciliation.preferredProvider)"))
        #expect(!deleteBody.contains("await refreshModels(for: reconciliation.preferredProvider)"))
    }

    @Test
    func aiSettingsNotificationReloadsRespectDisabledAutomaticTasksDuringVisionHosting() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")
        let localModelsBody = try section(
            from: ".onReceive(NotificationCenter.default.publisher(for: .localModelsDidChange))",
            to: ".onReceive(NotificationCenter.default.publisher(for: .settingsDidChange))",
            in: source
        )
        let tasteProfileBody = try section(
            from: ".onReceive(NotificationCenter.default.publisher(for: .tasteProfileDidChange))",
            to: "    }\n\n    @MainActor\n    private func flushPendingCloudKeySaves",
            in: source
        )

        #expect(localModelsBody.contains("guard !disablesAutomaticTasks else { return }"))
        #expect(localModelsBody.contains("reloadLocalModels(syncProvider: true)"))
        #expect(tasteProfileBody.contains("guard !disablesAutomaticTasks else { return }"))
        #expect(tasteProfileBody.contains("feedbackReloadTask = Task { await loadFeedbackState() }"))
    }

    @Test
    func traktSettingsCancelsDebouncedSaveTasksOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/TraktSettingsView.swift")
        #expect(source.contains(".onDisappear"))
        #expect(source.contains("flushPendingClientCredentialSaves()"))
        #expect(source.contains("clientIdSaveTask?.cancel()"))
        #expect(source.contains("clientSecretSaveTask?.cancel()"))
    }

    @Test
    func traktSettingsSurfacesPersistenceErrors() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/TraktSettingsView.swift")
        #expect(source.contains("persistBool"))
        #expect(source.contains("persistString"))
        #expect(source.contains("errorMessage = error.localizedDescription"))
    }

    @Test
    func traktSettingsRefreshesWhenSettingsOrResetNotificationsArrive() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/TraktSettingsView.swift")
        let settingsBody = try section(
            from: ".onReceive(NotificationCenter.default.publisher(for: .settingsDidChange))",
            to: ".onReceive(NotificationCenter.default.publisher(for: .appDidResetAllData))",
            in: source
        )
        let resetBody = try section(
            from: ".onReceive(NotificationCenter.default.publisher(for: .appDidResetAllData))",
            to: ".onDisappear",
            in: source
        )
        let disappearBody = try section(
            from: ".onDisappear",
            to: ".onChange(of: autoScrobble)",
            in: source
        )

        #expect(settingsBody.contains("guard !disablesAutomaticReload else { return }"))
        #expect(settingsBody.contains("await reloadPersistedState()"))
        #expect(resetBody.contains("guard !disablesAutomaticReload else { return }"))
        #expect(resetBody.contains("await reloadPersistedState()"))
        #expect(disappearBody.contains("guard !disablesAutomaticReload else { return }"))
    }

    @Test
    func traktCredentialReloadsDoNotScheduleSavesAndFlushOnlyPendingValues() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/TraktSettingsView.swift")
        let autoScrobbleBody = try section(
            from: ".onChange(of: autoScrobble)",
            to: ".onChange(of: syncWatchlist)",
            in: source
        )
        let syncWatchlistBody = try section(
            from: ".onChange(of: syncWatchlist)",
            to: ".onChange(of: syncHistory)",
            in: source
        )
        let syncHistoryBody = try section(
            from: ".onChange(of: syncHistory)",
            to: ".onChange(of: syncRatings)",
            in: source
        )
        let syncRatingsBody = try section(
            from: ".onChange(of: syncRatings)",
            to: ".onChange(of: syncFolders)",
            in: source
        )
        let syncFoldersBody = try section(
            from: ".onChange(of: syncFolders)",
            to: "        .alert(",
            in: source
        )
        let clientIdBody = try section(
            from: ".onChange(of: clientId)",
            to: ".onChange(of: clientSecret)",
            in: source
        )
        let clientSecretBody = try section(
            from: ".onChange(of: clientSecret)",
            to: "    }\n\n    // MARK: - Device Code Flow",
            in: source
        )
        let reloadBody = try section(
            from: "private func reloadPersistedState() async",
            to: "private func flushPendingClientCredentialSaves()",
            in: source
        )
        let flushBody = try section(
            from: "private func flushPendingClientCredentialSaves()",
            to: "    // MARK: - Sync",
            in: source
        )

        #expect(source.contains("@State private var isReloadingPersistedState = false"))
        #expect(autoScrobbleBody.contains("guard !isReloadingPersistedState else { return }"))
        #expect(syncWatchlistBody.contains("guard !isReloadingPersistedState else { return }"))
        #expect(syncHistoryBody.contains("guard !isReloadingPersistedState else { return }"))
        #expect(syncRatingsBody.contains("guard !isReloadingPersistedState else { return }"))
        #expect(syncFoldersBody.contains("guard !isReloadingPersistedState else { return }"))
        #expect(clientIdBody.contains("guard !isReloadingPersistedState else { return }"))
        #expect(clientSecretBody.contains("guard !isReloadingPersistedState else { return }"))
        #expect(reloadBody.contains("isReloadingPersistedState = true"))
        #expect(reloadBody.contains("defer { isReloadingPersistedState = false }"))
        #expect(flushBody.contains("let shouldFlushClientId = clientIdSaveTask != nil"))
        #expect(flushBody.contains("let shouldFlushClientSecret = clientSecretSaveTask != nil"))
        #expect(flushBody.contains("guard shouldFlushClientId || shouldFlushClientSecret else { return }"))
        #expect(flushBody.contains("if shouldFlushClientId"))
        #expect(flushBody.contains("if shouldFlushClientSecret"))
    }

    @Test
    func simklSettingsExposeReadOnlyCleanupSurface() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/SimklSettingsView.swift")
        #expect(source.contains("Cleanup Only in This Build"))
        #expect(source.contains("read-only"))
        #expect(source.contains("Saved Authorization"))
        #expect(source.contains("Disconnect"))
        #expect(source.contains("isShowingDisconnectConfirmation"))
        #expect(source.contains(".alert(\"Disconnect Simkl?\", isPresented: $isShowingDisconnectConfirmation)"))
    }

    @Test
    func simklSettingsNoLongerOfferInteractiveAuthorizationFlow() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/SimklSettingsView.swift")
        #expect(source.contains("authorizationState") == false)
        #expect(source.contains("openAuthorizationPage") == false)
        #expect(source.contains("completeAuthorization") == false)
        #expect(source.contains("simklClientIdSaveTask") == false)
        #expect(source.contains("simklClientSecretSaveTask") == false)
    }

    @Test
    func subtitleSettingsFlushesOpenSubtitlesKeyOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/SubtitleSettingsView.swift")
        #expect(source.contains(".onDisappear { flushOpenSubtitlesKey() }"))
        #expect(source.contains("openSubsSaveTask?.cancel()"))
        #expect(source.contains("private func flushOpenSubtitlesKey()"))
        #expect(source.contains("persistStringSetting(key: SettingsKeys.openSubtitlesApiKey, value: openSubsApiKey)"))
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
    }

    private func requiredRange(of needle: String, in source: String) throws -> Range<String.Index> {
        guard let range = source.range(of: needle) else {
            Issue.record("Missing expected source text: \(needle)")
            throw NSError(domain: "SettingsDebouncedTaskLifecycleTests", code: 1)
        }
        return range
    }

    private func section(from startToken: String, to endToken: String, in source: String) throws -> String {
        let startRange = try requiredRange(of: startToken, in: source)
        guard let endRange = source.range(
            of: endToken,
            range: startRange.upperBound..<source.endIndex
        ) else {
            Issue.record("Missing section terminator: \(endToken)")
            throw NSError(domain: "SettingsDebouncedTaskLifecycleTests", code: 2)
        }
        return String(source[startRange.upperBound..<endRange.lowerBound])
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
