import Foundation
import Testing
@testable import VPStudio

// MARK: - APIBayIndexer

@Suite("APIBayIndexer")
struct APIBayIndexerTestsIndexertests {
    @Test func searchConstructsCorrectQueryAndCategoryParameters() async throws {
        final class State: @unchecked Sendable {
            var query: String?
            var cat: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.query = components?.queryItems?.first(where: { $0.name == "q" })?.value
            state.cat = components?.queryItems?.first(where: { $0.name == "cat" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        _ = try await indexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)

        #expect(state.query == "tt1234567")
        #expect(state.cat == "0")
    }

    @Test func searchAppendsEpisodeContextToIMDbQuery() async throws {
        final class State: @unchecked Sendable { var query: String? }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.query = components?.queryItems?.first(where: { $0.name == "q" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        _ = try await indexer.search(imdbId: "tt7654321", type: .series, season: 3, episode: 5)

        #expect(state.query == "tt7654321 S03E05")
    }

    @Test func searchByQueryPreservesOriginalQueryText() async throws {
        final class State: @unchecked Sendable { var query: String? }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.query = components?.queryItems?.first(where: { $0.name == "q" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        _ = try await indexer.searchByQuery(query: "Show S01E02", type: .series)

        #expect(state.query == "Show S01E02")
    }

    @Test func searchParsesValidJSONResponseWithMultipleTorrents() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"1","name":"Movie 1080p","info_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":"1073741824","seeders":"100","leechers":"10"},
                {"id":"2","name":"Movie 720p","info_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":"536870912","seeders":"50","leechers":"5"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Movie", type: .movie)

        #expect(results.count == 2)
        #expect(results[0].infoHash == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        #expect(results[0].title == "Movie 1080p")
        #expect(results[0].sizeBytes == 1_073_741_824)
        #expect(results[0].seeders == 100)
        #expect(results[0].leechers == 10)
        #expect(results[0].quality == .hd1080p)
        #expect(results[0].indexerName == "APiBay")
        #expect(results[1].infoHash == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        #expect(results[1].sizeBytes == 536_870_912)
        #expect(results[1].seeders == 50)
    }

    @Test func searchFiltersInvalidIdRows() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"0","name":"Invalid","info_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":"100","seeders":"1","leechers":"1"},
                {"id":"1","name":"Valid","info_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":"100","seeders":"1","leechers":"1"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Movie", type: .movie)

        #expect(results.count == 1)
        #expect(results.first?.title == "Valid")
    }

    @Test func searchFiltersZeroHashRows() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"1","name":"Zero Hash","info_hash":"0000000000000000000000000000000000000000","size":"100","seeders":"1","leechers":"1"},
                {"id":"2","name":"Valid Hash","info_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":"100","seeders":"1","leechers":"1"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Movie", type: .movie)

        #expect(results.count == 1)
        #expect(results.first?.title == "Valid Hash")
    }

    @Test func searchFiltersEmptyInfoHashRows() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"1","name":"Empty Hash","info_hash":"","size":"100","seeders":"1","leechers":"1"},
                {"id":"2","name":"Valid Hash","info_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":"100","seeders":"1","leechers":"1"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Movie", type: .movie)

        #expect(results.count == 1)
        #expect(results.first?.title == "Valid Hash")
    }

    @Test func searchReturnsEmptyForEmptyJSONArray() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "unlikely", type: .movie)

        #expect(results.isEmpty)
    }

    @Test func searchThrowsBadServerResponseOnHTTPError() async {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = APIBayIndexer(session: session)
        await #expect(throws: URLError.self) {
            _ = try await indexer.searchByQuery(query: "Movie", type: .movie)
        }
    }

    @Test func searchThrowsOnMalformedJSONResponse() async {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{not-json}"#.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        await #expect(throws: DecodingError.self) {
            _ = try await indexer.searchByQuery(query: "Movie", type: .movie)
        }
    }

    @Test func searchByQueryWithEpisodeContextFiltersNonMatchingTorrents() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"id":"1","name":"Show S01E01 720p","info_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":"500","seeders":"5","leechers":"1"},
                {"id":"2","name":"Show S01E02 1080p","info_hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":"1000","seeders":"10","leechers":"2"},
                {"id":"3","name":"Show S01E03 720p","info_hash":"cccccccccccccccccccccccccccccccccccccccc","size":"500","seeders":"5","leechers":"1"}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        let results = try await indexer.searchByQuery(query: "Show S01E02", type: .series)

        #expect(results.count == 1)
        #expect(results.first?.infoHash == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        #expect(results.first?.title == "Show S01E02 1080p")
    }
}

