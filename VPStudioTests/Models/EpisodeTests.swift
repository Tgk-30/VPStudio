import Testing
import Foundation
import GRDB
@testable import VPStudio

@Suite("Episode Properties")
struct EpisodeModelTests {
    @Test("Episode properties are set correctly")
    func episodeProperties() {
        let episode = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5,
            title: "The Pilot",
            overview: "This is the first episode",
            airDate: "2023-01-01",
            stillPath: "/still.jpg",
            runtime: 45
        )

        #expect(episode.id == "episode-123")
        #expect(episode.mediaId == "media-456")
        #expect(episode.seasonNumber == 1)
        #expect(episode.episodeNumber == 5)
        #expect(episode.title == "The Pilot")
        #expect(episode.overview == "This is the first episode")
        #expect(episode.airDate == "2023-01-01")
        #expect(episode.stillPath == "/still.jpg")
        #expect(episode.runtime == 45)
    }

    @Test("Episode with optional properties nil")
    func optionalPropertiesNil() {
        let episode = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5
        )

        #expect(episode.title == nil)
        #expect(episode.overview == nil)
        #expect(episode.airDate == nil)
        #expect(episode.stillPath == nil)
        #expect(episode.runtime == nil)
    }
}

@Suite("Episode Display Title")
struct EpisodeDisplayTitleModelTests {
    @Test("Display title with season, episode, and title")
    func displayTitleWithTitle() {
        let episode = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5,
            title: "The Pilot"
        )

        #expect(episode.displayTitle == "S01E05 - The Pilot")
    }

    @Test("Display title with season and episode only")
    func displayTitleWithoutTitle() {
        let episode = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 2,
            episodeNumber: 10
        )

        #expect(episode.displayTitle == "S02E10")
    }

    @Test("Display title with empty title")
    func displayTitleWithEmptyTitle() {
        let episode = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5,
            title: ""
        )

        #expect(episode.displayTitle == "S01E05")
    }

    @Test("Display title formatting with single digit numbers")
    func displayTitleSingleDigit() {
        let episode = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5,
            title: "Pilot"
        )

        #expect(episode.displayTitle == "S01E05 - Pilot")
    }

    @Test("Display title formatting with double digit numbers")
    func displayTitleDoubleDigit() {
        let episode = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 12,
            episodeNumber: 25,
            title: "Finale"
        )

        #expect(episode.displayTitle == "S12E25 - Finale")
    }
}

@Suite("Episode Short Label")
struct EpisodeShortLabelModelTests {
    @Test("Short label format")
    func shortLabel() {
        let episode1 = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5
        )

        let episode2 = Episode(
            id: "episode-456",
            mediaId: "media-789",
            seasonNumber: 12,
            episodeNumber: 25
        )

        #expect(episode1.shortLabel == "S01E05")
        #expect(episode2.shortLabel == "S12E25")
    }
}

@Suite("Episode Still URL")
struct EpisodeStillURLModelTests {
    @Test("Still URL construction")
    func stillURL() {
        let episode1 = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5,
            stillPath: "/still.jpg"
        )

        let episode2 = Episode(
            id: "episode-456",
            mediaId: "media-789",
            seasonNumber: 1,
            episodeNumber: 5,
            stillPath: nil
        )

        #expect(episode1.stillURL == URL(string: "https://image.tmdb.org/t/p/w500/still.jpg")!)
        #expect(episode2.stillURL == nil)
    }
}

@Suite("Episode Season Number Parsing")
struct EpisodeSeasonNumberModelTests {
    @Test("Season number is preserved")
    func seasonNumber() {
        let episode1 = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5
        )

        let episode2 = Episode(
            id: "episode-456",
            mediaId: "media-789",
            seasonNumber: 10,
            episodeNumber: 15
        )

        #expect(episode1.seasonNumber == 1)
        #expect(episode2.seasonNumber == 10)
    }
}

@Suite("Episode Episode Number Parsing")
struct EpisodeEpisodeNumberModelTests {
    @Test("Episode number is preserved")
    func episodeNumber() {
        let episode1 = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5
        )

        let episode2 = Episode(
            id: "episode-456",
            mediaId: "media-789",
            seasonNumber: 1,
            episodeNumber: 25
        )

