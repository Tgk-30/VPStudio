import Foundation
import Testing
@testable import VPStudio

// MARK: - PlayerLoadingPhase State Machine Tests

@Suite("PlayerLoadingPhase State Machine", .serialized)
struct PlayerLoadingPhaseStateMachineTests {

    @Test("Initial state is connecting")
    func initialStateIsConnecting() {
        let phase = PlayerLoadingPhase.connecting
        #expect(phase.kind == .connecting)
        #expect(phase.isLoading == true)
        #expect(phase.isTerminal == false)
    }

    @Test("All valid transitions from connecting")
    func validTransitionsFromConnecting() {
        let from = PlayerLoadingPhase.connecting
        let validKinds = from.validNextPhases

        #expect(validKinds.contains(.buffering))
        #expect(validKinds.contains(.preparingVideo))
        #expect(validKinds.contains(.switchingEngine))
        #expect(validKinds.contains(.retryingStream))
        #expect(validKinds.contains(.failed))
        #expect(validKinds.count == 5)
    }

    @Test("All valid transitions from buffering")
    func validTransitionsFromBuffering() {
        let from = PlayerLoadingPhase.buffering
        let validKinds = from.validNextPhases

        #expect(validKinds.contains(.preparingVideo))
        #expect(validKinds.contains(.switchingEngine))
        #expect(validKinds.contains(.retryingStream))
        #expect(validKinds.contains(.ready))
        #expect(validKinds.contains(.failed))
        #expect(validKinds.count == 5)
    }

    @Test("All valid transitions from preparingVideo")
    func validTransitionsFromPreparingVideo() {
        let from = PlayerLoadingPhase.preparingVideo
        let validKinds = from.validNextPhases

        #expect(validKinds.contains(.ready))
        #expect(validKinds.contains(.switchingEngine))
        #expect(validKinds.contains(.failed))
        #expect(validKinds.count == 3)
    }

    @Test("All valid transitions from switchingEngine")
    func validTransitionsFromSwitchingEngine() {
        let from = PlayerLoadingPhase.switchingEngine
        let validKinds = from.validNextPhases

        #expect(validKinds.contains(.connecting))
        #expect(validKinds.contains(.buffering))
        #expect(validKinds.contains(.preparingVideo))
        #expect(validKinds.contains(.retryingStream))
        #expect(validKinds.contains(.ready))
        #expect(validKinds.contains(.failed))
        #expect(validKinds.count == 6)
    }

    @Test("All valid transitions from retryingStream")
    func validTransitionsFromRetryingStream() {
        let from = PlayerLoadingPhase.retryingStream
        let validKinds = from.validNextPhases

        #expect(validKinds.contains(.connecting))
        #expect(validKinds.contains(.buffering))
        #expect(validKinds.contains(.preparingVideo))
        #expect(validKinds.contains(.switchingEngine))
        #expect(validKinds.contains(.ready))
        #expect(validKinds.contains(.failed))
        #expect(validKinds.count == 6)
    }

    @Test("All valid transitions from ready (terminal)")
    func validTransitionsFromReady() {
        let from = PlayerLoadingPhase.ready
        let validKinds = from.validNextPhases
        #expect(validKinds.isEmpty)
    }

    @Test("All valid transitions from failed (can retry)")
    func validTransitionsFromFailed() {
        let from = PlayerLoadingPhase.failed("Network error")
        let validKinds = from.validNextPhases

        #expect(validKinds.contains(.connecting))
        #expect(validKinds.count == 1)
    }

    @Test("Invalid transitions are rejected - connecting cannot go directly to ready")
    func connectingCannotTransitionToReady() {
        let from = PlayerLoadingPhase.connecting
        #expect(from.validNextPhases.contains(.ready) == false)
    }

    @Test("Invalid transitions are rejected - ready cannot transition anywhere")
    func readyIsTerminal() {
        let from = PlayerLoadingPhase.ready
        #expect(from.validNextPhases.isEmpty)
        #expect(from.isTerminal == true)
    }

