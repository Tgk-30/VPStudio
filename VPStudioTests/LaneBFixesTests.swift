import Foundation
import Testing
@testable import VPStudio

struct LaneBFixesTests {
    @Test func discoverFilteringRejectsRatedRawMediaIdentifier() {
        let keep = DiscoverViewModel.shouldKeepRecommendation(
            title: "Indie Favorite",
            recommendationMediaID: "tt1234567",
            recommendationType: .movie,
            imdbId: "tt1234567",
            tmdbId: nil,
            ratedMediaIds: ["tt1234567"],
            libraryMediaIds: [],
            watchedMediaIds: [],
            ratedTitles: [],
            watchedTitles: [],
            libraryTitles: []
        )

        #expect(keep == false)
    }

    @Test func discoverFilteringRejectsEachLibraryRatedAndTitleExclusion() {
        #expect(Self.shouldKeepDiscoverRecommendation(libraryMediaIds: ["movie-local-1"]) == false)
        #expect(Self.shouldKeepDiscoverRecommendation(watchedMediaIds: ["movie-local-1"]) == false)
        #expect(Self.shouldKeepDiscoverRecommendation(tmdbId: 42, ratedMediaIds: ["movie-tmdb-42"]) == false)
        #expect(Self.shouldKeepDiscoverRecommendation(tmdbId: 42, libraryMediaIds: ["movie-tmdb-42"]) == false)
        #expect(Self.shouldKeepDiscoverRecommendation(tmdbId: 42, watchedMediaIds: ["movie-tmdb-42"]) == false)
        #expect(Self.shouldKeepDiscoverRecommendation(title: "Already Rated", ratedTitles: ["already rated"]) == false)
        #expect(Self.shouldKeepDiscoverRecommendation(title: "Already Watched", watchedTitles: ["already watched"]) == false)
        #expect(Self.shouldKeepDiscoverRecommendation(title: "Already Saved", libraryTitles: ["already saved"]) == false)
        #expect(Self.shouldKeepDiscoverRecommendation(title: "Fresh Pick") == true)
    }

