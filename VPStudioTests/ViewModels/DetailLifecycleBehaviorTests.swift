import Foundation
import Testing
@testable import VPStudio

@Suite("Detail Lifecycle Behavior", .serialized)
struct DetailLifecycleBehaviorTests {
    @MainActor
    private func makeIsolatedAppState() async throws -> (AppState, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "detail-lifecycle-\(UUID().uuidString)")
        try await database.migrate()
        let secretStore = TestSecretStore()
        let settingsManager = SettingsManager(database: database, secretStore: secretStore)
        let appState = AppState(
            database: database,
            secretStore: secretStore,
            settingsManager: settingsManager
        )
        return (appState, tempDir)
    }

    @Test
    @MainActor
    func searchPublishesInitialBatchAndLoadMoreRevealsTenAtATime() async {
        let appState = AppState()
        let indexer = FixedDetailIndexerManager(results: makeTorrentResults(count: 25))
        let debrid = StubDebridManager()
        let downloads = StubDownloadManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: indexer,
            debridManager: debrid,
            downloadManager: downloads
        )
        viewModel.mediaItem = MediaItem(id: "tt2300001", type: .movie, title: "Batch Test")

        await viewModel.searchTorrents()

        #expect(viewModel.torrentSearch.results.count == 10)
        #expect(viewModel.canLoadMoreTorrents)
        #expect(viewModel.remainingTorrentCount == 15)
        #expect(viewModel.nextTorrentBatchCount == 10)

        viewModel.loadMoreTorrentResults()
        #expect(viewModel.torrentSearch.results.count == 20)
        #expect(viewModel.remainingTorrentCount == 5)
        #expect(viewModel.nextTorrentBatchCount == 5)

        viewModel.loadMoreTorrentResults()
        #expect(viewModel.torrentSearch.results.count == 25)
        #expect(viewModel.remainingTorrentCount == 0)
        #expect(viewModel.canLoadMoreTorrents == false)
    }

    @Test
    @MainActor
    func newSearchResetsPreviouslyExpandedBatchWindow() async {
        let appState = AppState()
        let indexer = SequentialDetailIndexerManager(
            firstResults: makeTorrentResults(count: 24),
            secondResults: makeTorrentResults(count: 4)
        )
        let debrid = StubDebridManager()
        let downloads = StubDownloadManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: indexer,
            debridManager: debrid,
            downloadManager: downloads
        )
        viewModel.mediaItem = MediaItem(id: "tt2300002", type: .movie, title: "Batch Reset Test")

        await viewModel.searchTorrents()
        viewModel.loadMoreTorrentResults()
        #expect(viewModel.torrentSearch.results.count == 20)

        await viewModel.searchTorrents()

        #expect(viewModel.torrentSearch.results.count == 4)
        #expect(viewModel.remainingTorrentCount == 0)
        #expect(viewModel.canLoadMoreTorrents == false)
    }

    @Test
    @MainActor
    func searchUsesPreviewIMDbAliasWhenLoadedDetailItemKeepsLegacyTMDbID() async {
        let appState = AppState()
        let indexer = FixedDetailIndexerManager(results: makeTorrentResults(count: 1))
        let metadata = TestDetailMetadataProvider(
            detailResult: MediaItem(id: "series-tmdb-77", type: .series, title: "Alias Show", tmdbId: 77),
            seasonsResult: [
                Season(id: 1, seasonNumber: 1, name: "Season 1", overview: nil, posterPath: nil, episodeCount: 1, airDate: nil)
            ],
            episodesBySeason: [
                1: [
                    Episode(
                        id: "77-s1e1",
                        mediaId: "series-tmdb-77",
                        seasonNumber: 1,
                        episodeNumber: 1,
                        title: "Pilot",
                        overview: nil,
                        airDate: nil,
                        stillPath: nil,
                        runtime: nil
                    )
                ]
            ]
        )
        let viewModel = DetailViewModel(
            appState: appState,
            metadataProviderFactory: { _ in metadata },
            indexerManager: indexer,
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )
        let preview = MediaPreview(
            id: "series-imdb-tt2300101",
            type: .series,
            title: "Alias Show",
            tmdbId: 77
        )

        await viewModel.loadDetail(preview: preview, apiKey: "")
        viewModel.selectedSeason = 1
        viewModel.selectedEpisode = Episode(
            id: "77-s1e1",
            mediaId: "series-tmdb-77",
            seasonNumber: 1,
            episodeNumber: 1,
            title: "Pilot",
            overview: nil,
            airDate: nil,
            stillPath: nil,
            runtime: nil
        )

        await viewModel.searchTorrents()

        #expect(viewModel.torrentSearch.results.count == 1)
        #expect(viewModel.lastSearchContextKey == "tt2300101-s1e1")
        #expect(viewModel.requiresFreshEpisodeSearch == false)
    }

    @Test
    @MainActor
    func omdbDetailPreservesPreviewTMDbAliasForExistingRatings() async throws {
        let database = try DatabaseManager(inMemoryNamed: "detail-omdb-rating-alias-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database)
        // The rating was captured on the 1–10 scale; surface it on the same scale
        // so the preserved value round-trips to 9 instead of being re-projected onto
        // the default like/dislike display scale.
        try await database.setSetting(
            key: SettingsKeys.feedbackScaleMode,
            value: FeedbackScaleMode.oneToTen.rawValue
        )
        try await database.saveTasteEvent(
            TasteEvent(
                mediaId: "movie-tmdb-438631",
                eventType: .rated,
                signalStrength: 0.9,
                feedbackScale: .oneToTen,
                feedbackValue: 9,
                source: .manual,
                metadata: ["title": "Dune"]
            )
        )

        let metadata = TestDetailMetadataProvider(
            detailResult: MediaItem(id: "tt1160419", type: .movie, title: "Dune", tmdbId: nil),
            seasonsResult: [],
            episodesBySeason: [:]
        )
        let viewModel = DetailViewModel(
            appState: appState,
            metadataProviderFactory: { _ in metadata },
            indexerManager: StubIndexerManager(),
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )
        let preview = MediaPreview(
            id: "movie-tmdb-438631",
            type: .movie,
            title: "Dune",
            year: 2021,
            tmdbId: 438_631
        )

        await viewModel.loadDetail(preview: preview, apiKey: "")

        #expect(viewModel.mediaItem?.id == "tt1160419")
        #expect(viewModel.mediaItem?.tmdbId == 438_631)
        #expect(viewModel.currentFeedbackValue == 9)
        #expect(try await database.fetchLatestTasteRating(mediaId: "tt1160419")?.mediaId == "movie-tmdb-438631")
    }

    @Test
    @MainActor
    func secondSearchCancelsBlockedFirstSearchAndKeepsNewestResults() async {
        let appState = AppState()
        let staleResult = Fixtures.torrent(hash: "stale-hash", title: "Old.Result")
        let freshResult = Fixtures.torrent(hash: "fresh-hash", title: "New.Result")
        let indexer = BlockingDetailIndexerManager(firstResults: [staleResult], secondResults: [freshResult])
        let debrid = StubDebridManager()
        let downloads = StubDownloadManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: indexer,
            debridManager: debrid,
            downloadManager: downloads
        )
        viewModel.mediaItem = MediaItem(id: "tt1234567", type: .movie, title: "Cancellation Test")

        defer { Task { await indexer.unblockFirstSearchWithStaleResults() } }

        let firstSearch = Task { await viewModel.searchTorrents() }
        await indexer.waitForFirstSearchToStart()

        await viewModel.searchTorrents()
        await firstSearch.value

        #expect(await indexer.searchCallCount() == 2)
        #expect(viewModel.torrentSearch.results.map(\.infoHash) == ["fresh-hash"])
        #expect(viewModel.torrentSearch.didSearch)
    }

    @Test
    @MainActor
    func cancelInFlightWorkStopsBlockedSearchBeforeItCanPublishResults() async {
        let appState = AppState()
        let staleResult = Fixtures.torrent(hash: "stale-hash", title: "Old.Result")
        let indexer = BlockingDetailIndexerManager(firstResults: [staleResult], secondResults: [])
        let debrid = StubDebridManager()
        let downloads = StubDownloadManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: indexer,
            debridManager: debrid,
            downloadManager: downloads
        )
        viewModel.mediaItem = MediaItem(id: "tt7654321", type: .movie, title: "Cancellation Test")

        defer { Task { await indexer.unblockFirstSearchWithStaleResults() } }

        let searchTask = Task { await viewModel.searchTorrents() }
        await indexer.waitForFirstSearchToStart()

        viewModel.cancelInFlightWork()
        await searchTask.value

        #expect(await indexer.searchCallCount() == 1)
        #expect(viewModel.torrentSearch.results.isEmpty)
        #expect(viewModel.torrentSearch.didSearch == false)
    }

    @Test
    @MainActor
    func loadDetailRestoresEpisodeFromPreviewContextInsteadOfResettingToSeasonOneEpisodeOne() async {
        let appState = AppState()
        let metadata = TestDetailMetadataProvider(
            detailResult: MediaItem(id: "ttyoungpope", type: .series, title: "The Young Pope", tmdbId: 123),
            seasonsResult: [
                Season(id: 1, seasonNumber: 1, name: "Season 1", overview: nil, posterPath: nil, episodeCount: 10, airDate: nil),
                Season(id: 2, seasonNumber: 2, name: "Season 2", overview: nil, posterPath: nil, episodeCount: 10, airDate: nil)
            ],
            episodesBySeason: [
                2: [
                    Episode(id: "123-s2e4", mediaId: "tmdb-123", seasonNumber: 2, episodeNumber: 4, title: "Episode 4", overview: nil, airDate: nil, stillPath: nil, runtime: nil),
                    Episode(id: "123-s2e5", mediaId: "tmdb-123", seasonNumber: 2, episodeNumber: 5, title: "Episode 5", overview: nil, airDate: nil, stillPath: nil, runtime: nil)
                ]
            ]
        )

        let viewModel = DetailViewModel(
            appState: appState,
            metadataProviderFactory: { _ in metadata },
            indexerManager: StubIndexerManager(),
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )

        let preview = MediaPreview(
            id: "ttyoungpope",
            type: .series,
            title: "The Young Pope",
            tmdbId: 123,
            episodeId: "123-s2e5"
        )

        await viewModel.loadDetail(preview: preview, apiKey: "")

        #expect(viewModel.selectedSeason == 2)
        #expect(viewModel.selectedEpisode?.episodeNumber == 5)
    }

    @Test
    @MainActor
    func reloadLibraryStateRefreshesStoredWatchHistoryAndEpisodeStates() async throws {
        let (appState, tempDir) = try await makeIsolatedAppState()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await appState.database.saveWatchHistory(
            WatchHistory(
                id: "young-pope-history",
                mediaId: "ttyoungpope",
                episodeId: "ttyoungpope-s1e2",
                title: "Episode 2",
                progress: 3600,
                duration: 3600,
                watchedAt: Date(),
                isCompleted: true
            )
        )

        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )
        viewModel.setPreviewContext(
            MediaPreview(
                id: "ttyoungpope",
                type: .series,
                title: "The Young Pope"
            )
        )

        await viewModel.reloadLibraryState()

        #expect(viewModel.watchHistory?.episodeId == "ttyoungpope-s1e2")
        #expect(viewModel.episodeWatchStates["ttyoungpope-s1e2"]?.isCompleted == true)
    }

    @Test
    @MainActor
    func resolveStreamUsesSelectedEpisodeContextForSeries() async {
        let appState = AppState()
        let debrid = StubDebridManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: StubDownloadManager()
        )
        viewModel.mediaItem = MediaItem(id: "ttyoungpope", type: .series, title: "The Young Pope")
        viewModel.selectedEpisode = Episode(
            id: "123-s1e5",
            mediaId: "ttyoungpope",
            seasonNumber: 1,
            episodeNumber: 5,
            title: "Episode 5",
            overview: nil,
            airDate: nil,
            stillPath: nil,
            runtime: nil
        )

        let torrent = Fixtures.torrent(hash: "young-pope-pack", title: "The.Young.Pope.S01.Pack")
        _ = await viewModel.resolveStream(torrent: torrent)

        #expect(await debrid.lastResolvedHash == "young-pope-pack")
        #expect(await debrid.lastResolvedMagnetURI == torrent.magnetURI)
        #expect(await debrid.lastResolvedSeasonNumber == 1)
        #expect(await debrid.lastResolvedEpisodeNumber == 5)
    }

    @Test
    @MainActor
    func resolveStreamUsesDirectStremioURLWithoutDebridRoundTrip() async {
        let appState = AppState()
        let debrid = StubDebridManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: StubDownloadManager()
        )
        viewModel.mediaItem = MediaItem(id: "ttdirect", type: .movie, title: "Direct")

        var torrent = Fixtures.torrent(
            hash: "abcdef1234567890abcdef1234567890abcdef12",
            title: "Direct.2026.1080p.WEB-DL.mkv",
            indexerName: "Stremio Torrentio"
        )
        torrent.directStreamURL = "https://cdn.example.com/direct/Direct.2026.1080p.WEB-DL.mkv?token=abc"

        let stream = await viewModel.resolveStream(torrent: torrent)

        #expect(stream?.streamURL.absoluteString == torrent.directStreamURL)
        #expect(stream?.debridService == "Stremio Torrentio")
        #expect(stream?.recoveryContext?.infoHash == torrent.infoHash)
        #expect(stream?.recoveryContext?.magnetURI == torrent.magnetURI)
        #expect(await debrid.lastResolvedHash == nil)
        #expect(viewModel.debridResolver.streams.first == stream)
    }

    @Test
    @MainActor
    func resolveStreamRefreshesStremioResolverURLThroughLocalDebridWithHash() async {
        let hash = "abcdef1234567890abcdef1234567890abcdef12"
        let appState = AppState()
        let debrid = StubDebridManager()
        await debrid.setResolvedStream(
            Fixtures.stream(
                url: "https://rd.example.com/generated/Regional.Release.mkv",
                fileName: "Regional.Release.mkv",
                debridService: DebridServiceType.realDebrid.rawValue
            )
        )
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: StubDownloadManager()
        )
        viewModel.mediaItem = MediaItem(id: "ttresolver", type: .movie, title: "Resolver")

        var torrent = Fixtures.torrent(
            hash: hash,
            title: "Regional.Release.1080p.WEB-DL.mkv",
            cached: true,
            indexerName: "Stremio Torrentio"
        )
        torrent.directStreamURL = "https://torrentio.strem.fun/resolve/rd/\(hash)/Regional.Release.mkv"

        let stream = await viewModel.resolveStream(torrent: torrent)

        #expect(stream?.streamURL.absoluteString == "https://rd.example.com/generated/Regional.Release.mkv")
        #expect(stream?.debridService == DebridServiceType.realDebrid.rawValue)
        #expect(stream?.recoveryContext?.infoHash == hash)
        #expect(await debrid.lastResolvedHash == hash)
        #expect(await debrid.lastResolvedMagnetURI == torrent.magnetURI)
    }

    @Test
    @MainActor
    func resolveStreamUsesStremioRealDebridGeneratedURLDirectlyWithHash() async {
        let hash = "abcdef1234567890abcdef1234567890abcdef12"
        let appState = AppState()
        let debrid = StubDebridManager()
        await debrid.setResolvedStream(
            Fixtures.stream(
                url: "https://rd.example.com/generated/Regional.Release.mkv",
                fileName: "Regional.Release.mkv",
                debridService: DebridServiceType.realDebrid.rawValue
            )
        )
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: StubDownloadManager()
        )
        viewModel.mediaItem = MediaItem(id: "ttrdgenerated", type: .movie, title: "Resolver")

        var torrent = Fixtures.torrent(
            hash: hash,
            title: "Regional.Release.1080p.WEB-DL.mkv",
            cached: true,
            indexerName: "Stremio Torrentio"
        )
        torrent.directStreamURL = "https://sea1.download.real-debrid.com/d/abc/Regional.Release.mkv"

        let stream = await viewModel.resolveStream(torrent: torrent)

        #expect(stream?.streamURL.absoluteString == torrent.directStreamURL)
        #expect(stream?.debridService == "Stremio Torrentio")
        #expect(stream?.recoveryContext?.infoHash == hash)
        #expect(stream?.recoveryContext?.magnetURI == torrent.magnetURI)
        #expect(await debrid.lastResolvedHash == nil)
        #expect(await debrid.lastResolvedMagnetURI == nil)
    }

    @Test
    @MainActor
    func resolveStreamUsesStremioRealDebridGeneratedURLDirectlyWithoutHash() async {
        let appState = AppState()
        let debrid = StubDebridManager()
        await debrid.setUnrestrictedStream(
            Fixtures.stream(
                url: "https://rd.example.com/refreshed/Regional.Release.mkv",
                fileName: "Regional.Release.mkv",
                debridService: DebridServiceType.realDebrid.rawValue
            )
        )
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: StubDownloadManager()
        )
        viewModel.mediaItem = MediaItem(id: "ttrdgenerated-direct", type: .movie, title: "Resolver")

        var torrent = Fixtures.torrent(
            hash: "direct-regional",
            title: "Regional.Release.1080p.WEB-DL.mkv",
            cached: true,
            indexerName: "Stremio Torrentio"
        )
        torrent.directStreamURL = "https://sea1.download.real-debrid.com/d/abc/Regional.Release.mkv"

        let stream = await viewModel.resolveStream(torrent: torrent)

        #expect(stream?.streamURL.absoluteString == torrent.directStreamURL)
        #expect(stream?.debridService == "Stremio Torrentio")
        #expect(stream?.recoveryContext == nil)
        #expect(await debrid.lastUnrestrictedLink == nil)
        #expect(await debrid.lastUnrestrictedServiceType == nil)
        #expect(await debrid.lastResolvedHash == nil)
    }

    @Test
    @MainActor
    func queueDownloadRefreshesStremioResolverURLThroughLocalDebridWithHash() async {
        let hash = "abcdef1234567890abcdef1234567890abcdef12"
        let appState = AppState()
        let debrid = StubDebridManager()
        let downloads = StubDownloadManager()
        await debrid.setResolvedStream(
            Fixtures.stream(
                url: "https://rd.example.com/generated/Regional.Download.mkv",
                fileName: "Regional.Download.mkv",
                debridService: DebridServiceType.realDebrid.rawValue
            )
        )
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: downloads
        )
        viewModel.mediaItem = MediaItem(id: "ttresolver-download", type: .movie, title: "Resolver Download")

        var torrent = Fixtures.torrent(
            hash: hash,
            title: "Regional.Download.1080p.WEB-DL.mkv",
            cached: true,
            indexerName: "Stremio Torrentio"
        )
        torrent.directStreamURL = "https://torrentio.strem.fun/resolve/realdebrid/\(hash)/Regional.Download.mkv"

        await viewModel.queueDownload(torrent: torrent)

        let tasks = (try? await downloads.listDownloads()) ?? []
        #expect(await debrid.lastResolvedHash == hash)
        #expect(await debrid.lastResolvedMagnetURI == torrent.magnetURI)
        #expect(tasks.first?.streamURL == "https://rd.example.com/generated/Regional.Download.mkv")
        #expect(viewModel.downloadState(for: torrent) == .downloading)
    }

    @Test
    @MainActor
    func queueDownloadUsesCanonicalIMDbMediaIdentifierWhenPreviewProvidesAlias() async {
        let appState = AppState()
        let debrid = StubDebridManager()
        let downloads = StubDownloadManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: downloads
        )
        viewModel.mediaItem = MediaItem(
            id: "movie-tmdb-438631",
            type: .movie,
            title: "Dune",
            tmdbId: 438_631
        )
        viewModel.setPreviewContext(
            MediaPreview(
                id: "movie-imdb-tt1160419",
                type: .movie,
                title: "Dune",
                year: 2021,
                posterPath: nil,
                imdbRating: nil,
                tmdbId: nil
            )
        )

        let torrent = Fixtures.torrent(
            hash: "canonical-download",
            title: "Dune.2021.1080p.WEB-DL.mkv",
            cached: true
        )

        await viewModel.queueDownload(torrent: torrent)

        let tasks = (try? await downloads.listDownloads()) ?? []
        #expect(tasks.first?.mediaId == "tt1160419")
    }

    @Test
    @MainActor
    func resolveStreamDoesNotAttachRecoveryContextForSyntheticDirectOnlyResult() async {
        let appState = AppState()
        let debrid = StubDebridManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: StubDownloadManager()
        )
        viewModel.mediaItem = MediaItem(id: "ttdirect", type: .movie, title: "Direct")

        var torrent = Fixtures.torrent(
            hash: "direct-abcdef1234567890abcdef1234567890abcdef12",
            title: "Direct.2026.1080p.WEB-DL.mkv",
            indexerName: "Stremio Torrentio"
        )
        torrent.directStreamURL = "https://cdn.example.com/direct/Direct.2026.1080p.WEB-DL.mkv?token=abc"

        let stream = await viewModel.resolveStream(torrent: torrent)

        #expect(stream?.streamURL.absoluteString == torrent.directStreamURL)
        #expect(stream?.recoveryContext == nil)
        #expect(await debrid.lastResolvedHash == nil)
    }

    @Test
    @MainActor
    func resolveStreamAttachesRecoveryContextForDebridLinkRefresh() async {
        let appState = AppState()
        let debrid = StubDebridManager()
        await debrid.setResolvedStream(
            Fixtures.stream(debridService: DebridServiceType.allDebrid.rawValue)
        )
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: StubDownloadManager()
        )
        viewModel.mediaItem = MediaItem(id: "ttyoungpope", type: .series, title: "The Young Pope")
        viewModel.selectedEpisode = Episode(
            id: "123-s1e5",
            mediaId: "ttyoungpope",
            seasonNumber: 1,
            episodeNumber: 5,
            title: "Episode 5",
            overview: nil,
            airDate: nil,
            stillPath: nil,
            runtime: nil
        )

        let torrent = Fixtures.torrent(hash: "YOUNG-POPE-PACK", title: "The.Young.Pope.S01.Pack")
        let stream = await viewModel.resolveStream(torrent: torrent)

        #expect(stream?.recoveryContext?.infoHash == "young-pope-pack")
        #expect(stream?.recoveryContext?.preferredService == .allDebrid)
        #expect(stream?.recoveryContext?.magnetURI == torrent.magnetURI)
        #expect(stream?.recoveryContext?.seasonNumber == 1)
        #expect(stream?.recoveryContext?.episodeNumber == 5)
        #expect(viewModel.debridResolver.streams.first?.recoveryContext == stream?.recoveryContext)
    }

    @Test
    @MainActor
    func loadDetailFallsBackToMostRecentEpisodeHistoryForSeries() async throws {
        let db = try DatabaseManager(inMemoryNamed: "detail-history-\(UUID().uuidString)")
        try await db.migrate()

        let history = WatchHistory(
            id: "ttyoungpope-123-s2e4-progress",
            mediaId: "ttyoungpope",
            episodeId: "123-s2e4",
            title: "Episode 4",
            progress: 1200,
            duration: 3600,
            quality: nil,
            debridService: nil,
            streamURL: nil,
            watchedAt: Date(),
            isCompleted: false
        )
        try await db.saveWatchHistory(history)

        let appState = AppState(database: db)
        let metadata = TestDetailMetadataProvider(
            detailResult: MediaItem(id: "ttyoungpope", type: .series, title: "The Young Pope", tmdbId: 123),
            seasonsResult: [
                Season(id: 1, seasonNumber: 1, name: "Season 1", overview: nil, posterPath: nil, episodeCount: 10, airDate: nil),
                Season(id: 2, seasonNumber: 2, name: "Season 2", overview: nil, posterPath: nil, episodeCount: 10, airDate: nil)
            ],
            episodesBySeason: [
                2: [
                    Episode(id: "123-s2e4", mediaId: "tmdb-123", seasonNumber: 2, episodeNumber: 4, title: "Episode 4", overview: nil, airDate: nil, stillPath: nil, runtime: nil),
                    Episode(id: "123-s2e5", mediaId: "tmdb-123", seasonNumber: 2, episodeNumber: 5, title: "Episode 5", overview: nil, airDate: nil, stillPath: nil, runtime: nil)
                ]
            ]
        )

        let viewModel = DetailViewModel(
            appState: appState,
            metadataProviderFactory: { _ in metadata },
            indexerManager: StubIndexerManager(),
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )

        let preview = MediaPreview(id: "ttyoungpope", type: .series, title: "The Young Pope", tmdbId: 123)

        await viewModel.loadDetail(preview: preview, apiKey: "")

        #expect(viewModel.selectedSeason == 2)
        #expect(viewModel.selectedEpisode?.episodeNumber == 4)
    }

    @Test
    @MainActor
    func selectingAnotherEpisodeCancelsInFlightSearchAndSuppressesStaleResults() async {
        let appState = AppState()
        let staleResult = Fixtures.torrent(hash: "stale-episode-hash", title: "Old.Episode.Result")
        let indexer = BlockingDetailIndexerManager(firstResults: [staleResult], secondResults: [])
        let debrid = StubDebridManager()
        let downloads = StubDownloadManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: indexer,
            debridManager: debrid,
            downloadManager: downloads
        )
        viewModel.mediaItem = MediaItem(id: "tt3333333", type: .series, title: "Episode Cancellation Test")
        viewModel.selectedSeason = 1
        let episodeOne = Episode(
            id: "tt3333333-s1e1",
            mediaId: "tt3333333",
            seasonNumber: 1,
            episodeNumber: 1,
            title: "Episode 1",
            overview: nil,
            airDate: nil,
            stillPath: nil,
            runtime: nil
        )
        let episodeTwo = Episode(
            id: "tt3333333-s1e2",
            mediaId: "tt3333333",
            seasonNumber: 1,
            episodeNumber: 2,
            title: "Episode 2",
            overview: nil,
            airDate: nil,
            stillPath: nil,
            runtime: nil
        )
        viewModel.episodes = [episodeOne, episodeTwo]
        viewModel.selectedEpisode = episodeOne

        defer { Task { await indexer.unblockFirstSearchWithStaleResults() } }

        let searchTask = Task { await viewModel.searchTorrents() }
        await indexer.waitForFirstSearchToStart()

        viewModel.selectEpisode(episodeTwo)
        await searchTask.value

        #expect(await indexer.searchCallCount() == 1)
        #expect(viewModel.selectedEpisode?.id == episodeTwo.id)
        #expect(viewModel.torrentSearch.results.isEmpty)
        #expect(viewModel.torrentSearch.didSearch == false)
    }

    @Test
    @MainActor
    func retryReplaysFailedStreamResolutionForLastTorrent() async {
        let appState = AppState()
        let debrid = RetryableDetailDebridManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: StubDownloadManager()
        )
        viewModel.mediaItem = MediaItem(id: "ttretry-stream", type: .movie, title: "Retry Stream")
        let torrent = Fixtures.torrent(hash: "retry-stream-hash", title: "Retry.Stream.1080p")

        let initialStream = await viewModel.resolveStream(torrent: torrent)

        #expect(initialStream == nil)
        #expect(viewModel.error != nil)
        #expect(await debrid.resolveCallCount() == 1)
        #expect(viewModel.debridResolver.streams.isEmpty)

        await viewModel.retryLastFailedOperation(apiKey: "")

        #expect(viewModel.error == nil)
        #expect(await debrid.resolveCallCount() == 2)
        #expect(viewModel.debridResolver.streams.count == 1)
        #expect(viewModel.debridResolver.streams.first?.recoveryContext?.infoHash == "retry-stream-hash")
    }

    @Test
    @MainActor
    func retryReplaysFailedDownloadQueueForLastTorrent() async {
        let appState = AppState()
        let debrid = RetryableDetailDebridManager(initialResolveFailures: 0)
        let downloads = RetryableDetailDownloadManager()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: debrid,
            downloadManager: downloads
        )
        viewModel.mediaItem = MediaItem(id: "ttretry-download", type: .movie, title: "Retry Download")
        let torrent = Fixtures.torrent(hash: "retry-download-hash", title: "Retry.Download.1080p")

        await viewModel.queueDownload(torrent: torrent)

        #expect(viewModel.error != nil)
        #expect(await downloads.enqueueCallCount() == 1)
        #expect(await downloads.downloadCount() == 0)
        #expect(viewModel.downloadState(for: torrent) == .failed)

        await viewModel.retryLastFailedOperation(apiKey: "")

        #expect(viewModel.error == nil)
        #expect(await downloads.enqueueCallCount() == 2)
        #expect(await downloads.downloadCount() == 1)
        #expect(viewModel.downloadState(for: torrent) == .downloading)
    }

    @Test
    @MainActor
    func seriesWatchTallyCountsLoadedOMDbEpisodeIMDbIDs() async {
        let appState = AppState()
        let viewModel = DetailViewModel(
            appState: appState,
            indexerManager: StubIndexerManager(),
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )
        viewModel.mediaItem = MediaItem(id: "tt2300999", type: .series, title: "OMDb Series")
        viewModel.seasons = [
            Season(id: 1, seasonNumber: 1, name: "Season 1", overview: nil, posterPath: nil, episodeCount: 2, airDate: nil)
        ]
        viewModel.episodes = [
            Episode(
                id: "tt2301001",
                mediaId: "tt2300999",
                seasonNumber: 1,
                episodeNumber: 1,
                title: "Pilot",
                overview: nil,
                airDate: nil,
                stillPath: nil,
                runtime: nil
            ),
            Episode(
                id: "tt2301002",
                mediaId: "tt2300999",
                seasonNumber: 1,
                episodeNumber: 2,
                title: "Second",
                overview: nil,
                airDate: nil,
                stillPath: nil,
                runtime: nil
            )
        ]
        viewModel.episodeWatchStates = [
            "tt2301001": WatchHistory(
                id: "watch-omdb-episode",
                mediaId: "tt2300999",
                episodeId: "tt2301001",
                title: "Pilot",
                progress: 1,
                duration: 1,
                watchedAt: Date(),
                isCompleted: true
            ),
            "tt-unloaded-episode": WatchHistory(
                id: "watch-unloaded-omdb-episode",
                mediaId: "tt2300999",
                episodeId: "tt-unloaded-episode",
                title: "Unknown",
                progress: 1,
                duration: 1,
                watchedAt: Date(),
                isCompleted: true
            ),
            "s01e02": WatchHistory(
                id: "watch-trakt-synced-episode",
                mediaId: "tt2300999",
                episodeId: "s01e02",
                title: "Second",
                progress: 1,
                duration: 1,
                watchedAt: Date(),
                isCompleted: true
            )
        ]

        let tally = viewModel.seriesWatchTally
        #expect(tally.watched == 2)
        #expect(tally.total == 2)
    }

    private func makeTorrentResults(count: Int) -> [TorrentResult] {
        (0..<count).map { index in
            Fixtures.torrent(
                hash: "batch-hash-\(index)",
                title: "Batch.Result.\(index).1080p"
            )
        }
    }
}

