import SwiftUI
import Testing
@testable import VPStudio

@Suite("Detail Row Rendering Coverage")
@MainActor
struct DetailRowRenderCoverageTests {
    @Test
    func rendersRatingSheetScaleBranchesWithoutSubmittingActions() {
        let dislikeViewModel = makeDetailViewModel(mediaType: .movie)
        dislikeViewModel.feedbackScaleMode = .likeDislike
        dislikeViewModel.currentFeedbackValue = 0

        let likeViewModel = makeDetailViewModel(mediaType: .movie)
        likeViewModel.feedbackScaleMode = .likeDislike
        likeViewModel.currentFeedbackValue = 1

        let emptyTenPointViewModel = makeDetailViewModel(mediaType: .movie)
        emptyTenPointViewModel.feedbackScaleMode = .oneToTen

        let selectedTenPointViewModel = makeDetailViewModel(mediaType: .movie)
        selectedTenPointViewModel.feedbackScaleMode = .oneToTen
        selectedTenPointViewModel.currentFeedbackValue = 8

        let emptyHundredPointViewModel = makeDetailViewModel(mediaType: .movie)
        emptyHundredPointViewModel.feedbackScaleMode = .oneToHundred

        let selectedHundredPointViewModel = makeDetailViewModel(mediaType: .movie)
        selectedHundredPointViewModel.feedbackScaleMode = .oneToHundred
        selectedHundredPointViewModel.currentFeedbackValue = 87

        var showDislike = true
        var showLike = true
        var showEmptyTen = true
        var showSelectedTen = true
        var showEmptyHundred = true
        var showSelectedHundred = true
        var draftEmptyTen = 5.0
        var draftSelectedTen = 8.0
        var draftEmptyHundred = 42.0
        var draftSelectedHundred = 87.0

        let view = VStack(spacing: 16) {
            DetailRatingSheet(
                viewModel: dislikeViewModel,
                isShowing: Binding(get: { showDislike }, set: { showDislike = $0 }),
                draftFeedbackValue: .constant(0)
            )
            DetailRatingSheet(
                viewModel: likeViewModel,
                isShowing: Binding(get: { showLike }, set: { showLike = $0 }),
                draftFeedbackValue: .constant(1)
            )
            DetailRatingSheet(
                viewModel: emptyTenPointViewModel,
                isShowing: Binding(get: { showEmptyTen }, set: { showEmptyTen = $0 }),
                draftFeedbackValue: Binding(get: { draftEmptyTen }, set: { draftEmptyTen = $0 })
            )
            DetailRatingSheet(
                viewModel: selectedTenPointViewModel,
                isShowing: Binding(get: { showSelectedTen }, set: { showSelectedTen = $0 }),
                draftFeedbackValue: Binding(get: { draftSelectedTen }, set: { draftSelectedTen = $0 })
            )
            DetailRatingSheet(
                viewModel: emptyHundredPointViewModel,
                isShowing: Binding(get: { showEmptyHundred }, set: { showEmptyHundred = $0 }),
                draftFeedbackValue: Binding(get: { draftEmptyHundred }, set: { draftEmptyHundred = $0 })
            )
            DetailRatingSheet(
                viewModel: selectedHundredPointViewModel,
                isShowing: Binding(get: { showSelectedHundred }, set: { showSelectedHundred = $0 }),
                draftFeedbackValue: Binding(get: { draftSelectedHundred }, set: { draftSelectedHundred = $0 })
            )
        }
        .padding()

        SwiftUIViewDiagnosticHost.render(view, width: 760, height: 1_400)

        #expect(showDislike)
        #expect(showLike)
        #expect(showEmptyTen)
        #expect(showSelectedTen)
        #expect(showEmptyHundred)
        #expect(showSelectedHundred)
        #expect(dislikeViewModel.currentFeedbackValue == 0)
        #expect(likeViewModel.currentFeedbackValue == 1)
        #expect(emptyTenPointViewModel.currentFeedbackValue == nil)
        #expect(selectedTenPointViewModel.currentFeedbackValue == 8)
        #expect(emptyHundredPointViewModel.currentFeedbackValue == nil)
        #expect(selectedHundredPointViewModel.currentFeedbackValue == 87)
    }

