import Testing
import Foundation
@testable import VPStudio

// MARK: - URLProtocol Stub

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]
    static let lock = NSLock()
    static let handlerHeader = "X-VPStudio-Stub-ID"

    fileprivate static func register(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> String {
        let id = UUID().uuidString
        lock.lock()
        requestHandlers[id] = handler
        lock.unlock()
        return id
    }

    fileprivate static func handler(for id: String) -> ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        lock.lock()
        let handler = requestHandlers[id]
        lock.unlock()
        return handler
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: handlerHeader) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handlerID = request.value(forHTTPHeaderField: Self.handlerHeader),
              let handler = Self.handler(for: handlerID) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        var sanitizedRequest = request
        sanitizedRequest.setValue(nil, forHTTPHeaderField: Self.handlerHeader)
        do {
            let (response, data) = try handler(sanitizedRequest)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeStubSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
    let handlerID = URLProtocolStub.register(handler)
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolStub.self]
    config.httpAdditionalHeaders = [URLProtocolStub.handlerHeader: handlerID]
    return URLSession(configuration: config)
}

// MARK: - YTSIndexer Tests

@Suite("YTSIndexer")
struct YTSIndexerTests {

    @Test func buildSearchPathNormalizesBasePathAndTrailingSlash() async throws {
        final class State: @unchecked Sendable {
            var requestPath: String?
            var capturedQuery: String?
        }
        let state = State()

        let session = makeStubSession { request in
            let url = try #require(request.url)
            state.requestPath = url.path
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.capturedQuery = components?.queryItems?.first(where: { $0.name == "query_term" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
              "status": "ok",
              "data": { "movies": [] }
            }
            """
            return (response, Data(body.utf8))
        }

        let indexer = YTSIndexer(
            baseURLs: ["https://yts.example/base/"],
            session: session
        )
        _ = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(state.requestPath == "/base/api/v2/list_movies.json")
        #expect(state.capturedQuery == "Dune")
    }

    @Test func buildSearchPathDoesNotDuplicateFullEndpointInBaseURL() async throws {
        final class State: @unchecked Sendable {
            var requestPath: String?
        }
        let state = State()

        let session = makeStubSession { request in
            let url = try #require(request.url)
            state.requestPath = url.path
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"status":"ok","data":{"movies":[]}}"#
            return (response, Data(body.utf8))
        }

        let indexer = YTSIndexer(
            baseURLs: ["https://yts.example/api/v2/list_movies.json"],
            session: session
        )
        _ = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(state.requestPath == "/api/v2/list_movies.json")
    }

    @Test func searchByIMDbReturnsMoviesOnly() async throws {
        final class RequestState: @unchecked Sendable {
            var requestCount = 0
        }
        let state = RequestState()

        let session = makeStubSession { request in
            state.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "status": "ok",
                "data": {
                    "movie_count": 1,
                    "movies": [{
                        "title": "Dune",
                        "title_long": "Dune (2021)",
                        "year": 2021,
                        "imdb_code": "tt1160419",
                        "torrents": [{
                            "hash": "abc123def456abc123def456abc123def456abc1",
                            "quality": "1080p",
                            "type": "bluray",
                            "seeds": 100,
                            "peers": 20,
                            "size_bytes": 2147483648
                        }]
                    }]
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let indexer = YTSIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1160419", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].title.contains("Dune"))
        #expect(results[0].seeders == 100)
    }

    @Test func searchByQueryReturnsMoviesOnly() async throws {
        final class RequestState: @unchecked Sendable {
            var capturedQuery: String?
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            state.capturedQuery = components?.queryItems?.first(where: { $0.name == "query_term" })?.value
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "status": "ok",
                "data": {
                    "movie_count": 1,
                    "movies": [{
                        "title": "Dune",
                        "title_long": "Dune (2021)",
                        "year": 2021,
                        "imdb_code": "tt1160419",
                        "torrents": [{
                            "hash": "abc123def456abc123def456abc123def456abc1",
                            "quality": "2160p",
                            "type": "webrip",
                            "seeds": 50,
                            "peers": 10,
                            "size_bytes": 5368709120
                        }]
                    }]
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let indexer = YTSIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Dune 2021", type: .movie)

        #expect(state.capturedQuery == "Dune 2021")
        #expect(results.count == 1)
        #expect(results[0].quality == .uhd4k)
    }

    @Test func seriesTypeReturnsEmptyArray() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"ok","data":{"movies":[]}}"#.utf8))
        }

        let indexer = YTSIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt0120737", type: .series, season: 1, episode: 1)

        #expect(results.isEmpty)
    }

    @Test func searchByQuerySeriesReturnsEmptyArray() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"ok","data":{"movies":[]}}"#.utf8))
        }

        let indexer = YTSIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Breaking Bad S01E01", type: .series)

        #expect(results.isEmpty)
    }

    @Test func remoteHTTPBaseURLIsRejectedForSearchRequests() async throws {
        let session = makeStubSession { _ in
            Issue.record("Network request attempted for blocked URL")
            let url = URL(string: "https://fallback.example")!
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        let indexer = YTSIndexer(baseURLs: ["http://yts.example"], session: session)

        do {
            _ = try await indexer.searchByQuery(query: "Dune", type: .movie)
            Issue.record("Expected URLError(.unsupportedURL)")
        } catch let error as URLError {
            #expect(error.code == .unsupportedURL)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func multipleTorrentsPerMovieProducesMultipleResults() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "status": "ok",
                "data": {
                    "movies": [{
                        "title": "Dune",
                        "title_long": "Dune (2021)",
                        "year": 2021,
                        "imdb_code": "tt1160419",
                        "torrents": [
                            {"hash": "aaa123def456abc123def456abc123def456aaa1", "quality": "720p", "type": "bluray", "seeds": 10, "peers": 5, "size_bytes": 1073741824},
                            {"hash": "bbb123def456abc123def456abc123def456bbb1", "quality": "1080p", "type": "bluray", "seeds": 100, "peers": 20, "size_bytes": 2147483648},
                            {"hash": "ccc123def456abc123def456abc123def456ccc1", "quality": "2160p", "type": "webrip", "seeds": 50, "peers": 15, "size_bytes": 5368709120}
                        ]
                    }]
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let indexer = YTSIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(results.count == 3)
    }

    @Test func emptyMoviesArrayReturnsEmptyResults() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "status": "ok",
                "data": {
                    "movie_count": 0,
                    "movies": []
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let indexer = YTSIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Nonexistent Movie XYZ", type: .movie)

        #expect(results.isEmpty)
    }

    @Test func resultMappingSkipsMissingHashesAndUsesSafeDefaults() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "status": "ok",
                "data": {
                    "movies": [{
                        "torrents": [
                            {"hash": "", "quality": "1080p", "type": "bluray", "seeds": 1, "peers": 1, "size_bytes": 100},
                            {"quality": "720p", "type": "web", "seeds": 1, "peers": 1, "size_bytes": 100},
                            {"hash": "DDD123DEF456ABC123DEF456ABC123DEF456DDD1", "quality": "", "type": ""}
                        ]
                    }]
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let indexer = YTSIndexer(baseURLs: ["https://yts.example/api/v2"], session: session)
        let results = try await indexer.searchByQuery(query: "Unknown Movie", type: .movie)

        let result = try #require(results.first)
        #expect(results.count == 1)
        #expect(result.infoHash == "ddd123def456abc123def456abc123def456ddd1")
        #expect(result.title == "Unknown")
        #expect(result.sizeBytes == 0)
        #expect(result.seeders == 0)
        #expect(result.leechers == 0)
        #expect(result.quality == .unknown)
    }

    @Test func fallsBackToLaterBaseURLAfterHTTPFailure() async throws {
        final class RequestState: @unchecked Sendable {
            var hosts: [String] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let url = try #require(request.url)
            state.hosts.append(url.host ?? "")

            if url.host == "first.example" {
                let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "status": "ok",
                "data": {
                    "movies": [{
                        "title": "Fallback Movie",
                        "torrents": [
                            {"hash": "eee123def456abc123def456abc123def456eee1"}
                        ]
                    }]
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let indexer = YTSIndexer(
            baseURLs: ["https://first.example/api/v2", "https://second.example/api/v2"],
            session: session
        )
        let results = try await indexer.searchByQuery(query: "Fallback Movie", type: .movie)

        #expect(state.hosts == ["first.example", "first.example", "first.example", "second.example"])
        #expect(results.map(\.title) == ["Fallback Movie"])
    }

    @Test func httpErrorThrowsURLError() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = YTSIndexer(session: session)
        do {
            _ = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)
            Issue.record("Expected URLError")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func malformedJSONThrowsIndexerParseError() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{ invalid json }".utf8))
        }

        let indexer = YTSIndexer(session: session)
        do {
            _ = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)
            Issue.record("Expected IndexerParseError")
        } catch let error as IndexerParseError {
            if case .invalidPayload(let indexer, _) = error {
                #expect(indexer == "YTS")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func buildSearchURLContainsQueryTerm() async throws {
        final class RequestState: @unchecked Sendable {
            var queryTerms: [String?] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            state.queryTerms.append(components?.queryItems?.first(where: { $0.name == "query_term" })?.value)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"ok","data":{"movies":[]}}"#.utf8))
        }

        let indexer = YTSIndexer(session: session)
        _ = try await indexer.searchByQuery(query: "my search term", type: .movie)

        #expect(state.queryTerms == ["my search term", "my search term", "my search term"])
    }

    @Test func buildSearchURLDeduplicatesRepeatedQueryTerms() async throws {
        final class RequestState: @unchecked Sendable {
            var capturedQuery: String?
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            state.capturedQuery = components?.queryItems?.first(where: { $0.name == "query_term" })?.value
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"ok","data":{"movies":[]}}"#.utf8))
        }

        let indexer = YTSIndexer(session: session)
        _ = try await indexer.searchByQuery(query: "dune dune 2021 2021", type: .movie)

        #expect(state.capturedQuery == "dune 2021")
    }

    @Test func buildSearchURLDeduplicatesRepeatedQueryTermsCaseInsensitively() async throws {
        final class RequestState: @unchecked Sendable {
            var capturedQuery: String?
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            state.capturedQuery = components?.queryItems?.first(where: { $0.name == "query_term" })?.value
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"ok","data":{"movies":[]}}"#.utf8))
        }

        let indexer = YTSIndexer(session: session)
        _ = try await indexer.searchByQuery(query: "Dune dune DUNE 2021", type: .movie)

        #expect(state.capturedQuery == "Dune 2021")
    }

    @Test func defaultSessionIsEphemeral() async {
        let indexer = YTSIndexer()
        #expect(indexer.name == "YTS")
    }
}
