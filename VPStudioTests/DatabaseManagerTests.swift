import Testing
import Foundation
import GRDB
@testable import VPStudio

// MARK: - Helpers

private func makeTemporaryDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
    try await database.migrate()
    return (database, tempDir)
}

private func makeInMemoryDatabase(named name: String) async throws -> DatabaseManager {
    let database = try DatabaseManager(inMemoryNamed: name)
    try await database.migrate()
    return database
}

private func withFileBackedTemporaryDatabase(
    named fileName: String,
    _ body: (DatabaseManager, URL) async throws -> Void
) async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    do {
        let dbURL = tempDir.appendingPathComponent(fileName)
        let database = try DatabaseManager(path: dbURL.path)
        try await database.migrate()
        try await body(database, tempDir)
    }

    try? FileManager.default.removeItem(at: tempDir)
}

// MARK: - Initialization Tests

@Suite(.serialized)
struct DatabaseManagerInitializationTests {

    @Test func inMemoryDatabaseCreationAndMigration() async throws {
        let db = try await makeInMemoryDatabase(named: "init-memory-\(UUID().uuidString)")
        let item = MediaItem(id: "init-test", type: .movie, title: "Init Test")
        try await db.saveMediaItem(item)
        let fetched = try await db.fetchMediaItem(id: "init-test")
        #expect(fetched?.title == "Init Test")
    }

    @Test func fileBasedDatabaseCreationAndMigration() async throws {
        try await withFileBackedTemporaryDatabase(named: "file-based.sqlite") { db, _ in
            let item = MediaItem(id: "file-test", type: .series, title: "File Test")
            try await db.saveMediaItem(item)
            let fetched = try await db.fetchMediaItem(id: "file-test")
            #expect(fetched?.type == .series)
        }
    }

    @Test func unavailableDatabaseThrowsOnAccess() async throws {
        let db = DatabaseManager.unavailable(message: "Simulated failure")
        do {
            _ = try await db.fetchMediaItem(id: "any")
            Issue.record("Expected database access to throw")
        } catch {
            let description = (error as? any LocalizedError)?.errorDescription ?? ""
            #expect(description.contains("Simulated failure"))
        }
    }

    @Test func unavailableDatabasePreservesMessage() async throws {
        let db = DatabaseManager.unavailable(message: "Disk full")
        do {
            _ = try await db.fetchWatchHistory(limit: 1)
            Issue.record("Expected throw")
        } catch {
            let description = (error as? any LocalizedError)?.errorDescription ?? ""
            #expect(description == "Disk full")
        }
    }

    @Test func multipleMigrationsAreIdempotent() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "idempotent.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Run migration a second time; should not throw
        try await db.migrate()

        let item = MediaItem(id: "idempotent", type: .movie, title: "Idempotent")
        try await db.saveMediaItem(item)
        #expect(try await db.fetchMediaItem(id: "idempotent") != nil)
    }

    @Test func fileDatabasePersistsAcrossReopen() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let dbURL = tempDir.appendingPathComponent("reopen.sqlite")
        do {
            let db1 = try DatabaseManager(path: dbURL.path)
            try await db1.migrate()
            try await db1.saveMediaItem(MediaItem(id: "reopen", type: .movie, title: "Reopen"))
        }

        let fetchedTitle: String?
        do {
            let db2 = try DatabaseManager(path: dbURL.path)
            try await db2.migrate()
            fetchedTitle = try await db2.fetchMediaItem(id: "reopen")?.title
        }

        try? FileManager.default.removeItem(at: tempDir)
        #expect(fetchedTitle == "Reopen")
    }
}

// MARK: - MediaItem CRUD & Query Tests

@Suite(.serialized)
struct DatabaseManagerMediaItemTests {

