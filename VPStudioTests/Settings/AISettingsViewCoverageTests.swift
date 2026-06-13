import Foundation
import Testing
@testable import VPStudio

@Suite("AI Settings View Policy Coverage")
struct AISettingsViewCoverageTests {
    @Test
    func providerReconciliationLeavesCurrentSelectionUntouchedWhenNoFallbackExists() {
        let reconciled = AISettingsPolicy.reconciledProviderSelection(
            preferredProvider: .openAI,
            selectedProvider: .mistral,
            availableDefaultProviders: [],
            resolvedSelectedProvider: nil
        )

        #expect(reconciled.preferredProvider == .openAI)
        #expect(reconciled.selectedProvider == .mistral)
    }

    @Test
    func providerFormattingAndSelectorHelpersStayCanonical() {
        #expect(AISettingsPolicy.providerSelectionLabel(for: .mistral) == "Mistral")
        #expect(AISettingsPolicy.providerSelectionLabel(for: .minimax) == "MiniMax")
        #expect(AISettingsPolicy.providerSelectionLabel(for: .local) == "On-Device (MLX)")
        #expect(AISettingsPolicy.selectableProviders == [.anthropic, .openAI, .gemini, .openRouter, .mistral, .minimax, .ollama, .local])

        #expect(AISettingsPolicy.formattedCost(0.0099) == "$0.0099")
        #expect(AISettingsPolicy.formattedCost(0.01) == "$0.01")
        #expect(AISettingsPolicy.formattedTokens(999) == "999")
        #expect(AISettingsPolicy.formattedTokens(1_500) == "1.5K")
        #expect(AISettingsPolicy.formattedTokens(1_500_000) == "1.5M")

        #expect(AISettingsPolicy.configuredCloudProviderSummary([]) == "No cloud providers connected")
        #expect(AISettingsPolicy.configuredCloudProviderSummary([.anthropic, .openAI, .openRouter]) == "Anthropic Claude, OpenAI, OpenRouter")

        #expect(AISettingsPolicy.validActiveProviderPickerSelection(
            preferredProvider: .openAI,
            availableDefaultProviders: [.anthropic, .openAI],
            resolvedSelectedProvider: .anthropic
        ) == .openAI)

        #expect(AISettingsPolicy.validActiveProviderPickerSelection(
            preferredProvider: .openRouter,
            availableDefaultProviders: [.anthropic, .openAI],
            resolvedSelectedProvider: .anthropic
        ) == .anthropic)
    }

    @Test
    func cloudProviderSectionStateCoversConfiguredLimitAndFetchBranches() {
        let limitReached = AISettingsPolicy.cloudProviderSectionState(
            provider: .mistral,
            isConfigured: false,
            limitReached: true,
            selectedProvider: .mistral,
            preferredProvider: .anthropic,
            isFetchingModels: true
        )
        #expect(limitReached.disablesCredentialEntry)
        #expect(limitReached.helperMessage == AISettingsPolicy.cloudProviderLimitMessage)
        #expect(limitReached.showsModelPicker == false)
        #expect(limitReached.showsFetchProgress == false)
        #expect(limitReached.modelFetchNote == nil)
        #expect(limitReached.showsActiveProviderBadge == false)
        #expect(limitReached.showsUseForRequestsButton == false)
        #expect(limitReached.showsDeleteButton == false)

        let configured = AISettingsPolicy.cloudProviderSectionState(
            provider: .openAI,
            isConfigured: true,
            limitReached: false,
            selectedProvider: .openAI,
            preferredProvider: .anthropic,
            isFetchingModels: true
        )
        #expect(configured.disablesCredentialEntry == false)
        #expect(configured.helperMessage == nil)
        #expect(configured.showsModelPicker)
        #expect(configured.showsFetchProgress)
        #expect(configured.modelFetchNote == nil)
        #expect(configured.showsActiveProviderBadge == false)
        #expect(configured.showsUseForRequestsButton)
        #expect(configured.showsDeleteButton)

        let activeOpenRouter = AISettingsPolicy.cloudProviderSectionState(
            provider: .openRouter,
            isConfigured: true,
            limitReached: false,
            selectedProvider: .anthropic,
            preferredProvider: .openRouter,
            isFetchingModels: false
        )
        #expect(activeOpenRouter.helperMessage == nil)
        #expect(activeOpenRouter.modelFetchNote == AISettingsPolicy.modelFetchNote(for: .openRouter))
        #expect(activeOpenRouter.showsActiveProviderBadge)
        #expect(activeOpenRouter.showsUseForRequestsButton == false)
        #expect(activeOpenRouter.showsDeleteButton)

        let unconfigured = AISettingsPolicy.cloudProviderSectionState(
            provider: .gemini,
            isConfigured: false,
            limitReached: false,
            selectedProvider: .anthropic,
            preferredProvider: .anthropic,
            isFetchingModels: false
        )
        #expect(unconfigured.helperMessage == AISettingsPolicy.unconfiguredProviderMessage(for: .gemini))
        #expect(unconfigured.showsModelPicker == false)
        #expect(unconfigured.showsDeleteButton == false)
    }

    @Test
    func ollamaEndpointPersistenceDecisionHandlesWhitespaceLocalAndRemoteInputs() {
        if case .persist(let value) = AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "   ") {
            #expect(value.isEmpty)
        } else {
            #expect(Bool(false), "Whitespace-only Ollama URLs should persist as an empty trimmed value.")
        }

        if case .persist(let value) = AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "http://localhost:11434") {
            #expect(value == "http://localhost:11434")
        } else {
            #expect(Bool(false), "Localhost Ollama URLs should be persisted.")
        }

        if case .reject(let message) = AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "http://example.com:11434") {
            #expect(message.contains("HTTPS"))
        } else {
            #expect(Bool(false), "Remote HTTP Ollama URLs should be rejected.")
        }

        if case .reject(let message) = AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "not-a-url") {
            #expect(message == "Enter a valid Ollama server URL.")
        } else {
            #expect(Bool(false), "Malformed Ollama URLs should be rejected.")
        }
    }

    @Test
    func feedbackSummaryKeepsTitlesDedupedAndPreservesFallbackResolution() {
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let events: [TasteEvent] = [
            TasteEvent(
                id: "liked-1",
                userId: "user",
                mediaId: "media-1",
                eventType: .rated,
                signalStrength: 1,
                feedbackScale: .oneToTen,
                feedbackValue: 9,
                source: .manual,
                metadata: ["title": "  Featured Title  "],
                createdAt: timestamp
            ),
            TasteEvent(
                id: "liked-2",
                userId: "user",
                mediaId: "media-2",
                eventType: .rated,
                signalStrength: 1,
                feedbackScale: .oneToTen,
                feedbackValue: 8,
                source: .manual,
                metadata: ["title": "Featured Title"],
                createdAt: timestamp
            ),
            TasteEvent(
                id: "disliked-1",
                userId: "user",
                mediaId: "media-3",
                eventType: .rated,
                signalStrength: 1,
                feedbackScale: nil,
                feedbackValue: 0,
                source: .ai,
                metadata: [:],
                createdAt: timestamp
            ),
            TasteEvent(
                id: "disliked-2",
                userId: "user",
                mediaId: "media-4",
                eventType: .rated,
                signalStrength: 1,
                feedbackScale: nil,
                feedbackValue: 0,
                source: .ai,
                metadata: [:],
                createdAt: timestamp
            ),
            TasteEvent(
                id: "neutral-1",
                userId: "user",
                mediaId: nil,
                eventType: .rated,
                signalStrength: 1,
                feedbackScale: .oneToTen,
                feedbackValue: 5,
                source: .manual,
                metadata: [:],
                createdAt: timestamp
            ),
        ]

        let summary = AISettingsFeedbackPolicy.feedbackSummary(
            events: events,
            titleByMediaID: [
                "media-3": "  Media Title  ",
                "media-4": "Media Title",
            ],
            fallbackScaleMode: .likeDislike,
            recentLimit: 4
        )

        #expect(summary.likedTitles == ["Featured Title"])
        #expect(summary.dislikedTitles == ["Media Title"])
        #expect(summary.recentRatings == [
            "Featured Title (9/10)",
            "Featured Title (8/10)",
            "Media Title (Disliked)",
            "Unknown title (5/10)",
        ])
    }

    @Test
    func localModelSelectionUsesDownloadedModelFallbacks() {
        let downloadedModels = [
            makeLocalModel(id: "local-available", displayName: "Available Local", status: .downloaded),
            makeLocalModel(id: "local-default", displayName: "Default Local", status: .downloaded, isDefault: true),
        ]

        #expect(AISettingsPolicy.validLocalModelSelection(
            currentModelID: "missing",
            downloadedModels: downloadedModels
        ) == "local-default")

        #expect(AISettingsPolicy.validLocalModelSelection(
            currentModelID: "local-available",
            downloadedModels: downloadedModels
        ) == "local-available")
    }

    @Test
    func deletingThePreferredProviderFallsBackToTheFirstAvailableProvider() {
        let reconciliation = AISettingsPolicy.reconcileSelectionAfterDeletingCredential(
            deletedProvider: .openAI,
            deletedPreferredProvider: true,
            preferredProvider: .openAI,
            selectedProvider: .openAI,
            availableDefaultProviders: [.anthropic, .mistral]
        )

        #expect(reconciliation.preferredProvider == .anthropic)
        #expect(reconciliation.selectedProvider == .anthropic)
        #expect(reconciliation.shouldPersistDefaultProvider)
    }

    private func makeLocalModel(
        id: String,
        displayName: String,
        status: LocalModelStatus,
        progress: Double = 0,
        isDefault: Bool = false
    ) -> LocalModelDescriptor {
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
            downloadProgress: progress,
            downloadedBytes: 0,
            totalBytes: 700_000_000,
            lastProgressAt: now,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: status == .downloaded ? "/tmp/\(id)" : nil,
            partialDownloadPath: status == .paused ? "/tmp/\(id).partial" : nil,
            isDefault: isDefault,
            createdAt: now,
            updatedAt: now
        )
    }
}