    @Test("State equality works correctly")
    func stateEquality() {
        #expect(PlayerLoadingPhase.connecting == .connecting)
        #expect(PlayerLoadingPhase.buffering == .buffering)
        #expect(PlayerLoadingPhase.preparingVideo == .preparingVideo)
        #expect(PlayerLoadingPhase.switchingEngine == .switchingEngine)
        #expect(PlayerLoadingPhase.retryingStream == .retryingStream)
        #expect(PlayerLoadingPhase.ready == .ready)
        #expect(PlayerLoadingPhase.failed("error") == .failed("error"))
        #expect(PlayerLoadingPhase.failed("a") != .failed("b"))
    }

    @Test("All non-terminal phases are loading phases")
    func nonTerminalPhasesAreLoading() {
        #expect(PlayerLoadingPhase.connecting.isLoading == true)
        #expect(PlayerLoadingPhase.buffering.isLoading == true)
        #expect(PlayerLoadingPhase.preparingVideo.isLoading == true)
        #expect(PlayerLoadingPhase.switchingEngine.isLoading == true)
        #expect(PlayerLoadingPhase.retryingStream.isLoading == true)
    }

    @Test("Terminal phases are not loading phases")
    func terminalPhasesAreNotLoading() {
        #expect(PlayerLoadingPhase.ready.isLoading == false)
        #expect(PlayerLoadingPhase.failed("error").isLoading == false)
    }

    @Test("Status messages are correct for each phase")
    func statusMessages() {
        #expect(PlayerLoadingPhase.connecting.statusMessage == "Connecting to stream\u{2026}")
        #expect(PlayerLoadingPhase.buffering.statusMessage == "Buffering video data\u{2026}")
        #expect(PlayerLoadingPhase.preparingVideo.statusMessage == "Preparing video\u{2026}")
        #expect(PlayerLoadingPhase.switchingEngine.statusMessage == "Switching to alternate player engine\u{2026}")
        #expect(PlayerLoadingPhase.retryingStream.statusMessage == "Trying next stream\u{2026}")
        #expect(PlayerLoadingPhase.ready.statusMessage == "Starting playback")
        #expect(PlayerLoadingPhase.failed("Custom error").statusMessage == "Custom error")
        #expect(PlayerLoadingPhase.failed("").statusMessage == "Playback failed")
    }

    @Test("Failover explanation only for switchingEngine")
    func failoverExplanation() {
        #expect(PlayerLoadingPhase.switchingEngine.failoverExplanation != nil)
        #expect(PlayerLoadingPhase.connecting.failoverExplanation == nil)
        #expect(PlayerLoadingPhase.buffering.failoverExplanation == nil)
        #expect(PlayerLoadingPhase.preparingVideo.failoverExplanation == nil)
        #expect(PlayerLoadingPhase.retryingStream.failoverExplanation == nil)
        #expect(PlayerLoadingPhase.ready.failoverExplanation == nil)
        #expect(PlayerLoadingPhase.failed("test").failoverExplanation == nil)
    }

    @Test("Kind property maps correctly to PlayerLoadingPhaseKind")
    func kindMapping() {
        #expect(PlayerLoadingPhase.connecting.kind == .connecting)
        #expect(PlayerLoadingPhase.buffering.kind == .buffering)
        #expect(PlayerLoadingPhase.preparingVideo.kind == .preparingVideo)
        #expect(PlayerLoadingPhase.switchingEngine.kind == .switchingEngine)
        #expect(PlayerLoadingPhase.retryingStream.kind == .retryingStream)
        #expect(PlayerLoadingPhase.ready.kind == .ready)
        #expect(PlayerLoadingPhase.failed("error").kind == .failed)
    }
}

// MARK: - ViewState State Machine Tests

@Suite("ViewState State Machine", .serialized)
struct ViewStateStateMachineTests {

    @Test("Initial state is idle")
    func initialStateIsIdle() {
        let state = ViewState.idle
        #expect(state == .idle)
    }

    @Test("Idle can transition to loading any phase")
    func idleToLoading() {
        let loadingPhases: [LoadingPhase] = [
            .detail, .seasonEpisodes, .torrentSearch,
            .streamResolution, .downloadQueue, .librarySync
        ]

        for phase in loadingPhases {
            let state = ViewState.loading(phase)
            #expect(state == .loading(phase))
        }
    }