    @Test func saveAndFetchMediaItem() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "media-crud.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let item = MediaItem(
            id: "media-1", type: .movie, title: "Inception",
            year: 2010, genres: ["Sci-Fi", "Action"], imdbRating: 8.8, runtime: 148
        )
        try await db.saveMediaItem(item)
        let fetched = try #require(try await db.fetchMediaItem(id: "media-1"))
        #expect(fetched.title == "Inception")
        #expect(fetched.year == 2010)
        #expect(fetched.genres == ["Sci-Fi", "Action"])
        #expect(fetched.imdbRating == 8.8)
        #expect(fetched.runtime == 148)
    }

    @Test func fetchMediaItemReturnsNilForMissingID() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "media-miss.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fetched = try await db.fetchMediaItem(id: "missing")
        #expect(fetched == nil)
    }

    @Test func saveMediaItemOverwritesExisting() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "media-overwrite.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await db.saveMediaItem(MediaItem(id: "media-1", type: .movie, title: "Old", year: 2000))
        try await db.saveMediaItem(MediaItem(id: "media-1", type: .movie, title: "New", year: 2024))
        let fetched = try #require(try await db.fetchMediaItem(id: "media-1"))
        #expect(fetched.title == "New")
        #expect(fetched.year == 2024)
    }

    @Test func fetchMediaItemsByIDs() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "media-bulk.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let items = [
            MediaItem(id: "m1", type: .movie, title: "A"),
            MediaItem(id: "m2", type: .series, title: "B"),
            MediaItem(id: "m3", type: .movie, title: "C"),
        ]
        for item in items { try await db.saveMediaItem(item) }

        let fetched = try await db.fetchMediaItems(ids: ["m1", "m3", "missing"])
        #expect(fetched.count == 2)
        #expect(Set(fetched.map(\.id)) == ["m1", "m3"])
    }

    @Test func fetchMediaItemsByIDsReturnsEmptyForEmptyInput() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "media-empty-bulk.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fetched = try await db.fetchMediaItems(ids: [])
        #expect(fetched.isEmpty)
    }

    @Test func fetchMediaItemsResolvingAliases() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "media-alias.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let item = MediaItem(id: "tt123", type: .movie, title: "Alias Test", tmdbId: 999)
        try await db.saveMediaItem(item)

        let resolved = try await db.fetchMediaItemsResolvingAliases(ids: ["tt123", "movie-tmdb-999"])
        #expect(resolved["tt123"]?.title == "Alias Test")
        #expect(resolved["movie-tmdb-999"]?.title == "Alias Test")
    }
}

// MARK: - WatchHistory CRUD & Query Tests

@Suite(.serialized)
struct DatabaseManagerWatchHistoryTests {

    @Test func saveAndFetchWatchHistory() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "wh-crud.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let wh = WatchHistory(
            id: "wh-1", mediaId: "movie-1", title: "Watch Me",
            progress: 1200, duration: 3600, watchedAt: Date(), isCompleted: false
        )
        try await db.saveWatchHistory(wh)
        let results = try await db.fetchWatchHistory(limit: 10)
        #expect(results.count == 1)
        #expect(results.first?.title == "Watch Me")
    }

    @Test func fetchWatchHistoryByMediaIdAndEpisodeId() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "wh-episode.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let movieWH = WatchHistory(id: "wh-movie", mediaId: "movie-1", title: "Movie", progress: 0, duration: 100, watchedAt: Date(), isCompleted: true)
        let epWH = WatchHistory(id: "wh-ep", mediaId: "series-1", episodeId: "ep-1", title: "Episode", progress: 0, duration: 100, watchedAt: Date(), isCompleted: true)
        try await db.saveWatchHistory(movieWH)
        try await db.saveWatchHistory(epWH)

        let fetchedMovie = try await db.fetchWatchHistory(mediaId: "movie-1")
        #expect(fetchedMovie?.episodeId == nil)

        let fetchedEpisode = try await db.fetchWatchHistory(mediaId: "series-1", episodeId: "ep-1")
        #expect(fetchedEpisode?.episodeId == "ep-1")
    }

    @Test func fetchCompletedWatchHistory() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "wh-completed.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let completed = WatchHistory(id: "wh-c", mediaId: "m1", title: "Done", progress: 100, duration: 100, watchedAt: Date(), isCompleted: true)
        let incomplete = WatchHistory(id: "wh-i", mediaId: "m2", title: "Half", progress: 50, duration: 100, watchedAt: Date(), isCompleted: false)
        try await db.saveWatchHistory(completed)
        try await db.saveWatchHistory(incomplete)

        let results = try await db.fetchCompletedWatchHistory(limit: 10)
        #expect(results.count == 1)
        #expect(results.first?.id == "wh-c")
    }

    @Test func fetchWatchHistoryPagination() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "wh-page.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        for i in 0..<5 {
            let wh = WatchHistory(
                id: "wh-\(i)", mediaId: "m-\(i)", title: "T\(i)",
                progress: 0, duration: 100,
                watchedAt: Date().addingTimeInterval(Double(i)), isCompleted: true
            )
            try await db.saveWatchHistory(wh)
        }

        let page1 = try await db.fetchWatchHistory(limit: 2, offset: 0)
        #expect(page1.count == 2)

        let page2 = try await db.fetchWatchHistory(limit: 2, offset: 2)
        #expect(page2.count == 2)

        let page3 = try await db.fetchWatchHistory(limit: 2, offset: 4)
        #expect(page3.count == 1)
    }

    @Test func hasCompletedWatchHistoryEntryWithTolerance() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "wh-has-entry.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let wh = WatchHistory(
            id: "wh-1", mediaId: "m1", title: "T",
            progress: 100, duration: 100, watchedAt: base, isCompleted: true
        )
        try await db.saveWatchHistory(wh)

        let hasExact = try await db.hasCompletedWatchHistoryEntry(mediaId: "m1", watchedAt: base, tolerance: 0)
        #expect(hasExact == true)

        let hasWithinTolerance = try await db.hasCompletedWatchHistoryEntry(mediaId: "m1", watchedAt: base.addingTimeInterval(0.5), tolerance: 1)
        #expect(hasWithinTolerance == true)

        let hasOutsideTolerance = try await db.hasCompletedWatchHistoryEntry(mediaId: "m1", watchedAt: base.addingTimeInterval(5), tolerance: 1)
        #expect(hasOutsideTolerance == false)
    }

    @Test func markEpisodeWatchedAndUnwatched() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "wh-mark-ep.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await db.markEpisodeWatched(mediaId: "series-1", episodeId: "ep-1", title: "Pilot")
        let before = try await db.fetchWatchHistory(mediaId: "series-1", episodeId: "ep-1")
        #expect(before?.isCompleted == true)

        try await db.markEpisodeUnwatched(mediaId: "series-1", episodeId: "ep-1")
        let after = try await db.fetchWatchHistory(mediaId: "series-1", episodeId: "ep-1")
        #expect(after == nil)
    }

    @Test func markMovieWatchedAndUnwatched() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "wh-mark-movie.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await db.markMovieWatched(mediaId: "movie-1", title: "Film")
        let before = try await db.fetchWatchHistory(mediaId: "movie-1")
        #expect(before?.isCompleted == true)

        try await db.markMovieUnwatched(mediaId: "movie-1")
        let after = try await db.fetchWatchHistory(mediaId: "movie-1")
        #expect(after == nil)
    }

    @Test func markSeriesUnwatchedClearsEpisodesOnly() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "wh-mark-series.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await db.markMovieWatched(mediaId: "series-1", title: "Series Movie")
        try await db.markEpisodeWatched(mediaId: "series-1", episodeId: "ep-1", title: "Pilot")
        try await db.markEpisodeWatched(mediaId: "series-1", episodeId: "ep-2", title: "Second")

        try await db.markSeriesUnwatched(mediaId: "series-1")

        let movieLevel = try await db.fetchWatchHistory(mediaId: "series-1")
        #expect(movieLevel?.isCompleted == true)

        let ep1 = try await db.fetchWatchHistory(mediaId: "series-1", episodeId: "ep-1")
        #expect(ep1 == nil)
    }

    @Test func fetchEpisodeWatchStates() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "wh-ep-states.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await db.markEpisodeWatched(mediaId: "series-1", episodeId: "ep-1", title: "Pilot")
        try await db.markEpisodeWatched(mediaId: "series-1", episodeId: "ep-2", title: "Second")

        let states = try await db.fetchEpisodeWatchStates(mediaId: "series-1")
        #expect(states.count == 2)
        #expect(states["ep-1"]?.isCompleted == true)
        #expect(states["ep-2"]?.isCompleted == true)
    }

    @Test func saveWatchHistorySanitizesStreamURL() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "wh-sanitize.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let wh = WatchHistory(
            id: "wh-1", mediaId: "m1", title: "T",
            progress: 0, duration: 100, streamURL: "https://example.com/secret.m3u8",
            watchedAt: Date(), isCompleted: true
        )
        try await db.saveWatchHistory(wh)
        let fetched = try #require(try await db.fetchWatchHistory(mediaId: "m1"))
        #expect(fetched.streamURL == nil)
    }
}

