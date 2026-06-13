import Foundation
import Testing
@testable import VPStudio

@Suite("AI Settings Provider Selector Policy", .serialized)
struct AISettingsProviderSelectorPolicyTests {
    @Test
    func connectedProvidersAppearInPriorityOrderAndDriveTheActiveSelector() {
        let availableProviders = AIAssistantManager.availableDefaultProviders(
            configuredCloudProviders: [.openAI, .anthropic, .mistral],
            hasOllamaEndpoint: true,
            hasUsableLocalProvider: true
        )

        #expect(availableProviders == [.anthropic, .openAI, .mistral, .ollama, .local])

        #expect(AISettingsPolicy.validActiveProviderPickerSelection(
            preferredProvider: .openAI,
            availableDefaultProviders: availableProviders,
            resolvedSelectedProvider: .openAI
        ) == .openAI)

        #expect(AISettingsPolicy.validActiveProviderPickerSelection(
            preferredProvider: .gemini,
            availableDefaultProviders: availableProviders,
            resolvedSelectedProvider: .anthropic
        ) == .anthropic)
    }

    @Test
    func availableProvidersCanonicalizeConfiguredOrderAndDeduplicateBeforeAppendingLocalChoices() {
        let availableProviders = AIAssistantManager.availableDefaultProviders(
            configuredCloudProviders: [.mistral, .openAI, .anthropic, .mistral, .openAI],
            hasOllamaEndpoint: true,
            hasUsableLocalProvider: true
        )

        #expect(availableProviders == [.anthropic, .openAI, .mistral, .ollama, .local])
    }

    @Test
    func cloudProviderPickerCapsAtThreeConfiguredProvidersInCanonicalOrder() {
        let configuredProviders = AISettingsPolicy.enabledCloudProviders(
            candidates: [
                (.minimax, "minimax-key"),
                (.openRouter, "openrouter-key"),
                (.anthropic, "anthropic-key"),
                (.openAI, "openai-key"),
                (.mistral, "mistral-key"),
            ]
        )

        #expect(AISettingsPolicy.maxConfiguredCloudProviders == 3)
        #expect(configuredProviders == [.anthropic, .openAI, .openRouter])
        #expect(AISettingsPolicy.configuredCloudProviderSummary(configuredProviders) == "Anthropic Claude, OpenAI, OpenRouter")
    }

    @Test
    func deletingACloudKeyReleasesTheThirdProviderSlot() async throws {
        let (database, secretStore, settings) = try await makeSettingsManager()

        try await settings.setString(key: SettingsKeys.anthropicApiKey, value: "anthropic-key")
        try await settings.setString(key: SettingsKeys.openAIApiKey, value: "openai-key")
        try await settings.setString(key: SettingsKeys.geminiApiKey, value: "gemini-key")

        let initialCandidates = try await cloudCandidates(from: settings)
        #expect(AISettingsPolicy.enabledCloudProviders(candidates: initialCandidates) == [.anthropic, .openAI, .gemini])
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .mistral, candidates: initialCandidates))
        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.openAIApiKey)) == "openai-key")

        try await settings.setString(key: SettingsKeys.openAIApiKey, value: nil)
        try await settings.setString(key: SettingsKeys.mistralApiKey, value: "mistral-key")

        let updatedCandidates = try await cloudCandidates(from: settings)
        #expect(AISettingsPolicy.enabledCloudProviders(candidates: updatedCandidates) == [.anthropic, .gemini, .mistral])
        #expect(!AISettingsPolicy.cloudCredentialLimitReached(for: .mistral, candidates: updatedCandidates))
        #expect(try await database.getSetting(key: SettingsKeys.openAIApiKey) == nil)
        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.openAIApiKey)) == nil)
        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.mistralApiKey)) == "mistral-key")
    }

    @Test
    func sharedModelNamesStayDisambiguatedByProviderLabel() {
        let openAIModel = AIModelDefinition(
            id: "shared-openai",
            displayName: "Shared Model",
            provider: .openAI,
            inputCostPer1MTokens: 0,
            outputCostPer1MTokens: 0,
            maxContextTokens: 1,
            isDefault: true
        )
        let openRouterModel = AIModelDefinition(
            id: "shared-openrouter",
            displayName: "Shared Model",
            provider: .openRouter,
            inputCostPer1MTokens: 0,
            outputCostPer1MTokens: 0,
            maxContextTokens: 1,
            isDefault: false
        )

        #expect(AISettingsPolicy.modelSelectionLabel(openAIModel) == "Shared Model · OpenAI")
        #expect(AISettingsPolicy.modelSelectionLabel(openRouterModel) == "Shared Model · OpenRouter")
    }

    @Test
    func duplicateModelNamesRemainDistinctInTheSelectorBecauseTheProviderLabelIsIncluded() {
        let models = [
            AIModelDefinition(
                id: "shared-openai",
                displayName: "Shared Model",
                provider: .openAI,
                inputCostPer1MTokens: 0,
                outputCostPer1MTokens: 0,
                maxContextTokens: 1,
                isDefault: true
            ),
            AIModelDefinition(
                id: "shared-openrouter",
                displayName: "Shared Model",
                provider: .openRouter,
                inputCostPer1MTokens: 0,
                outputCostPer1MTokens: 0,
                maxContextTokens: 1,
                isDefault: false
            ),
            AIModelDefinition(
                id: "shared-mistral",
                displayName: "Shared Model",
                provider: .mistral,
                inputCostPer1MTokens: 0,
                outputCostPer1MTokens: 0,
                maxContextTokens: 1,
                isDefault: false
            ),
        ]

        let labels = models.map(AISettingsPolicy.modelSelectionLabel)

        #expect(labels == [
            "Shared Model · OpenAI",
            "Shared Model · OpenRouter",
            "Shared Model · Mistral",
        ])
        #expect(Set(labels).count == models.count)
    }

    @Test
    func repeatedModelDisplayNamesAcrossProvidersStillProduceUniquePickerLabels() {
        let models = [
            AIModelDefinition(
                id: "shared-anthropic",
                displayName: "Shared Model",
                provider: .anthropic,
                inputCostPer1MTokens: 0,
                outputCostPer1MTokens: 0,
                maxContextTokens: 1,
                isDefault: true
            ),
            AIModelDefinition(
                id: "shared-openai",
                displayName: "Shared Model",
                provider: .openAI,
                inputCostPer1MTokens: 0,
                outputCostPer1MTokens: 0,
                maxContextTokens: 1,
                isDefault: false
            ),
            AIModelDefinition(
                id: "shared-openrouter",
                displayName: "Shared Model",
                provider: .openRouter,
                inputCostPer1MTokens: 0,
                outputCostPer1MTokens: 0,
                maxContextTokens: 1,
                isDefault: false
            ),
            AIModelDefinition(
                id: "shared-minimax",
                displayName: "Shared Model",
                provider: .minimax,
                inputCostPer1MTokens: 0,
                outputCostPer1MTokens: 0,
                maxContextTokens: 1,
                isDefault: false
            ),
        ]

        let labels = models.map(AISettingsPolicy.modelSelectionLabel)
        #expect(labels == [
            "Shared Model · Anthropic Claude",
            "Shared Model · OpenAI",
            "Shared Model · OpenRouter",
            "Shared Model · MiniMax",
        ])
        #expect(Set(labels).count == models.count)
    }

    @Test
    func hydrationKeepsOpenRouterMistralAndMiniMaxModelIdsSeparated() {
        let availableProviders = AIAssistantManager.availableDefaultProviders(
            configuredCloudProviders: [.openRouter, .mistral, .minimax],
            hasOllamaEndpoint: false,
            hasUsableLocalProvider: false
        )

        let state = AISettingsHydrationPolicy.hydratedState(
            preferredProviderRawValue: AIProviderKind.mistral.rawValue,
            availableDefaultProviders: availableProviders,
            resolvedSelectedProvider: .mistral,
            storedAnthropicModelID: nil,
            storedOpenAIModelID: nil,
            storedGeminiModelID: nil,
            storedOpenRouterModelID: "mistralai/mistral-nemo",
            storedMistralModelID: "mistral-medium-latest",
            storedMiniMaxModelID: "MiniMax-M2",
            storedOllamaModelID: nil,
            localModelEnabled: nil,
            localModelID: nil
        )

        #expect(state.preferredProvider == .mistral)
        #expect(state.selectedProvider == .mistral)
        #expect(state.modelIDs[.openRouter] == "mistralai/mistral-nemo")
        #expect(state.modelIDs[.mistral] == "mistral-medium-latest")
        #expect(state.modelIDs[.minimax] == "MiniMax-M2")
    }

    @Test
    func deletingOpenRouterCredentialClearsTheSecretAndReleasesTheCloudSlotForMiniMax() async throws {
        let (database, secretStore, settings) = try await makeSettingsManager()

        try await settings.setString(key: SettingsKeys.anthropicApiKey, value: "anthropic-key")
        try await settings.setString(key: SettingsKeys.openAIApiKey, value: "openai-key")
        try await settings.setString(key: SettingsKeys.openRouterApiKey, value: "openrouter-key")

        let initialCandidates = try await cloudCandidates(from: settings)
        #expect(AISettingsPolicy.enabledCloudProviders(candidates: initialCandidates) == [.anthropic, .openAI, .openRouter])
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .minimax, candidates: initialCandidates))
        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.openRouterApiKey)) == "openrouter-key")

        try await settings.setString(key: SettingsKeys.openRouterApiKey, value: nil)

        let updatedCandidates = try await cloudCandidates(from: settings)
        #expect(AISettingsPolicy.enabledCloudProviders(candidates: updatedCandidates) == [.anthropic, .openAI])
        #expect(!AISettingsPolicy.cloudCredentialLimitReached(for: .minimax, candidates: updatedCandidates))
        #expect(AISettingsPolicy.canStoreCloudCredential(
            for: .minimax,
            currentConfiguredProviders: [.anthropic, .openAI],
            proposedValue: "minimax-key"
        ))

        try await settings.setString(key: SettingsKeys.minimaxApiKey, value: "minimax-key")

        let finalCandidates = try await cloudCandidates(from: settings)
        #expect(AISettingsPolicy.enabledCloudProviders(candidates: finalCandidates) == [.anthropic, .openAI, .minimax])
        #expect(try await database.getSetting(key: SettingsKeys.openRouterApiKey) == nil)
        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.openRouterApiKey)) == nil)
        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.minimaxApiKey)) == "minimax-key")
    }

    @Test
    func hydrationUsesCatalogDefaultsBeforeRemoteModelListsLoad() {
        let availableProviders = AIAssistantManager.availableDefaultProviders(
            configuredCloudProviders: [.anthropic],
            hasOllamaEndpoint: true,
            hasUsableLocalProvider: false
        )

        #expect(availableProviders == [.anthropic, .ollama])

        let state = AISettingsHydrationPolicy.hydratedState(
            preferredProviderRawValue: AIProviderKind.openAI.rawValue,
            availableDefaultProviders: availableProviders,
            resolvedSelectedProvider: AIAssistantManager.resolvedDefaultProvider(
                preferredProvider: .openAI,
                availableProviders: availableProviders
            ),
            storedAnthropicModelID: nil,
            storedOpenAIModelID: nil,
            storedGeminiModelID: nil,
            storedOpenRouterModelID: nil,
            storedMistralModelID: nil,
            storedMiniMaxModelID: nil,
            storedOllamaModelID: nil,
            localModelEnabled: nil,
            localModelID: nil
        )

        #expect(state.preferredProvider == .anthropic)
        #expect(state.selectedProvider == .anthropic)
        #expect(state.modelIDs[.anthropic] == AIModelCatalog.defaultModel(for: .anthropic)?.id)
        #expect(state.modelIDs[.openAI] == AIModelCatalog.defaultModel(for: .openAI)?.id)
        #expect(state.modelIDs[.ollama] == AIModelCatalog.defaultModel(for: .ollama)?.id)
        #expect(state.localModelEnabled == false)
    }

    @Test
    func hydrationSeedsCatalogDefaultsForOpenRouterMistralAndMiniMaxBeforeRemoteListsLoad() {
        let state = AISettingsHydrationPolicy.hydratedState(
            preferredProviderRawValue: AIProviderKind.anthropic.rawValue,
            availableDefaultProviders: [.anthropic],
            resolvedSelectedProvider: .anthropic,
            storedAnthropicModelID: nil,
            storedOpenAIModelID: nil,
            storedGeminiModelID: nil,
            storedOpenRouterModelID: nil,
            storedMistralModelID: nil,
            storedMiniMaxModelID: nil,
            storedOllamaModelID: nil,
            localModelEnabled: nil,
            localModelID: nil
        )

        #expect(state.preferredProvider == .anthropic)
        #expect(state.selectedProvider == .anthropic)
        #expect(state.modelIDs[.openRouter] == AIModelCatalog.defaultModel(for: .openRouter)?.id)
        #expect(state.modelIDs[.mistral] == AIModelCatalog.defaultModel(for: .mistral)?.id)
        #expect(state.modelIDs[.minimax] == AIModelCatalog.defaultModel(for: .minimax)?.id)
    }

    private func makeSettingsManager() async throws -> (
        database: DatabaseManager,
        secretStore: TestSecretStore,
        settings: SettingsManager
    ) {
        let database = try DatabaseManager(inMemoryNamed: "ai-provider-selector-\(UUID().uuidString)")
        try await database.migrate()
        let secretStore = TestSecretStore()
        let settings = SettingsManager(database: database, secretStore: secretStore)
        return (database, secretStore, settings)
    }

    private func cloudCandidates(from settings: SettingsManager) async throws -> [(AIProviderKind, String)] {
        [
            (.anthropic, try await settings.getString(key: SettingsKeys.anthropicApiKey) ?? ""),
            (.openAI, try await settings.getString(key: SettingsKeys.openAIApiKey) ?? ""),
            (.gemini, try await settings.getString(key: SettingsKeys.geminiApiKey) ?? ""),
            (.openRouter, try await settings.getString(key: SettingsKeys.openRouterApiKey) ?? ""),
            (.mistral, try await settings.getString(key: SettingsKeys.mistralApiKey) ?? ""),
            (.minimax, try await settings.getString(key: SettingsKeys.minimaxApiKey) ?? ""),
        ]
    }
}
