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

// MARK: - TorznabIndexer Tests

@Suite("TorznabIndexer")
struct TorznabIndexerTests {

    @Test func buildRequestIncludesApiKeyInHeaderWhenUsingHeaderTransport() async throws {
        final class RequestState: @unchecked Sendable {
            var apiKeyHeader: String?
            var apiKeyQuery: String?
            var path: String?
        }
        let state = RequestState()

        let session = makeStubSession { request in
            state.apiKeyHeader = request.value(forHTTPHeaderField: "X-Api-Key")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            state.apiKeyQuery = components?.queryItems?.first(where: { $0.name == "apikey" })?.value
            state.path = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("<xml><results></results></xml>".utf8))
        }

        let indexer = TorznabIndexer(
            name: "TestTorznab",
            baseURL: "https://example.com/api",
            apiKey: "my-api-key",
            apiKeyTransport: .header,
            session: session
        )
        _ = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(state.apiKeyHeader == "my-api-key")
        #expect(state.apiKeyQuery == nil)
    }

    @Test func buildRequestIncludesApiKeyInQueryWhenUsingQueryTransport() async throws {
        final class RequestState: @unchecked Sendable {
            var apiKeyHeader: String?
            var apiKeyQuery: String?
        }
        let state = RequestState()

        let session = makeStubSession { request in
            state.apiKeyHeader = request.value(forHTTPHeaderField: "X-Api-Key")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            state.apiKeyQuery = components?.queryItems?.first(where: { $0.name == "apikey" })?.value
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("<xml><results></results></xml>".utf8))
        }

        let indexer = TorznabIndexer(
            name: "TestTorznab",
            baseURL: "https://example.com/api",
            apiKey: "my-api-key",
            apiKeyTransport: .query,
            session: session
        )
        _ = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(state.apiKeyHeader == nil)
        #expect(state.apiKeyQuery == "my-api-key")
    }

    @Test func isProwlarrEndpointDetectsApiV1Search() async throws {
        let indexer = TorznabIndexer(
            name: "Prowlarr",
            baseURL: "https://example.com/api/v1/search",
            session: URLSession.shared
        )
        #expect(indexer.isProwlarrEndpoint == true)
    }

    @Test func isProwlarrEndpointReturnsFalseForStandardTorznab() async throws {
        let indexer = TorznabIndexer(
            name: "Standard",
            baseURL: "https://example.com/api",
            session: URLSession.shared
        )
        #expect(indexer.isProwlarrEndpoint == false)
    }

    @Test func prowlarrSearchTypeReturnsMoviesearchForMovie() async throws {
        let indexer = TorznabIndexer(
            name: "Prowlarr",
            baseURL: "https://example.com/api/v1/search",
            session: URLSession.shared
        )
        #expect(indexer.prowlarrSearchType(for: .movie) == "moviesearch")
    }

    @Test func prowlarrSearchTypeReturnsTvsearchForSeries() async throws {
        let indexer = TorznabIndexer(
            name: "Prowlarr",
            baseURL: "https://example.com/api/v1/search",
            session: URLSession.shared
        )
        #expect(indexer.prowlarrSearchType(for: .series) == "tvsearch")
    }

    @Test func prowlarrStructuredQueryFormatsCorrectly() async throws {
        let indexer = TorznabIndexer(
            name: "Prowlarr",
            baseURL: "https://example.com/api/v1/search",
            session: URLSession.shared
        )

        let result = indexer.prowlarrStructuredQuery(imdbId: "tt123", type: .movie, season: nil, episode: nil)
        #expect(result == "{ImdbId:tt123}")

        let withSeason = indexer.prowlarrStructuredQuery(imdbId: "tt123", type: .series, season: 1, episode: 5)
        #expect(withSeason == "{ImdbId:tt123} {Season:1} {Episode:5}")
    }

    @Test func dataLooksLikeJSONDetectsObject() async throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let data = Data("{\"results\":[]}".utf8)
        #expect(indexer.dataLooksLikeJSON(data) == true)
    }

    @Test func dataLooksLikeJSONDetectsArray() async throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let data = Data("[{\"title\":\"test\"}]".utf8)
        #expect(indexer.dataLooksLikeJSON(data) == true)
    }

    @Test func dataLooksLikeJSONRejectsXML() async throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let data = Data("<xml><results></results></xml>".utf8)
        #expect(indexer.dataLooksLikeJSON(data) == false)
    }

    @Test func dataLooksLikeJSONHandlesBOM() async throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let data = Data([0xEF, 0xBB, 0xBF, 0x7B, 0x22, 0x72, 0x65, 0x73, 0x75, 0x6C, 0x74, 0x73, 0x22, 0x3A, 0x5B, 0x5D, 0x7D])
        #expect(indexer.dataLooksLikeJSON(data) == true)
    }

    @Test func parseProwlarrJSONExtractsResults() async throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let data = Data("""
        {
            "results": [
                {
                    "title": "Test Movie",
                    "infoHash": "abc123def456abc123def456abc123def456abc1",
                    "size": 1073741824,
                    "seeders": 100,
                    "peers": 20
                }
            ]
        }
        """.utf8)

        let results = try indexer.parseProwlarrJSON(data)
        #expect(results.count == 1)
        #expect(results[0].title == "Test Movie")
        #expect(results[0].seeders == 100)
    }

    @Test func parseProwlarrJSONHandlesDirectArray() async throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let data = Data("""
        [
            {
                "title": "Direct Array Item",
                "hash": "abc123def456abc123def456abc123def456abc1",
                "size": 1024,
                "seeders": 5
            }
        ]
        """.utf8)

        let results = try indexer.parseProwlarrJSON(data)
        #expect(results.count == 1)
        #expect(results[0].title == "Direct Array Item")
    }

    @Test func parseProwlarrJSONExtractsInfoHashFromMagnetURL() async throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let data = Data("""
        {
            "results": [
                {
                    "title": "Magnet Only",
                    "magnetUrl": "magnet:?xt=urn:btih:abc123def456abc123def456abc123def456abc1",
                    "size": 1024
                }
            ]
        }
        """.utf8)

        let results = try indexer.parseProwlarrJSON(data)
        #expect(results.count == 1)
        #expect(results[0].infoHash == "abc123def456abc123def456abc123def456abc1")
    }

    @Test func parseProwlarrJSONThrowsForMalformedJSON() async throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let data = Data("{ invalid }".utf8)

        do {
            _ = try indexer.parseProwlarrJSON(data)
            Issue.record("Expected IndexerParseError")
        } catch let error as IndexerParseError {
            if case .invalidPayload(_, let reason) = error {
                #expect(reason.contains("malformed JSON"))
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func parseProwlarrJSONThrowsWhenNoUsableHashes() async throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let data = Data("""
        {
            "results": [
                {"title": "No Hash Item", "size": 1024}
            ]
        }
        """.utf8)

        do {
            _ = try indexer.parseProwlarrJSON(data)
            Issue.record("Expected IndexerParseError")
        } catch let error as IndexerParseError {
            if case .invalidPayload(_, let reason) = error {
                #expect(reason.contains("did not include any usable torrent hashes"))
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func buildRequestRequiresHTTPS() async throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "http://example.com/api")

        do {
            _ = try indexer.buildRequest(queryItems: [URLQueryItem(name: "t", value: "search")])
            Issue.record("Expected URLError.unsupportedURL")
        } catch let error as URLError {
            #expect(error.code == .unsupportedURL)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func buildRequestRejectsCleartextSingleLabelHostsBeforeSendingApiKey() async throws {
        let indexer = TorznabIndexer(
            name: "Prowlarr",
            baseURL: "http://prowlarr:9696/api",
            apiKey: "my-api-key",
            apiKeyTransport: .query
        )

        do {
            _ = try indexer.buildRequest(queryItems: [URLQueryItem(name: "t", value: "search")])
            Issue.record("Expected URLError.unsupportedURL")
        } catch let error as URLError {
            #expect(error.code == .unsupportedURL)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func buildRequestWithCategoryFilterAddsCategoryParam() async throws {
        final class RequestState: @unchecked Sendable {
            var queryItems: [URLQueryItem] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            state.queryItems = components?.queryItems ?? []
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("<xml><results></results></xml>".utf8))
        }

        let indexer = TorznabIndexer(
            name: "Test",
            baseURL: "https://example.com/api",
            categoryFilter: "2000",
            session: session
        )
        _ = try await indexer.search(imdbId: "tt000", type: .movie, season: nil, episode: nil)

        #expect(state.queryItems.first(where: { $0.name == "cat" })?.value == "2000")
    }

    @Test func searchByQueryFiltersSeriesResultsWithEpisodeContext() async throws {
        final class RequestState: @unchecked Sendable {
            var queryItems: [URLQueryItem] = []
        }
        let state = RequestState()

        let session = makeStubSession { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            state.queryItems = components?.queryItems ?? []
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("""
            {
                "results": [
                    {"title": "Show S01E01", "hash": "abc123def456abc123def456abc123def456abc1"},
                    {"title": "Show S01E02", "hash": "def123def456abc123def456abc123def456abc1"}
                ]
            }
            """.utf8))
        }

        let indexer = TorznabIndexer(
            name: "Test",
            baseURL: "https://example.com/api/v1/search",
            session: session
        )
        let results = try await indexer.searchByQuery(query: "Show S01E01", type: .series)

        #expect(results.count == 1)
        #expect(results[0].title.contains("S01E01"))
    }
}

// MARK: - TraktDefaults Tests

@Suite("TraktDefaults")
struct TraktDefaultsTestsSyncTraktsyncservicenetworktests {

    @Test func hasBundledCredentialsIsFalseForPlaceholder() {
        #expect(TraktDefaults.hasBundledCredentials == false)
    }

    @Test func resolvedCredentialsReturnsUserOverrideWhenProvided() {
        let result = TraktDefaults.resolvedCredentials(
            userClientId: "user-id",
            userClientSecret: "user-secret"
        )
        #expect(result?.clientId == "user-id")
        #expect(result?.clientSecret == "user-secret")
    }

    @Test func resolvedCredentialsReturnsNilForEmptyUserCredentials() {
        let result = TraktDefaults.resolvedCredentials(
            userClientId: "",
            userClientSecret: ""
        )
        #expect(result == nil)
    }

    @Test func resolvedCredentialsReturnsNilForWhitespaceOnly() {
        let result = TraktDefaults.resolvedCredentials(
            userClientId: "   ",
            userClientSecret: "   "
        )
        #expect(result == nil)
    }
}

// MARK: - TraktError Tests

@Suite("TraktError")
struct TraktErrorTestsSyncTraktsyncservicenetworktests {

    @Test func allErrorsHaveDescriptions() {
        let errors: [TraktError] = [
            .invalidURL,
            .httpError(500),
            .unauthorized,
            .notConnected,
            .authorizationSessionMissing,
            .authorizationSessionExpired,
            .authorizationStateMismatch,
            .deviceCodeExpired,
            .deviceCodeDenied,
            .deviceCodeInvalid,
            .deviceCodeAlreadyUsed,
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test func httpErrorIncludesStatusCode() {
        let error = TraktError.httpError(404)
        #expect(error.errorDescription?.contains("404") == true)
    }
}