// MARK: - UserLibraryEntry CRUD & Query Tests

@Suite(.serialized)
struct DatabaseManagerLibraryTests {

    @Test func addAndFetchLibraryEntry() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-crud.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let entry = UserLibraryEntry(
            id: "le-1", mediaId: "m1", folderId: "system-watchlist",
            listType: .watchlist, addedAt: Date()
        )
        try await db.addToLibrary(entry)
        let fetched = try await db.fetchLibraryEntries(listType: .watchlist)
        #expect(fetched.count == 1)
        #expect(fetched.first?.mediaId == "m1")
    }

    @Test func removeFromLibrary() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-remove.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let entry = UserLibraryEntry(id: "le-1", mediaId: "m1", folderId: "system-watchlist", listType: .watchlist, addedAt: Date())
        try await db.addToLibrary(entry)
        try await db.removeFromLibrary(mediaId: "m1", listType: .watchlist)
        let fetched = try await db.fetchLibraryEntries(listType: .watchlist)
        #expect(fetched.isEmpty)
    }

    @Test func isInLibrary() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-isin.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let entry = UserLibraryEntry(id: "le-1", mediaId: "m1", folderId: "system-favorites", listType: .favorites, addedAt: Date())
        try await db.addToLibrary(entry)
        #expect(try await db.isInLibrary(mediaId: "m1", listType: .favorites) == true)
        #expect(try await db.isInLibrary(mediaId: "m1", listType: .watchlist) == false)
    }

    @Test func fetchLibraryEntriesSortedByDateAddedDesc() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-sort-date.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let d1 = Date(timeIntervalSince1970: 1_000)
        let d2 = Date(timeIntervalSince1970: 2_000)
        let e1 = UserLibraryEntry(id: "le-1", mediaId: "m1", folderId: "system-favorites", listType: .favorites, addedAt: d1)
        let e2 = UserLibraryEntry(id: "le-2", mediaId: "m2", folderId: "system-favorites", listType: .favorites, addedAt: d2)
        try await db.addToLibrary(e1)
        try await db.addToLibrary(e2)

        let results = try await db.fetchLibraryEntries(listType: .favorites, folderId: nil, sortOption: .dateAddedDesc)
        #expect(results.map(\.mediaId) == ["m2", "m1"])
    }

    @Test func fetchLibraryEntriesSortedByDateAddedAsc() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-sort-date-asc.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let d1 = Date(timeIntervalSince1970: 1_000)
        let d2 = Date(timeIntervalSince1970: 2_000)
        try await db.addToLibrary(UserLibraryEntry(id: "le-1", mediaId: "m1", folderId: "system-favorites", listType: .favorites, addedAt: d1))
        try await db.addToLibrary(UserLibraryEntry(id: "le-2", mediaId: "m2", folderId: "system-favorites", listType: .favorites, addedAt: d2))

        let results = try await db.fetchLibraryEntries(listType: .favorites, folderId: nil, sortOption: .dateAddedAsc)
        #expect(results.map(\.mediaId) == ["m1", "m2"])
    }

    @Test func fetchLibraryEntriesFilteredByFolder() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-folder.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let folder = try await db.createLibraryFolder(name: "Custom", listType: .watchlist)
        let rootEntry = UserLibraryEntry(id: "le-1", mediaId: "m1", folderId: "system-watchlist", listType: .watchlist, addedAt: Date())
        let folderEntry = UserLibraryEntry(id: "le-2", mediaId: "m2", folderId: folder.id, listType: .watchlist, addedAt: Date())
        try await db.addToLibrary(rootEntry)
        try await db.addToLibrary(folderEntry)

        let rootResults = try await db.fetchLibraryEntries(listType: .watchlist, folderId: "system-watchlist")
        #expect(rootResults.count == 1)
        #expect(rootResults.first?.mediaId == "m1")

        let folderResults = try await db.fetchLibraryEntries(listType: .watchlist, folderId: folder.id)
        #expect(folderResults.count == 1)
        #expect(folderResults.first?.mediaId == "m2")
    }

    @Test func createLibraryFolderAndDelete() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-folder-crud.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let folder = try await db.createLibraryFolder(name: "Action", listType: .watchlist)
        #expect(folder.name == "Action")

        try await db.deleteLibraryFolder(id: folder.id, listType: .watchlist)
        let folders = try await db.fetchAllLibraryFolders(listType: .watchlist)
        #expect(folders.contains(where: { $0.id == folder.id }) == false)
    }

    @Test func createLibraryFolderMergesDuplicatesCaseInsensitively() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-folder-dedup.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let f1 = try await db.createLibraryFolder(name: "Horror", listType: .favorites)
        let f2 = try await db.createLibraryFolder(name: "horror", listType: .favorites)
        #expect(f1.id == f2.id)
    }

    @Test func pruneEmptyManualFolders() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-prune.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let folder = try await db.createLibraryFolder(name: "Empty", listType: .watchlist)
        let deleted = try await db.pruneEmptyManualFolders()
        #expect(deleted == 1)

        let folders = try await db.fetchAllLibraryFolders(listType: .watchlist)
        #expect(folders.contains(where: { $0.id == folder.id }) == false)
    }

    @Test func reorderLibraryFolders() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-reorder.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let f1 = try await db.createLibraryFolder(name: "A", listType: .favorites)
        let f2 = try await db.createLibraryFolder(name: "B", listType: .favorites)
        try await db.reorderLibraryFolders(ids: [f2.id, f1.id], listType: .favorites)

        let folders = try await db.fetchAllLibraryFolders(listType: .favorites)
        let manual = folders.filter { !$0.isSystem }
        #expect(manual.map(\.id) == [f2.id, f1.id])
    }

    @Test func moveLibraryEntryBetweenFolders() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "lib-move.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let folder = try await db.createLibraryFolder(name: "Target", listType: .watchlist)
        let entry = UserLibraryEntry(id: "le-1", mediaId: "m1", folderId: "system-watchlist", listType: .watchlist, addedAt: Date())
        try await db.addToLibrary(entry)
        try await db.moveLibraryEntry(mediaId: "m1", listType: .watchlist, toFolderId: folder.id)

        let results = try await db.fetchLibraryEntries(listType: .watchlist, folderId: folder.id)
        #expect(results.count == 1)
        #expect(results.first?.mediaId == "m1")
    }
}