        #expect(episode1.episodeNumber == 5)
        #expect(episode2.episodeNumber == 25)
    }
}

@Suite("Season Properties")
struct SeasonModelTests {
    @Test("Season properties are set correctly")
    func seasonProperties() {
        let season = Season(
            id: 1,
            seasonNumber: 1,
            name: "Season 1",
            overview: "The first season",
            posterPath: "/poster.jpg",
            episodeCount: 10,
            airDate: "2023-01-01"
        )

        #expect(season.id == 1)
        #expect(season.seasonNumber == 1)
        #expect(season.name == "Season 1")
        #expect(season.overview == "The first season")
        #expect(season.posterPath == "/poster.jpg")
        #expect(season.episodeCount == 10)
        #expect(season.airDate == "2023-01-01")
    }

    @Test("Season with optional properties nil")
    func optionalPropertiesNil() {
        let season = Season(
            id: 1,
            seasonNumber: 1,
            name: "Season 1",
            episodeCount: 10
        )

        #expect(season.overview == nil)
        #expect(season.posterPath == nil)
        #expect(season.airDate == nil)
    }
}

@Suite("Season Poster URL")
struct SeasonPosterURLModelTests {
    @Test("Poster URL construction")
    func posterURL() {
        let season1 = Season(
            id: 1,
            seasonNumber: 1,
            name: "Season 1",
            posterPath: "/poster.jpg",
            episodeCount: 10
        )

        let season2 = Season(
            id: 2,
            seasonNumber: 2,
            name: "Season 2",
            posterPath: nil,
            episodeCount: 10
        )

        #expect(season1.posterURL == URL(string: "https://image.tmdb.org/t/p/w342/poster.jpg")!)
        #expect(season2.posterURL == nil)
    }
}

@Suite("Episode Codable Round-Trip")
struct EpisodeModelCodableTests {
    @Test("Episode encodes and decodes correctly")
    func codableRoundTrip() throws {
        let originalEpisode = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5,
            title: "The Pilot",
            overview: "This is the first episode",
            airDate: "2023-01-01",
            stillPath: "/still.jpg",
            runtime: 45
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEpisode)
        let decoder = JSONDecoder()
        let decodedEpisode = try decoder.decode(Episode.self, from: data)

        #expect(decodedEpisode.id == originalEpisode.id)
        #expect(decodedEpisode.mediaId == originalEpisode.mediaId)
        #expect(decodedEpisode.seasonNumber == originalEpisode.seasonNumber)
        #expect(decodedEpisode.episodeNumber == originalEpisode.episodeNumber)
        #expect(decodedEpisode.title == originalEpisode.title)
        #expect(decodedEpisode.overview == originalEpisode.overview)
        #expect(decodedEpisode.airDate == originalEpisode.airDate)
        #expect(decodedEpisode.stillPath == originalEpisode.stillPath)
        #expect(decodedEpisode.runtime == originalEpisode.runtime)
    }

    @Test("Episode with minimal data encodes and decodes")
    func minimalCodableRoundTrip() throws {
        let originalEpisode = Episode(
            id: "episode-123",
            mediaId: "media-456",
            seasonNumber: 1,
            episodeNumber: 5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEpisode)
        let decoder = JSONDecoder()
        let decodedEpisode = try decoder.decode(Episode.self, from: data)

        #expect(decodedEpisode.id == originalEpisode.id)
        #expect(decodedEpisode.mediaId == originalEpisode.mediaId)
        #expect(decodedEpisode.seasonNumber == originalEpisode.seasonNumber)
        #expect(decodedEpisode.episodeNumber == originalEpisode.episodeNumber)
    }
}

@Suite("Season Codable Round-Trip")
struct SeasonModelCodableTests {
    @Test("Season encodes and decodes correctly")
    func codableRoundTrip() throws {
        let originalSeason = Season(
            id: 1,
            seasonNumber: 1,
            name: "Season 1",
            overview: "The first season",
            posterPath: "/poster.jpg",
            episodeCount: 10,
            airDate: "2023-01-01"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSeason)
        let decoder = JSONDecoder()
        let decodedSeason = try decoder.decode(Season.self, from: data)

        #expect(decodedSeason.id == originalSeason.id)
        #expect(decodedSeason.seasonNumber == originalSeason.seasonNumber)
        #expect(decodedSeason.name == originalSeason.name)
        #expect(decodedSeason.overview == originalSeason.overview)
        #expect(decodedSeason.posterPath == originalSeason.posterPath)
        #expect(decodedSeason.episodeCount == originalSeason.episodeCount)
        #expect(decodedSeason.airDate == originalSeason.airDate)
    }

