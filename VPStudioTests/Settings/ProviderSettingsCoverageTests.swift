import Foundation
import Testing
@testable import VPStudio

@Suite("Provider Settings Coverage")
struct ProviderSettingsCoverageTests {
    @Test
    func providerAndModelSelectorsKeepProviderScopedDefaultsAndFallbacksSeparate() {
        let hydrated = AISettingsHydrationPolicy.hydratedState(
            preferredProviderRawValue: AIProviderKind.openRouter.rawValue,
            availableDefaultProviders: [.anthropic, .openAI],
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

        #expect(hydrated.preferredProvider == .anthropic)
        #expect(hydrated.selectedProvider == .anthropic)
        #expect(hydrated.modelIDs[.anthropic] == AIModelCatalog.defaultModel(for: .anthropic)?.id)
        #expect(hydrated.modelIDs[.openAI] == AIModelCatalog.defaultModel(for: .openAI)?.id)
        #expect(hydrated.modelIDs[.gemini] == AIModelCatalog.defaultModel(for: .gemini)?.id)
        #expect(hydrated.modelIDs[.openRouter] == AIModelCatalog.defaultModel(for: .openRouter)?.id)
        #expect(hydrated.modelIDs[.mistral] == AIModelCatalog.defaultModel(for: .mistral)?.id)
        #expect(hydrated.modelIDs[.minimax] == AIModelCatalog.defaultModel(for: .minimax)?.id)
        #expect(hydrated.modelIDs[.ollama] == AIModelCatalog.defaultModel(for: .ollama)?.id)
        #expect(hydrated.localModelID == AIModelCatalog.defaultModel(for: .local)?.id)

        let validModel = AISettingsPolicy.validModelSelection(
            currentModelID: "missing",
            models: [
                AIModelDefinition(
                    id: "first",
                    displayName: "First",
                    provider: .openAI,
                    inputCostPer1MTokens: 0,
                    outputCostPer1MTokens: 0,
                    maxContextTokens: 1,
                    isDefault: false
                ),
                AIModelDefinition(
                    id: "preferred",
                    displayName: "Preferred",
                    provider: .openAI,
                    inputCostPer1MTokens: 0,
                    outputCostPer1MTokens: 0,
                    maxContextTokens: 1,
                    isDefault: true
                )
            ]
        )

        #expect(validModel == "preferred")
        #expect(AISettingsPolicy.validActiveProviderPickerSelection(
            preferredProvider: .openRouter,
            availableDefaultProviders: [.anthropic, .openAI],
            resolvedSelectedProvider: .anthropic
        ) == .anthropic)
    }

    @Test
    func threeConfiguredCloudProvidersCapTheSelectorAndBlockAFourthKey() {
        let candidates: [(AIProviderKind, String)] = [
            (.anthropic, "anthropic-key"),
            (.openAI, "openai-key"),
            (.gemini, "gemini-key"),
            (.openRouter, ""),
            (.mistral, ""),
        ]

        let enabled = AISettingsPolicy.enabledCloudProviders(candidates: candidates)
        let sectionState = AISettingsPolicy.cloudProviderSectionState(
            provider: .mistral,
            isConfigured: false,
            limitReached: true,
            selectedProvider: .mistral,
            preferredProvider: .anthropic,
            isFetchingModels: false
        )

        #expect(enabled == [.anthropic, .openAI, .gemini])
        #expect(AISettingsPolicy.maxConfiguredCloudProviders == 3)
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .mistral, candidates: candidates))
        #expect(!AISettingsPolicy.canStoreCloudCredential(
            for: .mistral,
            currentConfiguredProviders: enabled,
            proposedValue: "new-key"
        ))
        #expect(sectionState.disablesCredentialEntry)
        #expect(sectionState.helperMessage == AISettingsPolicy.cloudProviderLimitMessage)
        #expect(sectionState.showsModelPicker == false)
        #expect(sectionState.showsDeleteButton == false)
    }

    @Test
    func duplicateModelLabelsStayDistinctBecauseTheyIncludeTheProviderName() {
        let sharedAnthropic = AIModelDefinition(
            id: "shared-anthropic",
            displayName: "Shared Model",
            provider: .anthropic,
            inputCostPer1MTokens: 0,
            outputCostPer1MTokens: 0,
            maxContextTokens: 1,
            isDefault: true
        )

        let sharedOpenRouter = AIModelDefinition(
            id: "shared-openrouter",
            displayName: "Shared Model",
            provider: .openRouter,
            inputCostPer1MTokens: 0,
            outputCostPer1MTokens: 0,
            maxContextTokens: 1,
            isDefault: false
        )

        #expect(AISettingsPolicy.modelSelectionLabel(sharedAnthropic) == "Shared Model · Anthropic Claude")
        #expect(AISettingsPolicy.modelSelectionLabel(sharedOpenRouter) == "Shared Model · OpenRouter")
        #expect(AISettingsPolicy.modelSelectionLabel(sharedAnthropic) != AISettingsPolicy.modelSelectionLabel(sharedOpenRouter))
    }

    @Test
    func deletingACloudApiKeyClearsTheExistingSecretAndDatabaseRows() async throws {
        let (settings, database, secrets) = try await makeSettingsEnvironment()

        try await settings.setString(key: SettingsKeys.anthropicApiKey, value: "anthropic-key")
        try await settings.setString(key: SettingsKeys.openAIApiKey, value: "openai-key")

        #expect(try await database.getSetting(key: SettingsKeys.openAIApiKey) != nil)
        #expect(try await secrets.getSecret(for: SecretKey.setting(SettingsKeys.openAIApiKey)) == "openai-key")

        try await settings.setString(key: SettingsKeys.openAIApiKey, value: nil)

        #expect(try await settings.getString(key: SettingsKeys.openAIApiKey) == nil)
        #expect(try await database.getSetting(key: SettingsKeys.openAIApiKey) == nil)
        #expect(try await secrets.getSecret(for: SecretKey.setting(SettingsKeys.openAIApiKey)) == nil)
    }

    @Test
    func lazyFetchPolicyOnlyLoadsProvidersWithUsableConnectivity() {
        #expect(AISettingsPolicy.shouldFetchModels(
            for: .anthropic,
            hasStoredCredential: true,
            hasUsableOllamaEndpoint: false
        ))
        #expect(!AISettingsPolicy.shouldFetchModels(
            for: .anthropic,
            hasStoredCredential: false,
            hasUsableOllamaEndpoint: false
        ))
        #expect(AISettingsPolicy.shouldFetchModels(
            for: .ollama,
            hasStoredCredential: false,
            hasUsableOllamaEndpoint: true
        ))
        #expect(!AISettingsPolicy.shouldFetchModels(
            for: .ollama,
            hasStoredCredential: true,
            hasUsableOllamaEndpoint: false
        ))
        #expect(!AISettingsPolicy.shouldFetchModels(
            for: .local,
            hasStoredCredential: true,
            hasUsableOllamaEndpoint: true
        ))
        #expect(AISettingsPolicy.modelFetchNote(for: .openRouter) == "OpenRouter models load only while OpenRouter is selected. Similar model names stay labeled with their provider.")
        #expect(AISettingsPolicy.modelFetchNote(for: .mistral) == "Mistral models load only while Mistral is selected and connected.")
        #expect(AISettingsPolicy.modelFetchNote(for: .minimax) == "MiniMax models load only while MiniMax is selected and connected.")
        #expect(AISettingsPolicy.modelFetchNote(for: .anthropic) == nil)
    }

    private func makeSettingsEnvironment() async throws -> (SettingsManager, DatabaseManager, TestSecretStore) {
        let database = try DatabaseManager(inMemoryNamed: "provider-settings-\(UUID().uuidString)")
        try await database.migrate()
        let secretStore = TestSecretStore()
        let settings = SettingsManager(database: database, secretStore: secretStore)
        return (settings, database, secretStore)
    }
}

