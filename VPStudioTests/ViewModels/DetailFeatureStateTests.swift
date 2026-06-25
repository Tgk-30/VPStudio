import Foundation
import Testing
@testable import VPStudio

// MARK: - ViewState & LoadingPhase

@Suite("ViewState and LoadingPhase")
struct ViewStateTests {

    @Test func idleEquality() {
        #expect(ViewState.idle == .idle)
    }

    @Test func loadedEquality() {
        #expect(ViewState.loaded == .loaded)
    }

    @Test func loadingEquality() {
        #expect(ViewState.loading(.detail) == .loading(.detail))
        #expect(ViewState.loading(.torrentSearch) == .loading(.torrentSearch))
    }

    @Test func loadingInequality() {
        #expect(ViewState.loading(.detail) != .loading(.torrentSearch))
    }

    @Test func errorEquality() {
        #expect(ViewState.error(.unknown("x")) == .error(.unknown("x")))
    }

    @Test func idleNotEqualLoaded() {
        #expect(ViewState.idle != .loaded)
    }

    @Test func allLoadingPhasesAreDistinct() {
        let phases: [LoadingPhase] = [
            .detail, .seasonEpisodes, .torrentSearch,
            .streamResolution, .downloadQueue, .librarySync
        ]
        let unique = Set(phases.map(\.rawValue))
        #expect(unique.count == phases.count)
    }

    @Test func loadingPhaseRawValuesRemainStable() {
        #expect(LoadingPhase.detail.rawValue == "detail")
        #expect(LoadingPhase.seasonEpisodes.rawValue == "seasonEpisodes")
        #expect(LoadingPhase.torrentSearch.rawValue == "torrentSearch")
        #expect(LoadingPhase.streamResolution.rawValue == "streamResolution")
        #expect(LoadingPhase.downloadQueue.rawValue == "downloadQueue")
        #expect(LoadingPhase.librarySync.rawValue == "librarySync")
    }

    @Test func errorStatesCompareAssociatedErrors() {
        #expect(ViewState.error(.unknown("same")) == .error(.unknown("same")))
        #expect(ViewState.error(.unknown("one")) != .error(.unknown("two")))
        #expect(ViewState.error(.unknown("x")) != .loading(.detail))
    }
}

// MARK: - DownloadButtonState

@Suite("DownloadButtonState")
struct DownloadButtonStateTests {
    @Test
    func buttonStatesCompareByCase() {
        #expect(DownloadButtonState.idle == .idle)
        #expect(DownloadButtonState.resolving == .resolving)
        #expect(DownloadButtonState.downloading == .downloading)
        #expect(DownloadButtonState.completed == .completed)
        #expect(DownloadButtonState.failed == .failed)
        #expect(DownloadButtonState.idle != .resolving)
        #expect(DownloadButtonState.downloading != .completed)
    }

    @Test
    func allButtonStatesAreDistinct() {
        let states: [DownloadButtonState] = [
            .idle,
            .resolving,
            .downloading,
            .completed,
            .failed,
        ]

        for lhsIndex in states.indices {
            for rhsIndex in states.indices where lhsIndex != rhsIndex {
                #expect(states[lhsIndex] != states[rhsIndex])
            }
        }
    }
}

// MARK: - Detail protocol defaults

@Suite("Detail protocol defaults")
struct DetailProtocolDefaultTests {
    @Test
    func detailIndexerDefaultEnsureInitializedCallsInitialize() async throws {
        let indexer = DefaultEnsureInitializedIndexer()

        try await indexer.ensureInitialized()

        #expect(await indexer.initializeCallCount() == 1)
    }

    @Test
    func detailDebridDefaultUnrestrictReportsUnsupportedRefresh() async {
        let debrid = DefaultUnrestrictDebridManager()

        do {
            _ = try await debrid.unrestrict(link: "https://cdn.example.com/file.mkv", serviceType: .realDebrid)
            Issue.record("Expected default unrestrict to throw")
        } catch DebridError.networkError(let message) {
            #expect(message == "Direct debrid link refresh is not supported.")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private actor DefaultEnsureInitializedIndexer: DetailIndexerManaging {
        private var count = 0

        func initialize() async throws {
            count += 1
        }

        func initializeCallCount() -> Int {
            count
        }

        func search(
            imdbId: String,
            type: MediaType,
            season: Int?,
            episode: Int?
        ) async throws -> [TorrentResult] {
            []
        }

        func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
            []
        }
    }