// MARK: - EZTVIndexer

@Suite("EZTVIndexer")
struct EZTVIndexerTestsIndexertests {
    @Test func searchStripsTTFromIMDbID() async throws {
        final class State: @unchecked Sendable { var imdbId: String? }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.imdbId = components?.queryItems?.first(where: { $0.name == "imdb_id" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"torrents":[]}"#.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        _ = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)

        #expect(state.imdbId == "1234567")
    }

    @Test func searchReturnsEmptyForMovieTypeWithoutNetwork() async throws {
        let session = URLProtocolHarness.makeSession { _ in
            Issue.record("EZTV should not make network requests for movies")
            let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)

        #expect(results.isEmpty)
    }

    @Test func searchReturnsEmptyForEmptyIMDbID() async throws {
        let session = URLProtocolHarness.makeSession { _ in
            Issue.record("EZTV should not make network requests for empty IMDb ID")
            let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt", type: .series, season: nil, episode: nil)

        #expect(results.isEmpty)
    }

    @Test func searchConstructsCorrectPaginationParameters() async throws {
        final class State: @unchecked Sendable { var pages: [String] = [] }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let page = components?.queryItems?.first(where: { $0.name == "page" })?.value ?? "missing"
            state.pages.append(page)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"torrents":[{"hash":"hash1","title":"Show S01E01","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        _ = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)

        #expect(state.pages.first == "1")
    }

    @Test func searchByQueryPreservesOriginalSearchText() async throws {
        final class State: @unchecked Sendable { var search: String? }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.search = components?.queryItems?.first(where: { $0.name == "search" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"torrents":[]}"#.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        _ = try await indexer.searchByQuery(query: "Show S01E02", type: .series)

        #expect(state.search == "Show S01E02")
    }

    @Test func searchParsesValidJSONResponseWithOptionalFields() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"abc123","filename":"Show.S01E01.720p.mkv","title":"Show S01E01 720p","season":"1","episode":"1","seeds":22,"peers":3,"size_bytes":"12345","magnet_url":"magnet:?xt=urn:btih:abc123"},
                {"hash":"def456","filename":"Show.S01E02.1080p.mkv","title":null,"season":"1","episode":"2","seeds":15,"peers":2,"size_bytes":"67890","magnet_url":null}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)

        #expect(results.count == 2)
        #expect(results[0].infoHash == "abc123")
        #expect(results[0].title == "Show S01E01 720p")
        #expect(results[0].seeders == 22)
        #expect(results[0].leechers == 3)
        #expect(results[0].sizeBytes == 12_345)
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:abc123")
        #expect(results[1].infoHash == "def456")
        #expect(results[1].title == "Show.S01E02.1080p.mkv")
        #expect(results[1].magnetURI == nil)
    }

    @Test func searchFiltersBySeasonMetadataMismatch() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"s1","title":"Show S01E01","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"},
                {"hash":"s2","title":"Show S02E01","season":"2","episode":"1","seeds":1,"peers":0,"size_bytes":"100"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: 1, episode: nil)

        #expect(results.count == 1)
        #expect(results.first?.infoHash == "s1")
    }