// MARK: - DownloadTask CRUD & Update Tests

@Suite(.serialized)
struct DatabaseManagerDownloadTaskTests {

    @Test func saveAndFetchDownloadTask() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "dl-crud.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(id: "dl-1", mediaId: "m1", streamURL: "https://x.com/a.mkv", fileName: "a.mkv", status: .queued)
        try await db.saveDownloadTask(task)
        let fetched = try #require(try await db.fetchDownloadTask(id: "dl-1"))
        #expect(fetched.status == .queued)
        #expect(fetched.fileName == "a.mkv")
    }

    @Test func fetchDownloadTasksOrderedByUpdatedAtDesc() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "dl-order.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let t1 = DownloadTask(id: "dl-1", mediaId: "m1", streamURL: "https://x.com/1.mkv", fileName: "1.mkv", status: .queued, createdAt: Date(), updatedAt: Date().addingTimeInterval(-100))
        let t2 = DownloadTask(id: "dl-2", mediaId: "m2", streamURL: "https://x.com/2.mkv", fileName: "2.mkv", status: .queued, createdAt: Date(), updatedAt: Date())
        try await db.saveDownloadTask(t1)
        try await db.saveDownloadTask(t2)

        let results = try await db.fetchDownloadTasks()
        #expect(results.map(\.id) == ["dl-2", "dl-1"])
    }

    @Test func updateDownloadTaskStatus() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "dl-status.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(id: "dl-1", mediaId: "m1", streamURL: "https://x.com/a.mkv", fileName: "a.mkv")
        try await db.saveDownloadTask(task)
        try await db.updateDownloadTaskStatus(id: "dl-1", status: .downloading)
        #expect(try await db.fetchDownloadTask(id: "dl-1")?.status == .downloading)
    }

    @Test func updateDownloadTaskProgress() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "dl-progress.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(id: "dl-1", mediaId: "m1", streamURL: "https://x.com/a.mkv", fileName: "a.mkv")
        try await db.saveDownloadTask(task)
        try await db.updateDownloadTaskProgress(id: "dl-1", progress: 0.75, bytesWritten: 750, totalBytes: 1_000)
        let updated = try #require(try await db.fetchDownloadTask(id: "dl-1"))
        #expect(abs(updated.progress - 0.75) < 0.001)
        #expect(updated.bytesWritten == 750)
        #expect(updated.totalBytes == 1_000)
    }

    @Test func completingTaskClearsStreamURLAndResumeData() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "dl-complete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(
            id: "dl-1", mediaId: "m1",
            streamURL: "https://x.com/a.mkv", fileName: "a.mkv",
            status: .downloading, progress: 0.5,
            resumeDataBase64: Data("resume".utf8).base64EncodedString()
        )
        try await db.saveDownloadTask(task)
        try await db.updateDownloadTaskStatus(id: "dl-1", status: .completed)
        let updated = try #require(try await db.fetchDownloadTask(id: "dl-1"))
        #expect(updated.status == .completed)
        #expect(updated.progress == 1)
        #expect(updated.persistedStreamURL == nil)
        #expect(updated.resumeDataBase64 == nil)
    }

    @Test func updateDownloadTaskStreamURL() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "dl-stream.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(id: "dl-1", mediaId: "m1", streamURL: "https://old.com/a.mkv", fileName: "a.mkv", status: .queued)
        try await db.saveDownloadTask(task)
        try await db.updateDownloadTaskStreamURL(id: "dl-1", streamURL: "https://new.com/b.mkv")
        let updated = try #require(try await db.fetchDownloadTask(id: "dl-1"))
        #expect(updated.streamURL == "https://new.com/b.mkv")
    }

    @Test func clearDownloadTaskReplayableTransportState() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "dl-clear-transport.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(
            id: "dl-1", mediaId: "m1",
            streamURL: "https://x.com/a.mkv", fileName: "a.mkv",
            status: .downloading, resumeDataBase64: Data("resume".utf8).base64EncodedString()
        )
        try await db.saveDownloadTask(task)
        try await db.clearDownloadTaskReplayableTransportState(id: "dl-1")
        let updated = try #require(try await db.fetchDownloadTask(id: "dl-1"))
        #expect(updated.persistedStreamURL == nil)
        #expect(updated.resumeDataBase64 == nil)
    }

    @Test func deleteDownloadTask() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "dl-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(id: "dl-1", mediaId: "m1", streamURL: "https://x.com/a.mkv", fileName: "a.mkv")
        try await db.saveDownloadTask(task)
        try await db.deleteDownloadTask(id: "dl-1")
        #expect(try await db.fetchDownloadTask(id: "dl-1") == nil)
    }
}

