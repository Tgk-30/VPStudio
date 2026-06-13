import Testing
import Foundation
@testable import VPStudio

@Suite("UserLibraryEntry ListType Codable Round-Trip")
struct UserLibraryEntryListTypeCodableTests {
    @Test("ListType all cases encode and decode correctly")
    func listTypeAllCasesCodableRoundTrip() throws {
        let cases: [UserLibraryEntry.ListType] = [.watchlist, .favorites, .history]

        for listType in cases {
            let encoded = try JSONEncoder().encode(listType)
            let decoded = try JSONDecoder().decode(UserLibraryEntry.ListType.self, from: encoded)
            #expect(decoded == listType)
        }
    }

    @Test("ListType libraryTopTabs is correct order")
    func listTypeLibraryTopTabsOrder() {
        let expected = [UserLibraryEntry.ListType.watchlist, .favorites, .history]
        #expect(UserLibraryEntry.ListType.libraryTopTabs == expected)
    }

    @Test("ListType supportsFolders behavior")
    func listTypeSupportsFoldersBehavior() {
        #expect(UserLibraryEntry.ListType.watchlist.supportsFolders == true)
        #expect(UserLibraryEntry.ListType.favorites.supportsFolders == true)
        #expect(UserLibraryEntry.ListType.history.supportsFolders == false)
    }

    @Test("ListType fromStoredValue handles all cases including legacy")
    func listTypeFromStoredValueAllCases() {
        #expect(UserLibraryEntry.ListType.fromStoredValue("watchlist") == .watchlist)
        #expect(UserLibraryEntry.ListType.fromStoredValue("favorites") == .favorites)
        #expect(UserLibraryEntry.ListType.fromStoredValue("history") == .history)
        #expect(UserLibraryEntry.ListType.fromStoredValue("custom") == .favorites)
        #expect(UserLibraryEntry.ListType.fromStoredValue(nil) == .favorites)
        #expect(UserLibraryEntry.ListType.fromStoredValue("invalid") == .favorites)
    }
}

@Suite("LibraryFolder Codable Round-Trip")
struct LibraryFolderCodableTests {
    @Test("LibraryFolder encodes and decodes correctly")
    func libraryFolderCodableRoundTrip() throws {
        let original = LibraryFolder(
            id: "folder-123",
            name: "My Folder",
            parentId: "parent-456",
            listType: .favorites,
            folderKind: .manual,
            isSystem: false,
            sortOrder: 1,
            createdAt: Date(timeIntervalSince1970: 123456789),
            updatedAt: Date(timeIntervalSince1970: 123456790)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LibraryFolder.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.parentId == original.parentId)
        #expect(decoded.listType == original.listType)
        #expect(decoded.folderKind == original.folderKind)
        #expect(decoded.isSystem == original.isSystem)
        #expect(decoded.sortOrder == original.sortOrder)
        #expect(decoded.createdAt == original.createdAt)
        #expect(decoded.updatedAt == original.updatedAt)
    }

    @Test("LibraryFolder with nil parentId encodes and decodes correctly")
    func libraryFolderNilParentIdCodableRoundTrip() throws {
        let original = LibraryFolder(
            id: "root-folder",
            name: "Root",
            parentId: nil,
            listType: .watchlist,
            folderKind: .systemRoot,
            isSystem: true,
            sortOrder: 0
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LibraryFolder.self, from: encoded)

        #expect(decoded.parentId == nil)
        #expect(decoded.isSystem == true)
    }

    @Test("LibraryFolder FolderKind all cases encode and decode correctly")
    func libraryFolderKindAllCasesCodableRoundTrip() throws {
        let kinds: [LibraryFolder.FolderKind] = [.systemRoot, .manual, .watched, .releaseWait]

        for kind in kinds {
            let encoded = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(LibraryFolder.FolderKind.self, from: encoded)
            #expect(decoded == kind)
        }
    }

    @Test("LibraryFolder systemFolderID generation")
    func libraryFolderSystemFolderIdGeneration() {
        #expect(LibraryFolder.systemFolderID(for: .watchlist) == "system-watchlist")
        #expect(LibraryFolder.systemFolderID(for: .favorites) == "system-favorites")
        #expect(LibraryFolder.systemFolderID(for: .history) == "system-history")
    }

    @Test("LibraryFolder static constants")
    func libraryFolderStaticConstants() {
        #expect(LibraryFolder.watchedFolderID == "system-favorites-watched")
        #expect(LibraryFolder.releaseWaitFolderID == "system-favorites-release-wait")
    }

    @Test("LibraryFolder systemFolderName for each list type")
    func libraryFolderSystemFolderNameForEachListType() {
        #expect(LibraryFolder.systemFolderName(for: .watchlist) == "Watchlist")
        #expect(LibraryFolder.systemFolderName(for: .favorites) == "Favorites")
        #expect(LibraryFolder.systemFolderName(for: .history) == "History")
    }
}

@Suite("TraktListMapping Codable Round-Trip")
struct TraktListMappingCodableTests {
    @Test("TraktListMapping encodes and decodes correctly")
    func traktListMappingCodableRoundTrip() throws {
        let original = TraktListMapping(
            id: "mapping-123",
            traktListId: 456,
            traktListSlug: "my-list",
            localFolderId: "folder-789",
            listType: .watchlist,
            lastSyncedAt: Date(timeIntervalSince1970: 123456789)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TraktListMapping.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.traktListId == original.traktListId)
        #expect(decoded.traktListSlug == original.traktListSlug)
        #expect(decoded.localFolderId == original.localFolderId)
        #expect(decoded.listType == original.listType)
        #expect(decoded.lastSyncedAt == original.lastSyncedAt)
    }

    @Test("TraktListMapping with nil slug encodes and decodes correctly")
    func traktListMappingNilSlugCodableRoundTrip() throws {
        let original = TraktListMapping(
            id: "mapping-no-slug",
            traktListId: 123,
            traktListSlug: nil,
            localFolderId: "folder-456",
            listType: .favorites
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TraktListMapping.self, from: encoded)

        #expect(decoded.traktListSlug == nil)
    }

    @Test("TraktListMapping all list types encode and decode correctly")
    func traktListMappingAllListTypes() throws {
        let listTypes: [UserLibraryEntry.ListType] = [.watchlist, .favorites, .history]

        for listType in listTypes {
            let mapping = TraktListMapping(
                id: "mapping-\(listType.rawValue)",
                traktListId: 1,
                localFolderId: "folder",
                listType: listType
            )

            let encoded = try JSONEncoder().encode(mapping)
            let decoded = try JSONDecoder().decode(TraktListMapping.self, from: encoded)

            #expect(decoded.listType == listType)
        }
    }
}