#if os(visionOS)
import SwiftUI
import UIKit

@MainActor
@Suite("AI Settings View Vision Coverage", .serialized)
struct AISettingsViewVisionCoverageTests {
    private func waitUntil(
        timeout: Duration = .seconds(1.5),
        condition: @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("waitUntil timed out after \(timeout)")
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test
    func aiSettingsViewHostsBranchHeavyStatesOnVisionOS() async throws {
        let appState = AppState(testHooks: .init())
        let usageByProvider: [AIProviderKind: ProviderUsage] = [
            .anthropic: ProviderUsage(inputTokens: 12_000, outputTokens: 4_000, costUSD: 0.0134, requestCount: 3),
            .openAI: ProviderUsage(inputTokens: 8_000, outputTokens: 2_000, costUSD: 0.0089, requestCount: 2),
        ]
        let populatedUsage = AIUsageSummary(
            totalInputTokens: 20_000,
            totalOutputTokens: 6_000,
            totalCostUSD: 0.0223,
            byProvider: usageByProvider,
            requestCount: 5
        )
        let localModels = [
            makeLocalModel(id: "local-ready", displayName: "Ready Local", status: .downloaded, isDefault: true),
            makeLocalModel(id: "local-downloading", displayName: "Downloading Local", status: .downloading, progress: 0.41),
            makeLocalModel(id: "local-available", displayName: "Available Local", status: .available),
            makeLocalModel(id: "local-failed", displayName: "Failed Local", status: .failed),
            makeLocalModel(id: "local-corrupted", displayName: "Corrupted Local", status: .corrupted),
            makeLocalModel(id: "local-paused", displayName: "Paused Local", status: .paused, progress: 0.24),
        ]

        let views: [(String, AISettingsView)] = [
            (
                "Configured provider can be promoted",
                AISettingsView(
                    initialOpenAIKey: "fixture-openai-key",
                    initialOllamaURL: "http://localhost:11434",
                    initialSelectedProvider: .openAI,
                    initialPreferredProvider: .anthropic,
                    disablesAutomaticTasks: true
                )
            ),
            (
                "Provider limit warning",
                AISettingsView(
                    initialAnthropicKey: "fixture-anthropic-key",
                    initialOpenAIKey: "fixture-openai-key",
                    initialGeminiKey: "fixture-gemini-key",
                    initialSelectedProvider: .mistral,
                    initialPreferredProvider: .anthropic,
                    disablesAutomaticTasks: true
                )
            ),
            (
                "OpenRouter model refresh progress",
                AISettingsView(
                    initialOpenRouterKey: "fixture-openrouter-key",
                    initialSelectedProvider: .openRouter,
                    initialPreferredProvider: .anthropic,
                    initialIsFetchingModels: true,
                    disablesAutomaticTasks: true
                )
            ),
            (
                "Usage and feedback rows",
                AISettingsView(
                    initialAnthropicKey: "fixture-anthropic-key",
                    initialSelectedProvider: .anthropic,
                    initialPreferredProvider: .anthropic,
                    initialSessionUsage: populatedUsage,
                    initialLifetimeUsage: populatedUsage,
                    initialLikedTitles: ["Liked One"],
                    initialDislikedTitles: ["Disliked One"],
                    initialRecentRatings: ["Recent One (9/10)"],
                    disablesAutomaticTasks: true
                )
            ),
            (
                "Discover integration enabled",
                AISettingsView(
                    initialOpenAIKey: "fixture-openai-key",
                    initialSelectedProvider: .openAI,
                    initialPreferredProvider: .openAI,
                    initialDiscoverAIEnabled: true,
                    initialAIAutoGenerate: false,
                    disablesAutomaticTasks: true
                )
            ),
            (
                "Ollama warning branch",
                AISettingsView(
                    initialOllamaURL: "http://example.com:11434",
                    initialSelectedProvider: .ollama,
                    initialPreferredProvider: .ollama,
                    disablesAutomaticTasks: true
                )
            ),
            (
                "Local model actions",
                AISettingsView(
                    initialSelectedProvider: .local,
                    initialPreferredProvider: .local,
                    initialLocalModelEnabled: true,
                    initialLocalModels: localModels,
                    disablesAutomaticTasks: true
                )
            ),
            (
                "Local model enabled without downloaded models",
                AISettingsView(
                    initialSelectedProvider: .local,
                    initialPreferredProvider: .local,
                    initialLocalModelEnabled: true,
                    initialLocalModels: [
                        makeLocalModel(id: "local-waiting", displayName: "Waiting Local", status: .available),
                        makeLocalModel(id: "local-broken", displayName: "Broken Local", status: .failed),
                    ],
                    disablesAutomaticTasks: true
                )
            ),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 760, height: 2_200),
                size: CGSize(width: 980, height: 2_200)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            try await waitUntil {
                hosted.host.view.bounds.width > 0
                    && hosted.host.view.bounds.height > 0
                    && hosted.host.view.subviews.isEmpty == false
            }

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test
    func runtimeControlsPersistCredentialSecurelyAndRejectProviderLimitOverflow() async throws {
        let database = try DatabaseManager(inMemoryNamed: "ai-settings-runtime-credential-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(
            database: database,
            secretStore: AISettingsRuntimeInMemorySecretStore(),
            testHooks: .init()
        )
        let readiness = AISettingsRuntimeReadiness()
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                AISettingsView(
                    disablesAutomaticTasks: true,
                    enablesRuntimeControls: true,
                    onRuntimeControlsReady: { readiness.isReady = true },
                    onRuntimeControlCommandCompleted: { readiness.completedCommandCount += 1 }
                )
            }
            .environment(appState)
            .frame(width: 760, height: 1_600),
            size: CGSize(width: 980, height: 1_600)
        )
        var hostedWindow: UIWindow? = hosted.window
        defer {
            if let hostedWindow {
                tearDownVisionWindow(hostedWindow)
            }
        }
        try await waitForAISettingsRuntimeControlsReady(readiness)

        NotificationCenter.default.post(
            name: .aiSettingsControlPersistCloudCredential,
            object: AISettingsCloudCredentialRuntimeCommand(
                provider: .openRouter,
                value: "fixture-openrouter-runtime-key"
            )
        )
        try await waitForAISettingsRuntimeCommandCompletions(readiness, count: 1)

        try await waitForAISettingsRuntimeCondition {
            try await appState.settingsManager.getString(key: SettingsKeys.openRouterApiKey)
                == "fixture-openrouter-runtime-key"
        }
        let storedReference = try await database.getSetting(key: SettingsKeys.openRouterApiKey)
        #expect(storedReference.flatMap(SecretReference.decode) != nil)
        tearDownVisionWindow(hosted.window)
        hostedWindow = nil

        let limitDatabase = try DatabaseManager(inMemoryNamed: "ai-settings-runtime-limit-\(UUID().uuidString)")
        try await limitDatabase.migrate()
        let limitState = AppState(
            database: limitDatabase,
            secretStore: AISettingsRuntimeInMemorySecretStore(),
            testHooks: .init()
        )
        let limitReadiness = AISettingsRuntimeReadiness()
        let limitHosted = try hostInVisibleVisionWindow(
            NavigationStack {
                AISettingsView(
                    initialAnthropicKey: "fixture-anthropic-key",
                    initialOpenAIKey: "fixture-openai-key",
                    initialGeminiKey: "fixture-gemini-key",
                    initialMiniMaxKey: "draft-minimax-key",
                    initialSelectedProvider: .minimax,
                    disablesAutomaticTasks: true,
                    enablesRuntimeControls: true,
                    onRuntimeControlsReady: { limitReadiness.isReady = true },
                    onRuntimeControlCommandCompleted: { limitReadiness.completedCommandCount += 1 }
                )
            }
            .environment(limitState)
            .frame(width: 760, height: 1_600),
            size: CGSize(width: 980, height: 1_600)
        )
        defer { tearDownVisionWindow(limitHosted.window) }
        try await waitForAISettingsRuntimeControlsReady(limitReadiness)

        NotificationCenter.default.post(
            name: .aiSettingsControlPersistCloudCredential,
            object: AISettingsCloudCredentialRuntimeCommand(
                provider: .minimax,
                value: "fixture-minimax-over-limit"
            )
        )
        try await waitForAISettingsRuntimeCommandCompletions(limitReadiness, count: 1)

        try await waitForAISettingsRuntimeCondition(timeout: 4) {
            try await limitState.settingsManager.getString(key: SettingsKeys.minimaxApiKey) == nil
        }
        #expect(try await limitState.settingsManager.getString(key: SettingsKeys.minimaxApiKey) == nil)
    }

