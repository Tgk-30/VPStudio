import Foundation
import Testing
@testable import VPStudio

@Suite("AI Settings Policy")
struct AISettingsPolicyTests {
    @Test func providerSelectionLabelsMatchUserFacingDefaultProviderNames() {
        #expect(AISettingsPolicy.providerSelectionLabel(for: .anthropic) == "Anthropic Claude")
        #expect(AISettingsPolicy.providerSelectionLabel(for: .openAI) == "OpenAI")
        #expect(AISettingsPolicy.providerSelectionLabel(for: .gemini) == "Gemini")
        #expect(AISettingsPolicy.providerSelectionLabel(for: .openRouter) == "OpenRouter")
        #expect(AISettingsPolicy.providerSelectionLabel(for: .mistral) == "Mistral")
        #expect(AISettingsPolicy.providerSelectionLabel(for: .minimax) == "MiniMax")
        #expect(AISettingsPolicy.providerSelectionLabel(for: .ollama) == "Ollama (Local)")
        #expect(AISettingsPolicy.providerSelectionLabel(for: .local) == "On-Device (MLX)")
    }

    @Test func providerSetupUsesCanonicalSelectorOrderAndExplainsKeyThenModelFlow() {
        #expect(AISettingsPolicy.selectableProviders == [.anthropic, .openAI, .gemini, .openRouter, .mistral, .minimax, .ollama, .local])
        #expect(AISettingsPolicy.providerSetupInstruction == "Choose one provider at a time. Add its API key, then choose that provider's model.")
        #expect(AISettingsPolicy.activeProviderInstruction == "Only connected providers appear here. Model selection stays inside each provider setup.")
    }

    @Test func usageFormattersKeepSmallCostsAndLargeTokenCountsReadable() {
        #expect(AISettingsPolicy.formattedCost(0) == "$0.0000")
        #expect(AISettingsPolicy.formattedCost(0.0099) == "$0.0099")
        #expect(AISettingsPolicy.formattedCost(0.01) == "$0.01")
        #expect(AISettingsPolicy.formattedCost(12.345) == "$12.35")

        #expect(AISettingsPolicy.formattedTokens(999) == "999")
        #expect(AISettingsPolicy.formattedTokens(1_000) == "1.0K")
        #expect(AISettingsPolicy.formattedTokens(12_340) == "12.3K")
        #expect(AISettingsPolicy.formattedTokens(1_000_000) == "1.0M")
        #expect(AISettingsPolicy.formattedTokens(1_250_000) == "1.2M")
    }

    @Test func modelSelectionPreservesValidIDAndFallsBackToDefaultThenFirst() {
        let first = model(id: "first", isDefault: false)
        let preferred = model(id: "preferred", isDefault: true)
        let last = model(id: "last", isDefault: false)

        #expect(AISettingsPolicy.validModelSelection(currentModelID: "last", models: [first, preferred, last]) == "last")
        #expect(AISettingsPolicy.validModelSelection(currentModelID: "missing", models: [first, preferred, last]) == "preferred")
        #expect(AISettingsPolicy.validModelSelection(currentModelID: "missing", models: [first, last]) == "first")
        #expect(AISettingsPolicy.validModelSelection(currentModelID: "missing", models: []) == "missing")
    }