    @Test func searchFiltersByEpisodeMetadataMismatch() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"e1","title":"Show S01E01","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"},
                {"hash":"e2","title":"Show S01E02","season":"1","episode":"2","seeds":1,"peers":0,"size_bytes":"100"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: 2)

        #expect(results.count == 1)
        #expect(results.first?.infoHash == "e2")
    }

    @Test func searchFiltersByTitleEpisodeTokensWhenBothSeasonAndEpisodeProvided() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"match","title":"Show S01E02 1080p","season":"1","episode":"2","seeds":1,"peers":0,"size_bytes":"100"},
                {"hash":"wrong","title":"Show S01E03 1080p","season":"1","episode":"3","seeds":1,"peers":0,"size_bytes":"100"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: 1, episode: 2)

        #expect(results.count == 1)
        #expect(results.first?.infoHash == "match")
    }

    @Test func searchSkipsEntriesWithNilHash() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":null,"title":"No Hash","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"},
                {"hash":"valid","title":"Valid","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results.first?.infoHash == "valid")
    }

    @Test func searchSkipsEntriesWithEmptyHash() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"","title":"Empty Hash","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"},
                {"hash":"valid","title":"Valid","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results.first?.infoHash == "valid")
    }

    @Test func searchHandlesMagnetURIPresenceAndAbsence() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"withmag","title":"With Magnet","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100","magnet_url":"magnet:?xt=urn:btih:withmag"},
                {"hash":"nomag","title":"No Magnet","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)

        #expect(results.count == 2)
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:withmag")
        #expect(results[1].magnetURI == nil)
    }

    @Test func searchPaginatesUpToMaxPages() async throws {
        final class State: @unchecked Sendable { var pages: [String] = [] }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let page = components?.queryItems?.first(where: { $0.name == "page" })?.value ?? "missing"
            state.pages.append(page)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            // Return exactly 100 torrents so pagination continues until maxPages
            var torrents: [String] = []
            for i in 1...100 {
                torrents.append(#"{"hash":"page\#(page)_\#(i)","title":"Show S01E01","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"}"#)
            }
            let body = #"{"torrents":[\#(torrents.joined(separator: ","))]}"#
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        _ = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)

        #expect(state.pages.count == 3)
        #expect(state.pages == ["1", "2", "3"])
    }

    @Test func searchStopsPaginationWhenTorrentsCountLessThanLimit() async throws {
        final class State: @unchecked Sendable { var pages: [String] = [] }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let page = components?.queryItems?.first(where: { $0.name == "page" })?.value ?? "missing"
            state.pages.append(page)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if page == "1" {
                let items = (0..<100).map { i in
                    #"{"hash":"p1-\#(i)","title":"Show S01E01","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"}"#
                }.joined(separator: ",")
                let body = #"{"torrents":["# + items + #"]}"#
                return (response, Data(body.utf8))
            }
            let body = #"{"torrents":[{"hash":"p2","title":"Show S01E01","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"}]}"#
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        _ = try await indexer.searchByQuery(query: "Show", type: .series)

        #expect(state.pages == ["1", "2"])
    }

    @Test func searchHandlesInvalidSizeBytesGracefully() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"badsize","title":"Bad Size","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"not-a-number"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)

        #expect(results.count == 1)
        #expect(results.first?.sizeBytes == 0)
    }

    @Test func searchThrowsBadServerResponseOnHTTPError() async {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = EZTVIndexer(session: session)
        await #expect(throws: URLError.self) {
            _ = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)
        }
    }

    @Test func searchThrowsOnMalformedJSONResponse() async {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{not-json}"#.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        await #expect(throws: DecodingError.self) {
            _ = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)
        }
    }
}

// MARK: - ZileanIndexer

@Suite("ZileanIndexer")
struct ZileanIndexerTestsIndexertests {
    @Test func searchConstructsCorrectURLWithCustomEndpointPath() async throws {
        final class State: @unchecked Sendable { var path: String? }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.path = url.path
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", endpointPath: "/custom", session: session)
        _ = try await indexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)

