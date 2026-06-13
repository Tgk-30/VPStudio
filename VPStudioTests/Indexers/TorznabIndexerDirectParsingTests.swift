import Foundation
import Testing
@testable import VPStudio

// MARK: - dataLooksLikeJSON

@Suite("TorznabIndexerDataLooksLikeJSON")
struct TorznabIndexerDataLooksLikeJSONTests {

    private func indexer() -> TorznabIndexer {
        TorznabIndexer(name: "Test", baseURL: "https://example.com")
    }

    @Test func detectsObjectJSON() {
        let data = Data("{\"key\": \"value\"}".utf8)
        #expect(indexer().dataLooksLikeJSON(data) == true)
    }

    @Test func detectsArrayJSON() {
        let data = Data("[1, 2, 3]".utf8)
        #expect(indexer().dataLooksLikeJSON(data) == true)
    }

    @Test func detectsJSONAfterWhitespace() {
        let data = Data("   {\"a\": 1}".utf8)
        #expect(indexer().dataLooksLikeJSON(data) == true)
    }

    @Test func detectsJSONAfterBOM() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("{\"a\": 1}".utf8))
        #expect(indexer().dataLooksLikeJSON(data) == true)
    }

    @Test func detectsJSONAfterUTF16BOMBytes() {
        var bigEndianData = Data([0xFE, 0xFF])
        bigEndianData.append(Data("  {\"a\": 1}".utf8))

        var littleEndianData = Data([0xFF, 0xFE])
        littleEndianData.append(Data("\n[1]".utf8))

        #expect(indexer().dataLooksLikeJSON(bigEndianData) == true)
        #expect(indexer().dataLooksLikeJSON(littleEndianData) == true)
    }

    @Test func rejectsXML() {
        let data = Data("<?xml version=\"1.0\"?><rss></rss>".utf8)
        #expect(indexer().dataLooksLikeJSON(data) == false)
    }

    @Test func rejectsHTML() {
        let data = Data("<html></html>".utf8)
        #expect(indexer().dataLooksLikeJSON(data) == false)
    }

    @Test func rejectsEmptyData() {
        #expect(indexer().dataLooksLikeJSON(Data()) == false)
    }
}

// MARK: - parseTorznabXML

@Suite("TorznabIndexerParseTorznabXML")
struct TorznabIndexerParseTorznabXMLTests {

    private func indexer() -> TorznabIndexer {
        TorznabIndexer(name: "TestIndexer", baseURL: "https://example.com")
    }

