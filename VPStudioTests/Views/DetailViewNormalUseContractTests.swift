import Foundation
import Testing
#if os(visionOS)
import SwiftUI
import UIKit
#endif
@testable import VPStudio

@Suite("DetailView Normal-Use Contracts", .serialized)
struct DetailViewNormalUseContractTests {
    private static func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !(await condition()) {
            guard ContinuousClock.now < deadline else {
                Issue.record("waitUntil timed out after \(timeout)")
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: - DetailView Source Contracts

    @Test
    func openPlayerAssignsActiveSessionBeforeOpeningWindow() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")

        let assignRange = try requiredRange(of: "appState.activePlayerSession = request", in: source)
        let openRange = try requiredRange(of: "openWindow(id: \"player\", value: request)", in: source)

        #expect(assignRange.lowerBound < openRange.lowerBound)
    }

    @Test
    func openPlayerRechecksActiveSessionAfterExternalLaunchDecision() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")
        let activeSessionToken = "hasActivePlayerSession: appState.activePlayerSession != nil"
        let staleSessionToken = "hasActivePlayerSession: false,\n            didLaunchPreferredExternalPlayer: await launchWithPreferredPlayer"

        #expect(occurrenceCount(of: activeSessionToken, in: source) >= 2)
        #expect(source.contains(staleSessionToken) == false)
    }

    @Test
    func runInitialActionDefersWithoutMarkingHandled() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")

        let deferGuardRange = try requiredRange(of: "guard handling != .deferUntilMediaLoads else {", in: source)
        let handledRange = try requiredRange(of: "hasHandledInitialAction = true", in: source)

        // Deferral should happen before we mark the action handled, so a later pass can retry after media loads.
        #expect(deferGuardRange.lowerBound < handledRange.lowerBound)
    }

    @Test
    func runInitialActionMarksHandledBeforeSwitchingOnOutcome() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")

        let handledRange = try requiredRange(of: "hasHandledInitialAction = true", in: source)
        let switchRange = try requiredRange(of: "switch handling {", in: source)

        #expect(handledRange.lowerBound < switchRange.lowerBound)
    }

    @Test
    func castAndPlayShortCircuitOnActiveSessionBeforeOpeningStateChanges() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")

        let castGuardRange = try requiredRange(of: "private func castBestAvailable(_ vm: DetailViewModel) {", in: source)
        let castActiveSessionRange = try requiredRange(
            of: "guard appState.activePlayerSession == nil else {\n            showActiveSessionToast(for: appState.activePlayerSession)\n            return\n        }",
            in: source,
            after: castGuardRange.lowerBound
        )
        let castOpeningRange = try requiredRange(of: "isPlayerOpening = true", in: source, after: castActiveSessionRange.upperBound)

        let playGuardRange = try requiredRange(of: "private func playTorrent(_ torrent: TorrentResult, vm: DetailViewModel) {", in: source)
        let playActiveSessionRange = try requiredRange(
            of: "guard appState.activePlayerSession == nil else {\n            showActiveSessionToast(for: appState.activePlayerSession)\n            return\n        }",
            in: source,
            after: playGuardRange.lowerBound
        )
        let playOpeningRange = try requiredRange(of: "isPlayerOpening = true", in: source, after: playActiveSessionRange.upperBound)

        #expect(castActiveSessionRange.lowerBound < castOpeningRange.lowerBound)
        #expect(playActiveSessionRange.lowerBound < playOpeningRange.lowerBound)
    }

    @Test
    func qaEpisodeSelectionTriggersTorrentSearchAfterSelectingEpisode() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")

        let selectRange = try requiredRange(of: "vm.selectEpisode(episode)", in: source)
        let searchRange = try requiredRange(of: "await vm.searchTorrents()", in: source, after: selectRange.upperBound)

        #expect(selectRange.lowerBound < searchRange.lowerBound)
    }

    @Test
    func qaSampleDownloadPostsDownloadsChangedAfterEnqueue() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")

        let enqueueRange = try requiredRange(of: "appState.downloadManager.enqueueDownload(", in: source)
        let notifyRange = try requiredRange(of: "NotificationCenter.default.post(name: .downloadsDidChange, object: nil)", in: source)

        #expect(enqueueRange.lowerBound < notifyRange.lowerBound)
    }

    @Test
    func detailViewAvoidsPlaintextLoggingAndDirectDebugOutput() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")

        for forbiddenToken in ["print(", "debugPrint(", "NSLog(", "Logger(", "os_log("] {
            #expect(source.contains(forbiddenToken) == false)
        }
    }

    @Test
    func playerOpeningErrorsOnlyUsePolicyMessages() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")

        for requiredToken in [
            "DetailPlaybackCopyPolicy.noStreamsMessage(for: .cast)",
            "DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .cast)",
            "DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .playTorrent)",
            "DetailPlaybackCopyPolicy.missingEpisodeMessage",
            "DetailPlaybackCopyPolicy.noStreamsMessage(for: .resumePlayback)",
            "DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .resumePlayback)"
        ] {
            #expect(source.contains(requiredToken))
        }
    }

    // MARK: - Playback Routing Contracts (Runtime)