    @Test("Season with minimal data encodes and decodes")
    func minimalCodableRoundTrip() throws {
        let originalSeason = Season(
            id: 1,
            seasonNumber: 1,
            name: "Season 1",
            episodeCount: 10
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSeason)
        let decoder = JSONDecoder()
        let decodedSeason = try decoder.decode(Season.self, from: data)

        #expect(decodedSeason.id == originalSeason.id)
        #expect(decodedSeason.seasonNumber == originalSeason.seasonNumber)
        #expect(decodedSeason.name == originalSeason.name)
        #expect(decodedSeason.episodeCount == originalSeason.episodeCount)
    }
}

@Suite("Episode Database Round-Trip")
struct EpisodeDatabaseRoundTripTests {
    private func makeTempDatabase() async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "episode-test-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test func roundTripsThroughDatabaseManager() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let episode = Episode(
            id: "ep-1",
            mediaId: "media-123",
            seasonNumber: 1,
            episodeNumber: 5,
            title: "The Pilot",
            overview: "First episode",
            runtime: 45
        )
        try await database.saveEpisodes([episode])
        let fetched = try await database.fetchEpisodes(mediaId: "media-123", season: 1)

        #expect(fetched.count == 1)
        #expect(fetched.first?.id == episode.id)
        #expect(fetched.first?.title == episode.title)
        #expect(fetched.first?.runtime == episode.runtime)
    }

    @Test
    func episodeWithAllFieldsRoundTripsCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let episode = Episode(
            id: "full-ep",
            mediaId: "series-456",
            seasonNumber: 2,
            episodeNumber: 10,
            title: "The Finale",
            overview: "Last episode of the season",
            airDate: "2023-12-31",
            stillPath: "/still.jpg",
            runtime: 60
        )
        try await database.saveEpisodes([episode])
        let fetched = try await database.fetchEpisodes(mediaId: "series-456", season: 2)

        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "The Finale")
        #expect(fetched.first?.overview == "Last episode of the season")
        #expect(fetched.first?.stillPath == "/still.jpg")
        #expect(fetched.first?.runtime == 60)
    }

    @Test
    func multipleEpisodesForSameSeasonRoundTripCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let episodes = [
            Episode(id: "ep-a", mediaId: "series-1", seasonNumber: 1, episodeNumber: 1, title: "Episode 1"),
            Episode(id: "ep-b", mediaId: "series-1", seasonNumber: 1, episodeNumber: 2, title: "Episode 2"),
            Episode(id: "ep-c", mediaId: "series-1", seasonNumber: 1, episodeNumber: 3, title: "Episode 3")
        ]

        try await database.saveEpisodes(episodes)
        let fetched = try await database.fetchEpisodes(mediaId: "series-1", season: 1)

        #expect(fetched.count == 3)
        #expect(fetched.contains { $0.id == "ep-a" })
        #expect(fetched.contains { $0.id == "ep-b" })
        #expect(fetched.contains { $0.id == "ep-c" })
    }

    @Test func episodesFromDifferentSeasonsAreSeparate() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let episodes = [
            Episode(id: "s1-ep1", mediaId: "series-x", seasonNumber: 1, episodeNumber: 1),
            Episode(id: "s2-ep1", mediaId: "series-x", seasonNumber: 2, episodeNumber: 1)
        ]

        try await database.saveEpisodes(episodes)
        let season1Fetched = try await database.fetchEpisodes(mediaId: "series-x", season: 1)
        let season2Fetched = try await database.fetchEpisodes(mediaId: "series-x", season: 2)

        #expect(season1Fetched.count == 1)
        #expect(season2Fetched.count == 1)
        #expect(season1Fetched.first?.id == "s1-ep1")
        #expect(season2Fetched.first?.id == "s2-ep1")
    }
}