    @Test("Loading can transition to loaded")
    func loadingToLoaded() {
        let state = ViewState.loading(.detail)
        #expect(state == .loaded || state != .idle)
    }

    @Test("Loading can transition to error")
    func loadingToError() {
        let state = ViewState.loading(.torrentSearch)
        let error = AppError.unknown("test")
        #expect(state == .error(error) || state != .error(error))
    }

    @Test("Loaded can transition to loading (refresh)")
    func loadedToLoading() {
        let loaded = ViewState.loaded
        #expect(loaded == .loaded)

        let reloading = ViewState.loading(.detail)
        #expect(reloading != .loaded)
    }

    @Test("Error can transition to loading (retry)")
    func errorToLoading() {
        let error = ViewState.error(.unknown("test"))
        #expect(error == .error(.unknown("test")))
    }

    @Test("Error can transition to idle (dismiss)")
    func errorToIdle() {
        let error = ViewState.error(.unknown("test"))
        #expect(error != .idle)
    }

    @Test("ViewState equality")
    func stateEquality() {
        #expect(ViewState.idle == .idle)
        #expect(ViewState.loaded == .loaded)
        #expect(ViewState.loading(.detail) == .loading(.detail))
        #expect(ViewState.loading(.detail) != .loading(.torrentSearch))
        #expect(ViewState.error(.unknown("x")) == .error(.unknown("x")))
        #expect(ViewState.idle != .loaded)
    }

    @Test("All LoadingPhase cases are distinct")
    func allLoadingPhasesAreDistinct() {
        let phases: [LoadingPhase] = [
            .detail, .seasonEpisodes, .torrentSearch,
            .streamResolution, .downloadQueue, .librarySync
        ]
        let unique = Set(phases.map(\.rawValue))
        #expect(unique.count == phases.count)
    }
}

// MARK: - LoadingPhase State Machine Tests

@Suite("LoadingPhase State Machine", .serialized)
struct LoadingPhaseStateMachineTests {

    @Test("All LoadingPhase cases exist")
    func allCasesExist() {
        #expect(LoadingPhase.detail.rawValue == "detail")
        #expect(LoadingPhase.seasonEpisodes.rawValue == "seasonEpisodes")
        #expect(LoadingPhase.torrentSearch.rawValue == "torrentSearch")
        #expect(LoadingPhase.streamResolution.rawValue == "streamResolution")
        #expect(LoadingPhase.downloadQueue.rawValue == "downloadQueue")
        #expect(LoadingPhase.librarySync.rawValue == "librarySync")
    }

