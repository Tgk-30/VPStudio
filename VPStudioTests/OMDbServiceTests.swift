import Foundation
import Testing
@testable import VPStudio

@Suite("OMDbService")
struct OMDbServiceTests {
    @Test
    func searchUsesOMDbKeyAndReturnsIMDbBackedPreviews() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            return try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Search": [
                    {
                      "Title": "Dune",
                      "Year": "2021",
                      "imdbID": "tt1160419",
                      "Type": "movie",
                      "Poster": "https://m.media-amazon.com/images/M/dune.jpg"
                    }
                  ],
                  "totalResults": "1",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "  test-key  ", session: session)

        let result = try await service.search(query: "Dune", type: .movie, page: 1)
        let requestURL = try Self.require(capture.firstURL())
        let preview = try Self.require(result.items.first)

        #expect(Self.queryValue("apikey", in: requestURL) == "test-key")
        #expect(Self.queryValue("s", in: requestURL) == "Dune")
        #expect(Self.queryValue("type", in: requestURL) == "movie")
        #expect(preview.id == "tt1160419")
        #expect(preview.tmdbId == nil)
        #expect(preview.posterPath == "https://m.media-amazon.com/images/M/dune.jpg")
    }

    @Test
    func searchEnrichesIMDbRatingsFromDetailResponses() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            let url = try Self.require(request.url)
            if Self.queryValue("s", in: url) == "Dune" {
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Search": [
                        {
                          "Title": "Dune",
                          "Year": "2021",
                          "imdbID": "tt1160419",
                          "Type": "movie",
                          "Poster": "https://m.media-amazon.com/images/M/dune-search.jpg"
                        },
                        {
                          "Title": "Dune: Part Two",
                          "Year": "2024",
                          "imdbID": "tt15239678",
                          "Type": "movie",
                          "Poster": "https://m.media-amazon.com/images/M/dune-two-search.jpg"
                        }
                      ],
                      "totalResults": "2",
                      "Response": "True"
                    }
                    """
                )
            }

            switch Self.queryValue("i", in: url) {
            case "tt1160419":
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Dune",
                      "Year": "2021",
                      "Rated": "PG-13",
                      "Runtime": "155 min",
                      "Genre": "Adventure, Drama, Sci-Fi",
                      "Plot": "A noble family becomes embroiled in a war for control over the galaxy.",
                      "Poster": "https://m.media-amazon.com/images/M/dune-detail.jpg",
                      "imdbRating": "8.0",
                      "imdbID": "tt1160419",
                      "Type": "movie",
                      "Response": "True"
                    }
                    """
                )
            case "tt15239678":
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Dune: Part Two",
                      "Year": "2024",
                      "Rated": "PG-13",
                      "Runtime": "166 min",
                      "Genre": "Adventure, Drama, Sci-Fi",
                      "Plot": "Paul Atreides unites with Chani and the Fremen.",
                      "Poster": "https://m.media-amazon.com/images/M/dune-two-detail.jpg",
                      "imdbRating": "8.5",
                      "imdbID": "tt15239678",
                      "Type": "movie",
                      "Response": "True"
                    }
                    """
                )
            default:
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Response": "False",
                      "Error": "Title not found!"
                    }
                    """
                )
            }
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let result = try await service.search(query: "Dune", type: .movie, page: 1)

        #expect(result.items.map(\.id) == ["tt1160419", "tt15239678"])
        #expect(result.items.map(\.imdbRating) == [8.0, 8.5])
        #expect(result.items.map(\.posterPath) == [
            "https://m.media-amazon.com/images/M/dune-detail.jpg",
            "https://m.media-amazon.com/images/M/dune-two-detail.jpg"
        ])
        #expect(capture.urls().count == 3)
    }

    @Test
    func detailPropagatesInvalidOMDbAPIKeyForSettingsValidation() async throws {
        let session = URLProtocolHarness.makeSession { request in
            try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Response": "False",
                  "Error": "Invalid API key!"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "bad-key", session: session)

        await #expect(throws: OMDbError.unauthorized) {
            _ = try await service.getDetail(id: MetadataSettingsPolicy.validationProbeIMDbID, type: .movie)
        }
    }

    @Test
    func discoverSortsEnrichedOMDbResultsByIMDbRating() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            let url = try Self.require(request.url)
            if Self.queryValue("s", in: url) == "drama" {
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Search": [
                        {
                          "Title": "Lower Drama",
                          "Year": "2021",
                          "imdbID": "tt1111111",
                          "Type": "movie",
                          "Poster": "https://m.media-amazon.com/images/M/lower.jpg"
                        },
                        {
                          "Title": "Higher Drama",
                          "Year": "2022",
                          "imdbID": "tt2222222",
                          "Type": "movie",
                          "Poster": "https://m.media-amazon.com/images/M/higher.jpg"
                        }
                      ],
                      "totalResults": "2",
                      "Response": "True"
                    }
                    """
                )
            }

            switch Self.queryValue("i", in: url) {
            case "tt1111111":
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Lower Drama",
                      "Year": "2021",
                      "Rated": "PG-13",
                      "Runtime": "100 min",
                      "Genre": "Drama",
                      "Plot": "A lower-rated drama.",
                      "Poster": "https://m.media-amazon.com/images/M/lower-detail.jpg",
                      "imdbRating": "6.7",
                      "imdbID": "tt1111111",
                      "Type": "movie",
                      "Response": "True"
                    }
                    """
                )
            case "tt2222222":
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Higher Drama",
                      "Year": "2022",
                      "Rated": "PG-13",
                      "Runtime": "110 min",
                      "Genre": "Drama",
                      "Plot": "A higher-rated drama.",
                      "Poster": "https://m.media-amazon.com/images/M/higher-detail.jpg",
                      "imdbRating": "8.4",
                      "imdbID": "tt2222222",
                      "Type": "movie",
                      "Response": "True"
                    }
                    """
                )
            default:
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Response": "False",
                      "Error": "Title not found!"
                    }
                    """
                )
            }
        }
        let service = OMDbService(apiKey: "test-key", session: session)
        let filters = DiscoverFilters(genreId: 18, minRating: 8.0, sortBy: .ratingDesc, page: 1)

        let result = try await service.discover(type: .movie, filters: filters)

        #expect(result.items.map(\.id) == ["tt2222222"])
        #expect(result.items.map(\.imdbRating) == [8.4])
        #expect(Self.queryValue("s", in: try Self.require(capture.urls().first)) == "drama")
    }

    @Test
    func discoverAppliesReleaseWindowUsingOMDbYears() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            let url = try Self.require(request.url)
            if Self.queryValue("s", in: url) == "movie" {
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Search": [
                        {
                          "Title": "Fresh Movie",
                          "Year": "2026",
                          "imdbID": "tt2026001",
                          "Type": "movie"
                        },
                        {
                          "Title": "Stale Movie",
                          "Year": "2024",
                          "imdbID": "tt2024001",
                          "Type": "movie"
                        },
                        {
                          "Title": "Undated Movie",
                          "Year": "N/A",
                          "imdbID": "tt2026002",
                          "Type": "movie"
                        }
                      ],
                      "totalResults": "3",
                      "Response": "True"
                    }
                    """
                )
            }

            switch Self.queryValue("i", in: url) {
            case "tt2026001":
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Fresh Movie",
                      "Year": "2026",
                      "imdbID": "tt2026001",
                      "Type": "movie",
                      "Response": "True"
                    }
                    """
                )
            case "tt2024001":
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Stale Movie",
                      "Year": "2024",
                      "imdbID": "tt2024001",
                      "Type": "movie",
                      "Response": "True"
                    }
                    """
                )
            case "tt2026002":
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Undated Movie",
                      "Year": "N/A",
                      "imdbID": "tt2026002",
                      "Type": "movie",
                      "Response": "True"
                    }
                    """
                )
            default:
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Response": "False",
                      "Error": "Title not found!"
                    }
                    """
                )
            }
        }
        let service = OMDbService(apiKey: "test-key", session: session)
        let filters = DiscoverFilters(
            sortBy: .releaseDateDesc,
            page: 1,
            releaseDateGte: "2026-01-01",
            releaseDateLte: "2026-12-31"
        )

        let result = try await service.discover(type: .movie, filters: filters)

        #expect(result.items.map(\.id) == ["tt2026001"])
        #expect(Self.queryValue("s", in: try Self.require(capture.urls().first)) == "movie")
    }

    @Test
    func detailAcceptsCompositeIMDbIDAndPreservesAbsoluteArtwork() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            return try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "Dune",
                  "Year": "2021",
                  "Rated": "PG-13",
                  "Released": "22 Oct 2021",
                  "Runtime": "155 min",
                  "Genre": "Action, Adventure, Drama",
                  "Plot": "A noble family becomes embroiled in a war for control over the galaxy's most valuable asset.",
                  "Poster": "https://m.media-amazon.com/images/M/dune-detail.jpg",
                  "imdbRating": "8.0",
                  "imdbID": "tt1160419",
                  "Type": "movie",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let item = try await service.getDetail(id: "movie-imdb-tt1160419", type: .movie)
        let requestURL = try Self.require(capture.firstURL())

        #expect(Self.queryValue("i", in: requestURL) == "tt1160419")
        #expect(Self.queryValue("t", in: requestURL) == nil)
        #expect(item.id == "tt1160419")
        #expect(item.tmdbId == nil)
        #expect(item.posterPath == "https://m.media-amazon.com/images/M/dune-detail.jpg")
        #expect(item.runtime == 155)
        #expect(item.imdbRating == 8.0)
        #expect(item.genres == ["Action", "Adventure", "Drama"])
    }

    @Test
    func getDetailSplitsTitleYearLookupIntoOMDbTitleAndYearParameters() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            return try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "Dune",
                  "Year": "2021",
                  "Runtime": "155 min",
                  "Poster": "https://m.media-amazon.com/images/M/dune-detail.jpg",
                  "imdbRating": "8.0",
                  "imdbID": "tt1160419",
                  "Type": "movie",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let item = try await service.getDetail(id: " Dune (2021) ", type: .movie)
        let requestURL = try Self.require(capture.firstURL())

        #expect(Self.queryValue("i", in: requestURL) == nil)
        #expect(Self.queryValue("t", in: requestURL) == "Dune")
        #expect(Self.queryValue("y", in: requestURL) == "2021")
        #expect(Self.queryValue("type", in: requestURL) == "movie")
        #expect(item.id == "tt1160419")
    }

    @Test
    func detailFallbackIDPreservesYearWhenIMDbIDIsMissing() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            return try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "Dune",
                  "Year": "1984",
                  "Runtime": "137 min",
                  "Poster": "N/A",
                  "imdbRating": "6.3",
                  "Type": "movie",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let item = try await service.getDetail(id: "Dune (1984)", type: .movie)
        let requestURL = try Self.require(capture.firstURL())

        #expect(Self.queryValue("t", in: requestURL) == "Dune")
        #expect(Self.queryValue("y", in: requestURL) == "1984")
        #expect(item.id == "Dune (1984)")
        #expect(item.title == "Dune")
        #expect(item.year == 1984)
    }

    @Test
    func searchDropsUnsafePosterURLsFromOMDbResults() async throws {
        let session = URLProtocolHarness.makeSession { request in
            try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Search": [
                    {
                      "Title": "Unsafe Poster",
                      "Year": "2024",
                      "imdbID": "tt1111111",
                      "Type": "movie",
                      "Poster": "javascript:alert(1)"
                    },
                    {
                      "Title": "Local Poster",
                      "Year": "2024",
                      "imdbID": "tt2222222",
                      "Type": "movie",
                      "Poster": "file:///Users/example/private.png"
                    },
                    {
                      "Title": "Unknown Host Poster",
                      "Year": "2024",
                      "imdbID": "tt2222223",
                      "Type": "movie",
                      "Poster": "https://example.com/tracker.jpg"
                    },
                    {
                      "Title": "Safe Poster",
                      "Year": "2024",
                      "imdbID": "tt3333333",
                      "Type": "movie",
                      "Poster": "https://m.media-amazon.com/images/M/safe.jpg"
                    }
                  ],
                  "totalResults": "3",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let result = try await service.search(query: "poster", type: .movie, page: 1)

        #expect(result.items.map(\.posterPath) == [nil, nil, nil, "https://m.media-amazon.com/images/M/safe.jpg"])
    }

    @Test
    func detailDropsUnsafePosterURLFromOMDbResult() async throws {
        let session = URLProtocolHarness.makeSession { request in
            try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "Unsafe Detail",
                  "Year": "2024",
                  "Runtime": "101 min",
                  "Poster": "data:text/html,<script>alert(1)</script>",
                  "imdbRating": "6.5",
                  "imdbID": "tt4444444",
                  "Type": "movie",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let item = try await service.getDetail(id: "tt4444444", type: .movie)

        #expect(item.posterPath == nil)
        #expect(item.posterURL == nil)
        #expect(item.hasArtwork == false)
    }

    @Test
    func detailDropsUnknownHTTPSPosterHostFromOMDbResult() async throws {
        let session = URLProtocolHarness.makeSession { request in
            try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "Unknown Host Detail",
                  "Year": "2024",
                  "Runtime": "101 min",
                  "Poster": "https://example.com/poster.jpg",
                  "imdbRating": "6.5",
                  "imdbID": "tt5555555",
                  "Type": "movie",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let item = try await service.getDetail(id: "tt5555555", type: .movie)

        #expect(item.posterPath == nil)
        #expect(item.posterURL == nil)
        #expect(item.hasArtwork == false)
    }

    @Test
    func detailDropsOMDbPlaceholderFieldsBeforeTheyReachUI() async throws {
        let session = URLProtocolHarness.makeSession { request in
            try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "N/A",
                  "Year": "N/A",
                  "Rated": "n/a",
                  "Runtime": "N/A",
                  "Genre": "N/A",
                  "Plot": "n/a",
                  "Poster": "N/A",
                  "imdbRating": "N/A",
                  "imdbID": "tt6666666",
                  "Type": "movie",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let item = try await service.getDetail(id: "tt6666666", type: .movie)

        #expect(item.title == "Unknown")
        #expect(item.year == nil)
        #expect(item.status == nil)
        #expect(item.runtime == nil)
        #expect(item.genres.isEmpty)
        #expect(item.overview == nil)
        #expect(item.posterPath == nil)
        #expect(item.posterURL == nil)
        #expect(item.imdbRating == nil)
        #expect(item.hasArtwork == false)
    }

    @Test
    func detailFiltersPlaceholderGenresWithoutDroppingRealGenres() async throws {
        let session = URLProtocolHarness.makeSession { request in
            try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "Genre Fixture",
                  "Year": "2024",
                  "Rated": "PG",
                  "Runtime": "95 min",
                  "Genre": "Action, n/a, Drama, N/A",
                  "Poster": "https://m.media-amazon.com/images/M/genre-fixture.jpg",
                  "imdbRating": "7.1",
                  "imdbID": "tt7777777",
                  "Type": "movie",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let item = try await service.getDetail(id: "tt7777777", type: .movie)

        #expect(item.genres == ["Action", "Drama"])
        #expect(item.imdbRating == 7.1)
        #expect(item.posterPath == "https://m.media-amazon.com/images/M/genre-fixture.jpg")
    }

    @Test
    func episodesUseSeriesIMDbIDAsMediaID() async throws {
        let session = URLProtocolHarness.makeSession { request in
            try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "Example Show",
                  "Season": "1",
                  "Episodes": [
                    {
                      "Title": "Pilot",
                      "Released": "2024-01-01",
                      "Episode": "1",
                      "imdbRating": "7.8",
                      "imdbID": "tt9990001"
                    }
                  ],
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let episodes = try await service.getEpisodes(id: "tt7654321", type: .series, season: 1)
        let episode = try Self.require(episodes.first)

        #expect(episode.id == "tt9990001")
        #expect(episode.mediaId == "tt7654321")
        #expect(episode.seasonNumber == 1)
        #expect(episode.episodeNumber == 1)
        #expect(episode.title == "Pilot")
    }

    @Test
    func episodesIgnoreNonSeriesLookupsEvenWithIMDbID() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            return try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Response": "False",
                  "Error": "Should not be requested"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let episodes = try await service.getEpisodes(id: "tt1160419", type: .movie, season: 1)

        #expect(episodes.isEmpty)
        #expect(capture.urls().isEmpty)
    }

    @Test
    func episodesIgnoreNonPositiveSeasonsWithoutNetworkLookup() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            return try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Response": "False",
                  "Error": "Should not be requested"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let zeroSeasonEpisodes = try await service.getEpisodes(id: "tt7654321", type: .series, season: 0)
        let negativeSeasonEpisodes = try await service.getEpisodes(id: "Example Show", type: .series, season: -1)

        #expect(zeroSeasonEpisodes.isEmpty)
        #expect(negativeSeasonEpisodes.isEmpty)
        #expect(capture.urls().isEmpty)
    }

    @Test
    func seasonsResolveTitleToIMDbBackedSeriesDetail() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            return try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "Example Show",
                  "Year": "2024",
                  "Type": "series",
                  "imdbID": "tt7654321",
                  "totalSeasons": "2",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let seasons = try await service.getSeasons(id: " Example Show ", type: .series)
        let requestURL = try Self.require(capture.firstURL())

        #expect(Self.queryValue("t", in: requestURL) == "Example Show")
        #expect(Self.queryValue("type", in: requestURL) == "series")
        #expect(seasons.map(\.seasonNumber) == [1, 2])
    }

    @Test
    func seasonsPopulateEpisodeCountsFromSeasonResponses() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            let requestURL = try Self.require(request.url)
            switch Self.queryValue("Season", in: requestURL) {
            case "1":
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Example Show",
                      "Season": "1",
                      "Episodes": [
                        { "Title": "Pilot", "Released": "2024-01-01", "Episode": "1", "imdbID": "tt9000001" },
                        { "Title": "Second", "Released": "2024-01-08", "Episode": "2", "imdbID": "tt9000002" }
                      ],
                      "Response": "True"
                    }
                    """
                )
            case "2":
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Example Show",
                      "Season": "2",
                      "Episodes": [
                        { "Title": "Return", "Released": "2025-01-01", "Episode": "1", "imdbID": "tt9000101" }
                      ],
                      "Response": "True"
                    }
                    """
                )
            default:
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Example Show",
                      "Year": "2024",
                      "Type": "series",
                      "imdbID": "tt7654321",
                      "totalSeasons": "2",
                      "Response": "True"
                    }
                    """
                )
            }
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let seasons = try await service.getSeasons(id: "Example Show", type: .series)
        let requestURLs = capture.urls()

        #expect(seasons.map(\.seasonNumber) == [1, 2])
        #expect(seasons.map(\.episodeCount) == [2, 1])
        #expect(requestURLs.count == 3)
        #expect(Self.queryValue("t", in: try Self.require(requestURLs.first)) == "Example Show")
        let seasonURLs = Array(requestURLs.dropFirst()).sorted {
            (Self.queryValue("Season", in: $0) ?? "") < (Self.queryValue("Season", in: $1) ?? "")
        }
        let seasonOneURL = try Self.require(seasonURLs.first)
        let seasonTwoURL = try Self.require(seasonURLs.dropFirst().first)
        #expect(Self.queryValue("i", in: seasonOneURL) == "tt7654321")
        #expect(Self.queryValue("Season", in: seasonOneURL) == "1")
        #expect(Self.queryValue("i", in: seasonTwoURL) == "tt7654321")
        #expect(Self.queryValue("Season", in: seasonTwoURL) == "2")
    }

    @Test
    func getSeasonsSplitsTitleYearLookupIntoOMDbTitleAndYearParameters() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            return try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "Example Show",
                  "Year": "2024",
                  "Type": "series",
                  "imdbID": "tt7654321",
                  "totalSeasons": "2",
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let seasons = try await service.getSeasons(id: " Example Show (2024) ", type: .series)
        let requestURL = try Self.require(capture.firstURL())

        #expect(Self.queryValue("t", in: requestURL) == "Example Show")
        #expect(Self.queryValue("y", in: requestURL) == "2024")
        #expect(Self.queryValue("type", in: requestURL) == "series")
        #expect(seasons.map(\.seasonNumber) == [1, 2])
    }

    @Test
    func episodesResolveTitleToIMDbBeforeSeasonRequest() async throws {
        let capture = RequestCapture()
        let session = URLProtocolHarness.makeSession { request in
            capture.record(request)
            let requestURL = try Self.require(request.url)
            if Self.queryValue("t", in: requestURL) == "Example Show" {
                return try Self.jsonResponse(
                    for: request,
                    body: """
                    {
                      "Title": "Example Show",
                      "Year": "2024",
                      "Type": "series",
                      "imdbID": "tt7654321",
                      "totalSeasons": "2",
                      "Response": "True"
                    }
                    """
                )
            }

            return try Self.jsonResponse(
                for: request,
                body: """
                {
                  "Title": "Example Show",
                  "Season": "2",
                  "Episodes": [
                    {
                      "Title": "Second Season",
                      "Released": "2024-02-01",
                      "Episode": "1",
                      "imdbID": "tt9990002"
                    }
                  ],
                  "Response": "True"
                }
                """
            )
        }
        let service = OMDbService(apiKey: "test-key", session: session)

        let episodes = try await service.getEpisodes(id: "Example Show", type: .series, season: 2)
        let requestURLs = capture.urls()
        let episode = try Self.require(episodes.first)

        #expect(requestURLs.count == 2)
        #expect(Self.queryValue("t", in: try Self.require(requestURLs.first)) == "Example Show")
        #expect(Self.queryValue("i", in: try Self.require(requestURLs.last)) == "tt7654321")
        #expect(Self.queryValue("Season", in: try Self.require(requestURLs.last)) == "2")
        #expect(episode.id == "tt9990002")
        #expect(episode.mediaId == "tt7654321")
    }

    private static func jsonResponse(for request: URLRequest, body: String) throws -> (HTTPURLResponse, Data) {
        let url = try Self.require(request.url)
        let response = try Self.require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ))
        return (response, Data(body.utf8))
    }

    private static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw OMDbServiceTestError.missingRequiredValue }
        return value
    }

    private static func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}

private enum OMDbServiceTestError: Error {
    case missingRequiredValue
}

private final class RequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }

    func firstURL() -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return requests.first?.url
    }

    func urls() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return requests.compactMap(\.url)
    }
}
