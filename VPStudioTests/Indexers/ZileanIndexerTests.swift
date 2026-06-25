import Foundation
import Testing
@testable import VPStudio

@Suite("ZileanIndexer")
struct ZileanIndexerTests {
    @Test func searchByIMDbUsesConfiguredEndpointAndAllowsUntokenizedEpisodeTitles() async throws {
        final class State: @unchecked Sendable {
            var capturedPath: String?
            var queryItems: [URLQueryItem] = []
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.capturedPath = url.path
            state.queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"info_hash":"untokenized","raw_title":"Complete Season Pack","size":3000},
                {"info_hash":"episode-match","raw_title":"Show S01E02 1080p","size":2000},
                {"info_hash":"wrong-episode","raw_title":"Show S01E03 1080p","size":4000},
                {"info_hash":"","raw_title":"Missing Hash","size":1000},
                {"raw_title":"Nil Hash","size":1000}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", endpointPath: "/custom", session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: 1, episode: 2)

        #expect(state.capturedPath == "/custom/dmm/filtered")
        #expect(state.queryItems.first(where: { $0.name == "imdbId" })?.value == "tt1234567")
        #expect(state.queryItems.first(where: { $0.name == "season" })?.value == "1")
        #expect(state.queryItems.first(where: { $0.name == "episode" })?.value == "2")
        #expect(results.map { $0.infoHash } == ["untokenized", "episode-match"])
        #expect(results.first?.title == "Complete Season Pack")
        #expect(results.first?.sizeBytes == 3000)
        #expect(results.allSatisfy { $0.indexerName == "Zilean" })
    }

    @Test func searchByQueryRequiresEpisodeTokensWhenQueryContainsEpisodeContext() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"info_hash":"season-pack","raw_title":"Complete Season Pack","size":3000},
                {"info_hash":"episode-match","raw_title":"Show S02E04 720p","size":2000},
                {"info_hash":"wrong-episode","raw_title":"Show S02E05 720p","size":2000}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        let results = try await indexer.searchByQuery(query: "Show S02E04", type: .series)

        #expect(results.map { $0.infoHash } == ["episode-match"])
    }

    @Test func localHttpBaseURLIsAllowedForSelfHostedZilean() async throws {
        let state = URLProtocolState()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.url = url
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [{"info_hash":"hash"}]
            """
            return (response, Data(body.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "http://127.0.0.1:9696", session: session)
        _ = try await indexer.searchByQuery(query: "Movie", type: MediaType.movie)

        #expect(state.url?.scheme == "http")
        #expect(state.url?.host == "127.0.0.1")
        #expect(state.url?.path == "/api/dmm/search")
    }

    @Test func emptyEndpointPathDefaultsToApiForSearchRequests() async throws {
        let state = URLProtocolState()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.path = url.path
            state.queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[{"info_hash":"hash"}]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", endpointPath: "", session: session)
        _ = try await indexer.searchByQuery(query: "Movie", type: MediaType.movie)

        #expect(state.path == "/api/dmm/search")
        #expect(state.queryItems.first(where: { $0.name == "query" })?.value == "Movie")
    }

    @Test func normalizesEndpointPathAndKeepsBasePath() async throws {
        let state = URLProtocolState()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.path = url.path
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[{"info_hash":"hash"}]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example/root/", endpointPath: "/custom/", session: session)
        _ = try await indexer.searchByQuery(query: "Movie", type: MediaType.movie)

        #expect(state.path == "/root/custom/dmm/search")
    }

    @Test func baseURLWithApiPathAndEmptyEndpointDoesNotDuplicateApiSegment() async throws {
        let state = URLProtocolState()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.path = url.path
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[{"info_hash":"hash"}]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example/api", endpointPath: "", session: session)
        _ = try await indexer.searchByQuery(query: "Movie", type: MediaType.movie)

        #expect(state.path == "/api/dmm/search")
    }

    @Test func baseURLWithApiPathAndEmptyEndpointDoesNotDuplicateApiSegmentForIMDbSearch() async throws {
        let state = URLProtocolState()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.path = url.path
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[{"info_hash":"hash"}]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example/api", endpointPath: "", session: session)
        _ = try await indexer.search(imdbId: "tt123", type: MediaType.movie, season: nil, episode: nil)

        #expect(state.path == "/api/dmm/filtered")
    }

    @Test func emptyEndpointPathDefaultsToApiForIMDbSearch() async throws {
        let state = URLProtocolState()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.path = url.path
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[{"info_hash":"hash"}]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", endpointPath: "", session: session)
        _ = try await indexer.search(imdbId: "tt123", type: MediaType.movie, season: nil, episode: nil)

        #expect(state.path == "/api/dmm/filtered")
    }

    @Test func imdbSearchWithPartialEpisodeContextKeepsQueryItemAndDoesNotFilterResults() async throws {
        let state = URLProtocolState()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"info_hash":"season-only-one","raw_title":"Show Complete Pack","size":3000},
                {"info_hash":"season-only-two","raw_title":"Different Title","size":2000}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        let results = try await indexer.search(imdbId: "tt123", type: .series, season: 3, episode: nil)

        #expect(state.queryItems.first(where: { $0.name == "season" })?.value == "3")
        #expect(state.queryItems.contains(where: { $0.name == "episode" }) == false)
        #expect(results.map(\.infoHash) == ["season-only-one", "season-only-two"])
    }

    @Test func missingTitleAndSizeUseSafeDefaults() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[{"info_hash":"hash-with-defaults"}]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        let results = try await indexer.searchByQuery(query: "Movie", type: MediaType.movie)

        #expect(results.count == 1)
        #expect(results.first?.title == "Unknown")
        #expect(results.first?.sizeBytes == 0)
    }

    @Test func invalidBaseURLsAndNonSuccessResponsesThrow() async throws {
        let httpIndexer = ZileanIndexer(baseURL: "http://zilean.example", session: URLProtocolHarness.makeSession { request in
            Issue.record("Unexpected request for unsupported URL: \(request.url?.absoluteString ?? "nil")")
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        })

        do {
            _ = try await httpIndexer.searchByQuery(query: "Movie", type: MediaType.movie)
            Issue.record("Expected URLError.unsupportedURL")
        } catch let error as URLError {
            #expect(error.code == .unsupportedURL)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        let failingSession = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let failingIndexer = ZileanIndexer(baseURL: "https://zilean.example", session: failingSession)

        await #expect(throws: URLError.self) {
            _ = try await failingIndexer.searchByQuery(query: "Movie", type: MediaType.movie)
        }
    }

    @Test func requestHandlesNetworkErrors() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        await #expect(throws: URLError.self) {
            _ = try await indexer.searchByQuery(query: "Test", type: MediaType.movie)
        }
    }
}

private final class URLProtocolState: @unchecked Sendable {
    var path: String = ""
    var url: URL?
    var queryItems: [URLQueryItem] = []
}