// MARK: - Retention Sweep Tests

@Suite(.serialized)
struct DatabaseManagerRetentionTests {

    @Test func runRetentionSweepIfNeededRespectsInterval() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "retention-interval.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let now = Date()
        let old = WatchHistory(id: "wh-old", mediaId: "m1", title: "Old", progress: 100, duration: 100, watchedAt: now.addingTimeInterval(-400 * 24 * 60 * 60), isCompleted: true)
        try await db.saveWatchHistory(old)

        let deleted1 = try await db.runRetentionSweepIfNeeded(interval: 3600, maxEntries: 10, ttl: 365 * 24 * 60 * 60)
        #expect(deleted1 >= 0)

        let deleted2 = try await db.runRetentionSweepIfNeeded(interval: 3600, maxEntries: 10, ttl: 365 * 24 * 60 * 60)
        #expect(deleted2 == 0) // interval not elapsed
    }

    @Test func applyWatchHistoryRetentionPolicyDeletesStaleCompletedEntries() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "retention-policy.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let day: TimeInterval = 24 * 60 * 60
        let old = WatchHistory(id: "wh-old", mediaId: "m1", title: "Old", progress: 100, duration: 100, watchedAt: now.addingTimeInterval(-10 * day), isCompleted: true)
        let fresh = WatchHistory(id: "wh-fresh", mediaId: "m2", title: "Fresh", progress: 100, duration: 100, watchedAt: now.addingTimeInterval(-1 * day), isCompleted: true)
        let resume = WatchHistory(id: "wh-resume", mediaId: "m3", title: "Resume", progress: 50, duration: 100, watchedAt: now.addingTimeInterval(-10 * day), isCompleted: false)
        try await db.saveWatchHistory(old)
        try await db.saveWatchHistory(fresh)
        try await db.saveWatchHistory(resume)

        let deleted = try await db.applyWatchHistoryRetentionPolicy(maxEntries: 10, ttl: 5 * day, now: now)
        #expect(deleted == 1)

        let remaining = try await db.fetchWatchHistory(limit: 10)
        #expect(remaining.map(\.id).sorted() == ["wh-fresh", "wh-resume"])
    }
}

