import Foundation
import Testing
@testable import VPStudio

private final class IndexerFactoryRequestProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]
    static let lock = NSLock()
    static let handlerHeader = "X-VPStudio-Factory-ID"

    static func register(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> String {
        let id = UUID().uuidString
        lock.lock()
        requestHandlers[id] = handler
        lock.unlock()
        return id
    }

    static func handler(for id: String) -> ((URLRequest) throws -> (HTTPURLResponse, Data))? {
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

        var requestWithoutHeader = request
        requestWithoutHeader.setValue(nil, forHTTPHeaderField: Self.handlerHeader)

        do {
            let (response, data) = try handler(requestWithoutHeader)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeFactorySession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
    let id = IndexerFactoryRequestProtocol.register(handler)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [IndexerFactoryRequestProtocol.self]
    configuration.httpAdditionalHeaders = [IndexerFactoryRequestProtocol.handlerHeader: id]
    return URLSession(configuration: configuration)
}

@Suite("Torrent Indexer Factory")
struct TorrentIndexerFactoryTests {
    struct CaseData: Sendable {
        let config: IndexerConfig
        let shouldCreate: Bool
    }

    private static let cases: [CaseData] = {
        var values: [CaseData] = []
        let types: [IndexerConfig.IndexerType] = [.apiBay, .yts, .eztv, .torznab, .jackett, .prowlarr, .zilean, .stremio]
        for index in 0..<40 {
            let type = types[index % types.count]
            let needsURL = type == .torznab || type == .jackett || type == .prowlarr || type == .zilean || type == .stremio
            let includeURL = index % 2 == 0
            values.append(
                CaseData(
                    config: IndexerConfig(
                        id: "cfg-\(index)",
                        name: "Idx-\(index)",
                        indexerType: type,
                        baseURL: includeURL ? "https://indexer-\(index).example" : nil,
                        apiKey: "k",
                        isActive: true,
                        priority: index
                    ),
                    shouldCreate: needsURL ? includeURL : true
                )
            )
        }
        return values
    }()

    @Test(arguments: ExhaustiveMode.choose(fast: Array(cases.prefix(12)), full: cases))
    func factoryCreationMatrix(data: CaseData) {
        let created = IndexerFactory.create(from: data.config)
        #expect((created != nil) == data.shouldCreate)
    }

    @Test func ytsFactoryBuildsRequestsUsingConfiguredBaseURL() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
            var queryItems: [URLQueryItem] = []
        }

        let state = State()

        let session = makeFactorySession { request in
            state.requestURL = request.url
            state.queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"ok","data":{"movies":[]}}"#.utf8))
        }

        let indexer = IndexerFactory.create(
            from: IndexerConfig(
                id: "custom-yts",
                name: "Custom YTS",
                indexerType: .yts,
                baseURL: "https://yts.custom/root/",
                apiKey: nil,
                isActive: true,
                priority: 0
            ),
            session: session
        )

        let ytsIndexer = try #require(indexer as? YTSIndexer)
        _ = try await ytsIndexer.searchByQuery(query: "dune", type: .movie)

        #expect(state.requestURL?.host == "yts.custom")
        #expect(state.requestURL?.path == "/root/api/v2/list_movies.json")
        #expect(state.queryItems.first(where: { $0.name == "query_term" })?.value == "dune")
        #expect(state.queryItems.first(where: { $0.name == "limit" })?.value == "20")
    }

    @Test func eztvFactoryBuildsRequestsUsingConfiguredBaseURL() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
            var queryItems: [URLQueryItem] = []
        }

        let state = State()

        let session = makeFactorySession { request in
            state.requestURL = request.url
            state.queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"torrents":[]}"#.utf8))
        }

        let indexer = IndexerFactory.create(
            from: IndexerConfig(
                id: "custom-eztv",
                name: "Custom EZTV",
                indexerType: .eztv,
                baseURL: "https://eztv.custom/root/",
                apiKey: nil,
                isActive: true,
                priority: 0
            ),
            session: session
        )

        let ezTVIndexer = try #require(indexer as? EZTVIndexer)
        _ = try await ezTVIndexer.searchByQuery(query: "show", type: .series)

        #expect(state.requestURL?.host == "eztv.custom")
        #expect(state.requestURL?.path == "/root/get-torrents")
        #expect(state.queryItems.first(where: { $0.name == "search" })?.value == "show")
        #expect(state.queryItems.first(where: { $0.name == "limit" })?.value == "100")
    }

    @Test func apibayFactoryUsesConfiguredBaseURL() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
            var queryItems: [URLQueryItem] = []
        }

        let state = State()

        let session = makeFactorySession { request in
            state.requestURL = request.url
            state.queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"[{"id":"1","name":"Match","info_hash":"0123456789abcdef0123456789abcdef0123456789","size":"1024","seeders":"5","leechers":"2"}]"#
            return (response, Data(body.utf8))
        }

        let indexer = IndexerFactory.create(
            from: IndexerConfig(
                id: "custom-apibay",
                name: "Custom APIBay",
                indexerType: .apiBay,
                baseURL: "https://apibay.custom/root/",
                apiKey: nil,
                isActive: true,
                priority: 0
            ),
            session: session
        )

        let apiBayIndexer = try #require(indexer as? APIBayIndexer)
        _ = try await apiBayIndexer.searchByQuery(query: "dune", type: .movie)

        #expect(state.requestURL?.host == "apibay.custom")
        #expect(state.requestURL?.path == "/root/q.php")
        #expect(state.queryItems.first(where: { $0.name == "q" })?.value == "dune")
        #expect(state.queryItems.first(where: { $0.name == "cat" })?.value == "0")
    }

    @Test func zileanFactoryUsesInjectedSession() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
            var queryItems: [URLQueryItem] = []
        }

        let state = State()

        let session = makeFactorySession { request in
            state.requestURL = request.url
            state.queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[{"infoHash":"0123456789abcdef0123456789abcdef0123456789","rawTitle":"Zilean Item","size":123456}]"#.utf8))
        }

        let indexer = IndexerFactory.create(
            from: IndexerConfig(
                id: "custom-zilean",
                name: "Custom Zilean",
                indexerType: .zilean,
                baseURL: "https://zilean.custom/root/",
                apiKey: nil,
                isActive: true,
                priority: 0
            ),
            session: session
        )

        let zileanIndexer = try #require(indexer as? ZileanIndexer)
        let results = try await zileanIndexer.searchByQuery(query: "show", type: .movie)

        #expect(results.count == 1)
        #expect(state.requestURL?.host == "zilean.custom")
        #expect(state.requestURL?.path == "/root/api/dmm/search")
        #expect(state.queryItems.first(where: { $0.name == "query" })?.value == "show")
    }

    @Test func stremioFactoryUsesInjectedSession() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
            var queryItems: [URLQueryItem] = []
        }

        let state = State()

        let session = makeFactorySession { request in
            state.requestURL = request.url
            state.queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"streams":[{"title":"A","infoHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#.utf8))
        }

        let indexer = IndexerFactory.create(
            from: IndexerConfig(
                id: "custom-stremio",
                name: "Custom Stremio",
                indexerType: .stremio,
                baseURL: "https://stremio.custom/base",
                apiKey: nil,
                isActive: true,
                priority: 0
            ),
            session: session
        )

        let stremioIndexer = try #require(indexer as? StremioIndexer)
        _ = try await stremioIndexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)

        #expect(state.requestURL?.host == "stremio.custom")
        #expect(state.requestURL?.path == "/base/stream/movie/tt1234567.json")
    }

    @Test func torznabFactoryUsesInjectedSession() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
            var queryItems: [URLQueryItem] = []
        }

        let state = State()

        let session = makeFactorySession { request in
            state.requestURL = request.url
            state.queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let indexer = IndexerFactory.create(
            from: IndexerConfig(
                id: "custom-jackett",
                name: "Custom Jackett",
                indexerType: .jackett,
                baseURL: "https://jackett.custom/base",
                apiKey: "key",
                isActive: true,
                priority: 0,
                endpointPath: "/api/v2.0/indexers/all/results/torznab/api"
            ),
            session: session
        )

        let torznabIndexer = try #require(indexer as? TorznabIndexer)
        _ = try await torznabIndexer.searchByQuery(query: "show", type: .movie)

        #expect(state.requestURL?.host == "jackett.custom")
        #expect(state.requestURL?.path == "/base/api/v2.0/indexers/all/results/torznab/api")
        #expect(state.queryItems.first(where: { $0.name == "t" })?.value == "search")
        #expect(state.queryItems.first(where: { $0.name == "q" })?.value == "show")
    }

    @Test func jackettFactoryDefaultsEndpointPathWhenMissing() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
            var queryItems: [URLQueryItem] = []
            var apiKeyQuery: String?
        }

        let state = State()

        let session = makeFactorySession { request in
            state.requestURL = request.url
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            state.queryItems = components?.queryItems ?? []
            state.apiKeyQuery = components?
                .queryItems?
                .first(where: { $0.name == "apikey" })?
                .value
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let indexer = IndexerFactory.create(
            from: IndexerConfig(
                id: "missing-jackett-path",
                name: "Missing Jackett Path",
                indexerType: .jackett,
                baseURL: "https://jackett.custom/root",
                apiKey: "query-key",
                isActive: true,
                priority: 0,
                endpointPath: "",
                apiKeyTransport: .query
            ),
            session: session
        )

        let jackettIndexer = try #require(indexer as? TorznabIndexer)
        _ = try await jackettIndexer.searchByQuery(query: "dune", type: .movie)

        #expect(state.requestURL?.path == "/root/api/v2.0/indexers/all/results/torznab/api")
        #expect(state.queryItems.first(where: { $0.name == "t" })?.value == "search")
        #expect(state.queryItems.first(where: { $0.name == "q" })?.value == "dune")
        #expect(state.apiKeyQuery == "query-key")
    }

    @Test func prowlarrFactoryDefaultsEndpointPathWhenMissing() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
            var queryItems: [URLQueryItem] = []
            var apiKeyHeader: String?
        }

        let state = State()

        let session = makeFactorySession { request in
            state.requestURL = request.url
            state.queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            state.apiKeyHeader = request.value(forHTTPHeaderField: "X-Api-Key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("<caps></caps>".utf8))
        }

        let indexer = IndexerFactory.create(
            from: IndexerConfig(
                id: "missing-prowlarr-path",
                name: "Missing Prowlarr Path",
                indexerType: .prowlarr,
                baseURL: "https://prowlarr.custom/base",
                apiKey: "prowlarr-key",
                isActive: true,
                priority: 0,
                endpointPath: ""
            ),
            session: session
        )

        let prowlarrIndexer = try #require(indexer as? TorznabIndexer)
        _ = try await prowlarrIndexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)

        #expect(state.requestURL?.path == "/base/api/v1/search")
        #expect(state.apiKeyHeader == "prowlarr-key")
        #expect(state.queryItems.first(where: { $0.name == "type" })?.value == "moviesearch")
        #expect(state.queryItems.first(where: { $0.name == "query" })?.value == "{ImdbId:tt1234567}")
    }

    @Test func torznabFactoryDefaultsEndpointPathWhenMissing() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
            var queryItems: [URLQueryItem] = []
            var apiKeyQuery: String?
        }

        let state = State()

        let session = makeFactorySession { request in
            state.requestURL = request.url
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            state.queryItems = components?.queryItems ?? []
            state.apiKeyQuery = components?
                .queryItems?
                .first(where: { $0.name == "apikey" })?
                .value
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"[{"title":"T","infoHash":"0123456789abcdef0123456789abcdef0123456789"}]"#
            return (response, Data(body.utf8))
        }

        let indexer = IndexerFactory.create(
            from: IndexerConfig(
                id: "missing-torznab-path",
                name: "Missing Torznab Path",
                indexerType: .torznab,
                baseURL: "https://torznab.custom/base",
                apiKey: "query-key",
                isActive: true,
                priority: 0,
                endpointPath: "",
                apiKeyTransport: .query
            ),
            session: session
        )

        let torznabIndexer = try #require(indexer as? TorznabIndexer)
        _ = try await torznabIndexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)

        #expect(state.requestURL?.path == "/base/api")
        #expect(state.queryItems.first(where: { $0.name == "t" })?.value == "search")
        #expect(state.queryItems.first(where: { $0.name == "imdbid" })?.value == "tt1234567")
        #expect(state.apiKeyQuery == "query-key")
    }

    @Test func prowlarrFactoryUsesInjectedSession() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
            var queryItems: [URLQueryItem] = []
            var apiKeyHeader: String?
        }

        let state = State()

        let session = makeFactorySession { request in
            state.requestURL = request.url
            state.queryItems = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            state.apiKeyHeader = request.value(forHTTPHeaderField: "X-Api-Key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("<caps></caps>".utf8))
        }

        let indexer = IndexerFactory.create(
            from: IndexerConfig(
                id: "custom-prowlarr",
                name: "Custom Prowlarr",
                indexerType: .prowlarr,
                baseURL: "https://prowlarr.custom/base",
                apiKey: "prowlarr-key",
                isActive: true,
                priority: 0,
                endpointPath: "/api/v1/search",
                apiKeyTransport: .header
            ),
            session: session
        )

        let prowlarrIndexer = try #require(indexer as? TorznabIndexer)
        _ = try await prowlarrIndexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)

        #expect(state.requestURL?.host == "prowlarr.custom")
        #expect(state.requestURL?.path == "/base/api/v1/search")
        #expect(state.apiKeyHeader == "prowlarr-key")
        #expect(state.queryItems.first(where: { $0.name == "type" })?.value == "moviesearch")
        #expect(state.queryItems.first(where: { $0.name == "query" })?.value == "{ImdbId:tt1234567}")
    }
}