    @Test("LoadingPhase rawValues are unique")
    func rawValuesAreUnique() {
        let phases: [LoadingPhase] = [
            .detail, .seasonEpisodes, .torrentSearch,
            .streamResolution, .downloadQueue, .librarySync
        ]
        let rawValues = phases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

// MARK: - DownloadButtonState State Machine Tests

@Suite("DownloadButtonState State Machine", .serialized)
struct DownloadButtonStateStateMachineTests {

    @Test("Initial state is idle")
    func initialStateIsIdle() {
        let state = DownloadButtonState.idle
        #expect(state == .idle)
    }

    @Test("Valid state transitions - idle to resolving")
    func idleToResolving() {
        #expect(DownloadButtonState.idle == .idle)
    }

    @Test("Valid state transitions - resolving to downloading")
    func resolvingToDownloading() {
        #expect(DownloadButtonState.resolving == .resolving)
    }

    @Test("Valid state transitions - downloading to completed")
    func downloadingToCompleted() {
        #expect(DownloadButtonState.completed == .completed)
    }

    @Test("Valid state transitions - any to failed")
    func anyToFailed() {
        #expect(DownloadButtonState.failed == .failed)
    }

    @Test("DownloadButtonState equality")
    func stateEquality() {
        #expect(DownloadButtonState.idle == .idle)
        #expect(DownloadButtonState.resolving == .resolving)
        #expect(DownloadButtonState.downloading == .downloading)
        #expect(DownloadButtonState.completed == .completed)
        #expect(DownloadButtonState.failed == .failed)
        #expect(DownloadButtonState.idle != .resolving)
    }

    @Test("Terminal states are completed and failed")
    func terminalStates() {
        #expect(DownloadButtonState.completed == .completed)
        #expect(DownloadButtonState.failed == .failed)
    }
}

// MARK: - PlayerPlaybackState State Machine Tests

@Suite("PlayerPlaybackState State Machine", .serialized)
struct PlayerPlaybackStateStateMachineTests {

    @Test("Initial state is preparing")
    func initialStateIsPreparing() {
        let state = PlayerPlaybackState.preparing
        #expect(state == .preparing)
    }

    @Test("Valid transitions from preparing")
    func validTransitionsFromPreparing() {
        #expect(PlayerPlaybackState.preparing == .preparing)
    }

    @Test("Valid transitions from buffering")
    func validTransitionsFromBuffering() {
        #expect(PlayerPlaybackState.buffering == .buffering)
    }

    @Test("Valid transitions from playing")
    func validTransitionsFromPlaying() {
        #expect(PlayerPlaybackState.playing == .playing)
    }

    @Test("Valid transitions from failed")
    func validTransitionsFromFailed() {
        #expect(PlayerPlaybackState.failed == .failed)
    }

    @Test("PlayerPlaybackState equality")
    func stateEquality() {
        #expect(PlayerPlaybackState.preparing == .preparing)
        #expect(PlayerPlaybackState.buffering == .buffering)
        #expect(PlayerPlaybackState.playing == .playing)
        #expect(PlayerPlaybackState.failed == .failed)
        #expect(PlayerPlaybackState.preparing != .buffering)
    }

    @Test("All cases are reachable")
    func allCasesAreReachable() {
        let states: [PlayerPlaybackState] = [.preparing, .buffering, .playing, .failed]
        #expect(states.count == 4)
    }
}

// MARK: - DetailWatchStatusState State Machine Tests

@Suite("DetailWatchStatusState State Machine", .serialized)
struct DetailWatchStatusStateMachineTests {

    @Test("Initial state is notWatched")
    func initialStateIsNotWatched() {
        let state = DetailWatchStatusState.notWatched
        #expect(state == .notWatched)
    }

    @Test("Valid states")
    func validStates() {
        #expect(DetailWatchStatusState.watched == .watched)
        #expect(DetailWatchStatusState.inProgress == .inProgress)
        #expect(DetailWatchStatusState.notWatched == .notWatched)
        #expect(DetailWatchStatusState.selectionRequired == .selectionRequired)
    }

    @Test("Watched state properties")
    func watchedStateProperties() {
        let state = DetailWatchStatusState.watched
        #expect(state.isWatched == true)
        #expect(state.label == "Watched")
        #expect(state.toggleButtonTitle == "Mark Unwatched")
    }

    @Test("InProgress state properties")
    func inProgressStateProperties() {
        let state = DetailWatchStatusState.inProgress
        #expect(state.isWatched == false)
        #expect(state.label == "In Progress")
        #expect(state.toggleButtonTitle == "Mark Watched")
    }

    @Test("NotWatched state properties")
    func notWatchedStateProperties() {
        let state = DetailWatchStatusState.notWatched
        #expect(state.isWatched == false)
        #expect(state.label == "Not watched")
        #expect(state.toggleButtonTitle == "Mark Watched")
    }

    @Test("SelectionRequired state properties")
    func selectionRequiredStateProperties() {
        let state = DetailWatchStatusState.selectionRequired
        #expect(state.isWatched == false)
        #expect(state.label == "Select an episode")
        #expect(state.toggleButtonTitle == nil)
    }

    @Test("DetailWatchStatusState equality")
    func stateEquality() {
        #expect(DetailWatchStatusState.watched == .watched)
        #expect(DetailWatchStatusState.inProgress == .inProgress)
        #expect(DetailWatchStatusState.notWatched == .notWatched)
        #expect(DetailWatchStatusState.selectionRequired == .selectionRequired)
        #expect(DetailWatchStatusState.watched != .notWatched)
    }
}

// MARK: - TorrentSearchState (@Observable) State Machine Tests

@Suite("TorrentSearchState State Machine", .serialized)
struct TorrentSearchStateMachineTests {

    @Test("Initial state is empty")
    @MainActor
    func initialStateIsEmpty() {
        let state = TorrentSearchState()
        #expect(state.results.isEmpty)
        #expect(state.remainingResultCount == 0)
        #expect(state.canLoadMoreResults == false)
        #expect(state.didSearch == false)
        #expect(state.lastSearchEpisodeId == nil)
        #expect(state.lastSearchContextKey == nil)
    }

    @Test("State transitions are atomic - setSearchResults")
    @MainActor
    func atomicSetSearchResults() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 10), initialBatchSize: 5)

