import Foundation
import Testing
@testable import VPStudio

@Suite("Detail Series Content Coverage")
struct DetailSeriesContentCoverageTests {
    @Test
    func primaryPlayPolicyCoversMovieSeriesAndBusyStates() {
        #expect(SeriesPrimaryPlayPolicy.noStreamsMessage == "No streams found for this episode. Try another episode or result.")
        #expect(SeriesPrimaryPlayPolicy.selectEpisodeLabel == "Select Episode")

        #expect(SeriesPrimaryPlayPolicy.isBusy(isLocalPlayLoading: true, isPlayerOpening: false, isLoadingSeasonEpisodes: false))
        #expect(SeriesPrimaryPlayPolicy.isBusy(isLocalPlayLoading: false, isPlayerOpening: true, isLoadingSeasonEpisodes: false))
        #expect(SeriesPrimaryPlayPolicy.isBusy(isLocalPlayLoading: false, isPlayerOpening: false, isLoadingSeasonEpisodes: true))
        #expect(SeriesPrimaryPlayPolicy.isBusy(isLocalPlayLoading: false, isPlayerOpening: false, isLoadingSeasonEpisodes: false) == false)

        #expect(SeriesPrimaryPlayPolicy.isEnabled(mediaType: .movie, hasSelectedEpisode: false, isBusy: false))
        #expect(SeriesPrimaryPlayPolicy.isEnabled(mediaType: .series, hasSelectedEpisode: true, isBusy: false))
        #expect(SeriesPrimaryPlayPolicy.isEnabled(mediaType: .series, hasSelectedEpisode: false, isBusy: false) == false)
        #expect(SeriesPrimaryPlayPolicy.isEnabled(mediaType: .movie, hasSelectedEpisode: true, isBusy: true) == false)

        #expect(SeriesPrimaryPlayPolicy.title(mediaType: .series, hasSelectedEpisode: false) == "Select Episode")
        #expect(SeriesPrimaryPlayPolicy.title(mediaType: .series, hasSelectedEpisode: true) == "Play")
        #expect(SeriesPrimaryPlayPolicy.title(mediaType: .movie, hasSelectedEpisode: false) == "Play")

        #expect(SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .series, hasSelectedEpisode: false) == "Moves to episode choices before loading streams.")
        #expect(SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .movie, hasSelectedEpisode: false) == "Searches for streams if needed and opens the first available result.")
    }

