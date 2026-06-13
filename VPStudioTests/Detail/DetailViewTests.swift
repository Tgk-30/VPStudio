import Testing
@testable import VPStudio
import SwiftUI

@Suite("DetailView")
final class DetailViewTests {

    // MARK: - DetailInitialAction Tests

    @Suite("DetailInitialAction")
    struct DetailInitialActionTests {
        @Test func noneRawValue() {
            #expect(DetailInitialAction.none.rawValue == "none")
        }

        @Test func resumePlaybackRawValue() {
            #expect(DetailInitialAction.resumePlayback.rawValue == "resumePlayback")
        }

        @Test func equatable() {
            #expect(DetailInitialAction.none == DetailInitialAction.none)
            #expect(DetailInitialAction.resumePlayback == DetailInitialAction.resumePlayback)
            #expect(DetailInitialAction.none != DetailInitialAction.resumePlayback)
        }

        @Test func hashable() {
            let set: Set<DetailInitialAction> = [.none, .resumePlayback]
            #expect(set.count == 2)
        }
    }

    // MARK: - DetailAutoSearchPolicy Tests

    @Suite("DetailAutoSearchPolicy")
    struct AutoSearchPolicyTests {
        @Test func movieWithMediaItemAutoSearches() {
            #expect(
                DetailAutoSearchPolicy.shouldAutoSearch(
                    previewType: .movie,
                    hasMediaItem: true,
                    hasSelectedEpisode: false,
                    hasExplicitEpisodeContext: false
                )
            )
        }

