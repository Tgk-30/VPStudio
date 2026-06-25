import Foundation
import Testing
@testable import VPStudio

@Suite("SettingsKeys Constants Tests")
struct SettingsKeysConstantsTests {

    @Test("All SettingsKeys are non-empty static constants")
    func allKeysAreNonNil() {
        #expect(!SettingsKeys.omdbApiKey.isEmpty)
        #expect(!SettingsKeys.tmdbApiKey.isEmpty)
        #expect(!SettingsKeys.preferredQuality.isEmpty)
        #expect(!SettingsKeys.subtitleLanguage.isEmpty)
        #expect(!SettingsKeys.audioLanguage.isEmpty)
        #expect(!SettingsKeys.subtitleFontSize.isEmpty)
        #expect(!SettingsKeys.subtitleAutoSearch.isEmpty)
        #expect(!SettingsKeys.openSubtitlesApiKey.isEmpty)
        #expect(!SettingsKeys.autoPlayNext.isEmpty)
        #expect(!SettingsKeys.hardwareDecoding.isEmpty)
        #expect(!SettingsKeys.playerEngineStrategy.isEmpty)
        #expect(!SettingsKeys.externalPlayerApp.isEmpty)
        #expect(!SettingsKeys.externalPlayerURLTemplate.isEmpty)
        #expect(!SettingsKeys.preferCachedStreams.isEmpty)
        #expect(!SettingsKeys.preferAtmosAudio.isEmpty)
        #expect(!SettingsKeys.preferredHDRFormat.isEmpty)
        #expect(!SettingsKeys.defaultDebridService.isEmpty)
    }

    @Test("AI provider keys are non-empty")
    func aiProviderKeys() {
        #expect(!SettingsKeys.openAIApiKey.isEmpty)
        #expect(!SettingsKeys.anthropicApiKey.isEmpty)
        #expect(!SettingsKeys.openRouterApiKey.isEmpty)
        #expect(!SettingsKeys.geminiApiKey.isEmpty)
        #expect(!SettingsKeys.mistralApiKey.isEmpty)
        #expect(!SettingsKeys.minimaxApiKey.isEmpty)
        #expect(!SettingsKeys.ollamaEndpoint.isEmpty)
    }

    @Test("AI model preset keys are non-empty")
    func aiModelPresetKeys() {
        #expect(!SettingsKeys.openAIModelPreset.isEmpty)
        #expect(!SettingsKeys.anthropicModelPreset.isEmpty)
        #expect(!SettingsKeys.openRouterModelPreset.isEmpty)
        #expect(!SettingsKeys.geminiModelPreset.isEmpty)
        #expect(!SettingsKeys.mistralModelPreset.isEmpty)
        #expect(!SettingsKeys.minimaxModelPreset.isEmpty)
        #expect(!SettingsKeys.ollamaModelPreset.isEmpty)
        #expect(!SettingsKeys.defaultAIProvider.isEmpty)
        #expect(!SettingsKeys.aiCompareMode.isEmpty)
        #expect(!SettingsKeys.localModelEnabled.isEmpty)
        #expect(!SettingsKeys.localModelPreset.isEmpty)
    }

    @Test("Trakt keys are non-empty")
    func traktKeys() {
        #expect(!SettingsKeys.traktClientId.isEmpty)
        #expect(!SettingsKeys.traktClientSecret.isEmpty)
        #expect(!SettingsKeys.traktAccessToken.isEmpty)
        #expect(!SettingsKeys.traktRefreshToken.isEmpty)
        #expect(!SettingsKeys.traktAutoScrobble.isEmpty)
        #expect(!SettingsKeys.traktSyncWatchlist.isEmpty)
        #expect(!SettingsKeys.traktSyncHistory.isEmpty)
        #expect(!SettingsKeys.traktSyncRatings.isEmpty)
        #expect(!SettingsKeys.traktLastSyncDate.isEmpty)
        #expect(!SettingsKeys.traktSyncFolders.isEmpty)
    }

