import Testing
@testable import VPStudio

@Suite("DetailQAActionsPolicy")
struct DetailQAActionsPolicyTests {
    @Test
    func shouldRunRequiresEnabledNotAlreadyRunAndMediaItem() {
        #expect(
            DetailQAActionsPolicy.shouldRun(
                isQAEnabled: true,
                didRunQAActions: false,
                hasMediaItem: true
            )
        )

        #expect(
            DetailQAActionsPolicy.shouldRun(
                isQAEnabled: false,
                didRunQAActions: false,
                hasMediaItem: true
            ) == false
        )

        #expect(
            DetailQAActionsPolicy.shouldRun(
                isQAEnabled: true,
                didRunQAActions: true,
                hasMediaItem: true
            ) == false
        )

        #expect(
            DetailQAActionsPolicy.shouldRun(
                isQAEnabled: true,
                didRunQAActions: false,
                hasMediaItem: false
            ) == false
        )
    }

    @Test
    func seasonToLoadOnlyReturnsValueForSeriesAndChangedSeason() {
        #expect(
            DetailQAActionsPolicy.seasonToLoad(
                previewType: .series,
                selectedSeason: 2,
                currentSeason: 1
            ) == 2
        )

        #expect(
            DetailQAActionsPolicy.seasonToLoad(
                previewType: .series,
                selectedSeason: 1,
                currentSeason: 1
            ) == nil
        )

        #expect(
            DetailQAActionsPolicy.seasonToLoad(
                previewType: .series,
                selectedSeason: nil,
                currentSeason: 1
            ) == nil
        )

        #expect(
            DetailQAActionsPolicy.seasonToLoad(
                previewType: .movie,
                selectedSeason: 4,
                currentSeason: 1
            ) == nil
        )
    }

    @Test
    func selectedEpisodeNumberOnlyAppliesToSeries() {
        #expect(
            DetailQAActionsPolicy.selectedEpisodeNumber(
                previewType: .series,
                selectedEpisode: 7
            ) == 7
        )

        #expect(
            DetailQAActionsPolicy.selectedEpisodeNumber(
                previewType: .series,
                selectedEpisode: nil
            ) == nil
        )

        #expect(
            DetailQAActionsPolicy.selectedEpisodeNumber(
                previewType: .movie,
                selectedEpisode: 7
            ) == nil
        )
    }

    @Test
    func episodeToSelectUsesSeriesEpisodeNumberAndReturnsMatchingEpisode() {
        let first = makeEpisode(id: "ep-1", episodeNumber: 1)
        let second = makeEpisode(id: "ep-2", episodeNumber: 2)
        let duplicate = makeEpisode(id: "ep-2-dup", episodeNumber: 2)

        #expect(
            DetailQAActionsPolicy.episodeToSelect(
                previewType: .series,
                selectedEpisode: 2,
                episodes: [first, second, duplicate]
            )?.id == "ep-2"
        )
    }

    @Test
    func episodeToSelectReturnsNilForMovieOrMissingSelectionOrNoMatch() {
        let first = makeEpisode(id: "ep-1", episodeNumber: 1)

        #expect(
            DetailQAActionsPolicy.episodeToSelect(
                previewType: .movie,
                selectedEpisode: 1,
                episodes: [first]
            ) == nil
        )
        #expect(
            DetailQAActionsPolicy.episodeToSelect(
                previewType: .series,
                selectedEpisode: nil,
                episodes: [first]
            ) == nil
        )
        #expect(
            DetailQAActionsPolicy.episodeToSelect(
                previewType: .series,
                selectedEpisode: 99,
                episodes: [first]
            ) == nil
        )
    }

    @Test
    func libraryMutationsReturnsExpectedOperationsInExecutionOrder() {
        #expect(
            DetailQAActionsPolicy.libraryMutations(
                autoAddWatchlist: true,
                autoAddFavorites: true,
                autoRemoveWatchlist: true,
                autoRemoveFavorites: true,
                isInWatchlist: true,
                isInFavorites: false
            ) == [.addFavorites, .removeWatchlist]
        )

        #expect(
            DetailQAActionsPolicy.libraryMutations(
                autoAddWatchlist: true,
                autoAddFavorites: true,
                autoRemoveWatchlist: false,
                autoRemoveFavorites: false,
                isInWatchlist: false,
                isInFavorites: false
            ) == [.addWatchlist, .addFavorites]
        )

        #expect(
            DetailQAActionsPolicy.libraryMutations(
                autoAddWatchlist: false,
                autoAddFavorites: false,
                autoRemoveWatchlist: true,
                autoRemoveFavorites: true,
                isInWatchlist: true,
                isInFavorites: true
            ) == [.removeWatchlist, .removeFavorites]
        )
    }

    private func makeEpisode(id: String, episodeNumber: Int) -> Episode {
        Episode(
            id: id,
            mediaId: "series-1",
            seasonNumber: 1,
            episodeNumber: episodeNumber,
            title: "Episode \(episodeNumber)",
            overview: nil,
            airDate: nil,
            stillPath: nil,
            runtime: nil
        )
    }
}
