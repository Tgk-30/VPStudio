import Foundation
import Testing
@testable import VPStudio

@Suite("DiscoverViewModel - Continue Watching")
@MainActor
struct DiscoverContinueWatchingTests {
    private static func waitUntil(
        timeout: Duration = .milliseconds(5000),
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("waitUntil timed out after \(timeout)")
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    private func makeDB() async throws -> DatabaseManager {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let db = try DatabaseManager(inMemoryNamed: "discover-test-\(UUID().uuidString)")
        try await db.migrate()
        return db
    }

    private func seedHistory(db: DatabaseManager, mediaId: String, title: String, progress: Double, duration: Double, completed: Bool) async throws {
        let item = MediaItem(
            id: mediaId, type: .movie, title: title, year: 2025,
            posterPath: "/poster.jpg", backdropPath: nil, overview: nil,
            genres: [], imdbRating: 7.0, runtime: 120, status: nil,
            tmdbId: 100, lastFetched: Date()
        )
        try await db.saveMediaItem(item)

        let history = WatchHistory(
            id: "\(mediaId)-history",
            mediaId: mediaId,
            episodeId: nil,
            title: title,
            progress: progress,
            duration: duration,
            quality: nil,
            debridService: nil,
            streamURL: nil,
            watchedAt: Date(),
            isCompleted: completed
        )
        try await db.saveWatchHistory(history)
    }

    @Test func continueWatchingLoadsInProgressItems() async throws {
        let db = try await makeDB()
        try await seedHistory(db: db, mediaId: "tt1234567", title: "Test Movie", progress: 3600, duration: 7200, completed: false)

        let vm = DiscoverViewModel(database: db)
        await vm.loadContinueWatching()

        #expect(vm.continueWatching.count == 1)
        #expect(vm.continueWatching.first?.preview.title == "Test Movie")
    }

    @Test func continueWatchingResolvesOMDbHistoryIDToIMDbCachedItem() async throws {
        let db = try await makeDB()
        try await db.saveMediaItem(
            MediaItem(
                id: "tt0133093",
                type: .movie,
                title: "The Matrix",
                year: 1999,
                posterPath: "/matrix.jpg",
                backdropPath: nil,
                overview: nil,
                genres: [],
                imdbRating: 8.7,
                runtime: 136,
                status: nil,
                tmdbId: nil,
                lastFetched: Date()
            )
        )
        try await db.saveWatchHistory(
            WatchHistory(
                id: "matrix-omdb-history",
                mediaId: "movie-omdb-tt0133093",
                episodeId: nil,
                title: "The Matrix",
                progress: 3600,
                duration: 7200,
                quality: nil,
                debridService: nil,
                streamURL: nil,
                watchedAt: Date(),
                isCompleted: false
            )
        )

        let vm = DiscoverViewModel(database: db)
        await vm.loadContinueWatching()

        #expect(vm.continueWatching.count == 1)
        #expect(vm.continueWatching.first?.preview.id == "tt0133093")
        #expect(vm.continueWatching.first?.preview.title == "The Matrix")
    }

    @Test func continueWatchingCarriesEpisodeContextIntoPreview() async throws {
        let db = try await makeDB()
        let item = MediaItem(
            id: "ttyoungpope", type: .series, title: "The Young Pope", year: 2016,
            posterPath: "/poster.jpg", backdropPath: nil, overview: nil,
            genres: [], imdbRating: 8.0, runtime: 60, status: nil,
            tmdbId: 123, lastFetched: Date()
        )
        try await db.saveMediaItem(item)

        let history = WatchHistory(
            id: "ttyoungpope-123-s2e5-history",
            mediaId: "ttyoungpope",
            episodeId: "123-s2e5",
            title: "Episode 5",
            progress: 1200,
            duration: 3600,
            quality: nil,
            debridService: nil,
            streamURL: nil,
            watchedAt: Date(),
            isCompleted: false
        )
        try await db.saveWatchHistory(history)

        let vm = DiscoverViewModel(database: db)
        await vm.loadContinueWatching()

        #expect(vm.continueWatching.count == 1)
        #expect(vm.continueWatching.first?.preview.episodeId == "123-s2e5")
    }

    @Test func continueWatchingExcludesCompletedItems() async throws {
        let db = try await makeDB()
        try await seedHistory(db: db, mediaId: "tt1111111", title: "Finished Movie", progress: 7000, duration: 7200, completed: true)

        let vm = DiscoverViewModel(database: db)
        await vm.loadContinueWatching()

        #expect(vm.continueWatching.isEmpty)
    }

    @Test func continueWatchingExcludesNearlyFinished() async throws {
        let db = try await makeDB()
        // 96% progress — should be excluded (>95% threshold)
        try await seedHistory(db: db, mediaId: "tt2222222", title: "Almost Done", progress: 6912, duration: 7200, completed: false)

        let vm = DiscoverViewModel(database: db)
        await vm.loadContinueWatching()

        #expect(vm.continueWatching.isEmpty)
    }

    @Test func continueWatchingExcludesBarelyScrubbed() async throws {
        let db = try await makeDB()
        // 1% progress — should be excluded (<2% threshold)
        try await seedHistory(db: db, mediaId: "tt3333333", title: "Barely Started", progress: 72, duration: 7200, completed: false)

        let vm = DiscoverViewModel(database: db)
        await vm.loadContinueWatching()

        #expect(vm.continueWatching.isEmpty)
    }

    @Test func continueWatchingEmptyWhenNoHistory() async throws {
        let db = try await makeDB()

        let vm = DiscoverViewModel(database: db)
        await vm.loadContinueWatching()

        #expect(vm.continueWatching.isEmpty)
    }

    @Test func continueWatchingLimitsTo10() async throws {
        let db = try await makeDB()

        for i in 0..<15 {
            try await seedHistory(
                db: db,
                mediaId: "tt\(String(format: "%07d", i))",
                title: "Movie \(i)",
                progress: 3600,
                duration: 7200,
                completed: false
            )
        }

        let vm = DiscoverViewModel(database: db)
        await vm.loadContinueWatching()

        #expect(vm.continueWatching.count == 10)
    }

    @Test func lateDatabaseConfigurationRefreshesContinueWatchingAfterInitialLoad() async throws {
        let db = try await makeDB()
        try await seedHistory(
            db: db,
            mediaId: "tt7654321",
            title: "Configured Late",
            progress: 1800,
            duration: 7200,
            completed: false
        )

        let vm = DiscoverViewModel()
        vm.hasPerformedInitialLoad = true
        vm.configure(database: db)
        try await Self.waitUntil(timeout: .seconds(8)) { vm.continueWatching.count == 1 }

        #expect(vm.continueWatching.count == 1)
        #expect(vm.continueWatching.first?.preview.title == "Configured Late")
    }

    @Test func continueWatchingNavigationUsesResumePlaybackIntent() {
        let preview = MediaPreview(
            id: "ttyoungpope",
            type: .series,
            title: "The Young Pope",
            year: 2016,
            posterPath: "/poster.jpg",
            backdropPath: nil,
            imdbRating: 8.0,
            tmdbId: 123,
            episodeId: "123-s2e5",
            seasonNumber: 2,
            episodeNumber: 5
        )

        let route = DiscoverNavigationPolicy.continueWatchingRoute(for: preview)

        #expect(route.preview == preview)
        #expect(route.initialAction == .resumePlayback)
        #expect(route.id == "ttyoungpope-123-s2e5-resumePlayback")
    }

    @Test func browseNavigationDoesNotAutoResumePlayback() {
        let preview = MediaPreview(
            id: "tt1234567",
            type: .movie,
            title: "Test Movie",
            year: 2025,
            posterPath: "/poster.jpg",
            backdropPath: nil,
            imdbRating: 7.0,
            tmdbId: 100
        )

        let route = DiscoverNavigationPolicy.browseRoute(for: preview)

        #expect(route.preview == preview)
        #expect(route.initialAction == .none)
        #expect(route.id == "tt1234567-none-none")
    }

    @Test func browseNavigationRouteIncludesEpisodeContextWhenPresent() {
        let preview = MediaPreview(
            id: "ttseries",
            type: .series,
            title: "Test Series",
            year: 2026,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 321,
            episodeId: "321-s1e2",
            seasonNumber: 1,
            episodeNumber: 2
        )

        let route = DiscoverNavigationPolicy.browseRoute(for: preview)

        #expect(route.preview == preview)
        #expect(route.initialAction == .none)
        #expect(route.id == "ttseries-321-s1e2-none")
    }
}
