import Foundation
import Testing
@testable import VPStudio

@Suite("Indexer Parser Fallback Coverage")
struct IndexerParserFallbackCoverageTests {
    @Test func ytsMapsTitleFallbacksAndSkipsEmptyHashes() async throws {
        final class RequestState: @unchecked Sendable {
            var requestCount = 0
        }
        let state = RequestState()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.requestCount += 1
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let payload = """
            {
              "data": {
                "movies": [
                  {
                    "title": "Plain Title",
                    "torrents": [
                      {"hash": "", "quality": "1080p", "type": "bluray", "size_bytes": 123, "seeds": 9, "peers": 1},
                      {"hash": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "quality": null, "type": null}
                    ]
                  },
                  {
                    "torrents": [
                      {"hash": "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB", "quality": "2160p", "type": "web", "size_bytes": 42, "seeds": 7, "peers": 2}
                    ]
                  }
                ]
              }
            }
            """
            return (response, Data(payload.utf8))
        }

        let indexer = YTSIndexer(baseURLs: ["https://yts.example/api/v2"], session: session)
        let results = try await indexer.searchByQuery(query: "Plain Plain Title", type: .movie)

        #expect(state.requestCount == 1)
        #expect(results.map(\.infoHash) == [
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        ])
        #expect(results[0].title == "Plain Title")
        #expect(results[0].sizeBytes == 0)
        #expect(results[0].seeders == 0)
        #expect(results[1].title == "Unknown [2160p] [web]")
        #expect(results[1].sizeBytes == 42)
        #expect(results[1].seeders == 7)
        #expect(results[1].leechers == 2)
    }

    @Test func apiBayPropagatesMalformedJSONDecoderFailure() async {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("not-json".utf8))
        }

        let indexer = APIBayIndexer(baseURL: "https://apibay.example", session: session)

        do {
            _ = try await indexer.searchByQuery(query: "Movie", type: .movie)
            Issue.record("Expected JSON decoding to fail for malformed APIBay payload")
        } catch is DecodingError {
            #expect(true)
        } catch {
            Issue.record("Expected DecodingError, got \(error)")
        }
    }

    @Test func eztvSearchByQueryStopsAfterMaximumThreeFullPages() async throws {
        final class RequestState: @unchecked Sendable {
            var requestedPages: [String] = []
        }
        let state = RequestState()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "page" })?
                .value ?? "missing"
            state.requestedPages.append(page)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let torrents = (0..<100).map { index in
                """
                {"hash":"page-\(page)-\(index)","title":"Show S01E01 Part \(index)","season":"1","episode":"1","seeds":\(index),"peers":1,"size_bytes":"\(index + 1)"}
                """
            }
            .joined(separator: ",")
            return (response, Data("{\"torrents\":[\(torrents)]}".utf8))
        }

        let indexer = EZTVIndexer(baseURL: "https://eztv.example/api", session: session)
        let results = try await indexer.searchByQuery(query: "Show", type: .series)

        #expect(state.requestedPages == ["1", "2", "3"])
        #expect(results.count == 300)
        #expect(results.first?.infoHash == "page-1-0")
        #expect(results.last?.infoHash == "page-3-99")
    }

    @Test func eztvSearchByIMDbFallsBackToFilenameThenUnknownTitle() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let payload = """
            {
              "torrents": [
                {"hash":"filename-hash","filename":"Fallback.File.S01E02.mkv","season":"1","episode":"2","size_bytes":"bad"},
                {"hash":"unknown-hash","season":"1","episode":"3","seeds":5,"peers":2}
              ]
            }
            """
            return (response, Data(payload.utf8))
        }

        let indexer = EZTVIndexer(baseURL: "https://eztv.example/api", session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .series, season: nil, episode: nil)

        #expect(results.map(\.title) == ["Fallback.File.S01E02.mkv", "Unknown"])
        #expect(results[0].sizeBytes == 0)
        #expect(results[1].seeders == 5)
        #expect(results[1].leechers == 2)
    }
}