// MARK: - Settings Tests

@Suite(.serialized)
struct DatabaseManagerSettingsTests {

    @Test func setAndGetSetting() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "settings.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await db.setSetting(key: "theme", value: "dark")
        let value = try await db.getSetting(key: "theme")
        #expect(value == "dark")
    }

    @Test func getMissingSettingReturnsNil() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "settings-miss.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let value = try await db.getSetting(key: "missing")
        #expect(value == nil)
    }

    @Test func setSettingToNilDeletesIt() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "settings-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await db.setSetting(key: "temp", value: "value")
        try await db.setSetting(key: "temp", value: nil)
        let value = try await db.getSetting(key: "temp")
        #expect(value == nil)
    }
}

// MARK: - Environment Asset Tests

@Suite(.serialized)
struct DatabaseManagerEnvironmentAssetTests {

    @Test func saveAndFetchEnvironmentAssets() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "env-assets.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let asset = EnvironmentAsset(id: "env-1", name: "Space", sourceType: .bundled, assetPath: "/space.hdr")
        try await db.saveEnvironmentAsset(asset)
        let fetched = try await db.fetchEnvironmentAssets()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Space")
    }

    @Test func setActiveEnvironmentAsset() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "env-active.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let a1 = EnvironmentAsset(id: "env-1", name: "A", sourceType: .bundled, assetPath: "/a.hdr")
        let a2 = EnvironmentAsset(id: "env-2", name: "B", sourceType: .bundled, assetPath: "/b.hdr")
        try await db.saveEnvironmentAsset(a1)
        try await db.saveEnvironmentAsset(a2)
        try await db.setActiveEnvironmentAsset(id: "env-2")

        let active = try await db.fetchActiveEnvironmentAsset()
        #expect(active?.id == "env-2")
    }

    @Test func deleteEnvironmentAsset() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "env-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let asset = EnvironmentAsset(id: "env-1", name: "Space", sourceType: .bundled, assetPath: "/space.hdr")
        try await db.saveEnvironmentAsset(asset)
        try await db.deleteEnvironmentAsset(id: "env-1")
        #expect(try await db.fetchEnvironmentAssets().isEmpty)
    }
}

// MARK: - Debrid & Indexer Config Tests

@Suite(.serialized)
struct DatabaseManagerConfigTests {