    private actor DefaultUnrestrictDebridManager: DetailDebridManaging {
        func checkCacheAcrossServices(
            hashes: [String]
        ) async throws -> [String: (CacheStatus, DebridServiceType)] {
            [:]
        }

        func resolveStream(
            hash: String,
            preferredService: DebridServiceType?,
            magnetURI: String?,
            seasonNumber: Int?,
            episodeNumber: Int?
        ) async throws -> StreamInfo {
            Fixtures.stream(fileName: "\(hash).mkv")
        }
    }
}

// MARK: - TorrentSearchState

@Suite("TorrentSearchState", .serialized)
struct TorrentSearchStateTests {

    @Test @MainActor
    func initialStateIsEmpty() {
        let state = TorrentSearchState()
        #expect(state.results.isEmpty)
        #expect(state.remainingResultCount == 0)
        #expect(state.canLoadMoreResults == false)
        #expect(state.didSearch == false)
        #expect(state.lastSearchEpisodeId == nil)
        #expect(state.lastSearchContextKey == nil)
    }

    @Test @MainActor
    func setSearchResultsPublishesInitialBatchWindow() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 6), initialBatchSize: 2)

        #expect(state.results.map(\.infoHash) == ["hash-0", "hash-1"])
        #expect(state.remainingResultCount == 4)
        #expect(state.canLoadMoreResults)
    }

    @Test @MainActor
    func setSearchResultsClampsInitialBatchToAvailableResults() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 3), initialBatchSize: 10)

        #expect(state.results.count == 3)
        #expect(state.remainingResultCount == 0)
        #expect(state.canLoadMoreResults == false)
    }

    @Test @MainActor
    func setSearchResultsClampsNegativeInitialBatchToEmptyWindow() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 3), initialBatchSize: -4)

        #expect(state.results.isEmpty)
        #expect(state.remainingResultCount == 3)
        #expect(state.canLoadMoreResults)
    }

    @Test @MainActor
    func revealMoreResultsAppendsBatchAndUpdatesRemainingCount() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 8), initialBatchSize: 3)

        let didReveal = state.revealMoreResults(batchSize: 2)

        #expect(didReveal)
        #expect(state.results.map(\.infoHash) == ["hash-0", "hash-1", "hash-2", "hash-3", "hash-4"])
        #expect(state.remainingResultCount == 3)
        #expect(state.canLoadMoreResults)
    }

    @Test @MainActor
    func revealMoreResultsStopsAtEndAndReturnsFalseWhenFullyVisible() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 4), initialBatchSize: 3)

        let firstReveal = state.revealMoreResults(batchSize: 10)
        let secondReveal = state.revealMoreResults(batchSize: 1)

        #expect(firstReveal)
        #expect(secondReveal == false)
        #expect(state.results.count == 4)
        #expect(state.remainingResultCount == 0)
        #expect(state.canLoadMoreResults == false)
    }

    @Test @MainActor
    func revealMoreResultsWithNonPositiveBatchIsNoOp() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 5), initialBatchSize: 2)

        let zeroBatchReveal = state.revealMoreResults(batchSize: 0)
        let negativeBatchReveal = state.revealMoreResults(batchSize: -1)

        #expect(zeroBatchReveal == false)
        #expect(negativeBatchReveal == false)
        #expect(state.results.count == 2)
        #expect(state.remainingResultCount == 3)
    }

    @Test @MainActor
    func setSearchResultsResetsPreviouslyExpandedWindow() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 20), initialBatchSize: 5)
        _ = state.revealMoreResults(batchSize: 5)
        #expect(state.results.count == 10)

        state.setSearchResults(makeTorrentResults(count: 4), initialBatchSize: 2)

        #expect(state.results.map(\.infoHash) == ["hash-0", "hash-1"])
        #expect(state.remainingResultCount == 2)
        #expect(state.canLoadMoreResults)
    }

    @Test @MainActor
    func directResultsAssignmentRemainsBackwardCompatible() {
        let state = TorrentSearchState()
        state.results = makeTorrentResults(count: 7)

        #expect(state.results.count == 7)
        #expect(state.remainingResultCount == 0)
        #expect(state.canLoadMoreResults == false)
    }

    @Test @MainActor
    func markCompletedSearchSetsDIdSearch() {
        let state = TorrentSearchState()
        state.markCompletedSearch(episodeId: nil, contextKey: "tt123-movie")
        #expect(state.didSearch)
    }

    @Test @MainActor
    func markCompletedSearchSetsContextKey() {
        let state = TorrentSearchState()
        state.markCompletedSearch(episodeId: nil, contextKey: "tt123-s1e1")
        #expect(state.lastSearchContextKey == "tt123-s1e1")
    }

    @Test @MainActor
    func markCompletedSearchSetsEpisodeId() {
        let state = TorrentSearchState()
        state.markCompletedSearch(episodeId: "ep-1-2", contextKey: "tt123-s1e2")
        #expect(state.lastSearchEpisodeId == "ep-1-2")
    }

    @Test @MainActor
    func markCompletedSearchWithNilEpisodeId() {
        let state = TorrentSearchState()
        state.markCompletedSearch(episodeId: nil, contextKey: "movie-key")
        #expect(state.lastSearchEpisodeId == nil)
    }

    @Test @MainActor
    func markCompletedSearchOverwritesPreviousValues() {
        let state = TorrentSearchState()
        state.markCompletedSearch(episodeId: "ep-1", contextKey: "key-1")
        state.markCompletedSearch(episodeId: "ep-2", contextKey: "key-2")
        #expect(state.lastSearchEpisodeId == "ep-2")
        #expect(state.lastSearchContextKey == "key-2")
    }

    @Test @MainActor
    func invalidateForEpisodeChangeClearsResults() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 9), initialBatchSize: 3)
        _ = state.revealMoreResults(batchSize: 3)
        state.markCompletedSearch(episodeId: "ep-1", contextKey: "key-1")

        state.invalidateForEpisodeChange()

        #expect(state.results.isEmpty)
        #expect(state.remainingResultCount == 0)
        #expect(state.canLoadMoreResults == false)
        // didSearch and context key are intentionally NOT cleared by invalidate
        // (the search freshness check uses them to detect stale results)
        #expect(state.didSearch)
    }

    @Test @MainActor
    func invalidateOnEmptyStateIsIdempotent() {
        let state = TorrentSearchState()
        state.invalidateForEpisodeChange()
        state.invalidateForEpisodeChange()
        #expect(state.results.isEmpty)
        #expect(state.remainingResultCount == 0)
        #expect(state.canLoadMoreResults == false)
    }

    @Test @MainActor
    func allHashesReturnsHashesFromAllResults() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 5), initialBatchSize: 2)
        #expect(state.allHashes == ["hash-0", "hash-1", "hash-2", "hash-3", "hash-4"])
    }

    @Test @MainActor
    func allHashesSkipsDirectStreamResults() {
        let state = TorrentSearchState()
        var direct = Fixtures.torrent(
            hash: "abcdef1234567890abcdef1234567890abcdef12",
            title: "Direct.1080p"
        )
        direct.directStreamURL = "https://cdn.example.com/direct.mkv?token=abc"
        state.setSearchResults([
            Fixtures.torrent(hash: "hash-0", title: "Debrid.1080p"),
            direct,
        ], initialBatchSize: 2)

        #expect(state.allHashes == ["hash-0"])
    }

    @Test @MainActor
    func updateCacheStatusMarksMatchingResultsCached() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 4), initialBatchSize: 3)

        let cacheResults: [String: (CacheStatus, DebridServiceType)] = [
            "hash-1": (.cached(fileId: nil, fileName: nil, fileSize: nil), .realDebrid),
            "hash-3": (.cached(fileId: nil, fileName: nil, fileSize: nil), .allDebrid),
        ]
        state.updateCacheStatus(cacheResults)

        #expect(state.results[0].isCached == false)
        #expect(state.results[1].isCached == true)
        #expect(state.results[1].cachedOnService == DebridServiceType.realDebrid.rawValue)
        #expect(state.results[2].isCached == false)
    }

    @Test @MainActor
    func updateCacheStatusIsNoOpForEmptyResults() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 2), initialBatchSize: 2)
        state.updateCacheStatus([:])
        #expect(state.results[0].isCached == false)
        #expect(state.results[1].isCached == false)
    }

    @Test @MainActor
    func updateCacheStatusIgnoresUnknownHashesWithoutRefreshingVisibleWindow() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 3), initialBatchSize: 2)

        state.updateCacheStatus([
            "missing-hash": (.cached(fileId: "file", fileName: "Missing.mkv", fileSize: 1), .realDebrid),
        ])

        #expect(state.results.map(\.infoHash) == ["hash-0", "hash-1"])
        #expect(state.results.allSatisfy { !$0.isCached })
        #expect(state.remainingResultCount == 1)
    }

    @Test @MainActor
    func updateCacheStatusDoesNotDowngradeAlreadyCachedResults() {
        let state = TorrentSearchState()
        var results = makeTorrentResults(count: 2)
        results[0].isCached = true
        results[0].cachedOnService = DebridServiceType.realDebrid.rawValue
        state.setSearchResults(results, initialBatchSize: 2)

        let cacheResults: [String: (CacheStatus, DebridServiceType)] = [
            "hash-0": (.notCached, .allDebrid),
        ]
        state.updateCacheStatus(cacheResults)

        #expect(state.results[0].isCached == true)
        #expect(state.results[0].cachedOnService == DebridServiceType.realDebrid.rawValue)
    }

    @Test @MainActor
    func updateCacheStatusIgnoresMatchingNotCachedResults() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 2), initialBatchSize: 2)

        state.updateCacheStatus([
            "hash-0": (.notCached, .premiumize),
            "hash-1": (.unknown, .allDebrid),
        ])

        #expect(state.results[0].isCached == false)
        #expect(state.results[0].cachedOnService == nil)
        #expect(state.results[1].isCached == false)
        #expect(state.results[1].cachedOnService == nil)
    }

    @Test @MainActor
    func updateCacheStatusForHiddenResultIsAppliedWhenRevealed() {
        let state = TorrentSearchState()
        state.setSearchResults(makeTorrentResults(count: 4), initialBatchSize: 2)

        state.updateCacheStatus([
            "hash-3": (.cached(fileId: "file-3", fileName: "Hidden.mkv", fileSize: 123), .premiumize),
        ])

        #expect(state.results.count == 2)
        #expect(state.results.allSatisfy { !$0.isCached })

        #expect(state.revealMoreResults(batchSize: 2))
        #expect(state.results[3].isCached)
        #expect(state.results[3].cachedOnService == DebridServiceType.premiumize.rawValue)
    }

    @Test @MainActor
    func sourceFilterHidesConfirmedDownloadsButKeepsRawHashesForCacheChecks() {
        let state = TorrentSearchState()
        state.setSourceFilterOptions(SourceFilterPreset.instant.defaultOptions)
        state.setSearchResults(makeTorrentResults(count: 3), initialBatchSize: 3)

        state.updateCacheStatus([
            "hash-0": (.notCached, .premiumize),
            "hash-1": (.cached(fileId: "file-1", fileName: "Cached.mkv", fileSize: nil), .realDebrid),
        ])

        #expect(state.allHashes == ["hash-0", "hash-1", "hash-2"])
        #expect(state.results.map(\.infoHash) == ["hash-1", "hash-2"])
        #expect(state.results[0].isCached)
        #expect(state.results[0].cachedOnService == DebridServiceType.realDebrid.rawValue)
    }

    @Test @MainActor
    func changingSourceFilterPreservesVisibleWindowCount() {
        let state = TorrentSearchState()
        let results = [
            Fixtures.torrent(hash: "hash-0", title: "Result.0.2160p", quality: .uhd4k),
            Fixtures.torrent(hash: "hash-1", title: "Result.1.2160p", quality: .uhd4k),
            Fixtures.torrent(hash: "hash-2", title: "Result.2.2160p", quality: .uhd4k),
            Fixtures.torrent(hash: "hash-3", title: "Result.3.2160p", quality: .uhd4k),
            Fixtures.torrent(hash: "hash-4", title: "Result.4.720p", quality: .hd720p),
            Fixtures.torrent(hash: "hash-5", title: "Result.5.720p", quality: .hd720p),
        ]
        state.setSearchResults(results, initialBatchSize: 3)
        #expect(state.results.count == 3)

        state.setSourceFilterOptions(SourceFilterOptions(
            preset: .custom,
            hideConfirmedDownloads: false,
            hideCamSources: true,
            minimumSeeders: 0,
            maximumSizeGB: nil,
            minimumQuality: .uhd4k
        ))

        #expect(state.results.count == 3)
        #expect(state.results.allSatisfy { $0.quality == .uhd4k })
    }

    private func makeTorrentResults(count: Int) -> [TorrentResult] {
        (0..<count).map { index in
            Fixtures.torrent(
                hash: "hash-\(index)",
                title: "Result.\(index).1080p"
            )
        }
    }
}

