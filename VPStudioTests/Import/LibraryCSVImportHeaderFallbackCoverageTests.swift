import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct LibraryCSVImportHeaderFallbackCoverageTests {
    @Test
    func importUsesLaterHeaderAliasesWhenEarlierAliasesAreBlank() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "csv-header-fallback.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let csvURL = try writeCSV(
            """
            Const,IMDb URL,Title,Primary Title,Your Rating,My Score,Date Rated,Watched At,Title Type,Release Year
            ,https://www.imdb.com/title/tt7654321/,   ,Fallback Title,   ,88,   ,2026-04-05T12:34:56Z,tvEpisode,Released 2024
            """,
            name: "header-fallbacks.csv",
            in: tempDir
        )

        let service = LibraryCSVImportService(database: database)
        let summary = try await service.importCSV(
            from: csvURL,
            options: .init(destination: .history, importRatings: true)
        )

        #expect(summary.detectedFormat == .imdbRatings)
        #expect(summary.rowsRead == 1)
        #expect(summary.rowsImported == 1)
        #expect(summary.historyImported == 1)
        #expect(summary.watchlistImported == 1)
        #expect(summary.ratingsImported == 1)

        let item = try #require(try await database.fetchMediaItem(id: "tt7654321"))
        #expect(item.title == "Fallback Title")
        #expect(item.type == .series)
        #expect(item.year == 2024)

        let history = try await database.fetchWatchHistory(limit: 10)
        let entry = try #require(history.first)
        #expect(entry.mediaId == "tt7654321")
        #expect(entry.title == "Fallback Title")

        let ratings = try await database.fetchTasteEvents(eventType: .rated, limit: 10)
        let rating = try #require(ratings.first)
        #expect(rating.mediaId == "tt7654321")
        #expect(rating.feedbackScale?.canonicalMode == .oneToHundred)
        #expect(rating.feedbackValue == 88)
    }

    @Test
    func blankIdAndBlankUrlFallbackToNormalizedTitleAndYear() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "csv-title-id-fallback.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let csvURL = try writeCSV(
            """
            IMDb ID,Link,Name,Start Year,Favorite
            ,   ,  The Fallback Movie  ,circa 1984,yes
            """,
            name: "fallback-title.csv",
            in: tempDir
        )

        let service = LibraryCSVImportService(database: database)
        let summary = try await service.importCSV(
            from: csvURL,
            options: .init(
                destination: .auto,
                importRatings: true,
                promoteLikedRatingsToFavorites: true
            )
        )

        #expect(summary.detectedFormat == .generic)
        #expect(summary.rowsImported == 1)
        #expect(summary.favoritesImported == 1)
        #expect(summary.watchlistImported == 0)
        #expect(summary.ratingsImported == 1)

        let mediaID = "csv-the-fallback-movie-1984"
        let item = try #require(try await database.fetchMediaItem(id: mediaID))
        #expect(item.title == "The Fallback Movie")
        #expect(item.year == 1984)

        let favorites = try await database.fetchLibraryEntries(listType: .favorites)
        #expect(favorites.map(\.mediaId) == [mediaID])

        let ratings = try await database.fetchTasteEvents(eventType: .rated, limit: 10)
        let rating = try #require(ratings.first)
        #expect(rating.feedbackScale?.canonicalMode == .likeDislike)
        #expect(rating.feedbackValue == 1)
    }

    private func makeTemporaryDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    private func writeCSV(_ content: String, name: String, in directory: URL) throws -> URL {
        let fileURL = directory.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
