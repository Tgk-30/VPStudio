import Testing
@testable import VPStudio

// MARK: - Auto Search Policy

@Suite("DetailAutoSearchPolicy")
struct DetailAutoSearchPolicyTests {

    @Test
    func movieWithMediaItemReturnsTrue() {
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .movie,
                hasMediaItem: true,
                hasSelectedEpisode: false,
                hasExplicitEpisodeContext: false
            )
        )
    }

    @Test
    func movieWithoutMediaItemReturnsFalse() {
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .movie,
                hasMediaItem: false,
                hasSelectedEpisode: false,
                hasExplicitEpisodeContext: false
            ) == false
        )
    }

    @Test
    func seriesWithMediaItemReturnsFalse() {
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .series,
                hasMediaItem: true,
                hasSelectedEpisode: false,
                hasExplicitEpisodeContext: false
            ) == false
        )
    }

    @Test
    func seriesWithoutMediaItemReturnsFalse() {
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .series,
                hasMediaItem: false,
                hasSelectedEpisode: false,
                hasExplicitEpisodeContext: false
            ) == false
        )
    }

    @Test
    func movieIgnoresSelectedEpisodeFlag() {
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .movie,
                hasMediaItem: true,
                hasSelectedEpisode: true,
                hasExplicitEpisodeContext: false
            )
        )
    }

    @Test
    func movieIgnoresExplicitEpisodeContextFlag() {
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .movie,
                hasMediaItem: true,
                hasSelectedEpisode: false,
                hasExplicitEpisodeContext: true
            )
        )
    }

    @Test
    func seriesWithSelectedEpisodeReturnsFalse() {
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .series,
                hasMediaItem: true,
                hasSelectedEpisode: true,
                hasExplicitEpisodeContext: false
            ) == false
        )
    }

    @Test
    func seriesWithExplicitEpisodeContextReturnsFalse() {
        #expect(
            DetailAutoSearchPolicy.shouldAutoSearch(
                previewType: .series,
                hasMediaItem: true,
                hasSelectedEpisode: false,
                hasExplicitEpisodeContext: true
            ) == false
        )
    }
}

// MARK: - Share Item

@Suite("DetailPresentationPolicy.shareItem")
struct DetailPresentationPolicyShareItemTests {

    @Test
    func imdbLinkUsesMediaTitleWhenAvailable() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "tt0111161",
            previewTitle: "Fallback Title",
            previewType: .movie,
            previewTMDBID: 278,
            mediaTitle: "The Shawshank Redemption",
            mediaTMDBID: nil
        )
        #expect(result == "The Shawshank Redemption\nhttps://www.imdb.com/title/tt0111161/")
    }

    @Test
    func imdbLinkFallsBackToPreviewTitleWhenMediaTitleIsNil() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "tt0111161",
            previewTitle: "Fallback Title",
            previewType: .movie,
            previewTMDBID: 278,
            mediaTitle: nil,
            mediaTMDBID: nil
        )
        #expect(result == "Fallback Title\nhttps://www.imdb.com/title/tt0111161/")
    }

    @Test
    func tmdbMovieLinkUsesPreviewTMDBID() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "movie-278",
            previewTitle: "Inception",
            previewType: .movie,
            previewTMDBID: 27205,
            mediaTitle: nil,
            mediaTMDBID: nil
        )
        #expect(result == "Inception\nhttps://www.themoviedb.org/movie/27205")
    }

    @Test
    func tmdbSeriesLinkUsesPreviewTMDBID() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "tv-1396",
            previewTitle: "Breaking Bad",
            previewType: .series,
            previewTMDBID: 1396,
            mediaTitle: nil,
            mediaTMDBID: nil
        )
        #expect(result == "Breaking Bad\nhttps://www.themoviedb.org/tv/1396")
    }

    @Test
    func tmdbLinkPrefersMediaTMDBIDOverPreviewTMDBID() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "tv-9999",
            previewTitle: "Old Title",
            previewType: .series,
            previewTMDBID: 9999,
            mediaTitle: "Better Title",
            mediaTMDBID: 1396
        )
        #expect(result == "Better Title\nhttps://www.themoviedb.org/tv/1396")
    }

    @Test
    func tmdbMovieLinkUsesMediaTMDBIDWhenPreviewTMDBIDIsNil() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "local",
            previewTitle: "Local Movie",
            previewType: .movie,
            previewTMDBID: nil,
            mediaTitle: "Local Movie",
            mediaTMDBID: 12345
        )
        #expect(result == "Local Movie\nhttps://www.themoviedb.org/movie/12345")
    }

    @Test
    func returnsTitleOnlyWhenNoIDsAvailable() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "local",
            previewTitle: "Local Only",
            previewType: .movie,
            previewTMDBID: nil,
            mediaTitle: nil,
            mediaTMDBID: nil
        )
        #expect(result == "Local Only")
    }

    @Test
    func imdbPrefixTakesPrecedenceOverTMDBID() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "tt0109830",
            previewTitle: "Forrest Gump",
            previewType: .movie,
            previewTMDBID: 13,
            mediaTitle: nil,
            mediaTMDBID: 13
        )
        #expect(result == "Forrest Gump\nhttps://www.imdb.com/title/tt0109830/")
    }

    @Test
    func mediaTitleFallsBackToPreviewTitleForTmdbLink() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "movie-278",
            previewTitle: "Fallback Title",
            previewType: .movie,
            previewTMDBID: 278,
            mediaTitle: nil,
            mediaTMDBID: nil
        )
        #expect(result == "Fallback Title\nhttps://www.themoviedb.org/movie/278")
    }
}

// MARK: - Feedback Draft Value