    @Test
    func runtimeControlsDeleteCredentialAndReconcileDefaultProvider() async throws {
        let database = try DatabaseManager(inMemoryNamed: "ai-settings-runtime-delete-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(
            database: database,
            secretStore: AISettingsRuntimeInMemorySecretStore(),
            testHooks: .init()
        )
        try await appState.settingsManager.setString(key: SettingsKeys.anthropicApiKey, value: "fixture-anthropic-key")
        try await appState.settingsManager.setString(key: SettingsKeys.openAIApiKey, value: "fixture-openai-key")
        try await appState.settingsManager.setString(key: SettingsKeys.defaultAIProvider, value: AIProviderKind.openAI.rawValue)

        let readiness = AISettingsRuntimeReadiness()
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                AISettingsView(
                    initialAnthropicKey: "fixture-anthropic-key",
                    initialOpenAIKey: "fixture-openai-key",
                    initialSelectedProvider: .openAI,
                    initialPreferredProvider: .openAI,
                    disablesAutomaticTasks: true,
                    enablesRuntimeControls: true,
                    onRuntimeControlsReady: { readiness.isReady = true },
                    onRuntimeControlCommandCompleted: { readiness.completedCommandCount += 1 }
                )
            }
            .environment(appState)
            .frame(width: 760, height: 1_600),
            size: CGSize(width: 980, height: 1_600)
        )
        defer { tearDownVisionWindow(hosted.window) }
        try await waitForAISettingsRuntimeControlsReady(readiness)

        NotificationCenter.default.post(
            name: .aiSettingsControlDeleteCloudCredential,
            object: AIProviderKind.openAI
        )
        try await waitForAISettingsRuntimeCommandCompletions(readiness, count: 1)

        try await waitForAISettingsRuntimeCondition {
            let openAIKey = try await appState.settingsManager.getString(key: SettingsKeys.openAIApiKey)
            let preferredProvider = try await appState.settingsManager.getString(key: SettingsKeys.defaultAIProvider)
            return openAIKey == nil && preferredProvider == AIProviderKind.anthropic.rawValue
        }
    }

    @Test
    func runtimeControlsPersistSettingsModelPresetsAndResetUsage() async throws {
        let database = try DatabaseManager(inMemoryNamed: "ai-settings-runtime-settings-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(
            database: database,
            secretStore: AISettingsRuntimeInMemorySecretStore(),
            testHooks: .init()
        )
        try await database.saveAIUsageRecord(
            AIUsageRecord(
                provider: .openAI,
                model: "gpt-fixture",
                inputTokens: 100,
                outputTokens: 40,
                estimatedCostUSD: 0.01,
                requestType: .ask
            )
        )

        let readiness = AISettingsRuntimeReadiness()
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                AISettingsView(
                    disablesAutomaticTasks: true,
                    enablesRuntimeControls: true,
                    onRuntimeControlsReady: { readiness.isReady = true },
                    onRuntimeControlCommandCompleted: { readiness.completedCommandCount += 1 }
                )
            }
            .environment(appState)
            .frame(width: 760, height: 1_600),
            size: CGSize(width: 980, height: 1_600)
        )
        defer { tearDownVisionWindow(hosted.window) }
        try await waitForAISettingsRuntimeControlsReady(readiness)

        NotificationCenter.default.post(
            name: .aiSettingsControlPersistOllamaEndpoint,
            object: "   "
        )
        NotificationCenter.default.post(
            name: .aiSettingsControlPersistStringSetting,
            object: AISettingsStringRuntimeCommand(
                key: SettingsKeys.feedbackScaleMode,
                value: FeedbackScaleMode.fiveStar.rawValue
            )
        )
        NotificationCenter.default.post(
            name: .aiSettingsControlPersistBoolSetting,
            object: AISettingsBoolRuntimeCommand(
                key: SettingsKeys.discoverAIRecommendationsEnabled,
                value: true
            )
        )
        NotificationCenter.default.post(
            name: .aiSettingsControlScheduleModelPresetSave,
            object: AISettingsStringRuntimeCommand(
                key: SettingsKeys.openAIModelPreset,
                value: "gpt-runtime-preset"
            )
        )
        try await waitForAISettingsRuntimeCommandCompletions(readiness, count: 4)

        try await waitForAISettingsRuntimeCondition {
            let ollamaEndpoint = try await appState.settingsManager.getString(key: SettingsKeys.ollamaEndpoint)
            let scaleMode = try await appState.settingsManager.getString(key: SettingsKeys.feedbackScaleMode)
            let discoverEnabled = try await appState.settingsManager.getBool(key: SettingsKeys.discoverAIRecommendationsEnabled)
            let preset = try await appState.settingsManager.getString(key: SettingsKeys.openAIModelPreset)
            return ollamaEndpoint == ""
                && scaleMode == FeedbackScaleMode.fiveStar.rawValue
                && discoverEnabled
                && preset == "gpt-runtime-preset"
        }

        NotificationCenter.default.post(name: .aiSettingsControlResetUsageStats, object: nil)
        try await waitForAISettingsRuntimeCommandCompletions(readiness, count: 5)

        try await waitForAISettingsRuntimeCondition {
            try await database.fetchAIUsageRecords().isEmpty
        }
    }

    private func makeLocalModel(
        id: String,
        displayName: String,
        status: LocalModelStatus,
        progress: Double = 0,
        isDefault: Bool = false
    ) -> LocalModelDescriptor {
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
            downloadProgress: progress,
            downloadedBytes: 0,
            totalBytes: 700_000_000,
            lastProgressAt: now,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: status == .downloaded ? "/tmp/\(id)" : nil,
            partialDownloadPath: status == .paused ? "/tmp/\(id).partial" : nil,
            isDefault: isDefault,
            createdAt: now,
            updatedAt: now
        )
    }
}