#if os(visionOS)
import SwiftUI
import UIKit

@MainActor
@Suite("Provider Settings View Coverage", .serialized)
struct ProviderSettingsViewCoverageTests {
    @Test
    func hostedProviderViewsExerciseTheConditionalBranchesInTheSettingsForm() async throws {
        let appState = AppState(
            database: try DatabaseManager(inMemoryNamed: "provider-settings-view-\(UUID().uuidString)"),
            secretStore: TestSecretStore()
        )
        try await appState.database.migrate()

        let downloadedModel = makeLocalModel(id: "local-ready", displayName: "Local Ready", status: .downloaded)
        let availableModel = makeLocalModel(id: "local-available", displayName: "Local Available", status: .available)

        let views: [AISettingsView] = [
            AISettingsView(
                initialOpenRouterKey: "openrouter-key",
                initialSelectedProvider: .openRouter,
                initialPreferredProvider: .openRouter,
                disablesAutomaticTasks: true
            ),
            AISettingsView(
                initialAnthropicKey: "anthropic-key",
                initialOpenAIKey: "openai-key",
                initialGeminiKey: "gemini-key",
                initialSelectedProvider: .mistral,
                initialPreferredProvider: .anthropic,
                disablesAutomaticTasks: true
            ),
            AISettingsView(
                initialOllamaURL: "http://localhost:11434",
                initialSelectedProvider: .ollama,
                initialPreferredProvider: .ollama,
                disablesAutomaticTasks: true
            ),
            AISettingsView(
                initialSelectedProvider: .local,
                initialPreferredProvider: .local,
                initialLocalModelEnabled: true,
                initialLocalModels: [downloadedModel, availableModel],
                disablesAutomaticTasks: true
            ),
        ]

        for view in views {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { view.environment(appState) }
                    .frame(width: 760, height: 2_200),
                size: CGSize(width: 980, height: 2_200)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 80_000_000)

            #expect(hosted.host.view.bounds.width > 0)
            #expect(hosted.host.view.bounds.height > 0)
            #expect(hosted.host.view.subviews.isEmpty == false)
            tearDownVisionWindow(hosted.window)
        }
    }

    private func makeLocalModel(id: String, displayName: String, status: LocalModelStatus) -> LocalModelDescriptor {
        let now = Date(timeIntervalSince1970: 1_000)
        return LocalModelDescriptor(
            id: id,
            displayName: displayName,
            huggingFaceRepo: id,
            revision: "main",
            parameterCount: "360M",
            quantization: "4bit",
            diskSizeMB: 700,
            minMemoryMB: 800,
            expectedFileCount: 5,
            maxContextTokens: 2_048,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 1_024,
            status: status,
            downloadProgress: status == .available ? 0 : 1,
            downloadedBytes: status == .downloaded ? 700_000_000 : 0,
            totalBytes: 700_000_000,
            lastProgressAt: now,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: status == .downloaded ? "/tmp/\(id)" : nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: now,
            updatedAt: now
        )
    }
}

@MainActor
private func hostInVisibleVisionWindow<Content: View>(
    _ rootView: Content,
    size: CGSize = CGSize(width: 980, height: 820)
) throws -> (host: UIHostingController<AnyView>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )

    let host = UIHostingController(rootView: AnyView(rootView))
    host.view.backgroundColor = .clear
    let window = UIWindow(windowScene: scene)
    window.rootViewController = host
    window.frame = CGRect(origin: .zero, size: size)
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return (host, window)
}

@MainActor
private func tearDownVisionWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
    window.isHidden = true
    window.rootViewController = nil
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
}
#endif
