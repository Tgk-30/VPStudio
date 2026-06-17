import SwiftUI
import Testing
@testable import VPStudio

// MARK: - TabTransitionPolicy Tests

@Suite("TabTransitionPolicy Tests")
struct TabTransitionPolicyTestsViewsDetailviewpolicytests {
    @Test("scaleEffect is 0.98")
    func scaleEffectIsCorrect() {
        #expect(TabTransitionPolicy.scaleEffect == 0.98)
    }

    @Test("springResponse is 0.35")
    func springResponseIsCorrect() {
        #expect(TabTransitionPolicy.springResponse == 0.35)
    }

    @Test("springDamping is 0.82")
    func springDampingIsCorrect() {
        #expect(TabTransitionPolicy.springDamping == 0.82)
    }
}

// MARK: - DetailInitialAction Tests

@Suite("DetailInitialAction Tests")
struct DetailInitialActionTests {
    @Test("rawValue for none")
    func noneRawValue() {
        #expect(DetailInitialAction.none.rawValue == "none")
    }

    @Test("rawValue for resumePlayback")
    func resumePlaybackRawValue() {
        #expect(DetailInitialAction.resumePlayback.rawValue == "resumePlayback")
    }

    @Test("rawValue for playBestCached")
    func playBestCachedRawValue() {
        #expect(DetailInitialAction.playBestCached.rawValue == "playBestCached")
    }

    @Test("cases are hashable")
    func casesAreHashable() {
        let _ = DetailInitialAction.none.hashValue
        let _ = DetailInitialAction.resumePlayback.hashValue
        let _ = DetailInitialAction.playBestCached.hashValue
    }
}

// MARK: - DetailAutoSearchPolicy Tests

@Suite("DetailAutoSearchPolicy Tests")
struct DetailAutoSearchPolicyTestsViewsDetailviewpolicytests {
    @Test("returns false when no media item")
    func returnsFalseWhenNoMediaItem() {
        #expect(DetailAutoSearchPolicy.shouldAutoSearch(
            previewType: .movie,
            hasMediaItem: false,
            hasSelectedEpisode: false,
            hasExplicitEpisodeContext: false
        ) == false)
    }

    @Test("returns true for movie with media item")
    func returnsTrueForMovieWithMediaItem() {
        #expect(DetailAutoSearchPolicy.shouldAutoSearch(
            previewType: .movie,
            hasMediaItem: true,
            hasSelectedEpisode: false,
            hasExplicitEpisodeContext: false
        ) == true)
    }

    @Test("returns false for series regardless of episode context")
    func returnsFalseForSeries() {
        #expect(DetailAutoSearchPolicy.shouldAutoSearch(
            previewType: .series,
            hasMediaItem: true,
            hasSelectedEpisode: true,
            hasExplicitEpisodeContext: true
        ) == false)
    }
}

// MARK: - DetailInitialRenderPolicy Tests

@Suite("DetailInitialRenderPolicy Tests")
struct DetailInitialRenderPolicyTests {
    @Test("returns true when has viewModel and not preparing")
    func returnsTrueWhenReady() {
        #expect(DetailInitialRenderPolicy.shouldShowContent(
            hasViewModel: true,
            isPreparingInitialPresentation: false
        ) == true)
    }

    @Test("returns false when no viewModel")
    func returnsFalseWhenNoViewModel() {
        #expect(DetailInitialRenderPolicy.shouldShowContent(
            hasViewModel: false,
            isPreparingInitialPresentation: false
        ) == false)
    }

    @Test("returns false when preparing")
    func returnsFalseWhenPreparing() {
        #expect(DetailInitialRenderPolicy.shouldShowContent(
            hasViewModel: true,
            isPreparingInitialPresentation: true
        ) == false)
    }
}

// MARK: - DetailRefreshLoadingPresentationPolicy Tests

@Suite("DetailRefreshLoadingPresentationPolicy Tests")
struct DetailRefreshLoadingPresentationPolicyTests {
    @Test("refreshTitle is set correctly")
    func refreshTitleIsSet() {
        #expect(DetailRefreshLoadingPresentationPolicy.refreshTitle == "Refreshing Details")
    }

