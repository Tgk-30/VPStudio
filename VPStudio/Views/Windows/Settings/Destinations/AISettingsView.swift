import SwiftUI

// MARK: - AI Settings

enum AISettingsPolicy {
    enum OllamaEndpointPersistenceDecision: Equatable {
        case persist(String)
        case reject(String)
    }

    struct CloudProviderSectionState: Equatable {
        let disablesCredentialEntry: Bool
        let helperMessage: String?
        let showsModelPicker: Bool
        let showsFetchProgress: Bool
        let modelFetchNote: String?
        let showsActiveProviderBadge: Bool
        let showsUseForRequestsButton: Bool
        let showsDeleteButton: Bool
    }

    struct CredentialDeletionReconciliation: Equatable {
        let preferredProvider: AIProviderKind
        let selectedProvider: AIProviderKind
        let shouldPersistDefaultProvider: Bool
    }

    static let discoverProviderRequiredMessage = "Configure an AI provider before enabling the Discover AI row."
    static let maxConfiguredCloudProviders = 3
    static let cloudProviderLimitMessage = "You can configure up to 3 cloud AI providers at a time. Delete a saved API key before adding another."
    static let providerSetupInstruction = "Choose one provider at a time. Add its API key, then choose that provider's model."
    static let activeProviderInstruction = "Only connected providers appear here. Model selection stays inside each provider setup."
    static let cloudProviders: [AIProviderKind] = [
        .anthropic,
        .openAI,
        .gemini,
        .openRouter,
        .mistral,
        .minimax,
    ]
    static let selectableProviders: [AIProviderKind] = cloudProviders + [.ollama, .local]

    static func providerSelectionLabel(for provider: AIProviderKind) -> String {
        switch provider {
        case .anthropic:
            return "Anthropic Claude"
        case .openAI:
            return "OpenAI"
        case .gemini:
            return "Gemini"
        case .openRouter:
            return "OpenRouter"
        case .mistral:
            return "Mistral"
        case .minimax:
            return "MiniMax"
        case .ollama:
            return "Ollama (Local)"
        case .local:
            return "On-Device (MLX)"
        }
    }

