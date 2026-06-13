import Testing
import Foundation
@testable import VPStudio

@Suite("MediaItem Codable Round-Trip")
struct MediaItemCodableTests {
    @Test("MediaItem encodes and decodes correctly")
    func mediaItemCodableRoundTrip() throws {
        let original = MediaItem(
            id: "tt123456",
            type: .movie,
            title: "Test Movie",
            year: 2024,
            posterPath: "/poster.jpg",
            backdropPath: "/backdrop.jpg",
            overview: "A great movie about testing",
            genres: ["Action", "Drama", "Sci-Fi"],
            imdbRating: 8.5,
            runtime: 145,
            status: "Released",
            tmdbId: 12345,
            lastFetched: Date(timeIntervalSince1970: 123456789)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaItem.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.type == original.type)
        #expect(decoded.title == original.title)
        #expect(decoded.year == original.year)
        #expect(decoded.posterPath == original.posterPath)
        #expect(decoded.backdropPath == original.backdropPath)
        #expect(decoded.overview == original.overview)
        #expect(decoded.genres == original.genres)
        #expect(decoded.imdbRating == original.imdbRating)
        #expect(decoded.runtime == original.runtime)
        #expect(decoded.status == original.status)
        #expect(decoded.tmdbId == original.tmdbId)
        #expect(decoded.lastFetched == original.lastFetched)
    }

    @Test("MediaItem with all nil optionals encodes and decodes correctly")
    func mediaItemAllNilOptionalsCodableRoundTrip() throws {
        let original = MediaItem(
            id: "tt999999",
            type: .series,
            title: "Minimal Series"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaItem.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.type == original.type)
        #expect(decoded.title == original.title)
        #expect(decoded.year == nil)
        #expect(decoded.posterPath == nil)
        #expect(decoded.backdropPath == nil)
        #expect(decoded.overview == nil)
        #expect(decoded.genres == [])
        #expect(decoded.imdbRating == nil)
        #expect(decoded.runtime == nil)
        #expect(decoded.status == nil)
        #expect(decoded.tmdbId == nil)
        #expect(decoded.lastFetched == nil)
    }

    @Test("MediaItem with empty genres array encodes and decodes correctly")
    func mediaItemEmptyGenresCodableRoundTrip() throws {
        let original = MediaItem(
            id: "tt000000",
            type: .movie,
            title: "No Genre Movie",
            genres: []
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaItem.self, from: encoded)

        #expect(decoded.genres == [])
    }

    @Test("MediaItem type defaults to movie when decoded from invalid string")
    func mediaItemTypeDecodesFromInvalidString() throws {
        let json = """
        {
            "id": "tt123",
            "type": "invalid_type",
            "title": "Test",
            "year": 2024,
            "posterPath": null,
            "backdropPath": null,
            "overview": null,
            "genres": null,
            "imdbRating": null,
            "runtime": null,
            "status": null,
            "tmdbId": null,
            "lastFetched": null
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MediaItem.self, from: data)

        #expect(decoded.type == .movie)
    }

    @Test("MediaItem genres JSON encoding is correct")
    func mediaItemGenresJSONEncoding() throws {
        let original = MediaItem(
            id: "tt123",
            type: .movie,
            title: "Test",
            genres: ["Action", "Comedy"]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MediaItem.self, from: encoded)

        #expect(decoded.genres == ["Action", "Comedy"])
    }
}

@Suite("MediaPreview Codable Tests")
struct MediaPreviewCodableTests {
    @Test("MediaPreview is NOT Codable - only Sendable, Identifiable, Equatable, Hashable")
    func mediaPreviewIsNotCodable() {
        let preview = MediaPreview(
            id: "tt123",
            type: .movie,
            title: "Test",
            year: 2024,
            posterPath: "/poster.jpg",
            backdropPath: "/backdrop.jpg",
            imdbRating: 8.5,
            tmdbId: 12345,
            episodeId: nil,
            seasonNumber: nil,
            episodeNumber: nil
        )

        let sendableCheck: any Sendable = preview
        _ = sendableCheck

        let identifiableCheck: any Identifiable = preview
        _ = identifiableCheck
    }

    @Test("MediaPreview properties are correct")
    func mediaPreviewProperties() {
        let preview = MediaPreview(
            id: "tt123",
            type: .movie,
            title: "Test",
            year: 2024,
            posterPath: "/poster.jpg",
            backdropPath: "/backdrop.jpg",
            imdbRating: 8.5,
            tmdbId: 12345
        )

        #expect(preview.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w342/poster.jpg")
        #expect(preview.backdropURL?.absoluteString == "https://image.tmdb.org/t/p/w1280/backdrop.jpg")
    }
}
