import Foundation
import Testing
@testable import VPStudio

@Suite("Refresh Loading Presentation Policies")
struct RefreshLoadingPolicyTests {
    @Test
    func discoverUsesBlockingSkeletonForInitialLoad() {
        #expect(
            DiscoverLoadingPresentationPolicy.presentationMode(
                isLoading: true,
                featuredBackdropCount: 0,
                continueWatchingCount: 0,
                catalogRowCount: 0,
                aiRecommendationCount: 0
            ) == .blockingSkeleton
        )
    }

    @Test
    func discoverUsesRefreshingModeWhenContentExists() {
        #expect(
            DiscoverLoadingPresentationPolicy.presentationMode(
                isLoading: true,
                featuredBackdropCount: 1,
                continueWatchingCount: 0,
                catalogRowCount: 0,
                aiRecommendationCount: 0
            ) == .refreshingRetainedContent
        )

        #expect(
            DiscoverLoadingPresentationPolicy.presentationMode(
                isLoading: true,
                featuredBackdropCount: 0,
                continueWatchingCount: 0,
                catalogRowCount: 2,
                aiRecommendationCount: 0
            ) == .refreshingRetainedContent
        )
    }

    @Test
    func discoverUsesRefreshingModeWhenContinueWatchingContentExists() {
        #expect(
            DiscoverLoadingPresentationPolicy.presentationMode(
                isLoading: true,
                featuredBackdropCount: 0,
                continueWatchingCount: 1,
                catalogRowCount: 0,
                aiRecommendationCount: 0
            ) == .refreshingRetainedContent
        )
    }

    @Test
    func discoverUsesRefreshingModeWhenAIRecommendationsExist() {
        #expect(
            DiscoverLoadingPresentationPolicy.presentationMode(
                isLoading: true,
                featuredBackdropCount: 0,
                continueWatchingCount: 0,
                catalogRowCount: 0,
                aiRecommendationCount: 2
            ) == .refreshingRetainedContent
        )
        #expect(DiscoverLoadingPresentationPolicy.refreshTitle == "Refreshing Discover")
    }

    @Test
    func discoverUsesContentModeWhenNotLoading() {
        #expect(
            DiscoverLoadingPresentationPolicy.presentationMode(
                isLoading: false,
                featuredBackdropCount: 0,
                continueWatchingCount: 0,
                catalogRowCount: 0,
                aiRecommendationCount: 0
            ) == .content
        )
    }

    @Test
    func searchUsesBlockingSkeletonForInitialSearchingState() {
        #expect(
            SearchLoadingPresentationPolicy.presentationMode(
                explorePhase: .searching,
                resultCount: 0,
                aiRecommendationCount: 0
            ) == .blockingSkeleton
        )
    }

    @Test
    func searchUsesRefreshingModeWhenRetainingResults() {
        #expect(
            SearchLoadingPresentationPolicy.presentationMode(
                explorePhase: .searching,
                resultCount: 4,
                aiRecommendationCount: 0
            ) == .refreshingRetainedResults
        )

        #expect(
            SearchLoadingPresentationPolicy.presentationMode(
                explorePhase: .searching,
                resultCount: 0,
                aiRecommendationCount: 2
            ) == .refreshingRetainedResults
        )

        #expect(
            SearchLoadingPresentationPolicy.presentationMode(
                explorePhase: .searching,
                resultCount: 4,
                aiRecommendationCount: 2
            ) == .refreshingRetainedResults
        )
    }

    @Test
    func searchPassesThroughNonSearchingPhases() {
        #expect(
            SearchLoadingPresentationPolicy.presentationMode(
                explorePhase: .idle,
                resultCount: 0,
                aiRecommendationCount: 0
            ) == .idle
        )

        #expect(
            SearchLoadingPresentationPolicy.presentationMode(
                explorePhase: .results,
                resultCount: 3,
                aiRecommendationCount: 0
            ) == .results
        )

        #expect(
            SearchLoadingPresentationPolicy.presentationMode(
                explorePhase: .empty,
                resultCount: 0,
                aiRecommendationCount: 0
            ) == .empty
        )

        #expect(
            SearchLoadingPresentationPolicy.presentationMode(
                explorePhase: .error,
                resultCount: 0,
                aiRecommendationCount: 0
            ) == .error
        )
    }

    @Test
    func detailOverlayPolicyBlocksOnlyForInitialDetailLoad() {
        #expect(
            DetailRefreshLoadingPresentationPolicy.shouldShowBlockingOverlay(
                isLoadingDetail: true,
                isLoadingSeasonEpisodes: false,
                hasMediaItem: false
            )
        )

        #expect(
            DetailRefreshLoadingPresentationPolicy.shouldShowBlockingOverlay(
                isLoadingDetail: false,
                isLoadingSeasonEpisodes: true,
                hasMediaItem: true
            ) == false
        )
    }

    @Test
    func detailOverlayPolicyUsesInlineRefreshForSamePreviewReload() {
        #expect(
            DetailRefreshLoadingPresentationPolicy.shouldShowBlockingOverlay(
                isLoadingDetail: true,
                isLoadingSeasonEpisodes: false,
                hasMediaItem: true
            ) == false
        )

        #expect(
            DetailRefreshLoadingPresentationPolicy.shouldShowRefreshIndicator(
                isLoadingDetail: true,
                isLoadingSeasonEpisodes: false,
                hasMediaItem: true
            )
        )

        #expect(
            DetailRefreshLoadingPresentationPolicy.shouldShowRefreshIndicator(
                isLoadingDetail: false,
                isLoadingSeasonEpisodes: true,
                hasMediaItem: true
            ) == false
        )
    }

    @Test
    func detailPresentationPolicyFormatsMetadataAndFeedbackDefaults() {
        #expect(DetailPresentationPolicy.activeSessionToastText == "A video is already playing")
        #expect(DetailPresentationPolicy.yearText(nil) == nil)
        #expect(DetailPresentationPolicy.yearText(1999) == "1999")
        #expect(DetailPresentationPolicy.imdbRatingText(nil) == nil)
        #expect(DetailPresentationPolicy.imdbRatingText(0) == nil)
        #expect(DetailPresentationPolicy.imdbRatingText(7.94) == "7.9")
        #expect(DetailPresentationPolicy.runtimeText(nil) == nil)
        #expect(DetailPresentationPolicy.runtimeText("") == nil)
        #expect(DetailPresentationPolicy.runtimeText("2h 12m") == "2h 12m")

        #expect(DetailPresentationPolicy.feedbackDraftValue(
            currentValue: nil,
            scaleMode: .likeDislike
        ) == 1)
        #expect(DetailPresentationPolicy.feedbackDraftValue(
            currentValue: 14,
            scaleMode: .oneToTen
        ) == 10)
        #expect(DetailPresentationPolicy.feedbackDraftValue(
            currentValue: -4,
            scaleMode: .oneToHundred
        ) == 1)
    }

    @Test
    func detailPresentationPolicyBuildsStableShareItems() {
        #expect(DetailPresentationPolicy.shareItem(
            previewID: "tt0111161",
            previewTitle: "Fallback Title",
            previewType: .movie,
            previewTMDBID: 278,
            mediaTitle: "The Shawshank Redemption",
            mediaTMDBID: nil
        ) == "The Shawshank Redemption\nhttps://www.imdb.com/title/tt0111161/")

        #expect(DetailPresentationPolicy.shareItem(
            previewID: "movie-278",
            previewTitle: "Fallback Title",
            previewType: .movie,
            previewTMDBID: 278,
            mediaTitle: nil,
            mediaTMDBID: nil
        ) == "Fallback Title")

        #expect(DetailPresentationPolicy.shareItem(
            previewID: "tv-1396",
            previewTitle: "Breaking Bad",
            previewType: .series,
            previewTMDBID: nil,
            mediaTitle: "Better Title",
            mediaTMDBID: 1396
        ) == "Better Title")

        #expect(DetailPresentationPolicy.shareItem(
            previewID: "local",
            previewTitle: "Local Only",
            previewType: .movie,
            previewTMDBID: nil,
            mediaTitle: nil,
            mediaTMDBID: nil
        ) == "Local Only")
    }

    @Test
    func seriesSeasonLoadingPresentationKeepsEpisodesShellVisible() {
        #expect(
            SeriesSeasonLoadingPresentationPolicy.shouldShowEpisodesSection(
                hasSeasons: true,
                episodeCount: 0,
                isLoadingSeasonEpisodes: true
            )
        )

        #expect(
            SeriesSeasonLoadingPresentationPolicy.shouldShowEpisodesSection(
                hasSeasons: true,
                episodeCount: 5,
                isLoadingSeasonEpisodes: false
            )
        )

        #expect(
            SeriesSeasonLoadingPresentationPolicy.shouldShowEpisodesSection(
                hasSeasons: false,
                episodeCount: 0,
                isLoadingSeasonEpisodes: true
            ) == false
        )
    }

    @Test
    func detailMetadataLookupPolicyUsesEmbeddedIMDbIDForOMDb() {
        let preview = MediaPreview(
            id: "movie-imdb-tt1160419",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMetadataLookupPolicy.detailID(for: preview, preference: .imdbOrTitle)
                == "tt1160419"
        )
    }

    @Test
    func detailMetadataLookupPolicyFallsBackToTitleForOMDbWhenOnlyTMDBExists() {
        let preview = MediaPreview(
            id: "movie-tmdb-438631",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMetadataLookupPolicy.detailID(for: preview, preference: .imdbOrTitle)
                == "Dune (2021)"
        )
    }

    @Test
    func detailMetadataLookupPolicyFallsBackToPlainTitleForOMDbWhenYearIsMissing() {
        let preview = MediaPreview(
            id: "movie-tmdb-438631",
            type: .movie,
            title: "Dune",
            year: nil,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMetadataLookupPolicy.detailID(for: preview, preference: .imdbOrTitle)
                == "Dune"
        )
    }

    @Test
    func detailMetadataLookupPolicyIgnoresInvalidOMDbYearsAndAvoidsDoubleAppendingYear() {
        let invalidYearPreview = MediaPreview(
            id: "movie-tmdb-438631",
            type: .movie,
            title: "Dune",
            year: 10_000,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )
        let alreadyQualifiedPreview = MediaPreview(
            id: "series-tmdb-57243",
            type: .series,
            title: "Doctor Who (2005)",
            year: 1963,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 57_243
        )

        #expect(
            DetailMetadataLookupPolicy.detailID(for: invalidYearPreview, preference: .imdbOrTitle)
                == "Dune"
        )
        #expect(
            DetailMetadataLookupPolicy.detailID(for: alreadyQualifiedPreview, preference: .imdbOrTitle)
                == "Doctor Who (2005)"
        )
    }

    @Test
    func detailMetadataLookupPolicyKeepsLegacyTMDBLookupForTMDBProviders() {
        let preview = MediaPreview(
            id: "movie-tmdb-438631",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMetadataLookupPolicy.detailID(for: preview, preference: .tmdbOrStableID)
                == "438631"
        )
    }

    @Test
    func detailEpisodeLookupPolicyFallsBackToTitleForOMDbWhenOnlyTMDBExists() {
        let item = MediaItem(
            id: "tmdb-1399",
            type: .series,
            title: "Game of Thrones",
            year: 2011,
            tmdbId: 1399
        )

        #expect(
            DetailMetadataLookupPolicy.episodeLookupID(for: item, preference: .imdbOrTitle)
                == "Game of Thrones (2011)"
        )
    }

    @Test
    func detailEpisodeLookupPolicyFallsBackToPlainTitleForOMDbWhenYearIsMissing() {
        let item = MediaItem(
            id: "tmdb-1399",
            type: .series,
            title: "Game of Thrones",
            year: nil,
            tmdbId: 1399
        )

        #expect(
            DetailMetadataLookupPolicy.episodeLookupID(for: item, preference: .imdbOrTitle)
                == "Game of Thrones"
        )
    }

    @Test
    func detailEpisodeLookupPolicyUsesSharedOMDbTitleYearGuards() {
        let invalidYearItem = MediaItem(
            id: "tmdb-1399",
            type: .series,
            title: "Game of Thrones",
            year: 999,
            tmdbId: 1399
        )
        let alreadyQualifiedItem = MediaItem(
            id: "tmdb-57243",
            type: .series,
            title: "Doctor Who (2005)",
            year: 1963,
            tmdbId: 57_243
        )

        #expect(
            DetailMetadataLookupPolicy.episodeLookupID(for: invalidYearItem, preference: .imdbOrTitle)
                == "Game of Thrones"
        )
        #expect(
            DetailMetadataLookupPolicy.episodeLookupID(for: alreadyQualifiedItem, preference: .imdbOrTitle)
                == "Doctor Who (2005)"
        )
    }

    @Test
    func detailEpisodeLookupPolicyKeepsLegacyTMDBForTMDBProviders() {
        let item = MediaItem(
            id: "tmdb-1399",
            type: .series,
            title: "Game of Thrones",
            year: 2011,
            tmdbId: 1399
        )

        #expect(
            DetailMetadataLookupPolicy.episodeLookupID(for: item, preference: .tmdbOrStableID)
                == "tmdb-1399"
        )
    }

    @Test
    func detailEpisodeLookupPolicyPrefersIMDbForProviderNeutralMergedDetails() {
        let item = MediaItem(
            id: "tt0944947",
            type: .series,
            title: "Game of Thrones",
            year: 2011,
            tmdbId: 1399
        )

        #expect(
            DetailMetadataLookupPolicy.episodeLookupID(for: item, preference: .providerIDOrStableID)
                == "tt0944947"
        )
    }

    @Test
    func detailEpisodeLookupPolicyFallsBackToTMDBForProviderNeutralLegacyDetails() {
        let item = MediaItem(
            id: "tmdb-1399",
            type: .series,
            title: "Game of Thrones",
            year: 2011,
            tmdbId: 1399
        )

        #expect(
            DetailMetadataLookupPolicy.episodeLookupID(for: item, preference: .providerIDOrStableID)
                == "tmdb-1399"
        )
    }

    @Test
    func detailEpisodeLookupPolicyKeepsTMDBForMergedIMDbDetailsWhenTMDBProviderIsPreferred() {
        let item = MediaItem(
            id: "tt0944947",
            type: .series,
            title: "Game of Thrones",
            year: 2011,
            tmdbId: 1399
        )

        #expect(
            DetailMetadataLookupPolicy.episodeLookupID(for: item, preference: .tmdbOrStableID)
                == "tmdb-1399"
        )
    }

    @Test
    func detailMediaIdentityPolicyPrefersTypedOMDbIDFromPreviewIMDbAlias() {
        let preview = MediaPreview(
            id: "movie-imdb-TT1160419",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMediaIdentityPolicy.canonicalMediaID(mediaItem: nil, preview: preview)
                == "movie-omdb-tt1160419"
        )
    }

    @Test
    func detailMediaIdentityPolicyPrefersTypedOMDbItemIDOverLegacyPreviewTMDBID() {
        let item = MediaItem(
            id: "TT1160419",
            type: .movie,
            title: "Dune",
            year: 2021,
            tmdbId: nil
        )
        let preview = MediaPreview(
            id: "movie-tmdb-438631",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMediaIdentityPolicy.canonicalMediaID(mediaItem: item, preview: preview)
                == "movie-omdb-tt1160419"
        )
    }

    @Test
    func detailMediaIdentityPolicyUsesSeriesOMDbPrefixForSeriesIMDbAliases() {
        let preview = MediaPreview(
            id: "series-omdb-TT0944947",
            type: .series,
            title: "Game of Thrones",
            year: 2011,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 1399
        )

        #expect(
            DetailMediaIdentityPolicy.canonicalMediaID(mediaItem: nil, preview: preview)
                == "series-omdb-tt0944947"
        )
    }

    @Test
    func detailMediaIdentityPolicyFallsBackToTMDBAliasWhenNoStableIDExists() {
        let preview = MediaPreview(
            id: "   ",
            type: .movie,
            title: "Untitled",
            year: nil,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMediaIdentityPolicy.canonicalMediaID(mediaItem: nil, preview: preview)
                == "movie-tmdb-438631"
        )
    }

    @Test
    func detailMediaIdentityPolicyPreservesTypedTMDBAliasWhenIMDbIsUnavailable() {
        let preview = MediaPreview(
            id: "movie-tmdb-438631",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMediaIdentityPolicy.canonicalMediaID(mediaItem: nil, preview: preview)
                == "movie-tmdb-438631"
        )
    }

    @Test
    func detailMediaIdentityPolicyPreservesSeriesTMDBAliasWhenIMDbIsUnavailable() {
        let preview = MediaPreview(
            id: "series-tmdb-438631",
            type: .series,
            title: "Series With Shared TMDB Number",
            year: 2026,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMediaIdentityPolicy.canonicalMediaID(mediaItem: nil, preview: preview)
                == "series-tmdb-438631"
        )
    }

    @Test
    func detailMediaIdentityPolicyUsesProviderIDBeforeLocalFetchedItemID() {
        let item = MediaItem(
            id: "local-library-dune",
            type: .movie,
            title: "Dune",
            year: 2021,
            tmdbId: 438_631
        )
        let preview = MediaPreview(
            id: "local-library-dune",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMediaIdentityPolicy.canonicalMediaID(mediaItem: item, preview: preview)
                == "movie-tmdb-438631"
        )
    }

    @Test
    func detailMediaIdentityPolicyKeepsOMDbPreviewAliasAheadOfLocalFetchedItemID() {
        let item = MediaItem(
            id: "local-library-dune",
            type: .movie,
            title: "Dune",
            year: 2021,
            tmdbId: 438_631
        )
        let preview = MediaPreview(
            id: "movie-imdb-TT1160419",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        #expect(
            DetailMediaIdentityPolicy.canonicalMediaID(mediaItem: item, preview: preview)
                == "movie-omdb-tt1160419"
        )
    }

    @Test
    func detailRetentionPolicyPreservesForSameMediaContext() {
        let current = MediaItem(
            id: "tt0111161",
            type: .movie,
            title: "The Shawshank Redemption",
            year: 1994,
            tmdbId: 278
        )

        let sameIDPreview = MediaPreview(
            id: "tt0111161",
            type: .movie,
            title: "The Shawshank Redemption",
            year: 1994,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 278
        )
        #expect(
            DetailRefreshRetentionPolicy.shouldPreserveExistingContent(
                currentMediaItem: current,
                incomingPreview: sameIDPreview
            )
        )

        let sameTMDBDifferentIDPreview = MediaPreview(
            id: "movie-tmdb-278",
            type: .movie,
            title: "The Shawshank Redemption",
            year: 1994,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 278
        )
        #expect(
            DetailRefreshRetentionPolicy.shouldPreserveExistingContent(
                currentMediaItem: current,
                incomingPreview: sameTMDBDifferentIDPreview
            )
        )

        let sameIMDbCompositePreview = MediaPreview(
            id: "movie-imdb-tt0111161",
            type: .movie,
            title: "The Shawshank Redemption",
            year: 1994,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: nil
        )
        #expect(
            DetailRefreshRetentionPolicy.shouldPreserveExistingContent(
                currentMediaItem: current,
                incomingPreview: sameIMDbCompositePreview
            )
        )
    }

    @Test
    func detailRetentionPolicyRejectsDifferentContentOrType() {
        let current = MediaItem(
            id: "tt0903747",
            type: .series,
            title: "Breaking Bad",
            year: 2008,
            tmdbId: 1396
        )

        let differentSeriesPreview = MediaPreview(
            id: "tt7366338",
            type: .series,
            title: "Chernobyl",
            year: 2019,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 87108
        )
        #expect(
            DetailRefreshRetentionPolicy.shouldPreserveExistingContent(
                currentMediaItem: current,
                incomingPreview: differentSeriesPreview
            ) == false
        )

        let differentTypePreview = MediaPreview(
            id: "tt0109830",
            type: .movie,
            title: "Forrest Gump",
            year: 1994,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 13
        )
        #expect(
            DetailRefreshRetentionPolicy.shouldPreserveExistingContent(
                currentMediaItem: current,
                incomingPreview: differentTypePreview
            ) == false
        )

        #expect(
            DetailRefreshRetentionPolicy.shouldPreserveExistingContent(
                currentMediaItem: nil,
                incomingPreview: differentSeriesPreview
            ) == false
        )
    }
}
