import Testing
@testable import VPStudio

@Suite("Discover Presentation Policy Coverage")
struct DiscoverPresentationPolicyCoverageTests {
    @Test
    func aiCuratedSectionReturnsNilWhenDisabled() {
        let state = DiscoverAICuratedSectionPolicy.makeState(
            enabled: false,
            isLoading: false,
            heroPreview: Fixtures.mediaPreview(id: "hero", type: .movie),
            recommendations: [recommendation(title: "Arrival", tmdbId: 329_865)]
        )

        #expect(state == nil)
    }

    @Test
    func aiCuratedSectionBuildsLoadingStateWithoutRecommendations() throws {
        let state: DiscoverAICuratedSectionState = try #require(DiscoverAICuratedSectionPolicy.makeState(
            enabled: true,
            isLoading: true,
            heroPreview: Fixtures.mediaPreview(id: "hero", type: .movie),
            recommendations: [recommendation(title: "Arrival", tmdbId: 329_865)]
        ))

        #expect(state.isLoading)
        #expect(!state.isRegenerateEnabled)
        #expect(state.primaryRecommendation == nil)
        #expect(state.primaryPreview == nil)
        #expect(state.supportingRecommendations.isEmpty)
        #expect(!state.showsEmptyState)
    }

    @Test
    func aiCuratedSectionCapsSupportingRecommendationsAfterPrimary() throws {
        let preview = Fixtures.mediaPreview(id: "primary-preview", type: .movie)
        let recommendations = (1...6).map {
            recommendation(title: "Pick \($0)", tmdbId: 10_000 + $0)
        }

        let state: DiscoverAICuratedSectionState = try #require(DiscoverAICuratedSectionPolicy.makeState(
            enabled: true,
            isLoading: false,
            heroPreview: preview,
            recommendations: recommendations
        ))

        #expect(!state.isLoading)
        #expect(state.isRegenerateEnabled)
        #expect(state.primaryRecommendation == recommendations[0])
        #expect(state.primaryPreview == preview)
        #expect(state.supportingRecommendations == Array(recommendations[1...3]))
        #expect(state.supportingRecommendations.count == DiscoverAICuratedSectionPolicy.maxSupportingRecommendations)
        #expect(!state.showsEmptyState)
    }

    @Test
    func aiCuratedSectionMarksEmptyStateWhenEnabledWithoutRecommendations() throws {
        let state: DiscoverAICuratedSectionState = try #require(DiscoverAICuratedSectionPolicy.makeState(
            enabled: true,
            isLoading: false,
            heroPreview: nil,
            recommendations: []
        ))

        #expect(!state.isLoading)
        #expect(state.isRegenerateEnabled)
        #expect(state.primaryRecommendation == nil)
        #expect(state.primaryPreview == nil)
        #expect(state.supportingRecommendations.isEmpty)
        #expect(state.showsEmptyState)
    }

    @Test
    func loadingPresentationModesCoverBlockingRefreshAndContentBranches() {
        #expect(DiscoverLoadingPresentationPolicy.presentationMode(
            isLoading: false,
            featuredBackdropCount: 0,
            continueWatchingCount: 0,
            catalogRowCount: 0,
            aiRecommendationCount: 0
        ) == .content)

        #expect(DiscoverLoadingPresentationPolicy.presentationMode(
            isLoading: true,
            featuredBackdropCount: 0,
            continueWatchingCount: 0,
            catalogRowCount: 0,
            aiRecommendationCount: 0
        ) == .blockingSkeleton)

        #expect(DiscoverLoadingPresentationPolicy.presentationMode(
            isLoading: true,
            featuredBackdropCount: 1,
            continueWatchingCount: 0,
            catalogRowCount: 0,
            aiRecommendationCount: 0
        ) == .refreshingRetainedContent)

        #expect(DiscoverLoadingPresentationPolicy.presentationMode(
            isLoading: true,
            featuredBackdropCount: 0,
            continueWatchingCount: 1,
            catalogRowCount: 1,
            aiRecommendationCount: 1
        ) == .refreshingRetainedContent)
    }

    private func recommendation(title: String, tmdbId: Int) -> AIMovieRecommendation {
        AIMovieRecommendation(
            title: title,
            year: 2024,
            type: .movie,
            reason: "Policy coverage fixture.",
            tmdbId: tmdbId,
            score: 0.8
        )
    }
}
