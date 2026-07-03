import Testing
import Foundation
import GRDB
@testable import VPStudio

@Suite("UserLibraryEntry ListType")
struct UserLibraryEntryListTypeTests {
    @Test("Library top tabs are correct")
    func libraryTopTabs() {
        let expectedTabs = [UserLibraryEntry.ListType.watchlist, .favorites, .history]
        #expect(UserLibraryEntry.ListType.libraryTopTabs == expectedTabs)
    }

    @Test("ListType from stored value")
    func fromStoredValue() {
        #expect(UserLibraryEntry.ListType.fromStoredValue("watchlist") == .watchlist)
        #expect(UserLibraryEntry.ListType.fromStoredValue("favorites") == .favorites)
        #expect(UserLibraryEntry.ListType.fromStoredValue("history") == .history)
        #expect(UserLibraryEntry.ListType.fromStoredValue("custom") == .favorites)
        #expect(UserLibraryEntry.ListType.fromStoredValue("unknown") == .favorites)
        #expect(UserLibraryEntry.ListType.fromStoredValue(nil) == .favorites)
    }

    @Test("Display names are correct")
    func displayNames() {
        #expect(UserLibraryEntry.ListType.watchlist.displayName == "Watchlist")
        #expect(UserLibraryEntry.ListType.favorites.displayName == "Favorites")
        #expect(UserLibraryEntry.ListType.history.displayName == "History")
    }

    @Test("Description matches display name")
    func descriptionMatches() {
        #expect(UserLibraryEntry.ListType.watchlist.description == "Watchlist")
        #expect(UserLibraryEntry.ListType.favorites.description == "Favorites")
        #expect(UserLibraryEntry.ListType.history.description == "History")
    }

    @Test("Supports folders correctly")
    func supportsFolders() {
        #expect(UserLibraryEntry.ListType.watchlist.supportsFolders == true)
        #expect(UserLibraryEntry.ListType.favorites.supportsFolders == true)
        #expect(UserLibraryEntry.ListType.history.supportsFolders == false)
    }
}

@Suite("UserLibraryEntry Database Round-Trip")
struct UserLibraryEntryDatabaseRoundTripTests {
    private func makeTempDatabase() async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "user-library-test-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test func roundTripsThroughDatabaseManager() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let entry = UserLibraryEntry(
            id: "entry-1",
            mediaId: "movie-123",
            folderId: "system-watchlist",
            listType: .watchlist,
            addedAt: Date()
        )
        try await database.addToLibrary(entry)
        let fetched = try await database.fetchLibraryEntries(listType: .watchlist).first

        #expect(fetched != nil)
        #expect(fetched?.id == entry.id)
        #expect(fetched?.mediaId == entry.mediaId)
        #expect(fetched?.listType == entry.listType)
    }

    @Test
    func userLibraryEntryWithAllFieldsRoundTripsCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let entry = UserLibraryEntry(
            id: "full-entry",
            mediaId: "series-456",
            folderId: "system-favorites",
            listType: .favorites,
            addedAt: Date(),
            customListName: "Great show!"
        )
        try await database.addToLibrary(entry)
        let fetched = try await database.fetchLibraryEntries(listType: .favorites).first

        #expect(fetched != nil)
        #expect(fetched?.customListName == "Great show!")
    }

    @Test
    func userLibraryEntryWithUnknownListTypeDefaultsToFavorites() async throws {
        let entry = UserLibraryEntry(
            id: "unknown-type",
            mediaId: "movie-789",
            folderId: "system-favorites",
            listType: .favorites,
            addedAt: Date()
        )
        #expect(entry.listType == .favorites)
    }

    @Test
    func multipleUserLibraryEntriesRoundTripCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let entries = [
            UserLibraryEntry(id: "e1", mediaId: "m1", folderId: "system-watchlist", listType: .watchlist, addedAt: Date()),
            UserLibraryEntry(id: "e2", mediaId: "m2", folderId: "system-favorites", listType: .favorites, addedAt: Date()),
            UserLibraryEntry(id: "e3", mediaId: "m3", folderId: "system-history", listType: .history, addedAt: Date())
        ]

        for entry in entries {
            try await database.addToLibrary(entry)
        }

        let fetched = try await database.fetchLibraryEntries(listType: .watchlist)
        #expect(fetched.count >= 1)
    }

    @Test func userLibraryEntryCanBeRemovedFromLibrary() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let entry = UserLibraryEntry(id: "to-remove", mediaId: "movie-999", folderId: "system-watchlist", listType: .watchlist, addedAt: Date())
        try await database.addToLibrary(entry)
        try await database.removeFromLibrary(mediaId: "movie-999", listType: .watchlist)

        let fetched = try await database.fetchLibraryEntries(listType: .watchlist).first { $0.mediaId == "movie-999" }
        #expect(fetched == nil)
    }
}