private actor TestDetailMetadataProvider: DetailMetadataProviding {
    let detailResult: MediaItem
    let seasonsResult: [Season]
    let episodesBySeason: [Int: [Episode]]

    init(detailResult: MediaItem, seasonsResult: [Season], episodesBySeason: [Int: [Episode]]) {
        self.detailResult = detailResult
        self.seasonsResult = seasonsResult
        self.episodesBySeason = episodesBySeason
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem { detailResult }
    func getSeasons(id: String, type: MediaType) async throws -> [Season] { seasonsResult }
    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode] { episodesBySeason[season] ?? [] }
    func getSeasons(tmdbId: Int) async throws -> [Season] { seasonsResult }
    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { episodesBySeason[season] ?? [] }
}

private actor FixedDetailIndexerManager: DetailIndexerManaging {
    private let results: [TorrentResult]

    init(results: [TorrentResult]) {
        self.results = results
    }

    func initialize() async throws {}

    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
        results
    }

    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
        []
    }
}

private actor SequentialDetailIndexerManager: DetailIndexerManaging {
    private let firstResults: [TorrentResult]
    private let secondResults: [TorrentResult]
    private var searchCalls = 0

    init(firstResults: [TorrentResult], secondResults: [TorrentResult]) {
        self.firstResults = firstResults
        self.secondResults = secondResults
    }

    func initialize() async throws {}

    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
        searchCalls += 1
        if searchCalls == 1 {
            return firstResults
        }
        return secondResults
    }

    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
        []
    }
}