    @Test func localModelSelectionAlwaysMatchesVisibleDownloadedPickerTags() {
        let first = downloadedLocalModel(id: "local-ready", isDefault: false)
        let defaultModel = downloadedLocalModel(id: "local-default", isDefault: true)

        #expect(
            AISettingsPolicy.validLocalModelSelection(
                currentModelID: "local-ready",
                downloadedModels: [first, defaultModel]
            ) == "local-ready"
        )
        #expect(
            AISettingsPolicy.validLocalModelSelection(
                currentModelID: "apple/SmolLM2-360M-Instruct-CoreML",
                downloadedModels: [first, defaultModel]
            ) == "local-default"
        )
        #expect(
            AISettingsPolicy.validLocalModelSelection(
                currentModelID: "stale-model",
                downloadedModels: [first]
            ) == "local-ready"
        )
        #expect(
            AISettingsPolicy.validLocalModelSelection(
                currentModelID: "stale-model",
                downloadedModels: []
            ) == "stale-model"
        )
    }

    @Test func discoverProviderRequiredMessageStaysActionable() {
        #expect(AISettingsPolicy.discoverProviderRequiredMessage == "Configure an AI provider before enabling the Discover AI row.")
    }

    @Test func enabledCloudProvidersCapsAtThreeAndIgnoresBlankKeys() {
        let providers = AISettingsPolicy.enabledCloudProviders(
            candidates: [
                (.anthropic, " anthropic-key "),
                (.openAI, "openai-key"),
                (.gemini, ""),
                (.openRouter, "openrouter-key"),
                (.mistral, "mistral-key"),
                (.ollama, "http://localhost:11434"),
            ]
        )

        #expect(providers == [.anthropic, .openAI, .openRouter])
    }

    @Test func enabledCloudProvidersIgnoresLocalProviderCandidates() {
        let providers = AISettingsPolicy.enabledCloudProviders(
            candidates: [
                (.ollama, "http://localhost:11434"),
                (.local, "apple/SmolLM2-360M-Instruct-CoreML"),
                (.anthropic, "anthropic-key"),
                (.openAI, "openai-key"),
            ]
        )

        #expect(providers == [.anthropic, .openAI])
    }

    @Test func enabledCloudProvidersKeepsOpenRouterMistralAndMiniMaxInPriorityOrder() {
        let providers = AISettingsPolicy.enabledCloudProviders(
            candidates: [
                (.minimax, " minimax-key "),
                (.openRouter, "openrouter-key"),
                (.mistral, "mistral-key"),
                (.ollama, "http://localhost:11434"),
            ]
        )

        #expect(providers == [.openRouter, .mistral, .minimax])
    }

    @Test func enabledCloudProvidersDeduplicatesRepeatedCandidatesAndUsesCanonicalCloudPriority() {
        let providers = AISettingsPolicy.enabledCloudProviders(
            candidates: [
                (.mistral, "mistral-key"),
                (.openAI, "openai-key"),
                (.anthropic, "anthropic-key"),
                (.openAI, "replacement-openai-key"),
                (.gemini, "gemini-key"),
                (.minimax, "minimax-key"),
            ]
        )

        #expect(providers == [.anthropic, .openAI, .gemini])
    }

    @Test func configuredCloudProviderSummaryUsesUserFacingNames() {
        #expect(AISettingsPolicy.configuredCloudProviderSummary([]) == "No cloud providers connected")
        #expect(
            AISettingsPolicy.configuredCloudProviderSummary([.anthropic, .mistral, .minimax])
                == "Anthropic Claude, Mistral, MiniMax"
        )
    }

    @Test func providerHasStoredCredentialTreatsWhitespaceOnlyKeyAsMissing() {
        let candidates: [(AIProviderKind, String)] = [
            (.anthropic, "  "),
            (.openAI, " key "),
            (.ollama, "http://localhost:11434"),
        ]

        #expect(AISettingsPolicy.providerHasStoredCredential(.anthropic, candidates: candidates) == false)
        #expect(AISettingsPolicy.providerHasStoredCredential(.openAI, candidates: candidates))
        #expect(AISettingsPolicy.providerHasStoredCredential(.ollama, candidates: candidates) == false)
    }

    @Test func cloudCredentialLimitReachedOnlyBlocksNewCloudProviderWhenThreeOthersConfigured() {
        let candidates: [(AIProviderKind, String)] = [
            (.anthropic, "anthropic-key"),
            (.openAI, "openai-key"),
            (.gemini, "gemini-key"),
            (.openRouter, ""),
            (.mistral, "   "),
        ]

        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .openRouter, candidates: candidates))
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .anthropic, candidates: candidates) == false)
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .mistral, candidates: candidates))
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .ollama, candidates: candidates) == false)
    }

    @Test func cloudCredentialLimitReachedTreatsMiniMaxAndMistralAsNewFourthProviders() {
        let candidates: [(AIProviderKind, String)] = [
            (.anthropic, "anthropic-key"),
            (.openAI, "openai-key"),
            (.gemini, "gemini-key"),
            (.openRouter, ""),
            (.mistral, ""),
            (.minimax, ""),
        ]

        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .openRouter, candidates: candidates))
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .mistral, candidates: candidates))
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .minimax, candidates: candidates))
    }

    @Test func cloudCredentialLimitReachedCountsDistinctConfiguredProvidersWhenCandidateRowsRepeat() {
        let candidates: [(AIProviderKind, String)] = [
            (.openAI, ""),
            (.anthropic, "anthropic-key"),
            (.openAI, "openai-key"),
            (.gemini, "gemini-key"),
            (.openAI, "replacement-openai-key"),
            (.mistral, ""),
        ]

        #expect(AISettingsPolicy.enabledCloudProviders(candidates: candidates) == [.anthropic, .openAI, .gemini])
        #expect(AISettingsPolicy.providerHasStoredCredential(.openAI, candidates: candidates))
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .openAI, candidates: candidates) == false)
        #expect(AISettingsPolicy.cloudCredentialLimitReached(for: .mistral, candidates: candidates))
    }

    @Test func cloudCredentialLimitAllowsDeletingOrEditingExistingProvider() {
        let configured: [AIProviderKind] = [.anthropic, .openAI, .gemini]

        #expect(AISettingsPolicy.canStoreCloudCredential(
            for: .openRouter,
            currentConfiguredProviders: configured,
            proposedValue: ""
        ))
        #expect(AISettingsPolicy.canStoreCloudCredential(
            for: .openAI,
            currentConfiguredProviders: configured,
            proposedValue: "replacement"
        ))
        #expect(!AISettingsPolicy.canStoreCloudCredential(
            for: .openRouter,
            currentConfiguredProviders: configured,
            proposedValue: "new-key"
        ))
    }

    @Test func canStoreCloudCredentialAllowsLocalProvidersAndOnlyBlocksNewFourthCloudProvider() {
        #expect(AISettingsPolicy.canStoreCloudCredential(
            for: .local,
            currentConfiguredProviders: [.anthropic, .openAI, .gemini],
            proposedValue: "local-model"
        ))
        #expect(AISettingsPolicy.canStoreCloudCredential(
            for: .ollama,
            currentConfiguredProviders: [.anthropic, .openAI, .gemini],
            proposedValue: "http://localhost:11434"
        ))
        #expect(AISettingsPolicy.canStoreCloudCredential(
            for: .mistral,
            currentConfiguredProviders: [.anthropic, .openAI],
            proposedValue: "mistral-key"
        ))
        #expect(!AISettingsPolicy.canStoreCloudCredential(
            for: .mistral,
            currentConfiguredProviders: [.anthropic, .openAI, .gemini],
            proposedValue: "mistral-key"
        ))
        #expect(AISettingsPolicy.canStoreCloudCredential(
            for: .openAI,
            currentConfiguredProviders: [.anthropic, .openAI, .gemini],
            proposedValue: "replacement-key"
        ))
    }

    @Test func modelSelectionLabelDisambiguatesSameNamedModelsByProvider() {
        let model = AIModelDefinition(
            id: "mistral-small-latest",
            displayName: "Mistral Small",
            provider: .mistral,
            inputCostPer1MTokens: 0,
            outputCostPer1MTokens: 0,
            maxContextTokens: 1,
            isDefault: true
        )

        #expect(AISettingsPolicy.modelSelectionLabel(model) == "Mistral Small · Mistral")
    }

    @Test func modelSelectionLabelsDisambiguateSameDisplayNameAcrossProviders() {
        let anthropicModel = AIModelDefinition(
            id: "claude-sonnet-4-6",
            displayName: "Shared Model Name",
            provider: .anthropic,
            inputCostPer1MTokens: 0,
            outputCostPer1MTokens: 0,
            maxContextTokens: 1,
            isDefault: true
        )
        let openRouterModel = AIModelDefinition(
            id: "google/gemini-2.5-flash-lite-preview",
            displayName: "Shared Model Name",
            provider: .openRouter,
            inputCostPer1MTokens: 0,
            outputCostPer1MTokens: 0,
            maxContextTokens: 1,
            isDefault: false
        )

        #expect(AISettingsPolicy.modelSelectionLabel(anthropicModel) == "Shared Model Name · Anthropic Claude")
        #expect(AISettingsPolicy.modelSelectionLabel(openRouterModel) == "Shared Model Name · OpenRouter")
    }

    @Test func providerSectionStateKeepsModelSelectionHiddenUntilAKeyIsConfigured() {
        let state = AISettingsPolicy.cloudProviderSectionState(
            provider: .mistral,
            isConfigured: false,
            limitReached: false,
            selectedProvider: .mistral,
            preferredProvider: .openAI,
            isFetchingModels: true
        )

        #expect(state.disablesCredentialEntry == false)
        #expect(state.helperMessage == "Add an API key to unlock model selection for Mistral.")
        #expect(state.showsModelPicker == false)
        #expect(state.showsFetchProgress == false)
        #expect(state.modelFetchNote == nil)
        #expect(state.showsActiveProviderBadge == false)
        #expect(state.showsUseForRequestsButton == false)
        #expect(state.showsDeleteButton == false)
    }

    @Test func providerSectionStateShowsProviderScopedModelPickerAndActiveBadgeWhenConfigured() {
        let state = AISettingsPolicy.cloudProviderSectionState(
            provider: .openRouter,
            isConfigured: true,
            limitReached: false,
            selectedProvider: .openRouter,
            preferredProvider: .openRouter,
            isFetchingModels: true
        )

        #expect(state.disablesCredentialEntry == false)
        #expect(state.helperMessage == nil)
        #expect(state.showsModelPicker)
        #expect(state.showsFetchProgress)
        #expect(state.modelFetchNote == "OpenRouter models load only while OpenRouter is selected. Similar model names stay labeled with their provider.")
        #expect(state.showsActiveProviderBadge)
        #expect(state.showsUseForRequestsButton == false)
        #expect(state.showsDeleteButton)
    }

    @Test func providerSectionStateShowsMistralScopedModelFetchNoteWhenConfigured() {
        let state = AISettingsPolicy.cloudProviderSectionState(
            provider: .mistral,
            isConfigured: true,
            limitReached: false,
            selectedProvider: .mistral,
            preferredProvider: .openAI,
            isFetchingModels: true
        )

        #expect(state.disablesCredentialEntry == false)
        #expect(state.helperMessage == nil)
        #expect(state.showsModelPicker)
        #expect(state.showsFetchProgress)
        #expect(state.modelFetchNote == "Mistral models load only while Mistral is selected and connected.")
        #expect(state.showsActiveProviderBadge == false)
        #expect(state.showsUseForRequestsButton)
        #expect(state.showsDeleteButton)
    }

    @Test func providerSectionStateShowsMiniMaxScopedModelFetchNoteWhenConfigured() {
        let state = AISettingsPolicy.cloudProviderSectionState(
            provider: .minimax,
            isConfigured: true,
            limitReached: false,
            selectedProvider: .minimax,
            preferredProvider: .openAI,
            isFetchingModels: false
        )

        #expect(state.disablesCredentialEntry == false)
        #expect(state.helperMessage == nil)
        #expect(state.showsModelPicker)
        #expect(state.showsFetchProgress == false)
        #expect(state.modelFetchNote == "MiniMax models load only while MiniMax is selected and connected.")
        #expect(state.showsActiveProviderBadge == false)
        #expect(state.showsUseForRequestsButton)
        #expect(state.showsDeleteButton)
    }

    @Test func providerSectionStateOnlyShowsFetchProgressForTheSelectedProvider() {
        let state = AISettingsPolicy.cloudProviderSectionState(
            provider: .minimax,
            isConfigured: true,
            limitReached: false,
            selectedProvider: .mistral,
            preferredProvider: .openAI,
            isFetchingModels: true
        )

        #expect(state.showsModelPicker)
        #expect(state.showsFetchProgress == false)
        #expect(state.modelFetchNote == "MiniMax models load only while MiniMax is selected and connected.")
        #expect(state.showsActiveProviderBadge == false)
        #expect(state.showsUseForRequestsButton)
        #expect(state.showsDeleteButton)
    }

    @Test func providerSectionStateBlocksNewFourthCloudProviderWithoutShowingModelControls() {
        let state = AISettingsPolicy.cloudProviderSectionState(
            provider: .minimax,
            isConfigured: false,
            limitReached: true,
            selectedProvider: .minimax,
            preferredProvider: .anthropic,
            isFetchingModels: false
        )

        #expect(state.disablesCredentialEntry)
        #expect(state.helperMessage == AISettingsPolicy.cloudProviderLimitMessage)
        #expect(state.showsModelPicker == false)
        #expect(state.showsFetchProgress == false)
        #expect(state.modelFetchNote == nil)
        #expect(state.showsUseForRequestsButton == false)
        #expect(state.showsDeleteButton == false)
    }

    @Test func ollamaEndpointPersistenceRejectsMalformedURLsAndRemotePlainHTTP() {
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "not a url")
                == .reject("Enter a valid Ollama server URL.")
        )
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "http://example.com:11434")
                == .reject("Remote Ollama endpoints must use HTTPS. Plain HTTP is only allowed for localhost and loopback addresses.")
        )
    }

    @Test func ollamaEndpointPersistenceAllowsBlankLocalhostAndHTTPS() {
        #expect(AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "   ") == .persist(""))
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: " http://localhost:11434 ")
                == .persist("http://localhost:11434")
        )
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "https://ollama.example.com")
                == .persist("https://ollama.example.com")
        )
    }

    @Test func ollamaEndpointPersistenceAllowsUppercaseLocalhostAndRejectsUppercaseUnsupportedScheme() {
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "HTTP://127.0.0.1:11434")
                == .persist("http://127.0.0.1:11434")
        )
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: " HTTPS://[::1]:11434 ")
                == .persist("https://[::1]:11434")
        )
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "HTTPS://Ollama.Example.Com:11434/api")
                == .persist("https://Ollama.Example.Com:11434/api")
        )
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "HTTP://ollama.example.com:11434")
                == .reject("Remote Ollama endpoints must use HTTPS. Plain HTTP is only allowed for localhost and loopback addresses.")
        )
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "WS://localhost:11434")
                == .reject("Enter a valid Ollama server URL.")
        )
    }

    @Test func ollamaEndpointPersistenceAllowsExpandedLoopbackHosts() {
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "http://127.0.0.42:11434")
                == .persist("http://127.0.0.42:11434")
        )
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "http://[0:0:0:0:0:0:0:1]:11434")
                == .persist("http://[0:0:0:0:0:0:0:1]:11434")
        )
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "http://[0:0:0:0:0:0:0:2]:11434")
                == .reject("Remote Ollama endpoints must use HTTPS. Plain HTTP is only allowed for localhost and loopback addresses.")
        )
    }

    @Test func ollamaEndpointPersistenceRejectsUnsupportedSchemes() {
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "ftp://ollama.example.com:11434")
                == .reject("Enter a valid Ollama server URL.")
        )
        #expect(
            AISettingsPolicy.ollamaEndpointPersistenceDecision(for: "ws://localhost:11434")
                == .reject("Enter a valid Ollama server URL.")
        )
    }

    @Test func providerReconciliationSyncsSelectedProviderWhenMirroringStalePreferred() {
        let reconciled = AISettingsPolicy.reconciledProviderSelection(
            preferredProvider: .openAI,
            selectedProvider: .openAI,
            availableDefaultProviders: [.anthropic],
            resolvedSelectedProvider: .anthropic
        )

        #expect(reconciled.preferredProvider == .anthropic)
        #expect(reconciled.selectedProvider == .anthropic)
    }

    @Test func providerReconciliationPreservesDeliberateProviderConfigurationSelection() {
        let reconciled = AISettingsPolicy.reconciledProviderSelection(
            preferredProvider: .openAI,
            selectedProvider: .mistral,
            availableDefaultProviders: [.anthropic],
            resolvedSelectedProvider: .anthropic
        )

        #expect(reconciled.preferredProvider == .anthropic)
        #expect(reconciled.selectedProvider == .mistral)
    }

    @Test func providerReconciliationLeavesAvailablePreferredProviderUntouched() {
        let reconciled = AISettingsPolicy.reconciledProviderSelection(
            preferredProvider: .openAI,
            selectedProvider: .mistral,
            availableDefaultProviders: [.openAI, .anthropic],
            resolvedSelectedProvider: .openAI
        )

        #expect(reconciled.preferredProvider == .openAI)
        #expect(reconciled.selectedProvider == .mistral)
    }

    @Test func deletingNonPreferredCredentialDoesNotPersistProviderFallback() {
        let reconciliation = AISettingsPolicy.reconcileSelectionAfterDeletingCredential(
            deletedProvider: .gemini,
            deletedPreferredProvider: false,
            preferredProvider: .openAI,
            selectedProvider: .gemini,
            availableDefaultProviders: [.openAI, .anthropic]
        )

        #expect(
            reconciliation == AISettingsPolicy.CredentialDeletionReconciliation(
                preferredProvider: .openAI,
                selectedProvider: .gemini,
                shouldPersistDefaultProvider: false
            )
        )
    }

    @Test func deletingPreferredCredentialFallsBackToFirstAvailableProviderAndUpdatesMirroredSelection() {
        let reconciliation = AISettingsPolicy.reconcileSelectionAfterDeletingCredential(
            deletedProvider: .openAI,
            deletedPreferredProvider: true,
            preferredProvider: .openAI,
            selectedProvider: .openAI,
            availableDefaultProviders: [.gemini, .ollama]
        )

        #expect(
            reconciliation == AISettingsPolicy.CredentialDeletionReconciliation(
                preferredProvider: .gemini,
                selectedProvider: .gemini,
                shouldPersistDefaultProvider: true
            )
        )
    }

    @Test func deletingPreferredCredentialPreservesDeliberateSelectedProvider() {
        let reconciliation = AISettingsPolicy.reconcileSelectionAfterDeletingCredential(
            deletedProvider: .openAI,
            deletedPreferredProvider: true,
            preferredProvider: .openAI,
            selectedProvider: .mistral,
            availableDefaultProviders: [.gemini, .ollama]
        )

        #expect(
            reconciliation == AISettingsPolicy.CredentialDeletionReconciliation(
                preferredProvider: .gemini,
                selectedProvider: .mistral,
                shouldPersistDefaultProvider: true
            )
        )
    }

    @Test func deletingOnlyPreferredCredentialFallsBackToAnthropic() {
        let reconciliation = AISettingsPolicy.reconcileSelectionAfterDeletingCredential(
            deletedProvider: .openAI,
            deletedPreferredProvider: true,
            preferredProvider: .openAI,
            selectedProvider: .openAI,
            availableDefaultProviders: []
        )

        #expect(
            reconciliation == AISettingsPolicy.CredentialDeletionReconciliation(
                preferredProvider: .anthropic,
                selectedProvider: .anthropic,
                shouldPersistDefaultProvider: true
            )
        )
    }

    @Test func activeProviderPickerSelectionNeverUsesUnavailablePreferredProvider() {
        #expect(AISettingsPolicy.validActiveProviderPickerSelection(
            preferredProvider: .anthropic,
            availableDefaultProviders: [.openAI, .ollama],
            resolvedSelectedProvider: .openAI
        ) == .openAI)

        #expect(AISettingsPolicy.validActiveProviderPickerSelection(
            preferredProvider: .openRouter,
            availableDefaultProviders: [.openAI, .openRouter],
            resolvedSelectedProvider: .openAI
        ) == .openRouter)

        #expect(AISettingsPolicy.validActiveProviderPickerSelection(
            preferredProvider: .anthropic,
            availableDefaultProviders: [],
            resolvedSelectedProvider: nil
        ) == .anthropic)
    }

    @Test func activeProviderPickerSelectionUsesAvailablePreferredProviderWithoutResolvedSelection() {
        #expect(AISettingsPolicy.validActiveProviderPickerSelection(
            preferredProvider: .openRouter,
            availableDefaultProviders: [.openRouter],
            resolvedSelectedProvider: nil
        ) == .openRouter)
    }

    @Test func modelFetchingOnlyRunsForConnectedProvidersAndUsableOllamaEndpoints() {
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
    }

    @Test func lazyModelFetchingTreatsEveryCloudProviderAsCredentialGated() {
        for provider in AISettingsPolicy.cloudProviders {
            #expect(AISettingsPolicy.shouldFetchModels(
                for: provider,
                hasStoredCredential: true,
                hasUsableOllamaEndpoint: false
            ))
            #expect(!AISettingsPolicy.shouldFetchModels(
                for: provider,
                hasStoredCredential: false,
                hasUsableOllamaEndpoint: true
            ))
        }
    }

    @Test func deletingThePreferredProviderPersistsTheResolvedFallbackProvider() {
        let reconciliation = AISettingsPolicy.reconcileSelectionAfterDeletingCredential(
            deletedProvider: .openAI,
            deletedPreferredProvider: true,
            preferredProvider: .openAI,
            selectedProvider: .openAI,
            availableDefaultProviders: [.ollama, .local]
        )

        #expect(reconciliation == .init(
            preferredProvider: .ollama,
            selectedProvider: .ollama,
            shouldPersistDefaultProvider: true
        ))
    }

    @Test func deletingThePreferredProviderKeepsTheProviderBeingConfiguredWhenDifferent() {
        let reconciliation = AISettingsPolicy.reconcileSelectionAfterDeletingCredential(
            deletedProvider: .openAI,
            deletedPreferredProvider: true,
            preferredProvider: .openAI,
            selectedProvider: .mistral,
            availableDefaultProviders: [.ollama, .local]
        )

        #expect(reconciliation == .init(
            preferredProvider: .ollama,
            selectedProvider: .mistral,
            shouldPersistDefaultProvider: true
        ))
    }

    @Test func deletingThePreferredProviderFallsBackToAnthropicWhenNoDefaultProvidersRemain() {
        let reconciliation = AISettingsPolicy.reconcileSelectionAfterDeletingCredential(
            deletedProvider: .openAI,
            deletedPreferredProvider: true,
            preferredProvider: .openAI,
            selectedProvider: .openAI,
            availableDefaultProviders: []
        )

        #expect(reconciliation == .init(
            preferredProvider: .anthropic,
            selectedProvider: .anthropic,
            shouldPersistDefaultProvider: true
        ))
    }

    @Test func deletingANonPreferredProviderKeepsCurrentSelectionAndSkipsDefaultPersistence() {
        let reconciliation = AISettingsPolicy.reconcileSelectionAfterDeletingCredential(
            deletedProvider: .mistral,
            deletedPreferredProvider: false,
            preferredProvider: .openAI,
            selectedProvider: .mistral,
            availableDefaultProviders: [.openAI, .ollama]
        )

        #expect(reconciliation == .init(
            preferredProvider: .openAI,
            selectedProvider: .mistral,
            shouldPersistDefaultProvider: false
        ))
    }

    @Suite("AI Settings Hydration Policy")
    struct AISettingsHydrationPolicyTests {
        @Test
        func hydratedStateKeepsProviderSelectorAndModelSelectorsSeparated() {
            let state = AISettingsHydrationPolicy.hydratedState(
                preferredProviderRawValue: AIProviderKind.openAI.rawValue,
                availableDefaultProviders: [.anthropic, .openAI],
                resolvedSelectedProvider: .openAI,
                storedAnthropicModelID: "claude-sonnet-4-6",
                storedOpenAIModelID: "gpt-5.4",
                storedGeminiModelID: nil,
                storedOpenRouterModelID: nil,
                storedMistralModelID: nil,
                storedMiniMaxModelID: nil,
                storedOllamaModelID: nil,
                localModelEnabled: true,
                localModelID: "apple/SmolLM2-360M-Instruct-CoreML"
            )

            #expect(state.preferredProvider == .openAI)
            #expect(state.selectedProvider == .openAI)
            #expect(state.modelIDs[.anthropic] == "claude-sonnet-4-6")
            #expect(state.modelIDs[.openAI] == "gpt-5.4")
            #expect(state.localModelEnabled)
            #expect(state.localModelID == "apple/SmolLM2-360M-Instruct-CoreML")
        }

        @Test
        func hydratedStateFallsBackWhenStoredProviderWasDeleted() {
            let state = AISettingsHydrationPolicy.hydratedState(
                preferredProviderRawValue: AIProviderKind.openAI.rawValue,
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
        }

        @Test
        func hydratedStateKeepsProviderScopedModelsDistinct() {
            let state = AISettingsHydrationPolicy.hydratedState(
                preferredProviderRawValue: AIProviderKind.mistral.rawValue,
                availableDefaultProviders: [.mistral, .openRouter],
                resolvedSelectedProvider: .mistral,
                storedAnthropicModelID: nil,
                storedOpenAIModelID: nil,
                storedGeminiModelID: nil,
                storedOpenRouterModelID: "mistralai/mistral-nemo",
                storedMistralModelID: "mistral-small-latest",
                storedMiniMaxModelID: nil,
                storedOllamaModelID: nil,
                localModelEnabled: nil,
                localModelID: nil
            )

            #expect(state.modelIDs[.mistral] == "mistral-small-latest")
            #expect(state.modelIDs[.openRouter] == "mistralai/mistral-nemo")
        }

        @Test
        func hydratedStateUsesCatalogDefaultsWithoutNeedingRemoteFetches() {
            let state = AISettingsHydrationPolicy.hydratedState(
                preferredProviderRawValue: nil,
                availableDefaultProviders: [],
                resolvedSelectedProvider: nil,
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
            #expect(state.modelIDs[.openAI] == "gpt-5.4")
            #expect(state.modelIDs[.ollama] == "llama3.1")
            #expect(!state.localModelEnabled)
        }

        @Test
        func hydratedStateFallsBackFromInvalidStoredProviderRawValue() {
            let state = AISettingsHydrationPolicy.hydratedState(
                preferredProviderRawValue: "broken-value",
                availableDefaultProviders: [],
                resolvedSelectedProvider: nil,
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
            #expect(state.modelIDs[.openAI] == "gpt-5.4")
            #expect(state.modelIDs[.ollama] == "llama3.1")
        }

        @Test
        func hydratedStateRestoresMiniMaxAndOllamaModelIDs() {
            let state = AISettingsHydrationPolicy.hydratedState(
                preferredProviderRawValue: AIProviderKind.minimax.rawValue,
                availableDefaultProviders: [.minimax],
                resolvedSelectedProvider: .minimax,
                storedAnthropicModelID: nil,
                storedOpenAIModelID: nil,
                storedGeminiModelID: nil,
                storedOpenRouterModelID: nil,
                storedMistralModelID: nil,
                storedMiniMaxModelID: "minimax-m2",
                storedOllamaModelID: "llama3.2",
                localModelEnabled: nil,
                localModelID: nil
            )

            #expect(state.modelIDs[.minimax] == "minimax-m2")
            #expect(state.modelIDs[.ollama] == "llama3.2")
        }
    }

    @Test func providerFirstSettingsVisualContractKeepsCloudChoicesBeforeLocalChoices() {
        #expect(AISettingsPolicy.maxConfiguredCloudProviders == 3)
        #expect(AISettingsPolicy.cloudProviders == [
            .anthropic,
            .openAI,
            .gemini,
            .openRouter,
            .mistral,
            .minimax,
        ])
    }

    @Test func settingsViewKeepsProviderSetupLazyAndFocused() throws {
        let source = try Self.aiSettingsViewSource()

        #expect(source.contains("Picker(\"Provider to Configure\""))
        #expect(source.contains("selectedProviderCredentialSection"))
        #expect(source.contains("Picker(\"Use for AI Requests\""))
        #expect(source.contains("activeProviderPickerSelection"))
        #expect(source.contains(".onChange(of: selectedProvider)"))
        #expect(source.contains("scheduleModelRefresh(for: newValue)"))
        #expect(source.contains("guard !disablesAutomaticTasks else { return }"))
        #expect(source.contains("await reloadPersistedState(refreshRemoteModels: false)"))
        #expect(source.contains("Add an API key to unlock model selection"))
        #expect(source.contains("if state.showsModelPicker {"))
        #expect(source.contains("AISettingsPolicy.cloudProviderLimitMessage"))
        #expect(!source.contains("private func refreshModels() async"))
        #expect(!source.contains("async let openAI"))
        #expect(!source.contains("async let anthropic"))
    }

    private func model(id: String, isDefault: Bool) -> AIModelDefinition {
        AIModelDefinition(
            id: id,
            displayName: id,
            provider: .openAI,
            inputCostPer1MTokens: 0,
            outputCostPer1MTokens: 0,
            maxContextTokens: 1,
            isDefault: isDefault
        )
    }

    private func downloadedLocalModel(id: String, isDefault: Bool) -> LocalModelDescriptor {
        let now = Date(timeIntervalSince1970: 1_000)
        return LocalModelDescriptor(
            id: id,
            displayName: id,
            huggingFaceRepo: id,
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
            downloadedBytes: 700_000_000,
            totalBytes: 700_000_000,
            lastProgressAt: now,
            checksumSHA256: nil,
            validationState: .valid,
            localPath: "/tmp/\(id)",
            partialDownloadPath: nil,
            isDefault: isDefault,
            createdAt: now,
            updatedAt: now
        )
    }

    private static func aiSettingsViewSource() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot.appendingPathComponent(
            "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift"
        )
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