        #expect(state.path == "/custom/dmm/filtered")
    }

    @Test func searchRejectsHTTPBaseURL() async {
        let session = URLProtocolHarness.makeSession { request in
            Issue.record("Should not reach network for HTTP URL")
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "http://zilean.example", session: session)
        await #expect(throws: URLError.self) {
            _ = try await indexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)
        }
    }

    @Test func searchAddsSeasonAndEpisodeQueryParameters() async throws {
        final class State: @unchecked Sendable {
            var season: String?
            var episode: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.season = components?.queryItems?.first(where: { $0.name == "season" })?.value
            state.episode = components?.queryItems?.first(where: { $0.name == "episode" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        _ = try await indexer.search(imdbId: "tt1234567", type: .series, season: 2, episode: 4)

        #expect(state.season == "2")
        #expect(state.episode == "4")
    }

    @Test func searchParsesValidJSONResponseWithOptionalFields() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"info_hash":"abc123","raw_title":"Movie 1080p","size":1073741824},
                {"info_hash":"def456","raw_title":null,"size":null},
                {"info_hash":"","raw_title":"Empty Hash","size":100}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)

        // Empty hash is filtered out; null fields are preserved as defaults
        #expect(results.count == 2)
        #expect(results[0].infoHash == "abc123")
        #expect(results[0].title == "Movie 1080p")
        #expect(results[0].sizeBytes == 1_073_741_824)
        #expect(results[1].infoHash == "def456")
        #expect(results[1].title == "Unknown")
        #expect(results[1].sizeBytes == 0)
    }

    @Test func searchByQueryUsesSearchEndpoint() async throws {
        final class State: @unchecked Sendable { var path: String? }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.path = url.path
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        _ = try await indexer.searchByQuery(query: "Movie", type: .movie)

        #expect(state.path == "/api/dmm/search")
    }

    @Test func searchByQueryIncludesQueryParameter() async throws {
        final class State: @unchecked Sendable { var query: String? }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.query = components?.queryItems?.first(where: { $0.name == "query" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        _ = try await indexer.searchByQuery(query: "Show S01E02", type: .series)

        #expect(state.query == "Show S01E02")
    }

    @Test func searchByQueryRequiresEpisodeTokensWhenContextPresent() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"info_hash":"season-pack","raw_title":"Complete Season Pack","size":3000},
                {"info_hash":"episode-match","raw_title":"Show S01E02 1080p","size":2000},
                {"info_hash":"wrong-episode","raw_title":"Show S01E03 1080p","size":2000}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        let results = try await indexer.searchByQuery(query: "Show S01E02", type: .series)

        #expect(results.map(\.infoHash) == ["episode-match"])
    }

    @Test func searchAllowsUntokenizedTitlesForIMDbSearch() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            [
                {"info_hash":"season-pack","raw_title":"Complete Season Pack","size":3000},
                {"info_hash":"episode-match","raw_title":"Show S01E02 1080p","size":2000}
            ]
            """
            return (response, Data(body.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: 1, episode: 2)

        #expect(results.map(\.infoHash) == ["season-pack", "episode-match"])
    }

    @Test func searchThrowsBadServerResponseOnHTTPError() async {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        await #expect(throws: URLError.self) {
            _ = try await indexer.searchByQuery(query: "Movie", type: .movie)
        }
    }

    @Test func searchThrowsOnMalformedJSONResponse() async {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{not-json}"#.utf8))
        }

        let indexer = ZileanIndexer(baseURL: "https://zilean.example", session: session)
        await #expect(throws: DecodingError.self) {
            _ = try await indexer.searchByQuery(query: "Movie", type: .movie)
        }
    }
}

// MARK: - IndexerConnectivityTester Extended

@Suite("IndexerConnectivityTester Extended")
struct IndexerConnectivityTesterExtendedTests {
    @Test func testConnectionValidatesJSONArrayPayloadForAPIBay() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let config = IndexerConfig(
            id: "apibay-conn",
            name: "APIBay",
            indexerType: .apiBay,
            baseURL: nil,
            apiKey: nil,
            isActive: true,
            priority: 0
        )

        try await IndexerConnectivityTester.testConnection(for: config, session: session)
    }

    @Test func testConnectionValidatesJSONObjectPayloadForEZTV() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"torrents":[]}"#.utf8))
        }

        let config = IndexerConfig(
            id: "eztv-conn",
            name: "EZTV",
            indexerType: .eztv,
            baseURL: nil,
            apiKey: nil,
            isActive: true,
            priority: 0
        )

        try await IndexerConnectivityTester.testConnection(for: config, session: session)
    }

    @Test func testConnectionValidatesJSONArrayPayloadForZilean() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let config = IndexerConfig(
            id: "zilean-conn",
            name: "Zilean",
            indexerType: .zilean,
            baseURL: "https://zilean.example",
            apiKey: nil,
            isActive: true,
            priority: 0
        )

        try await IndexerConnectivityTester.testConnection(for: config, session: session)
    }

    @Test func makeRequestSetsTimeoutIntervalTo12Seconds() throws {
        let config = IndexerConfig(
            id: "apibay-timeout",
            name: "APIBay",
            indexerType: .apiBay,
            baseURL: nil,
            apiKey: nil,
            isActive: true,
            priority: 0
        )

        let request = try IndexerConnectivityTester.makeRequest(for: config)
        #expect(request.timeoutInterval == 12)
    }

    @Test func makeRequestUsesGETHTTPMethod() throws {
        let config = IndexerConfig(
            id: "eztv-method",
            name: "EZTV",
            indexerType: .eztv,
            baseURL: nil,
            apiKey: nil,
            isActive: true,
            priority: 0
        )

        let request = try IndexerConnectivityTester.makeRequest(for: config)
        #expect(request.httpMethod == "GET")
    }

    @Test func makeRequestIncludesAPIKeyInHeaderForHeaderTransport() throws {
        let config = IndexerConfig(
            id: "torznab-header",
            name: "Torznab",
            indexerType: .torznab,
            baseURL: "https://indexer.example",
            apiKey: "secret-key",
            isActive: true,
            priority: 0,
            apiKeyTransport: .header
        )

        let request = try IndexerConnectivityTester.makeRequest(for: config)
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == "secret-key")
    }

    @Test func makeRequestIncludesAPIKeyInQueryForQueryTransport() throws {
        let config = IndexerConfig(
            id: "jackett-query",
            name: "Jackett",
            indexerType: .jackett,
            baseURL: "https://jackett.example",
            apiKey: "query-key",
            isActive: true,
            priority: 0,
            apiKeyTransport: .query
        )

        let request = try IndexerConnectivityTester.makeRequest(for: config)
        let url = try #require(request.url)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryKey = components?.queryItems?.first(where: { $0.name == "apikey" })?.value
        #expect(queryKey == "query-key")
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == nil)
    }
}

// MARK: - IndexerRequestLimiter

@Suite("IndexerRequestLimiter", .serialized)
struct IndexerRequestLimiterTests {
    @Test func retriesOnRetryableStatusCodeAndSucceeds() async throws {
        final class State: @unchecked Sendable { var count = 0 }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            state.count += 1
            let url = try #require(request.url)
            let status = state.count < 3 ? 503 : 200
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"ok":true}"#.utf8))
        }

        let limiter = IndexerRequestLimiter(minimumRequestInterval: 0.001, maximumBackoffInterval: 0.001, maximumAttempts: 3)
        let request = URLRequest(url: URL(string: "https://indexer.example/api")!)
        let (_, response) = try await limiter.data(for: request, session: session)

        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(state.count == 3)
    }

    @Test func returnsRateLimitedAfterMaxAttemptsOn429() async {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let limiter = IndexerRequestLimiter(minimumRequestInterval: 0.001, maximumBackoffInterval: 0.001, maximumAttempts: 2)
        let request = URLRequest(url: URL(string: "https://indexer.example/api")!)

        await #expect(throws: IndexerRequestError.rateLimited) {
            _ = try await limiter.data(for: request, session: session)
        }
    }

    @Test func retriesOnTransportErrorAndSucceeds() async throws {
        final class State: @unchecked Sendable { var count = 0 }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            state.count += 1
            if state.count < 2 {
                throw URLError(.timedOut)
            }
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"ok":true}"#.utf8))
        }

        let limiter = IndexerRequestLimiter(minimumRequestInterval: 0.001, maximumBackoffInterval: 0.001, maximumAttempts: 2)
        let request = URLRequest(url: URL(string: "https://indexer.example/api")!)
        let (_, response) = try await limiter.data(for: request, session: session)

        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(state.count == 2)
    }

    @Test func throwsTransportErrorAfterExhaustingRetries() async {
        let session = URLProtocolHarness.makeSession { request in
            throw URLError(.cannotConnectToHost)
        }

        let limiter = IndexerRequestLimiter(minimumRequestInterval: 0.001, maximumBackoffInterval: 0.001, maximumAttempts: 2)
        let request = URLRequest(url: URL(string: "https://indexer.example/api")!)

        await #expect(throws: URLError.self) {
            _ = try await limiter.data(for: request, session: session)
        }
    }

    @Test func returnsImmediatelyOnNonRetryableStatusCode() async throws {
        final class State: @unchecked Sendable { var count = 0 }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            state.count += 1
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let limiter = IndexerRequestLimiter(minimumRequestInterval: 0.001, maximumBackoffInterval: 0.001, maximumAttempts: 3)
        let request = URLRequest(url: URL(string: "https://indexer.example/api")!)
        let (_, response) = try await limiter.data(for: request, session: session)

        #expect((response as? HTTPURLResponse)?.statusCode == 400)
        #expect(state.count == 1)
    }

    @Test func propagatesCancellationError() async {
        let session = URLProtocolHarness.makeSession { _ in
            throw CancellationError()
        }

        let limiter = IndexerRequestLimiter(minimumRequestInterval: 0.001, maximumBackoffInterval: 0.001, maximumAttempts: 3)
        let request = URLRequest(url: URL(string: "https://indexer.example/api")!)

        do {
            _ = try await limiter.data(for: request, session: session)
            Issue.record("Expected cancellation error to be thrown")
        } catch is CancellationError {
            // Swift CancellationError propagated correctly
        } catch let error as NSError where error.domain == "Swift.CancellationError" {
            // URLSession wraps the error in an NSError on some runtimes
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - TorrentIndexer Protocol

@Suite("TorrentIndexer Protocol")
struct TorrentIndexerProtocolTests {
    private struct MockIndexer: TorrentIndexer {
        let name = "MockIndexer"
        var results: [TorrentResult] = []

        func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
            results
        }

        func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
            results
        }
    }

    @Test func mockIndexerConformsToProtocol() async throws {
        let indexer: any TorrentIndexer = MockIndexer(results: [
            TorrentResult.fromSearch(infoHash: "abc123", title: "Test", sizeBytes: 1000, seeders: 5, leechers: 1, indexerName: "MockIndexer")
        ])

        #expect(indexer.name == "MockIndexer")

        let imdbResults = try await indexer.search(imdbId: "tt123", type: .movie, season: nil, episode: nil)
        #expect(imdbResults.count == 1)
        #expect(imdbResults.first?.infoHash == "abc123")

        let queryResults = try await indexer.searchByQuery(query: "Test", type: .movie)
        #expect(queryResults.count == 1)
        #expect(queryResults.first?.indexerName == "MockIndexer")
    }

    @Test func protocolConformanceIsSendable() {
        let indexer = MockIndexer()
        let _ = indexer as any TorrentIndexer
        let _ = indexer as Sendable
        #expect(Bool(true))
    }
}

// MARK: - Edge Cases

@Suite("Indexer Edge Cases")
struct IndexerEdgeCaseTests {
    @Test func apiBaySearchHandlesPercentEncodingInQuery() async throws {
        final class State: @unchecked Sendable { var query: String? }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            state.query = components?.queryItems?.first(where: { $0.name == "q" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let indexer = APIBayIndexer(session: session)
        _ = try await indexer.searchByQuery(query: "Show & Movie", type: .movie)

        #expect(state.query == "Show & Movie")
    }

    @Test func eztvPositiveEpisodeComponentRejectsNonPositiveValues() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"zero","title":"Show S01E00","season":"1","episode":"0","seeds":1,"peers":0,"size_bytes":"100"},
                {"hash":"neg","title":"Show S01E-1","season":"1","episode":"-1","seeds":1,"peers":0,"size_bytes":"100"},
                {"hash":"blank","title":"Show Special","season":"1","episode":"","seeds":1,"peers":0,"size_bytes":"100"},
                {"hash":"valid","title":"Show S01E01","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: 1, episode: 1)

        #expect(results.count == 1)
        #expect(results.first?.infoHash == "valid")
    }

    @Test func magnetLinkVsTorrentFileURLHandling() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"torrents":[
                {"hash":"magnet-only","title":"Magnet Only","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100","magnet_url":"magnet:?xt=urn:btih:magnet-only&dn=Magnet+Only"},
                {"hash":"no-magnet","title":"No Magnet","season":"1","episode":"1","seeds":1,"peers":0,"size_bytes":"100"}
            ]}
            """
            return (response, Data(body.utf8))
        }

        let indexer = EZTVIndexer(session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)

        #expect(results.count == 2)
        #expect(results[0].magnetURI == "magnet:?xt=urn:btih:magnet-only&dn=Magnet+Only")
        #expect(results[1].magnetURI == nil)
    }

    @Test func emptySearchResultsReturnEmptyArrayForAllIndexers() async throws {
        let emptySession = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"[]"#.utf8))
        }

        let apiBay = APIBayIndexer(session: emptySession)
        let zilean = ZileanIndexer(baseURL: "https://zilean.example", session: emptySession)

        let apiBayResults = try await apiBay.searchByQuery(query: "unlikely", type: .movie)
        let zileanResults = try await zilean.searchByQuery(query: "unlikely", type: .movie)

        #expect(apiBayResults.isEmpty)
        #expect(zileanResults.isEmpty)
    }

    @Test func httpErrorCodeMappingForAllIndexers() async {
        let errorSession = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let apiBay = APIBayIndexer(session: errorSession)
        let eztv = EZTVIndexer(session: errorSession)
        let zilean = ZileanIndexer(baseURL: "https://zilean.example", session: errorSession)

        await #expect(throws: URLError.self) {
            _ = try await apiBay.searchByQuery(query: "Movie", type: .movie)
        }
        await #expect(throws: URLError.self) {
            _ = try await eztv.searchByQuery(query: "Show", type: .series)
        }
        await #expect(throws: URLError.self) {
            _ = try await zilean.searchByQuery(query: "Movie", type: .movie)
        }
    }
}