    @Test
    func detailScrollAndSeasonLoadingPoliciesCoverAllVisibleBranches() {
        #expect(SeriesDetailScrollPolicy.shouldShowTorrentsSection(
            mediaType: .series,
            hasSelectedEpisode: false,
            isLoadingTorrentSearch: true,
            didSearch: false,
            hasTorrentResults: false
        ))
        #expect(SeriesDetailScrollPolicy.shouldShowTorrentsSection(
            mediaType: .series,
            hasSelectedEpisode: false,
            isLoadingTorrentSearch: false,
            didSearch: true,
            hasTorrentResults: false
        ))
        #expect(SeriesDetailScrollPolicy.shouldShowTorrentsSection(
            mediaType: .movie,
            hasSelectedEpisode: false,
            isLoadingTorrentSearch: false,
            didSearch: false,
            hasTorrentResults: true
        ))
        #expect(SeriesDetailScrollPolicy.shouldShowTorrentsSection(
            mediaType: .movie,
            hasSelectedEpisode: true,
            isLoadingTorrentSearch: false,
            didSearch: false,
            hasTorrentResults: false
        ) == false)

        #expect(SeriesSeasonLoadingPresentationPolicy.shouldShowEpisodesSection(
            hasSeasons: true,
            episodeCount: 0,
            isLoadingSeasonEpisodes: true
        ))
        #expect(SeriesSeasonLoadingPresentationPolicy.shouldShowEpisodesSection(
            hasSeasons: true,
            episodeCount: 3,
            isLoadingSeasonEpisodes: false
        ))
        #expect(SeriesSeasonLoadingPresentationPolicy.shouldShowEpisodesSection(
            hasSeasons: false,
            episodeCount: 3,
            isLoadingSeasonEpisodes: true
        ) == false)
        #expect(SeriesSeasonLoadingPresentationPolicy.loadingTitle(for: 4) == "Loading Season 4\u{2026}")
        #expect(SeriesSeasonLoadingPresentationPolicy.loadingMessage(for: 4) == "Updating episode choices for Season 4 while keeping your place on the page.")
    }

    @Test
    func contentRootPoliciesCoverNavigationBadgesAndQuickStartPrompt() {
        #expect(NavigationChromePolicy.usesSidebar(for: .leftSidebar))
        #expect(NavigationChromePolicy.usesSidebar(for: .bottomTabBar) == false)
        #expect(NavigationChromePolicy.usesBottomTabBar(for: .bottomTabBar))
        #expect(NavigationChromePolicy.usesBottomTabBar(for: .leftSidebar) == false)

        #expect(BottomTabRoutingPolicy.action(for: .environments, opensEnvironmentPicker: true) == .openEnvironmentPicker)
        #expect(BottomTabRoutingPolicy.action(for: .environments, opensEnvironmentPicker: false) == .select(.environments))
        #expect(BottomTabRoutingPolicy.action(for: .library, opensEnvironmentPicker: true) == .select(.library))

        #expect(RootTabSelectionPolicy.navigationAction(currentTab: .search, selectedTab: .search) == .resetStack)
        #expect(RootTabSelectionPolicy.navigationAction(currentTab: .search, selectedTab: .library) == .clearPath)
        #expect(RootTabSelectionPolicy.shouldResetNavigationStack(currentTab: .settings, selectedTab: .settings))
        #expect(RootTabSelectionPolicy.shouldClearNavigationPath(currentTab: .settings, selectedTab: .downloads))

        #expect(QuickStartPromptPolicy.restoredTab(from: "Search") == .search)
        #expect(QuickStartPromptPolicy.restoredTab(from: SidebarTab.library.rawValue) == .library)
        #expect(QuickStartPromptPolicy.restoredTab(from: "missing") == nil)
        #expect(QuickStartPromptPolicy.shouldShowPrompt(
            setupRecommendationNeeded: true,
            promptDismissed: false,
            selectedTab: .discover
        ))
        #expect(QuickStartPromptPolicy.shouldShowPrompt(
            setupRecommendationNeeded: true,
            promptDismissed: false,
            selectedTab: .discover,
            promptSuppressed: true
        ) == false)
        #expect(QuickStartPromptPolicy.shouldShowPrompt(
            setupRecommendationNeeded: true,
            promptDismissed: false,
            selectedTab: .library
        ) == false)
    }

    @Test
    func detailTorrentsAndRatingSheetRetainBranchSpecificCopy() throws {
        let torrentsSource = try sourceContents(of: "VPStudio/Views/Windows/Detail/DetailTorrentsSection.swift")
        #expect(torrentsSource.contains("\"Episode Changed\""))
        #expect(torrentsSource.contains("\"Selected \\(selectedEpisode.displayTitle). Run a new search for this episode.\""))
        #expect(torrentsSource.contains("\"Select an Episode\""))
        #expect(torrentsSource.contains("\"Tap Play or select an episode above to search for available streams.\""))
        #expect(torrentsSource.contains("\"Tap Play to search for available streams.\""))
        #expect(torrentsSource.contains("Label(\"Load \\(viewModel.nextTorrentBatchCount) More\", systemImage: \"plus.circle\")"))
        #expect(torrentsSource.contains("InlineLoadingStatusView("))

        let ratingSource = try sourceContents(of: "VPStudio/Views/Windows/Detail/DetailRatingSheet.swift")
        #expect(ratingSource.contains("if viewModel.feedbackScaleMode == .likeDislike"))
        #expect(ratingSource.contains("} else if viewModel.feedbackScaleMode == .oneToTen {"))
        #expect(ratingSource.contains("Slider("))
        #expect(ratingSource.contains("await viewModel.clearFeedback()"))
        #expect(ratingSource.contains("await viewModel.submitFeedback(value: draftFeedbackValue)"))
    }
}

private func sourceContents(of relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