#if os(visionOS)
    @Test
    @MainActor
    func detailViewLoadsMovieAndHonorsActiveSessionResumePolicy() async throws {
        let database = try DatabaseManager(inMemoryNamed: "detail-view-movie-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, testHooks: .init())
        appState.activePlayerSession = PlayerSessionRequest(
            stream: Fixtures.stream(),
            mediaTitle: "Already Playing",
            mediaId: "tt-existing",
            episodeId: nil
        )

        let metadataProvider = StubMetadataProvider()
        await metadataProvider.setDetailResult(MediaItem(
            id: "ttmovie-1",
            type: .movie,
            title: "Fixture Movie",
            tmdbId: 777
        ))

        let indexerManager = StubIndexerManager()
        await indexerManager.setSearchResults([
            Fixtures.torrent(hash: "fixture-hash", title: "Fixture Movie 1080p")
        ])

        let viewModel = DetailViewModel(
            appState: appState,
            metadataProviderFactory: { _ in metadataProvider },
            indexerManager: indexerManager,
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )

        let preview = MediaPreview(
            id: "ttmovie-1",
            type: .movie,
            title: "Fixture Movie",
            tmdbId: 777
        )

        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                DetailView(
                    preview: preview,
                    initialAction: .resumePlayback,
                    initialViewModel: viewModel
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Self.waitUntil(timeout: .seconds(5)) {
            viewModel.mediaItem?.title == "Fixture Movie"
        }

        #expect(hosted.host.view.bounds.width > 0)
        #expect(viewModel.mediaItem?.title == "Fixture Movie")
        // Resume requested while a session is already active must short-circuit to the
        // "already playing" toast: no torrent search runs, so results stay empty and the
        // existing session is preserved (the resume policy is honored, not hijacked).
        #expect(viewModel.torrentSearch.results.isEmpty)
        #expect(appState.activePlayerSession?.mediaId == "tt-existing")
    }

    @Test
    @MainActor
    func detailViewLoadsSeriesContextWithoutAutoSearching() async throws {
        let database = try DatabaseManager(inMemoryNamed: "detail-view-series-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, testHooks: .init())

        let metadataProvider = StubMetadataProvider()
        await metadataProvider.setDetailResult(MediaItem(
            id: "ttseries-1",
            type: .series,
            title: "Fixture Series",
            tmdbId: 888
        ))
        await metadataProvider.setSeasonsResult([
            Season(id: 1, seasonNumber: 1, name: "Season 1", episodeCount: 2)
        ])
        await metadataProvider.setEpisodesResult([
            Episode(
                id: "ep-1",
                mediaId: "ttseries-1",
                seasonNumber: 1,
                episodeNumber: 1,
                title: "Pilot"
            ),
            Episode(
                id: "ep-2",
                mediaId: "ttseries-1",
                seasonNumber: 1,
                episodeNumber: 2,
                title: "Second"
            ),
        ])

        let viewModel = DetailViewModel(
            appState: appState,
            metadataProviderFactory: { _ in metadataProvider },
            indexerManager: StubIndexerManager(),
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )

        let preview = MediaPreview(
            id: "ttseries-1",
            type: .series,
            title: "Fixture Series",
            tmdbId: 888,
            episodeId: "ep-2"
        )

        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                DetailView(
                    preview: preview,
                    initialViewModel: viewModel
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Self.waitUntil(timeout: .seconds(5)) {
            viewModel.mediaItem?.type == .series &&
                viewModel.seasons.count == 1 &&
                viewModel.selectedEpisode?.id == "ep-2" &&
                viewModel.torrentSearch.results.isEmpty
        }

        #expect(hosted.host.view.bounds.width > 0)
        #expect(viewModel.mediaItem?.type == .series)
        #expect(viewModel.seasons.count == 1)
        #expect(viewModel.selectedEpisode?.id == "ep-2")
        #expect(viewModel.torrentSearch.results.isEmpty)
    }

    @Test
    @MainActor
    func detailViewRendersModalToastAndNotificationRefreshStates() async throws {
        let database = try DatabaseManager(inMemoryNamed: "detail-view-notifications-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, testHooks: .init())
        appState.activePlayerSession = PlayerSessionRequest(
            stream: Fixtures.stream(fileName: "already-playing.mkv"),
            mediaTitle: "Already Playing",
            mediaId: "tt-existing",
            episodeId: nil
        )

        let metadataProvider = StubMetadataProvider()
        await metadataProvider.setDetailResult(MediaItem(
            id: "tt-notification",
            type: .movie,
            title: "Notification Fixture",
            runtime: 121,
            tmdbId: 4_242
        ))

        let viewModel = DetailViewModel(
            appState: appState,
            metadataProviderFactory: { _ in metadataProvider },
            indexerManager: StubIndexerManager(),
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )
        viewModel.mediaItem = MediaItem(
            id: "tt-notification",
            type: .movie,
            title: "Notification Fixture",
            runtime: 121,
            tmdbId: 4_242
        )
        viewModel.torrentSearch.results = [
            Fixtures.torrent(hash: "notification-hash", title: "Notification.Fixture.1080p")
        ]
        viewModel.currentFeedbackValue = 8
        viewModel.feedbackScaleMode = .oneToTen

        let preview = MediaPreview(
            id: "tt-notification",
            type: .movie,
            title: "Notification Fixture",
            tmdbId: 4_242
        )

        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                DetailView(
                    preview: preview,
                    initialViewModel: viewModel,
                    initialTMDBApiKey: "fixture-key",
                    initialIsShowingRatingSheet: true,
                    initialDraftFeedbackValue: 8,
                    initialShowActiveSessionToast: true,
                    initialIsPlayerOpening: true,
                    initialPlayerOpeningError: "Resolving the selected stream took too long.",
                    initialIsPreparingInitialPresentation: false,
                    disablesAutomaticLoading: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 980)
        )
        defer { tearDownVisionWindow(hosted.window) }

        NotificationCenter.default.post(name: .libraryDidChange, object: nil)
        NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
        NotificationCenter.default.post(name: .tasteProfileDidChange, object: nil)
        NotificationCenter.default.post(name: .downloadsDidChange, object: nil)
        NotificationCenter.default.post(name: .tmdbApiKeyDidChange, object: nil)

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 350_000_000)

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.bounds.height > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
        #expect(appState.activePlayerSession?.mediaId == "tt-existing")
    }
#endif

    @Test @MainActor
    func makePlayerSessionRequestPublishesNextEpisodeCandidateForSeries() {
        let appState = AppState(testHooks: .init())
        let viewModel = DetailViewModel(appState: appState)

        viewModel.mediaItem = MediaItem(id: "tt-series", type: .series, title: "Show", tmdbId: 101)

        // Intentionally unordered input; next episode should come from season/episode ordering.
        let s2e1 = Episode(id: "s2e1", mediaId: "tt-series", seasonNumber: 2, episodeNumber: 1, title: "S2E1")
        let s1e3 = Episode(id: "s1e3", mediaId: "tt-series", seasonNumber: 1, episodeNumber: 3, title: "S1E3")
        let s1e2 = Episode(id: "s1e2", mediaId: "tt-series", seasonNumber: 1, episodeNumber: 2, title: "S1E2")
        let s1e1 = Episode(id: "s1e1", mediaId: "tt-series", seasonNumber: 1, episodeNumber: 1, title: "S1E1")
        viewModel.episodes = [s2e1, s1e3, s1e1, s1e2]

        viewModel.selectedEpisode = s1e2

        let stream = Fixtures.stream()
        let preview = MediaPreview(id: "tt-series", type: .series, title: "Show", tmdbId: 101)
        let request = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)

        #expect(request.episodeId == "s1e2")
        #expect(request.nextEpisode?.episodeId == "s1e3")
        #expect(request.nextEpisode?.seasonNumber == 1)
        #expect(request.nextEpisode?.episodeNumber == 3)
        #expect(request.nextEpisode?.title.contains("S1E3") == true)
    }

    @Test @MainActor
    func makePlayerSessionRequestUsesCrossSeasonNextEpisodeWhenAtSeasonEnd() {
        let appState = AppState(testHooks: .init())
        let viewModel = DetailViewModel(appState: appState)

        viewModel.mediaItem = MediaItem(id: "tt-series", type: .series, title: "Show", tmdbId: 101)
        let s1e10 = Episode(id: "s1e10", mediaId: "tt-series", seasonNumber: 1, episodeNumber: 10, title: "Finale")
        let s2e1 = Episode(id: "s2e1", mediaId: "tt-series", seasonNumber: 2, episodeNumber: 1, title: "Premiere")
        viewModel.episodes = [s2e1, s1e10]
        viewModel.selectedEpisode = s1e10

        let request = viewModel.makePlayerSessionRequest(
            stream: Fixtures.stream(),
            preview: MediaPreview(id: "tt-series", type: .series, title: "Show", tmdbId: 101)
        )

        #expect(request.nextEpisode?.episodeId == "s2e1")
        #expect(request.nextEpisode?.seasonNumber == 2)
        #expect(request.nextEpisode?.episodeNumber == 1)
    }

    @Test @MainActor
    func makePlayerSessionRequestDoesNotAttachNextEpisodeForMovies() {
        let appState = AppState(testHooks: .init())
        let viewModel = DetailViewModel(appState: appState)

        viewModel.mediaItem = MediaItem(id: "tt-movie", type: .movie, title: "Movie", tmdbId: 202)
        viewModel.selectedEpisode = Episode(
            id: "should-not-apply",
            mediaId: "tt-movie",
            seasonNumber: 1,
            episodeNumber: 1,
            title: "Ignored",
            overview: nil,
            airDate: nil,
            stillPath: nil,
            runtime: nil
        )

        let request = viewModel.makePlayerSessionRequest(
            stream: Fixtures.stream(),
            preview: MediaPreview(id: "tt-movie", type: .movie, title: "Movie", tmdbId: 202)
        )

        #expect(request.episodeId == nil)
        #expect(request.nextEpisode == nil)
    }

    @Test
    func playbackCopyPolicyDifferentiatesNormalDetailErrorsByAction() {
        #expect(DetailPlaybackCopyPolicy.missingEpisodeMessage == "Pick an episode to continue watching.")
        #expect(DetailPlaybackCopyPolicy.noStreamsMessage(for: .cast) == "No streams available to cast right now.")
        #expect(DetailPlaybackCopyPolicy.noStreamsMessage(for: .playTorrent) == "Could not open stream. Please try another result.")
        #expect(DetailPlaybackCopyPolicy.noStreamsMessage(for: .resumePlayback) == "No streams are available to resume right now.")
        #expect(DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .cast) == "Could not open stream for casting.")
        #expect(DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .playTorrent) == "Could not open stream. Please try another result.")
        #expect(DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .resumePlayback) == "Could not resume playback right now.")
    }

    @Test
    func qaLibraryMutationsStayStableForNoOpAndConflictingInputs() {
        #expect(
            DetailQAActionsPolicy.libraryMutations(
                autoAddWatchlist: false,
                autoAddFavorites: false,
                autoRemoveWatchlist: false,
                autoRemoveFavorites: false,
                isInWatchlist: false,
                isInFavorites: false
            ).isEmpty
        )

        #expect(
            DetailQAActionsPolicy.libraryMutations(
                autoAddWatchlist: true,
                autoAddFavorites: false,
                autoRemoveWatchlist: true,
                autoRemoveFavorites: false,
                isInWatchlist: false,
                isInFavorites: false
            ) == [.addWatchlist]
        )

        #expect(
            DetailQAActionsPolicy.libraryMutations(
                autoAddWatchlist: true,
                autoAddFavorites: false,
                autoRemoveWatchlist: true,
                autoRemoveFavorites: false,
                isInWatchlist: true,
                isInFavorites: false
            ) == [.removeWatchlist]
        )
    }

    @Test
    func qaSamplePolicySeparatesSeriesEpisodeMetadataFromMovies() {
        let seriesEpisode = Episode(
            id: "ep-2",
            mediaId: "series-1",
            seasonNumber: 2,
            episodeNumber: 4,
            title: "Episode Four"
        )

        #expect(
            DetailQASamplePolicy.sampleFileName(
                mediaTitle: "Show Name",
                previewType: .series,
                selectedEpisode: seriesEpisode
            ) == "Show Name-S02E04.mp4"
        )
        #expect(
            DetailQASamplePolicy.sampleFileName(
                mediaTitle: "Movie Name",
                previewType: .movie,
                selectedEpisode: seriesEpisode
            ) == "Movie Name.mp4"
        )

        let media = MediaItem(id: "series-1", type: .series, title: "Show Name", posterPath: "/poster.png")
        let seriesArguments = DetailQASamplePolicy.downloadArguments(
            mediaItem: media,
            previewType: .series,
            selectedEpisode: seriesEpisode
        )
        #expect(
            seriesArguments == DetailQASamplePolicy.DownloadArguments(
                mediaId: "series-1",
                episodeId: "ep-2",
                mediaTitle: "Show Name",
                mediaType: "series",
                posterPath: "/poster.png",
                seasonNumber: 2,
                episodeNumber: 4,
                episodeTitle: "Episode Four"
            )
        )

        let movieArguments = DetailQASamplePolicy.downloadArguments(
            mediaItem: MediaItem(id: "movie-1", type: .movie, title: "Movie Name", posterPath: "/movie.png"),
            previewType: .movie,
            selectedEpisode: seriesEpisode
        )
        #expect(
            movieArguments == DetailQASamplePolicy.DownloadArguments(
                mediaId: "movie-1",
                episodeId: nil,
                mediaTitle: "Movie Name",
                mediaType: "movie",
                posterPath: "/movie.png",
                seasonNumber: nil,
                episodeNumber: nil,
                episodeTitle: nil
            )
        )
    }
}