// MARK: - DebridResolverState

@Suite("DebridResolverState", .serialized)
struct DebridResolverStateTests {

    @Test @MainActor
    func initialStateIsEmpty() {
        let state = DebridResolverState()
        #expect(state.streams.isEmpty)
    }

    @Test @MainActor
    func appendStreamIfNeededAddsNewStream() {
        let state = DebridResolverState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        state.appendStreamIfNeeded(stream)
        #expect(state.streams.count == 1)
        #expect(state.streams.first?.id == stream.id)
    }

    @Test @MainActor
    func appendStreamIfNeededIgnoresDuplicate() {
        let state = DebridResolverState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        state.appendStreamIfNeeded(stream)
        state.appendStreamIfNeeded(stream)
        #expect(state.streams.count == 1)
    }

    @Test @MainActor
    func appendStreamIfNeededAllowsDifferentStreams() {
        let state = DebridResolverState()
        let s1 = Fixtures.stream(url: "https://cdn.example.com/a.mkv", fileName: "a.mkv")
        let s2 = Fixtures.stream(url: "https://cdn.example.com/b.mkv", fileName: "b.mkv")
        state.appendStreamIfNeeded(s1)
        state.appendStreamIfNeeded(s2)
        #expect(state.streams.count == 2)
    }

    @Test @MainActor
    func appendStreamIfNeededKeepsDistinctResolvedURLsForSameReleaseMetadata() {
        let state = DebridResolverState()
        let primary = Fixtures.stream(
            url: "https://cdn.example.com/files/stream-a.mkv?token=one",
            fileName: "Movie.2026.1080p.WEB-DL.mkv"
        )
        let alternate = Fixtures.stream(
            url: "https://cdn.example.com/files/stream-b.mkv?token=two",
            fileName: "Movie.2026.1080p.WEB-DL.mkv"
        )
        let refreshedPrimary = Fixtures.stream(
            url: "https://cdn.example.com/files/stream-a.mkv?token=three",
            fileName: "Movie.2026.1080p.WEB-DL.mkv"
        )

        state.appendStreamIfNeeded(primary)
        state.appendStreamIfNeeded(alternate)
        state.appendStreamIfNeeded(refreshedPrimary)

        #expect(state.streams.count == 2)
        #expect(state.streams.map(\.streamURL.path).sorted() == ["/files/stream-a.mkv", "/files/stream-b.mkv"])
    }