    @Test("shouldShowBlockingOverlay returns true when loading detail without media")
    func shouldShowBlockingOverlay() {
        #expect(DetailRefreshLoadingPresentationPolicy.shouldShowBlockingOverlay(
            isLoadingDetail: true,
            isLoadingSeasonEpisodes: false,
            hasMediaItem: false
        ) == true)
    }

    @Test("shouldShowBlockingOverlay returns false when has media")
    func shouldShowBlockingOverlayReturnsFalse() {
        #expect(DetailRefreshLoadingPresentationPolicy.shouldShowBlockingOverlay(
            isLoadingDetail: true,
            isLoadingSeasonEpisodes: false,
            hasMediaItem: true
        ) == false)
    }

    @Test("shouldShowRefreshIndicator returns true when loading with media")
    func shouldShowRefreshIndicator() {
        #expect(DetailRefreshLoadingPresentationPolicy.shouldShowRefreshIndicator(
            isLoadingDetail: true,
            isLoadingSeasonEpisodes: false,
            hasMediaItem: true
        ) == true)
    }

    @Test("shouldShowRefreshIndicator returns false when loading season episodes")
    func shouldShowRefreshIndicatorReturnsFalseWhenLoadingEpisodes() {
        #expect(DetailRefreshLoadingPresentationPolicy.shouldShowRefreshIndicator(
            isLoadingDetail: true,
            isLoadingSeasonEpisodes: true,
            hasMediaItem: true
        ) == false)
    }
}

// MARK: - DetailPresentationPolicy Tests

@Suite("DetailPresentationPolicy Tests")
struct DetailPresentationPolicyTests {
    @Test("activeSessionToastText is set correctly")
    func activeSessionToastTextIsSet() {
        #expect(DetailPresentationPolicy.activeSessionToastText == "A video is already playing")
    }

    @Test("yearText returns string for valid year")
    func yearTextReturnsString() {
        #expect(DetailPresentationPolicy.yearText(2024) == "2024")
    }

    @Test("yearText returns nil for nil year")
    func yearTextReturnsNil() {
        #expect(DetailPresentationPolicy.yearText(nil) == nil)
    }

    @Test("imdbRatingText returns formatted string for valid rating")
    func imdbRatingTextReturnsFormatted() {
        #expect(DetailPresentationPolicy.imdbRatingText(8.5) == "8.5")
    }

    @Test("imdbRatingText returns nil for zero rating")
    func imdbRatingTextReturnsNilForZero() {
        #expect(DetailPresentationPolicy.imdbRatingText(0) == nil)
    }

    @Test("imdbRatingText returns nil for negative rating")
    func imdbRatingTextReturnsNilForNegative() {
        #expect(DetailPresentationPolicy.imdbRatingText(-1) == nil)
    }

    @Test("runtimeText returns string for valid runtime")
    func runtimeTextReturnsString() {
        #expect(DetailPresentationPolicy.runtimeText("120 min") == "120 min")
    }

    @Test("runtimeText returns nil for nil runtime")
    func runtimeTextReturnsNil() {
        #expect(DetailPresentationPolicy.runtimeText(nil) == nil)
    }

    @Test("runtimeText returns nil for empty runtime")
    func runtimeTextReturnsNilForEmpty() {
        #expect(DetailPresentationPolicy.runtimeText("") == nil)
    }

    @Test("feedbackDraftValue returns clamped value")
    func feedbackDraftValueClamps() {
        #expect(DetailPresentationPolicy.feedbackDraftValue(currentValue: 15, scaleMode: .oneToTen) == 10)
    }

    @Test("feedbackDraftValue returns max when nil")
    func feedbackDraftValueReturnsMax() {
        #expect(DetailPresentationPolicy.feedbackDraftValue(currentValue: nil, scaleMode: .oneToTen) == 10)
    }

    @Test("shareItem returns IMDb link for IMDb IDs")
    func shareItemReturnsIMDBLink() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "tt1234567",
            previewTitle: "Test Movie",
            previewType: .movie,
            previewTMDBID: nil,
            mediaTitle: nil,
            mediaTMDBID: nil
        )
        #expect(result.contains("imdb.com"))
    }

    @Test("shareItem returns TMDB link when available")
    func shareItemReturnsTMDBLink() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "custom-id",
            previewTitle: "Test Movie",
            previewType: .movie,
            previewTMDBID: 123,
            mediaTitle: nil,
            mediaTMDBID: nil
        )
        #expect(result.contains("themoviedb.org"))
    }

    @Test("shareItem falls back to title when no links available")
    func shareItemFallsBackToTitle() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "custom-id",
            previewTitle: "Test Movie",
            previewType: .movie,
            previewTMDBID: nil,
            mediaTitle: nil,
            mediaTMDBID: nil
        )
        #expect(result == "Test Movie")
    }

    @Test("shareItem uses mediaTitle when available")
    func shareItemUsesMediaTitle() {
        let result = DetailPresentationPolicy.shareItem(
            previewID: "tt1234567",
            previewTitle: "Preview",
            previewType: .movie,
            previewTMDBID: nil,
            mediaTitle: "Media Title",
            mediaTMDBID: nil
        )
        #expect(result.contains("Media Title"))
    }
}