import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct DetailViewModelWatchStateTests {
    struct StateExpectation: Sendable {
        let state: DetailWatchStatusState
        let label: String
        let toggleButtonTitle: String?
        let isWatched: Bool
    }

    @Test(arguments: [
        StateExpectation(state: .watched, label: "Watched", toggleButtonTitle: "Mark Unwatched", isWatched: true),
        StateExpectation(state: .inProgress, label: "In Progress", toggleButtonTitle: "Mark Watched", isWatched: false),
        StateExpectation(state: .notWatched, label: "Not watched", toggleButtonTitle: "Mark Watched", isWatched: false),
        StateExpectation(state: .selectionRequired, label: "Select an episode", toggleButtonTitle: nil, isWatched: false),
    ])
    func watchStatusStateExposesExpectedPresentation(data: StateExpectation) {
        #expect(data.state.label == data.label)
        #expect(data.state.toggleButtonTitle == data.toggleButtonTitle)
        #expect(data.state.isWatched == data.isWatched)
    }

    @Test
    @MainActor
    func currentWatchStatusStateFallsBackToPreviewContextWhenDetailNotLoaded() throws {
        let viewModel = try makeViewModel()
        viewModel.setPreviewContext(MediaPreview(id: "series-preview", type: .series, title: "Preview"))

        #expect(viewModel.currentWatchStatusState == .selectionRequired)
    }

    @Test
    @MainActor
    func currentWatchStatusStateForSeriesReflectsEpisodeCompletion() throws {
        let viewModel = try makeViewModel()
        let episode = Episode(
            id: "ep-1-2",
            mediaId: "series-1",
            seasonNumber: 1,
            episodeNumber: 2,
            title: "Episode 2",
            overview: nil,
            airDate: nil,
            stillPath: nil,
            runtime: nil
        )

        viewModel.mediaItem = MediaItem(id: "series-1", type: .series, title: "Series")
        viewModel.selectedEpisode = episode
        viewModel.episodeWatchStates[episode.id] = WatchHistory(
            id: "history-1",
            mediaId: "series-1",
            episodeId: episode.id,
            title: episode.title ?? "Episode 2",
            progress: 2400,
            duration: 2400,
            watchedAt: Date(),
            isCompleted: true
        )

        #expect(viewModel.currentWatchStatusState == .watched)

        viewModel.episodeWatchStates[episode.id]?.isCompleted = false
        #expect(viewModel.currentWatchStatusState == .notWatched)
    }

    @Test
    @MainActor
    func currentWatchStatusStateForMovieDistinguishesCompletedProgressAndThreshold() throws {
        let viewModel = try makeViewModel()
        viewModel.mediaItem = MediaItem(id: "movie-1", type: .movie, title: "Movie")

        #expect(viewModel.currentWatchStatusState == .notWatched)

        viewModel.watchHistory = WatchHistory(
            id: "history-2",
            mediaId: "movie-1",
            title: "Movie",
            progress: 3,
            duration: 100,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(viewModel.currentWatchStatusState == .inProgress)

        viewModel.watchHistory = WatchHistory(
            id: "history-3",
            mediaId: "movie-1",
            title: "Movie",
            progress: 2,
            duration: 100,
            watchedAt: Date(),
            isCompleted: false
        )
        #expect(viewModel.currentWatchStatusState == .notWatched)

        viewModel.watchHistory = WatchHistory(
            id: "history-4",
            mediaId: "movie-1",
            title: "Movie",
            progress: 100,
            duration: 100,
            watchedAt: Date(),
            isCompleted: true
        )
        #expect(viewModel.currentWatchStatusState == .watched)
    }

    @MainActor
    private func makeViewModel() throws -> DetailViewModel {
        let database = try DatabaseManager(inMemoryNamed: "detail-watch-state-\(UUID().uuidString)")
        let appState = AppState(database: database, secretStore: TestSecretStore())
        return DetailViewModel(
            appState: appState,
            metadataProviderFactory: { _ in StubMetadataProvider() },
            indexerManager: StubIndexerManager(),
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )
    }
}