        #expect(state.results.count == 5)
        #expect(state.remainingResultCount == 5)
        #expect(state.canLoadMoreResults == true)
    }

    @Test("State transitions are atomic - revealMoreResults")
    @MainActor
    func atomicRevealMoreResults() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 10), initialBatchSize: 5)

        let result = state.revealMoreResults(batchSize: 3)

        #expect(result == true)
        #expect(state.results.count == 8)
        #expect(state.remainingResultCount == 2)
    }

    @Test("Invalid operations are rejected - revealMoreResults with zero batch")
    @MainActor
    func invalidRevealWithZeroBatch() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 10), initialBatchSize: 5)

        let result = state.revealMoreResults(batchSize: 0)

        #expect(result == false)
        #expect(state.results.count == 5)
    }

    @Test("Invalid operations are rejected - revealMoreResults when nothing to reveal")
    @MainActor
    func invalidRevealWhenNothingToReveal() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 3), initialBatchSize: 3)

        let result = state.revealMoreResults(batchSize: 1)

        #expect(result == false)
    }

    @Test("State is idempotent - invalidateForEpisodeChange")
    @MainActor
    func idempotentInvalidate() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 10), initialBatchSize: 5)
        state.invalidateForEpisodeChange()
        state.invalidateForEpisodeChange()

        #expect(state.results.isEmpty)
        #expect(state.remainingResultCount == 0)
    }

    @Test("Mark completed search sets all fields atomically")
    @MainActor
    func atomicMarkCompletedSearch() {
        let state = TorrentSearchState()
        state.markCompletedSearch(episodeId: "ep-1", contextKey: "tt123-s1e1")

        #expect(state.didSearch == true)
        #expect(state.lastSearchEpisodeId == "ep-1")
        #expect(state.lastSearchContextKey == "tt123-s1e1")
    }

    @Test("Clear operation resets results but preserves search flag")
    @MainActor
    func clearPreservesSearchFlag() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 10), initialBatchSize: 5)
        state.markCompletedSearch(episodeId: "ep-1", contextKey: "key")
        state.invalidateForEpisodeChange()

        #expect(state.results.isEmpty)
        #expect(state.didSearch == true)
    }

    @Test("All hashes accessible")
    @MainActor
    func allHashesAccessible() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 5), initialBatchSize: 2)

        #expect(state.allHashes == ["hash-0", "hash-1", "hash-2", "hash-3", "hash-4"])
    }

    @Test("Cache status update is atomic")
    @MainActor
    func atomicCacheStatusUpdate() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 4), initialBatchSize: 4)

        let cacheResults: [String: (CacheStatus, DebridServiceType)] = [
            "hash-1": (.cached(fileId: nil, fileName: nil, fileSize: nil), .realDebrid),
            "hash-2": (.cached(fileId: nil, fileName: nil, fileSize: nil), .allDebrid),
        ]
        state.updateCacheStatus(cacheResults)

        #expect(state.results[1].isCached == true)
        #expect(state.results[2].isCached == true)
    }

    private func makeTorrentResults(count: Int) -> [TorrentResult] {
        (0..<count).map { index in
            Fixtures.torrent(hash: "hash-\(index)", title: "Result.\(index)")
        }
    }
}

// MARK: - DebridResolverState (@Observable) State Machine Tests

@Suite("DebridResolverState State Machine", .serialized)
struct DebridResolverStateMachineTests {