    @Test @MainActor
    func clearStreamsEmptiesArray() {
        let state = DebridResolverState()
        state.appendStreamIfNeeded(Fixtures.stream(fileName: "a.mkv"))
        state.appendStreamIfNeeded(Fixtures.stream(url: "https://cdn.example.com/b.mkv", fileName: "b.mkv"))
        state.clearStreams()
        #expect(state.streams.isEmpty)
    }

    @Test @MainActor
    func clearStreamsIsIdempotent() {
        let state = DebridResolverState()
        state.clearStreams()
        state.clearStreams()
        #expect(state.streams.isEmpty)
    }

    @Test @MainActor
    func appendAfterClearAddsStream() {
        let state = DebridResolverState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        state.appendStreamIfNeeded(stream)
        state.clearStreams()
        state.appendStreamIfNeeded(stream)
        #expect(state.streams.count == 1)
    }
}

// MARK: - MediaLibraryState

@Suite("MediaLibraryState", .serialized)
struct MediaLibraryStateTests {

    @Test @MainActor
    func initialStateDefaults() {
        let state = MediaLibraryState()
        #expect(state.watchHistory == nil)
        #expect(state.isInWatchlist == false)
        #expect(state.isInFavorites == false)
        #expect(state.watchlistFolders.isEmpty)
        #expect(state.favoriteFolders.isEmpty)
        #expect(state.statusMessage == nil)
    }

