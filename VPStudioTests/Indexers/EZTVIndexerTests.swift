import Foundation
import Testing
@testable import VPStudio

@Suite("EZTVIndexer")
struct EZTVIndexerTests {
    @Test func searchByQueryNormalizesBasePathAndTrailingSlash() async throws {
        final class State: @unchecked Sendable {
            var requestPath: String?
            var page: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.requestPath = url.path
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.page = components?.queryItems?.first(where: { $0.name == "page" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(baseURL: "https://eztv.example/base/", session: session)
        _ = try await indexer.searchByQuery(query: "show", type: .series)

        #expect(state.requestPath == "/base/get-torrents")
        #expect(state.page == "1")
    }

    @Test func searchByIMDbStripsTTAndConstructsCorrectURL() async throws {
        final class State: @unchecked Sendable {
            var capturedIMDbID: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.capturedIMDbID = components?.queryItems?.first(where: { $0.name == "imdb_id" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"test-hash","title":"Show.S01E01.720p.mkv","season":"1","episode":"1","seeds":10,"peers":2,"size_bytes":"12345","magnet_url":"magnet:?xt=urn:btih:test-hash"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: 1, episode: 1)

        #expect(state.capturedIMDbID == "1234567")
        #expect(results.count == 1)
        #expect(results.first?.infoHash == "test-hash")
        #expect(results.first?.title == "Show.S01E01.720p.mkv")
    }

    @Test func searchByIMDbNormalizesEmbeddedID() async throws {
        final class State: @unchecked Sendable {
            var capturedIMDbID: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.capturedIMDbID = components?.queryItems?.first(where: { $0.name == "imdb_id" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"torrents":[]}"#.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        _ = try await indexer.search(
            imdbId: "https://www.imdb.com/title/TT1234567/",
            type: .series,
            season: nil,
            episode: nil
        )

        #expect(state.capturedIMDbID == "1234567")
    }

    @Test func searchByIMDbFiltersBySeasonAndEpisode() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"wrong-season","title":"Show S02E01","season":"2","episode":"1","seeds":1,"peers":1,"size_bytes":"1000"},
                {"hash":"wrong-episode","title":"Show S01E02","season":"1","episode":"2","seeds":1,"peers":1,"size_bytes":"1000"},
                {"hash":"correct-match","title":"Show S01E01","season":"1","episode":"1","seeds":5,"peers":1,"size_bytes":"2000","magnet_url":"magnet:?xt=urn:btih:correct-match"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: 1, episode: 1)

        #expect(results.count == 1)
        #expect(results.first?.infoHash == "correct-match")
        #expect(results.first?.seeders == 5)
    }

    @Test func searchByIMDbReturnsEmptyForMissingHash() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"","title":"Missing Hash","season":"1","episode":"1","seeds":1,"peers":1,"size_bytes":"1000"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: 1, episode: 1)

        #expect(results.isEmpty)
    }

    @Test func searchByQueryReturnsEmptyForMovies() async throws {
        let session = URLProtocolHarness.makeSession { request in
            Issue.record("Unexpected EZTV request for movie: \(request.url?.absoluteString ?? "nil")")
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Movie Title", type: .movie)

        #expect(results.isEmpty)
    }

    @Test func searchByQueryReturnsEmptyForEmptyIMDbID() async throws {
        let session = URLProtocolHarness.makeSession { request in
            Issue.record("Unexpected EZTV request for empty IMDb: \(request.url?.absoluteString ?? "nil")")
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt", type: .series, season: nil, episode: nil)

        #expect(results.isEmpty)
    }

    @Test func searchByQueryPaginatesUntilShortPage() async throws {
        final class State: @unchecked Sendable {
            var pages: [String] = []
        }
        let state = State()

        let firstPage = (0..<100).map { index in
            #"{"hash":"page1-\#(index)","title":"Show S01E01","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100","magnet_url":"magnet:?xt=urn:btih:page1-\#(index)"}"#
        }.joined(separator: ",")

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let page = components?.queryItems?.first(where: { $0.name == "page" })?.value ?? "missing"
            state.pages.append(page)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if page == "1" {
                let body = #"{"torrents":["# + firstPage + #"]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"torrents":[{"hash":"page2","season":"1","episode":"1","seeds":9,"peers":2,"size_bytes":"2000","magnet_url":"magnet:?xt=urn:btih:page2"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Show", type: .series)

        #expect(state.pages == ["1", "2"])
        #expect(results.count == 101)
    }

    @Test func searchByQueryFallsBackToTitleTokensWhenEpisodeMetadataIsInvalid() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"zero-metadata","title":"Show S03E04 1080p","season":"0","episode":"0","seeds":4,"peers":1,"size_bytes":"1000"},
                {"hash":"invalid-metadata","title":"Show S03E04 720p","season":"bad","episode":"n/a","seeds":3,"peers":1,"size_bytes":"900"},
                {"hash":"wrong-title","title":"Show S03E05 720p","season":"0","episode":"0","seeds":2,"peers":1,"size_bytes":"800"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Show S03E04", type: .series)

        #expect(results.map(\.infoHash) == ["zero-metadata", "invalid-metadata"])
    }

    @Test func searchByQueryUsesFilenameAndUnknownTitleFallbacksWithMissingStats() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"filename-title","filename":"File.Name.S01E01.mkv","size_bytes":"not-a-number"},
                {"hash":"unknown-title"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Show", type: .series)

        #expect(results.map(\.title) == ["File.Name.S01E01.mkv", "Unknown"])
        #expect(results.map(\.sizeBytes) == [0, 0])
        #expect(results.map(\.seeders) == [0, 0])
        #expect(results.map(\.leechers) == [0, 0])
        #expect(results.allSatisfy { $0.magnetURI == nil })
    }

    @Test func imdbSearchForMovieReturnsEmptyWithoutNetworkRequest() async throws {
        let session = URLProtocolHarness.makeSession { request in
            Issue.record("Unexpected EZTV request for movie IMDb search: \(request.url?.absoluteString ?? "nil")")
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)

        #expect(results.isEmpty)
    }

    @Test func requestHandlesNetworkErrors() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = EZTVIndexer(session: session)
        await #expect(throws: URLError.self) {
            _ = try await indexer.searchByQuery(query: "Test", type: .series)
        }
    }

    @Test func remoteHTTPBaseURLIsRejectedForSearchRequests() async throws {
        let session = URLProtocolHarness.makeSession { _ in
            Issue.record("Network request attempted for blocked URL")
            let url = URL(string: "https://fallback.example")!
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        let indexer = EZTVIndexer(baseURL: "http://eztv.example", session: session)

        do {
            _ = try await indexer.searchByQuery(query: "Show", type: .series)
            Issue.record("Expected URLError(.unsupportedURL)")
        } catch let error as URLError {
            #expect(error.code == .unsupportedURL)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