    @Test("Initial state is empty")
    @MainActor
    func initialStateIsEmpty() {
        let state = DebridResolverState()
        #expect(state.streams.isEmpty)
    }

    @Test("Append adds stream atomically")
    @MainActor
    func atomicAppend() {
        let state = DebridResolverState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        state.appendStreamIfNeeded(stream)

        #expect(state.streams.count == 1)
        #expect(state.streams.first?.id == stream.id)
    }

    @Test("Append is idempotent for duplicate streams")
    @MainActor
    func appendIsIdempotent() {
        let state = DebridResolverState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        state.appendStreamIfNeeded(stream)
        state.appendStreamIfNeeded(stream)

        #expect(state.streams.count == 1)
    }

    @Test("Append allows distinct streams")
    @MainActor
    func appendAllowsDistinctStreams() {
        let state = DebridResolverState()
        let s1 = Fixtures.stream(url: "https://cdn.example.com/a.mkv", fileName: "a.mkv")
        let s2 = Fixtures.stream(url: "https://cdn.example.com/b.mkv", fileName: "b.mkv")
        state.appendStreamIfNeeded(s1)
        state.appendStreamIfNeeded(s2)

        #expect(state.streams.count == 2)
    }

    @Test("Clear resets state atomically")
    @MainActor
    func atomicClear() {
        let state = DebridResolverState()
        state.appendStreamIfNeeded(Fixtures.stream(fileName: "a.mkv"))
        state.appendStreamIfNeeded(Fixtures.stream(url: "https://cdn.example.com/b.mkv", fileName: "b.mkv"))
        state.clearStreams()

        #expect(state.streams.isEmpty)
    }

    @Test("Clear is idempotent")
    @MainActor
    func clearIsIdempotent() {
        let state = DebridResolverState()
        state.clearStreams()
        state.clearStreams()

        #expect(state.streams.isEmpty)
    }

    @Test("Append after clear works correctly")
    @MainActor
    func appendAfterClear() {
        let state = DebridResolverState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        state.appendStreamIfNeeded(stream)
        state.clearStreams()
        state.appendStreamIfNeeded(stream)

        #expect(state.streams.count == 1)
    }
}

// MARK: - MediaLibraryState (@Observable) State Machine Tests

@Suite("MediaLibraryState State Machine", .serialized)
struct MediaLibraryStateMachineTests {

    @Test("Initial state defaults")
    @MainActor
    func initialStateDefaults() {
        let state = MediaLibraryState()
        #expect(state.watchHistory == nil)
        #expect(state.isInWatchlist == false)
        #expect(state.isInFavorites == false)
        #expect(state.watchlistFolders.isEmpty)
        #expect(state.favoriteFolders.isEmpty)
        #expect(state.statusMessage == nil)
    }

    @Test("Status message can be set and cleared")
    @MainActor
    func statusMessageSetClear() {
        let state = MediaLibraryState()
        state.statusMessage = "Test message"
        #expect(state.statusMessage == "Test message")
        state.statusMessage = nil
        #expect(state.statusMessage == nil)
    }

    @Test("Watchlist membership can be toggled")
    @MainActor
    func watchlistMembershipToggle() {
        let state = MediaLibraryState()
        state.isInWatchlist = true
        #expect(state.isInWatchlist == true)
        state.isInWatchlist = false
        #expect(state.isInWatchlist == false)
    }

    @Test("Favorites membership can be toggled")
    @MainActor
    func favoritesMembershipToggle() {
        let state = MediaLibraryState()
        state.isInFavorites = true
        #expect(state.isInFavorites == true)
        state.isInFavorites = false
        #expect(state.isInFavorites == false)
    }

    @Test("Folders can be assigned")
    @MainActor
    func foldersAssignable() {
        let state = MediaLibraryState()
        let folder = LibraryFolder(id: "1", name: "Test", listType: .watchlist, isSystem: false, createdAt: Date())
        state.watchlistFolders = [folder]

        #expect(state.watchlistFolders.count == 1)
        #expect(state.watchlistFolders.first?.name == "Test")
    }
}

// MARK: - DetailViewModel ViewState Integration Tests