    @Test func parsesSingleItemWithAttributes() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
        <title>Movie.2024.1080p.WEB-DL</title>
        <torznab:attr name="infohash" value="abc123def4567890abc123def4567890abc12345"/>
        <torznab:attr name="size" value="2000000000"/>
        <torznab:attr name="seeders" value="50"/>
        <torznab:attr name="peers" value="55"/>
        </item>
        </channel></rss>
        """
        let results = try indexer().parseTorznabXML(Data(xml.utf8))
        #expect(results.count == 1)
        #expect(results[0].title == "Movie.2024.1080p.WEB-DL")
        #expect(results[0].infoHash == "abc123def4567890abc123def4567890abc12345")
        #expect(results[0].sizeBytes == 2_000_000_000)
        #expect(results[0].seeders == 50)
        #expect(results[0].leechers == 55)
    }

    @Test func parsesMultipleItems() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
        <title>Movie.A.1080p</title>
        <torznab:attr name="infohash" value="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"/>
        </item>
        <item>
        <title>Movie.B.720p</title>
        <torznab:attr name="infohash" value="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"/>
        </item>
        </channel></rss>
        """
        let results = try indexer().parseTorznabXML(Data(xml.utf8))
        #expect(results.count == 2)
        #expect(results[0].title == "Movie.A.1080p")
        #expect(results[1].title == "Movie.B.720p")
    }

    @Test func skipsItemsWithoutTitle() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
        <torznab:attr name="infohash" value="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"/>
        </item>
        <item>
        <title>Valid.Title</title>
        <torznab:attr name="infohash" value="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"/>
        </item>
        </channel></rss>
        """
        let results = try indexer().parseTorznabXML(Data(xml.utf8))
        #expect(results.count == 1)
        #expect(results[0].title == "Valid.Title")
    }

    @Test func skipsItemsWithoutHash() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
        <title>No Hash Movie</title>
        </item>
        </channel></rss>
        """
        let results = try indexer().parseTorznabXML(Data(xml.utf8))
        #expect(results.isEmpty)
    }

    @Test func emptyXMLReturnsEmptyResults() throws {
        let xml = "<?xml version=\"1.0\"?><rss><channel></channel></rss>"
        let results = try indexer().parseTorznabXML(Data(xml.utf8))
        #expect(results.isEmpty)
    }

    @Test func throwsForHTMLResponse() {
        let html = "<html><body>Error</body></html>"
        #expect(throws: IndexerParseError.self) {
            try indexer().parseTorznabXML(Data(html.utf8))
        }
    }

    @Test func throwsForMalformedXML() {
        let badXML = "<rss><channel><item><title>Unclosed"
        #expect(throws: IndexerParseError.self) {
            try indexer().parseTorznabXML(Data(badXML.utf8))
        }
    }

    @Test func parsesMagnetURIFromAttributes() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
        <title>Movie.2024</title>
        <torznab:attr name="magneturl" value="magnet:?xt=urn:btih:abc123"/>
        </item>
        </channel></rss>
        """
        let results = try indexer().parseTorznabXML(Data(xml.utf8))
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:abc123")
    }

    @Test func extractsHashFromMagnetURIWhenInfoHashMissing() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
        <title>Movie.2024</title>
        <torznab:attr name="magneturl" value="magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"/>
        </item>
        </channel></rss>
        """
        let results = try indexer().parseTorznabXML(Data(xml.utf8))
        #expect(results[0].infoHash == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    }

    @Test func decodesDoubleEscapedTitleEntities() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
        <title>Movie &amp;#x42;&amp;#111; &amp;quot;Edition&amp;quot; &amp;nbsp; Final</title>
        <guid>bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb</guid>
        </item>
        </channel></rss>
        """
        let results = try indexer().parseTorznabXML(Data(xml.utf8))
        #expect(results[0].title == "Movie Bo \"Edition\"   Final")
    }

    @Test func extractsHashFromEnclosureURLWhenOtherHashFieldsAreMissing() throws {
        let hash = "cccccccccccccccccccccccccccccccccccccccc"
        let xml = """
        <?xml version="1.0"?>
        <rss><channel>
        <item>
        <title>Enclosure Movie</title>
        <enclosure url="https://tracker.example/download/\(hash).torrent?token=a&amp;amp;b=2"/>
        </item>
        </channel></rss>
        """
        let results = try indexer().parseTorznabXML(Data(xml.utf8))
        #expect(results[0].infoHash == hash)
        #expect(results[0].magnetURI == nil)
    }
}

// MARK: - parseProwlarrJSON

@Suite("TorznabIndexerParseProwlarrJSON")
struct TorznabIndexerParseProwlarrJSONTests {

    private func indexer() -> TorznabIndexer {
        TorznabIndexer(name: "TestIndexer", baseURL: "https://example.com")
    }

    @Test func parsesTopLevelArray() throws {
        let json = """
        [
            {
                "title": "Movie.2024.1080p",
                "infoHash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "size": 2000000000,
                "seeders": 50,
                "peers": 55
            }
        ]
        """
        let results = try indexer().parseProwlarrJSON(Data(json.utf8))
        #expect(results.count == 1)
        #expect(results[0].title == "Movie.2024.1080p")
        #expect(results[0].infoHash == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        #expect(results[0].sizeBytes == 2_000_000_000)
        #expect(results[0].seeders == 50)
        #expect(results[0].leechers == 55)
    }

    @Test func parsesResultsObject() throws {
        let json = """
        {
            "results": [
                {
                    "title": "Show.S01E01.1080p",
                    "infoHash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    "size": 1500000000,
                    "seeders": 100,
                    "leechers": 10
                }
            ]
        }
        """
        let results = try indexer().parseProwlarrJSON(Data(json.utf8))
        #expect(results.count == 1)
        #expect(results[0].title == "Show.S01E01.1080p")
        #expect(results[0].seeders == 100)
        #expect(results[0].leechers == 10)
    }

    @Test func usesHashFieldAsFallback() throws {
        let json = """
        [
            {
                "title": "Movie.2024",
                "hash": "cccccccccccccccccccccccccccccccccccccccc"
            }
        ]
        """
        let results = try indexer().parseProwlarrJSON(Data(json.utf8))
        #expect(results[0].infoHash == "cccccccccccccccccccccccccccccccccccccccc")
    }

    @Test func extractsHashFromMagnetUrl() throws {
        let json = """
        [
            {
                "title": "Movie.2024",
                "magnetUrl": "magnet:?xt=urn:btih:dddddddddddddddddddddddddddddddddddddddd"
            }
        ]
        """
        let results = try indexer().parseProwlarrJSON(Data(json.utf8))
        #expect(results[0].infoHash == "dddddddddddddddddddddddddddddddddddddddd")
    }

    @Test func skipsItemsWithoutUsableHash() throws {
        let json = """
        [
            {"title": "No Hash", "size": 100},
            {"title": "Has Hash", "infoHash": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}
        ]
        """
        let results = try indexer().parseProwlarrJSON(Data(json.utf8))
        #expect(results.count == 1)
        #expect(results[0].title == "Has Hash")
    }

    @Test func throwsForMalformedJSON() {
        #expect(throws: IndexerParseError.self) {
            try indexer().parseProwlarrJSON(Data("not json".utf8))
        }
    }

    @Test func throwsForMissingResultsArray() {
        let json = "{\"total\": 10}"
        #expect(throws: IndexerParseError.self) {
            try indexer().parseProwlarrJSON(Data(json.utf8))
        }
    }

    @Test func throwsWhenAllItemsLackHash() {
        let json = """
        [
            {"title": "No Hash 1"},
            {"title": "No Hash 2"}
        ]
        """
        #expect(throws: IndexerParseError.self) {
            try indexer().parseProwlarrJSON(Data(json.utf8))
        }
    }

    @Test func emptyArrayReturnsEmpty() throws {
        let results = try indexer().parseProwlarrJSON(Data("[]".utf8))
        #expect(results.isEmpty)
    }

    @Test func parsesNameFieldAsTitleFallback() throws {
        let json = """
        [
            {
                "name": "Movie.2024.720p",
                "infoHash": "ffffffffffffffffffffffffffffffffffffffff"
            }
        ]
        """
        let results = try indexer().parseProwlarrJSON(Data(json.utf8))
        #expect(results[0].title == "Movie.2024.720p")
    }
}

// MARK: - buildRequest

@Suite("TorznabIndexerBuildRequest")
struct TorznabIndexerBuildRequestTests {

    @Test func torznabSearchBuildsCorrectURL() throws {
        let indexer = TorznabIndexer(
            name: "Test",
            baseURL: "https://indexer.example",
            apiKey: "secret123",
            apiKeyTransport: .header
        )
        let request = try indexer.buildRequest(queryItems: [
            URLQueryItem(name: "t", value: "search"),
            URLQueryItem(name: "q", value: "dune"),
        ])
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "/api")
        #expect(components.queryItems?.contains(where: { $0.name == "t" && $0.value == "search" }) == true)
        #expect(components.queryItems?.contains(where: { $0.name == "q" && $0.value == "dune" }) == true)
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == "secret123")
        #expect(request.timeoutInterval == 20)
    }

    @Test func queryApiKeyTransportPutsKeyInQuery() throws {
        let indexer = TorznabIndexer(
            name: "Test",
            baseURL: "https://indexer.example",
            apiKey: "secret123",
            apiKeyTransport: .query
        )
        let request = try indexer.buildRequest(queryItems: [])
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.contains(where: { $0.name == "apikey" && $0.value == "secret123" }) == true)
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == nil)
    }

    @Test func localHttpBaseURLIsAllowedForSelfHostedAggregators() throws {
        let indexer = TorznabIndexer(
            name: "Local Prowlarr",
            baseURL: "http://127.0.0.1:9696",
            endpointPath: "/api/v1/search",
            apiKey: "secret123",
            apiKeyTransport: .header
        )
        let request = try indexer.buildRequest(queryItems: [
            URLQueryItem(name: "query", value: "dune"),
        ])
        let url = try #require(request.url)

        #expect(url.scheme == "http")
        #expect(url.host == "127.0.0.1")
        #expect(url.port == 9696)
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == "secret123")
    }

    @Test func emptyApiKeyOmitsAuth() throws {
        let indexer = TorznabIndexer(
            name: "Test",
            baseURL: "https://indexer.example",
            apiKey: "",
            apiKeyTransport: .header
        )
        let request = try indexer.buildRequest(queryItems: [])
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == nil)
    }

    @Test func rejectsRemoteHTTPURL() {
        let indexer = TorznabIndexer(
            name: "Test",
            baseURL: "http://insecure.example"
        )
        #expect(throws: URLError.self) {
            try indexer.buildRequest(queryItems: [])
        }
    }

    @Test func categoryFilterAppendsCatParameter() throws {
        let indexer = TorznabIndexer(
            name: "Test",
            baseURL: "https://indexer.example",
            categoryFilter: "2000"
        )
        let request = try indexer.buildRequest(queryItems: [])
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.contains(where: { $0.name == "cat" && $0.value == "2000" }) == true)
    }

    @Test func nilQueryItemsAreFiltered() throws {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://indexer.example")
        let request = try indexer.buildRequest(queryItems: [
            URLQueryItem(name: "q", value: "test"),
            URLQueryItem(name: "empty", value: nil),
        ])
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.contains(where: { $0.name == "empty" }) == false)
    }
}

// MARK: - prowlarr helpers

@Suite("TorznabIndexerProwlarrHelpers")
struct TorznabIndexerProwlarrHelpersTests {

    @Test func detectsProwlarrEndpoint() {
        let indexer = TorznabIndexer(
            name: "Prowlarr",
            baseURL: "https://prowlarr.example",
            endpointPath: "/api/v1/search"
        )
        #expect(indexer.isProwlarrEndpoint == true)
    }

    @Test func nonProwlarrEndpointIsFalse() {
        let indexer = TorznabIndexer(
            name: "Jackett",
            baseURL: "https://jackett.example",
            endpointPath: "/api"
        )
        #expect(indexer.isProwlarrEndpoint == false)
    }

    @Test func prowlarrSearchTypeForMovie() {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        #expect(indexer.prowlarrSearchType(for: .movie) == "moviesearch")
    }

    @Test func prowlarrSearchTypeForSeries() {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        #expect(indexer.prowlarrSearchType(for: .series) == "tvsearch")
    }

    @Test func prowlarrStructuredQueryWithImdbOnly() {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let query = indexer.prowlarrStructuredQuery(imdbId: "tt123", type: .movie, season: nil, episode: nil)
        #expect(query == "{ImdbId:tt123}")
    }

    @Test func prowlarrStructuredQueryWithSeasonAndEpisode() {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let query = indexer.prowlarrStructuredQuery(imdbId: "tt456", type: .series, season: 1, episode: 2)
        #expect(query == "{ImdbId:tt456} {Season:1} {Episode:2}")
    }

    @Test func prowlarrStructuredQueryMovieIgnoresSeasonEpisode() {
        let indexer = TorznabIndexer(name: "Test", baseURL: "https://example.com")
        let query = indexer.prowlarrStructuredQuery(imdbId: "tt789", type: .movie, season: 1, episode: 2)
        #expect(query == "{ImdbId:tt789}")
    }
}