    @Test func saveAndFetchDebridConfigs() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "debrid.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = DebridConfig(serviceType: .realDebrid, apiTokenRef: "token", priority: 1)
        try await db.saveDebridConfig(config)
        let fetched = try await db.fetchDebridConfigs()
        #expect(fetched.count == 1)
        #expect(fetched.first?.serviceType == .realDebrid)
    }

    @Test func deleteDebridConfig() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "debrid-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = DebridConfig(serviceType: .realDebrid, apiTokenRef: "token")
        try await db.saveDebridConfig(config)
        try await db.deleteDebridConfig(id: config.id)
        #expect(try await db.fetchDebridConfigs().isEmpty)
    }

    @Test func saveAndFetchIndexerConfigs() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "indexer.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = IndexerConfig(name: "YTS", indexerType: .yts, priority: 0)
        try await db.saveIndexerConfig(config)
        let fetched = try await db.fetchIndexerConfigs()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "YTS")
    }

    @Test func saveMultipleIndexerConfigs() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "indexer-multi.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configs = [
            IndexerConfig(name: "A", indexerType: .yts, priority: 0),
            IndexerConfig(name: "B", indexerType: .eztv, priority: 1),
        ]
        try await db.saveIndexerConfigs(configs)
        let fetched = try await db.fetchAllIndexerConfigs()
        #expect(fetched.count == 2)
    }

    @Test func deleteIndexerConfig() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "indexer-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = IndexerConfig(name: "YTS", indexerType: .yts)
        try await db.saveIndexerConfig(config)
        try await db.deleteIndexerConfig(id: config.id)
        #expect(try await db.fetchIndexerConfigs().isEmpty)
    }
}

// MARK: - AI Usage & Context Snapshot Tests

@Suite(.serialized)
struct DatabaseManagerAITests {

    @Test func saveAndFetchAIUsageRecords() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "ai-usage.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let record = AIUsageRecord(provider: .openAI, model: "gpt-4", inputTokens: 100, outputTokens: 50, estimatedCostUSD: 0.01, requestType: .ask)
        try await db.saveAIUsageRecord(record)
        let fetched = try await db.fetchAIUsageRecords()
        #expect(fetched.count == 1)
        #expect(fetched.first?.provider == "openai")
    }

    @Test func fetchAIUsageSummary() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "ai-summary.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let r1 = AIUsageRecord(provider: .openAI, model: "gpt-4", inputTokens: 100, outputTokens: 50, estimatedCostUSD: 0.01, requestType: .ask)
        let r2 = AIUsageRecord(provider: .anthropic, model: "claude", inputTokens: 200, outputTokens: 100, estimatedCostUSD: 0.02, requestType: .recommendation)
        try await db.saveAIUsageRecord(r1)
        try await db.saveAIUsageRecord(r2)

        let summary = try await db.fetchAIUsageSummary()
        #expect(summary.requestCount == 2)
        #expect(summary.totalInputTokens == 300)
        #expect(summary.totalOutputTokens == 150)
        #expect(summary.byProvider[.openAI]?.requestCount == 1)
        #expect(summary.byProvider[.anthropic]?.requestCount == 1)
    }

    @Test func saveAndFetchContextSnapshot() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "ai-context.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshot = AIContextSnapshot(id: "latest", snapshotJSON: "{}")
        try await db.saveContextSnapshot(snapshot)
        let fetched = try await db.fetchLatestContextSnapshot()
        #expect(fetched?.snapshotJSON == "{}")
    }

    @Test func deleteContextSnapshots() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "ai-context-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await db.saveContextSnapshot(AIContextSnapshot(snapshotJSON: "{}"))
        try await db.deleteContextSnapshots()
        #expect(try await db.fetchLatestContextSnapshot() == nil)
    }
}

// MARK: - Taste Events & Profile Tests

@Suite(.serialized)
struct DatabaseManagerTasteTests {

    @Test func saveAndFetchUserTasteProfile() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "taste-profile.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let profile = UserTasteProfile(id: "default", likedGenres: ["Sci-Fi"], dislikedGenres: ["Horror"], eventCount: 5)
        try await db.saveUserTasteProfile(profile)
        let fetched = try await db.fetchUserTasteProfile()
        #expect(fetched?.likedGenres == ["Sci-Fi"])
        #expect(fetched?.dislikedGenres == ["Horror"])
    }

    @Test func saveAndFetchTasteEvents() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "taste-events.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let event = TasteEvent(userId: "default", mediaId: "m1", eventType: .watched, createdAt: Date())
        try await db.saveTasteEvent(event)
        let fetched = try await db.fetchTasteEvents(limit: 10)
        #expect(fetched.count == 1)
        #expect(fetched.first?.eventType == .watched)
    }

    @Test func fetchTasteEventsByType() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "taste-filter.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let e1 = TasteEvent(userId: "default", mediaId: "m1", eventType: .watched, createdAt: Date())
        let e2 = TasteEvent(userId: "default", mediaId: "m2", eventType: .rated, createdAt: Date())
        try await db.saveTasteEvent(e1)
        try await db.saveTasteEvent(e2)

        let rated = try await db.fetchTasteEvents(eventType: .rated, limit: 10)
        #expect(rated.count == 1)
        #expect(rated.first?.eventType == .rated)
    }

    @Test func fetchLatestTasteRating() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "taste-rating.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let older = TasteEvent(userId: "default", mediaId: "m1", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 7, createdAt: Date().addingTimeInterval(-100))
        let newer = TasteEvent(userId: "default", mediaId: "m1", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 9, createdAt: Date())
        try await db.saveTasteEvent(older)
        try await db.saveTasteEvent(newer)

        let latest = try await db.fetchLatestTasteRating(mediaId: "m1")
        #expect(latest?.feedbackValue == 9)
    }

    @Test func deleteLatestTasteRating() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "taste-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let event = TasteEvent(userId: "default", mediaId: "m1", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 8, createdAt: Date())
        try await db.saveTasteEvent(event)
        try await db.deleteLatestTasteRating(mediaId: "m1")
        #expect(try await db.fetchLatestTasteRating(mediaId: "m1") == nil)
    }
}

