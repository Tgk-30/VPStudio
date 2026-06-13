import Foundation
import Testing
@testable import VPStudio

// MARK: - TorrentIndexer Protocol Conformance Tests

private func acceptsTorrentIndexer<T: TorrentIndexer>(_ value: T) -> Bool {
    _ = value
    return true
}

@Suite("TorrentIndexer Conformance")
struct TorrentIndexerConformanceTests {

    @Test func ytsIndexerConformsToTorrentIndexer() {
        let indexer = YTSIndexer()
        #expect(acceptsTorrentIndexer(indexer))
    }

    @Test func ytsIndexerNameIsYTS() {
        let indexer = YTSIndexer()
        #expect(indexer.name == "YTS")
    }

    @Test func eztvIndexerConformsToTorrentIndexer() {
        let indexer = EZTVIndexer()
        #expect(acceptsTorrentIndexer(indexer))
    }

    @Test func apiBayIndexerConformsToTorrentIndexer() {
        let indexer = APIBayIndexer(baseURL: "https://apibay.org")
        #expect(acceptsTorrentIndexer(indexer))
    }

    @Test func torznabIndexerConformsToTorrentIndexer() {
        let indexer = TorznabIndexer(
            name: "Test Torznab",
            baseURL: "https://torznab.example.com",
            endpointPath: "/api",
            apiKey: "test-key",
            categoryFilter: nil
        )
        #expect(acceptsTorrentIndexer(indexer))
    }

    @Test func stremioIndexerConformsToTorrentIndexer() {
        let indexer = StremioIndexer(
            name: "Test Stremio",
            baseURL: "https://stremio.example.com",
            endpointPath: "/manifest.json"
        )
        #expect(acceptsTorrentIndexer(indexer))
    }

    @Test func zileanIndexerConformsToTorrentIndexer() {
        let indexer = ZileanIndexer(
            baseURL: "https://zilean.example.com",
            endpointPath: "/api"
        )
        #expect(acceptsTorrentIndexer(indexer))
    }
}

// MARK: - TorrentIndexer Behavior Tests

@Suite("TorrentIndexer Behavior")
struct TorrentIndexerBehaviorTests {

    @Test func ytsSearchReturnsEmptyForSeriesType() async throws {
        let indexer = YTSIndexer()
        let results = try await indexer.search(imdbId: "tt0000001", type: .series, season: 1, episode: 5)
        #expect(results.isEmpty)
    }

    @Test func ytsSearchByQueryReturnsEmptyForSeriesType() async throws {
        let indexer = YTSIndexer()
        let results = try await indexer.searchByQuery(query: "The Matrix", type: .series)
        #expect(results.isEmpty)
    }

    @Test func torznabIndexerNameIsConfigurable() {
        let torznab = TorznabIndexer(
            name: "My Custom Indexer",
            baseURL: "https://torznab.example.com",
            endpointPath: "/api",
            apiKey: "test-key",
            categoryFilter: nil
        )
        #expect(torznab.name == "My Custom Indexer")
    }

    @Test func stremioIndexerNameIsConfigurable() {
        let stremio = StremioIndexer(
            name: "My Stremio",
            baseURL: "https://stremio.example.com",
            endpointPath: "/manifest.json"
        )
        #expect(stremio.name == "My Stremio")
    }
}

// MARK: - IndexerParseError Tests

@Suite("IndexerParseError")
struct IndexerParseErrorTestsTorrentindexerprotocolconformancetests {

    @Test func invalidPayloadHasDescription() {
        let error = IndexerParseError.invalidPayload(indexer: "TestIndexer", reason: "malformed JSON")
        #expect(error.errorDescription == "TestIndexer returned an invalid response: malformed JSON")
    }

    @Test func invalidPayloadIsEquatable() {
        let error1 = IndexerParseError.invalidPayload(indexer: "A", reason: "B")
        let error2 = IndexerParseError.invalidPayload(indexer: "A", reason: "B")
        let error3 = IndexerParseError.invalidPayload(indexer: "A", reason: "C")
        let error4 = IndexerParseError.invalidPayload(indexer: "B", reason: "B")

        #expect(error1 == error2)
        #expect(error1 != error3)
        #expect(error1 != error4)
    }
}

// MARK: - IndexerLogSanitizer Tests

@Suite("IndexeLogSanitizer")
struct IndexerLogSanitizerTestsTorrentindexerprotocolconformancetests {

    @Test func redactedURLStringReturnsNilForNil() {
        #expect(IndexerLogSanitizer.redactedURLString(nil) == "nil")
    }

    @Test func redactedURLStringReturnsNilForEmpty() {
        #expect(IndexerLogSanitizer.redactedURLString("") == "nil")
    }

    @Test func redactedURLStringRedactsUserInfo() {
        let url = URL(string: "https://user:password@example.com/path")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("REDACTED"))
        #expect(!redacted.contains("password"))
    }

    @Test func redactedURLStringRedactsSensitiveQueryItems() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: "movie"),
            URLQueryItem(name: "api_key", value: "secret123"),
        ]
        let url = components.url!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("q=movie"))
        #expect(redacted.contains("api_key=REDACTED"))
    }

    @Test func redactedURLStringHandlesURLsWithoutQuery() {
        let url = URL(string: "https://example.com/movie")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("example.com"))
    }

    @Test func redactedURLStringReturnsRedactedForInvalidURL() {
        let result = IndexerLogSanitizer.redactedURLString("not-a-valid-url")
        #expect(result == "REDACTED")
    }

    @Test func redactedURLStringHandlesMagnetURIs() {
        let magnet = "magnet:?xt=urn:btih:abc123def456&dn=Movie+Name"
        let result = IndexerLogSanitizer.redactedURLString(magnet)
        #expect(result.contains("magnet"))
    }
}
