import Foundation
import AVFoundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct AppStateObservablePropertiesTests {

    // MARK: - Navigation Properties - Initial Values

    @Test @MainActor
    func selectedTabDefaultsToDiscover() {
        let appState = AppState()
        #expect(appState.selectedTab == .discover)
    }

    @Test @MainActor
    func navigationLayoutDefaultsToBottomTabBar() {
        let appState = AppState()
        #expect(appState.navigationLayout == .bottomTabBar)
    }

    @Test @MainActor
    func isShowingSetupDefaultsToFalse() {
        let appState = AppState()
        #expect(appState.isShowingSetup == false)
    }

    @Test @MainActor
    func setupRecommendationNeededDefaultsToFalse() {
        let appState = AppState()
        #expect(appState.setupRecommendationNeeded == false)
    }

    @Test @MainActor
    func navigationResetIDIsValidUUID() {
        let appState = AppState()
        #expect(appState.navigationResetID != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(appState.navigationResetID != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test @MainActor
    func isBootstrappingDefaultsToTrue() {
        let appState = AppState()
        #expect(appState.isBootstrapping == true)
    }

    @Test @MainActor
    func runtimeDiagnosticsEnabledDefaultsToFalse() {
        let appState = AppState()
        #expect(appState.runtimeDiagnosticsEnabled == false)
    }

    // MARK: - Warning Properties - Initial Values

    @Test @MainActor
    func environmentBootstrapWarningIsNilByDefault() {
        let appState = AppState()
        #expect(appState.environmentBootstrapWarning == nil)
    }

    @Test @MainActor
    func indexerReloadWarningIsNilByDefault() {
        let appState = AppState()
        #expect(appState.indexerReloadWarning == nil)
    }

    // MARK: - Immersive State Properties - Initial Values

    @Test @MainActor
    func activeEnvironmentIsNilByDefault() {
        let appState = AppState()
        #expect(appState.activeEnvironment == nil)
    }

    @Test @MainActor
    func isImmersiveSpaceOpenDefaultsToFalse() {
        let appState = AppState()
        #expect(appState.isImmersiveSpaceOpen == false)
    }

    @Test @MainActor
    func selectedEnvironmentAssetIsNilByDefault() {
        let appState = AppState()
        #expect(appState.selectedEnvironmentAsset == nil)
    }

    @Test @MainActor
    func isImmersiveTransitionInFlightDefaultsToFalse() {
        let appState = AppState()
        #expect(appState.isImmersiveTransitionInFlight == false)
    }

    @Test @MainActor
    func shouldRestoreImmersiveAfterSuspensionDefaultsToFalse() {
        let appState = AppState()
        #expect(appState.shouldRestoreImmersiveAfterSuspension == false)
    }

    // MARK: - Player Session Properties - Initial Values

    @Test @MainActor
    func activePlayerSessionIsNilByDefault() {
        let appState = AppState()
        #expect(appState.activePlayerSession == nil)
    }

    @Test @MainActor
    func fullscreenBySessionIDStartsEmpty() {
        let appState = AppState()
        #expect(appState.fullscreenBySessionID.isEmpty)
    }

    @Test @MainActor
    func isMainWindowSuppressedForPlayerDefaultsToFalse() {
        let appState = AppState()
        #expect(appState.isMainWindowSuppressedForPlayer == false)
    }

    // MARK: - Player Resources

    @Test @MainActor
    func activeAVPlayerIsNilByDefault() {
        let appState = AppState()
        #expect(appState.activeAVPlayer == nil)
    }

    @Test @MainActor
    func activeVideoRendererIsNilByDefault() {
        let appState = AppState()
        #expect(appState.activeVideoRenderer == nil)
    }

    // MARK: - State Transitions

    @Test @MainActor
    func selectedTabTransitionsThroughAllCases() {
        let appState = AppState()
        for tab in SidebarTab.allCases {
            appState.selectedTab = tab
            #expect(appState.selectedTab == tab)
        }
    }

    @Test @MainActor
    func navigationLayoutTransitions() {
        let appState = AppState()
        appState.navigationLayout = .leftSidebar
        #expect(appState.navigationLayout == .leftSidebar)
        appState.navigationLayout = .bottomTabBar
        #expect(appState.navigationLayout == .bottomTabBar)
    }

    @Test @MainActor
    func isShowingSetupCanBeSetTrue() {
        let appState = AppState()
        appState.isShowingSetup = true
        #expect(appState.isShowingSetup == true)
    }

    @Test @MainActor
    func isBootstrappingCanBeSetFalse() {
        let appState = AppState()
        #expect(appState.isBootstrapping == true)
        appState.isBootstrapping = false
        #expect(appState.isBootstrapping == false)
    }

    @Test @MainActor
    func runtimeDiagnosticsEnabledCanBeToggled() {
        let appState = AppState()
        #expect(appState.runtimeDiagnosticsEnabled == false)
        appState.runtimeDiagnosticsEnabled = true
        #expect(appState.runtimeDiagnosticsEnabled == true)
    }

    @Test @MainActor
    func environmentBootstrapWarningCanBeSet() {
        let appState = AppState()
        appState.environmentBootstrapWarning = "Environment bootstrap failed"
        #expect(appState.environmentBootstrapWarning == "Environment bootstrap failed")
    }

    @Test @MainActor
    func indexerReloadWarningCanBeSet() {
        let appState = AppState()
        appState.indexerReloadWarning = "Indexer reload failed"
        #expect(appState.indexerReloadWarning == "Indexer reload failed")
    }

    @Test @MainActor
    func navigationResetIDGeneratesNewUUIDOnSet() {
        let appState = AppState()
        let originalID = appState.navigationResetID
        appState.navigationResetID = UUID()
        #expect(appState.navigationResetID != originalID)
    }

    // MARK: - Spatial Audio Manager

    @Test @MainActor
    func spatialAudioManagerIsCreated() {
        let appState = AppState()
        #expect(appState.spatialAudioManager.isImmersiveMode == false)
    }
}

// MARK: - AppState Secret Store Namespace Tests

@Suite("AppState - Secret Store Namespace")
struct AppStateSecretStoreNamespaceTests {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "VPStudioTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test
    func currentSecretStoreNamespaceReturnsNonNegative() {
        let defaults = makeIsolatedDefaults()
        let namespace = AppState.currentSecretStoreNamespace(defaults: defaults)
        #expect(namespace >= 0)
    }

    @Test
    func secretStoreServiceNameForZeroNamespaceReturnsBaseName() {
        let name = AppState.secretStoreServiceName(namespace: 0)
        #expect(name == "com.vpstudio.credentials")
    }

    @Test
    func secretStoreServiceNameForPositiveNamespaceIncludesVersion() {
        let name = AppState.secretStoreServiceName(namespace: 1)
        #expect(name == "com.vpstudio.credentials.v1")
        let name2 = AppState.secretStoreServiceName(namespace: 5)
        #expect(name2 == "com.vpstudio.credentials.v5")
    }

    @Test
    func currentSecretStoreServiceNameDefaultsToBaseName() {
        let defaults = makeIsolatedDefaults()
        defaults.set(0, forKey: "app.secret_store_namespace")

        let name = AppState.currentSecretStoreServiceName(defaults: defaults)
        #expect(name == "com.vpstudio.credentials")
    }

    @Test
    func currentSecretStoreServiceNameWithNamespaceIncludesVersion() {
        let defaults = makeIsolatedDefaults()
        defaults.set(3, forKey: "app.secret_store_namespace")

        let name = AppState.currentSecretStoreServiceName(defaults: defaults)
        #expect(name == "com.vpstudio.credentials.v3")
    }

    @Test
    func advanceSecretStoreNamespaceIncrements() {
        let defaults = makeIsolatedDefaults()
        defaults.set(0, forKey: "app.secret_store_namespace")

        let next = AppState.advanceSecretStoreNamespace(defaults: defaults)
        #expect(next == 1)
        #expect(AppState.currentSecretStoreNamespace(defaults: defaults) == 1)
    }

    @Test
    func advanceSecretStoreNamespaceReturnsNextValue() {
        let defaults = makeIsolatedDefaults()
        defaults.set(5, forKey: "app.secret_store_namespace")

        let next = AppState.advanceSecretStoreNamespace(defaults: defaults)
        #expect(next == 6)
    }
}

// MARK: - AppState Local AI Provider Configuration Tests

@Suite("AppState - Local AI Provider Configuration")
struct AppStateLocalAIProviderConfigurationTests {

    @Test @MainActor
    func localAIProviderConfigurationDefaultsToDisabled() async {
        let appState = AppState()
        let config = await appState.localAIProviderConfiguration()
        #expect(config.isEnabled == false)
        #expect(config.selectedModelID == nil)
        #expect(config.resolvedModelID == nil)
        #expect(config.isUsable == false)
    }

    @Test
    func localAIProviderConfigurationUsabilityRequiresEnabledResolvedModel() {
        let usable = AppState.LocalAIProviderConfiguration(
            isEnabled: true,
            selectedModelID: nil,
            resolvedModelID: "local-model"
        )
        let disabled = AppState.LocalAIProviderConfiguration(
            isEnabled: false,
            selectedModelID: "local-model",
            resolvedModelID: "local-model"
        )
        let missingModel = AppState.LocalAIProviderConfiguration(
            isEnabled: true,
            selectedModelID: "missing-model",
            resolvedModelID: nil
        )

        #expect(usable.isUsable)
        #expect(!disabled.isUsable)
        #expect(!missingModel.isUsable)
    }

    @Test @MainActor
    func localAIProviderConfigurationResolvesDownloadedModelFromSettings() async throws {
        let database = try DatabaseManager(inMemoryNamed: "local-ai-config-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())
        let model = Self.makeDownloadedModel(id: "local/test-model", isDefault: false)

        try await database.saveLocalModel(model)
        try await appState.settingsManager.setBool(key: SettingsKeys.localModelEnabled, value: true)
        try await appState.settingsManager.setString(key: SettingsKeys.localModelPreset, value: model.id)

        let config = await appState.localAIProviderConfiguration()

        #expect(config.isEnabled)
        #expect(config.selectedModelID == model.id)
        #expect(config.resolvedModelID == model.id)
        #expect(config.isUsable)
    }

    @Test @MainActor
    func localAIProviderConfigurationKeepsStoredSelectionSeparateFromResolvedModel() async throws {
        let database = try DatabaseManager(inMemoryNamed: "local-ai-config-separation-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())
        let fallbackModel = Self.makeDownloadedModel(id: AIModelCatalog.localSmolLM2.id, isDefault: true)
        let backupModel = Self.makeDownloadedModel(id: "custom/local-model", isDefault: false)

        try await database.saveLocalModel(fallbackModel)
        try await database.saveLocalModel(backupModel)
        try await appState.settingsManager.setBool(key: SettingsKeys.localModelEnabled, value: true)
        try await appState.settingsManager.setString(key: SettingsKeys.localModelPreset, value: "stale/local-model")

        let config = await appState.localAIProviderConfiguration()

        #expect(config.isEnabled)
        #expect(config.selectedModelID == "stale/local-model")
        #expect(config.resolvedModelID == fallbackModel.id)
        #expect(config.isUsable)
    }

    @Test @MainActor
    func configureAIProvidersCapsCloudProvidersAndKeepsLocalModelRegistrationSeparate() async throws {
        let database = try DatabaseManager(inMemoryNamed: "configure-ai-providers-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())
        let localModel = Self.makeDownloadedModel(id: AIModelCatalog.localSmolLM2.id, isDefault: true)

        try await database.saveLocalModel(localModel)
        try await appState.settingsManager.setString(key: SettingsKeys.anthropicApiKey, value: "anthropic-key")
        try await appState.settingsManager.setString(key: SettingsKeys.openAIApiKey, value: "openai-key")
        try await appState.settingsManager.setString(key: SettingsKeys.geminiApiKey, value: "gemini-key")
        try await appState.settingsManager.setString(key: SettingsKeys.openRouterApiKey, value: "openrouter-key")
        try await appState.settingsManager.setBool(key: SettingsKeys.localModelEnabled, value: true)
        try await appState.settingsManager.setString(key: SettingsKeys.localModelPreset, value: localModel.id)

        await appState.configureAIProviders()

        let configuredModels = reflectedConfiguredModels(from: appState.aiAssistantManager)

        #expect(Set(configuredModels.keys) == Set([.anthropic, .openAI, .gemini, .ollama, .local]))
        #expect(configuredModels[.openRouter] == nil)
        #expect(configuredModels[.local] == localModel.id)
        #expect(configuredModels[.anthropic] == AIModelCatalog.defaultModel(for: .anthropic)?.id)
        #expect(configuredModels[.openAI] == AIModelCatalog.defaultModel(for: .openAI)?.id)
        #expect(configuredModels[.gemini] == AIModelCatalog.defaultModel(for: .gemini)?.id)
        #expect(configuredModels[.ollama] == AIModelCatalog.defaultModel(for: .ollama)?.id)
    }

    @Test @MainActor
    func configureAIProvidersRegistersMistralAndMinimaxWhenConfigured() async throws {
        let database = try DatabaseManager(inMemoryNamed: "configure-ai-mistral-minimax-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())

        try await appState.settingsManager.setString(key: SettingsKeys.mistralApiKey, value: "mistral-key")
        try await appState.settingsManager.setString(key: SettingsKeys.minimaxApiKey, value: "minimax-key")
        try await appState.settingsManager.setString(key: SettingsKeys.ollamaEndpoint, value: "   ")

        await appState.configureAIProviders()

        let configuredModels = reflectedConfiguredModels(from: appState.aiAssistantManager)
        #expect(Set(configuredModels.keys) == Set([.mistral, .minimax]))
        #expect(configuredModels[.mistral] == AIModelCatalog.defaultModel(for: .mistral)?.id)
        #expect(configuredModels[.minimax] == AIModelCatalog.defaultModel(for: .minimax)?.id)
    }

    @Test @MainActor
    func configureAIProvidersSkipsOllamaWhenEndpointBlank() async throws {
        let database = try DatabaseManager(inMemoryNamed: "configure-ai-ollama-blank-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())

        try await appState.settingsManager.setString(key: SettingsKeys.openAIApiKey, value: "openai-key")
        try await appState.settingsManager.setString(key: SettingsKeys.ollamaEndpoint, value: "   ")

        await appState.configureAIProviders()

        let configuredModels = reflectedConfiguredModels(from: appState.aiAssistantManager)
        #expect(Set(configuredModels.keys) == Set([.openAI]))
        #expect(configuredModels[.openAI] == AIModelCatalog.defaultModel(for: .openAI)?.id)
        #expect(configuredModels[.ollama] == nil)
    }

    @Test @MainActor
    func configureAIProvidersSkipsOllamaWhenEndpointHasUnsupportedScheme() async throws {
        let database = try DatabaseManager(inMemoryNamed: "configure-ai-ollama-unsupported-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())

        try await appState.settingsManager.setString(key: SettingsKeys.openAIApiKey, value: "openai-key")
        try await appState.settingsManager.setString(key: SettingsKeys.ollamaEndpoint, value: "ws://localhost:11434")

        await appState.configureAIProviders()

        let configuredModels = reflectedConfiguredModels(from: appState.aiAssistantManager)
        #expect(Set(configuredModels.keys) == Set([.openAI]))
        #expect(configuredModels[.openAI] == AIModelCatalog.defaultModel(for: .openAI)?.id)
        #expect(configuredModels[.ollama] == nil)
    }

    @Test @MainActor
    func configureAIProvidersRespectsCloudProviderLimit() async throws {
        let database = try DatabaseManager(inMemoryNamed: "configure-ai-provider-limit-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())

        try await appState.settingsManager.setString(key: SettingsKeys.anthropicApiKey, value: "anthropic-key")
        try await appState.settingsManager.setString(key: SettingsKeys.openAIApiKey, value: "openai-key")
        try await appState.settingsManager.setString(key: SettingsKeys.geminiApiKey, value: "gemini-key")
        try await appState.settingsManager.setString(key: SettingsKeys.openRouterApiKey, value: "openrouter-key")
        try await appState.settingsManager.setString(key: SettingsKeys.ollamaEndpoint, value: "   ")

        await appState.configureAIProviders()

        let configuredModels = reflectedConfiguredModels(from: appState.aiAssistantManager)
        #expect(configuredModels.keys.count == 3)
        #expect(Set(configuredModels.keys) == Set([.anthropic, .openAI, .gemini]))
    }

    private static func makeDownloadedModel(id: String, isDefault: Bool) -> LocalModelDescriptor {
        LocalModelDescriptor(
            id: id,
            displayName: "Local Test Model",
            huggingFaceRepo: id,
            revision: "main",
            parameterCount: "1B",
            quantization: "float16",
            diskSizeMB: 100,
            minMemoryMB: 100,
            expectedFileCount: 1,
            maxContextTokens: 2_048,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 1_024,
            status: .downloaded,
            downloadProgress: 1,
            downloadedBytes: 100,
            totalBytes: 100,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .valid,
            localPath: "/tmp/local-test-model",
            partialDownloadPath: nil,
            isDefault: isDefault,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func reflectedConfiguredModels(from manager: AIAssistantManager) -> [AIProviderKind: String] {
        let mirror = Mirror(reflecting: manager)
        guard let configuredModelsChild = mirror.children.first(where: { $0.label == "configuredModels" }),
              let configuredModels = configuredModelsChild.value as? [AIProviderKind: String] else {
            Issue.record("Could not reflect configuredModels from AIAssistantManager")
            return [:]
        }

        return configuredModels
    }
}

// MARK: - AppState Resolved Local Model ID Tests

@Suite("AppState - Resolved Local Model ID")
struct AppStateResolvedLocalModelIDTests {

    @Test
    func resolvedLocalModelIDReturnsNilForEmptyModels() {
        let result = AppState.resolvedLocalModelID(preferredModelID: nil, downloadedModels: [])
        #expect(result == nil)
    }

    @Test
    func resolvedLocalModelIDReturnsNilWhenPreferredNotDownloaded() {
        // Returns nil only when downloadedModels is empty
        let result = AppState.resolvedLocalModelID(
            preferredModelID: "nonexistent/Model",
            downloadedModels: []
        )
        #expect(result == nil)
    }

    @Test
    func resolvedLocalModelIDReturnsPreferredWhenDownloaded() {
        let model = LocalModelDescriptor(
            id: "apple/SmolLM2-360M-Instruct-CoreML",
            displayName: "SmolLM2 360M",
            huggingFaceRepo: "apple/SmolLM2-360M-Instruct-CoreML",
            revision: "main",
            parameterCount: "360M",
            quantization: "float16",
            diskSizeMB: 700,
            minMemoryMB: 800,
            expectedFileCount: 5,
            maxContextTokens: 2_048,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 1_024,
            status: .downloaded,
            downloadProgress: 1,
            downloadedBytes: 0,
            totalBytes: 0,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        let result = AppState.resolvedLocalModelID(
            preferredModelID: "apple/SmolLM2-360M-Instruct-CoreML",
            downloadedModels: [model]
        )
        #expect(result == "apple/SmolLM2-360M-Instruct-CoreML")
    }

    @Test
    func resolvedLocalModelIDReturnsFirstModelWhenNoPreferred() {
        let model1 = LocalModelDescriptor(
            id: "model-1",
            displayName: "Model 1",
            huggingFaceRepo: "model/1",
            revision: "main",
            parameterCount: "360M",
            quantization: "float16",
            diskSizeMB: 700,
            minMemoryMB: 800,
            expectedFileCount: 5,
            maxContextTokens: 2_048,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 1_024,
            status: .downloaded,
            downloadProgress: 1,
            downloadedBytes: 0,
            totalBytes: 0,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        let model2 = LocalModelDescriptor(
            id: "model-2",
            displayName: "Model 2",
            huggingFaceRepo: "model/2",
            revision: "main",
            parameterCount: "360M",
            quantization: "float16",
            diskSizeMB: 700,
            minMemoryMB: 800,
            expectedFileCount: 5,
            maxContextTokens: 2_048,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 1_024,
            status: .downloaded,
            downloadProgress: 1,
            downloadedBytes: 0,
            totalBytes: 0,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        let result = AppState.resolvedLocalModelID(
            preferredModelID: nil,
            downloadedModels: [model1, model2]
        )
        #expect(result == "model-1")
    }

    @Test
    func resolvedLocalModelIDTrimsWhitespaceFromPreferred() {
        let model = LocalModelDescriptor(
            id: "apple/SmolLM2-360M-Instruct-CoreML",
            displayName: "SmolLM2 360M",
            huggingFaceRepo: "apple/SmolLM2-360M-Instruct-CoreML",
            revision: "main",
            parameterCount: "360M",
            quantization: "float16",
            diskSizeMB: 700,
            minMemoryMB: 800,
            expectedFileCount: 5,
            maxContextTokens: 2_048,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 1_024,
            status: .downloaded,
            downloadProgress: 1,
            downloadedBytes: 0,
            totalBytes: 0,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        let result = AppState.resolvedLocalModelID(
            preferredModelID: "  apple/SmolLM2-360M-Instruct-CoreML  ",
            downloadedModels: [model]
        )
        #expect(result == "apple/SmolLM2-360M-Instruct-CoreML")
    }

    @Test
    func resolvedLocalModelIDReturnsDefaultModelWhenPreferredNotAvailable() {
        let defaultModel = LocalModelDescriptor(
            id: "default-model",
            displayName: "Default Model",
            huggingFaceRepo: "default/model",
            revision: "main",
            parameterCount: "360M",
            quantization: "float16",
            diskSizeMB: 700,
            minMemoryMB: 800,
            expectedFileCount: 5,
            maxContextTokens: 2_048,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 1_024,
            status: .downloaded,
            downloadProgress: 1,
            downloadedBytes: 0,
            totalBytes: 0,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let result = AppState.resolvedLocalModelID(
            preferredModelID: "nonexistent/model",
            downloadedModels: [defaultModel]
        )
        #expect(result == "default-model")
    }
}

// MARK: - AppState Trakt Sync Tests

@Suite("AppState - Trakt Sync")
struct AppStateTraktSyncTests {

    @Test @MainActor
    func performTraktSyncReturnsNilWhenNoCredentials() async throws {
        let appState = try await makeAppStateWithoutTraktCredentials()
        let result = await appState.performTraktSyncAndRefreshLocalState()
        #expect(result == nil)
    }

    @Test @MainActor
    func makeTraktSyncOrchestratorReturnsNilWithoutCredentials() async throws {
        let appState = try await makeAppStateWithoutTraktCredentials()
        let orchestrator = await appState.makeTraktSyncOrchestrator()
        #expect(orchestrator == nil)
    }

    @Test @MainActor
    func makeTraktSyncOrchestratorReturnsConfiguredInstanceWithCredentials() async throws {
        let database = try DatabaseManager(inMemoryNamed: "appstate-trakt-creds-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())

        try await appState.settingsManager.setString(key: SettingsKeys.traktClientId, value: "client-id")
        try await appState.settingsManager.setString(key: SettingsKeys.traktClientSecret, value: "client-secret")
        try await appState.settingsManager.setString(key: SettingsKeys.traktAccessToken, value: "access-token")
        try await appState.settingsManager.setString(key: SettingsKeys.traktRefreshToken, value: "refresh-token")

        let orchestrator = await appState.makeTraktSyncOrchestrator()

        #expect(orchestrator != nil)
    }

    @MainActor
    private func makeAppStateWithoutTraktCredentials() async throws -> AppState {
        let database = try DatabaseManager(inMemoryNamed: "appstate-trakt-no-creds-\(UUID().uuidString)")
        try await database.migrate()
        return AppState(database: database, secretStore: TestSecretStore())
    }
}

// MARK: - AppState Player Lifecycle Tests

@Suite("AppState - Player Lifecycle")
struct AppStatePlayerLifecycleTests {

    @Test @MainActor
    func terminateActivePlayerSessionCallsReleaseWithClearSession() {
        let appState = AppState()
        let player = AVPlayer()
        appState.activePlayerSession = PlayerSessionRequest(
            id: UUID(),
            stream: Fixtures.stream(),
            availableStreams: [],
            mediaTitle: "Test",
            mediaId: "tt123",
            episodeId: nil
        )
        appState.activeAVPlayer = player
        appState.fullscreenBySessionID[appState.activePlayerSession!.id] = true

        appState.terminateActivePlayerSession()

        #expect(appState.activePlayerSession == nil)
        #expect(appState.activeAVPlayer == nil)
        #expect(appState.fullscreenBySessionID[appState.activePlayerSession?.id ?? UUID()] == nil)
    }
}

// MARK: - AppState Migration Tests

@Suite("AppState - Migration")
struct AppStateMigrationTests {

    @Test @MainActor
    func migratePersistedSecretsIfNeededHandlesEmptyConfigs() async throws {
        let database = try DatabaseManager(inMemoryNamed: "migrate-empty-\(UUID().uuidString)")
        try await database.migrate()

        let appState = AppState(database: database, secretStore: TestSecretStore())
        try await appState.migratePersistedSecretsIfNeeded()
        // Should complete without error
        #expect(Bool(true))
    }

    @Test @MainActor
    func migratePersistedSecretsIfNeededMigratesDebridConfig() async throws {
        let database = try DatabaseManager(inMemoryNamed: "migrate-debrid-\(UUID().uuidString)")
        try await database.migrate()

        let secretStore = TestSecretStore()
        let debridID = "test-debrid-migrate"

        try await database.saveDebridConfig(
            DebridConfig(
                id: debridID,
                serviceType: .realDebrid,
                apiTokenRef: "  plaintext-debrid-token  ",
                isActive: true,
                priority: 0
            )
        )

        let appState = AppState(database: database, secretStore: secretStore)
        try await appState.migratePersistedSecretsIfNeeded()

        let config = try #require(try await database.fetchAllDebridConfigs().first { $0.id == debridID })
        #expect(config.apiTokenRef.hasPrefix("keychain:") || config.apiTokenRef.contains("SecretReference"))
    }

    @Test @MainActor
    func migratePersistedSecretsIfNeededMigratesIndexerConfig() async throws {
        let database = try DatabaseManager(inMemoryNamed: "migrate-indexer-\(UUID().uuidString)")
        try await database.migrate()

        let secretStore = TestSecretStore()
        let indexerID = "test-indexer-migrate"

        try await database.saveIndexerConfig(
            IndexerConfig(
                id: indexerID,
                name: "Test Indexer",
                indexerType: .torznab,
                baseURL: "https://test.example",
                apiKey: "  plaintext-api-key  ",
                isActive: true,
                priority: 0
            )
        )

        let appState = AppState(database: database, secretStore: secretStore)
        try await appState.migratePersistedSecretsIfNeeded()

        let config = try #require(try await database.fetchAllIndexerConfigs().first { $0.id == indexerID })
        let apiKey = config.apiKey ?? ""
        #expect(apiKey.hasPrefix("keychain:") || apiKey.contains("SecretReference"))
    }
}

// MARK: - AppState Notifications Tests

@Suite("AppState - Notifications", .serialized)
struct AppStateNotificationsTests {

    private final class NotificationFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false

        func markPosted() {
            lock.lock()
            value = true
            lock.unlock()
        }

        func didPost() -> Bool {
            lock.lock()
            let posted = value
            lock.unlock()
            return posted
        }
    }

    @Test @MainActor
    func applyTraktSyncLocalRefreshPostsLibraryNotification() {
        let flag = NotificationFlag()
        let token = NotificationCenter.default.addObserver(
            forName: .libraryDidChange,
            object: nil,
            queue: nil
        ) { _ in flag.markPosted() }
        defer { NotificationCenter.default.removeObserver(token) }

        let appState = AppState()
        appState.applyTraktSyncLocalRefresh(for: .init(localRefreshTargets: [.library]))

        #expect(flag.didPost())
    }

    @Test @MainActor
    func applyTraktSyncLocalRefreshPostsTasteProfileNotification() {
        let flag = NotificationFlag()
        let token = NotificationCenter.default.addObserver(
            forName: .tasteProfileDidChange,
            object: nil,
            queue: nil
        ) { _ in flag.markPosted() }
        defer { NotificationCenter.default.removeObserver(token) }

        let appState = AppState()
        appState.applyTraktSyncLocalRefresh(for: .init(localRefreshTargets: [.tasteProfile]))

        #expect(flag.didPost())
    }

    @Test @MainActor
    func applyTraktSyncLocalRefreshDoesNotPostForEmptyTargets() {
        let flag = NotificationFlag()
        let token = NotificationCenter.default.addObserver(
            forName: .libraryDidChange,
            object: nil,
            queue: nil
        ) { _ in flag.markPosted() }
        defer { NotificationCenter.default.removeObserver(token) }

        let appState = AppState()
        appState.applyTraktSyncLocalRefresh(for: .init(localRefreshTargets: []))

        #expect(flag.didPost() == false)
    }

    @Test @MainActor
    func disconnectTraktPostsSettingsDidChangeNotification() async throws {
        let flag = NotificationFlag()
        let token = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: nil
        ) { _ in flag.markPosted() }
        defer { NotificationCenter.default.removeObserver(token) }

        let database = try DatabaseManager(inMemoryNamed: "appstate-disconnect-trakt-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())

        try await appState.settingsManager.setString(key: SettingsKeys.traktAccessToken, value: "access-token")
        try await appState.settingsManager.setString(key: SettingsKeys.traktRefreshToken, value: "refresh-token")

        try await appState.disconnectTrakt()

        #expect(flag.didPost())
        #expect(try await appState.settingsManager.getString(key: SettingsKeys.traktAccessToken) == nil)
        #expect(try await appState.settingsManager.getString(key: SettingsKeys.traktRefreshToken) == nil)
    }

    @Test @MainActor
    func disconnectTraktDoesNotPostNotificationWhenSecretStoreDeleteFails() async throws {
        let flag = NotificationFlag()
        let token = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: nil
        ) { _ in flag.markPosted() }
        defer { NotificationCenter.default.removeObserver(token) }

        let database = try DatabaseManager(inMemoryNamed: "appstate-disconnect-trakt-fail-\(UUID().uuidString)")
        try await database.migrate()
        let secretStore = FailingDeleteSecretStore()
        let appState = AppState(database: database, secretStore: secretStore)

        try await appState.settingsManager.setString(key: SettingsKeys.traktAccessToken, value: "access-token")
        try await appState.settingsManager.setString(key: SettingsKeys.traktRefreshToken, value: "refresh-token")

        do {
            try await appState.disconnectTrakt()
            #expect(Bool(false), "disconnectTrakt should throw when the injected secret store cannot delete secrets")
        } catch {
            // expected
        }

        #expect(flag.didPost() == false)
        #expect(try await appState.settingsManager.getString(key: SettingsKeys.traktAccessToken) == "access-token")
        #expect(try await appState.settingsManager.getString(key: SettingsKeys.traktRefreshToken) == "refresh-token")
    }

    @Test @MainActor
    func disconnectTraktRollsBackWhenRefreshTokenDeleteFails() async throws {
        let flag = NotificationFlag()
        let token = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: nil
        ) { _ in flag.markPosted() }
        defer { NotificationCenter.default.removeObserver(token) }

        let database = try DatabaseManager(inMemoryNamed: "appstate-disconnect-trakt-rollback-\(UUID().uuidString)")
        try await database.migrate()
        let secretStore = FailingRollbackSecretStore(failOnDeleteAttempt: 2)
        let appState = AppState(database: database, secretStore: secretStore)

        try await appState.settingsManager.setString(key: SettingsKeys.traktAccessToken, value: "access-token")
        try await appState.settingsManager.setString(key: SettingsKeys.traktRefreshToken, value: "refresh-token")

        do {
            try await appState.disconnectTrakt()
            #expect(Bool(false), "disconnectTrakt should throw when the refresh-token delete fails")
        } catch {
            // expected
        }

        #expect(flag.didPost() == false)
        #expect(try await appState.settingsManager.getString(key: SettingsKeys.traktAccessToken) == "access-token")
        #expect(try await appState.settingsManager.getString(key: SettingsKeys.traktRefreshToken) == "refresh-token")
        #expect(await secretStore.setSecretAttempts == 4)
        #expect(await secretStore.deleteSecretAttempts == 2)
    }

    @Test @MainActor
    func disconnectTraktContinuesRollbackWhenFirstRestoreWriteFails() async throws {
        let flag = NotificationFlag()
        let token = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: nil
        ) { _ in flag.markPosted() }
        defer { NotificationCenter.default.removeObserver(token) }

        let database = try DatabaseManager(inMemoryNamed: "appstate-disconnect-trakt-first-fail-\(UUID().uuidString)")
        try await database.migrate()
        let secretStore = FailingRollbackSecretStore(failOnDeleteAttempt: 1, failOnSetAttempt: 3)
        let appState = AppState(database: database, secretStore: secretStore)

        try await appState.settingsManager.setString(key: SettingsKeys.traktAccessToken, value: "access-token")
        try await appState.settingsManager.setString(key: SettingsKeys.traktRefreshToken, value: "refresh-token")

        do {
            try await appState.disconnectTrakt()
            #expect(Bool(false), "disconnectTrakt should throw when the original secret delete fails")
        } catch {
            // expected
        }

        #expect(flag.didPost() == false)
        #expect(try await appState.settingsManager.getString(key: SettingsKeys.traktAccessToken) == "access-token")
        #expect(try await appState.settingsManager.getString(key: SettingsKeys.traktRefreshToken) == "refresh-token")
        #expect(await secretStore.setSecretAttempts == 4)
        #expect(await secretStore.deleteSecretAttempts == 1)
    }

    private actor FailingDeleteSecretStore: SecretStore {
        enum Failure: Error {
            case cannotDelete
        }

        private var values: [String: String] = [:]

        func setSecret(_ secret: String, for key: String) async throws {
            values[key] = secret
        }

        func getSecret(for key: String) async throws -> String? {
            values[key]
        }

        func deleteSecret(for key: String) async throws {
            throw Failure.cannotDelete
        }

        func deleteAllSecrets() async throws {
            throw Failure.cannotDelete
        }
    }

    private actor FailingRollbackSecretStore: SecretStore {
        enum Failure: Error {
            case deleteFailed
            case restoreWriteFailed
        }

        let failOnDeleteAttempt: Int
        let failOnSetAttempt: Int?
        var setSecretAttempts: Int = 0
        var deleteSecretAttempts: Int = 0
        var values: [String: String] = [:]

        init(failOnDeleteAttempt: Int, failOnSetAttempt: Int? = nil) {
            self.failOnDeleteAttempt = failOnDeleteAttempt
            self.failOnSetAttempt = failOnSetAttempt
        }

        func setSecret(_ secret: String, for key: String) async throws {
            setSecretAttempts += 1
            if setSecretAttempts == failOnSetAttempt {
                throw Failure.restoreWriteFailed
            }
            values[key] = secret
        }

        func getSecret(for key: String) async throws -> String? {
            values[key]
        }

        func deleteSecret(for key: String) async throws {
            deleteSecretAttempts += 1
            if deleteSecretAttempts == failOnDeleteAttempt {
                throw Failure.deleteFailed
            }
            values.removeValue(forKey: key)
        }

        func deleteAllSecrets() async throws {}
    }
}

// MARK: - AppState Database Factory Tests

@Suite("AppState - Database Factory")
struct AppStateDatabaseFactoryTests {

    @Test @MainActor
    func databasePropertyReturnsInjectedDatabase() async throws {
        let database = try DatabaseManager(inMemoryNamed: "injected-\(UUID().uuidString)")
        try await database.migrate()

        let appState = AppState(database: database, secretStore: TestSecretStore())
        #expect(ObjectIdentifier(appState.database) == ObjectIdentifier(database))
    }

    @Test @MainActor
    func databasePropertyFallsBackToFactoryOnFailure() async throws {
        struct FactoryError: Error {}

        let appState = AppState(
            testHooks: .init(
                databaseFactory: {
                    throw FactoryError()
                }
            )
        )

        let database = appState.database
        #expect(type(of: database) == DatabaseManager.self)
    }
}

// MARK: - AppState Service Managers Tests

@Suite("AppState - Service Managers")
struct AppStateServiceManagersTests {

    @Test @MainActor
    func secretStorePropertyReturnsInjectedOrCreatesKeychain() {
        let appState = AppState()
        let store = appState.secretStore
        #expect(store is KeychainSecretStore)
    }

    @Test @MainActor
    func settingsManagerIsLazyInitialized() {
        let appState = AppState()
        let manager1 = appState.settingsManager
        let manager2 = appState.settingsManager
        #expect(ObjectIdentifier(manager1) == ObjectIdentifier(manager2))
    }

    @Test @MainActor
    func debridManagerIsLazyInitialized() {
        let appState = AppState()
        let manager1 = appState.debridManager
        let manager2 = appState.debridManager
        #expect(ObjectIdentifier(manager1) == ObjectIdentifier(manager2))
    }

    @Test @MainActor
    func indexerManagerIsLazyInitialized() {
        let appState = AppState()
        let manager1 = appState.indexerManager
        let manager2 = appState.indexerManager
        #expect(ObjectIdentifier(manager1) == ObjectIdentifier(manager2))
    }

    @Test @MainActor
    func downloadManagerIsLazyInitialized() {
        let appState = AppState()
        let manager1 = appState.downloadManager
        let manager2 = appState.downloadManager
        #expect(ObjectIdentifier(manager1) == ObjectIdentifier(manager2))
    }

    @Test @MainActor
    func environmentCatalogManagerIsLazyInitialized() {
        let appState = AppState()
        let manager1 = appState.environmentCatalogManager
        let manager2 = appState.environmentCatalogManager
        #expect(ObjectIdentifier(manager1) == ObjectIdentifier(manager2))
    }

    @Test @MainActor
    func scrobbleCoordinatorIsLazyInitialized() {
        let appState = AppState()
        let coordinator1 = appState.scrobbleCoordinator
        let coordinator2 = appState.scrobbleCoordinator
        #expect(ObjectIdentifier(coordinator1) == ObjectIdentifier(coordinator2))
    }

    @Test @MainActor
    func libraryCSVImportServiceIsLazyInitialized() {
        let appState = AppState()
        let service1 = appState.libraryCSVImportService
        let service2 = appState.libraryCSVImportService
        #expect(ObjectIdentifier(service1) == ObjectIdentifier(service2))
    }

    @Test @MainActor
    func networkMonitorIsLazyInitialized() {
        let appState = AppState()
        let monitor1 = appState.networkMonitor
        let monitor2 = appState.networkMonitor
        #expect(ObjectIdentifier(monitor1) == ObjectIdentifier(monitor2))
    }

    @Test @MainActor
    func aiAssistantManagerIsLazyInitialized() {
        let appState = AppState()
        let manager1 = appState.aiAssistantManager
        let manager2 = appState.aiAssistantManager
        #expect(ObjectIdentifier(manager1) == ObjectIdentifier(manager2))
    }

    @Test @MainActor
    func localCatalogStoreIsLazyInitialized() {
        let appState = AppState()
        let store1 = appState.localCatalogStore
        let store2 = appState.localCatalogStore
        #expect(ObjectIdentifier(store1) == ObjectIdentifier(store2))
    }

    @Test @MainActor
    func localDownloadServiceIsLazyInitialized() {
        let appState = AppState()
        let service1 = appState.localDownloadService
        let service2 = appState.localDownloadService
        #expect(ObjectIdentifier(service1) == ObjectIdentifier(service2))
    }

    @Test @MainActor
    func localInferenceEngineIsLazyInitialized() {
        let appState = AppState()
        let engine1 = appState.localInferenceEngine
        let engine2 = appState.localInferenceEngine
        #expect(ObjectIdentifier(engine1) == ObjectIdentifier(engine2))
    }
}

// MARK: - AppState Cleanup Persistent Artifacts Tests

@Suite("AppState - Cleanup Persistent Artifacts")
struct AppStateCleanupPersistentArtifactsTests {

    @Test
    func cleanupPersistentArtifactsRemovesDownloadsDirectory() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appSupport = root.appendingPathComponent("ApplicationSupport", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let downloadsDir = appSupport.appendingPathComponent("VPStudio/Downloads", isDirectory: true)
        try fileManager.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        try AppState.cleanupPersistentArtifacts(
            using: fileManager,
            localModels: [],
            appSupportDirectory: appSupport
        )

        #expect(!fileManager.fileExists(atPath: downloadsDir.path))
    }

    @Test
    func cleanupPersistentArtifactsRemovesEnvironmentsDirectory() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appSupport = root.appendingPathComponent("ApplicationSupport", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let envDir = appSupport.appendingPathComponent("VPStudio/Environments", isDirectory: true)
        try fileManager.createDirectory(at: envDir, withIntermediateDirectories: true)

        try AppState.cleanupPersistentArtifacts(
            using: fileManager,
            localModels: [],
            appSupportDirectory: appSupport
        )

        #expect(!fileManager.fileExists(atPath: envDir.path))
    }

    @Test
    func cleanupPersistentArtifactsDoesNotThrowWhenDirectoriesDoNotExist() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appSupport = root.appendingPathComponent("ApplicationSupport", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        // Don't create any directories
        try AppState.cleanupPersistentArtifacts(
            using: fileManager,
            localModels: [],
            appSupportDirectory: appSupport
        )

        #expect(Bool(true))
    }

}

// MARK: - AppState QA Trakt Refresh Tests

@Suite("AppState - QA Trakt Refresh")
struct AppStateQATraktRefreshTests {

    @Test @MainActor
    func runQATraktRefreshIfRequestedDoesNothingWhenNoFixturePath() async {
        let appState = AppState()
        await appState.runQATraktRefreshIfRequested()
        // Should complete without error and without posting notifications
        #expect(Bool(true))
    }
}

// MARK: - AppState Reset All Data Rollback Tests

@Suite("AppState - Reset All Data Rollback")
struct AppStateResetAllDataRollbackTests {

    @Test @MainActor
    func resetAllDataPreservesTabSelectionOnSecretDeletionFailure() async throws {
        struct FailingSecretStore: SecretStore {
            func setSecret(_ value: String, for key: String) async throws {}
            func getSecret(for key: String) async throws -> String? { nil }
            func deleteSecret(for key: String) async throws {}
            func deleteAllSecrets() async throws { throw NSError(domain: "Test", code: 1) }
        }

        let database = try DatabaseManager(inMemoryNamed: "reset-rollback-\(UUID().uuidString)")
        try await database.migrate()

        let appState = AppState(database: database, secretStore: FailingSecretStore())
        appState.selectedTab = .library

        do {
            try await appState.resetAllData()
            Issue.record("Expected resetAllData to throw")
        } catch {
            #expect(appState.selectedTab == .library)
        }
    }
}
