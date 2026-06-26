import Testing
@testable import VPStudio

@Suite("DiscoverCatalogPreferencesPolicy")
struct DiscoverCatalogPreferencesPolicyTests {
    @Test
    func catalogKindMetadataUsesStableIDsTitlesAndSymbols() {
        #expect(DiscoverCatalogKind.allCases.map(\.id) == [
            "trendingMovies",
            "trendingShows",
            "popularMovies",
            "topRatedMovies",
            "nowPlayingMovies",
        ])
        #expect(DiscoverCatalogKind.allCases.map(\.rowID) == [
            "trending-movies",
            "trending-shows",
            "popular-movies",
            "top-rated-movies",
            "now-playing-movies",
        ])
        #expect(DiscoverCatalogKind.allCases.map(\.title) == [
            "Trending Now",
            "Trending TV Shows",
            "Popular",
            "Top Rated",
            "Now Playing",
        ])
        #expect(DiscoverCatalogKind.allCases.map(\.symbol) == [
            "flame",
            "tv",
            "star",
            "trophy",
            "film",
        ])
    }

    @Test
    func emptyOrUnknownStorageFallsBackToDefaultCatalogs() {
        #expect(DiscoverCatalogPreferencesPolicy.enabledKinds(from: "").count == DiscoverCatalogKind.allCases.count)
        #expect(DiscoverCatalogPreferencesPolicy.enabledKinds(from: "missing").count == DiscoverCatalogKind.allCases.count)
    }

    @Test
    func encodedSelectionPreservesCanonicalRowOrder() {
        let encoded = DiscoverCatalogPreferencesPolicy.encoded([.nowPlayingMovies, .trendingMovies])

        #expect(encoded == "trendingMovies,nowPlayingMovies")
    }

    @Test
    func togglingLastSelectedCatalogKeepsCurrentSelection() {
        let current: Set<DiscoverCatalogKind> = [.popularMovies]

        #expect(DiscoverCatalogPreferencesPolicy.selection(afterToggling: .popularMovies, in: current) == current)
    }

    @Test
    func togglingUnselectedCatalogAddsItToSelection() {
        let current: Set<DiscoverCatalogKind> = [.popularMovies]

        #expect(
            DiscoverCatalogPreferencesPolicy.selection(
                afterToggling: .trendingShows,
                in: current
            ) == [.popularMovies, .trendingShows]
        )
    }

    @Test
    func errorRetryBehaviorDistinguishesSetupErrorsFromRefreshableErrors() {
        #expect(DiscoverErrorActionPolicy.retryBehavior(isSetupError: true) == .dismissOnly)
        #expect(DiscoverErrorActionPolicy.retryBehavior(isSetupError: false) == .refreshAndDismiss)
    }

    @Test
    func setupSurfacePolicyShowsBackdropOnlyForSuppressedSetupErrors() {
        #expect(
            DiscoverSetupSurfacePolicy.showsSuppressedSetupBackdrop(
                suppressSetupSurface: true,
                isSetupError: true
            )
        )
        #expect(
            DiscoverSetupSurfacePolicy.showsSuppressedSetupBackdrop(
                suppressSetupSurface: false,
                isSetupError: true
            ) == false
        )
        #expect(
            DiscoverSetupSurfacePolicy.showsSuppressedSetupBackdrop(
                suppressSetupSurface: true,
                isSetupError: false
            ) == false
        )
    }

    @Test
    func setupSurfacePolicyHidesCatalogControlsBehindSetupBackdrop() {
        #expect(
            DiscoverSetupSurfacePolicy.showsCatalogControls(
                hasHeroItems: true,
                hasContinueWatching: true,
                hasCatalogRows: true,
                hasAISection: true,
                isShowingSuppressedSetupBackdrop: true
            ) == false
        )
        #expect(
            DiscoverSetupSurfacePolicy.showsCatalogControls(
                hasHeroItems: false,
                hasContinueWatching: false,
                hasCatalogRows: false,
                hasAISection: false,
                isShowingSuppressedSetupBackdrop: false
            ) == false
        )
        #expect(
            DiscoverSetupSurfacePolicy.showsCatalogControls(
                hasHeroItems: true,
                hasContinueWatching: false,
                hasCatalogRows: false,
                hasAISection: false,
                isShowingSuppressedSetupBackdrop: false
            )
        )
        #expect(
            DiscoverSetupSurfacePolicy.showsCatalogControls(
                hasHeroItems: false,
                hasContinueWatching: false,
                hasCatalogRows: true,
                hasAISection: false,
                isShowingSuppressedSetupBackdrop: false
            )
        )
    }

    @Test
    func setupSurfacePolicyKeepsInitialLockedPreviewToOneVisibleRow() {
        #expect(DiscoverSetupSurfacePolicy.lockedPreviewRowCount == 1)
    }

    @Test
    func layoutPolicyReservesBottomClearanceForBottomTabs() {
        #expect(DiscoverLayoutPolicy.standardBottomContentPadding == 132)
        #expect(DiscoverLayoutPolicy.bottomTabBarContentPadding == 240)
        #expect(DiscoverLayoutPolicy.bottomContentPadding(for: .bottomTabBar) == DiscoverLayoutPolicy.bottomTabBarContentPadding)
        #expect(DiscoverLayoutPolicy.bottomContentPadding(for: .leftSidebar) == DiscoverLayoutPolicy.standardBottomContentPadding)
        #expect(DiscoverLayoutPolicy.bottomTabBarContentPadding > DiscoverLayoutPolicy.standardBottomContentPadding)
    }

    @Test
    func visibleRowsHonorEnabledCatalogsAndRecomputeDelays() {
        let movie = Fixtures.mediaPreview(id: "movie")
        let show = Fixtures.mediaPreview(id: "show", type: .series)

        let rows = DiscoverHierarchyPolicy.visibleCatalogRows(
            trendingMovies: [movie],
            trendingShows: [show],
            popularMovies: [movie],
            topRatedMovies: [movie],
            nowPlayingMovies: [movie],
            enabledCatalogs: [.trendingShows, .topRatedMovies]
        )

        #expect(rows.map(\.id) == ["trending-shows", "top-rated-movies"])
        #expect(rows.map(\.animationDelay) == [
            DiscoverHierarchyPolicy.firstCatalogDelay,
            DiscoverHierarchyPolicy.firstCatalogDelay + DiscoverHierarchyPolicy.catalogDelayStep,
        ])
    }
}