private actor BlockingDetailIndexerManager: DetailIndexerManaging {
    private let firstResults: [TorrentResult]
    private let secondResults: [TorrentResult]

    private var searchCalls = 0
    private var firstSearchContinuation: CheckedContinuation<[TorrentResult], Error>?
    private var firstSearchStartedContinuation: CheckedContinuation<Void, Never>?

    init(firstResults: [TorrentResult], secondResults: [TorrentResult]) {
        self.firstResults = firstResults
        self.secondResults = secondResults
    }

    func initialize() async throws {}

    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
        searchCalls += 1
        if searchCalls == 1 {
            return try await withTaskCancellationHandler(
                operation: {
                    try await withCheckedThrowingContinuation { continuation in
                        firstSearchContinuation = continuation
                        firstSearchStartedContinuation?.resume()
                        firstSearchStartedContinuation = nil
                    }
                },
                onCancel: {
                    Task { await self.resumeFirstSearchIfNeeded(throwing: CancellationError()) }
                }
            )
        }

        return secondResults
    }

    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
        []
    }

    func waitForFirstSearchToStart() async {
        if firstSearchContinuation != nil {
            return
        }

        await withCheckedContinuation { continuation in
            firstSearchStartedContinuation = continuation
        }
    }

    func unblockFirstSearchWithStaleResults() {
        firstSearchContinuation?.resume(returning: firstResults)
        firstSearchContinuation = nil
    }

    private func resumeFirstSearchIfNeeded(throwing error: Error) {
        firstSearchContinuation?.resume(throwing: error)
        firstSearchContinuation = nil
    }

    func searchCallCount() -> Int {
        searchCalls
    }
}