    @Test
    func rendersAIAnalysisVerdictLoadingErrorAndActionBranchesWithoutFetching() {
        let verdicts: [AIPersonalizedAnalysis.Verdict] = [
            .strongYes,
            .yes,
            .maybe,
            .no,
            .strongNo,
        ]
        let analysisViewModels = verdicts.enumerated().map { offset, verdict in
            let viewModel = makeDetailViewModel(mediaType: .movie)
            viewModel.aiAnalysis = AIPersonalizedAnalysis(
                personalizedDescription: "Verdict fixture \(offset)",
                predictedRating: Double(9 - offset),
                verdict: verdict,
                reasons: offset == 1 ? [] : ["Taste match", "Recent rating overlap"]
            )
            return viewModel
        }
        let loadingViewModel = makeDetailViewModel(mediaType: .movie)
        loadingViewModel.isLoadingAIAnalysis = true

        let errorViewModel = makeDetailViewModel(mediaType: .movie)
        errorViewModel.aiAnalysisError = "Analysis provider unavailable"

        let actionViewModel = makeDetailViewModel(mediaType: .movie)

        let emptyViewModel = DetailViewModel(appState: AppState(testHooks: .init()))

        let view = VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(analysisViewModels.enumerated()), id: \.offset) { item in
                DetailAIAnalysis(viewModel: item.element)
            }
            DetailAIAnalysis(viewModel: loadingViewModel)
            DetailAIAnalysis(viewModel: errorViewModel)
            DetailAIAnalysis(viewModel: actionViewModel)
            DetailAIAnalysis(viewModel: emptyViewModel)
        }
        .padding()

        SwiftUIViewDiagnosticHost.render(view, width: 720, height: 980)

        #expect(analysisViewModels.allSatisfy { $0.aiAnalysis != nil })
        #expect(loadingViewModel.isLoadingAIAnalysis)
        #expect(errorViewModel.aiAnalysisError == "Analysis provider unavailable")
        #expect(actionViewModel.aiAnalysis == nil)
    }

    @Test
    func rendersTorrentSectionEmptyLoadingAndLoadMoreBranchesWithoutPlaying() {
        let changedEpisodeViewModel = makeDetailViewModel(mediaType: .series)
        let selectedEpisode = makeEpisode(id: "fresh-episode", episodeNumber: 4)
        changedEpisodeViewModel.selectedEpisode = selectedEpisode
        changedEpisodeViewModel.selectedSeason = selectedEpisode.seasonNumber
        changedEpisodeViewModel.torrentSearch.didSearch = true

        let didSearchViewModel = makeDetailViewModel(mediaType: .movie)
        didSearchViewModel.torrentSearch.didSearch = true

        let selectEpisodeViewModel = makeDetailViewModel(mediaType: .series)

        let loadingSearchViewModel = makeDetailViewModel(mediaType: .movie)
        loadingSearchViewModel.viewState = .loading(.torrentSearch)

        let resolvingViewModel = makeDetailViewModel(mediaType: .movie)
        resolvingViewModel.viewState = .loading(.streamResolution)

        let loadMoreViewModel = makeDetailViewModel(mediaType: .movie)
        loadMoreViewModel.torrentSearch.setSearchResults(
            [
                makeTorrent(infoHashPrefix: "111111", title: "First Result 1080p WEB-DL"),
                makeTorrent(infoHashPrefix: "222222", title: "Second Result 2160p HDR10 WEB-DL"),
                makeTorrent(infoHashPrefix: "333333", title: "Third Result 720p HDTV"),
            ],
            initialBatchSize: 1
        )
        loadMoreViewModel.torrentSearch.didSearch = true

        var isPlayerOpening = false
        var playerOpeningError: String?
        var playedTorrents: [TorrentResult] = []

        let view = VStack(spacing: 20) {
            DetailTorrentsSection(
                viewModel: changedEpisodeViewModel,
                mediaType: .series,
                streamResultsAnchor: "changed",
                isPlayerOpening: Binding(get: { isPlayerOpening }, set: { isPlayerOpening = $0 }),
                playerOpeningError: Binding(get: { playerOpeningError }, set: { playerOpeningError = $0 }),
                onPlayTorrent: { playedTorrents.append($0) }
            )
            DetailTorrentsSection(
                viewModel: didSearchViewModel,
                mediaType: .movie,
                streamResultsAnchor: "searched",
                isPlayerOpening: Binding(get: { isPlayerOpening }, set: { isPlayerOpening = $0 }),
                playerOpeningError: Binding(get: { playerOpeningError }, set: { playerOpeningError = $0 }),
                onPlayTorrent: { playedTorrents.append($0) }
            )
            DetailTorrentsSection(
                viewModel: selectEpisodeViewModel,
                mediaType: .series,
                streamResultsAnchor: "select",
                isPlayerOpening: Binding(get: { isPlayerOpening }, set: { isPlayerOpening = $0 }),
                playerOpeningError: Binding(get: { playerOpeningError }, set: { playerOpeningError = $0 }),
                onPlayTorrent: { playedTorrents.append($0) }
            )
            DetailTorrentsSection(
                viewModel: loadingSearchViewModel,
                mediaType: .movie,
                streamResultsAnchor: "loading",
                isPlayerOpening: Binding(get: { isPlayerOpening }, set: { isPlayerOpening = $0 }),
                playerOpeningError: Binding(get: { playerOpeningError }, set: { playerOpeningError = $0 }),
                onPlayTorrent: { playedTorrents.append($0) }
            )
            DetailTorrentsSection(
                viewModel: resolvingViewModel,
                mediaType: .movie,
                streamResultsAnchor: "resolving",
                isPlayerOpening: Binding(get: { isPlayerOpening }, set: { isPlayerOpening = $0 }),
                playerOpeningError: Binding(get: { playerOpeningError }, set: { playerOpeningError = $0 }),
                onPlayTorrent: { playedTorrents.append($0) }
            )
            DetailTorrentsSection(
                viewModel: loadMoreViewModel,
                mediaType: .movie,
                streamResultsAnchor: "load-more",
                isPlayerOpening: Binding(get: { isPlayerOpening }, set: { isPlayerOpening = $0 }),
                playerOpeningError: Binding(get: { playerOpeningError }, set: { playerOpeningError = $0 }),
                onPlayTorrent: { playedTorrents.append($0) }
            )
        }
        .padding()

        SwiftUIViewDiagnosticHost.render(view, width: 820, height: 1_200)

        #expect(loadMoreViewModel.canLoadMoreTorrents)
        #expect(loadMoreViewModel.remainingTorrentCount == 2)
        #expect(playedTorrents.isEmpty)
    }

    @Test
    func rendersEpisodeCardsForFallbackProgressAndCompletedBranchesWithoutActions() {
        let inProgressEpisode = Episode(
            id: "render-s1e1",
            mediaId: "render-series",
            seasonNumber: 1,
            episodeNumber: 1,
            title: "Pilot",
            overview: "A crew follows a signal.",
            airDate: "2024-01-01",
            stillPath: "/episode.jpg",
            runtime: 47
        )
        let completedEpisode = Episode(
            id: "render-s1e2",
            mediaId: "render-series",
            seasonNumber: 1,
            episodeNumber: 2,
            title: nil,
            overview: nil,
            airDate: nil,
            stillPath: nil,
            runtime: nil
        )
        let inProgress = WatchHistory(
            id: "render-progress",
            mediaId: inProgressEpisode.mediaId,
            episodeId: inProgressEpisode.id,
            title: inProgressEpisode.displayTitle,
            progress: 900,
            duration: 3600,
            watchedAt: Date(timeIntervalSince1970: 100),
            isCompleted: false
        )
        let completed = WatchHistory(
            id: "render-complete",
            mediaId: completedEpisode.mediaId,
            episodeId: completedEpisode.id,
            title: completedEpisode.displayTitle,
            progress: 3600,
            duration: 3600,
            watchedAt: Date(timeIntervalSince1970: 200),
            isCompleted: true
        )
        var selectedEpisodes: [Episode] = []
        var toggledEpisodes: [Episode] = []

        let view = VStack(spacing: 18) {
            EpisodeCardView(
                episode: inProgressEpisode,
                watchState: inProgress,
                isSelected: true,
                onSelect: { selectedEpisodes.append(inProgressEpisode) },
                onToggleWatched: { toggledEpisodes.append(inProgressEpisode) }
            )
            EpisodeCardView(
                episode: completedEpisode,
                watchState: completed,
                isSelected: false,
                onSelect: { selectedEpisodes.append(completedEpisode) },
                onToggleWatched: { toggledEpisodes.append(completedEpisode) }
            )
            EpisodeCardView(
                episode: completedEpisode,
                watchState: nil,
                isSelected: false,
                onSelect: { selectedEpisodes.append(completedEpisode) },
                onToggleWatched: { toggledEpisodes.append(completedEpisode) }
            )
            EpisodeRow(
                episodes: [inProgressEpisode, completedEpisode],
                episodeWatchStates: [
                    inProgressEpisode.id: inProgress,
                    completedEpisode.id: completed,
                ],
                selectedEpisodeID: inProgressEpisode.id,
                onSelectEpisode: { selectedEpisodes.append($0) },
                onToggleWatched: { toggledEpisodes.append($0) }
            )
        }
        .padding()

        SwiftUIViewDiagnosticHost.render(view, width: 620, height: 760)

        #expect(selectedEpisodes.isEmpty)
        #expect(toggledEpisodes.isEmpty)
    }

    @Test
    func rendersTorrentRowsForOpeningErrorAndDownloadStateBranchesWithoutActions() {
        let richTorrent = TorrentResult(
            infoHash: "abcdef1234567890abcdef1234567890abcdef12",
            title: "Dune 2021 2160p DV Atmos WEB-DL",
            sizeBytes: 8_589_934_592,
            seeders: 42,
            leechers: 3,
            quality: .uhd4k,
            codec: .h265,
            audio: .atmos,
            source: .webDL,
            hdr: .dolbyVision,
            indexerName: "Fixture",
            magnetURI: "magnet:?xt=urn:btih:abcdef1234567890abcdef1234567890abcdef12",
            isCached: true,
            cachedOnService: "Premiumize"
        )
        let sparseTorrent = TorrentResult(
            infoHash: "bbbbbb1234567890bbbbbb1234567890bbbbbb12",
            title: "Unknown Stream",
            sizeBytes: 734_003_200,
            seeders: 0,
            leechers: 0,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            indexerName: "Fixture",
            magnetURI: nil,
            isCached: false,
            cachedOnService: nil
        )
        var isOpening = false
        var openingError: String?
        var playCount = 0
        var downloadCount = 0
        let downloadStates: [DownloadButtonState] = [
            .idle,
            .resolving,
            .downloading,
            .completed,
            .failed,
        ]

        let view = VStack(spacing: 10) {
            ForEach(Array(downloadStates.enumerated()), id: \.offset) { item in
                TorrentResultRow(
                    torrent: richTorrent,
                    isPlayerOpening: Binding(get: { isOpening }, set: { isOpening = $0 }),
                    playerOpeningError: Binding(get: { openingError }, set: { openingError = $0 }),
                    onPlay: { playCount += 1 },
                    onDownload: { downloadCount += 1 },
                    downloadState: item.element
                )
            }

            TorrentResultRow(
                torrent: sparseTorrent,
                isPlayerOpening: .constant(true),
                playerOpeningError: .constant(nil),
                onPlay: { playCount += 1 },
                onDownload: nil,
                downloadState: .idle
            )
            TorrentResultRow(
                torrent: sparseTorrent,
                isPlayerOpening: .constant(false),
                playerOpeningError: .constant("Player unavailable"),
                onPlay: { playCount += 1 },
                onDownload: nil,
                downloadState: .idle
            )
        }
        .padding()

        SwiftUIViewDiagnosticHost.render(view, width: 760, height: 760)

        #expect(isOpening == false)
        #expect(openingError == nil)
        #expect(playCount == 0)
        #expect(downloadCount == 0)
    }

    private func makeDetailViewModel(mediaType: MediaType) -> DetailViewModel {
        let viewModel = DetailViewModel(appState: AppState(testHooks: .init()))
        viewModel.mediaItem = MediaItem(
            id: "detail-render-\(mediaType.rawValue)",
            type: mediaType,
            title: mediaType == .series ? "The Expanse" : "Dune",
            year: 2021,
            posterPath: nil,
            backdropPath: nil,
            overview: "Fixture overview",
            genres: ["Science Fiction"],
            imdbRating: 8.1,
            runtime: 155,
            status: "Released",
            tmdbId: 123
        )
        return viewModel
    }

    private func makeEpisode(id: String, episodeNumber: Int) -> Episode {
        Episode(
            id: id,
            mediaId: "detail-render-series",
            seasonNumber: 1,
            episodeNumber: episodeNumber,
            title: "Episode \(episodeNumber)",
            overview: "Episode overview",
            airDate: "2024-01-0\(episodeNumber)",
            stillPath: nil,
            runtime: 45
        )
    }

    private func makeTorrent(infoHashPrefix: String, title: String) -> TorrentResult {
        TorrentResult(
            infoHash: "\(infoHashPrefix)1234567890abcdef1234567890abcdef12",
            title: title,
            sizeBytes: 2_147_483_648,
            seeders: 12,
            leechers: 1,
            quality: VideoQuality.parse(from: title),
            codec: VideoCodec.parse(from: title),
            audio: AudioFormat.parse(from: title),
            source: SourceType.parse(from: title),
            hdr: HDRFormat.parse(from: title),
            indexerName: "Fixture",
            magnetURI: "magnet:?xt=urn:btih:\(infoHashPrefix)1234567890abcdef1234567890abcdef12",
            isCached: false,
            cachedOnService: nil
        )
    }
}
