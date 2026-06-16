import Foundation
import Testing
import GRDB
@testable import VPStudio

// MARK: - MediaItem Computed Properties

@Suite("MediaItemComputedProperties")
struct MediaItemComputedPropertiesTests {

    @Test func posterURLBuildsTMDBw500() {
        let item = MediaItem(
            id: "tt123",
            type: .movie,
            title: "Test",
            posterPath: "/poster.jpg"
        )
        #expect(item.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w500/poster.jpg")
    }

    @Test func posterURLIsNilWhenPathMissing() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test")
        #expect(item.posterURL == nil)
    }

    @Test func posterURLIsNilWhenPathIsEmpty() {
        let item = MediaItem(
            id: "tt123",
            type: .movie,
            title: "Test",
            posterPath: ""
        )
        #expect(item.posterURL == nil)
    }

    @Test func backdropURLBuildsTMDBW1280() {
        let item = MediaItem(
            id: "tt123",
            type: .movie,
            title: "Test",
            backdropPath: "/backdrop.jpg"
        )
        // w1280 (not original): intentional payload reduction with no visible quality loss (see MediaItem.backdropURL).
        #expect(item.backdropURL?.absoluteString == "https://image.tmdb.org/t/p/w1280/backdrop.jpg")
    }

    @Test func backdropURLIsNilWhenPathMissingOrEmpty() {
        let missing = MediaItem(id: "tt123", type: .movie, title: "Test")
        let empty = MediaItem(id: "tt456", type: .movie, title: "Test", backdropPath: "")

        #expect(missing.backdropURL == nil)
        #expect(empty.backdropURL == nil)
    }

    @Test func hasArtworkTrueWithPoster() {
        let item = MediaItem(
            id: "tt123",
            type: .movie,
            title: "Test",
            posterPath: "/poster.jpg"
        )
        #expect(item.hasArtwork == true)
    }

    @Test func hasArtworkTrueWithBackdrop() {
        let item = MediaItem(
            id: "tt123",
            type: .movie,
            title: "Test",
            backdropPath: "/backdrop.jpg"
        )
        #expect(item.hasArtwork == true)
    }

    @Test func hasArtworkFalseWithEmptyPaths() {
        let item = MediaItem(
            id: "tt123",
            type: .movie,
            title: "Test",
            posterPath: "",
            backdropPath: ""
        )
        #expect(item.hasArtwork == false)
    }

    @Test func hasArtworkFalseWithNilPaths() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test")
        #expect(item.hasArtwork == false)
    }

    @Test func yearStringReturnsValue() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test", year: 2024)
        #expect(item.yearString == "2024")
    }

    @Test func yearStringReturnsEmptyWhenNil() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test")
        #expect(item.yearString == "")
    }

    @Test func ratingStringFormatsToOneDecimal() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test", imdbRating: 8.75)
        #expect(item.ratingString == "8.8")
    }

    @Test func ratingStringReturnsEmptyWhenNil() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test")
        #expect(item.ratingString == "")
    }

    @Test func runtimeStringWithHoursAndMinutes() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test", runtime: 145)
        #expect(item.runtimeString == "2h 25m")
    }

    @Test func runtimeStringWithMinutesOnly() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test", runtime: 45)
        #expect(item.runtimeString == "45m")
    }

    @Test func runtimeStringReturnsEmptyWhenNil() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test")
        #expect(item.runtimeString == "")
    }
}

// MARK: - MediaItem Value Semantics

@Suite("MediaItemValueSemantics")
struct MediaItemValueSemanticsTests {

    @Test func withIDReturnsCopyWithNewID() {
        let original = MediaItem(id: "tt123", type: .movie, title: "Original")
        let copy = original.withID("tt456")
        #expect(copy.id == "tt456")
        #expect(original.id == "tt123")
        #expect(copy.title == original.title)
    }

