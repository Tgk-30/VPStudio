import Foundation
import Testing
@testable import VPStudio

@Suite("APIBayIndexer")
struct APIBayIndexerTests {
    @Test func searchByQueryNormalizesTrailingSlashAndBasePathWhenBuildingURL() async throws {
        final class State: @unchecked Sendable {
            var requestPath: String?
            var capturedQuery: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.requestPath = url.path
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.capturedQuery = components?.queryItems?.first(where: { $0.name == "q" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"1","name":"Movie","info_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":"100","seeders":"1","leechers":"1"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(baseURL: "https://apibay.example/root/", session: session)
        _ = try await indexer.searchByQuery(query: "movie", type: .movie)

        #expect(state.requestPath == "/root/q.php")
        #expect(state.capturedQuery == "movie")
    }

    @Test func searchByIMDbAppendsEpisodeContext() async throws {
        final class State: @unchecked Sendable {
            var capturedQuery: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.capturedQuery = components?.queryItems?.first(where: { $0.name == "q" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"0","name":"invalid id","info_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":"100","seeders":"1","leechers":"1"},
                {"id":"2","name":"zero hash","info_hash":"0000000000000000000000000000000000000000","size":"100","seeders":"1","leechers":"1"},
                {"id":"3","name":"Show S01E01","info_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":"100","seeders":"1","leechers":"1"},
                {"id":"4","name":"Show S01E02 1080p WEB-DL","info_hash":"cccccccccccccccccccccccccccccccccccccccc","size":"2000","seeders":"50","leechers":"5"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: 1, episode: 2)

        #expect(state.capturedQuery == "tt1234567 S01E02")
        #expect(results.map { $0.infoHash } == ["cccccccccccccccccccccccccccccccccccccccc"])
        #expect(results.first?.title == "Show S01E02 1080p WEB-DL")
        #expect(results.first?.seeders == 50)
        #expect(results.first?.leechers == 5)
        #expect(results.first?.quality == .hd1080p)
    }

    @Test func searchByQueryUsesEpisodeContextWhenPresent() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"1","name":"Show S02E03","info_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":"1000","seeders":"8","leechers":"2"},
                {"id":"2","name":"Show S02E04","info_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":"1000","seeders":"7","leechers":"1"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Show S02E03", type: .series)

        #expect(results.map { $0.infoHash } == ["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"])
    }

    @Test func noResultsSentinelReturnsEmptyList() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"[{"id":"0","name":"No results returned","info_hash":"","size":"0","seeders":"0","leechers":"0"}]"#
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "unlikely", type: .movie)

        #expect(results.isEmpty)
    }

    @Test func emptyJSONResponseReturnsEmptyList() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "missing", type: .movie)

        #expect(results.isEmpty)
    }

    @Test func nonNumericStatsUseZeroFallbacksWhenNoEpisodeContextExists() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"1","name":"Movie 2160p WEB-DL","info_hash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","size":"unknown","seeders":"many","leechers":"few"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Movie", type: .movie)

        let result = try #require(results.first)
        #expect(results.count == 1)
        #expect(result.infoHash == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        #expect(result.sizeBytes == 0)
        #expect(result.seeders == 0)
        #expect(result.leechers == 0)
        #expect(result.quality == .uhd4k)
    }

    @Test func searchByIMDbWithoutEpisodeContextUsesOnlyIMDbQuery() async throws {
        final class State: @unchecked Sendable {
            var capturedQuery: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.capturedQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "q" })?
                .value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"1","name":"Movie Untokenized","info_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":"1234","seeders":"9","leechers":"3"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt7654321", type: .movie, season: nil, episode: nil)

        #expect(state.capturedQuery == "tt7654321")
        #expect(results.map(\.infoHash) == ["bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"])
    }

    @Test func searchByIMDbFiltersInvalidRows() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"invalid","name":"Invalid ID S01E01","info_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":"100","seeders":"1","leechers":"1"},
                {"id":"0","name":"Zero ID S01E01","info_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":"100","seeders":"1","leechers":"1"},
                {"id":"1","name":"Valid Result S01E01","info_hash":"cccccccccccccccccccccccccccccccccccccccc","size":"1000","seeders":"10","leechers":"2"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: 1, episode: 1)

        // id=="0" and empty/zero-hash items are filtered out; remaining must match S01E01 in title
        #expect(results.count == 2)
        let infoHashes = results.map(\.infoHash)
        #expect(infoHashes.contains("cccccccccccccccccccccccccccccccccccccccc"))
    }

    @Test func requestHandlesNetworkErrors() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = APIBayIndexer(session: session)
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

        let indexer = APIBayIndexer(baseURL: "http://apibay.example", session: session)

        do {
            _ = try await indexer.searchByQuery(query: "Movie", type: .movie)
            Issue.record("Expected URLError(.unsupportedURL)")
        } catch let error as URLError {
            #expect(error.code == .unsupportedURL)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