private extension DetailViewNormalUseContractTests {
    func requiredRange(of token: String, in source: String) throws -> Range<String.Index> {
        try requiredRange(of: token, in: source, after: source.startIndex)
    }

    func requiredRange(
        of token: String,
        in source: String,
        after startIndex: String.Index
    ) throws -> Range<String.Index> {
        guard let range = source.range(of: token, range: startIndex..<source.endIndex) else {
            throw NSError(
                domain: "DetailViewNormalUseContractTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing token: \(token)"]
            )
        }
        return range
    }

    func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
    }

    func occurrenceCount(of token: String, in source: String) -> Int {
        source.components(separatedBy: token).count - 1
    }

    func repoRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }
}

#if os(visionOS)
@MainActor
private func hostInVisibleVisionWindow<Content: View>(
    _ rootView: Content
) throws -> (host: UIHostingController<AnyView>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )

    let host = UIHostingController(rootView: AnyView(rootView))
    host.view.backgroundColor = .clear
    let window = UIWindow(windowScene: scene)
    window.rootViewController = host
    window.frame = CGRect(x: 0, y: 0, width: 980, height: 820)
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return (host, window)
}

@MainActor
private func tearDownVisionWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
    window.isHidden = true
    window.rootViewController = nil
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
}
#endif