@Suite("UserLibraryEntry Row Initialization")
struct UserLibraryEntryRowInitializationTests {
    @Test("Row initializer defaults unknown stored list type to favorites")
    func rowInitializerDefaultsUnknownStoredListTypeToFavorites() throws {
        let addedAt = Date(timeIntervalSince1970: 500)
        let row = Row([
            "id": "entry-row",
            "mediaId": "movie-1",
            "folderId": "folder-1",
            "listType": "legacy-custom",
            "addedAt": addedAt,
            "customListName": "Legacy",
            "releaseDateHint": "2026-06-11",
            "renewalStatus": "renewed",
        ])

        let entry = try UserLibraryEntry(row: row)

        #expect(entry.id == "entry-row")
        #expect(entry.mediaId == "movie-1")
        #expect(entry.folderId == "folder-1")
        #expect(entry.listType == .favorites)
        #expect(entry.addedAt == addedAt)
        #expect(entry.customListName == "Legacy")
        #expect(entry.releaseDateHint == "2026-06-11")
        #expect(entry.renewalStatus == "renewed")
    }
}

@Suite("LibraryFolder Properties")
struct LibraryFolderModelTests {
    @Test("System folder ID generation")
    func systemFolderID() {
        #expect(LibraryFolder.systemFolderID(for: .watchlist) == "system-watchlist")
        #expect(LibraryFolder.systemFolderID(for: .favorites) == "system-favorites")
        #expect(LibraryFolder.systemFolderID(for: .history) == "system-history")
    }

    @Test("System folder names")
    func systemFolderNames() {
        #expect(LibraryFolder.systemFolderName(for: .watchlist) == "Watchlist")
        #expect(LibraryFolder.systemFolderName(for: .favorites) == "Favorites")
        #expect(LibraryFolder.systemFolderName(for: .history) == "History")
    }

    @Test("Watched folder ID constant")
    func watchedFolderID() {
        #expect(LibraryFolder.watchedFolderID == "system-favorites-watched")
    }

    @Test("Release wait folder ID constant")
    func releaseWaitFolderID() {
        #expect(LibraryFolder.releaseWaitFolderID == "system-favorites-release-wait")
    }
}

@Suite("LibraryFolder GRDB Row Init")
struct LibraryFolderModelGRDBTests {
    @Test("LibraryFolder initializes from GRDB row")
    func rowInitialization() throws {
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let row = Row([
            "id": "folder-row",
            "name": "Sci-Fi",
            "parentId": LibraryFolder.systemFolderID(for: .watchlist),
            "listType": UserLibraryEntry.ListType.watchlist.rawValue,
            "folderKind": LibraryFolder.FolderKind.releaseWait.rawValue,
            "isSystem": false,
            "sortOrder": 12,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
        ])

        let folder = try LibraryFolder(row: row)

        #expect(folder.id == "folder-row")
        #expect(folder.name == "Sci-Fi")
        #expect(folder.parentId == LibraryFolder.systemFolderID(for: .watchlist))
        #expect(folder.listType == .watchlist)
        #expect(folder.folderKind == .releaseWait)
        #expect(folder.isSystem == false)
        #expect(folder.sortOrder == 12)
        #expect(folder.createdAt == createdAt)
        #expect(folder.updatedAt == updatedAt)
    }

    @Test("Unknown folder kind defaults based on isSystem")
    func unknownFolderKind() throws {
        let createdAt = Date(timeIntervalSince1970: 100)
        let systemRow = Row([
            "id": "system-folder",
            "name": "Root",
            "parentId": nil,
            "listType": "unknown",
            "folderKind": "unknown",
            "isSystem": true,
            "sortOrder": nil,
            "createdAt": createdAt,
            "updatedAt": createdAt,
        ])
        let manualRow = Row([
            "id": "manual-folder",
            "name": "Loose",
            "parentId": nil,
            "listType": "unknown",
            "folderKind": "unknown",
            "isSystem": false,
            "sortOrder": nil,
            "createdAt": createdAt,
            "updatedAt": createdAt,
        ])

        let systemFolder = try LibraryFolder(row: systemRow)
        let manualFolder = try LibraryFolder(row: manualRow)

        #expect(systemFolder.listType == .favorites)
        #expect(systemFolder.folderKind == .systemRoot)
        #expect(systemFolder.sortOrder == 0)
        #expect(manualFolder.listType == .favorites)
        #expect(manualFolder.folderKind == .manual)
        #expect(manualFolder.sortOrder == 0)
    }