@MainActor
private final class AISettingsRuntimeReadiness {
    var isReady = false
    var completedCommandCount = 0
}

@MainActor
private func waitForAISettingsRuntimeControlsReady(
    _ readiness: AISettingsRuntimeReadiness,
    timeout: TimeInterval = 2
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if readiness.isReady {
            return
        }
        try await Task.sleep(for: .milliseconds(20))
    }
    Issue.record("Timed out waiting for AI settings runtime controls to become ready.")
}

@MainActor
private func waitForAISettingsRuntimeCommandCompletions(
    _ readiness: AISettingsRuntimeReadiness,
    count: Int,
    timeout: TimeInterval = 2
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if readiness.completedCommandCount >= count {
            return
        }
        try await Task.sleep(for: .milliseconds(20))
    }
    Issue.record("Timed out waiting for \(count) AI settings runtime command completions.")
}

private func waitForAISettingsRuntimeCondition(
    timeout: TimeInterval = 2,
    condition: @escaping () async throws -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if try await condition() {
            return
        }
        try await Task.sleep(for: .milliseconds(20))
    }
    Issue.record("Timed out waiting for AI settings runtime condition.")
}

private actor AISettingsRuntimeInMemorySecretStore: SecretStore {
    private var secrets: [String: String] = [:]

    func setSecret(_ secret: String, for key: String) async throws {
        secrets[key] = secret
    }

    func getSecret(for key: String) async throws -> String? {
        secrets[key]
    }

    func deleteSecret(for key: String) async throws {
        secrets.removeValue(forKey: key)
    }

    func deleteAllSecrets() async throws {
        secrets.removeAll()
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
