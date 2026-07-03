import Foundation
import Testing
@testable import VPStudio

@Suite("Static Policy Constant Coverage")
struct StaticPolicyConstantCoverageTests {
    @Test
    func aiProviderResolutionOrderStaysUserPreferredThenLocalFallbacks() {
        #expect(AIAssistantManager.defaultProviderResolutionOrder == [
            .anthropic,
            .openAI,
            .gemini,
            .openRouter,
            .mistral,
            .minimax,
            .ollama,
            .local,
        ])
    }

    @Test
    func discoverTimingAndAICopyConstantsStayStable() {
        #expect(DiscoverHierarchyPolicy.continueWatchingDelay == 0.02)
        #expect(DiscoverHierarchyPolicy.firstCatalogDelay == 0.05)
        #expect(DiscoverHierarchyPolicy.catalogDelayStep == 0.07)
        #expect(DiscoverAICuratedSectionPolicy.helperCopy == "Picked from your watchlist, favorites, ratings, and recent activity.")
        #expect(DiscoverAICuratedSectionPolicy.maxSupportingRecommendations == 3)
    }

    @Test
    func playerAndSearchDefaultsStayStable() {
        #expect(PlayerWatchProgressPolicy.completionThreshold == 0.9)
        #expect(ExploreFilterSheetLanguageSelectionPolicy.defaultLanguageCode == "en-US")
    }

    @Test
    func subtitleDefaultsUseExpectedLanguageAndFontRange() {
        #expect(SubtitleSettingsPolicy.defaultLanguage == "en")
        #expect(SubtitleSettingsPolicy.defaultAutoSearch)
        #expect(SubtitleSettingsPolicy.defaultFontSize == 24)
        #expect(SubtitleSettingsPolicy.minFontSize == 16)
        #expect(SubtitleSettingsPolicy.maxFontSize == 48)
    }

    @Test
    func traktSettingsMessagesStayUserFacing() {
        #expect(TraktSettingsPolicy.connectedStatusMessage == "Connected to Trakt.")
        #expect(TraktSettingsPolicy.authorizationTimedOutMessage == "Authorization timed out. Please try again.")
        #expect(TraktSettingsPolicy.cannotSyncMissingCredentialsMessage == "Cannot sync: Trakt credentials are missing.")
        #expect(TraktSettingsPolicy.missingCredentialsHelpMessage.contains("Enter your Trakt Client ID and Secret"))
    }

    @Test
    func traktHistoryPaginationDefaultsRemainUncapped() {
        #expect(TraktSyncOrchestrator.defaultMaxHistoryPages == nil)
        #expect(TraktSyncOrchestrator.maxHistoryPages == nil)
    }

    @Test
    func externalPlayerPlaceholdersNormalizeRawURLTemplate() {
        #expect(ExternalPlayerRouting.encodedURLPlaceholder == "{url}")
        #expect(ExternalPlayerRouting.rawURLPlaceholder == "{raw_url}")
        #expect(
            ExternalPlayerRouting.normalizedCustomTemplate(" player://open?stream={raw_url} ")
                == "player://open?stream={url}"
        )
    }

    @Test
    func ytsDefaultAPIBaseURLsKeepFallbackOrder() {
        #expect(YTSIndexer.apiBaseURLs == [
            "https://yts.torrentbay.st/api/v2",
            "https://yts.mx/api/v2",
            "https://yts.bz/api/v2",
        ])
    }

    @Test
    func indexerURLSecurityPolicyRecognizesLocalAndPrivateHostsDirectly() {
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("localhost"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("media.localhost"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("[::1]"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("fe80::1"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("fc00::1"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("fd12::1"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("nas.local"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("prowlarr"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("10.0.0.2"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("127.0.0.1"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("172.16.0.1"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("192.168.1.1"))
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("169.254.1.1"))

        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("2001:db8::1") == false)
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("example.com") == false)
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("172.32.0.1") == false)
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("192.169.1.1") == false)
        #expect(IndexerURLSecurityPolicy.isLocalOrPrivateHost("999.1.1.1") == false)
    }
}
