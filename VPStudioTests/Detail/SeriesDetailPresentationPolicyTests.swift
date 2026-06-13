import Testing
@testable import VPStudio

// MARK: - SeriesPrimaryPlayPolicy

@Suite("SeriesPrimaryPlayPolicy")
struct SeriesPrimaryPlayPolicyTests {

    // MARK: isBusy

    @Test func isBusyReturnsFalseWhenAllFlagsAreFalse() {
        #expect(
            SeriesPrimaryPlayPolicy.isBusy(
                isLocalPlayLoading: false,
                isPlayerOpening: false,
                isLoadingSeasonEpisodes: false
            ) == false
        )
    }

    @Test func isBusyReturnsTrueWhenLocalPlayLoading() {
        #expect(
            SeriesPrimaryPlayPolicy.isBusy(
                isLocalPlayLoading: true,
                isPlayerOpening: false,
                isLoadingSeasonEpisodes: false
            ) == true
        )
    }

    @Test func isBusyReturnsTrueWhenPlayerOpening() {
        #expect(
            SeriesPrimaryPlayPolicy.isBusy(
                isLocalPlayLoading: false,
                isPlayerOpening: true,
                isLoadingSeasonEpisodes: false
            ) == true
        )
    }

    @Test func isBusyReturnsTrueWhenLoadingSeasonEpisodes() {
        #expect(
            SeriesPrimaryPlayPolicy.isBusy(
                isLocalPlayLoading: false,
                isPlayerOpening: false,
                isLoadingSeasonEpisodes: true
            ) == true
        )
    }

    @Test func isBusyReturnsTrueWhenAllFlagsAreTrue() {
        #expect(
            SeriesPrimaryPlayPolicy.isBusy(
                isLocalPlayLoading: true,
                isPlayerOpening: true,
                isLoadingSeasonEpisodes: true
            ) == true
        )
    }

    // MARK: isEnabled

    @Test(arguments: [
        (MediaType.movie, false, false, true),
        (MediaType.movie, true,  false, true),
        (MediaType.series, false, false, false),
        (MediaType.series, true,  false, true),
        (MediaType.movie, false, true,  false),
        (MediaType.movie, true,  true,  false),
        (MediaType.series, false, true,  false),
        (MediaType.series, true,  true,  false),
    ] as [(MediaType, Bool, Bool, Bool)])
    func isEnabledPermutations(mediaType: MediaType, hasSelectedEpisode: Bool, isBusy: Bool, expected: Bool) {
        let result = SeriesPrimaryPlayPolicy.isEnabled(
            mediaType: mediaType,
            hasSelectedEpisode: hasSelectedEpisode,
            isBusy: isBusy
        )
        #expect(result == expected)
    }

    // MARK: title

    @Test func titleIsPlayForMovieWithoutSelection() {
        #expect(SeriesPrimaryPlayPolicy.title(mediaType: .movie, hasSelectedEpisode: false) == "Play")
    }

    @Test func titleIsPlayForMovieWithSelection() {
        #expect(SeriesPrimaryPlayPolicy.title(mediaType: .movie, hasSelectedEpisode: true) == "Play")
    }

    @Test func titleIsSelectEpisodeForSeriesWithoutSelection() {
        #expect(
            SeriesPrimaryPlayPolicy.title(mediaType: .series, hasSelectedEpisode: false)
            == SeriesPrimaryPlayPolicy.selectEpisodeLabel
        )
    }

    @Test func titleIsPlayForSeriesWithSelection() {
        #expect(SeriesPrimaryPlayPolicy.title(mediaType: .series, hasSelectedEpisode: true) == "Play")
    }

    // MARK: accessibilityHint

    @Test func accessibilityHintForMovieWithoutSelection() {
        #expect(
            SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .movie, hasSelectedEpisode: false)
            == "Searches for streams if needed and opens the first available result."
        )
    }

    @Test func accessibilityHintForMovieWithSelection() {
        #expect(
            SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .movie, hasSelectedEpisode: true)
            == "Searches for streams if needed and opens the first available result."
        )
    }

    @Test func accessibilityHintForSeriesWithoutSelection() {
        #expect(
            SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .series, hasSelectedEpisode: false)
            == "Choose an episode before loading streams."
        )
    }

    @Test func accessibilityHintForSeriesWithSelection() {
        #expect(
            SeriesPrimaryPlayPolicy.accessibilityHint(mediaType: .series, hasSelectedEpisode: true)
            == "Searches for streams if needed and opens the first available result."
        )
    }
}

