import Foundation
import AVFoundation
import Testing
@testable import VPStudio

@Suite("IndexerConnectivityTester BuildURL Tests")
struct IndexerConnectivityTesterBuildURLTestsServicesSpatialaudioandconnectivitytests {
    @Test
    func buildURLAddsHTTPScheme() throws {
        let url = try IndexerConnectivityTester_BuildURL.build(
            baseURL: "https://example.com",
            path: "/api",
            queryItems: []
        )

        #expect(url.scheme == "https")
    }

    @Test
    func buildURLNormalizesTrailingSlash() throws {
        let url = try IndexerConnectivityTester_BuildURL.build(
            baseURL: "https://example.com/",
            path: "/api/",
            queryItems: []
        )

        #expect(url.path == "/api")
    }

    @Test
    func buildURLAddsQueryItems() throws {
        let url = try IndexerConnectivityTester_BuildURL.build(
            baseURL: "https://example.com",
            path: "/search",
            queryItems: [
                URLQueryItem(name: "q", value: "test"),
                URLQueryItem(name: "limit", value: "10")
            ]
        )

        #expect(url.query?.contains("q=test") == true)
        #expect(url.query?.contains("limit=10") == true)
    }

    @Test
    func buildURLThrowsForInvalidBaseURL() {
        do {
            _ = try IndexerConnectivityTester_BuildURL.build(
                baseURL: "not a url",
                path: "/api",
                queryItems: []
            )
            Issue.record("Expected throw")
        } catch IndexerConnectivityError.invalidBaseURL {
        } catch {
            Issue.record("Expected invalidBaseURL, got \(error)")
        }
    }

    @Test
    func buildURLThrowsForRemoteHttpScheme() {
        do {
            _ = try IndexerConnectivityTester_BuildURL.build(
                baseURL: "http://example.com",
                path: "/api",
                queryItems: []
            )
            Issue.record("Expected throw")
        } catch IndexerConnectivityError.invalidBaseURL {
        } catch {
            Issue.record("Expected invalidBaseURL, got \(error)")
        }
    }

    @Test
    func buildURLAllowsLocalHttpScheme() throws {
        let url = try IndexerConnectivityTester_BuildURL.build(
            baseURL: "http://prowlarr.local:9696",
            path: "/api/v1/search",
            queryItems: []
        )

        #expect(url.scheme == "http")
        #expect(url.host == "prowlarr.local")
        #expect(url.port == 9696)
        #expect(url.path == "/api/v1/search")
    }

    @Test
    func buildURLHandlesEmptyPath() throws {
        let url = try IndexerConnectivityTester_BuildURL.build(
            baseURL: "https://example.com",
            path: "",
            queryItems: []
        )

        #expect(url.path == "")
    }

    @Test
    func buildURLHandlesBothEmptyPathAndBasePath() throws {
        let url = try IndexerConnectivityTester_BuildURL.build(
            baseURL: "https://example.com/",
            path: "",
            queryItems: []
        )

        #expect(url.path == "")
    }
}

private enum IndexerConnectivityTester_BuildURL {
    static func build(baseURL: String, path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw IndexerConnectivityError.invalidBaseURL
        }

        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let appendPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch (normalizedPath.isEmpty, appendPath.isEmpty) {
        case (true, false):
            components.path = "/\(appendPath)"
        case (false, true):
            components.path = "/\(normalizedPath)"
        case (false, false):
            components.path = "/\(normalizedPath)/\(appendPath)"
        default:
            components.path = ""
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url,
              IndexerURLSecurityPolicy.permits(url: url) else {
            throw IndexerConnectivityError.invalidBaseURL
        }
        return url
    }
}

@Suite("IndexerConnectivityTester validatePayload")
struct IndexerConnectivityTesterValidationTests {
    @Test
    func stremioManifestValidationRejectsEmptyCatalogs() async throws {
        let config = IndexerConfig(name: "Test Stremio", indexerType: .stremio, baseURL: "https://stremio.example.com")

        let invalidManifest = """
        {"catalogs": []}
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://stremio.example.com/manifest.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, invalidManifest)
        }

        do {
            try await IndexerConnectivityTester.testConnection(for: config, session: session)
            Issue.record("Expected incompatibleManifest error")
        } catch IndexerConnectivityError.incompatibleManifest {
        } catch {
            Issue.record("Expected incompatibleManifest, got \(error)")
        }
    }

    @Test
    func stremioManifestValidationRejectsNonMovieTVCatalogs() async throws {
        let config = IndexerConfig(name: "Test Stremio", indexerType: .stremio, baseURL: "https://stremio.example.com")

        let invalidManifest = """
        {"catalogs": [{"type": "person", "extra": [{"name": "search"}]}]}
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://stremio.example.com/manifest.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, invalidManifest)
        }

