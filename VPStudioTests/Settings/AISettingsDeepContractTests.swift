import Foundation
import Testing
@testable import VPStudio

@Suite("AI Settings Deep Contracts", .serialized)
struct AISettingsDeepContractTests {
    @Test
    func providerSelectorCapsConfiguredCloudProvidersAtThreeInCanonicalOrder() {
        let candidates: [(AIProviderKind, String)] = [
            (.minimax, ""),
            (.openRouter, "openrouter-key"),
            (.mistral, "   "),
            (.anthropic, "anthropic-key"),
            (.openAI, "openai-key"),
        ]

        let enabledProviders = AISettingsPolicy.enabledCloudProviders(candidates: candidates)

        #expect(AISettingsPolicy.maxConfiguredCloudProviders == 3)
        #expect(AISettingsPolicy.cloudProviderLimitMessage.contains("up to 3 cloud AI providers"))
        #expect(enabledProviders == [.anthropic, .openAI, .openRouter])
        #expect(AISettingsPolicy.configuredCloudProviderSummary(enabledProviders) == "Anthropic Claude, OpenAI, OpenRouter")
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .mistral, candidates: candidates))
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .minimax, candidates: candidates))
    }

    @Test
    func duplicateModelNamesStayDistinctAcrossProviderLabels() {
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
            "Shared Model · OpenRouter",
            "Shared Model · MiniMax",
        ])
        #expect(Set(labels).count == models.count)
    }

    @Test
    func whitespaceOnlyCloudKeyClearsStoredSecretAndReleasesTheProviderSlot() async throws {
        let (settings, database, secretStore) = try await makeSettingsEnvironment()

        try await settings.setString(key: SettingsKeys.anthropicApiKey, value: "anthropic-key")
        try await settings.setString(key: SettingsKeys.openAIApiKey, value: "openai-key")
        try await settings.setString(key: SettingsKeys.openRouterApiKey, value: "openrouter-key")

        let initialProviders = try await configuredCloudProviders(from: settings)
        #expect(initialProviders == [.anthropic, .openAI, .openRouter])
        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.openRouterApiKey)) == "openrouter-key")

        try await settings.setString(key: SettingsKeys.openRouterApiKey, value: "   \n\t ")

        let storedReference = try await database.getSetting(key: SettingsKeys.openRouterApiKey)
        let storedSecret = try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.openRouterApiKey))
        let currentValue = try await settings.getString(key: SettingsKeys.openRouterApiKey)
        let updatedProviders = try await configuredCloudProviders(from: settings)

        #expect(storedReference == nil)
        #expect(storedSecret == nil)
        #expect(currentValue == nil)
        #expect(updatedProviders == [.anthropic, .openAI])
        #expect(!AISettingsPolicy.cloudCredentialLimitReached(
            for: .mistral,
            candidates: try await cloudCandidates(from: settings)
        ))
    }

    @Test
    func aiStatusMessagesStayProviderSpecificForMistralMiniMaxAndFallback() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.aiProvider = .mistral
        snapshot.hasOllamaEndpoint = false

        let missingMistral = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(missingMistral.kind == .neutral)
        #expect(missingMistral.message == "Mistral not set")

        snapshot.hasMistralKey = true
        let configuredMistral = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(configuredMistral.kind == .positive)
        #expect(configuredMistral.message == "Mistral configured")

        snapshot = SettingsStatusSnapshot()
        snapshot.aiProvider = .minimax
        snapshot.hasOllamaEndpoint = false

        let missingMiniMax = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(missingMiniMax.kind == .neutral)
        #expect(missingMiniMax.message == "MiniMax not set")

        snapshot.hasMiniMaxKey = true
        let configuredMiniMax = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(configuredMiniMax.kind == .positive)
        #expect(configuredMiniMax.message == "MiniMax configured")

        snapshot = SettingsStatusSnapshot()
        snapshot.aiProvider = .gemini
        snapshot.hasOpenRouterKey = true
        snapshot.hasOllamaEndpoint = false

        let fallbackStatus = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(fallbackStatus.kind == .warning)
        #expect(fallbackStatus.message == "Using OpenRouter")
    }

    @Test
    func sourceContractScopesProviderDisclosureToTheSelectedProviderAndConfiguredState() throws {
        let source = try loadAISettingsViewSource()
        let normalized = normalized(source)

        #expect(normalized.contains("privatevarselectedProviderCredentialSection:someView{switchselectedProvider{"))
        #expect(normalized.contains("case.anthropic:anthropicSection"))
        #expect(normalized.contains("case.openAI:openAISection"))
        #expect(normalized.contains("case.gemini:geminiSection"))
        #expect(normalized.contains("case.openRouter:openRouterSection"))
        #expect(normalized.contains("case.mistral:mistralSection"))
        #expect(normalized.contains("case.minimax:minimaxSection"))
        #expect(normalized.contains("case.ollama:ollamaSection"))
        #expect(normalized.contains("case.local:localModelsSection"))
        #expect(source.contains("SecureField(\"API Key\", text: apiKey)"))
        #expect(source.contains("let state = AISettingsPolicy.cloudProviderSectionState("))
        #expect(source.contains("if state.showsModelPicker {"))
        #expect(source.contains("Picker(\"Model\", selection: modelID)"))
        #expect(source.contains("Text(helperMessage)"))
        #expect(source.contains("unconfiguredProviderMessage(for: provider)"))
    }

    @Test
    func discoverIntegrationUXStaysGatedUntilAnAIProviderIsConfigured() throws {
        let source = try loadAISettingsViewSource()
        let normalized = normalized(source)

        #expect(source.contains("Toggle(\"Show AI Curated Row\", isOn: $discoverAIEnabled)"))
        #expect(normalized.contains("if!canEnableDiscoverAI{"))
        #expect(source.contains("Text(\"Configure at least one AI provider before enabling Discover recommendations.\")"))
        #expect(source.contains("Toggle(\"Auto-generate recommendations\", isOn: $aiAutoGenerate)"))
        #expect(normalized.contains(".disabled(!discoverAIEnabled||!canEnableDiscoverAI)"))
        #expect(source.contains("Text(\"Personalized \\u{201C}Curated For You\\u{201D} row on the Discover page using your taste profile.\")"))
    }

    @Test
    func sourceContractKeepsModelFetchingLazyAndProviderSpecificMessagesScoped() throws {
        let source = try loadAISettingsViewSource()
        let normalized = normalized(source)

        #expect(containsTokensInOrder(
            source,
            [
                ".onChange(of: selectedProvider)",
                "guard !isReloadingPersistedState else { return }",
                "scheduleModelRefresh(for: newValue)"
            ]
        ))
        #expect(source.contains("private func scheduleModelRefresh(for provider: AIProviderKind)"))
        #expect(source.contains("modelRefreshTask?.cancel()"))
        #expect(source.contains("modelRefreshTask = Task { await refreshModels(for: provider) }"))
        #expect(source.contains("guard AISettingsPolicy.shouldFetchModels("))
        #expect(normalized.contains("showsFetchProgress:isConfigured&&isFetchingModels&&selectedProvider==provider"))
        #expect(source.contains("if state.showsFetchProgress {"))
        #expect(source.contains("Text(\"Refreshing \\(providerSelectionLabel(for: provider)) models...\")"))
        #expect(source.contains("OpenRouter models load only while OpenRouter is selected. Similar model names stay labeled with their provider."))
        #expect(source.contains("Mistral models load only while Mistral is selected and connected."))
        #expect(source.contains("MiniMax models load only while MiniMax is selected and connected."))
        #expect(source.contains("if state.showsDeleteButton {"))
        #expect(source.contains("Button(role: .destructive) {"))
        #expect(source.contains("Label(\"Delete API Key\", systemImage: \"trash\")"))
        #expect(source.contains("let deletedPreferredProvider = preferredProvider == provider"))
        #expect(source.contains("AISettingsPolicy.reconcileSelectionAfterDeletingCredential("))
        #expect(source.contains("scheduleModelRefresh(for: reconciliation.preferredProvider)"))
    }

    @Test
    func sourceContractCloudCredentialPersistenceEnforcesProviderLimitBeforeSaving() throws {
        let source = try loadAISettingsViewSource()
        let functionRange = try requiredRange(of: "private func persistCloudKey(", in: source)
        let body = String(source[functionRange.lowerBound...])

        #expect(containsTokensInOrder(
            body,
            [
                "guard AISettingsPolicy.canStoreCloudCredential(",
                "clearCloudKeyDraft(for: provider)",
                "surfaceError = .unknown(AISettingsPolicy.cloudProviderLimitMessage)",
                "return",
                "try await appState.settingsManager.setString(key: key, value: value)",
                "await refreshAIProviders()"
            ]
        ))
    }

    @Test
    func sourceContractOllamaEndpointPersistenceUsesPolicyDecisionBranches() throws {
        let source = try loadAISettingsViewSource()
        let functionRange = try requiredRange(of: "private func persistOllamaEndpoint(", in: source)
        let body = String(source[functionRange.lowerBound...])

        #expect(body.contains("switch AISettingsPolicy.ollamaEndpointPersistenceDecision(for: newValue)"))
        #expect(body.contains("case .persist(let trimmedValue):"))
        #expect(body.contains("case .reject(let warningMessage):"))
        #expect(body.contains("surfaceError = .unknown(warningMessage)"))
    }

    private func makeSettingsEnvironment() async throws -> (SettingsManager, DatabaseManager, TestSecretStore) {
        let database = try DatabaseManager(inMemoryNamed: "ai-settings-deep-\(UUID().uuidString)")
        try await database.migrate()
        let secretStore = TestSecretStore()
        let settings = SettingsManager(database: database, secretStore: secretStore)
        return (settings, database, secretStore)
    }

    private func configuredCloudProviders(from settings: SettingsManager) async throws -> [AIProviderKind] {
        AISettingsPolicy.enabledCloudProviders(candidates: try await cloudCandidates(from: settings))
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

    private func loadAISettingsViewSource() throws -> String {
        try String(
            contentsOf: repoRootURL().appendingPathComponent("VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift"),
            encoding: .utf8
        )
    }

    private func normalized(_ source: String) -> String {
        source.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    private func containsTokensInOrder(_ source: String, _ tokens: [String]) -> Bool {
        var searchStart = source.startIndex
        for token in tokens {
            guard let range = source.range(of: token, range: searchStart..<source.endIndex) else {
                return false
            }
            searchStart = range.upperBound
        }
        return true
    }

    private func requiredRange(of needle: String, in source: String) throws -> Range<String.Index> {
        guard let range = source.range(of: needle) else {
            Issue.record("Missing expected source text: \(needle)")
            throw NSError(domain: "AISettingsDeepContractTests", code: 1)
        }
        return range
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