    @Test("Nil sort order defaults to 0")
    func nilSortOrder() throws {
        let createdAt = Date(timeIntervalSince1970: 100)
        let row = Row([
            "id": "nil-sort",
            "name": "No Sort",
            "parentId": nil,
            "listType": UserLibraryEntry.ListType.history.rawValue,
            "folderKind": nil,
            "isSystem": false,
            "sortOrder": nil,
            "createdAt": createdAt,
            "updatedAt": createdAt,
        ])

        let folder = try LibraryFolder(row: row)

        #expect(folder.listType == .history)
        #expect(folder.folderKind == .manual)
        #expect(folder.sortOrder == 0)
    }
}

@Suite("TraktListMapping GRDB Row Init")
struct TraktListMappingModelGRDBTests {
    @Test("TraktListMapping initializes from GRDB row")
    func rowInitialization() throws {
        let syncedAt = Date(timeIntervalSince1970: 800)
        let row = Row([
            "id": "mapping-row",
            "traktListId": 42,
            "traktListSlug": "watch-soon",
            "localFolderId": "folder-42",
            "listType": UserLibraryEntry.ListType.watchlist.rawValue,
            "lastSyncedAt": syncedAt,
        ])

        let mapping = try TraktListMapping(row: row)

        #expect(mapping.id == "mapping-row")
        #expect(mapping.traktListId == 42)
        #expect(mapping.traktListSlug == "watch-soon")
        #expect(mapping.localFolderId == "folder-42")
        #expect(mapping.listType == .watchlist)
        #expect(mapping.lastSyncedAt == syncedAt)
    }

    @Test("Unknown list type defaults to favorites")
    func unknownListType() throws {
        let syncedAt = Date(timeIntervalSince1970: 800)
        let row = Row([
            "id": "mapping-row",
            "traktListId": 42,
            "traktListSlug": nil,
            "localFolderId": "folder-42",
            "listType": "legacy-custom",
            "lastSyncedAt": syncedAt,
        ])

        let mapping = try TraktListMapping(row: row)

        #expect(mapping.traktListSlug == nil)
        #expect(mapping.listType == .favorites)
    }
}

@Suite("UserLibraryEntry Codable Round-Trip")
struct UserLibraryEntryModelCodableTests {
    @Test("UserLibraryEntry encodes and decodes correctly")
    func codableRoundTrip() throws {
        let originalEntry = UserLibraryEntry(
            id: "entry-123",
            mediaId: "media-456",
            folderId: "folder-789",
            listType: .watchlist,
            addedAt: Date(timeIntervalSince1970: 123456789),
            customListName: "Custom List",
            releaseDateHint: "2023-01-01",
            renewalStatus: "active"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEntry)
        let decoder = JSONDecoder()
        let decodedEntry = try decoder.decode(UserLibraryEntry.self, from: data)

        #expect(decodedEntry.id == originalEntry.id)
        #expect(decodedEntry.mediaId == originalEntry.mediaId)
        #expect(decodedEntry.folderId == originalEntry.folderId)
        #expect(decodedEntry.listType == originalEntry.listType)
        #expect(decodedEntry.addedAt == originalEntry.addedAt)
        #expect(decodedEntry.customListName == originalEntry.customListName)
        #expect(decodedEntry.releaseDateHint == originalEntry.releaseDateHint)
        #expect(decodedEntry.renewalStatus == originalEntry.renewalStatus)
    }

    @Test("UserLibraryEntry with minimal data encodes and decodes")
    func minimalCodableRoundTrip() throws {
        let originalEntry = UserLibraryEntry(
            id: "entry-123",
            mediaId: "media-456",
            folderId: "folder-789",
            listType: .favorites,
            addedAt: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEntry)
        let decoder = JSONDecoder()
        let decodedEntry = try decoder.decode(UserLibraryEntry.self, from: data)

        #expect(decodedEntry.id == originalEntry.id)
        #expect(decodedEntry.mediaId == originalEntry.mediaId)
        #expect(decodedEntry.folderId == originalEntry.folderId)
        #expect(decodedEntry.listType == originalEntry.listType)
    }
}