@Suite("DetailPresentationPolicy.feedbackDraftValue")
struct DetailPresentationPolicyFeedbackDraftValueTests {

    @Test
    func nilCurrentValueReturnsMaximumForLikeDislike() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: nil,
                scaleMode: .likeDislike
            ) == 1
        )
    }

    @Test
    func nilCurrentValueReturnsMaximumForOneToTen() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: nil,
                scaleMode: .oneToTen
            ) == 10
        )
    }

    @Test
    func nilCurrentValueReturnsMaximumForOneToHundred() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: nil,
                scaleMode: .oneToHundred
            ) == 100
        )
    }

    @Test
    func clampsAboveMaximumForOneToTen() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: 15,
                scaleMode: .oneToTen
            ) == 10
        )
    }

    @Test
    func clampsBelowMinimumForOneToTen() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: -5,
                scaleMode: .oneToTen
            ) == 1
        )
    }

    @Test
    func clampsAboveMaximumForOneToHundred() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: 200,
                scaleMode: .oneToHundred
            ) == 100
        )
    }

    @Test
    func clampsBelowMinimumForOneToHundred() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: -10,
                scaleMode: .oneToHundred
            ) == 1
        )
    }

    @Test
    func preservesInRangeValueForLikeDislike() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: 0.5,
                scaleMode: .likeDislike
            ) == 0.5
        )
    }

    @Test
    func preservesInRangeValueForOneToTen() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: 7,
                scaleMode: .oneToTen
            ) == 7
        )
    }

    @Test
    func clampsAboveMaximumForLikeDislike() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: 5,
                scaleMode: .likeDislike
            ) == 1
        )
    }

    @Test
    func clampsBelowMinimumForLikeDislike() {
        #expect(
            DetailPresentationPolicy.feedbackDraftValue(
                currentValue: -1,
                scaleMode: .likeDislike
            ) == 0
        )
    }
}

@Suite("DetailPlaybackCopyPolicy")
struct DetailPlaybackCopyPolicyTests {
    @Test
    func noStreamMessagesMatchPlaybackContext() {
        #expect(
            DetailPlaybackCopyPolicy.noStreamsMessage(for: .cast)
                == "No streams available to cast right now."
        )
        #expect(
            DetailPlaybackCopyPolicy.noStreamsMessage(for: .playTorrent)
                == "Could not open stream. Please try another result."
        )
        #expect(
            DetailPlaybackCopyPolicy.noStreamsMessage(for: .resumePlayback)
                == "No streams are available to resume right now."
        )
    }

    @Test
    func streamResolutionFailureMessagesMatchPlaybackContext() {
        #expect(
            DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .cast)
                == "Could not open stream for casting."
        )
        #expect(
            DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .playTorrent)
                == "Could not open stream. Please try another result."
        )
        #expect(
            DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .resumePlayback)
                == "Could not resume playback right now."
        )
    }

    @Test
    func missingEpisodeMessageIsActionable() {
        #expect(DetailPlaybackCopyPolicy.missingEpisodeMessage == "Pick an episode to continue watching.")
    }
}

// MARK: - Metadata Text Formatting

@Suite("DetailPresentationPolicy metadata formatting")
struct DetailPresentationPolicyMetadataFormattingTests {

    @Test
    func activeSessionToastTextIsStable() {
        #expect(DetailPresentationPolicy.activeSessionToastText == "A video is already playing")
    }

    @Test
    func yearTextReturnsNilForNilYear() {
        #expect(DetailPresentationPolicy.yearText(nil) == nil)
    }

    @Test
    func yearTextReturnsStringForValidYear() {
        #expect(DetailPresentationPolicy.yearText(1999) == "1999")
    }

    @Test
    func imdbRatingTextReturnsNilForNilRating() {
        #expect(DetailPresentationPolicy.imdbRatingText(nil) == nil)
    }

    @Test
    func imdbRatingTextReturnsNilForZeroRating() {
        #expect(DetailPresentationPolicy.imdbRatingText(0) == nil)
    }

    @Test
    func imdbRatingTextReturnsNilForNegativeRating() {
        #expect(DetailPresentationPolicy.imdbRatingText(-1.5) == nil)
    }

    @Test
    func imdbRatingTextFormatsPositiveRatingToOneDecimal() {
        #expect(DetailPresentationPolicy.imdbRatingText(7.94) == "7.9")
    }

    @Test
    func imdbRatingTextRoundsToNearestTenth() {
        // String(format:) uses round-half-away-from-zero; 8.95 rounds to 8.9 due to binary representation
        #expect(DetailPresentationPolicy.imdbRatingText(8.96) == "9.0")
        #expect(DetailPresentationPolicy.imdbRatingText(8.94) == "8.9")
    }

    @Test
    func imdbRatingTextFormatsWholeNumber() {
        #expect(DetailPresentationPolicy.imdbRatingText(8.0) == "8.0")
    }

    @Test
    func imdbRatingTextIncludesLowPositiveRating() {
        #expect(DetailPresentationPolicy.imdbRatingText(0.1) == "0.1")
    }

    @Test
    func runtimeTextReturnsNilForNil() {
        #expect(DetailPresentationPolicy.runtimeText(nil) == nil)
    }

    @Test
    func runtimeTextReturnsNilForEmptyString() {
        #expect(DetailPresentationPolicy.runtimeText("") == nil)
    }

    @Test
    func runtimeTextReturnsValueForValidString() {
        #expect(DetailPresentationPolicy.runtimeText("2h 12m") == "2h 12m")
    }

    @Test
    func runtimeTextPassesThroughWhitespaceOnly() {
        #expect(DetailPresentationPolicy.runtimeText("   ") == "   ")
    }
}