    @Test @MainActor
    func statusMessageCanBeSetAndCleared() {
        let state = MediaLibraryState()
        state.statusMessage = "Added to watchlist."
        #expect(state.statusMessage == "Added to watchlist.")
        state.statusMessage = nil
        #expect(state.statusMessage == nil)
    }

    @Test @MainActor
    func isInWatchlistCanBeToggled() {
        let state = MediaLibraryState()
        state.isInWatchlist = true
        #expect(state.isInWatchlist)
        state.isInWatchlist = false
        #expect(state.isInWatchlist == false)
    }

    @Test @MainActor
    func isInFavoritesCanBeToggled() {
        let state = MediaLibraryState()
        state.isInFavorites = true
        #expect(state.isInFavorites)
        state.isInFavorites = false
        #expect(state.isInFavorites == false)
    }

    @Test @MainActor
    func watchHistoryCanBeAssignedAndCleared() {
        let state = MediaLibraryState()
        let history = WatchHistory(
            id: "history-1",
            mediaId: "tt1234567",
            title: "Stored Movie",
            progress: 42,
            duration: 100,
            watchedAt: Date(timeIntervalSince1970: 1_000),
            isCompleted: false
        )

        state.watchHistory = history
        #expect(state.watchHistory == history)

        state.watchHistory = nil
        #expect(state.watchHistory == nil)
    }