        do {
            try await IndexerConnectivityTester.testConnection(for: config, session: session)
            Issue.record("Expected incompatibleManifest error")
        } catch IndexerConnectivityError.incompatibleManifest {
        } catch {
            Issue.record("Expected incompatibleManifest, got \(error)")
        }
    }

    @Test
    func stremioManifestValidationAcceptsValidMovieCatalog() async throws {
        let config = IndexerConfig(name: "Test Stremio", indexerType: .stremio, baseURL: "https://stremio.example.com")

        let validManifest = """
        {"catalogs": [{"type": "movie", "extra": [{"name": "search"}]}]}
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://stremio.example.com/manifest.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, validManifest)
        }

        try await IndexerConnectivityTester.testConnection(for: config, session: session)
    }

    @Test
    func stremioManifestValidationAcceptsValidSeriesCatalog() async throws {
        let config = IndexerConfig(name: "Test Stremio", indexerType: .stremio, baseURL: "https://stremio.example.com")

        let validManifest = """
        {"catalogs": [{"type": "series", "extra": [{"name": "search"}, {"name": "meta"}]}]}
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://stremio.example.com/manifest.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, validManifest)
        }

        try await IndexerConnectivityTester.testConnection(for: config, session: session)
    }

    @Test
    func stremioManifestValidationRejectsMissingSearchExtra() async throws {
        let config = IndexerConfig(name: "Test Stremio", indexerType: .stremio, baseURL: "https://stremio.example.com")

        let invalidManifest = """
        {"catalogs": [{"type": "movie", "extra": [{"name": "genre"}]}]}
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://stremio.example.com/manifest.json")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, invalidManifest)
        }

        do {
            try await IndexerConnectivityTester.testConnection(for: config, session: session)
            Issue.record("Expected incompatibleManifest error")
        } catch IndexerConnectivityError.incompatibleManifest {
        } catch {
            Issue.record("Expected incompatibleManifest, got \(error)")
        }
    }

    @Test
    func torznabCapsValidationRejectsInvalidXML() async throws {
        let config = IndexerConfig(
            name: "Test Torznab",
            indexerType: .torznab,
            baseURL: "https://torznab.example.com",
            apiKey: "test-key"
        )

        let invalidXML = """
        <notatorznab></notatorznab>
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://torznab.example.com/api")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, invalidXML)
        }

        do {
            try await IndexerConnectivityTester.testConnection(for: config, session: session)
            Issue.record("Expected invalidResponse error")
        } catch IndexerConnectivityError.invalidResponse {
        } catch {
            Issue.record("Expected invalidResponse, got \(error)")
        }
    }

    @Test
    func torznabCapsValidationAcceptsCapsElement() async throws {
        let config = IndexerConfig(
            name: "Test Torznab",
            indexerType: .torznab,
            baseURL: "https://torznab.example.com",
            apiKey: "test-key"
        )

        let validXML = """
        <caps><searching><search available="yes"/></searching></caps>
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://torznab.example.com/api")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, validXML)
        }

        try await IndexerConnectivityTester.testConnection(for: config, session: session)
    }

    @Test
    func torznabCapsValidationAcceptsErrorElement() async throws {
        let config = IndexerConfig(
            name: "Test Torznab",
            indexerType: .torznab,
            baseURL: "https://torznab.example.com",
            apiKey: "test-key"
        )

        let errorXML = """
        <error>Some error occurred</error>
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://torznab.example.com/api")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, errorXML)
        }

        try await IndexerConnectivityTester.testConnection(for: config, session: session)
    }

    @Test
    func genericJSONValidationAcceptsObjectResponse() async throws {
        let config = IndexerConfig(name: "APiBay", indexerType: .apiBay)

        let jsonObject = """
        {"status": "ok", "data": []}
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://apibay.org")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, jsonObject)
        }

        try await IndexerConnectivityTester.testConnection(for: config, session: session)
    }

    @Test
    func genericJSONValidationAcceptsArrayResponse() async throws {
        let config = IndexerConfig(name: "YTS", indexerType: .yts)

        let jsonArray = """
        []
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://yts.torrentbay.st")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, jsonArray)
        }

        try await IndexerConnectivityTester.testConnection(for: config, session: session)
    }

    @Test
    func genericJSONValidationRejectsNonJSON() async throws {
        let config = IndexerConfig(name: "EZTV", indexerType: .eztv)

        let nonJSON = """
        This is plain text, not JSON
        """.data(using: .utf8)!

        let session = URLProtocolHarness.makeSession { _ in
            let response = HTTPURLResponse(url: URL(string: "https://eztvx.to")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, nonJSON)
        }

        do {
            try await IndexerConnectivityTester.testConnection(for: config, session: session)
            Issue.record("Expected invalidResponse error")
        } catch IndexerConnectivityError.invalidResponse {
        } catch {
            Issue.record("Expected invalidResponse, got \(error)")
        }
    }
}