    @Test func discoverFilteringRejectsOMDbCompositeIMDbIdentifiers() {
        #expect(
            Self.shouldKeepDiscoverRecommendation(
                recommendationMediaID: "tt0133093",
                imdbId: "tt0133093",
                ratedMediaIds: ["movie-omdb-tt0133093"]
            ) == false
        )
        #expect(
            Self.shouldKeepDiscoverRecommendation(
                recommendationMediaID: "tt0133093",
                imdbId: "tt0133093",
                libraryMediaIds: ["movie-omdb-tt0133093"]
            ) == false
        )
    }

    @Test func discoverFilteringRejectsEmbeddedIMDbIdentifiers() {
        #expect(
            Self.shouldKeepDiscoverRecommendation(
                recommendationMediaID: "movie-imdb-tt1160419",
                imdbId: "https://www.imdb.com/title/TT1160419/",
                ratedMediaIds: ["tt1160419"]
            ) == false
        )
        #expect(
            Self.shouldKeepDiscoverRecommendation(
                recommendationMediaID: "movie-imdb-tt1160419",
                imdbId: "https://www.imdb.com/title/TT1160419/",
                libraryMediaIds: ["movie-omdb-tt1160419"]
            ) == false
        )
    }

    @Test func discoverRecommendationScoringNormalizesIMDbIdentifierForms() {
        #expect(DiscoverViewModel.imdbIDsMatch("https://www.imdb.com/title/TT1160419/", "movie-imdb-tt1160419"))
        #expect(DiscoverViewModel.imdbIDsMatch("TT1160419", "movie-omdb-tt1160419"))
        #expect(DiscoverViewModel.imdbIDsMatch("tt1160419", "tt15239678") == false)
        #expect(DiscoverViewModel.imdbIDsMatch(nil, "tt1160419") == false)
    }

    @Test func discoverMissingKeyResetPolicyOnlyTriggersForConfiguredKey() {
        #expect(DiscoverViewModel.shouldResetRemoteServiceForMissingKey(configuredApiKey: "abc") == true)
        #expect(DiscoverViewModel.shouldResetRemoteServiceForMissingKey(configuredApiKey: nil) == false)
        #expect(DiscoverViewModel.shouldResetRemoteServiceForMissingKey(configuredApiKey: "   ") == false)
    }

    @Test func detailAutoSearchPolicyDefersSeriesSearchUntilExplicitUserAction() {
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .movie,
                hasMediaItem: true,
                hasSelectedEpisode: false,
                hasExplicitEpisodeContext: false
            ) == true
        )
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .series,
                hasMediaItem: true,
                hasSelectedEpisode: false,
                hasExplicitEpisodeContext: false
            ) == false
        )
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .series,
                hasMediaItem: true,
                hasSelectedEpisode: true,
                hasExplicitEpisodeContext: false
            ) == false
        )
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .series,
                hasMediaItem: true,
                hasSelectedEpisode: true,
                hasExplicitEpisodeContext: true
            ) == false
        )
    }

    @Test func detailInitialRenderPolicyKeepsFirstOpenOnSkeletonUntilInitialTaskFinishes() {
        #expect(
            DetailInitialRenderPolicy.shouldShowContent(
                hasViewModel: false,
                isPreparingInitialPresentation: true
            ) == false
        )

        #expect(
            DetailInitialRenderPolicy.shouldShowContent(
                hasViewModel: true,
                isPreparingInitialPresentation: true
            ) == false
        )

        #expect(
            DetailInitialRenderPolicy.shouldShowContent(
                hasViewModel: true,
                isPreparingInitialPresentation: false
            ) == true
        )
    }

    @Test func librarySelectionTransitionResetsOnlyWhenListChanges() {
        #expect(
            LibrarySelectionTransitionPolicy.shouldResetTransientFolderState(
                previous: .watchlist,
                next: .history
            ) == true
        )
        #expect(
            LibrarySelectionTransitionPolicy.shouldResetTransientFolderState(
                previous: .favorites,
                next: .favorites
            ) == false
        )
    }

    @Test func libraryTitleRefreshPolicyBlocksHistoryAndInFlightRefreshes() {
        #expect(LibraryTitleRefreshPolicy.canStartRefresh(selectedList: .watchlist, isRefreshing: false) == true)
        #expect(LibraryTitleRefreshPolicy.canStartRefresh(selectedList: .history, isRefreshing: false) == false)
        #expect(LibraryTitleRefreshPolicy.canStartRefresh(selectedList: .favorites, isRefreshing: true) == false)
    }

    @Test func downloadProgressPolicyNormalizesFromBytesAndClampsInvalidProgress() {
        let bytesBacked = DownloadProgressPolicy.normalizedProgress(
            progress: .nan,
            bytesWritten: 50,
            totalBytes: 100,
            status: .downloading
        )
        #expect(abs(bytesBacked - 0.5) < 0.000_1)

        let invalidProgress = DownloadProgressPolicy.normalizedProgress(
            progress: .nan,
            bytesWritten: 0,
            totalBytes: nil,
            status: .downloading
        )
        #expect(invalidProgress == 0)

        let completedWithoutTotal = DownloadProgressPolicy.normalizedProgress(
            progress: 0.2,
            bytesWritten: 0,
            totalBytes: nil,
            status: .completed
        )
        #expect(completedWithoutTotal == 1)
    }

    @Test func downloadProgressPolicyUsesLatestTaskTimestamp() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)

        let tasks = [
            DownloadTask(
                id: "a",
                mediaId: "m1",
                streamURL: "https://example.com/a",
                fileName: "old.mkv",
                status: .queued,
                progress: 0,
                bytesWritten: 0,
                totalBytes: nil,
                destinationPath: nil,
                errorMessage: nil,
                mediaTitle: "Old",
                mediaType: "movie",
                posterPath: nil,
                seasonNumber: nil,
                episodeNumber: nil,
                episodeTitle: nil,
                createdAt: older,
                updatedAt: older
            ),
            DownloadTask(
                id: "b",
                mediaId: "m1",
                streamURL: "https://example.com/b",
                fileName: "new.mkv",
                status: .downloading,
                progress: 0.1,
                bytesWritten: 1,
                totalBytes: 10,
                destinationPath: nil,
                errorMessage: nil,
                mediaTitle: "New",
                mediaType: "movie",
                posterPath: nil,
                seasonNumber: nil,
                episodeNumber: nil,
                episodeTitle: nil,
                createdAt: newer,
                updatedAt: newer
            )
        ]

        #expect(DownloadProgressPolicy.latestUpdatedAt(in: tasks) == newer)
    }

    @Test func downloadProgressPolicyClampsRawProgressBounds() {
        #expect(DownloadProgressPolicy.clampedUnitProgress(-0.25) == 0)
        #expect(DownloadProgressPolicy.clampedUnitProgress(0.75) == 0.75)
        #expect(DownloadProgressPolicy.clampedUnitProgress(1.25) == 1)
        #expect(DownloadProgressPolicy.clampedUnitProgress(.infinity) == 0)
    }

    @Test func downloadProgressPolicyUsesDistantPastForEmptyTaskLists() {
        #expect(DownloadProgressPolicy.latestUpdatedAt(in: []) == .distantPast)
    }

    @Test func seriesPrimaryPlayPolicyUsesSharedBusyGateAndFeedbackMessage() {
        #expect(SeriesPrimaryPlayPolicy.isBusy(isLocalPlayLoading: true, isPlayerOpening: false, isLoadingSeasonEpisodes: false) == true)
        #expect(SeriesPrimaryPlayPolicy.isBusy(isLocalPlayLoading: false, isPlayerOpening: true, isLoadingSeasonEpisodes: false) == true)
        #expect(SeriesPrimaryPlayPolicy.isBusy(isLocalPlayLoading: false, isPlayerOpening: false, isLoadingSeasonEpisodes: false) == false)
        #expect(SeriesPrimaryPlayPolicy.noStreamsMessage.contains("No streams found"))
    }

    @Test func searchShellCopyPolicyReturnsContextAwareCopy() {
        #expect(
            SearchShellCopyPolicy.title(
                explorePhase: .results,
                submittedQuery: "dune",
                hasSelectedGenre: false,
                hasActiveMoodCard: false
            ) == "Search the catalog"
        )

        let subtitle = SearchShellCopyPolicy.subtitle(
            activeMoodCardTitle: "Dark Thrillers",
            selectedGenreName: nil,
            submittedQuery: ""
        )
        #expect(subtitle.contains("dark thrillers"))
    }

    @Test func searchGenreRemapPrefersIdThenCaseInsensitiveName() {
        let sourceGenre = Genre(id: 28, name: "Action")
        let byID = SearchViewModel.remapGenre(sourceGenre, in: [Genre(id: 28, name: "Action & Adventure")])
        #expect(byID?.id == 28)

        let byName = SearchViewModel.remapGenre(sourceGenre, in: [Genre(id: 999, name: "action")])
        #expect(byName?.id == 999)
    }

    private static func shouldKeepDiscoverRecommendation(
        title: String = "Fresh Pick",
        recommendationMediaID: String = "movie-local-1",
        recommendationType: MediaType = .movie,
        imdbId: String? = nil,
        tmdbId: Int? = nil,
        ratedMediaIds: Set<String> = [],
        libraryMediaIds: Set<String> = [],
        watchedMediaIds: Set<String> = [],
        ratedTitles: Set<String> = [],
        watchedTitles: Set<String> = [],
        libraryTitles: Set<String> = []
    ) -> Bool {
        DiscoverViewModel.shouldKeepRecommendation(
            title: title,
            recommendationMediaID: recommendationMediaID,
            recommendationType: recommendationType,
            imdbId: imdbId,
            tmdbId: tmdbId,
            ratedMediaIds: ratedMediaIds,
            libraryMediaIds: libraryMediaIds,
            watchedMediaIds: watchedMediaIds,
            ratedTitles: ratedTitles,
            watchedTitles: watchedTitles,
            libraryTitles: libraryTitles
        )
    }
}