    @Test func mediaItemEquality() {
        let a = MediaItem(id: "tt123", type: .movie, title: "Test", year: 2024)
        let b = MediaItem(id: "tt123", type: .movie, title: "Test", year: 2024)
        #expect(a == b)
    }

    @Test func mediaItemInequality() {
        let a = MediaItem(id: "tt123", type: .movie, title: "Test")
        let b = MediaItem(id: "tt456", type: .movie, title: "Test")
        #expect(a != b)
    }
}

// MARK: - MediaItem GRDB Round-Trip

@Suite("MediaItemGRDB")
struct MediaItemGRDBTests {

    @Test func initFromRowDecodesTypeAndGenres() throws {
        let row = Row([
            "id": "tt123",
            "type": "series",
            "title": "Test",
            "year": 2024,
            "posterPath": nil,
            "backdropPath": nil,
            "overview": nil,
            "genres": try JSONEncoder().encode(["Comedy"]),
            "imdbRating": nil,
            "runtime": nil,
            "status": nil,
            "tmdbId": nil,
            "lastFetched": nil,
        ])
        let item = try MediaItem(row: row)
        #expect(item.id == "tt123")
        #expect(item.type == .series)
        #expect(item.genres == ["Comedy"])
    }

    @Test func initFromRowFallsBackToMovieForUnknownType() throws {
        let row = Row([
            "id": "tt123",
            "type": "invalid",
            "title": "Test",
            "year": nil,
            "posterPath": nil,
            "backdropPath": nil,
            "overview": nil,
            "genres": nil,
            "imdbRating": nil,
            "runtime": nil,
            "status": nil,
            "tmdbId": nil,
            "lastFetched": nil,
        ])
        let item = try MediaItem(row: row)
        #expect(item.type == .movie)
        #expect(item.genres == [])
    }

    @Test func initFromRowFallsBackToEmptyGenresForMalformedJSON() throws {
        let row = Row([
            "id": "tt123",
            "type": "movie",
            "title": "Test",
            "year": nil,
            "posterPath": nil,
            "backdropPath": nil,
            "overview": nil,
            "genres": Data("not-json".utf8),
            "imdbRating": nil,
            "runtime": nil,
            "status": nil,
            "tmdbId": nil,
            "lastFetched": nil,
        ])

        let item = try MediaItem(row: row)

        #expect(item.type == .movie)
        #expect(item.genres == [])
    }

    @Test func customDecoderDefaultsMissingTypeAndGenres() throws {
        let data = Data("""
        {
          "id": "tt123",
          "title": "Decoded"
        }
        """.utf8)

        let item = try JSONDecoder().decode(MediaItem.self, from: data)

        #expect(item.type == .movie)
        #expect(item.genres == [])
        #expect(item.title == "Decoded")
    }
}

// MARK: - MediaPreview Properties

@Suite("MediaPreviewProperties")
struct MediaPreviewPropertiesTests {

    @Test func posterURLUsesw342() {
        let preview = MediaPreview(id: "tt123", type: .movie, title: "Test", posterPath: "/poster.jpg")
        #expect(preview.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w342/poster.jpg")
    }

    @Test func posterURLIsNilWhenPreviewPathMissingOrEmpty() {
        let missing = MediaPreview(id: "tt123", type: .movie, title: "Test")
        let empty = MediaPreview(id: "tt456", type: .movie, title: "Test", posterPath: "")

        #expect(missing.posterURL == nil)
        #expect(empty.posterURL == nil)
    }

    @Test func backdropURLUsesw1280() {
        let preview = MediaPreview(id: "tt123", type: .movie, title: "Test", backdropPath: "/bg.jpg")
        #expect(preview.backdropURL?.absoluteString == "https://image.tmdb.org/t/p/w1280/bg.jpg")
    }