    @Test("Simkl keys are non-empty")
    func simklKeys() {
        #expect(!SettingsKeys.simklClientId.isEmpty)
        #expect(!SettingsKeys.simklAccessToken.isEmpty)
        #expect(!SettingsKeys.simklRefreshToken.isEmpty)
    }

    @Test("UI and navigation keys are non-empty")
    func uiNavKeys() {
        #expect(!SettingsKeys.lastSelectedTab.isEmpty)
        #expect(!SettingsKeys.personalizationEnabled.isEmpty)
        #expect(!SettingsKeys.preferredEnvironment.isEmpty)
        #expect(!SettingsKeys.activeEnvironmentSelectionCleared.isEmpty)
        #expect(!SettingsKeys.autoOpenEnvironment.isEmpty)
        #expect(!SettingsKeys.autoSuggestEnvironmentByGenre.isEmpty)
        #expect(!SettingsKeys.feedbackScaleMode.isEmpty)
        #expect(!SettingsKeys.runtimeDiagnosticsEnabled.isEmpty)
        #expect(!SettingsKeys.recentSearches.isEmpty)
        #expect(!SettingsKeys.navigationLayout.isEmpty)
        #expect(!SettingsKeys.discoverAIRecommendationsEnabled.isEmpty)
        #expect(!SettingsKeys.aiAutoGenerate.isEmpty)
        #expect(!SettingsKeys.aiCachedRecommendations.isEmpty)
        #expect(!SettingsKeys.playerDimPassthrough.isEmpty)
        #expect(!SettingsKeys.cinemaAutoDimOnPlay.isEmpty)
    }

    @Test("All keys are unique")
    func allKeysUnique() {
        let allKeys: [String] = [
            SettingsKeys.omdbApiKey, SettingsKeys.tmdbApiKey, SettingsKeys.preferredQuality,
            SettingsKeys.subtitleLanguage, SettingsKeys.audioLanguage,
            SettingsKeys.subtitleFontSize, SettingsKeys.subtitleAutoSearch,
            SettingsKeys.openSubtitlesApiKey, SettingsKeys.autoPlayNext,
            SettingsKeys.hardwareDecoding, SettingsKeys.playerEngineStrategy,
            SettingsKeys.externalPlayerApp, SettingsKeys.externalPlayerURLTemplate,
            SettingsKeys.preferCachedStreams, SettingsKeys.preferAtmosAudio,
            SettingsKeys.preferredHDRFormat, SettingsKeys.defaultDebridService,
            SettingsKeys.openAIApiKey, SettingsKeys.anthropicApiKey,
            SettingsKeys.openRouterApiKey, SettingsKeys.geminiApiKey,
            SettingsKeys.mistralApiKey, SettingsKeys.minimaxApiKey,
            SettingsKeys.mistralModelPreset, SettingsKeys.minimaxModelPreset,
            SettingsKeys.ollamaEndpoint, SettingsKeys.defaultAIProvider,
            SettingsKeys.traktClientId, SettingsKeys.traktClientSecret,
            SettingsKeys.traktAccessToken, SettingsKeys.traktRefreshToken,
            SettingsKeys.simklClientId, SettingsKeys.simklAccessToken,
            SettingsKeys.lastSelectedTab, SettingsKeys.navigationLayout,
            SettingsKeys.activeEnvironmentSelectionCleared,
            SettingsKeys.playerDimPassthrough, SettingsKeys.cinemaAutoDimOnPlay
        ]
        let uniqueKeys = Set(allKeys)
        #expect(uniqueKeys.count == allKeys.count)
    }

    @Test("Keys follow expected naming patterns")
    func keyNamingPatterns() {
        #expect(SettingsKeys.omdbApiKey.hasPrefix("omdb"))
        #expect(SettingsKeys.tmdbApiKey.hasPrefix("tmdb"))
        #expect(SettingsKeys.openAIApiKey.hasPrefix("openai"))
        #expect(SettingsKeys.anthropicApiKey.hasPrefix("anthropic"))
        #expect(SettingsKeys.traktClientId.hasPrefix("trakt"))
        #expect(SettingsKeys.simklClientId.hasPrefix("simkl"))
    }
}