// MARK: - SeriesDetailPresentationPolicy

@Suite("SeriesDetailPresentationPolicy")
struct SeriesDetailPresentationPolicyTests {

    // MARK: seasonCountText

    @Test func seasonCountTextReturnsNilForZero() {
        #expect(SeriesDetailPresentationPolicy.seasonCountText(0) == nil)
    }

    @Test func seasonCountTextSingular() {
        #expect(SeriesDetailPresentationPolicy.seasonCountText(1) == "1 Season")
    }

    @Test func seasonCountTextPlural() {
        #expect(SeriesDetailPresentationPolicy.seasonCountText(3) == "3 Seasons")
    }

    // MARK: runtimeText

    @Test func runtimeTextReturnsNilForNil() {
        #expect(SeriesDetailPresentationPolicy.runtimeText(minutes: nil) == nil)
    }

    @Test func runtimeTextReturnsNilForZero() {
        #expect(SeriesDetailPresentationPolicy.runtimeText(minutes: 0) == nil)
    }

    @Test func runtimeTextReturnsMinutes() {
        #expect(SeriesDetailPresentationPolicy.runtimeText(minutes: 90) == "90 min")
    }

    // MARK: imdbRatingText

    @Test func imdbRatingTextReturnsNilForNil() {
        #expect(SeriesDetailPresentationPolicy.imdbRatingText(nil) == nil)
    }

    @Test func imdbRatingTextReturnsNilForZero() {
        #expect(SeriesDetailPresentationPolicy.imdbRatingText(0.0) == nil)
    }

    @Test func imdbRatingTextFormatsPositiveValue() {
        #expect(SeriesDetailPresentationPolicy.imdbRatingText(8.5) == "8.5 IMDb")
    }

    // MARK: episodeContextText

    @Test func episodeContextTextFormatsCorrectly() {
        #expect(SeriesDetailPresentationPolicy.episodeContextText(season: 2, episodeNumber: 5) == "S2:E5")
    }

    // MARK: episodeRuntimeText

    @Test func episodeRuntimeTextReturnsNilForNil() {
        #expect(SeriesDetailPresentationPolicy.episodeRuntimeText(minutes: nil) == nil)
    }

    @Test func episodeRuntimeTextReturnsNilForZero() {
        #expect(SeriesDetailPresentationPolicy.episodeRuntimeText(minutes: 0) == nil)
    }

    @Test func episodeRuntimeTextReturnsFormattedMinutes() {
        #expect(SeriesDetailPresentationPolicy.episodeRuntimeText(minutes: 42) == "• 42m")
    }

    // MARK: episodeTitle

    @Test func episodeTitleFallsBackToEpisodeNumberWhenNil() {
        #expect(SeriesDetailPresentationPolicy.episodeTitle(nil, episodeNumber: 3) == "Episode 3")
    }

    @Test func episodeTitleFallsBackToEpisodeNumberWhenEmpty() {
        #expect(SeriesDetailPresentationPolicy.episodeTitle("", episodeNumber: 3) == "Episode 3")
    }

    @Test func episodeTitleReturnsProvidedTitle() {
        #expect(SeriesDetailPresentationPolicy.episodeTitle("Pilot", episodeNumber: 1) == "Pilot")
    }

    // MARK: episodeAccessibilityLabel

