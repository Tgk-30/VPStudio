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

// MARK: - StremioIndexer Tests

@Suite("StremioIndexer")
struct StremioIndexerTests {

    @Test func searchByIMDbReturnsStreams() async throws {
        final class RequestState: @unchecked Sendable {
            var manifestRequested = false
            var streamRequested = false
            var capturedPath: String?
        }
        let state = RequestState()

        let session = makeStubSession { request in
            state.capturedPath = request.url?.path
            if request.url?.path.contains("/manifest.json") == true {
                state.manifestRequested = true
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            state.streamRequested = true
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"streams":[{"title":"Example Stream","url":"magnet:?xt=urn:btih:abc123def456abc123def456abc123def456abc1","infoHash":"abc123def456abc123def456abc123def456abc1","behaviorHints":{"videoSize":1073741824,"seeders":100}}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt1160419", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].title == "Example Stream")
        #expect(results[0].seeders == 100)
        #expect(results[0].sizeBytes == 1073741824)
    }

    @Test func searchByQueryWithoutIMDbIdFallsBackToCatalogSearch() async throws {
        final class RequestState: @unchecked Sendable {
            var requests: [String] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            state.requests.append(request.url?.path ?? "")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            if request.url?.path.contains("/search=") == true {
                let body = #"{"metas":[{"id":"dune-movie","name":"Dune","type":"movie"}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        _ = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(state.requests.contains("/manifest.json"))
        #expect(state.requests.contains(where: { $0.contains("/search=") }))
    }

    @Test func searchByQueryMatchesCatalogSearchExtraCaseInsensitively() async throws {
        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path == "/manifest.json" {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"SEARCH"}]}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/catalog/movie/movies/search=") {
                let body = #"{"metas":[{"id":"dune-movie","name":"Dune","type":"movie"}]}"#
                return (response, Data(body.utf8))
            }
            if path == "/stream/movie/dune-movie.json" {
                let body = #"{"streams":[{"title":"Dune Source","infoHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","url":"magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
                return (response, Data(body.utf8))
            }
            return (response, Data("{}".utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(results.count == 1)
        #expect(results[0].title == "Dune Source")
    }

    @Test func searchByQueryContinuesWhenOneCatalogPayloadIsMalformed() async throws {
        final class RequestState: @unchecked Sendable {
            var catalogRequests: [String] = []
            var streamRequested = false
        }
        let state = RequestState()
        let backupHash = String(repeating: "b", count: 40)

        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path.contains("/manifest.json") {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }

            if path.contains("/catalog/") {
                state.catalogRequests.append(path)
                if path.contains("/catalog/movie/movies/search=") {
                    let body = #"{"metas":[{"name":"Dune","type":"movie"}]}"#
                    return (response, Data(body.utf8))
                }
                if path.contains("/catalog/movie/backup/search=") {
                    let body = #"{"metas":[{"id":"dune-backup","name":"Dune","type":"movie"}]}"#
                    return (response, Data(body.utf8))
                }
                return (response, Data("{}".utf8))
            }

            if path.contains("/stream/movie/dune-backup") {
                state.streamRequested = true
                let body = #"{"streams":[{"title":"Recovered Stream","url":"magnet:?xt=urn:btih:\#(backupHash)"}]}"#
                return (response, Data(body.utf8))
            }

            let body = #"{"streams":[]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(state.catalogRequests.count == 2)
        #expect(state.streamRequested == true)
        #expect(results.count == 1)
        #expect(results[0].title == "Recovered Stream")
    }

    @Test func searchByQueryContinuesWhenOneCatalogPayloadIsInvalidJSON() async throws {
        final class RequestState: @unchecked Sendable {
            var catalogRequests: [String] = []
            var streamRequested = false
            var streamIDs: [String] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path.contains("/manifest.json") {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }

            if path.contains("/catalog/") {
                state.catalogRequests.append(path)
                if path.contains("/catalog/movie/movies/search=") {
                    return (response, Data("not valid json".utf8))
                }
                let body = #"{"metas":[{"id":"dune-backup","name":"Dune","type":"movie"}]}"#
                return (response, Data(body.utf8))
            }

            if path.contains("/stream/movie/dune-backup") {
                state.streamRequested = true
                state.streamIDs.append(path)
                let body = #"{"streams":[{"title":"Recovered Stream","url":"magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
                return (response, Data(body.utf8))
            }

            let body = #"{"streams":[]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(state.catalogRequests.count == 2)
        #expect(state.streamRequested == true)
        #expect(state.streamIDs == ["/stream/movie/dune-backup.json"])
        #expect(results.count == 1)
        #expect(results[0].title == "Recovered Stream")
    }

    @Test func searchByQueryRanksCatalogMetasAndLimitsToTopThree() async throws {
        final class RequestState: @unchecked Sendable {
            var streamRequests: [String] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path.contains("/manifest.json") {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }

            if path.contains("/catalog/") {
                let body = #"{"metas":[{"id":"high","name":"Dune","type":"movie"},{"id":"medium","name":"Dune: The Origin","type":"movie"},{"id":"contains","name":"The Story of Dune","type":"movie"},{"id":"low","name":"Unrelated Movie","type":"movie"}]}"#
                return (response, Data(body.utf8))
            }

            if path.contains("/stream/movie/high") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"High Score","url":"magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/medium") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Medium Score","url":"magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/contains") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Contains Score","url":"magnet:?xt=urn:btih:cccccccccccccccccccccccccccccccccccccccc"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/low") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Low Score","url":"magnet:?xt=urn:btih:dddddddddddddddddddddddddddddddddddddddd"}]}"#
                return (response, Data(body.utf8))
            }

            return (response, Data("{}".utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(state.streamRequests == [
            "/stream/movie/high.json",
            "/stream/movie/medium.json",
            "/stream/movie/contains.json"
        ])
        #expect(results.count == 3)
        #expect(results[0].title == "High Score")
        #expect(results[1].title == "Medium Score")
        #expect(results[2].title == "Contains Score")
    }

    @Test func searchByQueryRanksCatalogMetasWithReleaseYearBonus() async throws {
        final class RequestState: @unchecked Sendable {
            var streamRequests: [String] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path.contains("/manifest.json") {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }

            if path.contains("/catalog/") {
                let body = #"{"metas":[{"id":"exactYear","name":"Dune","type":"movie","releaseInfo":"2024"},{"id":"exactNoYear","name":"Dune","type":"movie","releaseInfo":"1999"},{"id":"prefixYear","name":"Dune Legacy","type":"movie","releaseInfo":"2024"},{"id":"contains","name":"The Tale of Dune","type":"movie","releaseInfo":"2024"}]}"#
                return (response, Data(body.utf8))
            }

            if path.contains("/stream/movie/exactYear") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Exact year match","url":"magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/exactNoYear") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Exact without year","url":"magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/prefixYear") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Prefix with year","url":"magnet:?xt=urn:btih:cccccccccccccccccccccccccccccccccccccccc"}]}"#
                return (response, Data(body.utf8))
            }

            return (response, Data("{}".utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.searchByQuery(query: "Dune 2024", type: .movie)

        #expect(state.streamRequests == [
            "/stream/movie/exactYear.json",
            "/stream/movie/exactNoYear.json",
            "/stream/movie/prefixYear.json"
        ])
        #expect(results.count == 3)
        #expect(results[0].title == "Exact year match")
        #expect(results[1].title == "Exact without year")
        #expect(results[2].title == "Prefix with year")
    }

    @Test func searchByQueryDeduplicatesCatalogIDsBeforeFetchingStreams() async throws {
        final class RequestState: @unchecked Sendable {
            var streamRequests: [String] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path.contains("/manifest.json") {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }

            if path.contains("/catalog/") {
                let body = #"{"metas":[{"id":"dune-dup","name":"Dune","type":"movie"},{"id":"dune-dup","name":"Dune","type":"movie"},{"id":"other","name":"Not Dune","type":"movie"}]}"#
                return (response, Data(body.utf8))
            }

            if path.contains("/stream/movie/dune-dup") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Deduped Stream","url":"magnet:?xt=urn:btih:dddddddddddddddddddddddddddddddddddddddd"}]}"#
                return (response, Data(body.utf8))
            }

            if path.contains("/stream/movie/other") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Ignored Stream","url":"magnet:?xt=urn:btih:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}]}"#
                return (response, Data(body.utf8))
            }

            return (response, Data("{}".utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(state.streamRequests == ["/stream/movie/dune-dup.json", "/stream/movie/other.json"])
        #expect(results.contains(where: { $0.title == "Deduped Stream" }))
        #expect(results.first(where: { $0.title == "Ignored Stream" }) != nil)
    }

    @Test func searchByQuerySkipsMetasFromWrongTypeAndWithZeroScore() async throws {
        final class RequestState: @unchecked Sendable {
            var streamRequests: [String] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path == "/manifest.json" {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/catalog/") {
                let body = #"{"metas":[{"id":"series-id","name":"Dune","type":"series"},{"id":"noise-id","name":"Completely Different Title","type":"movie"},{"id":"valid-id","name":"Dune: Legacy","type":"movie"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/valid-id") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Valid Match","url":"magnet:?xt=urn:btih:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}]}"#
                return (response, Data(body.utf8))
            }
            return (response, Data("{}".utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(state.streamRequests == ["/stream/movie/valid-id.json"])
        #expect(results.count == 1)
        #expect(results[0].title == "Valid Match")
    }

    @Test func searchByQueryExtractsIMDbIdFromQuery() async throws {
        final class RequestState: @unchecked Sendable {
            var streamPath: String?
        }
        let state = RequestState()

        let session = makeStubSession { request in
            state.streamPath = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        _ = try await indexer.searchByQuery(query: "tt1160419 Dune", type: .movie)

        #expect(state.streamPath?.contains("tt1160419") == true)
    }

    @Test func nonSearchableCatalogReturnsEmptyArray() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[]}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(results.isEmpty)
    }

    @Test func httpErrorThrowsURLError() async {
        let session = makeStubSession { request in
            if request.url?.path.contains("/manifest.json") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        do {
            _ = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)
            Issue.record("Expected URLError")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func malformedStreamJSONThrowsIndexerParseError() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            return (response, Data("{ invalid json }".utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        do {
            _ = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)
            Issue.record("Expected IndexerParseError")
        } catch let error as IndexerParseError {
            if case .invalidPayload(let indexer, _) = error {
                #expect(indexer == "TestAddon")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func streamsMissingInfoHashKeepDirectURLWithSyntheticHash() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"No Hash Stream","url":"https://example.com/file.mp4"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].directStreamURL == "https://example.com/file.mp4")
        #expect(results[0].magnetURI == nil)
        #expect(results[0].infoHash.hasPrefix("direct-"))
        #expect(DebridHashValidator.normalizedInfoHash(results[0].infoHash) == nil)
    }

    @Test func streamsGenerateMagnetURIWithDeduplicatedAndEncodedTrackers() async throws {
        let hash = String(repeating: "a", count: 40)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Tracker Stream","infoHash":"\#(hash)","url":"https://cdn.example.com/file.mkv","sources":["tracker:udp://Tracker.Example.Com:1337/announce","udp://tracker.example.com:1337/announce","tracker:https://tracker-secure.example.net/announce","https://tracker-secure.example.net/announce","ftp://ignored.example.com/announce"]}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt1160419", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(
            results[0].magnetURI
                == "magnet:?xt=urn:btih:\(hash)&dn=Tracker%20Stream&tr=udp%3A%2F%2FTracker.Example.Com%3A1337%2Fannounce&tr=https%3A%2F%2Ftracker-secure.example.net%2Fannounce"
        )
    }

    @Test func streamsGenerateMagnetURIDeduplicatesCaseInsensitiveTrackers() async throws {
        let hash = String(repeating: "c", count: 40)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Case Stream","infoHash":"\#(hash)","url":"https://cdn.example.com/file.mkv","sources":["https://tracker.example.com/announce","HTTPS://tracker.example.com/announce","tracker:https://tracker.example.com/announce"]}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt1160419", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:\(hash)&dn=Case%20Stream&tr=https%3A%2F%2Ftracker.example.com%2Fannounce")
    }

    @Test func streamsGenerateMagnetURIExcludesUnsupportedTrackers() async throws {
        let hash = String(repeating: "b", count: 40)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Filtered Stream","infoHash":"\#(hash)","url":"https://cdn.example.com/file.mkv","sources":["mailto:help@example.com","socks://tracker.example.com","ftp://tracker.example.com","tcp://tracker.example.com","https://tracker.allowed.example.com/announce"]}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt1160419", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(
            results[0].magnetURI
                == "magnet:?xt=urn:btih:\(hash)&dn=Filtered%20Stream&tr=https%3A%2F%2Ftracker.allowed.example.com%2Fannounce"
        )
    }

    @Test func streamsCaptureProxyHeadersFromBehaviorHints() async throws {
        let hash = String(repeating: "f", count: 40)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Header Stream","url":"https://cdn.example.com/file.mkv","infoHash":"\#(hash)","behaviorHints":{"proxyHeaders":{"request":{" User-Agent ":"  TestAgent ","Referer":"https://app.strem.io/","Authorization":"Bearer ignored","X-Auth":"token-123","X-Empty":"   "}}}}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt1160419", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].directStreamRequestHeaders?["User-Agent"] == "TestAgent")
        #expect(results[0].directStreamRequestHeaders?["Referer"] == "https://app.strem.io/")
        #expect(results[0].directStreamRequestHeaders?["Authorization"] == nil)
        #expect(results[0].directStreamRequestHeaders?["X-Auth"] == nil)
        #expect(results[0].directStreamRequestHeaders?["X-Empty"] == nil)
        #expect(results[0].directStreamRequestHeaders?.count == 2)
    }

    @Test func searchByQueryThrowsWhenAllCatalogsFail() async throws {
        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if path.contains("/manifest.json") {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/catalog/") {
                let failResponse = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
                return (failResponse, Data())
            }
            return (response, Data("{}".utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        do {
            _ = try await indexer.searchByQuery(query: "Dune", type: .movie)
            Issue.record("Expected URLError")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func searchByQueryThrowsInvalidPayloadWhenAllCatalogPayloadInvalid() async throws {
        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path.contains("/manifest.json") {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            return (response, Data("definitely not valid json".utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        do {
            _ = try await indexer.searchByQuery(query: "Dune", type: .movie)
            Issue.record("Expected decoding error")
        } catch let error as IndexerParseError {
            if case .invalidPayload(_, let reason) = error {
                #expect(reason.localizedCaseInsensitiveContains("malformed JSON payload"))
                return
            }
            Issue.record("Expected invalid payload error, got \(error)")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func searchByQueryAllowsNilMetaType() async throws {
        final class RequestState: @unchecked Sendable {
            var streamRequests: [String] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path.contains("/manifest.json") {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/catalog/") {
                let body = #"{"metas":[{"id":"null-type","name":"Dune","type":null},{"id":"wrong-type","name":"Dune","type":"series"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/null-type") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Nil Type Match","url":"magnet:?xt=urn:btih:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/wrong-type") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Wrong Type Match","url":"magnet:?xt=urn:btih:ffffffffffffffffffffffffffffffffffffffff"}]}"#
                return (response, Data(body.utf8))
            }
            return (response, Data("{}".utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(results.count == 1)
        #expect(results.first?.title == "Nil Type Match")
        #expect(state.streamRequests == ["/stream/movie/null-type.json"])
    }

    @Test func searchByQueryAllowsUppercaseCatalogType() async throws {
        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path.contains("/manifest.json") {
                let body = #"{"catalogs":[{"id":"movies","type":"MOVIE","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/catalog/") {
                let body = #"{"metas":[{"id":"dune","name":"Dune","type":"movie"}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Dune","infoHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(results.map(\.infoHash) == ["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"])
    }

    @Test func searchByQueryTiesResolvedAlphabeticallyByMetaName() async throws {
        final class RequestState: @unchecked Sendable {
            var streamRequests: [String] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if path.contains("/manifest.json") {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/catalog/") {
                let body = #"{"metas":[{"id":"zeta","name":"Alpine","type":"movie"},{"id":"alpha","name":"Alpha","type":"movie"},{"id":"beta","name":"Alto","type":"movie"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/alpha") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Alpha","url":"magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/beta") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Beta","url":"magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]}"#
                return (response, Data(body.utf8))
            }
            if path.contains("/stream/movie/zeta") {
                state.streamRequests.append(path)
                let body = #"{"streams":[{"title":"Zeta","url":"magnet:?xt=urn:btih:cccccccccccccccccccccccccccccccccccccccc"}]}"#
                return (response, Data(body.utf8))
            }

            return (response, Data("{}".utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        _ = try await indexer.searchByQuery(query: "Al", type: .movie)

        #expect(state.streamRequests == [
            "/stream/movie/alpha.json",
            "/stream/movie/zeta.json",
            "/stream/movie/beta.json",
        ])
    }

    @Test func streamsGenerateMagnetURIWithUppercasePathHash() async throws {
        let hash = String(repeating: "A", count: 40)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Upper Hash Stream","url":"https://torrentio.strem.fun/resolve/rd/\#(hash)/file.mkv"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt1160419", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].infoHash == hash.lowercased())
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:\(hash.lowercased())&dn=Upper%20Hash%20Stream")
    }

    @Test func streamsFallbackToLookupHashWhenDeclaredInfoHashIsInvalid() async throws {
        let validHash = String(repeating: "a", count: 40)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Invalid Hash Stream","url":"https://torrentio.strem.fun/resolve/rd/\#(validHash)/invalid-hash.mp4","infoHash":"not-a-real-hash"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].infoHash == validHash)
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:\(validHash)&dn=Invalid%20Hash%20Stream")
    }

    @Test func streamsIgnoresInvalidLookupMagnetHashWhenMagnetFieldIsValid() async throws {
        let validHash = String(repeating: "a", count: 40)
        let invalidHash = String(repeating: "b", count: 16)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Invalid Lookup Hash Stream","url":"magnet:?xt=urn:btih:\#(invalidHash)","magnet":"magnet:?xt=urn:btih:\#(validHash)&dn=valid"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].infoHash == validHash)
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:\(validHash)&dn=valid")
    }

    @Test func streamsMissingInfoHashAndPlayableURLAreFiltered() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"No Hash Stream"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(results.isEmpty)
    }

    @Test func streamsUseExternalURLHashWhenURLFieldHasNoHash() async throws {
        let hash = String(repeating: "1", count: 40)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"External Hash Stream","url":"https://cdn.example.com/stream.mp4","externalUrl":"https://cdn.example.com/resolve/\#(hash)/stream"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].infoHash == hash)
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:\(hash)&dn=External%20Hash%20Stream")
    }

    @Test func streamsIgnoresInvalidExternalMagnetWhenMagnetFieldIsValid() async throws {
        let validHash = String(repeating: "a", count: 40)
        let invalidHash = String(repeating: "b", count: 12)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Invalid External Hash Stream","url":"https://cdn.example.com/stream.mp4","externalUrl":"magnet:?xt=urn:btih:\#(invalidHash)","magnet":"magnet:?xt=urn:btih:\#(validHash)&dn=magnet"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].infoHash == validHash)
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:\(validHash)&dn=magnet")
    }

    @Test func streamsIgnoresMismatchedMagnetWhenLookupHashIsValid() async throws {
        let lookupHash = String(repeating: "c", count: 40)
        let mismatchedHash = String(repeating: "d", count: 40)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Mismatched Magnet","url":"https://cdn.example.com/\#(lookupHash)/stream.mkv","magnet":"magnet:?xt=urn:btih:\#(mismatchedHash)&dn=wrong"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].infoHash == lookupHash)
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:\(lookupHash)&dn=Mismatched%20Magnet")
    }

    @Test func streamsWith64CharInfoHashAreNormalized() async throws {
        let hash64 = String(repeating: "a", count: 64)
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Stream 64","url":"https://cdn.example.com/file.mkv","infoHash":"\#(hash64)"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results[0].infoHash == hash64)
    }

    @Test func emptyStreamsArrayReturnsEmptyResults() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(results.isEmpty)
    }

    @Test func buildStreamURLConstructsCorrectPath() async throws {
        final class RequestState: @unchecked Sendable {
            var streamPaths: [String?] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            state.streamPaths.append(request.url?.path)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Stream","url":"magnet:?xt=urn:btih:abc123def456abc123def456abc123def456abc1"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        _ = try await indexer.search(imdbId: "tt1160419", type: .movie, season: nil, episode: nil)

        #expect(state.streamPaths.first(where: { $0?.contains("/stream/") == true }) != nil)
    }

    @Test func seriesSearchIncludesSeasonAndEpisodeInMediaID() async throws {
        final class RequestState: @unchecked Sendable {
            var streamPaths: [String?] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            state.streamPaths.append(request.url?.path)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"series","type":"series","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Episode","url":"magnet:?xt=urn:btih:abc123def456abc123def456abc123def456abc1"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        _ = try await indexer.search(imdbId: "tt000", type: .series, season: 1, episode: 5)

        #expect(state.streamPaths.first(where: { $0?.contains(":1:5") == true }) != nil)
    }

    @Test func episodeAnnotationAppendsSeasonEpisodeToken() async throws {
        final class RequestState: @unchecked Sendable {
            var titles: [String] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            state.titles.append(contentsOf: request.url?.path.split(separator: "/").map(String.init) ?? [])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"series","type":"series","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Breaking Bad S01E05","url":"magnet:?xt=urn:btih:abc123def456abc123def456abc123def456abc1","behaviorHints":{"seeders":200}}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "https://example.com", session: session)
        let results = try await indexer.search(imdbId: "tt000", type: .series, season: 1, episode: 5)

        #expect(results.count == 1)
        #expect(results[0].title.contains("S01E05"))
    }

    @Test func supportsStremioSchemeBaseURLs() async throws {
        final class RequestState: @unchecked Sendable {
            var capturedScheme: String?
            var capturedHost: String?
        }
        let state = RequestState()

        let session = makeStubSession { request in
            state.capturedScheme = request.url?.scheme
            state.capturedHost = request.url?.host
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.path.contains("/manifest.json") == true {
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }
            if request.url?.path.contains("/search=") == true {
                let body = #"{"metas":[{"id":"dune","name":"Dune","type":"movie"}]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"streams":[{"title":"Stream","url":"https://cdn.example.com/stream.mp4"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = StremioIndexer(name: "TestAddon", baseURL: "stremio://addon.example", session: session)
        _ = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(state.capturedScheme == "https")
        #expect(state.capturedHost == "addon.example")
    }

    @Test func manifestURLBuilderAvoidsDuplicateManifestSuffix() throws {
        let urlWithSuffix = try StremioAddonURLBuilder.manifestURL(
            baseURL: "https://addon.example/api/v1/manifest.json",
            endpointPath: "/manifest.json"
        )
        #expect(urlWithSuffix.absoluteString == "https://addon.example/api/v1/manifest.json")

        let urlFromBasePath = try StremioAddonURLBuilder.manifestURL(
            baseURL: "https://addon.example/api/v1",
            endpointPath: "manifest.json"
        )
        #expect(urlFromBasePath.absoluteString == "https://addon.example/api/v1/manifest.json")
    }

    @Test func manifestURLBuilderRejectsBlankBaseURL() throws {
        #expect(throws: URLError(.badURL)) {
            _ = try StremioAddonURLBuilder.manifestURL(baseURL: "   ", endpointPath: "/manifest.json")
        }
    }

    @Test func normalizedAddonURLStringConvertsStremioSchemeAndTrimsWhitespace() {
        let normalized = StremioAddonURLBuilder.normalizedAddonURLString("  stremio://addon.example/streams  ")
        #expect(normalized == "https://addon.example/streams")
    }

    @Test func normalizedAddonURLStringConvertsUppercaseSchemeAndTrimsWhitespace() {
        let normalized = StremioAddonURLBuilder.normalizedAddonURLString("  STREMIO://addon.example/streams  ")
        #expect(normalized == "https://addon.example/streams")
    }

    @Test func normalizedAddonURLStringLeavesNonStremioSchemeUntouched() {
        let normalized = StremioAddonURLBuilder.normalizedAddonURLString("  https://addon.example/streams  ")
        #expect(normalized == "https://addon.example/streams")
    }
}

// MARK: - IndexerLogSanitizer Tests

@Suite("IndexerLogSanitizer")
struct IndexerLogSanitizerTests {

    @Test func redactsURLWithCredentials() {
        let url = URL(string: "https://user:pass@example.com/api?key=secret")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("user") == false)
        #expect(redacted.contains("pass") == false)
        #expect(redacted.contains("secret") == false)
        #expect(redacted.contains("example.com"))
    }

    @Test func redactsSensitiveQueryParameters() {
        let url = URL(string: "https://example.com/api?api_key=mykey&query=test")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("mykey") == false)
        #expect(redacted.contains("test"))
    }

    @Test func redactsTokenLikePathSegments() {
        let url = URL(string: "https://example.com/token_segment_1234567890abcdef/path")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("REDACTED"))
    }

    @Test func urlWithNoSensitiveDataIsNotRedacted() {
        let url = URL(string: "https://example.com/api?query=test&page=1")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("example.com"))
        #expect(redacted.contains("test"))
    }

    @Test func redactedURLStringHandlesNil() {
        let result = IndexerLogSanitizer.redactedURLString(nil)
        #expect(result == "nil")
    }

    @Test func redactedURLStringHandlesEmpty() {
        let result = IndexerLogSanitizer.redactedURLString("")
        #expect(result == "nil")
    }

    @Test func redactedErrorMessageRedactsURLs() {
        let error = URLError(.badServerResponse)
        let message = IndexerLogSanitizer.redactedErrorMessage(error)
        #expect(message.isEmpty == false)
    }

    @Test func looksSensitiveDetectsLongTokens() {
        let longToken = String(repeating: "a", count: 40)
        #expect(IndexerLogSanitizer.redactedURLString(longToken) == "REDACTED")
    }

    @Test func looksSensitiveAllowsShortStrings() {
        let short = "abc123"
        #expect(IndexerLogSanitizer.redactedURLString(short) == short)
    }
}

// MARK: - IndexerManager Tests

@Suite("IndexerManager")
struct IndexerManagerTests {

    @Test func deduplicateAndSortPrefersCachedResults() async throws {
        let results = [
            TorrentResult.fromSearch(infoHash: "abc", title: "Title A", sizeBytes: 100, seeders: 10, leechers: 1, indexerName: "A"),
            TorrentResult.fromSearch(infoHash: "abc", title: "Title B", sizeBytes: 100, seeders: 100, leechers: 1, indexerName: "B"),
            TorrentResult.fromSearch(infoHash: "def", title: "Title C", sizeBytes: 100, seeders: 50, leechers: 1, indexerName: "C"),
        ]

        let deduplicated = IndexerManager.deduplicateAndSort(results)
        #expect(deduplicated.count == 2)
        let abcResult = deduplicated.first { $0.infoHash == "abc" }
        #expect(abcResult?.seeders == 100)
    }

    @Test func deduplicateAndSortOrdersByCachedThenQualityThenSeeders() async throws {
        var results = [
            TorrentResult.fromSearch(infoHash: "uncached", title: "Uncached", sizeBytes: 100, seeders: 1000, leechers: 1, indexerName: "A"),
            TorrentResult.fromSearch(infoHash: "cached", title: "Cached", sizeBytes: 100, seeders: 1, leechers: 1, indexerName: "B"),
        ]
        results[1].isCached = true

        let deduplicated = IndexerManager.deduplicateAndSort(results)
        #expect(deduplicated[0].infoHash == "cached")
        #expect(deduplicated[1].infoHash == "uncached")
    }

    @Test func configuredIndexerNamesReturnsNames() async throws {
        let indexer1 = YTSIndexer()
        let indexer2 = EZTVIndexer()
        let indexers: [any TorrentIndexer] = [indexer1, indexer2]

        let names = indexers.map(\.name)
        #expect(names.contains("YTS"))
        #expect(names.contains("EZTV"))
    }
}