private actor RetryableDetailDebridManager: DetailDebridManaging {
    private var remainingResolveFailures: Int
    private var resolvedStream = Fixtures.stream(url: "https://cdn.example.com/retry-stream.mkv")
    private var resolveCalls = 0

    init(initialResolveFailures: Int = 1) {
        self.remainingResolveFailures = initialResolveFailures
    }

    func resolveCallCount() -> Int {
        resolveCalls
    }

    func checkCacheAcrossServices(hashes: [String]) async throws -> [String: (CacheStatus, DebridServiceType)] {
        [:]
    }

    func resolveStream(
        hash: String,
        preferredService: DebridServiceType?,
        magnetURI: String?,
        seasonNumber: Int?,
        episodeNumber: Int?
    ) async throws -> StreamInfo {
        resolveCalls += 1
        if remainingResolveFailures > 0 {
            remainingResolveFailures -= 1
            throw URLError(.timedOut)
        }
        return resolvedStream
    }
}

private actor RetryableDetailDownloadManager: DetailDownloadManaging {
    private var remainingEnqueueFailures = 1
    private var downloads: [DownloadTask] = []
    private var enqueueCalls = 0

    func enqueueCallCount() -> Int {
        enqueueCalls
    }

    func downloadCount() -> Int {
        downloads.count
    }

    func enqueueDownload(
        stream: StreamInfo,
        mediaId: String,
        episodeId: String?,
        mediaTitle: String,
        mediaType: String,
        posterPath: String?,
        seasonNumber: Int?,
        episodeNumber: Int?,
        episodeTitle: String?
    ) async throws -> DownloadTask {
        enqueueCalls += 1
        if remainingEnqueueFailures > 0 {
            remainingEnqueueFailures -= 1
            throw URLError(.cannotConnectToHost)
        }

        let task = DownloadTask(
            mediaId: mediaId,
            episodeId: episodeId,
            streamURL: stream.streamURL.absoluteString,
            fileName: stream.fileName,
            mediaTitle: mediaTitle,
            mediaType: mediaType,
            posterPath: posterPath,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            episodeTitle: episodeTitle
        )
        downloads.append(task)
        return task
    }
}
