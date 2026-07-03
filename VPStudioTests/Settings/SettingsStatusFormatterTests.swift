import Testing
@testable import VPStudio

struct SettingsStatusFormatterTests {
    @Test
    func debridStatusReflectsActiveServiceCount() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.activeDebridCount = 2

        let status = SettingsStatusFormatter.status(for: .debrid, snapshot: snapshot)
        #expect(status.kind == .positive)
        #expect(status.message == "2 active services")
    }

    @Test
    func statusSummariesUseSingularLabelsForSingleConfiguredItem() {
        var snapshot = SettingsStatusSnapshot()

        snapshot.activeDebridCount = 1
        let debridStatus = SettingsStatusFormatter.status(for: .debrid, snapshot: snapshot)
        #expect(debridStatus.kind == .positive)
        #expect(debridStatus.message == "1 active service")

        snapshot.activeIndexerCount = 1
        let indexerStatus = SettingsStatusFormatter.status(for: .indexers, snapshot: snapshot)
        #expect(indexerStatus.kind == .positive)
        #expect(indexerStatus.message == "1 active indexer")

        snapshot.environmentAssetCount = 1
        let environmentStatus = SettingsStatusFormatter.status(for: .environments, snapshot: snapshot)
        #expect(environmentStatus.kind == .positive)
        #expect(environmentStatus.message == "1 asset")
    }

    @Test
    func debridStatusWarnsWhenNoServicesAreActive() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.activeDebridCount = 0

        let status = SettingsStatusFormatter.status(for: .debrid, snapshot: snapshot)

        #expect(status.kind == .warning)
        #expect(status.message == "Not configured")
    }

    @Test
    func indexerStatusWarnsWhenNoIndexersAreActive() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.activeIndexerCount = 0

        let status = SettingsStatusFormatter.status(for: .indexers, snapshot: snapshot)

        #expect(status.kind == .warning)
        #expect(status.message == "No active indexers")
    }

    @Test
    func indexerStatusUsesPluralLabelForMultipleActiveIndexers() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.activeIndexerCount = 3

        let status = SettingsStatusFormatter.status(for: .indexers, snapshot: snapshot)

        #expect(status.kind == .positive)
        #expect(status.message == "3 active indexers")
    }

    @Test
    func metadataStatusWarnsWhenMetadataMissing() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.hasMetadataKey = false

        let status = SettingsStatusFormatter.status(for: .metadata, snapshot: snapshot)
        #expect(status.kind == .warning)
        #expect(status.message == "OMDb key required")
    }

    @Test
    func metadataStatusIsPositiveWhenMetadataIsConfigured() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.hasMetadataKey = true
        snapshot.metadataProviderSummary = "OMDb + legacy TMDb fallback"

        let status = SettingsStatusFormatter.status(for: .metadata, snapshot: snapshot)

        #expect(status.kind == .positive)
        #expect(status.message == "OMDb + legacy TMDb fallback")
    }

    @Test
    func aiStatusUsesSelectedProviderRequirements() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.aiProvider = .openAI
        snapshot.hasOllamaEndpoint = true

        let warningStatus = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(warningStatus.kind == .warning)
        #expect(warningStatus.message == "Using Ollama")

        snapshot.hasOpenAIKey = true
        let okStatus = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(okStatus.kind == .positive)
        #expect(okStatus.message == "OpenAI configured")
    }

    @Test
    func aiStatusUsesOpenRouterCredentialsWhenSelected() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.aiProvider = .openRouter
        snapshot.hasOpenRouterKey = false
        snapshot.hasOllamaEndpoint = false

        let warningStatus = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(warningStatus.kind == .neutral)
        #expect(warningStatus.message == "OpenRouter not set")

        snapshot.hasOpenRouterKey = true
        let okStatus = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(okStatus.kind == .positive)
        #expect(okStatus.message == "OpenRouter configured")
    }

    @Test
    func aiStatusTreatsLocalAsConfiguredOnlyWhenEnabledAndUsable() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.aiProvider = .local
        snapshot.isLocalAIEnabled = false
        snapshot.hasUsableLocalModel = false
        snapshot.hasOllamaEndpoint = false

        let disabledStatus = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(disabledStatus.kind == .neutral)
        #expect(disabledStatus.message == "On-Device (Local) is disabled")

        snapshot.isLocalAIEnabled = true
        let missingModelStatus = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(missingModelStatus.kind == .neutral)
        #expect(missingModelStatus.message == "On-Device (Local) needs a downloaded model")

        snapshot.hasUsableLocalModel = true
        let readyStatus = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(readyStatus.kind == .positive)
        #expect(readyStatus.message == "On-Device (Local) configured")
    }

    @Test
    func aiStatusWarnsWhenStoredProviderFallsBackToConfiguredRuntimeProvider() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.aiProvider = .ollama
        snapshot.hasOllamaEndpoint = true
        snapshot.hasOpenAIKey = true

        let status = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)
        #expect(status.kind == .positive)
        #expect(status.message == "Ollama configured")
    }

    @Test
    func aiStatusAppliesCloudProviderCapBeforeResolvingStoredProvider() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.aiProvider = .minimax
        snapshot.hasOllamaEndpoint = false
        snapshot.hasAnthropicKey = true
        snapshot.hasOpenAIKey = true
        snapshot.hasGeminiKey = true
        snapshot.hasMiniMaxKey = true

        let status = SettingsStatusFormatter.status(for: .ai, snapshot: snapshot)

        #expect(status.kind == .warning)
        #expect(status.message == "Using Anthropic")
    }

    @Test
    func environmentsStatusUsesAppleEnvironmentWhenNoneImported() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.environmentAssetCount = 0

        let status = SettingsStatusFormatter.status(for: .environments, snapshot: snapshot)
        #expect(status.kind == .neutral)
        #expect(status.message == "Apple Environment available")
    }

    @Test
    func environmentsStatusUsesPluralAssetCount() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.environmentAssetCount = 2

        let status = SettingsStatusFormatter.status(for: .environments, snapshot: snapshot)

        #expect(status.kind == .positive)
        #expect(status.message == "2 assets")
    }

    @Test
    func subtitlesStatusFallsBackToLocalOnlyWhenOpenSubtitlesMissing() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.hasOpenSubtitlesKey = false

        let status = SettingsStatusFormatter.status(for: .subtitles, snapshot: snapshot)

        #expect(status.kind == .neutral)
        #expect(status.message == "Local subtitles only")
    }

    @Test
    func subtitlesStatusIsPositiveWhenOpenSubtitlesIsConfigured() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.hasOpenSubtitlesKey = true

        let status = SettingsStatusFormatter.status(for: .subtitles, snapshot: snapshot)

        #expect(status.kind == .positive)
        #expect(status.message == "OpenSubtitles enabled")
    }

    @Test
    func fixedNeutralDestinationStatusesRemainStable() {
        let snapshot = SettingsStatusSnapshot()
        let cases: [(SettingsDestination, String)] = [
            (.imdbImport, "CSV import via IMDb exports"),
            (.player, "Playback preferences"),
            (.library, "Browse your library"),
            (.downloads, "Manage downloads"),
            (.resetData, "Erase all app data"),
            (.testMode, "10 screens to preview")
        ]

        for (destination, expectedMessage) in cases {
            let status = SettingsStatusFormatter.status(for: destination, snapshot: snapshot)

            #expect(status.kind == .neutral)
            #expect(status.message == expectedMessage)
        }
    }

    @Test
    func simklStatusIsNeutralEvenWithoutCredentials() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.hasSimklCredentials = false

        let status = SettingsStatusFormatter.status(for: .simkl, snapshot: snapshot)

        #expect(status.kind == .neutral)
        #expect(status.message == "Unavailable in this build")
    }

    @Test
    func syncStatusTracksRuntimeConnectionAndSavedAuthorization() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.hasTraktCredentials = false
        snapshot.hasSimklCredentials = true

        let traktStatus = SettingsStatusFormatter.status(for: .trakt, snapshot: snapshot)
        let simklStatus = SettingsStatusFormatter.status(for: .simkl, snapshot: snapshot)

        #expect(traktStatus.kind == .neutral)
        #expect(traktStatus.message == "Optional")
        #expect(simklStatus.kind == .neutral)
        #expect(simklStatus.message == "Unavailable in this build")
    }

    @Test
    func traktStatusOnlyShowsConnectedForAnActiveSession() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.hasTraktCredentials = true

        let readyStatus = SettingsStatusFormatter.status(for: .trakt, snapshot: snapshot)
        #expect(readyStatus.kind == .neutral)
        #expect(readyStatus.message == "Ready to connect")

        snapshot.hasTraktConnection = true
        let connectedStatus = SettingsStatusFormatter.status(for: .trakt, snapshot: snapshot)
        #expect(connectedStatus.kind == .positive)
        #expect(connectedStatus.message == "Connected")
    }
}
