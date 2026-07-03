import Foundation
import Testing
@testable import VPStudio

@Suite("Presentation Support Value Coverage")
struct PresentationSupportValueCoverageTests {
    @Test
    func discoverSupportValuesExposeStableIdentifiersAndModes() {
        let preview = MediaPreview(
            id: "series-tmdb-95396",
            type: .series,
            title: "Severance",
            year: 2022,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: 8.7,
            tmdbId: 95_396,
            episodeId: "s1e1",
            seasonNumber: 1,
            episodeNumber: 1
        )
        let rowSpec = DiscoverMediaRowSpec(
            id: "trending-shows",
            title: "Trending TV Shows",
            symbol: "tv",
            items: [preview],
            animationDelay: 0.12
        )
        let route = DiscoverDetailRoute(
            preview: preview,
            initialAction: .resumePlayback
        )
        let loadingMode: DiscoverLoadingPresentationMode = .refreshingRetainedContent
        let presentation: DiscoverErrorPresentation = DiscoverErrorPresentationPolicy.presentation(
            for: .metadataSetupRequired(feature: "Discover")
        )

        #expect(rowSpec.id == "trending-shows")
        #expect(rowSpec.items == [preview])
        #expect(route.id == "series-tmdb-95396-s1e1-resumePlayback")
        #expect(loadingMode == .refreshingRetainedContent)
        #expect(presentation.isSetupError)
    }

    @Test
    func navigationDownloadsSettingsAndExternalPlayerSupportValuesRemainEquatable() {
        let bottomAction: BottomTabAction = BottomTabRoutingPolicy.action(
            for: .environments,
            opensEnvironmentPicker: true
        )
        let downloadsMode: DownloadsErrorSurfaceMode = DownloadsErrorSurfacePolicy.presentationMode(
            groupCount: 2,
            hasRootError: true
        )
        let settingsKind: SettingsStatusKind = .warning
        let settingsGroup = SettingsDestinationGroup(
            category: .connect,
            destinations: [.debrid, .metadata]
        )
        let validation: ExternalPlayerTemplateValidation = ExternalPlayerRouting.validationResult(
            forCustomTemplate: "player://open?url={url}"
        )

        #expect(bottomAction == .openEnvironmentPicker)
        #expect(downloadsMode == .inlineError)
        #expect(settingsKind == .warning)
        #expect(settingsGroup.id == .connect)
        #expect(settingsGroup == SettingsDestinationGroup(category: .connect, destinations: [.debrid, .metadata]))
        #expect(validation == .valid)
    }

    @Test
    func librarySupportValuesPreserveKindsAndFeedbackPriority() {
        let actions: [LibraryHeaderActionSpec] = LibraryActionRowPolicy.actions(
            selectedList: .history,
            isRefreshing: false
        )
        let feedback: LibraryFeedbackMessage? = LibraryFeedbackPresentationPolicy.message(
            statusMessage: "Refresh complete",
            actionError: nil
        )

        #expect(actions.map(\.kind) == [.sort, .export, .import, .refresh])
        #expect(actions.last?.id == .refresh)
        #expect(actions.last?.isEnabled == false)
        #expect(feedback == .status("Refresh complete"))
    }

    @Test
    func searchLoadingModeAndStreamRefreshPlanExposeExpectedCases() {
        let searchMode: SearchLoadingPresentationMode = SearchLoadingPresentationPolicy.presentationMode(
            explorePhase: .searching,
            resultCount: 1,
            aiRecommendationCount: 0
        )
        let refreshedURL = URL(string: "https://qa.example.com/fresh.mp4")!
        let stream = Fixtures.stream(
            url: "https://qa.example.com/expired.mp4",
            debridService: "qa-sample"
        )
        let refreshPlan: PlayerStreamLinkRefreshPlan? = PlayerStreamLinkRecovery.refreshPlan(
            for: stream,
            priorAttempts: 0,
            qaRefreshURL: refreshedURL
        )

        #expect(searchMode == .refreshingRetainedResults)
        guard case let .replace(replacement)? = refreshPlan else {
            Issue.record("Expected a replacement stream refresh plan")
            return
        }
        #expect(replacement.streamURL == refreshedURL)
    }
}
