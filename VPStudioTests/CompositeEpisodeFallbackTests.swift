import Foundation
import Testing
@testable import VPStudio

/// OMDb has no episode catalog for many newly-airing series (totalSeasons
/// "N/A", Season lookups return "Series or season not found!"). The composite
/// provider must fall back to the legacy TMDb catalog in both failure shapes:
/// an EMPTY seasons list (OMDb returns [] without throwing) and a THROWN
/// episode lookup.
private struct EpisodeFallbackOMDbStub: MetadataProvider {
    var seasons: [Season] = []
    var episodesError: Error = OMDbError.notFound

    func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        MediaItem(id: id, type: type, title: "OMDb Item")
    }

    func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
    }

    func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
    }

    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
    }

    func getGenres(type: MediaType) async throws -> [Genre] { [] }

    func getSeasons(id: String, type: MediaType) async throws -> [Season] { seasons }

    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode] {
        throw episodesError
    }
}

private struct EpisodeFallbackTMDbStub: MetadataProvider {
    let resolvedTMDBID: Int
    let seasons: [Season]
    let episodes: [Episode]

    func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        var item = MediaItem(id: id, type: type, title: "TMDb Item")
        item.tmdbId = resolvedTMDBID
        return item
    }

    func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
    }

    func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
    }

    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
    }

    func getGenres(type: MediaType) async throws -> [Genre] { [] }

    func getSeasons(tmdbId: Int) async throws -> [Season] { seasons }

    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { episodes }
}

@Suite("Composite Episode Catalog Fallback")
struct CompositeEpisodeFallbackTests {
    private let season = Season(
        id: 1,
        seasonNumber: 1,
        name: "Season 1",
        overview: nil,
        posterPath: nil,
        episodeCount: 8,
        airDate: nil
    )

    private let episode = Episode(
        id: "tmdb-episode-900001",
        mediaId: "tmdb-260001",
        seasonNumber: 1,
        episodeNumber: 1,
        title: "Pilot",
        overview: nil,
        airDate: nil,
        stillPath: nil,
        runtime: nil
    )

    @Test func emptyOMDbSeasonsFallBackToTMDbCatalog() async throws {
        let provider = CompositeMetadataProvider(
            omdbProvider: EpisodeFallbackOMDbStub(),
            tmdbProvider: EpisodeFallbackTMDbStub(resolvedTMDBID: 260_001, seasons: [season], episodes: [episode])
        )

        let seasons = try await provider.getSeasons(id: "tt34809853", type: .series)

        #expect(seasons.count == 1)
        #expect(seasons.first?.episodeCount == 8)
    }

    @Test func thrownOMDbEpisodeLookupFallsBackToTMDbCatalog() async throws {
        let provider = CompositeMetadataProvider(
            omdbProvider: EpisodeFallbackOMDbStub(),
            tmdbProvider: EpisodeFallbackTMDbStub(resolvedTMDBID: 260_001, seasons: [season], episodes: [episode])
        )

        let episodes = try await provider.getEpisodes(id: "tt34809853", type: .series, season: 1)

        #expect(episodes.count == 1)
        #expect(episodes.first?.title == "Pilot")
    }

    @Test func nonEmptyOMDbSeasonsAreServedWithoutFallback() async throws {
        let omdbSeason = Season(
            id: 1,
            seasonNumber: 1,
            name: "Season 1",
            overview: nil,
            posterPath: nil,
            episodeCount: 12,
            airDate: nil
        )
        let provider = CompositeMetadataProvider(
            omdbProvider: EpisodeFallbackOMDbStub(seasons: [omdbSeason]),
            tmdbProvider: EpisodeFallbackTMDbStub(resolvedTMDBID: 260_001, seasons: [season], episodes: [episode])
        )

        let seasons = try await provider.getSeasons(id: "tt34809853", type: .series)

        #expect(seasons.first?.episodeCount == 12)
    }

    @Test func emptySeasonsWithoutTMDbProviderStayEmpty() async throws {
        let provider = CompositeMetadataProvider(
            omdbProvider: EpisodeFallbackOMDbStub(),
            tmdbProvider: nil
        )

        let seasons = try await provider.getSeasons(id: "tt34809853", type: .series)

        #expect(seasons.isEmpty)
    }

    @Test func movieLookupsDoNotTriggerSeriesCatalogFallback() async throws {
        let provider = CompositeMetadataProvider(
            omdbProvider: EpisodeFallbackOMDbStub(),
            tmdbProvider: EpisodeFallbackTMDbStub(resolvedTMDBID: 260_001, seasons: [season], episodes: [episode])
        )

        let seasons = try await provider.getSeasons(id: "tt1160419", type: .movie)

        #expect(seasons.isEmpty)
    }
}
