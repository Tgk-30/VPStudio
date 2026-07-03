import Foundation
import Testing
@testable import VPStudio

@Suite("AI Settings Provider UX Contracts", .serialized)
struct AISettingsProviderUXContractTests {
    @Test
    func providerFallbackUsesTheResolvedDefaultAsTheActiveSelection() {
        let availableProviders = AIAssistantManager.availableDefaultProviders(
            configuredCloudProviders: [.mistral, .openAI, .openAI, .minimax],
            hasOllamaEndpoint: false,
            hasUsableLocalProvider: false
        )

        #expect(availableProviders == [.openAI, .mistral, .minimax])

        let resolvedProvider = AIAssistantManager.resolvedDefaultProvider(
            preferredProvider: .openRouter,
            availableProviders: availableProviders
        )
        #expect(resolvedProvider == .openAI)

        let hydratedState = AISettingsHydrationPolicy.hydratedState(
            preferredProviderRawValue: AIProviderKind.openRouter.rawValue,
            availableDefaultProviders: availableProviders,
            resolvedSelectedProvider: resolvedProvider,
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

        #expect(hydratedState.preferredProvider == .openAI)
        #expect(hydratedState.selectedProvider == .openAI)
        #expect(AISettingsPolicy.validActiveProviderPickerSelection(
            preferredProvider: .openRouter,
            availableDefaultProviders: availableProviders,
            resolvedSelectedProvider: resolvedProvider
        ) == .openAI)
    }

    @Test
    func deletingACloudApiKeyClearsTheSecretAndReleasesTheThirdProviderSlot() async throws {
        let (settings, database, secretStore, tempDir) = try await makeSettingsEnvironment()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await settings.setString(key: SettingsKeys.anthropicApiKey, value: "anthropic-key")
        try await settings.setString(key: SettingsKeys.openAIApiKey, value: "openai-key")
        try await settings.setString(key: SettingsKeys.geminiApiKey, value: "gemini-key")

        let initialCandidates = try await cloudCandidates(from: settings)
        #expect(AISettingsPolicy.enabledCloudProviders(candidates: initialCandidates) == [.anthropic, .openAI, .gemini])
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .mistral, candidates: initialCandidates))
        #expect(!AISettingsPolicy.canStoreCloudCredential(
            for: .mistral,
            currentConfiguredProviders: [.anthropic, .openAI, .gemini],
            proposedValue: "mistral-key"
        ))

        try await settings.setString(key: SettingsKeys.openAIApiKey, value: nil)

        #expect(try await database.getSetting(key: SettingsKeys.openAIApiKey) == nil)
        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.openAIApiKey)) == nil)

        let afterDeletionCandidates = try await cloudCandidates(from: settings)
        #expect(AISettingsPolicy.enabledCloudProviders(candidates: afterDeletionCandidates) == [.anthropic, .gemini])
        #expect(!AISettingsPolicy.cloudCredentialLimitReached(for: .mistral, candidates: afterDeletionCandidates))
        #expect(AISettingsPolicy.canStoreCloudCredential(
            for: .mistral,
            currentConfiguredProviders: [.anthropic, .gemini],
            proposedValue: "mistral-key"
        ))

        try await settings.setString(key: SettingsKeys.mistralApiKey, value: "mistral-key")

        let finalCandidates = try await cloudCandidates(from: settings)
        #expect(AISettingsPolicy.enabledCloudProviders(candidates: finalCandidates) == [.anthropic, .gemini, .mistral])
        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.mistralApiKey)) == "mistral-key")
    }

    @Test
    func duplicateModelNamesStayDistinctBecauseLabelsIncludeTheProvider() {
        let anthropicModel = AIModelDefinition(
            id: "shared-anthropic",
            displayName: "Shared Model",
            provider: .anthropic,
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

        #expect(AISettingsPolicy.modelSelectionLabel(anthropicModel) == "Shared Model · Anthropic Claude")
        #expect(AISettingsPolicy.modelSelectionLabel(openRouterModel) == "Shared Model · OpenRouter")
        #expect(AISettingsPolicy.modelSelectionLabel(anthropicModel) != AISettingsPolicy.modelSelectionLabel(openRouterModel))
        #expect(anthropicModel.id != openRouterModel.id)
    }

    @Test
    func aiSettingsViewRefreshesAndLabelsModelsOneProviderAtATime() throws {
        let source = try normalizedContents(of: "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift")

        #expect(source.contains("ForEach(AISettingsPolicy.selectableProviders,id:\\.self){providerin"))
        #expect(source.contains("Text(AISettingsPolicy.providerSetupInstruction)"))
        #expect(source.contains("Text(modelSelectionLabel(model)).tag(model.id)"))
        #expect(source.contains("Similarmodelnamesstaylabeledwiththeirprovider."))
        #expect(source.contains("scheduleModelRefresh(for:newValue)"))
        #expect(source.contains("modelRefreshTask=Task{awaitrefreshModels(for:provider)}"))
        #expect(source.contains("ifrefreshRemoteModels{awaitrefreshModels(for:selectedProvider)}"))
        #expect(source.contains("letstate=AISettingsPolicy.cloudProviderSectionState("))
        #expect(source.contains("switchprovider{case.anthropic:awaitrefreshAnthropicModels()"))
        #expect(source.contains("case.openAI:awaitrefreshOpenAIModels()"))
        #expect(source.contains("case.gemini:awaitrefreshGeminiModels()"))
        #expect(source.contains("case.openRouter:awaitrefreshOpenRouterModels()"))
        #expect(source.contains("case.mistral:awaitrefreshMistralModels()"))
        #expect(source.contains("case.minimax:awaitrefreshMiniMaxModels()"))
        #expect(source.contains("case.ollama:awaitrefreshOllamaModels()"))
    }

    private func makeSettingsEnvironment() async throws -> (SettingsManager, DatabaseManager, TestSecretStore, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let database = try DatabaseManager(inMemoryNamed: "ai-settings-provider-ux-\(UUID().uuidString)")
        try await database.migrate()
        let secretStore = TestSecretStore()
        let settings = SettingsManager(database: database, secretStore: secretStore)

        return (settings, database, secretStore, tempDir)
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

    private func normalizedContents(of relativePath: String) throws -> String {
        let source = try contents(of: relativePath)
        return source.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
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