    @Test @MainActor
    func folderBucketsCanBeAssignedIndependently() {
        let state = MediaLibraryState()
        let watchlistFolder = makeFolder(
            id: "watchlist-manual",
            name: "Weekend",
            listType: .watchlist
        )
        let favoriteFolder = makeFolder(
            id: "favorites-manual",
            name: "Best",
            listType: .favorites
        )

        state.watchlistFolders = [watchlistFolder]
        state.favoriteFolders = [favoriteFolder]

        #expect(state.watchlistFolders.map(\.id) == ["watchlist-manual"])
        #expect(state.favoriteFolders.map(\.id) == ["favorites-manual"])
    }

    private func makeFolder(
        id: String,
        name: String,
        listType: UserLibraryEntry.ListType
    ) -> LibraryFolder {
        LibraryFolder(
            id: id,
            name: name,
            parentId: LibraryFolder.systemFolderID(for: listType),
            listType: listType,
            folderKind: .manual,
            isSystem: false,
            sortOrder: 0,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

// MARK: - DetailViewModel ViewState Computed Properties

@Suite("DetailViewModel - ViewState Computed Properties", .serialized)
struct DetailViewModelViewStateTests {

    @Test @MainActor
    func errorComputedPropertyReturnsNilWhenIdle() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .idle
        #expect(viewModel.error == nil)
    }

    @Test @MainActor
    func errorComputedPropertyReturnsNilWhenLoaded() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .loaded
        #expect(viewModel.error == nil)
    }

    @Test @MainActor
    func errorComputedPropertyReturnsNilWhenLoading() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .loading(.detail)
        #expect(viewModel.error == nil)
    }

    @Test @MainActor
    func settingErrorTransitionsToErrorState() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.error = .unknown("Test error")
        #expect(viewModel.viewState == .error(.unknown("Test error")))
        #expect(viewModel.error == .unknown("Test error"))
    }

    @Test @MainActor
    func clearingErrorFromErrorStateTransitionsToIdle() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.error = .indexer(.queryFailed("oops"))
        #expect(viewModel.viewState == .error(.indexer(.queryFailed("oops"))))

        viewModel.error = nil
        #expect(viewModel.viewState == .idle)
    }

    @Test @MainActor
    func clearingErrorWhenNotInErrorStateIsNoOp() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .loaded
        viewModel.error = nil
        #expect(viewModel.viewState == .loaded)
    }

    @Test @MainActor
    func isLoadingDetailTrueWhenLoadingDetail() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .loading(.detail)
        #expect(viewModel.isLoadingDetail)
    }

    @Test @MainActor
    func isLoadingDetailTrueWhenLoadingSeasonEpisodes() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .loading(.seasonEpisodes)
        #expect(viewModel.isLoadingDetail)
    }

    @Test @MainActor
    func isLoadingDetailFalseWhenLoadingTorrents() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .loading(.torrentSearch)
        #expect(viewModel.isLoadingDetail == false)
    }

    @Test @MainActor
    func isLoadingTorrentsTrueWhenLoadingTorrentSearch() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .loading(.torrentSearch)
        #expect(viewModel.isLoadingTorrents)
    }

    @Test @MainActor
    func isResolvingStreamTrueWhenStreamResolution() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .loading(.streamResolution)
        #expect(viewModel.isResolvingStream)
    }

    @Test @MainActor
    func isResolvingStreamTrueWhenDownloadQueue() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .loading(.downloadQueue)
        #expect(viewModel.isResolvingStream)
    }

    @Test @MainActor
    func loadingPhaseReturnsNilWhenNotLoading() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .idle
        #expect(viewModel.loadingPhase == nil)
    }

    @Test @MainActor
    func loadingPhaseReturnsCurrentPhase() {
        let appState = AppState()
        let viewModel = DetailViewModel(appState: appState)
        viewModel.viewState = .loading(.librarySync)
        #expect(viewModel.loadingPhase == .librarySync)
    }
}