// MARK: - Trakt List Mapping Tests

@Suite(.serialized)
struct DatabaseManagerTraktTests {

    @Test func saveAndFetchTraktListMapping() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "trakt.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mapping = TraktListMapping(traktListId: 123, localFolderId: "folder-1", listType: .watchlist)
        try await db.saveTraktListMapping(mapping)
        let fetched = try await db.fetchTraktListMapping(traktListId: 123)
        #expect(fetched?.localFolderId == "folder-1")
    }

    @Test func fetchTraktListMappingByLocalFolderId() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "trakt-folder.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mapping = TraktListMapping(traktListId: 456, localFolderId: "folder-abc", listType: .favorites)
        try await db.saveTraktListMapping(mapping)
        let fetched = try await db.fetchTraktListMapping(localFolderId: "folder-abc")
        #expect(fetched?.traktListId == 456)
    }

    @Test func deleteTraktListMapping() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "trakt-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mapping = TraktListMapping(traktListId: 789, localFolderId: "folder-x", listType: .watchlist)
        try await db.saveTraktListMapping(mapping)
        try await db.deleteTraktListMapping(traktListId: 789)
        #expect(try await db.fetchTraktListMapping(traktListId: 789) == nil)
    }
}

// MARK: - Local Model Tests

@Suite(.serialized)
struct DatabaseManagerLocalModelTests {

    @Test func saveAndFetchLocalModel() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "local-model.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = LocalModelDescriptor(
            id: "model-1", displayName: "Test", huggingFaceRepo: "repo",
            revision: "main", parameterCount: "4B", quantization: "4bit",
            diskSizeMB: 1000, minMemoryMB: 8000, expectedFileCount: 3,
            maxContextTokens: 4096, effectivePromptCap: 2048, effectiveOutputCap: 512,
            status: .available, downloadProgress: 0, downloadedBytes: 0, totalBytes: 0,
            validationState: .pending, isDefault: false, createdAt: Date(), updatedAt: Date()
        )
        try await db.saveLocalModel(model)
        let fetched = try await db.fetchLocalModel(id: "model-1")
        #expect(fetched?.displayName == "Test")
    }

    @Test func deleteLocalModel() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "local-model-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = LocalModelDescriptor(
            id: "model-1", displayName: "Test", huggingFaceRepo: "repo",
            revision: "main", parameterCount: "4B", quantization: "4bit",
            diskSizeMB: 1000, minMemoryMB: 8000, expectedFileCount: 3,
            maxContextTokens: 4096, effectivePromptCap: 2048, effectiveOutputCap: 512,
            status: .available, downloadProgress: 0, downloadedBytes: 0, totalBytes: 0,
            validationState: .pending, isDefault: false, createdAt: Date(), updatedAt: Date()
        )
        try await db.saveLocalModel(model)
        try await db.deleteLocalModel(id: "model-1")
        #expect(try await db.fetchLocalModel(id: "model-1") == nil)
    }
}

// MARK: - Transaction & Reset Tests

@Suite(.serialized)
struct DatabaseManagerTransactionTests {

    @Test func writeInTransactionCommits() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "tx-commit.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = try await db.writeInTransaction { database in
            try database.execute(
                sql: "INSERT INTO media_cache (id, type, title) VALUES (?, ?, ?)",
                arguments: ["tx-item", "movie", "Tx Item"]
            )
            return 42
        }
        #expect(result == 42)
        let fetched = try await db.fetchMediaItem(id: "tx-item")
        #expect(fetched?.title == "Tx Item")
    }

    @Test func resetAllDataClearsAllTables() async throws {
        let (db, tempDir) = try await makeTemporaryDatabase(named: "reset.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await db.saveMediaItem(MediaItem(id: "m1", type: .movie, title: "A"))
        try await db.saveWatchHistory(WatchHistory(id: "wh-1", mediaId: "m1", title: "A", progress: 0, duration: 100, watchedAt: Date(), isCompleted: true))
        try await db.setSetting(key: "k", value: "v")

        try await db.resetAllData()

        #expect(try await db.fetchMediaItem(id: "m1") == nil)
        #expect(try await db.fetchWatchHistory(limit: 10).isEmpty)
        #expect(try await db.getSetting(key: "k") == nil)
    }
}