        @Test func movieWithoutMediaItemDoesNotAutoSearch() {
            #expect(
                DetailAutoSearchPolicy.shouldAutoSearch(
                    previewType: .movie,
                    hasMediaItem: false,
                    hasSelectedEpisode: false,
                    hasExplicitEpisodeContext: false
                ) == false
            )
        }

        @Test func seriesNeverAutoSearches() {
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
                    hasExplicitEpisodeContext: true
                ) == false
            )
        }

        @Test func episodeContextIgnoredForSeries() {
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

    // MARK: - DetailInitialRenderPolicy Tests

    @Suite("DetailInitialRenderPolicy")
    struct InitialRenderPolicyTests {
        @Test func showsContentWhenViewModelExistsAndNotPreparing() {
            #expect(
                DetailInitialRenderPolicy.shouldShowContent(
                    hasViewModel: true,
                    isPreparingInitialPresentation: false
                )
            )
        }

        @Test func showsSkeletonWhenViewModelMissing() {
            #expect(
                DetailInitialRenderPolicy.shouldShowContent(
                    hasViewModel: false,
                    isPreparingInitialPresentation: false
                ) == false
            )
        }

        @Test func showsSkeletonWhenStillPreparing() {
            #expect(
                DetailInitialRenderPolicy.shouldShowContent(
                    hasViewModel: true,
                    isPreparingInitialPresentation: true
                ) == false
            )
        }

        @Test func showsContentWhenPrimaryMediaResolvedDuringPreparation() {
            #expect(
                DetailInitialRenderPolicy.shouldShowContent(
                    hasViewModel: true,
                    isPreparingInitialPresentation: true,
                    hasResolvedPrimaryMedia: true
                )
            )
        }

        @Test func showsSkeletonWhenBothConditionsMet() {
            #expect(
                DetailInitialRenderPolicy.shouldShowContent(
                    hasViewModel: false,
                    isPreparingInitialPresentation: true
                ) == false
            )
        }
    }

    // MARK: - DetailRefreshLoadingPresentationPolicy Tests

    @Suite("DetailRefreshLoadingPresentationPolicy")
    struct RefreshLoadingPresentationPolicyTests {
        @Test func refreshTitleIsStable() {
            #expect(DetailRefreshLoadingPresentationPolicy.refreshTitle == "Refreshing Details")
        }

        @Test func blockingOverlayTitleTracksSeasonEpisodeLoadingState() {
            #expect(
                DetailRefreshLoadingPresentationPolicy.blockingOverlayTitle(
                    isLoadingSeasonEpisodes: true
                ) == "Loading Episodes"
            )
            #expect(
                DetailRefreshLoadingPresentationPolicy.blockingOverlayTitle(
                    isLoadingSeasonEpisodes: false
                ) == "Loading Details"
            )
        }

        @Test func blockingOverlayShowsWhenLoadingWithoutMediaItem() {
            #expect(
                DetailRefreshLoadingPresentationPolicy.shouldShowBlockingOverlay(
                    isLoadingDetail: true,
                    isLoadingSeasonEpisodes: false,
                    hasMediaItem: false
                )
            )
        }

        @Test func blockingOverlayHiddenWhenHasMediaItem() {
            #expect(
                DetailRefreshLoadingPresentationPolicy.shouldShowBlockingOverlay(
                    isLoadingDetail: true,
                    isLoadingSeasonEpisodes: false,
                    hasMediaItem: true
                ) == false
            )
        }

        @Test func blockingOverlayHiddenWhenNotLoading() {
            #expect(
                DetailRefreshLoadingPresentationPolicy.shouldShowBlockingOverlay(
                    isLoadingDetail: false,
                    isLoadingSeasonEpisodes: false,
                    hasMediaItem: false
                ) == false
            )
        }

        @Test func refreshIndicatorShowsWhenLoadingWithMediaItem() {
            #expect(
                DetailRefreshLoadingPresentationPolicy.shouldShowRefreshIndicator(
                    isLoadingDetail: true,
                    isLoadingSeasonEpisodes: false,
                    hasMediaItem: true
                )
            )
        }

        @Test func refreshIndicatorHiddenWhenLoadingSeasonEpisodes() {
            #expect(
                DetailRefreshLoadingPresentationPolicy.shouldShowRefreshIndicator(
                    isLoadingDetail: true,
                    isLoadingSeasonEpisodes: true,
                    hasMediaItem: true
                ) == false
            )
        }

        @Test func refreshIndicatorHiddenWithoutMediaItem() {
            #expect(
                DetailRefreshLoadingPresentationPolicy.shouldShowRefreshIndicator(
                    isLoadingDetail: true,
                    isLoadingSeasonEpisodes: false,
                    hasMediaItem: false
                ) == false
            )
        }
    }

    // MARK: - DetailPresentationPolicy Tests

    @Suite("DetailPresentationPolicy")
    struct PresentationPolicyTests {
        @Test func yearTextReturnsNilForNil() {
            #expect(DetailPresentationPolicy.yearText(nil) == nil)
        }

        @Test func yearTextReturnsString() {
            #expect(DetailPresentationPolicy.yearText(2024) == "2024")
        }

        @Test func imdbRatingTextReturnsNilForNil() {
            #expect(DetailPresentationPolicy.imdbRatingText(nil) == nil)
        }

        @Test func imdbRatingTextReturnsNilForZero() {
            #expect(DetailPresentationPolicy.imdbRatingText(0) == nil)
        }

        @Test func imdbRatingTextReturnsNilForNegative() {
            #expect(DetailPresentationPolicy.imdbRatingText(-1.0) == nil)
        }

        @Test func imdbRatingTextFormatsPositiveRating() {
            #expect(DetailPresentationPolicy.imdbRatingText(7.8) == "7.8")
        }

        @Test func runtimeTextReturnsNilForNil() {
            #expect(DetailPresentationPolicy.runtimeText(nil) == nil)
        }

        @Test func runtimeTextReturnsNilForEmpty() {
            #expect(DetailPresentationPolicy.runtimeText("") == nil)
        }

        @Test func runtimeTextReturnsValue() {
            #expect(DetailPresentationPolicy.runtimeText("2h 15m") == "2h 15m")
        }

        @Test func activeSessionToastTextIsStable() {
            #expect(DetailPresentationPolicy.activeSessionToastText == "A video is already playing")
        }

        @Test func feedbackDraftValueWithNilReturnsMaximum() {
            #expect(
                DetailPresentationPolicy.feedbackDraftValue(
                    currentValue: nil,
                    scaleMode: .likeDislike
                ) == 1.0
            )
            #expect(
                DetailPresentationPolicy.feedbackDraftValue(
                    currentValue: nil,
                    scaleMode: .oneToTen
                ) == 10.0
            )
            #expect(
                DetailPresentationPolicy.feedbackDraftValue(
                    currentValue: nil,
                    scaleMode: .oneToHundred
                ) == 100.0
            )
        }

        @Test func feedbackDraftValueClampsOutOfRange() {
            #expect(
                DetailPresentationPolicy.feedbackDraftValue(
                    currentValue: 15,
                    scaleMode: .oneToTen
                ) == 10.0
            )
            #expect(
                DetailPresentationPolicy.feedbackDraftValue(
                    currentValue: -5,
                    scaleMode: .oneToTen
                ) == 1.0
            )
        }

        @Test func shareItemWithIMDbPrefix() {
            let result = DetailPresentationPolicy.shareItem(
                previewID: "tt0111161",
                previewTitle: "The Shawshank Redemption",
                previewType: .movie,
                previewTMDBID: nil,
                mediaTitle: nil,
                mediaTMDBID: nil
            )
            #expect(result.contains("tt0111161"))
            #expect(result.contains("imdb.com"))
        }

        @Test func shareItemWithTMDBMovie() {
            let result = DetailPresentationPolicy.shareItem(
                previewID: "local-123",
                previewTitle: "Inception",
                previewType: .movie,
                previewTMDBID: 27205,
                mediaTitle: nil,
                mediaTMDBID: nil
            )
            #expect(result.contains("themoviedb.org"))
            #expect(result.contains("movie"))
            #expect(result.contains("27205"))
        }

        @Test func shareItemWithTMDbSeries() {
            let result = DetailPresentationPolicy.shareItem(
                previewID: "local-456",
                previewTitle: "Breaking Bad",
                previewType: .series,
                previewTMDBID: 1396,
                mediaTitle: nil,
                mediaTMDBID: nil
            )
            #expect(result.contains("themoviedb.org"))
            #expect(result.contains("tv"))
            #expect(result.contains("1396"))
        }

        @Test func shareItemPrefersMediaTitleOverPreview() {
            let result = DetailPresentationPolicy.shareItem(
                previewID: "tt999",
                previewTitle: "Original Title",
                previewType: .movie,
                previewTMDBID: nil,
                mediaTitle: "Better Title",
                mediaTMDBID: nil
            )
            #expect(result.hasPrefix("Better Title"))
        }
    }

    // MARK: - View Construction Tests

    @Suite("DetailView Construction")
    struct ViewConstructionTests {
        @Test func detailViewInitializesWithPreview() {
            let preview = MediaPreview(
                id: "tt123",
                type: .movie,
                title: "Test Movie",
                year: 2024
            )
            let view = DetailView(preview: preview)
            #expect(view.preview.id == "tt123")
            #expect(view.preview.title == "Test Movie")
        }

        @Test func detailViewInitializesWithInitialAction() {
            let preview = MediaPreview(
                id: "tt123",
                type: .movie,
                title: "Test Movie"
            )
            let view = DetailView(preview: preview, initialAction: .resumePlayback)
            #expect(view.initialAction == .resumePlayback)
        }

        @Test func detailViewDefaultInitialActionIsNone() {
            let preview = MediaPreview(
                id: "tt123",
                type: .movie,
                title: "Test Movie"
            )
            let view = DetailView(preview: preview)
            #expect(view.initialAction == .none)
        }
    }
}