    @Test func episodeAccessibilityLabelWithTitle() {
        #expect(
            SeriesDetailPresentationPolicy.episodeAccessibilityLabel(episodeNumber: 2, title: "The Storm")
            == "Episode 2, The Storm"
        )
    }

    @Test func episodeAccessibilityLabelWithoutTitle() {
        #expect(
            SeriesDetailPresentationPolicy.episodeAccessibilityLabel(episodeNumber: 2, title: nil)
            == "Episode 2, Untitled"
        )
    }

    // MARK: episodeAccessibilityValue

    @Test func episodeAccessibilityValueWatchedAndSelected() {
        #expect(
            SeriesDetailPresentationPolicy.episodeAccessibilityValue(isWatched: true, isSelected: true)
            == "Watched, selected"
        )
    }

    @Test func episodeAccessibilityValueWatchedNotSelected() {
        #expect(
            SeriesDetailPresentationPolicy.episodeAccessibilityValue(isWatched: true, isSelected: false)
            == "Watched"
        )
    }

    @Test func episodeAccessibilityValueNotWatchedSelected() {
        #expect(
            SeriesDetailPresentationPolicy.episodeAccessibilityValue(isWatched: false, isSelected: true)
            == "Selected"
        )
    }

    @Test func episodeAccessibilityValueNotWatchedNotSelected() {
        #expect(
            SeriesDetailPresentationPolicy.episodeAccessibilityValue(isWatched: false, isSelected: false)
            == "Not watched"
        )
    }

    // MARK: episodeWatchLabel

    @Test func episodeWatchLabelWatched() {
        #expect(SeriesDetailPresentationPolicy.episodeWatchLabel(isWatched: true) == "Watched")
    }

    @Test func episodeWatchLabelNotWatched() {
        #expect(SeriesDetailPresentationPolicy.episodeWatchLabel(isWatched: false) == "Not watched")
    }

    // MARK: episodeWatchActionTitle

    @Test func episodeWatchActionTitleMarkUnwatched() {
        #expect(
            SeriesDetailPresentationPolicy.episodeWatchActionTitle(isWatched: true)
            == "Mark Episode as Unwatched"
        )
    }

    @Test func episodeWatchActionTitleMarkWatched() {
        #expect(
            SeriesDetailPresentationPolicy.episodeWatchActionTitle(isWatched: false)
            == "Mark Episode as Watched"
        )
    }

    // MARK: watchStatusIcon

    @Test func watchStatusIconForWatched() {
        #expect(SeriesDetailPresentationPolicy.watchStatusIcon(for: .watched) == "checkmark.circle.fill")
    }

    @Test func watchStatusIconForInProgress() {
        #expect(SeriesDetailPresentationPolicy.watchStatusIcon(for: .inProgress) == "play.circle.fill")
    }

    @Test func watchStatusIconForNotWatched() {
        #expect(SeriesDetailPresentationPolicy.watchStatusIcon(for: .notWatched) == "circle")
    }

    @Test func watchStatusIconForSelectionRequired() {
        #expect(
            SeriesDetailPresentationPolicy.watchStatusIcon(for: .selectionRequired)
            == "rectangle.and.hand.point.up.left.fill"
        )
    }

    // MARK: selectedEpisodeWatchState

    @Test func selectedEpisodeWatchStateRequiresSelection() {
        #expect(
            SeriesDetailPresentationPolicy.selectedEpisodeWatchState(
                hasSelectedEpisode: false,
                isSelectedEpisodeCompleted: false
            ) == .selectionRequired
        )
    }

    @Test func selectedEpisodeWatchStateWatched() {
        #expect(
            SeriesDetailPresentationPolicy.selectedEpisodeWatchState(
                hasSelectedEpisode: true,
                isSelectedEpisodeCompleted: true
            ) == .watched
        )
    }

    @Test func selectedEpisodeWatchStateNotWatched() {
        #expect(
            SeriesDetailPresentationPolicy.selectedEpisodeWatchState(
                hasSelectedEpisode: true,
                isSelectedEpisodeCompleted: false
            ) == .notWatched
        )
    }

    @Test func selectedEpisodeWatchStateCompletedFlagIgnoredWhenNoSelection() {
        #expect(
            SeriesDetailPresentationPolicy.selectedEpisodeWatchState(
                hasSelectedEpisode: false,
                isSelectedEpisodeCompleted: true
            ) == .selectionRequired
        )
    }

    // MARK: seriesWatchProgressLabel

    @Test func seriesWatchProgressLabelZeroTotalEdgeCase() {
        #expect(
            SeriesDetailPresentationPolicy.seriesWatchProgressLabel(
                watchedCount: 0,
                seasonEpisodeCounts: []
            ) == "Series Actions"
        )
    }

    @Test func seriesWatchProgressLabelSomeWatched() {
        #expect(
            SeriesDetailPresentationPolicy.seriesWatchProgressLabel(
                watchedCount: 3,
                seasonEpisodeCounts: [5, 5]
            ) == "3/10 watched"
        )
    }

    @Test func seriesWatchProgressLabelAllWatched() {
        #expect(
            SeriesDetailPresentationPolicy.seriesWatchProgressLabel(
                watchedCount: 10,
                seasonEpisodeCounts: [5, 5]
            ) == "10/10 watched"
        )
    }

    @Test func seriesWatchProgressLabelWatchedCountExceedsComputedTotal() {
        // watchedCount is used as the total when it exceeds the sum of seasonEpisodeCounts
        #expect(
            SeriesDetailPresentationPolicy.seriesWatchProgressLabel(
                watchedCount: 12,
                seasonEpisodeCounts: [5, 5]
            ) == "12/12 watched"
        )
    }
}