    static func formattedCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }

    static func formattedTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }

    static func validModelSelection(currentModelID: String, models: [AIModelDefinition]) -> String {
        if models.contains(where: { $0.id == currentModelID }) {
            return currentModelID
        }
        return models.first(where: \.isDefault)?.id ?? models.first?.id ?? currentModelID
    }

    static func validLocalModelSelection(
        currentModelID: String,
        downloadedModels: [LocalModelDescriptor]
    ) -> String {
        AppState.resolvedLocalModelID(
            preferredModelID: currentModelID,
            downloadedModels: downloadedModels
        ) ?? downloadedModels.first?.id ?? currentModelID
    }

    static func enabledCloudProviders(candidates: [(AIProviderKind, String)]) -> [AIProviderKind] {
        cloudProviders.filter { provider in
            candidates.contains { candidate, key in
                candidate == provider && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        .prefix(maxConfiguredCloudProviders)
        .map { $0 }
    }

    static func configuredCloudProviderSummary(_ providers: [AIProviderKind]) -> String {
        guard !providers.isEmpty else { return "No cloud providers connected" }
        return providers
            .map(providerSelectionLabel(for:))
            .joined(separator: ", ")
    }

    static func providerHasStoredCredential(
        _ provider: AIProviderKind,
        candidates: [(AIProviderKind, String)]
    ) -> Bool {
        guard cloudProviders.contains(provider) else { return false }
        return candidates.contains { candidate, key in
            candidate == provider && !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    static func cloudCredentialLimitReached(
        for provider: AIProviderKind,
        candidates: [(AIProviderKind, String)]
    ) -> Bool {
        cloudProviders.contains(provider)
            && !providerHasStoredCredential(provider, candidates: candidates)
            && enabledCloudProviders(
                candidates: candidates.map { candidate, key in
                    (candidate, candidate == provider ? "" : key)
                }
            ).count >= maxConfiguredCloudProviders
    }

    static func canStoreCloudCredential(
        for provider: AIProviderKind,
        currentConfiguredProviders: [AIProviderKind],
        proposedValue: String
    ) -> Bool {
        guard cloudProviders.contains(provider) else { return true }
        guard !proposedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        return currentConfiguredProviders.contains(provider)
            || currentConfiguredProviders.count < maxConfiguredCloudProviders
    }

    static func modelSelectionLabel(_ model: AIModelDefinition) -> String {
        "\(model.displayName) · \(providerSelectionLabel(for: model.provider))"
    }

    static func unconfiguredProviderMessage(for provider: AIProviderKind) -> String {
        "Add an API key to unlock model selection for \(providerSelectionLabel(for: provider))."
    }

    static func modelFetchNote(for provider: AIProviderKind) -> String? {
        switch provider {
        case .openRouter:
            return "OpenRouter models load only while OpenRouter is selected. Similar model names stay labeled with their provider."
        case .mistral:
            return "Mistral models load only while Mistral is selected and connected."
        case .minimax:
            return "MiniMax models load only while MiniMax is selected and connected."
        case .anthropic, .openAI, .gemini, .ollama, .local:
            return nil
        }
    }

    static func cloudProviderSectionState(
        provider: AIProviderKind,
        isConfigured: Bool,
        limitReached: Bool,
        selectedProvider: AIProviderKind,
        preferredProvider: AIProviderKind,
        isFetchingModels: Bool
    ) -> CloudProviderSectionState {
        let helperMessage: String?
        if limitReached {
            helperMessage = cloudProviderLimitMessage
        } else if !isConfigured {
            helperMessage = unconfiguredProviderMessage(for: provider)
        } else {
            helperMessage = nil
        }

        return CloudProviderSectionState(
            disablesCredentialEntry: limitReached,
            helperMessage: helperMessage,
            showsModelPicker: isConfigured,
            showsFetchProgress: isConfigured && isFetchingModels && selectedProvider == provider,
            modelFetchNote: isConfigured ? modelFetchNote(for: provider) : nil,
            showsActiveProviderBadge: isConfigured && preferredProvider == provider,
            showsUseForRequestsButton: isConfigured && preferredProvider != provider,
            showsDeleteButton: isConfigured
        )
    }

    static func ollamaEndpointPersistenceDecision(
        for rawValue: String
    ) -> OllamaEndpointPersistenceDecision {
        let trimmedValue = rawValue.trimmedForAISettings
        guard !trimmedValue.isEmpty else {
            return .persist(trimmedValue)
        }

        if let warningMessage = AIOllamaEndpointPolicy.warningMessage(for: trimmedValue) {
            return .reject(warningMessage)
        }

        guard var components = URLComponents(string: trimmedValue),
              let scheme = components.scheme?.lowercased() else {
            return .persist(trimmedValue)
        }
        components.scheme = scheme
        return .persist(components.url?.absoluteString ?? trimmedValue)
    }

    static func reconciledProviderSelection(
        preferredProvider: AIProviderKind,
        selectedProvider: AIProviderKind,
        availableDefaultProviders: [AIProviderKind],
        resolvedSelectedProvider: AIProviderKind?
    ) -> (preferredProvider: AIProviderKind, selectedProvider: AIProviderKind) {
        guard !availableDefaultProviders.isEmpty,
              !availableDefaultProviders.contains(preferredProvider),
              let resolvedSelectedProvider else {
            return (preferredProvider, selectedProvider)
        }

        return (
            preferredProvider: resolvedSelectedProvider,
            selectedProvider: selectedProvider == preferredProvider ? resolvedSelectedProvider : selectedProvider
        )
    }

    static func validActiveProviderPickerSelection(
        preferredProvider: AIProviderKind,
        availableDefaultProviders: [AIProviderKind],
        resolvedSelectedProvider: AIProviderKind?
    ) -> AIProviderKind {
        if availableDefaultProviders.contains(preferredProvider) {
            return preferredProvider
        }

        return resolvedSelectedProvider ?? availableDefaultProviders.first ?? preferredProvider
    }

    static func shouldFetchModels(
        for provider: AIProviderKind,
        hasStoredCredential: Bool,
        hasUsableOllamaEndpoint: Bool
    ) -> Bool {
        switch provider {
        case .anthropic, .openAI, .gemini, .openRouter, .mistral, .minimax:
            return hasStoredCredential
        case .ollama:
            return hasUsableOllamaEndpoint
        case .local:
            return false
        }
    }

    static func reconcileSelectionAfterDeletingCredential(
        deletedProvider: AIProviderKind,
        deletedPreferredProvider: Bool,
        preferredProvider: AIProviderKind,
        selectedProvider: AIProviderKind,
        availableDefaultProviders: [AIProviderKind]
    ) -> CredentialDeletionReconciliation {
        guard deletedPreferredProvider else {
            return CredentialDeletionReconciliation(
                preferredProvider: preferredProvider,
                selectedProvider: selectedProvider,
                shouldPersistDefaultProvider: false
            )
        }

        let fallbackProvider = AIAssistantManager.resolvedDefaultProvider(
            preferredProvider: nil,
            availableProviders: availableDefaultProviders
        ) ?? .anthropic
        let reconciledSelectedProvider = selectedProvider == deletedProvider ? fallbackProvider : selectedProvider

        return CredentialDeletionReconciliation(
            preferredProvider: fallbackProvider,
            selectedProvider: reconciledSelectedProvider,
            shouldPersistDefaultProvider: true
        )
    }
}

enum AISettingsHydrationPolicy {
    struct State: Equatable {
        var preferredProvider: AIProviderKind
        var selectedProvider: AIProviderKind
        var modelIDs: [AIProviderKind: String]
        var localModelEnabled: Bool
        var localModelID: String
    }

    static func hydratedState(
        preferredProviderRawValue: String?,
        availableDefaultProviders: [AIProviderKind],
        resolvedSelectedProvider: AIProviderKind?,
        storedAnthropicModelID: String?,
        storedOpenAIModelID: String?,
        storedGeminiModelID: String?,
        storedOpenRouterModelID: String?,
        storedMistralModelID: String?,
        storedMiniMaxModelID: String?,
        storedOllamaModelID: String?,
        localModelEnabled: Bool?,
        localModelID: String?
    ) -> State {
        let preferredProvider = preferredProviderRawValue
            .flatMap(AIProviderKind.init(rawValue:))
            ?? .anthropic

        let reconciled = AISettingsPolicy.reconciledProviderSelection(
            preferredProvider: preferredProvider,
            selectedProvider: preferredProvider,
            availableDefaultProviders: availableDefaultProviders,
            resolvedSelectedProvider: resolvedSelectedProvider
        )

        return State(
            preferredProvider: reconciled.preferredProvider,
            selectedProvider: reconciled.selectedProvider,
            modelIDs: [
                .anthropic: storedAnthropicModelID ?? defaultModelID(for: .anthropic),
                .openAI: storedOpenAIModelID ?? defaultModelID(for: .openAI),
                .gemini: storedGeminiModelID ?? defaultModelID(for: .gemini),
                .openRouter: storedOpenRouterModelID ?? defaultModelID(for: .openRouter),
                .mistral: storedMistralModelID ?? defaultModelID(for: .mistral),
                .minimax: storedMiniMaxModelID ?? defaultModelID(for: .minimax),
                .ollama: storedOllamaModelID ?? defaultModelID(for: .ollama),
            ],
            localModelEnabled: localModelEnabled ?? false,
            localModelID: localModelID ?? defaultModelID(for: .local)
        )
    }

    private static func defaultModelID(for provider: AIProviderKind) -> String {
        switch provider {
        case .anthropic:
            return AIModelCatalog.defaultModel(for: .anthropic)?.id ?? "claude-sonnet-4-6"
        case .openAI:
            return AIModelCatalog.defaultModel(for: .openAI)?.id ?? "gpt-5.4"
        case .gemini:
            return AIModelCatalog.defaultModel(for: .gemini)?.id ?? "gemini-2.5-flash"
        case .openRouter:
            return AIModelCatalog.defaultModel(for: .openRouter)?.id ?? ""
        case .mistral:
            return AIModelCatalog.defaultModel(for: .mistral)?.id ?? ""
        case .minimax:
            return AIModelCatalog.defaultModel(for: .minimax)?.id ?? ""
        case .ollama:
            return AIModelCatalog.defaultModel(for: .ollama)?.id ?? "llama3.1"
        case .local:
            return AIModelCatalog.defaultModel(for: .local)?.id ?? ""
        }
    }
}

enum AISettingsFeedbackPolicy {
    struct Summary: Equatable {
        let likedTitles: [String]
        let dislikedTitles: [String]
        let recentRatings: [String]
    }

    static func resolvedFeedbackTitle(for event: TasteEvent, titleByMediaID: [String: String]) -> String {
        if let metadataTitle = event.metadata["title"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !metadataTitle.isEmpty {
            return metadataTitle
        }
        if let mediaID = event.mediaId,
           let mediaTitle = titleByMediaID[mediaID]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !mediaTitle.isEmpty {
            return mediaTitle
        }
        return event.mediaId ?? "Unknown title"
    }

    static func feedbackSummary(
        events: [TasteEvent],
        titleByMediaID: [String: String],
        fallbackScaleMode: FeedbackScaleMode,
        recentLimit: Int = 20
    ) -> Summary {
        var likedTitles: [String] = []
        var dislikedTitles: [String] = []
        var recentRatings: [String] = []

        var likedSeen = Set<String>()
        var dislikedSeen = Set<String>()
        var recentSeen = Set<String>()

        for event in events {
            guard let rawValue = event.feedbackValue else { continue }
            let scale = (event.feedbackScale ?? fallbackScaleMode).canonicalMode
            let title = resolvedFeedbackTitle(for: event, titleByMediaID: titleByMediaID)
            guard !title.isEmpty else { continue }

            switch scale.sentiment(for: rawValue) {
            case .liked:
                let key = title.lowercased()
                if likedSeen.insert(key).inserted {
                    likedTitles.append(title)
                }
            case .disliked:
                let key = title.lowercased()
                if dislikedSeen.insert(key).inserted {
                    dislikedTitles.append(title)
                }
            case .neutral:
                break
            }

            let ratingLine = "\(title) (\(scale.format(rawValue)))"
            let ratingKey = ratingLine.lowercased()
            if recentRatings.count < recentLimit, recentSeen.insert(ratingKey).inserted {
                recentRatings.append(ratingLine)
            }
        }

        return Summary(
            likedTitles: likedTitles,
            dislikedTitles: dislikedTitles,
            recentRatings: recentRatings
        )
    }
}

struct AISettingsCloudCredentialRuntimeCommand {
    let provider: AIProviderKind
    let value: String

    var settingsKey: String? {
        switch provider {
        case .anthropic:
            SettingsKeys.anthropicApiKey
        case .openAI:
            SettingsKeys.openAIApiKey
        case .gemini:
            SettingsKeys.geminiApiKey
        case .openRouter:
            SettingsKeys.openRouterApiKey
        case .mistral:
            SettingsKeys.mistralApiKey
        case .minimax:
            SettingsKeys.minimaxApiKey
        case .ollama, .local:
            nil
        }
    }
}

struct AISettingsStringRuntimeCommand {
    let key: String
    let value: String
}

struct AISettingsBoolRuntimeCommand {
    let key: String
    let value: Bool
}

struct AISettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var anthropicKey = ""
    @State private var openAIKey = ""
    @State private var geminiKey = ""
    @State private var openRouterKey = ""
    @State private var mistralKey = ""
    @State private var minimaxKey = ""
    @State private var ollamaURL = "http://localhost:11434"
    @State private var selectedProvider: AIProviderKind = .anthropic
    @State private var preferredProvider: AIProviderKind = .anthropic
    @State private var anthropicModelID: String = AIModelCatalog.defaultModel(for: .anthropic)?.id ?? ""
    @State private var openAIModelID: String = AIModelCatalog.defaultModel(for: .openAI)?.id ?? ""
    @State private var geminiModelID: String = AIModelCatalog.defaultModel(for: .gemini)?.id ?? ""
    @State private var openRouterModelID: String = AIModelCatalog.defaultModel(for: .openRouter)?.id ?? ""
    @State private var mistralModelID: String = AIModelCatalog.defaultModel(for: .mistral)?.id ?? ""
    @State private var minimaxModelID: String = AIModelCatalog.defaultModel(for: .minimax)?.id ?? ""
    @State private var ollamaModelID: String = AIModelCatalog.defaultModel(for: .ollama)?.id ?? ""
    @State private var feedbackScaleMode: FeedbackScaleMode = .likeDislike
    @State private var likedTitles: [String] = []
    @State private var dislikedTitles: [String] = []
    @State private var recentRatings: [String] = []
    @State private var anthropicSaveTask: Task<Void, Never>?
    @State private var openAISaveTask: Task<Void, Never>?
    @State private var geminiSaveTask: Task<Void, Never>?
    @State private var openRouterSaveTask: Task<Void, Never>?
    @State private var mistralSaveTask: Task<Void, Never>?
    @State private var minimaxSaveTask: Task<Void, Never>?
    @State private var feedbackReloadTask: Task<Void, Never>?
    @State private var modelRefreshTask: Task<Void, Never>?
    @State private var settingsReloadTask: Task<Void, Never>?
    @State private var modelPresetSaveTasks: [String: Task<Void, Never>] = [:]
    @State private var sessionUsage: AIUsageSummary = .empty
    @State private var lifetimeUsage: AIUsageSummary = .empty
    @State private var discoverAIEnabled = false
    @State private var aiAutoGenerate = true
    @State private var isShowingResetStatisticsConfirmation = false
    @State private var surfaceError: AppError?

    // Local on-device models
    @State private var localModelEnabled = false
    @State private var localModelID: String = AIModelCatalog.defaultModel(for: .local)?.id ?? ""
    @State private var localModels: [LocalModelDescriptor] = []

    // Live-fetched model lists (fall back to static catalog)
    @State private var anthropicModels: [AIModelDefinition] = AIModelCatalog.models(for: .anthropic)
    @State private var openAIModels: [AIModelDefinition] = AIModelCatalog.models(for: .openAI)
    @State private var geminiModels: [AIModelDefinition] = AIModelCatalog.models(for: .gemini)
    @State private var openRouterModels: [AIModelDefinition] = AIModelCatalog.models(for: .openRouter)
    @State private var mistralModels: [AIModelDefinition] = AIModelCatalog.models(for: .mistral)
    @State private var minimaxModels: [AIModelDefinition] = AIModelCatalog.models(for: .minimax)
    @State private var ollamaModels: [AIModelDefinition] = AIModelCatalog.models(for: .ollama)
    @State private var isFetchingModels = false
    @State private var isReloadingPersistedState = false
    private let disablesAutomaticTasks: Bool
    private let enablesRuntimeControls: Bool
    private let onRuntimeControlsReady: (@MainActor () -> Void)?
    private let onRuntimeControlCommandCompleted: (@MainActor () -> Void)?

    /// Approximate app launch time — used to partition session vs lifetime usage.
    private static let appLaunchDate = Date()

    init(
        initialAnthropicKey: String = "",
        initialOpenAIKey: String = "",
        initialGeminiKey: String = "",
        initialOpenRouterKey: String = "",
        initialMistralKey: String = "",
        initialMiniMaxKey: String = "",
        initialOllamaURL: String = "http://localhost:11434",
        initialSelectedProvider: AIProviderKind = .anthropic,
        initialPreferredProvider: AIProviderKind = .anthropic,
        initialLocalModelEnabled: Bool = false,
        initialLocalModelID: String = AIModelCatalog.defaultModel(for: .local)?.id ?? "",
        initialLocalModels: [LocalModelDescriptor] = [],
        initialSessionUsage: AIUsageSummary = .empty,
        initialLifetimeUsage: AIUsageSummary = .empty,
        initialDiscoverAIEnabled: Bool = false,
        initialAIAutoGenerate: Bool = true,
        initialFeedbackScaleMode: FeedbackScaleMode = .likeDislike,
        initialLikedTitles: [String] = [],
        initialDislikedTitles: [String] = [],
        initialRecentRatings: [String] = [],
        initialSurfaceError: AppError? = nil,
        initialIsFetchingModels: Bool = false,
        disablesAutomaticTasks: Bool = false,
        enablesRuntimeControls: Bool = false,
        onRuntimeControlsReady: (@MainActor () -> Void)? = nil,
        onRuntimeControlCommandCompleted: (@MainActor () -> Void)? = nil
    ) {
        _anthropicKey = State(initialValue: initialAnthropicKey)
        _openAIKey = State(initialValue: initialOpenAIKey)
        _geminiKey = State(initialValue: initialGeminiKey)
        _openRouterKey = State(initialValue: initialOpenRouterKey)
        _mistralKey = State(initialValue: initialMistralKey)
        _minimaxKey = State(initialValue: initialMiniMaxKey)
        _ollamaURL = State(initialValue: initialOllamaURL)
        _selectedProvider = State(initialValue: initialSelectedProvider)
        _preferredProvider = State(initialValue: initialPreferredProvider)
        _localModelEnabled = State(initialValue: initialLocalModelEnabled)
        _localModelID = State(initialValue: initialLocalModelID)
        _localModels = State(initialValue: initialLocalModels)
        _sessionUsage = State(initialValue: initialSessionUsage)
        _lifetimeUsage = State(initialValue: initialLifetimeUsage)
        _discoverAIEnabled = State(initialValue: initialDiscoverAIEnabled)
        _aiAutoGenerate = State(initialValue: initialAIAutoGenerate)
        _feedbackScaleMode = State(initialValue: initialFeedbackScaleMode)
        _likedTitles = State(initialValue: initialLikedTitles)
        _dislikedTitles = State(initialValue: initialDislikedTitles)
        _recentRatings = State(initialValue: initialRecentRatings)
        _surfaceError = State(initialValue: initialSurfaceError)
        _isFetchingModels = State(initialValue: initialIsFetchingModels)
        self.disablesAutomaticTasks = disablesAutomaticTasks
        self.enablesRuntimeControls = enablesRuntimeControls
        self.onRuntimeControlsReady = onRuntimeControlsReady
        self.onRuntimeControlCommandCompleted = onRuntimeControlCommandCompleted
    }

    private func cloudCredentialCandidates(excluding provider: AIProviderKind? = nil) -> [(AIProviderKind, String)] {
        [
            (.anthropic, provider == .anthropic ? "" : anthropicKey),
            (.openAI, provider == .openAI ? "" : openAIKey),
            (.gemini, provider == .gemini ? "" : geminiKey),
            (.openRouter, provider == .openRouter ? "" : openRouterKey),
            (.mistral, provider == .mistral ? "" : mistralKey),
            (.minimax, provider == .minimax ? "" : minimaxKey),
        ]
    }

    private var configuredCloudProviders: [AIProviderKind] {
        AISettingsPolicy.enabledCloudProviders(
            candidates: cloudCredentialCandidates()
        )
    }

    private func configuredCloudProviders(excluding provider: AIProviderKind? = nil) -> [AIProviderKind] {
        AISettingsPolicy.enabledCloudProviders(
            candidates: cloudCredentialCandidates(excluding: provider)
        )
    }

    private var hasConfiguredCloudProvider: Bool {
        !configuredCloudProviders.isEmpty
    }

    private var configuredCloudProviderSummary: String {
        AISettingsPolicy.configuredCloudProviderSummary(configuredCloudProviders)
    }

    private var hasUsableLocalProvider: Bool {
        guard localModelEnabled else { return false }
        let downloadedModels = localModels.filter { $0.status == .downloaded }
        return AppState.resolvedLocalModelID(
            preferredModelID: localModelID,
            downloadedModels: downloadedModels
        ) != nil
    }

    private var availableDefaultProviders: [AIProviderKind] {
        AIAssistantManager.availableDefaultProviders(
            configuredCloudProviders: configuredCloudProviders,
            hasOllamaEndpoint: hasUsableOllamaEndpoint,
            hasUsableLocalProvider: hasUsableLocalProvider
        )
    }

    private var resolvedSelectedProvider: AIProviderKind? {
        AIAssistantManager.resolvedDefaultProvider(
            preferredProvider: preferredProvider,
            availableProviders: availableDefaultProviders
        )
    }

    private var showsProviderFallbackMessage: Bool {
        guard let resolvedSelectedProvider else { return false }
        return preferredProvider != resolvedSelectedProvider
    }

    private var activeProviderPickerSelection: Binding<AIProviderKind> {
        Binding(
            get: {
                AISettingsPolicy.validActiveProviderPickerSelection(
                    preferredProvider: preferredProvider,
                    availableDefaultProviders: availableDefaultProviders,
                    resolvedSelectedProvider: resolvedSelectedProvider
                )
            },
            set: { newValue in
                preferredProvider = newValue
            }
        )
    }

    private var ollamaEndpointWarningMessage: String? {
        AIOllamaEndpointPolicy.warningMessage(for: ollamaURL)
    }

    private var hasUsableOllamaEndpoint: Bool {
        let trimmed = ollamaURL.trimmedForAISettings
        return !trimmed.isEmpty && ollamaEndpointWarningMessage == nil
    }

    private func localModelPickerSelection(downloadedModels: [LocalModelDescriptor]) -> Binding<String> {
        Binding(
            get: {
                AISettingsPolicy.validLocalModelSelection(
                    currentModelID: localModelID,
                    downloadedModels: downloadedModels
                )
            },
            set: { newValue in
                localModelID = newValue
            }
        )
    }

    private var canEnableDiscoverAI: Bool {
        !availableDefaultProviders.isEmpty
    }

    var body: some View {
        formWithKeyHandlers
            .navigationTitle("AI Assistant")
            .confirmationDialog(
                "Reset AI Usage Statistics?",
                isPresented: $isShowingResetStatisticsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Statistics", role: .destructive) {
                    Task { await resetUsageStats() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears request counts and cost history for all AI providers. This cannot be undone.")
            }
        .task {
            guard !disablesAutomaticTasks else { return }
            await reloadPersistedState(refreshRemoteModels: false)
        }
        .onChange(of: anthropicKey) { _, newValue in
            guard !isReloadingPersistedState else { return }
            reconcilePreferredProvider()
            scheduleCloudKeySave(task: &anthropicSaveTask, key: SettingsKeys.anthropicApiKey, value: newValue, provider: .anthropic)
        }
        .onChange(of: openAIKey) { _, newValue in
            guard !isReloadingPersistedState else { return }
            reconcilePreferredProvider()
            scheduleCloudKeySave(task: &openAISaveTask, key: SettingsKeys.openAIApiKey, value: newValue, provider: .openAI)
        }
        .onChange(of: geminiKey) { _, newValue in
            guard !isReloadingPersistedState else { return }
            reconcilePreferredProvider()
            scheduleCloudKeySave(task: &geminiSaveTask, key: SettingsKeys.geminiApiKey, value: newValue, provider: .gemini)
        }
        .onChange(of: openRouterKey) { _, newValue in
            guard !isReloadingPersistedState else { return }
            reconcilePreferredProvider()
            scheduleCloudKeySave(task: &openRouterSaveTask, key: SettingsKeys.openRouterApiKey, value: newValue, provider: .openRouter)
        }
        .onChange(of: mistralKey) { _, newValue in
            guard !isReloadingPersistedState else { return }
            reconcilePreferredProvider()
            scheduleCloudKeySave(task: &mistralSaveTask, key: SettingsKeys.mistralApiKey, value: newValue, provider: .mistral)
        }
        .onChange(of: minimaxKey) { _, newValue in
            guard !isReloadingPersistedState else { return }
            reconcilePreferredProvider()
            scheduleCloudKeySave(task: &minimaxSaveTask, key: SettingsKeys.minimaxApiKey, value: newValue, provider: .minimax)
        }
        .onChange(of: localModelEnabled) { _, newValue in
            guard !isReloadingPersistedState else { return }
            reconcilePreferredProvider()
            Task {
                await persistBoolSetting(key: SettingsKeys.localModelEnabled, value: newValue) {
                    await reloadLocalModels(syncProvider: false)
                    await refreshAIProviders()
                }
            }
        }
        .onChange(of: localModelID) { _, newValue in
            guard !isReloadingPersistedState else { return }
            reconcilePreferredProvider()
            scheduleModelPresetSave(key: SettingsKeys.localModelPreset, value: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .localModelsDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            Task {
                await reloadLocalModels(syncProvider: true)
                await MainActor.run { reconcilePreferredProvider() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            schedulePersistedStateReload(refreshRemoteModels: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidResetAllData)) { _ in
            guard !disablesAutomaticTasks else { return }
            schedulePersistedStateReload(refreshRemoteModels: false)
        }
        .onDisappear {
            guard !disablesAutomaticTasks else { return }
            flushPendingCloudKeySaves()
            for task in modelPresetSaveTasks.values {
                task.cancel()
            }
            modelPresetSaveTasks.removeAll()
            settingsReloadTask?.cancel()
            settingsReloadTask = nil
            feedbackReloadTask?.cancel()
            feedbackReloadTask = nil
            modelRefreshTask?.cancel()
            modelRefreshTask = nil
        }
        .onAppear {
            guard enablesRuntimeControls else { return }
            onRuntimeControlsReady?()
        }
        .modifier(
            AISettingsRuntimeControlHandlers(
                enabled: enablesRuntimeControls,
                persistCloudCredential: { command in
                    guard let key = command.settingsKey else { return }
                    await persistCloudKey(key: key, value: command.value, provider: command.provider)
                    onRuntimeControlCommandCompleted?()
                },
                deleteCloudCredential: { provider in
                    await deleteCloudCredential(for: provider)
                    onRuntimeControlCommandCompleted?()
                },
                persistOllamaEndpoint: { value in
                    await persistOllamaEndpoint(value)
                    onRuntimeControlCommandCompleted?()
                },
                persistStringSetting: { command in
                    await persistStringSetting(key: command.key, value: command.value)
                    onRuntimeControlCommandCompleted?()
                },
                persistBoolSetting: { command in
                    await persistBoolSetting(key: command.key, value: command.value)
                    onRuntimeControlCommandCompleted?()
                },
                scheduleModelPresetSave: { command in
                    scheduleModelPresetSave(key: command.key, value: command.value)
                    onRuntimeControlCommandCompleted?()
                },
                resetUsageStats: {
                    await resetUsageStats()
                    onRuntimeControlCommandCompleted?()
                }
            )
        )
    }

    private var formWithKeyHandlers: some View {
        formContent
        .onChange(of: ollamaURL) { _, newValue in
            guard !isReloadingPersistedState else { return }
            reconcilePreferredProvider()
            Task {
                await persistOllamaEndpoint(newValue)
            }
        }
        .onChange(of: anthropicModelID) { _, newValue in
            guard !isReloadingPersistedState else { return }
            scheduleModelPresetSave(key: SettingsKeys.anthropicModelPreset, value: newValue)
        }
        .onChange(of: openAIModelID) { _, newValue in
            guard !isReloadingPersistedState else { return }
            scheduleModelPresetSave(key: SettingsKeys.openAIModelPreset, value: newValue)
        }
        .onChange(of: geminiModelID) { _, newValue in
            guard !isReloadingPersistedState else { return }
            scheduleModelPresetSave(key: SettingsKeys.geminiModelPreset, value: newValue)
        }
        .onChange(of: openRouterModelID) { _, newValue in
            guard !isReloadingPersistedState else { return }
            scheduleModelPresetSave(key: SettingsKeys.openRouterModelPreset, value: newValue)
        }
        .onChange(of: mistralModelID) { _, newValue in
            guard !isReloadingPersistedState else { return }
            scheduleModelPresetSave(key: SettingsKeys.mistralModelPreset, value: newValue)
        }
        .onChange(of: minimaxModelID) { _, newValue in
            guard !isReloadingPersistedState else { return }
            scheduleModelPresetSave(key: SettingsKeys.minimaxModelPreset, value: newValue)
        }
        .onChange(of: ollamaModelID) { _, newValue in
            guard !isReloadingPersistedState else { return }
            scheduleModelPresetSave(key: SettingsKeys.ollamaModelPreset, value: newValue)
        }
        .onChange(of: selectedProvider) { _, newValue in
            guard !isReloadingPersistedState else { return }
            scheduleModelRefresh(for: newValue)
        }
        .onChange(of: preferredProvider) { _, newValue in
            guard !isReloadingPersistedState else { return }
            guard availableDefaultProviders.contains(newValue) else { return }
            Task {
                await persistStringSetting(key: SettingsKeys.defaultAIProvider, value: newValue.rawValue) {
                    await refreshAIProviders()
                    scheduleModelRefresh(for: newValue)
                }
            }
        }
        .onChange(of: discoverAIEnabled) { _, newValue in
            guard !isReloadingPersistedState else { return }
            guard !newValue || canEnableDiscoverAI else {
                discoverAIEnabled = false
                surfaceError = .unknown(AISettingsPolicy.discoverProviderRequiredMessage)
                return
            }
            Task {
                await persistBoolSetting(key: SettingsKeys.discoverAIRecommendationsEnabled, value: newValue) {
                    NotificationCenter.default.post(name: .discoverAISettingsDidChange, object: nil)
                }
            }
        }
        .onChange(of: aiAutoGenerate) { _, newValue in
            guard !isReloadingPersistedState else { return }
            Task {
                await persistBoolSetting(key: SettingsKeys.aiAutoGenerate, value: newValue) {
                    NotificationCenter.default.post(name: .discoverAISettingsDidChange, object: nil)
                }
            }
        }
        .onChange(of: feedbackScaleMode) { _, newValue in
            guard !isReloadingPersistedState else { return }
            Task {
                await persistStringSetting(
                    key: SettingsKeys.feedbackScaleMode,
                    value: newValue.canonicalMode.rawValue
                ) {
                    NotificationCenter.default.post(name: .tasteProfileDidChange, object: nil)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tasteProfileDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            feedbackReloadTask?.cancel()
            feedbackReloadTask = Task { await loadFeedbackState() }
        }
    }

    @MainActor
    private func flushPendingCloudKeySaves() {
        let shouldFlushAnthropic = anthropicSaveTask != nil
        let shouldFlushOpenAI = openAISaveTask != nil
        let shouldFlushGemini = geminiSaveTask != nil
        let shouldFlushOpenRouter = openRouterSaveTask != nil
        let shouldFlushMistral = mistralSaveTask != nil
        let shouldFlushMiniMax = minimaxSaveTask != nil

        anthropicSaveTask?.cancel()
        anthropicSaveTask = nil
        openAISaveTask?.cancel()
        openAISaveTask = nil
        geminiSaveTask?.cancel()
        geminiSaveTask = nil
        openRouterSaveTask?.cancel()
        openRouterSaveTask = nil
        mistralSaveTask?.cancel()
        mistralSaveTask = nil
        minimaxSaveTask?.cancel()
        minimaxSaveTask = nil

        if shouldFlushAnthropic {
            Task { await persistCloudKey(key: SettingsKeys.anthropicApiKey, value: anthropicKey, provider: .anthropic) }
        }
        if shouldFlushOpenAI {
            Task { await persistCloudKey(key: SettingsKeys.openAIApiKey, value: openAIKey, provider: .openAI) }
        }
        if shouldFlushGemini {
            Task { await persistCloudKey(key: SettingsKeys.geminiApiKey, value: geminiKey, provider: .gemini) }
        }
        if shouldFlushOpenRouter {
            Task { await persistCloudKey(key: SettingsKeys.openRouterApiKey, value: openRouterKey, provider: .openRouter) }
        }
        if shouldFlushMistral {
            Task { await persistCloudKey(key: SettingsKeys.mistralApiKey, value: mistralKey, provider: .mistral) }
        }
        if shouldFlushMiniMax {
            Task { await persistCloudKey(key: SettingsKeys.minimaxApiKey, value: minimaxKey, provider: .minimax) }
        }
    }

    @MainActor
    private func scheduleCloudKeySave(
        task: inout Task<Void, Never>?,
        key: String,
        value: String,
        provider: AIProviderKind
    ) {
        task?.cancel()
        task = Task {
            do {
                try await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await persistCloudKey(key: key, value: value, provider: provider)
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    surfaceError = AppError(error)
                }
            }
        }
    }

    @MainActor
    private func scheduleModelPresetSave(key: String, value: String) {
        modelPresetSaveTasks[key]?.cancel()
        modelPresetSaveTasks[key] = Task {
            do {
                try await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                await persistStringSetting(key: key, value: value) {
                    guard !Task.isCancelled else { return }
                    await refreshAIProviders()
                }
                guard !Task.isCancelled else { return }
                modelPresetSaveTasks[key] = nil
            } catch is CancellationError {
                return
            } catch {
                surfaceError = AppError(error)
            }
        }
    }

    @MainActor
    private func persistCloudKey(key: String, value: String, provider: AIProviderKind) async {
        guard AISettingsPolicy.canStoreCloudCredential(
            for: provider,
            currentConfiguredProviders: configuredCloudProviders(excluding: provider),
            proposedValue: value
        ) else {
            clearCloudKeyDraft(for: provider)
            surfaceError = .unknown(AISettingsPolicy.cloudProviderLimitMessage)
            return
        }

        do {
            try await appState.settingsManager.setString(key: key, value: value)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            await refreshAIProviders()
            if selectedProvider == provider || preferredProvider == provider {
                scheduleModelRefresh(for: provider)
            }
            surfaceError = nil
        } catch {
            surfaceError = AppError(error)
        }
    }

    @MainActor
    private func persistOllamaEndpoint(_ newValue: String) async {
        switch AISettingsPolicy.ollamaEndpointPersistenceDecision(for: newValue) {
        case .persist(let trimmedValue):
            await persistStringSetting(
                key: SettingsKeys.ollamaEndpoint,
                value: trimmedValue
            ) {
                await refreshAIProviders()
                await refreshOllamaModels()
            }
        case .reject(let warningMessage):
            surfaceError = .unknown(warningMessage)
        }
    }

    @MainActor
    private func persistStringSetting(
        key: String,
        value: String,
        postSave: (() async -> Void)? = nil
    ) async {
        do {
            try await appState.settingsManager.setString(key: key, value: value)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            surfaceError = nil
            if let postSave {
                await postSave()
            }
        } catch {
            surfaceError = AppError(error)
        }
    }

    @MainActor
    private func persistBoolSetting(
        key: String,
        value: Bool,
        postSave: (() async -> Void)? = nil
    ) async {
        do {
            try await appState.settingsManager.setBool(key: key, value: value)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            surfaceError = nil
            if let postSave {
                await postSave()
            }
        } catch {
            surfaceError = AppError(error)
        }
    }

    @MainActor
    private func refreshAIProviders() async {
        await appState.configureAIProviders()
        reconcilePreferredProvider()
        NotificationCenter.default.post(name: .discoverAISettingsDidChange, object: nil)
    }

    @MainActor
    private func refreshModels(for provider: AIProviderKind) async {
        guard !Task.isCancelled else { return }
        guard AISettingsPolicy.shouldFetchModels(
            for: provider,
            hasStoredCredential: providerHasKey(provider),
            hasUsableOllamaEndpoint: hasUsableOllamaEndpoint
        ) else {
            return
        }

        isFetchingModels = true
        defer {
            if !Task.isCancelled {
                isFetchingModels = false
            }
        }
        switch provider {
        case .anthropic:
            await refreshAnthropicModels()
        case .openAI:
            await refreshOpenAIModels()
        case .gemini:
            await refreshGeminiModels()
        case .openRouter:
            await refreshOpenRouterModels()
        case .mistral:
            await refreshMistralModels()
        case .minimax:
            await refreshMiniMaxModels()
        case .ollama:
            await refreshOllamaModels()
        case .local:
            break
        }
    }

    @MainActor
    private func scheduleModelRefresh(for provider: AIProviderKind) {
        modelRefreshTask?.cancel()
        modelRefreshTask = Task { await refreshModels(for: provider) }
    }

    @MainActor
    private func schedulePersistedStateReload(refreshRemoteModels: Bool) {
        settingsReloadTask?.cancel()
        settingsReloadTask = Task {
            guard !Task.isCancelled else { return }
            await reloadPersistedState(refreshRemoteModels: refreshRemoteModels)
        }
    }

    // MARK: - Usage & Costs Section

    @ViewBuilder
    private var usageCostsSection: some View {
        Section("Usage & Costs") {
            LabeledContent("Session Cost") {
                Text(AISettingsPolicy.formattedCost(sessionUsage.totalCostUSD))
                    .monospacedDigit()
            }
            LabeledContent("Lifetime Cost") {
                Text(AISettingsPolicy.formattedCost(lifetimeUsage.totalCostUSD))
                    .monospacedDigit()
            }
            LabeledContent("Total Requests") {
                Text("\(lifetimeUsage.requestCount)")
                    .monospacedDigit()
            }

            if !lifetimeUsage.byProvider.isEmpty {
                ForEach(AIProviderKind.allCases) { provider in
                    if let usage = lifetimeUsage.byProvider[provider] {
                        HStack {
                            Text(provider.displayName)
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(AISettingsPolicy.formattedCost(usage.costUSD))
                                    .monospacedDigit()
                                Text("\(usage.requestCount) requests · \(AISettingsPolicy.formattedTokens(usage.inputTokens + usage.outputTokens)) tokens")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            Button("Reset Statistics", role: .destructive) {
                isShowingResetStatisticsConfirmation = true
            }
        }
    }

    private var formContent: some View {
        Form {
            providerSections
            localAndUsageSections
            feedbackSections
            if let surfaceError {
                Section {
                    SettingsErrorBanner(error: surfaceError)
                }
            }
        }
    }

    // MARK: - Form Sections
    @ViewBuilder
    private var providerSections: some View {
        providerSetupSection
        selectedProviderCredentialSection
        activeProviderSection
    }

    @ViewBuilder
    private var localAndUsageSections: some View {
        usageCostsSection
        discoverIntegrationSection
    }

    @ViewBuilder
    private var feedbackSections: some View {
        personalizationFeedbackSection
        likedTitlesSection
        dislikedTitlesSection
        recentRatingsSection
    }

    private var providerSetupSection: some View {
        Section("AI Provider") {
            Picker("Provider to Configure", selection: $selectedProvider) {
                ForEach(AISettingsPolicy.selectableProviders, id: \.self) { provider in
                    Text(providerSelectionLabel(for: provider)).tag(provider)
                }
            }

            LabeledContent("Connected Cloud Providers") {
                Text("\(configuredCloudProviders.count)/\(AISettingsPolicy.maxConfiguredCloudProviders)")
                    .monospacedDigit()
            }

            Text(AISettingsPolicy.providerSetupInstruction)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(configuredCloudProviderSummary)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var activeProviderSection: some View {
        if !availableDefaultProviders.isEmpty {
            Section("Active Provider") {
                if availableDefaultProviders.count == 1, let provider = availableDefaultProviders.first {
                    LabeledContent("Using") {
                        Text(providerSelectionLabel(for: provider))
                    }
                } else {
                    Picker("Use for AI Requests", selection: activeProviderPickerSelection) {
                        ForEach(availableDefaultProviders, id: \.self) { provider in
                            Text(providerSelectionLabel(for: provider)).tag(provider)
                        }
                    }
                }

                if showsProviderFallbackMessage, let resolvedSelectedProvider {
                    Text(
                        "\(providerSelectionLabel(for: preferredProvider)) is unavailable right now. Requests will use \(providerSelectionLabel(for: resolvedSelectedProvider))."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(AISettingsPolicy.activeProviderInstruction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var selectedProviderCredentialSection: some View {
        switch selectedProvider {
        case .anthropic:
            anthropicSection
        case .openAI:
            openAISection
        case .gemini:
            geminiSection
        case .openRouter:
            openRouterSection
        case .mistral:
            mistralSection
        case .minimax:
            minimaxSection
        case .ollama:
            ollamaSection
        case .local:
            localModelsSection
        }
    }

    private var anthropicSection: some View {
        cloudProviderSection(
            provider: .anthropic,
            apiKey: $anthropicKey,
            modelID: $anthropicModelID,
            models: anthropicModels
        )
    }

    private var openAISection: some View {
        cloudProviderSection(
            provider: .openAI,
            apiKey: $openAIKey,
            modelID: $openAIModelID,
            models: openAIModels
        )
    }

    private var geminiSection: some View {
        cloudProviderSection(
            provider: .gemini,
            apiKey: $geminiKey,
            modelID: $geminiModelID,
            models: geminiModels
        )
    }

    private var openRouterSection: some View {
        cloudProviderSection(
            provider: .openRouter,
            apiKey: $openRouterKey,
            modelID: $openRouterModelID,
            models: openRouterModels
        )
    }

    private var mistralSection: some View {
        cloudProviderSection(
            provider: .mistral,
            apiKey: $mistralKey,
            modelID: $mistralModelID,
            models: mistralModels
        )
    }

    private var minimaxSection: some View {
        cloudProviderSection(
            provider: .minimax,
            apiKey: $minimaxKey,
            modelID: $minimaxModelID,
            models: minimaxModels
        )
    }

    @ViewBuilder
    private func cloudProviderSection(
        provider: AIProviderKind,
        apiKey: Binding<String>,
        modelID: Binding<String>,
        models: [AIModelDefinition]
    ) -> some View {
        let isConfigured = providerHasKey(provider)
        let limitReached = cloudCredentialLimitReached(for: provider)
        let state = AISettingsPolicy.cloudProviderSectionState(
            provider: provider,
            isConfigured: isConfigured,
            limitReached: limitReached,
            selectedProvider: selectedProvider,
            preferredProvider: preferredProvider,
            isFetchingModels: isFetchingModels
        )

        Section(providerSelectionLabel(for: provider)) {
            HStack {
                SecureField("API Key", text: apiKey)
                    .disabled(state.disablesCredentialEntry)
                PasteFieldButton { apiKey.wrappedValue = $0 }
                    .disabled(state.disablesCredentialEntry)
                    .accessibilityLabel("Paste \(providerSelectionLabel(for: provider)) API key from clipboard")
                    .accessibilityHint("Pastes the \(providerSelectionLabel(for: provider)) API key into the field.")
            }

            if limitReached, let helperMessage = state.helperMessage {
                Label(helperMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let helperMessage = state.helperMessage {
                Text(helperMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if state.showsModelPicker {
                Picker("Model", selection: modelID) {
                    ForEach(models) { model in
                        Text(modelSelectionLabel(model)).tag(model.id)
                    }
                }

                if state.showsFetchProgress {
                    HStack {
                        ProgressView()
                        Text("Refreshing \(providerSelectionLabel(for: provider)) models...")
                            .foregroundStyle(.secondary)
                    }
                }

                if let modelFetchNote = state.modelFetchNote {
                    Text(modelFetchNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if state.showsActiveProviderBadge {
                    Label("Active provider", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(VPColor.success)
                } else if state.showsUseForRequestsButton {
                    Button {
                        preferredProvider = provider
                    } label: {
                        Label("Use for AI Requests", systemImage: "checkmark.circle")
                    }
                }

                if state.showsDeleteButton {
                    disconnectCloudProviderButton(provider)
                }
            }
        }
    }

    @ViewBuilder
    private var ollamaSection: some View {
        Section("Ollama") {
            TextField("Server URL", text: $ollamaURL)
            if let ollamaEndpointWarningMessage {
                Text(ollamaEndpointWarningMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Plain HTTP is only allowed for localhost and loopback Ollama servers. Remote Ollama endpoints must use HTTPS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("Model", selection: $ollamaModelID) {
                ForEach(ollamaModels) { model in
                    Text(modelSelectionLabel(model)).tag(model.id)
                }
            }
            .disabled(!hasUsableOllamaEndpoint)
        }
    }

    private func disconnectCloudProviderButton(_ provider: AIProviderKind) -> some View {
        Button(role: .destructive) {
            Task { await deleteCloudCredential(for: provider) }
        } label: {
            Label("Delete API Key", systemImage: "trash")
        }
    }

    // MARK: - On-Device Models

    @ViewBuilder
    private var localModelsSection: some View {
        Section("On-Device Models (MLX)") {
            Toggle("Enable Local Inference", isOn: $localModelEnabled)
            Text("Run AI models directly on your device. Free and private — no API key needed.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if localModelEnabled {
                let downloaded = localModels.filter { $0.status == .downloaded }
                if !downloaded.isEmpty {
                    Picker("Active Model", selection: localModelPickerSelection(downloadedModels: downloaded)) {
                        ForEach(downloaded, id: \.id) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                } else {
                    Text("Download at least one model before choosing On-Device as your active provider.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(localModels, id: \.id) { model in
                    localModelRow(model)
                }
            }
        }
    }

    @ViewBuilder
    private func localModelRow(_ model: LocalModelDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "cpu")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.displayName)
                        .font(.headline)
                    Text("\(model.parameterCount) params \u{00B7} \(model.quantization) \u{00B7} \(model.diskSizeMB)MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Context: \(model.effectivePromptCap / 1000)K prompt \u{00B7} RAM: \(model.minMemoryMB)MB min")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                localModelAction(model)
            }

            if model.status == .downloaded {
                Button(role: .destructive) {
                    Task { await appState.localDownloadService.deleteModel(id: model.id) }
                } label: {
                    Label("Delete Model", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            if model.status == .downloading {
                Button("Cancel") {
                    Task { await appState.localDownloadService.cancelDownload(id: model.id) }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func localModelAction(_ model: LocalModelDescriptor) -> some View {
        switch model.status {
        case .downloaded:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(VPColor.success)
        case .downloading:
            VStack(spacing: 4) {
                ProgressView(value: model.downloadProgress)
                    .frame(width: 80)
                Text("\(Int(model.downloadProgress * 100))%")
                    .font(.caption2)
                    .monospacedDigit()
            }
        case .available:
            Button {
                Task { await appState.localDownloadService.downloadModel(id: model.id) }
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
        case .failed, .corrupted:
            Button {
                Task { await appState.localDownloadService.downloadModel(id: model.id) }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        case .paused:
            Button {
                Task { await appState.localDownloadService.downloadModel(id: model.id) }
            } label: {
                Label("Resume", systemImage: "play.circle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
    }

    @MainActor
    private func reloadLocalModels(syncProvider: Bool) async {
        let models = (try? await appState.localCatalogStore.availableModels()) ?? []
        localModels = models

        let downloadedModels = models.filter { $0.status == .downloaded }
        let resolvedLocalModelID = AppState.resolvedLocalModelID(
            preferredModelID: localModelID,
            downloadedModels: downloadedModels
        )

        if let resolvedLocalModelID, resolvedLocalModelID != localModelID {
            localModelID = resolvedLocalModelID
            await persistStringSetting(
                key: SettingsKeys.localModelPreset,
                value: resolvedLocalModelID
            )
        }

        if syncProvider {
            await appState.configureAIProviders()
        }
    }

    private func reconcilePreferredProvider() {
        let reconciled = AISettingsPolicy.reconciledProviderSelection(
            preferredProvider: preferredProvider,
            selectedProvider: selectedProvider,
            availableDefaultProviders: availableDefaultProviders,
            resolvedSelectedProvider: resolvedSelectedProvider
        )
        preferredProvider = reconciled.preferredProvider
        selectedProvider = reconciled.selectedProvider
    }

    private func providerSelectionLabel(for provider: AIProviderKind) -> String {
        AISettingsPolicy.providerSelectionLabel(for: provider)
    }

    private func modelSelectionLabel(_ model: AIModelDefinition) -> String {
        AISettingsPolicy.modelSelectionLabel(model)
    }

    private func providerHasKey(_ provider: AIProviderKind) -> Bool {
        AISettingsPolicy.providerHasStoredCredential(
            provider,
            candidates: cloudCredentialCandidates()
        )
    }

    private func cloudCredentialLimitReached(for provider: AIProviderKind) -> Bool {
        AISettingsPolicy.cloudCredentialLimitReached(
            for: provider,
            candidates: cloudCredentialCandidates()
        )
    }

    private func clearCloudKeyDraft(for provider: AIProviderKind) {
        switch provider {
        case .anthropic:
            anthropicKey = ""
        case .openAI:
            openAIKey = ""
        case .gemini:
            geminiKey = ""
        case .openRouter:
            openRouterKey = ""
        case .mistral:
            mistralKey = ""
        case .minimax:
            minimaxKey = ""
        case .ollama, .local:
            break
        }
    }

    @MainActor
    private func deleteCloudCredential(for provider: AIProviderKind) async {
        let deletedPreferredProvider = preferredProvider == provider

        switch provider {
        case .anthropic:
            anthropicKey = ""
            await persistCloudKey(key: SettingsKeys.anthropicApiKey, value: "", provider: .anthropic)
        case .openAI:
            openAIKey = ""
            await persistCloudKey(key: SettingsKeys.openAIApiKey, value: "", provider: .openAI)
        case .gemini:
            geminiKey = ""
            await persistCloudKey(key: SettingsKeys.geminiApiKey, value: "", provider: .gemini)
        case .openRouter:
            openRouterKey = ""
            await persistCloudKey(key: SettingsKeys.openRouterApiKey, value: "", provider: .openRouter)
        case .mistral:
            mistralKey = ""
            await persistCloudKey(key: SettingsKeys.mistralApiKey, value: "", provider: .mistral)
        case .minimax:
            minimaxKey = ""
            await persistCloudKey(key: SettingsKeys.minimaxApiKey, value: "", provider: .minimax)
        case .ollama, .local:
            break
        }

        let reconciliation = AISettingsPolicy.reconcileSelectionAfterDeletingCredential(
            deletedProvider: provider,
            deletedPreferredProvider: deletedPreferredProvider,
            preferredProvider: preferredProvider,
            selectedProvider: selectedProvider,
            availableDefaultProviders: availableDefaultProviders
        )

        preferredProvider = reconciliation.preferredProvider
        selectedProvider = reconciliation.selectedProvider

        if reconciliation.shouldPersistDefaultProvider {
            await persistStringSetting(key: SettingsKeys.defaultAIProvider, value: preferredProvider.rawValue) {
                await refreshAIProviders()
                scheduleModelRefresh(for: reconciliation.preferredProvider)
            }
        }
    }

    @ViewBuilder
    private var discoverIntegrationSection: some View {
        Section("Discover Integration") {
            Toggle("Show AI Curated Row", isOn: $discoverAIEnabled)
            if !canEnableDiscoverAI {
                Text("Configure at least one AI provider before enabling Discover recommendations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Personalized \u{201C}Curated For You\u{201D} row on the Discover page using your taste profile.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Auto-generate recommendations", isOn: $aiAutoGenerate)
                .disabled(!discoverAIEnabled || !canEnableDiscoverAI)
            Text("When off, shows cached recommendations. Press \u{201C}Regenerate\u{201D} on the Discover page to fetch new ones.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var personalizationFeedbackSection: some View {
        Section("Personalization Feedback") {
            Picker("Rating Scale", selection: $feedbackScaleMode) {
                ForEach(FeedbackScaleMode.selectableCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Text("This scale is used when you rate titles and is sent to AI context.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var likedTitlesSection: some View {
        Section("Liked Titles") {
            if likedTitles.isEmpty {
                Text("No liked titles yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(likedTitles, id: \.self) { title in
                    Text(title)
                }
            }
        }
    }

    @ViewBuilder
    private var dislikedTitlesSection: some View {
        Section("Disliked Titles") {
            if dislikedTitles.isEmpty {
                Text("No disliked titles yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dislikedTitles, id: \.self) { title in
                    Text(title)
                }
            }
        }
    }

    @ViewBuilder
    private var recentRatingsSection: some View {
        Section("Recent Ratings") {
            if recentRatings.isEmpty {
                Text("No ratings yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentRatings, id: \.self) { line in
                    Text(line)
                }
            }
        }
    }

    // MARK: - Model Fetching

    @MainActor
    private func refreshAnthropicModels() async {
        let fetched = await AIModelFetcher.fetchAnthropicModels(apiKey: anthropicKey)
        guard !Task.isCancelled else { return }
        if !fetched.isEmpty {
            anthropicModels = fetched
            ensureSelectionValid(modelID: &anthropicModelID, in: anthropicModels)
        }
    }

    @MainActor
    private func refreshOpenAIModels() async {
        let fetched = await AIModelFetcher.fetchOpenAIModels(apiKey: openAIKey)
        guard !Task.isCancelled else { return }
        if !fetched.isEmpty {
            openAIModels = fetched
            ensureSelectionValid(modelID: &openAIModelID, in: openAIModels)
        }
    }

    @MainActor
    private func refreshGeminiModels() async {
        let fetched = await AIModelFetcher.fetchGeminiModels(apiKey: geminiKey)
        guard !Task.isCancelled else { return }
        if !fetched.isEmpty {
            geminiModels = fetched
            ensureSelectionValid(modelID: &geminiModelID, in: geminiModels)
        }
    }

    @MainActor
    private func refreshOpenRouterModels() async {
        let fetched = await AIModelFetcher.fetchOpenRouterModels(apiKey: openRouterKey)
        guard !Task.isCancelled else { return }
        if !fetched.isEmpty {
            openRouterModels = fetched
            ensureSelectionValid(modelID: &openRouterModelID, in: openRouterModels)
        }
    }

    @MainActor
    private func refreshMistralModels() async {
        let fetched = await AIModelFetcher.fetchMistralModels(apiKey: mistralKey)
        guard !Task.isCancelled else { return }
        if !fetched.isEmpty {
            mistralModels = fetched
            ensureSelectionValid(modelID: &mistralModelID, in: mistralModels)
        }
    }

    @MainActor
    private func refreshMiniMaxModels() async {
        let fetched = await AIModelFetcher.fetchMiniMaxModels(apiKey: minimaxKey)
        guard !Task.isCancelled else { return }
        if !fetched.isEmpty {
            minimaxModels = fetched
            ensureSelectionValid(modelID: &minimaxModelID, in: minimaxModels)
        }
    }

    @MainActor
    private func refreshOllamaModels() async {
        guard hasUsableOllamaEndpoint else { return }

        let fetched = await AIModelFetcher.fetchOllamaModels(baseURL: ollamaURL)
        guard !Task.isCancelled else { return }
        if !fetched.isEmpty {
            ollamaModels = fetched
            ensureSelectionValid(modelID: &ollamaModelID, in: ollamaModels)
        }
    }

    /// Ensures the current selection exists in the model list to avoid invalid Picker tags.
    private func ensureSelectionValid(modelID: inout String, in models: [AIModelDefinition]) {
        modelID = AISettingsPolicy.validModelSelection(currentModelID: modelID, models: models)
    }

    // MARK: - Data Loading

    @MainActor
    private func loadUsageStats() async {
        sessionUsage = (try? await appState.database.fetchAIUsageSummary(since: Self.appLaunchDate)) ?? .empty
        lifetimeUsage = (try? await appState.database.fetchAIUsageSummary()) ?? .empty
    }

    @MainActor
    private func reloadPersistedState(refreshRemoteModels: Bool) async {
        guard !Task.isCancelled else { return }
        isReloadingPersistedState = true
        defer { isReloadingPersistedState = false }

        let storedProviderRawValue = try? await appState.settingsManager.getString(key: SettingsKeys.defaultAIProvider)

        anthropicKey = (try? await appState.settingsManager.getString(key: SettingsKeys.anthropicApiKey)) ?? ""
        openAIKey = (try? await appState.settingsManager.getString(key: SettingsKeys.openAIApiKey)) ?? ""
        geminiKey = (try? await appState.settingsManager.getString(key: SettingsKeys.geminiApiKey)) ?? ""
        openRouterKey = (try? await appState.settingsManager.getString(key: SettingsKeys.openRouterApiKey)) ?? ""
        mistralKey = (try? await appState.settingsManager.getString(key: SettingsKeys.mistralApiKey)) ?? ""
        minimaxKey = (try? await appState.settingsManager.getString(key: SettingsKeys.minimaxApiKey)) ?? ""
        ollamaURL = (try? await appState.settingsManager.getString(key: SettingsKeys.ollamaEndpoint)) ?? "http://localhost:11434"

        let storedAnthropicModel = try? await appState.settingsManager.getString(key: SettingsKeys.anthropicModelPreset)
        let storedOpenAIModel = try? await appState.settingsManager.getString(key: SettingsKeys.openAIModelPreset)
        let storedGeminiModel = try? await appState.settingsManager.getString(key: SettingsKeys.geminiModelPreset)
        let storedOpenRouterModel = try? await appState.settingsManager.getString(key: SettingsKeys.openRouterModelPreset)
        let storedMistralModel = try? await appState.settingsManager.getString(key: SettingsKeys.mistralModelPreset)
        let storedMiniMaxModel = try? await appState.settingsManager.getString(key: SettingsKeys.minimaxModelPreset)
        let storedOllamaModel = try? await appState.settingsManager.getString(key: SettingsKeys.ollamaModelPreset)
        discoverAIEnabled = (try? await appState.settingsManager.getBool(key: SettingsKeys.discoverAIRecommendationsEnabled)) ?? false
        aiAutoGenerate = (try? await appState.settingsManager.getBool(key: SettingsKeys.aiAutoGenerate, default: true)) ?? true
        localModelEnabled = (try? await appState.settingsManager.getBool(key: SettingsKeys.localModelEnabled)) ?? false
        let storedLocalModel = try? await appState.settingsManager.getString(key: SettingsKeys.localModelPreset)
        localModelID = storedLocalModel ?? AIModelCatalog.defaultModel(for: .local)?.id ?? ""

        await reloadLocalModels(syncProvider: true)
        guard !Task.isCancelled else { return }

        let storedPreferredProvider = storedProviderRawValue
            .flatMap(AIProviderKind.init(rawValue:))
            ?? .anthropic
        let storedResolvedSelectedProvider = AIAssistantManager.resolvedDefaultProvider(
            preferredProvider: storedPreferredProvider,
            availableProviders: availableDefaultProviders
        )

        let hydratedState = AISettingsHydrationPolicy.hydratedState(
            preferredProviderRawValue: storedProviderRawValue,
            availableDefaultProviders: availableDefaultProviders,
            resolvedSelectedProvider: storedResolvedSelectedProvider,
            storedAnthropicModelID: storedAnthropicModel,
            storedOpenAIModelID: storedOpenAIModel,
            storedGeminiModelID: storedGeminiModel,
            storedOpenRouterModelID: storedOpenRouterModel,
            storedMistralModelID: storedMistralModel,
            storedMiniMaxModelID: storedMiniMaxModel,
            storedOllamaModelID: storedOllamaModel,
            localModelEnabled: localModelEnabled,
            localModelID: localModelID
        )

        preferredProvider = hydratedState.preferredProvider
        selectedProvider = hydratedState.selectedProvider
        anthropicModelID = hydratedState.modelIDs[.anthropic] ?? AIModelCatalog.defaultModel(for: .anthropic)?.id ?? "claude-sonnet-4-6"
        openAIModelID = hydratedState.modelIDs[.openAI] ?? AIModelCatalog.defaultModel(for: .openAI)?.id ?? "gpt-5.4"
        geminiModelID = hydratedState.modelIDs[.gemini] ?? AIModelCatalog.defaultModel(for: .gemini)?.id ?? "gemini-2.5-flash"
        openRouterModelID = hydratedState.modelIDs[.openRouter] ?? AIModelCatalog.defaultModel(for: .openRouter)?.id ?? ""
        mistralModelID = hydratedState.modelIDs[.mistral] ?? AIModelCatalog.defaultModel(for: .mistral)?.id ?? ""
        minimaxModelID = hydratedState.modelIDs[.minimax] ?? AIModelCatalog.defaultModel(for: .minimax)?.id ?? ""
        ollamaModelID = hydratedState.modelIDs[.ollama] ?? AIModelCatalog.defaultModel(for: .ollama)?.id ?? "llama3.1"
        localModelEnabled = hydratedState.localModelEnabled
        localModelID = hydratedState.localModelID

        await loadFeedbackState()
        guard !Task.isCancelled else { return }
        await loadUsageStats()
        guard !Task.isCancelled else { return }

        if refreshRemoteModels {
            await refreshModels(for: selectedProvider)
        }
    }

    @MainActor
    private func resetUsageStats() async {
        do {
            try await appState.database.deleteAllAIUsageRecords()
            surfaceError = nil
            await loadUsageStats()
        } catch {
            surfaceError = AppError(error)
        }
    }

    @MainActor
    private func loadFeedbackState() async {
        feedbackScaleMode = ((try? await appState.settingsManager.getFeedbackScaleMode()) ?? .likeDislike).canonicalMode

        let events = (try? await appState.database.fetchTasteEvents(eventType: .rated, limit: 400)) ?? []
        let mediaIDs = Set(events.compactMap(\.mediaId))
        var titleByMediaID: [String: String] = [:]
        for mediaID in mediaIDs {
            if let title = try? await appState.database.fetchMediaItemResolvingAliases(id: mediaID)?.title,
               !title.isEmpty {
                titleByMediaID[mediaID] = title
            }
        }

        let summary = AISettingsFeedbackPolicy.feedbackSummary(
            events: events,
            titleByMediaID: titleByMediaID,
            fallbackScaleMode: feedbackScaleMode
        )

        likedTitles = summary.likedTitles
        dislikedTitles = summary.dislikedTitles
        recentRatings = summary.recentRatings
    }

}

private extension String {
    var trimmedForAISettings: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct AISettingsRuntimeControlHandlers: ViewModifier {
    let enabled: Bool
    let persistCloudCredential: @MainActor (AISettingsCloudCredentialRuntimeCommand) async -> Void
    let deleteCloudCredential: @MainActor (AIProviderKind) async -> Void
    let persistOllamaEndpoint: @MainActor (String) async -> Void
    let persistStringSetting: @MainActor (AISettingsStringRuntimeCommand) async -> Void
    let persistBoolSetting: @MainActor (AISettingsBoolRuntimeCommand) async -> Void
    let scheduleModelPresetSave: @MainActor (AISettingsStringRuntimeCommand) -> Void
    let resetUsageStats: @MainActor () async -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .aiSettingsControlPersistCloudCredential)) { notification in
                guard enabled, let command = notification.object as? AISettingsCloudCredentialRuntimeCommand else { return }
                Task {
                    await persistCloudCredential(command)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiSettingsControlDeleteCloudCredential)) { notification in
                guard enabled, let provider = notification.object as? AIProviderKind else { return }
                Task {
                    await deleteCloudCredential(provider)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiSettingsControlPersistOllamaEndpoint)) { notification in
                guard enabled, let value = notification.object as? String else { return }
                Task {
                    await persistOllamaEndpoint(value)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiSettingsControlPersistStringSetting)) { notification in
                guard enabled, let command = notification.object as? AISettingsStringRuntimeCommand else { return }
                Task {
                    await persistStringSetting(command)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiSettingsControlPersistBoolSetting)) { notification in
                guard enabled, let command = notification.object as? AISettingsBoolRuntimeCommand else { return }
                Task {
                    await persistBoolSetting(command)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiSettingsControlScheduleModelPresetSave)) { notification in
                guard enabled, let command = notification.object as? AISettingsStringRuntimeCommand else { return }
                scheduleModelPresetSave(command)
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiSettingsControlResetUsageStats)) { _ in
                guard enabled else { return }
                Task {
                    await resetUsageStats()
                }
            }
    }
}