    @Test func backdropURLIsNilWhenPreviewPathMissingOrEmpty() {
        let missing = MediaPreview(id: "tt123", type: .movie, title: "Test")
        let empty = MediaPreview(id: "tt456", type: .movie, title: "Test", backdropPath: "")

        #expect(missing.backdropURL == nil)
        #expect(empty.backdropURL == nil)
    }

    @Test func episodeMetadataDefaultsAndStoresValues() {
        let defaultPreview = MediaPreview(id: "tt123", type: .series, title: "Show")
        let episodePreview = MediaPreview(
            id: "tt123-s1e2",
            type: .series,
            title: "Episode",
            episodeId: "ep-2",
            seasonNumber: 1,
            episodeNumber: 2
        )

        #expect(defaultPreview.episodeId == nil)
        #expect(defaultPreview.seasonNumber == nil)
        #expect(defaultPreview.episodeNumber == nil)
        #expect(episodePreview.episodeId == "ep-2")
        #expect(episodePreview.seasonNumber == 1)
        #expect(episodePreview.episodeNumber == 2)
    }

    @Test func mediaPreviewEquatable() {
        let a = MediaPreview(id: "tt123", type: .movie, title: "Test")
        let b = MediaPreview(id: "tt123", type: .movie, title: "Test")
        #expect(a == b)
    }
}

// MARK: - MediaItem Database Round-Trip

@Suite("MediaItemDatabaseRoundTrip")
struct MediaItemDatabaseRoundTripTests {
    private func makeTempDatabase() async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "media-item-test-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test func roundTripsThroughDatabaseManager() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let item = MediaItem(
            id: "tt123",
            type: .movie,
            title: "Test Movie",
            year: 2024
        )
        try await database.saveMediaItem(item)
        let fetched = try await database.fetchMediaItem(id: "tt123")

        #expect(fetched != nil)
        #expect(fetched?.id == item.id)
        #expect(fetched?.title == item.title)
        #expect(fetched?.type == item.type)
    }

    @Test
    func mediaItemWithAllFieldsRoundTripsCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let item = MediaItem(
            id: "tt456",
            type: .series,
            title: "Test Series",
            year: 2023,
            posterPath: "/poster.jpg",
            backdropPath: "/backdrop.jpg",
            overview: "A great series",
            genres: ["Drama", "Action"],
            imdbRating: 8.5,
            runtime: 60,
            status: "Released",
            tmdbId: 12345
        )
        try await database.saveMediaItem(item)
        let fetched = try await database.fetchMediaItem(id: "tt456")

        #expect(fetched != nil)
        #expect(fetched?.overview == "A great series")
        #expect(fetched?.genres == ["Drama", "Action"])
        #expect(fetched?.imdbRating == 8.5)
        #expect(fetched?.tmdbId == 12345)
    }

    @Test
    func multipleMediaItemsRoundTripCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let items = [
            MediaItem(id: "tt001", type: .movie, title: "Movie 1", year: 2020),
            MediaItem(id: "tt002", type: .movie, title: "Movie 2", year: 2021),
            MediaItem(id: "tt003", type: .series, title: "Series 1", year: 2022)
        ]

        for item in items {
            try await database.saveMediaItem(item)
        }

        let ids = items.map(\.id)
        let fetched = try await database.fetchMediaItems(ids: ids)

        #expect(fetched.count == 3)
        #expect(fetched.contains { $0.id == "tt001" })
        #expect(fetched.contains { $0.id == "tt002" })
        #expect(fetched.contains { $0.id == "tt003" })
    }

    @Test func mediaItemGenresArrayPersistsCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let item = MediaItem(
            id: "tt789",
            type: .movie,
            title: "Genre Test",
            genres: ["Sci-Fi", "Adventure", "Action"]
        )
        try await database.saveMediaItem(item)
        let fetched = try await database.fetchMediaItem(id: "tt789")

        #expect(fetched != nil)
        #expect(fetched?.genres.count == 3)
        #expect(fetched?.genres == ["Sci-Fi", "Adventure", "Action"])
    }
}