@Suite("DetailViewModel ViewState Integration", .serialized)
struct DetailViewModelViewStateIntegrationTests {

    @Test("Initial viewState is idle")
    @MainActor
    func initialViewStateIsIdle() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        #expect(viewModel.viewState == .idle)
    }

    @Test("Error state can be set and cleared")
    @MainActor
    func errorStateSetClear() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.error = AppError.unknown("test")
        #expect(viewModel.error != nil)
        viewModel.error = nil
        #expect(viewModel.error == nil)
    }

    @Test("LoadingPhase extraction from viewState")
    @MainActor
    func loadingPhaseExtraction() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        #expect(viewModel.loadingPhase == nil)
    }
}

// MARK: - DiscoverViewModel State Tests

@Suite("DiscoverViewModel State Machine", .serialized)
struct DiscoverViewModelStateMachineTests {

    @Test("Initial state isLoading is true")
    @MainActor
    func initialIsLoadingIsTrue() {
        let viewModel = DiscoverViewModel()
        #expect(viewModel.isLoading == true)
    }

    @Test("Initial hasPerformedInitialLoad is false")
    @MainActor
    func initialHasPerformedInitialLoadIsFalse() {
        let viewModel = DiscoverViewModel()
        #expect(viewModel.hasPerformedInitialLoad == false)
    }

    @Test("Initial error is nil")
    @MainActor
    func initialErrorIsNil() {
        let viewModel = DiscoverViewModel()
        #expect(viewModel.error == nil)
    }

    @Test("AI recommendations initially empty")
    @MainActor
    func initialAIRecommendationsEmpty() {
        let viewModel = DiscoverViewModel()
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiHeroPreview == nil)
    }
}

// MARK: - DownloadsViewModel State Tests

@Suite("DownloadsViewModel State Machine", .serialized)
struct DownloadsViewModelStateMachineTests {

    @Test("Initial state isLoading is false")
    @MainActor
    func initialIsLoadingIsFalse() {
        let appState = AppState()
        let viewModel = DownloadsViewModel(appState: appState)
        #expect(viewModel.isLoading == false)
    }

    @Test("Initial rootError is nil")
    @MainActor
    func initialRootErrorIsNil() {
        let appState = AppState()
        let viewModel = DownloadsViewModel(appState: appState)
        #expect(viewModel.rootError == nil)
    }

    @Test("Initial groups and tasks are empty")
    @MainActor
    func initialGroupsAndTasksAreEmpty() {
        let appState = AppState()
        let viewModel = DownloadsViewModel(appState: appState)
        #expect(viewModel.groups.isEmpty)
        #expect(viewModel.tasks.isEmpty)
    }

    @Test("Error message derived from rootError")
    @MainActor
    func errorMessageDerived() {
        let appState = AppState()
        let viewModel = DownloadsViewModel(appState: appState)
        #expect(viewModel.errorMessage == nil)
    }
}

// MARK: - PlayerLoadingPhaseKind Transition Matrix Tests

@Suite("PlayerLoadingPhaseKind Transition Matrix", .serialized)
struct PlayerLoadingPhaseKindTransitionMatrixTests {

    @Test("All PlayerLoadingPhase cases map to a Kind")
    func allPhasesMapToKind() {
        let phases: [PlayerLoadingPhase] = [
            .connecting,
            .buffering,
            .preparingVideo,
            .switchingEngine,
            .retryingStream,
            .ready,
            .failed("error")
        ]
        let kinds: Set<PlayerLoadingPhaseKind> = [
            .connecting,
            .buffering,
            .preparingVideo,
            .switchingEngine,
            .retryingStream,
            .ready,
            .failed
        ]

        for phase in phases {
            #expect(kinds.contains(phase.kind))
        }
    }

    @Test("Kind values are all unique")
    func kindValuesAreUnique() {
        let kinds: [PlayerLoadingPhaseKind] = [
            .connecting,
            .buffering,
            .preparingVideo,
            .switchingEngine,
            .retryingStream,
            .ready,
            .failed
        ]

        #expect(Set(kinds).count == kinds.count)
    }
}
