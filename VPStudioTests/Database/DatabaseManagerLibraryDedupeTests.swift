import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct DatabaseManagerLibraryDedupeTests {
    @Test
    func dedupePrefersHigherLatestUserRatingBeforeIMDbAndAddedAt() async throws {
        let db = try await makeDatabase(named: "dedupe-rating-priority")

        try await db.saveMediaItem(MediaItem(id: "m-a", type: .movie, title: "The Matrix", imdbRating: 9.8))
        try await db.saveMediaItem(MediaItem(id: "m-b", type: .movie, title: "The Matrix", imdbRating: 6.0))

        let now = Date()
        try await db.addToLibrary(UserLibraryEntry(id: "e-a", mediaId: "m-a", folderId: "", listType: .favorites, addedAt: now))
        try await db.addToLibrary(UserLibraryEntry(id: "e-b", mediaId: "m-b", folderId: "", listType: .favorites, addedAt: now.addingTimeInterval(10)))

        try await db.saveTasteEvent(TasteEvent(id: "r-a", mediaId: "m-a", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 4, createdAt: now))
        try await db.saveTasteEvent(TasteEvent(id: "r-b", mediaId: "m-b", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 9, createdAt: now))

        let removed = try await db.dedupeLibraryEntriesByTitleEquivalence(listType: .favorites)
        #expect(removed == 1)

        let remaining = try await db.fetchLibraryEntries(listType: .favorites)
        #expect(remaining.count == 1)
        #expect(remaining.first?.mediaId == "m-b")
    }

    @Test
    func dedupePrefersHigherIMDbWhenUserRatingsAreMissing() async throws {
        let db = try await makeDatabase(named: "dedupe-imdb-priority")

        try await db.saveMediaItem(MediaItem(id: "m-low", type: .movie, title: "Arrival", imdbRating: 7.5))
        try await db.saveMediaItem(MediaItem(id: "m-high", type: .movie, title: "Arrival", imdbRating: 8.9))

        let now = Date()
        try await db.addToLibrary(UserLibraryEntry(id: "e-low", mediaId: "m-low", folderId: "", listType: .watchlist, addedAt: now.addingTimeInterval(50)))
        try await db.addToLibrary(UserLibraryEntry(id: "e-high", mediaId: "m-high", folderId: "", listType: .watchlist, addedAt: now))

        let removed = try await db.dedupeLibraryEntriesByTitleEquivalence(listType: .watchlist)
        #expect(removed == 1)

        let remaining = try await db.fetchLibraryEntries(listType: .watchlist)
        #expect(remaining.count == 1)
        #expect(remaining.first?.mediaId == "m-high")
    }

    @Test
    func dedupePrefersNewestAddedAtWhenRatingsTie() async throws {
        let db = try await makeDatabase(named: "dedupe-added-at-priority")

        try await db.saveMediaItem(MediaItem(id: "m-old", type: .movie, title: "Heat", imdbRating: 8.0))
        try await db.saveMediaItem(MediaItem(id: "m-new", type: .movie, title: "Heat", imdbRating: 8.0))

        let base = Date()
        try await db.addToLibrary(UserLibraryEntry(id: "e-old", mediaId: "m-old", folderId: "", listType: .favorites, addedAt: base))
        try await db.addToLibrary(UserLibraryEntry(id: "e-new", mediaId: "m-new", folderId: "", listType: .favorites, addedAt: base.addingTimeInterval(120)))

        try await db.saveTasteEvent(TasteEvent(id: "r-old", mediaId: "m-old", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 8, createdAt: base))
        try await db.saveTasteEvent(TasteEvent(id: "r-new", mediaId: "m-new", eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 8, createdAt: base))

        let removed = try await db.dedupeLibraryEntriesByTitleEquivalence(listType: .favorites)
        #expect(removed == 1)

        let remaining = try await db.fetchLibraryEntries(listType: .favorites)
        #expect(remaining.count == 1)
        #expect(remaining.first?.mediaId == "m-new")
    }

    @Test
    func dedupeMatchesTitlesAfterCaseAccentAndPunctuationNormalization() async throws {
        let db = try await makeDatabase(named: "dedupe-title-normalization")

        try await db.saveMediaItem(MediaItem(id: "m-accented", type: .movie, title: "Léon: The Professional", imdbRating: 8.5))
        try await db.saveMediaItem(MediaItem(id: "m-plain", type: .movie, title: "leon the professional", imdbRating: 7.0))

        let now = Date()
        try await db.addToLibrary(UserLibraryEntry(id: "e-accented", mediaId: "m-accented", folderId: "", listType: .favorites, addedAt: now))
        try await db.addToLibrary(UserLibraryEntry(id: "e-plain", mediaId: "m-plain", folderId: "", listType: .favorites, addedAt: now.addingTimeInterval(60)))

        let removed = try await db.dedupeLibraryEntriesByTitleEquivalence(listType: .favorites)
        #expect(removed == 1)

        let remaining = try await db.fetchLibraryEntries(listType: .favorites)
        #expect(remaining.count == 1)
        #expect(remaining.first?.mediaId == "m-accented")
    }

    @Test
    func dedupeIgnoresTitlesThatNormalizeToEmptyKeys() async throws {
        let db = try await makeDatabase(named: "dedupe-empty-title-key")

        try await db.saveMediaItem(MediaItem(id: "m-punctuation-a", type: .movie, title: "!!!"))
        try await db.saveMediaItem(MediaItem(id: "m-punctuation-b", type: .movie, title: " -- "))

        let now = Date()
        try await db.addToLibrary(UserLibraryEntry(id: "e-a", mediaId: "m-punctuation-a", folderId: "", listType: .favorites, addedAt: now))
        try await db.addToLibrary(UserLibraryEntry(id: "e-b", mediaId: "m-punctuation-b", folderId: "", listType: .favorites, addedAt: now.addingTimeInterval(60)))

        let removed = try await db.dedupeLibraryEntriesByTitleEquivalence(listType: .favorites)
        #expect(removed == 0)

        let remaining = try await db.fetchLibraryEntries(listType: .favorites)
        #expect(remaining.map(\.mediaId).sorted() == ["m-punctuation-a", "m-punctuation-b"])
    }

    private func makeDatabase(named name: String) async throws -> DatabaseManager {
        let database = try DatabaseManager(inMemoryNamed: "\(name)-\(UUID().uuidString)")
        try await database.migrate()
        return database
    }
}
