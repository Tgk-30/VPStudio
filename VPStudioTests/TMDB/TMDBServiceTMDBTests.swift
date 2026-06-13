import Testing
import Foundation
@testable import VPStudio

private func makeStubSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    URLProtocolHarness.makeSession(handler: handler)
}

// MARK: - TMDBService API Request Construction Tests

@Suite("TMDBService - API Request Construction")
struct TMDBServiceAPIRequestConstructionTests {

    @Test func trendingMoviePath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.getTrending(type: .movie, timeWindow: .week)

        #expect(recorder.path == "/3/trending/movie/week")
    }

    @Test func trendingTVPath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.getTrending(type: .series, timeWindow: .day)

        #expect(recorder.path == "/3/trending/tv/day")
    }

    @Test func categoryMoviePath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.getCategory(.nowPlaying, type: .movie)

        #expect(recorder.path == "/3/movie/now_playing")
    }

    @Test func categoryTVPath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.getCategory(.popular, type: .series)

        #expect(recorder.path == "/3/tv/popular")
    }

    @Test func discoverMoviePath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.discover(type: .movie, filters: DiscoverFilters())

        #expect(recorder.path == "/3/discover/movie")
    }

    @Test func discoverTVPath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.discover(type: .series, filters: DiscoverFilters())

        #expect(recorder.path == "/3/discover/tv")
    }

    @Test func getDetailPath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"id":123,"title":"Test","external_ids":{"imdb_id":"tt123"}}"#
            return (response, Data(body.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.getDetail(id: "123", type: .movie)

        #expect(recorder.path == "/3/movie/123")
    }

    @Test func getGenresPath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"genres":[]}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.getGenres(type: .movie)

        #expect(recorder.path == "/3/genre/movie/list")
    }

    @Test func getSeasonsPath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":1399}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.getSeasons(tmdbId: 1399)

        #expect(recorder.path == "/3/tv/1399")
    }

    @Test func getEpisodesPath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"episodes":[]}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.getEpisodes(tmdbId: 1399, season: 1)

        #expect(recorder.path == "/3/tv/1399/season/1")
    }

    @Test func getExternalIdsMoviePath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"imdb_id":"tt123"}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.getExternalIds(tmdbId: 123, type: .movie)

        #expect(recorder.path == "/3/movie/123/external_ids")
    }

    @Test func findByIMDBIdPath() async throws {
        final class PathRecorder: @unchecked Sendable { var path: String? }
        let recorder = PathRecorder()

        let session = makeStubSession { request in
            recorder.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movie_results":[],"tv_results":[]}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.findByImdbId("tt1160419", type: .movie)

        #expect(recorder.path == "/3/find/tt1160419")
    }

    @Test func searchMovieIncludesYearFilter() async throws {
        final class QueryRecorder: @unchecked Sendable { var queryItems: [URLQueryItem] = [] }
        let recorder = QueryRecorder()

        let session = makeStubSession { request in
            let url = try #require(request.url)
            recorder.queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        _ = try await service.search(query: "Dune", type: .movie, page: 1, year: 2021, language: nil)

        #expect(recorder.queryItems.first(where: { $0.name == "year" })?.value == "2021")
        #expect(recorder.queryItems.first(where: { $0.name == "first_air_date_year" }) == nil)
    }
}

// MARK: - TMDBService Response Parsing Tests

@Suite("TMDBService - Response Parsing")
struct TMDBServiceResponseParsingTests {

    @Test func searchReturnsMetadataSearchResult() async throws {
        let json = """
        {
            "page": 1,
            "results": [
                {"id": 1, "title": "Movie A", "media_type": "movie", "release_date": "2024-01-01", "vote_average": 7.0},
                {"id": 2, "name": "Show B", "media_type": "tv", "first_air_date": "2024-02-01", "vote_average": 8.0}
            ],
            "total_pages": 5,
            "total_results": 100
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        let result = try await service.search(query: "Test", type: nil)

        #expect(result.page == 1)
        #expect(result.totalPages == 5)
        #expect(result.totalResults == 100)
        #expect(result.items.count == 2)
        #expect(result.items[0].title == "Movie A")
        #expect(result.items[1].title == "Show B")
    }

    @Test func searchFiltersOutResultsWithEmptyTitle() async throws {
        let json = """
        {
            "page": 1,
            "results": [
                {"id": 1, "title": "Valid Movie", "media_type": "movie", "release_date": "2024-01-01", "vote_average": 7.0},
                {"id": 2, "title": null, "name": null, "media_type": "movie", "release_date": "2024-01-01", "vote_average": 8.0},
                {"id": 3, "title": "", "name": "", "media_type": "movie", "release_date": "2024-01-01", "vote_average": 9.0}
            ],
            "total_pages": 1,
            "total_results": 3
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        let result = try await service.search(query: "Test", type: nil)

        #expect(result.items.count == 1)
        #expect(result.items[0].title == "Valid Movie")
    }

    @Test func getDetailReturnsCompleteMediaItem() async throws {
        let json = """
        {
            "id": 123,
            "title": "Test Movie",
            "overview": "A compelling story",
            "poster_path": "/poster.jpg",
            "backdrop_path": "/backdrop.jpg",
            "release_date": "2024-06-15",
            "vote_average": 8.5,
            "runtime": 135,
            "status": "Released",
            "genres": [
                {"id": 28, "name": "Action"},
                {"id": 12, "name": "Adventure"},
                {"id": 878, "name": "Science Fiction"}
            ],
            "external_ids": {"imdb_id": "tt1234567", "tvdb_id": null}
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        let item = try await service.getDetail(id: "123", type: .movie)

        #expect(item.id == "tt1234567")
        #expect(item.title == "Test Movie")
        #expect(item.year == 2024)
        #expect(item.overview == "A compelling story")
        #expect(item.posterPath == "/poster.jpg")
        #expect(item.backdropPath == "/backdrop.jpg")
        #expect(item.imdbRating == 8.5)
        #expect(item.runtime == 135)
        #expect(item.status == "Released")
        #expect(item.genres == ["Action", "Adventure", "Science Fiction"])
        #expect(item.tmdbId == 123)
    }

    @Test func getDetailUsesEpisodeRunTimeWhenRuntimeIsZero() async throws {
        let json = """
        {
            "id": 456,
            "name": "Test Series",
            "runtime": 0,
            "episodeRunTime": [42, 55],
            "status": "Returning Series",
            "external_ids": {"imdb_id": null, "tvdb_id": 12345}
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        let item = try await service.getDetail(id: "456", type: .series)

        #expect(item.runtime == 42)
        #expect(item.id == "tmdb-456")
    }

    @Test func getSeasonsParsesSeasonList() async throws {
        let json = """
        {
            "id": 1399,
            "seasons": [
                {"id": 1, "season_number": 0, "name": "Specials", "overview": "Special episodes", "poster_path": "/s0.jpg", "episode_count": 0, "air_date": "2010-04-17"},
                {"id": 10, "season_number": 1, "name": "Season 1", "overview": "First season", "poster_path": "/s1.jpg", "episode_count": 10, "air_date": "2011-04-17"},
                {"id": 20, "season_number": 2, "name": "Season 2", "overview": "Second season", "poster_path": "/s2.jpg", "episode_count": 10, "air_date": "2012-04-01"}
            ]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        let seasons = try await service.getSeasons(tmdbId: 1399)

        #expect(seasons.count == 3)
        #expect(seasons[0].seasonNumber == 0)
        #expect(seasons[0].name == "Specials")
        #expect(seasons[0].episodeCount == 0)
        #expect(seasons[1].seasonNumber == 1)
        #expect(seasons[1].name == "Season 1")
        #expect(seasons[1].episodeCount == 10)
    }

    @Test func getEpisodesParsesEpisodeList() async throws {
        let json = """
        {
            "episodes": [
                {"id": 1001, "episode_number": 1, "name": "Winter Is Coming", "overview": "The king dies", "still_path": "/still1.jpg", "runtime": 62, "air_date": "2011-04-17"},
                {"id": 1002, "episode_number": 2, "name": "The Kingsroad", "overview": "Jon joins the Night's Watch", "still_path": "/still2.jpg", "runtime": 58, "air_date": "2011-04-24"},
                {"id": 1003, "episode_number": 3, "name": "Lord Snow", "overview": "Jon trains", "still_path": null, "runtime": null, "air_date": "2011-05-01"}
            ]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        let episodes = try await service.getEpisodes(tmdbId: 1399, season: 1)

        #expect(episodes.count == 3)
        #expect(episodes[0].title == "Winter Is Coming")
        #expect(episodes[0].episodeNumber == 1)
        #expect(episodes[0].runtime == 62)
        #expect(episodes[0].stillPath == "/still1.jpg")
        #expect(episodes[1].title == "The Kingsroad")
        #expect(episodes[2].title == "Lord Snow")
        #expect(episodes[2].stillPath == nil)
        #expect(episodes[2].runtime == nil)
    }

    @Test func getGenresReturnsGenreList() async throws {
        let json = """
        {
            "genres": [
                {"id": 28, "name": "Action"},
                {"id": 12, "name": "Adventure"},
                {"id": 16, "name": "Animation"},
                {"id": 35, "name": "Comedy"},
                {"id": 80, "name": "Crime"},
                {"id": 99, "name": "Documentary"},
                {"id": 18, "name": "Drama"},
                {"id": 10751, "name": "Family"},
                {"id": 14, "name": "Fantasy"},
                {"id": 36, "name": "History"}
            ]
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        let genres = try await service.getGenres(type: .movie)

        #expect(genres.count == 10)
        #expect(genres[0] == Genre(id: 28, name: "Action"))
        #expect(genres[9] == Genre(id: 36, name: "History"))
    }

    @Test func getExternalIdsParsesCorrectly() async throws {
        let json = """
        {
            "imdb_id": "tt1234567",
            "tvdb_id": 456789,
            "facebook_id": "@test",
            "instagram_id": "@test",
            "twitter_id": "@test"
        }
        """

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        let ids = try await service.getExternalIds(tmdbId: 123, type: .movie)

        #expect(ids.imdbId == "tt1234567")
        #expect(ids.tvdbId == 456789)
    }
}

// MARK: - TMDBService Image URL Construction Tests

@Suite("TMDBService - Image URL Construction")
struct TMDBImageURLTests {

    @Test func posterURLUsesW500ForMediaItem() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test", posterPath: "/abc.jpg")
        #expect(item.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w500/abc.jpg")
    }

    @Test func backdropURLUsesOriginalForMediaItem() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test", backdropPath: "/xyz.jpg")
        #expect(item.backdropURL?.absoluteString == "https://image.tmdb.org/t/p/original/xyz.jpg")
    }

    @Test func previewPosterURLUsesW342() {
        let preview = MediaPreview(id: "movie-tmdb-1", type: .movie, title: "Test", posterPath: "/preview.jpg")
        #expect(preview.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w342/preview.jpg")
    }

    @Test func previewBackdropURLUsesW1280() {
        let preview = MediaPreview(id: "movie-tmdb-1", type: .movie, title: "Test", backdropPath: "/backdrop.jpg")
        #expect(preview.backdropURL?.absoluteString == "https://image.tmdb.org/t/p/w1280/backdrop.jpg")
    }

    @Test func imageURLReturnsNilForNilPath() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test", posterPath: nil)
        #expect(item.posterURL == nil)
        #expect(item.backdropURL == nil)

        let preview = MediaPreview(id: "movie-tmdb-1", type: .movie, title: "Test", posterPath: nil)
        #expect(preview.posterURL == nil)
        #expect(preview.backdropURL == nil)
    }

    @Test func imageURLReturnsNilForEmptyPath() {
        let item = MediaItem(id: "tt123", type: .movie, title: "Test", posterPath: "")
        #expect(item.posterURL == nil)

        let preview = MediaPreview(id: "movie-tmdb-1", type: .movie, title: "Test", backdropPath: "")
        #expect(preview.backdropURL == nil)
    }

    @Test func seasonPosterURLFromService() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"id":1399,"seasons":[{"id":10,"season_number":1,"name":"Season 1","poster_path":"/season1.webp","episode_count":10}]}"#
            return (response, Data(body.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        let seasons = try await service.getSeasons(tmdbId: 1399)

        #expect(seasons[0].posterURL?.absoluteString == "https://image.tmdb.org/t/p/w342/season1.webp")
    }

    @Test func episodeStillPathPreserved() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"episodes":[{"id":1,"episode_number":1,"name":"Pilot","still_path":"/still.jpg","runtime":60}]}"#
            return (response, Data(body.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)
        let episodes = try await service.getEpisodes(tmdbId: 1399, season: 1)

        #expect(episodes[0].stillPath == "/still.jpg")
    }
}

// MARK: - TMDBService Error Handling Tests

@Suite("TMDBService - Error Handling")
struct TMDBServiceErrorHandlingTests {

    @Test func unauthorizedErrorFrom401() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TMDBService(apiKey: "invalid", session: session)

        do {
            _ = try await service.search(query: "Test", type: .movie)
            Issue.record("Expected error")
        } catch let error as TMDBError {
            #expect(error == .unauthorized)
        } catch {
            Issue.record("Expected TMDBError, got \(error)")
        }
    }

    @Test func notFoundErrorFrom404() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TMDBService(apiKey: "key", session: session)

        do {
            _ = try await service.getDetail(id: "999999", type: .movie)
            Issue.record("Expected error")
        } catch let error as TMDBError {
            if case .notFound = error {
                // expected
            } else {
                Issue.record("Expected notFound, got \(error)")
            }
        } catch {
            Issue.record("Expected TMDBError, got \(error)")
        }
    }

    @Test func rateLimitedErrorAfterMaxRetries() async throws {
        final class Counter: @unchecked Sendable {
            private let lock = NSLock()
            private var _count = 0
            var count: Int {
                lock.lock(); defer { lock.unlock() }
                return _count
            }
            func increment() {
                lock.lock(); defer { lock.unlock() }
                _count += 1
            }
        }
        let counter = Counter()

        let session = makeStubSession { request in
            counter.increment()
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TMDBService(apiKey: "key", session: session) { _ in
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        do {
            _ = try await service.search(query: "Test", type: .movie)
            Issue.record("Expected rateLimited")
        } catch let error as TMDBError {
            #expect(error == .rateLimited)
            #expect(counter.count == 3)
        } catch {
            Issue.record("Expected TMDBError.rateLimited, got \(error)")
        }
    }

    @Test func httpErrorIncludesBodyInErrorMessage() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("Service Unavailable".utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)

        do {
            _ = try await service.search(query: "Test", type: .movie)
            Issue.record("Expected error")
        } catch let error as TMDBError {
            if case .httpError(let code, let body) = error {
                #expect(code == 500)
                #expect(body == "Service Unavailable")
            } else {
                Issue.record("Expected httpError, got \(error)")
            }
        } catch {
            Issue.record("Expected TMDBError, got \(error)")
        }
    }

    @Test func invalidURLThrownForUnparsableURL() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session)

        do {
            let _: MetadataSearchResult = try await service.search(query: "Test\u{FFFF}", type: .movie)
        } catch let error as TMDBError {
            if case .invalidURL = error {
                // expected
            } else {
                Issue.record("Expected invalidURL, got \(error)")
            }
        } catch {
            // Other errors acceptable for malformed URL
        }
    }

    @Test func emptyApiKeyThrowsUnauthorizedWithoutNetwork() async {
        var called = false
        let session = makeStubSession { request in
            called = true
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TMDBService(apiKey: "", session: session)

        await #expect(throws: TMDBError.unauthorized) {
            _ = try await service.search(query: "Test", type: .movie)
        }

        #expect(called == false)
    }

    @Test func whitespaceApiKeyThrowsUnauthorized() async {
        var called = false
        let service = TMDBService(apiKey: "   ", session: makeStubSession { _ in
            called = true
            let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        })

        await #expect(throws: TMDBError.unauthorized) {
            _ = try await service.search(query: "Test", type: .movie)
        }

        #expect(called == false)
    }
}

// MARK: - TMDBService Retry and Backoff Tests

@Suite("TMDBService - Retry and Backoff")
struct TMDBServiceRetryBackoffTests {

    @Test func retriesWithExponentialBackoff() async throws {
        final class SleepRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _sleeps: [UInt64] = []
            var sleeps: [UInt64] {
                lock.lock(); defer { lock.unlock() }
                return _sleeps
            }
            func record(_ ns: UInt64) {
                lock.lock(); defer { lock.unlock() }
                _sleeps.append(ns)
            }
        }
        let recorder = SleepRecorder()

        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TMDBService(apiKey: "key", session: session) { ns in
            recorder.record(ns)
            try await Task.sleep(nanoseconds: ns)
        }

        do {
            _ = try await service.search(query: "Test", type: .movie)
        } catch {
            // Expected
        }

        #expect(recorder.sleeps.count == 2)
        #expect(recorder.sleeps[0] == 500_000_000)
        #expect(recorder.sleeps[1] == 1_000_000_000)
    }

    @Test func respectsRetryAfterHeader() async throws {
        final class SleepRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _sleeps: [UInt64] = []
            var sleeps: [UInt64] {
                lock.lock(); defer { lock.unlock() }
                return _sleeps
            }
            func record(_ ns: UInt64) {
                lock.lock(); defer { lock.unlock() }
                _sleeps.append(ns)
            }
        }
        let recorder = SleepRecorder()

        let session = makeStubSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "2"]
            )!
            return (response, Data())
        }

        let service = TMDBService(apiKey: "key", session: session) { ns in
            recorder.record(ns)
            try await Task.sleep(nanoseconds: ns)
        }

        do {
            _ = try await service.search(query: "Test", type: .movie)
        } catch {
            // Expected
        }

        #expect(recorder.sleeps.count == 2)
        #expect(recorder.sleeps[0] >= 2_000_000_000)
    }

    @Test func capsBackoffAtMaximum() async throws {
        final class SleepRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _sleeps: [UInt64] = []
            var sleeps: [UInt64] {
                lock.lock(); defer { lock.unlock() }
                return _sleeps
            }
            func record(_ ns: UInt64) {
                lock.lock(); defer { lock.unlock() }
                _sleeps.append(ns)
            }
        }
        let recorder = SleepRecorder()

        let session = makeStubSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "100"]
            )!
            return (response, Data())
        }

        let service = TMDBService(apiKey: "key", session: session) { ns in
            recorder.record(ns)
        }

        do {
            _ = try await service.search(query: "Test", type: .movie)
        } catch {
            // Expected
        }

        #expect(recorder.sleeps.allSatisfy { $0 <= 4_000_000_000 })
    }

    @Test func retryAfterRFC850DateHeaderIsParsedAndCapped() async throws {
        final class SleepRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _sleeps: [UInt64] = []
            var sleeps: [UInt64] {
                lock.lock(); defer { lock.unlock() }
                return _sleeps
            }
            func record(_ ns: UInt64) {
                lock.lock(); defer { lock.unlock() }
                _sleeps.append(ns)
            }
        }
        final class AttemptCounter: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 0
            func next() -> Int {
                lock.lock(); defer { lock.unlock() }
                value += 1
                return value
            }
        }

        let recorder = SleepRecorder()
        let attempts = AttemptCounter()
        let retryAfter = Date(timeIntervalSinceNow: 60)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEEE',' dd-MMM-yy HH':'mm':'ss zzz"

        let session = makeStubSession { request in
            if attempts.next() == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: ["Retry-After": formatter.string(from: retryAfter)]
                )!
                return (response, Data())
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session) { ns in
            recorder.record(ns)
        }
        _ = try await service.search(query: "Test", type: .movie)

        #expect(recorder.sleeps == [4_000_000_000])
    }

    @Test func retryAfterASCTimeDateHeaderIsParsedAndCapped() async throws {
        final class SleepRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var _sleeps: [UInt64] = []
            var sleeps: [UInt64] {
                lock.lock(); defer { lock.unlock() }
                return _sleeps
            }
            func record(_ ns: UInt64) {
                lock.lock(); defer { lock.unlock() }
                _sleeps.append(ns)
            }
        }
        final class AttemptCounter: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 0
            func next() -> Int {
                lock.lock(); defer { lock.unlock() }
                value += 1
                return value
            }
        }

        let recorder = SleepRecorder()
        let attempts = AttemptCounter()
        let retryAfter = Date(timeIntervalSinceNow: 60)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE MMM d HH':'mm':'ss yyyy"

        let session = makeStubSession { request in
            if attempts.next() == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: ["Retry-After": formatter.string(from: retryAfter)]
                )!
                return (response, Data())
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "key", session: session) { ns in
            recorder.record(ns)
        }
        _ = try await service.search(query: "Test", type: .movie)

        #expect(recorder.sleeps == [4_000_000_000])
    }
}

// MARK: - TMDBService Authentication Mode Tests

@Suite("TMDBService - Authentication Mode")
struct TMDBServiceAuthModeTests {

    @Test func bearerPrefixStrippedFromToken() async throws {
        final class AuthRecorder: @unchecked Sendable { var auth: String? }
        let recorder = AuthRecorder()

        let session = makeStubSession { request in
            recorder.auth = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "Bearer my-token-123", session: session)
        _ = try await service.search(query: "Test", type: .movie)

        #expect(recorder.auth == "Bearer my-token-123")
    }

    @Test func classicApiKeyInQueryString() async throws {
        final class QueryRecorder: @unchecked Sendable { var apiKeyValue: String? }
        let recorder = QueryRecorder()

        let session = makeStubSession { request in
            let url = try #require(request.url)
            recorder.apiKeyValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "api_key" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "abc123def456", session: session)
        _ = try await service.search(query: "Test", type: .movie)

        #expect(recorder.apiKeyValue == "abc123def456")
        #expect(recorder.apiKeyValue != nil)
    }

    @Test func jwtTokenDetectedAndUsedAsBearer() async throws {
        final class AuthRecorder: @unchecked Sendable { var auth: String? }
        let recorder = AuthRecorder()

        let session = makeStubSession { request in
            recorder.auth = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdGltZXIiOiIxMjM0NTY3ODkwIn0.signature"
        let service = TMDBService(apiKey: jwt, session: session)
        _ = try await service.search(query: "Test", type: .movie)

        #expect(recorder.auth == "Bearer \(jwt)")
    }

    @Test func apiKeyQueryOmitsAuthorizationHeader() async throws {
        final class AuthRecorder: @unchecked Sendable { var auth: String? }
        let recorder = AuthRecorder()

        let session = makeStubSession { request in
            recorder.auth = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let service = TMDBService(apiKey: "legacy-api-key-123", session: session)
        _ = try await service.search(query: "Test", type: .movie)

        #expect(recorder.auth == nil)
    }

    @Test func malformedJWTLikeCredentialFallsBackToAPIKeyQuery() async throws {
        final class RequestRecorder: @unchecked Sendable {
            var authorization: String?
            var apiKey: String?
        }
        let recorder = RequestRecorder()

        let session = makeStubSession { request in
            recorder.authorization = request.value(forHTTPHeaderField: "Authorization")
            recorder.apiKey = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "api_key" })?.value
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"page":1,"results":[],"total_pages":0,"total_results":0}"#.utf8))
        }

        let credential = "header..signature+"
        let service = TMDBService(apiKey: credential, session: session)
        _ = try await service.search(query: "Test", type: .movie)

        #expect(recorder.authorization == nil)
        #expect(recorder.apiKey == credential)
    }
}

// MARK: - TMDBSearchResult.toMediaPreview Tests

@Suite("TMDBSearchResult - toMediaPreview")
struct TMDBSearchResultMediaPreviewTests {

    @Test func movieResultCreatesCorrectMediaPreview() {
        let result = TMDBSearchResult(
            id: 123,
            title: "Inception",
            name: nil,
            mediaType: "movie",
            overview: "A mind-bending thriller",
            posterPath: "/inception.jpg",
            backdropPath: "/inception_bg.jpg",
            releaseDate: "2010-07-16",
            firstAirDate: nil,
            voteAverage: 8.8
        )

        let preview = result.toMediaPreview()

        #expect(preview != nil)
        #expect(preview?.id == "movie-tmdb-123")
        #expect(preview?.type == .movie)
        #expect(preview?.title == "Inception")
        #expect(preview?.year == 2010)
        #expect(preview?.posterPath == "/inception.jpg")
        #expect(preview?.backdropPath == "/inception_bg.jpg")
        #expect(preview?.imdbRating == 8.8)
        #expect(preview?.tmdbId == 123)
    }

    @Test func tvResultCreatesCorrectMediaPreview() {
        let result = TMDBSearchResult(
            id: 456,
            title: nil,
            name: "The Office",
            mediaType: "tv",
            overview: "A mockumentary",
            posterPath: "/office.jpg",
            backdropPath: "/office_bg.jpg",
            releaseDate: nil,
            firstAirDate: "2005-03-24",
            voteAverage: 9.0
        )

        let preview = result.toMediaPreview()

        #expect(preview != nil)
        #expect(preview?.id == "series-tmdb-456")
        #expect(preview?.type == .series)
        #expect(preview?.title == "The Office")
        #expect(preview?.year == 2005)
    }

    @Test func personMediaTypeReturnsNil() {
        let result = TMDBSearchResult(
            id: 789,
            title: "Actor Name",
            name: nil,
            mediaType: "person",
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: nil,
            firstAirDate: nil,
            voteAverage: nil
        )

        #expect(result.toMediaPreview() == nil)
    }

    @Test func emptyTitleAndNameReturnsNil() {
        let result = TMDBSearchResult(
            id: 100,
            title: nil,
            name: nil,
            mediaType: "movie",
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: nil,
            firstAirDate: nil,
            voteAverage: nil
        )

        #expect(result.toMediaPreview() == nil)
    }

    @Test func infersMovieFromTitleWhenNoMediaType() {
        let result = TMDBSearchResult(
            id: 200,
            title: "Standalone Movie",
            name: nil,
            mediaType: nil,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "2024-01-01",
            firstAirDate: nil,
            voteAverage: nil
        )

        #expect(result.toMediaPreview()?.type == .movie)
    }

    @Test func infersSeriesFromNameWhenNoMediaType() {
        let result = TMDBSearchResult(
            id: 300,
            title: nil,
            name: "Standalone Show",
            mediaType: nil,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: nil,
            firstAirDate: "2024-01-01",
            voteAverage: nil
        )

        #expect(result.toMediaPreview()?.type == .series)
    }

    @Test func extractsYearFromPartialDate() {
        let result = TMDBSearchResult(
            id: 400,
            title: "Movie",
            name: nil,
            mediaType: "movie",
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "2024-12",
            firstAirDate: nil,
            voteAverage: nil
        )

        #expect(result.toMediaPreview()?.year == 2024)
    }

    @Test func extractsYearFromFirstAirDate() {
        let result = TMDBSearchResult(
            id: 500,
            title: nil,
            name: "Show",
            mediaType: "tv",
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: nil,
            firstAirDate: "2023-06-15",
            voteAverage: nil
        )

        #expect(result.toMediaPreview()?.year == 2023)
    }
}

// MARK: - TMDBDetailResponse.toMediaItem Tests

@Suite("TMDBDetailResponse - toMediaItem")
struct TMDBDetailResponseMediaItemTests {

    @Test func movieDetailConvertsCorrectly() {
        let response = TMDBDetailResponse(
            id: 123,
            title: "Dune Part Two",
            name: nil,
            overview: "Paul Atreides unites with Chani and the Fremen",
            posterPath: "/dune2.jpg",
            backdropPath: "/dune2_bg.jpg",
            releaseDate: "2024-02-27",
            firstAirDate: nil,
            voteAverage: 8.6,
            runtime: 166,
            episodeRunTime: nil,
            status: "Released",
            genres: [
                TMDBGenre(id: 878, name: "Science Fiction"),
                TMDBGenre(id: 12, name: "Adventure")
            ],
            externalIds: ExternalIds(imdbId: "tt15239678", tvdbId: nil)
        )

        let item = response.toMediaItem(type: .movie)

        #expect(item.id == "tt15239678")
        #expect(item.title == "Dune Part Two")
        #expect(item.year == 2024)
        #expect(item.overview == "Paul Atreides unites with Chani and the Fremen")
        #expect(item.posterPath == "/dune2.jpg")
        #expect(item.backdropPath == "/dune2_bg.jpg")
        #expect(item.imdbRating == 8.6)
        #expect(item.runtime == 166)
        #expect(item.status == "Released")
        #expect(item.genres == ["Science Fiction", "Adventure"])
        #expect(item.tmdbId == 123)
    }

    @Test func seriesDetailConvertsCorrectly() {
        let response = TMDBDetailResponse(
            id: 456,
            title: nil,
            name: "Severance",
            overview: "Mark leads a team of employees",
            posterPath: "/severance.jpg",
            backdropPath: "/severance_bg.jpg",
            releaseDate: nil,
            firstAirDate: "2022-02-18",
            voteAverage: 8.7,
            runtime: 0,
            episodeRunTime: [50, 60],
            status: "Returning Series",
            genres: [
                TMDBGenre(id: 18, name: "Drama"),
                TMDBGenre(id: 878, name: "Science Fiction")
            ],
            externalIds: ExternalIds(imdbId: "tt11280740", tvdbId: 364150)
        )

        let item = response.toMediaItem(type: .series)

        #expect(item.id == "tt11280740")
        #expect(item.title == "Severance")
        #expect(item.year == 2022)
        #expect(item.runtime == 50)
        #expect(item.genres == ["Drama", "Science Fiction"])
    }

    @Test func fallsBackToTmdbIdWhenNoIMDB() {
        let response = TMDBDetailResponse(
            id: 789,
            title: "Unknown Movie",
            name: nil,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "2024-01-01",
            firstAirDate: nil,
            voteAverage: nil,
            runtime: nil,
            episodeRunTime: nil,
            status: nil,
            genres: nil,
            externalIds: ExternalIds(imdbId: nil, tvdbId: nil)
        )

        let item = response.toMediaItem(type: .movie)

        #expect(item.id == "tmdb-789")
    }

    @Test func usesFirstEpisodeRunTimeWhenRuntimeIsZero() {
        let response = TMDBDetailResponse(
            id: 100,
            title: nil,
            name: "Show",
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: nil,
            firstAirDate: "2020-01-01",
            voteAverage: nil,
            runtime: 0,
            episodeRunTime: [25, 30, 35],
            status: nil,
            genres: nil,
            externalIds: nil
        )

        let item = response.toMediaItem(type: .series)

        #expect(item.runtime == 25)
    }

    @Test func usesRuntimeWhenSet() {
        let response = TMDBDetailResponse(
            id: 200,
            title: "Movie",
            name: nil,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "2024-01-01",
            firstAirDate: nil,
            voteAverage: nil,
            runtime: 120,
            episodeRunTime: [25],
            status: nil,
            genres: nil,
            externalIds: nil
        )

        let item = response.toMediaItem(type: .movie)

        #expect(item.runtime == 120)
    }
}
