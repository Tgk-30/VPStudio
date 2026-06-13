import Foundation
import Testing
@testable import VPStudio

@Suite("StremioIndexer Search Edge Cases")
struct StremioIndexerSearchEdgeCasesTests {

    @Test func searchByQuerySkipsStreamFetchWhenNoCatalogMetasMatchQuery() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"top","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/top/search=Matrix%202021.json":
                let body = #"{"metas":[{"id":"abc","name":"No Match","type":"movie"},{"id":"def","name":"Another Title","type":"movie"}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "Matrix 2021", type: .movie)

        #expect(results.isEmpty)
        #expect(requestLog.requestedPaths == [
            "/manifest.json",
            "/catalog/movie/top/search=Matrix%202021.json",
        ])
    }

    @Test func searchByQueryThrowsMalformedStreamErrorWhenNoStreamsCanBeCollected() async {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"top","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/top/search=Matrix.json":
                let body = #"{"metas":[{"id":"tt1111111","name":"Matrix","type":"movie"}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/backup/search=Matrix.json":
                let body = #"{"metas":[{"id":"tt2222222","name":"The Matrix","type":"movie"}]}"#
                return (response, Data(body.utf8))
            case "/stream/movie/tt1111111.json":
                return (response, Data("not valid json".utf8))
            case "/stream/movie/tt2222222.json":
                return (response, Data("{\"streams\":[]}".utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        do {
            _ = try await indexer.searchByQuery(query: "Matrix", type: .movie)
            Issue.record("Expected IndexerParseError.invalidPayload")
        } catch let error as IndexerParseError {
            if case .invalidPayload(_, let reason) = error {
                #expect(reason.localizedCaseInsensitiveContains("malformed JSON payload"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func searchByQueryEncodesReservedCharactersInCatalogSearchPath() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=My%20Show%3A%20The%2FReturn.json":
                let body = #"{"metas":[{"id":"tt3333333","name":"My Show: The/Return","type":"movie"}]}"#
                return (response, Data(body.utf8))
            case "/stream/movie/tt3333333.json":
                let body = #"{"streams":[{"title":"Direct","url":"https://cdn.example.com/stream.mkv","behaviorHints":{"videoSize":1}}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "My Show: The/Return", type: .movie)

        #expect(requestLog.requestedPaths == [
            "/manifest.json",
            "/catalog/movie/movies/search=My%20Show%3A%20The%2FReturn.json",
            "/stream/movie/tt3333333.json",
        ])
        #expect(results.count == 1)
        #expect(results[0].title == "Direct")
    }

    @Test func searchByQueryDeduplicatesDuplicateMetaIDsBeforeStreamFetch() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=Dune%202024.json":
                let body = #"{"metas":[{"id":"dune","name":"Dune","type":"movie"},{"id":"dune","name":"Dune 2021","type":"movie"}]}"#
                return (response, Data(body.utf8))
            case "/stream/movie/dune.json":
                let body = #"{"streams":[{"title":"Dune Source","infoHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(requestLog.requestedPaths == [
            "/manifest.json",
            "/catalog/movie/movies/search=Dune.json",
            "/stream/movie/dune.json",
        ])
        #expect(results.count == 1)
    }

    @Test func searchByQueryContinuesWhenOneStreamFetchFails() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=Dune.json":
                return (response, Data(#"{"metas":[{"id":"bad-stream","name":"Dune A","type":"movie"}]}"#.utf8))
            case "/catalog/movie/backup/search=Dune.json":
                return (response, Data(#"{"metas":[{"id":"good-stream","name":"Dune B","type":"movie"}]}"#.utf8))
            case "/stream/movie/bad-stream.json":
                let failure = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (failure, Data())
            case "/stream/movie/good-stream.json":
                let body = #"{"streams":[{"title":"Recovered Source","url":"https://cdn.example.com/stream.mkv","behaviorHints":{"videoSize":1}}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: MediaType.movie)

        #expect(requestLog.requestedPaths.starts(with: ["/manifest.json"]))
        #expect(requestLog.requestedPaths.contains("/catalog/movie/movies/search=Dune.json"))
        #expect(requestLog.requestedPaths.contains("/catalog/movie/backup/search=Dune.json"))
        #expect(requestLog.requestedPaths.filter { $0 == "/stream/movie/bad-stream.json" }.count >= 1)
        #expect(requestLog.requestedPaths.filter { $0 == "/stream/movie/good-stream.json" }.count >= 1)
        #expect(results.count == 1)
        #expect(results[0].title == "Recovered Source")
    }

    @Test func searchByQuerySkipsMalformedStreamPayloadAndContinues() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=Dune.json":
                return (response, Data(#"{"metas":[{"id":"bad-stream","name":"Dune A","type":"movie"}]}"#.utf8))
            case "/catalog/movie/backup/search=Dune.json":
                return (response, Data(#"{"metas":[{"id":"good-stream","name":"Dune B","type":"movie"}]}"#.utf8))
            case "/stream/movie/bad-stream.json":
                return (response, Data("not valid json".utf8))
            case "/stream/movie/good-stream.json":
                let body = #"{"streams":[{"title":"Recovered Source","url":"https://cdn.example.com/stream.mkv","behaviorHints":{"videoSize":1}}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(requestLog.requestedPaths.starts(with: ["/manifest.json"]))
        #expect(requestLog.requestedPaths.contains("/catalog/movie/movies/search=Dune.json"))
        #expect(requestLog.requestedPaths.contains("/catalog/movie/backup/search=Dune.json"))
        #expect(requestLog.requestedPaths.contains("/stream/movie/bad-stream.json"))
        #expect(requestLog.requestedPaths.contains("/stream/movie/good-stream.json"))
        #expect(results.count == 1)
        #expect(results[0].title == "Recovered Source")
    }

    @Test func searchByQueryAppendsEpisodeTokenWhenIMDbQueryContainsEpisodeContext() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            requestLog.requestedPaths.append(request.url?.path ?? "")
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch request.url?.path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"series","type":"series","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/stream/series/tt1122334:1:5.json":
                let body = #"{"streams":[{"title":"Pilot","url":"https://cdn.example.com/stream.mkv","infoHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "tt1122334 S01E05", type: .series)

        #expect(requestLog.requestedPaths == [
            "/stream/series/tt1122334:1:5.json",
        ])
        #expect(results.count == 1)
        #expect(results[0].title == "Pilot S01E05")
    }

    @Test func searchByQueryWithIMDbIDAndMovieTypeDoesNotAppendEpisodeToken() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            requestLog.requestedPaths.append(request.url?.path ?? "")
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch request.url?.path {
            case "/stream/movie/tt1122334.json":
                let body = #"{"streams":[{"title":"Pilot","url":"https://cdn.example.com/stream.mkv","infoHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "tt1122334 S01E05", type: .movie)

        #expect(requestLog.requestedPaths == ["/stream/movie/tt1122334.json"])
        #expect(results.count == 1)
        #expect(results[0].title == "Pilot")
    }

    @Test func searchByQueryThrowsWhenAllStreamFetchesFail() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)

            if path == "/manifest.json" {
                let manifestResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (manifestResponse, Data(body.utf8))
            }

            if path == "/catalog/movie/movies/search=Dune.json" {
                let catalogResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"metas":[{"id":"stream-1","name":"Dune A","type":"movie"}]}"#
                return (catalogResponse, Data(body.utf8))
            }

            if path == "/catalog/movie/backup/search=Dune.json" {
                let catalogResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"metas":[{"id":"stream-2","name":"Dune B","type":"movie"}]}"#
                return (catalogResponse, Data(body.utf8))
            }

            if path == "/stream/movie/stream-1.json" {
                let streamResponse = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (streamResponse, Data())
            }

            if path == "/stream/movie/stream-2.json" {
                let streamResponse = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (streamResponse, Data())
            }

            throw URLError(.unsupportedURL)
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)

        do {
            _ = try await indexer.searchByQuery(query: "Dune", type: .movie)
            Issue.record("Expected an error when all streams fail")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
            #expect(requestLog.requestedPaths.starts(with: ["/manifest.json"]))
            #expect(requestLog.requestedPaths.contains("/catalog/movie/movies/search=Dune.json"))
            #expect(requestLog.requestedPaths.contains("/catalog/movie/backup/search=Dune.json"))
            #expect(requestLog.requestedPaths.filter { $0 == "/stream/movie/stream-1.json" }.count >= 1)
            #expect(requestLog.requestedPaths.filter { $0 == "/stream/movie/stream-2.json" }.count >= 1)
        } catch {
            Issue.record("Expected URLError.badServerResponse, got \(error)")
        }
    }

    @Test func searchByQueryIncludesCatalogMetasWithNilType() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=Dune.json":
                let body = #"{"metas":[{"id":"typed","name":"Dune","type":"series"},{"id":"nullable","name":"Dune"}]}"#
                return (response, Data(body.utf8))
            case "/stream/movie/nullable.json":
                let body = #"{"streams":[{"title":"Nullable Type Source","url":"https://cdn.example.com/stream.mkv"}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(requestLog.requestedPaths == [
            "/manifest.json",
            "/catalog/movie/movies/search=Dune.json",
            "/stream/movie/nullable.json",
        ])
        #expect(results.count == 1)
        #expect(results[0].title == "Nullable Type Source")
    }

    @Test func searchByQueryContinuesWhenSomeCatalogSearchRequestsFail() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=Dune.json":
                return (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            case "/catalog/movie/backup/search=Dune.json":
                let body = #"{"metas":[{"id":"good-stream","name":"Dune","type":"movie"}]}"#
                return (response, Data(body.utf8))
            case "/stream/movie/good-stream.json":
                let body = #"{"streams":[{"title":"Recovered Source","url":"https://cdn.example.com/stream.mkv"}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(requestLog.requestedPaths.starts(with: ["/manifest.json"]))
        #expect(requestLog.requestedPaths.contains("/catalog/movie/movies/search=Dune.json"))
        #expect(requestLog.requestedPaths.contains("/catalog/movie/backup/search=Dune.json"))
        #expect(requestLog.requestedPaths.contains("/stream/movie/good-stream.json"))
        #expect(requestLog.requestedPaths.filter { $0 == "/catalog/movie/movies/search=Dune.json" }.count >= 1)
        #expect(requestLog.requestedPaths.last == "/stream/movie/good-stream.json")
        #expect(results.count == 1)
        #expect(results[0].title == "Recovered Source")
    }

    @Test func searchByQueryThrowsWhenAllCatalogSearchesFail() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)

            if path == "/manifest.json" {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            }

            return (
                HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)

        do {
            _ = try await indexer.searchByQuery(query: "Dune", type: .movie)
            Issue.record("Expected searchByQuery to throw")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
            #expect(requestLog.requestedPaths.starts(with: ["/manifest.json"]))
            #expect(requestLog.requestedPaths.contains("/catalog/movie/movies/search=Dune.json"))
            #expect(requestLog.requestedPaths.contains("/catalog/movie/backup/search=Dune.json"))
        } catch {
            Issue.record("Expected URLError.badServerResponse, got \(error)")
        }
    }

    @Test func searchByQueryThrowsWhenAllStreamFetchesAreMalformed() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=Dune.json":
                return (response, Data(#"{"metas":[{"id":"first","name":"Dune","type":"movie"}]}"#.utf8))
            case "/catalog/movie/backup/search=Dune.json":
                return (response, Data(#"{"metas":[{"id":"second","name":"Dune","type":"movie"}]}"#.utf8))
            case "/stream/movie/first.json":
                return (response, Data("malformed".utf8))
            case "/stream/movie/second.json":
                return (response, Data("malformed".utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        do {
            _ = try await indexer.searchByQuery(query: "Dune", type: .movie)
            Issue.record("Expected IndexerParseError.invalidPayload")
        } catch let error as IndexerParseError {
            if case .invalidPayload(_, let reason) = error {
                #expect(reason.localizedCaseInsensitiveContains("malformed JSON payload"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected IndexerParseError.invalidPayload, got \(error)")
        }
    }

    @Test func searchByQueryThrowsOnNon2xxManifestResponse() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)

        await #expect(throws: URLError(.badServerResponse)) {
            _ = try await indexer.searchByQuery(query: "Dune", type: .movie)
        }
    }

    @Test func payloadBuildsMagnetFromTrackersAndDeduplicatesCaseInsensitiveSources() async throws {
        let hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let payload = """
            {
              "streams":[
                {
                  "title":"Case Test",
                  "infoHash":"\(hash)",
                  "sources":[
                    "TRACKER:udp://tracker.example.com:1337/announce",
                    "tracker:udp://tracker.example.com:1337/announce",
                    "https://cdn.example.com/stream.mkv",
                    "tracker:https://tracker.example.net:8080/announce",
                    "invalid:abc"
                  ],
                  "behaviorHints":{"videoSize":1}
                }
              ]
            }
            """
            return (response, Data(payload.utf8))
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)
        let magnet = try #require(results.first?.magnetURI)
        let components = try #require(URLComponents(string: magnet))
        let trackers = components.queryItems?
            .filter { $0.name == "tr" }
            .compactMap(\.value) ?? []
        let queryItems = components.queryItems ?? []

        #expect(results.count == 1)
        #expect(results[0].infoHash == hash)
        #expect(queryItems.first { $0.name == "xt" }?.value == "urn:btih:\(hash)")
        #expect(trackers == [
            "udp://tracker.example.com:1337/announce",
            "https://tracker.example.net:8080/announce"
        ])
    }

    @Test func payloadFiltersOutTrackersThatPointToVideoFilesOrLackTrackers() async throws {
        let hash = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let payload = """
            {
              "streams":[
                {
                  "title":"Filtered Trackers",
                  "infoHash":"\(hash)",
                  "sources":[
                    "tracker:https://tracker.example.com/path/announce",
                    "tracker:https://tracker.example.com/path/file.mp4",
                    "tracker:https://tracker.example.com/path/file.MKV",
                    "tracker:https://cdn.example.com/movie.mkv",
                    "http://tracker.example.net:6969/announce",
                    "tracker:"
                  ],
                  "behaviorHints":{"videoSize":1}
                }
              ]
            }
            """
            return (response, Data(payload.utf8))
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)
        let magnet = try #require(results.first?.magnetURI)
        let components = try #require(URLComponents(string: magnet))
        let trackers = components.queryItems?
            .filter { $0.name == "tr" }
            .compactMap(\.value) ?? []

        #expect(results.count == 1)
        #expect(trackers == [
            "https://tracker.example.com/path/announce",
            "http://tracker.example.net:6969/announce"
        ])
    }

    @Test func searchByQueryDoesNotAnnotateAlreadySeasonedResults() async throws {
        final class RequestLog: @unchecked Sendable { var requestedPaths: [String] = [] }
        let requestLog = RequestLog()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            requestLog.requestedPaths.append(request.url?.path ?? "")
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch request.url?.path {
            case "/stream/series/tt1122334:1:5.json":
                let body = #"{"streams":[{"title":"Pilot S01E05","url":"https://cdn.example.com/stream.mkv","infoHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "tt1122334 S01E05", type: .series)

        #expect(requestLog.requestedPaths == ["/stream/series/tt1122334:1:5.json"])
        #expect(results.count == 1)
        #expect(results[0].title == "Pilot S01E05")
    }

    @Test func payloadDropsBlankTrackerSourcesWhenGeneratingMagnet() async throws {
        let hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let payload = """
            {
              "streams":[
                {
                  "title":"Blank Tracker",
                  "infoHash":"\(hash)",
                  "sources":[
                    "tracker:",
                    "tracker:   ",
                    "   ",
                    "invalid"
                  ],
                  "behaviorHints":{"videoSize":1}
                }
              ]
            }
            """
            return (response, Data(payload.utf8))
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)
        let magnet = try #require(results.first?.magnetURI)
        let components = try #require(URLComponents(string: magnet))
        let trackers = components.queryItems?
            .filter { $0.name == "tr" }
            .compactMap(\.value) ?? []

        #expect(results.count == 1)
        #expect(trackers.isEmpty)
    }

    @Test func payloadTrimsTrackerSourcesBeforeMagnetEncoding() async throws {
        let hash = String(repeating: "a", count: 40)
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let payload = """
            {
              "streams":[
                {
                  "title":"Whitespace Trackers",
                  "infoHash":"\(hash)",
                  "sources":[
                    "   tracker:https://tracker.example.com/announce   ",
                    "tracker:   https://tracker.example.com/announce",
                    "   "
                  ],
                  "behaviorHints":{"videoSize":1}
                }
              ]
            }
            """
            return (response, Data(payload.utf8))
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.search(imdbId: "tt1234567", type: .movie, season: nil, episode: nil)
        let magnet = try #require(results.first?.magnetURI)
        let components = try #require(URLComponents(string: magnet))
        let trackers = components.queryItems?
            .filter { $0.name == "tr" }
            .compactMap(\.value) ?? []

        #expect(results.count == 1)
        #expect(results[0].infoHash == hash)
        #expect(trackers == ["https://tracker.example.com/announce"])
    }

    @Test func searchByQueryThrowsWhenCatalogsAllInvalid() async {
        final class RequestState: @unchecked Sendable {
            var paths: [String] = []
        }
        let state = RequestState()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            state.paths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"top","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/top/search=Nope.json":
                return (response, Data("bad json".utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        do {
            _ = try await indexer.searchByQuery(query: "Nope", type: .movie)
            Issue.record("Expected searchByQuery to throw")
        } catch let error as IndexerParseError {
            if case .invalidPayload(_, let reason) = error {
                #expect(reason.localizedCaseInsensitiveContains("malformed JSON"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(state.paths == [
            "/manifest.json",
            "/catalog/movie/top/search=Nope.json"
        ])
    }

    @Test func searchByQueryThrowsMalformedManifestAsInvalidPayload() async {
        final class RequestState: @unchecked Sendable {
            var paths: [String] = []
        }
        let state = RequestState()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            state.paths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            guard path == "/manifest.json" else {
                throw URLError(.unsupportedURL)
            }
            return (response, Data("bad manifest".utf8))
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        do {
            _ = try await indexer.searchByQuery(query: "Dune", type: .movie)
            Issue.record("Expected IndexerParseError.invalidPayload")
        } catch let error as IndexerParseError {
            if case .invalidPayload(_, let reason) = error {
                #expect(reason.localizedCaseInsensitiveContains("manifest payload malformed JSON payload"))
            } else {
                Issue.record("Expected invalidPayload, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(state.paths == ["/manifest.json"])
    }

    @Test func searchByQueryThrowsWhenManifestHasNoCatalogsField() async throws {
        final class RequestState: @unchecked Sendable {
            var paths: [String] = []
        }
        let state = RequestState()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            state.paths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            switch path {
            case "/manifest.json":
                return (response, Data(#"{"other":true}"#.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)
        #expect(results.isEmpty)
        #expect(state.paths == ["/manifest.json"])
    }

    @Test func searchByQueryContinuesWhenSomeCatalogsAreMalformed() async throws {
        final class RequestState: @unchecked Sendable {
            var paths: [String] = []
        }
        let state = RequestState()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            state.paths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]},{"id":"backup","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=Dune.json":
                return (response, Data("malformed payload".utf8))
            case "/catalog/movie/backup/search=Dune.json":
                return (response, Data(#"{"metas":[{"id":"working","name":"Dune","type":"movie"}]}"#.utf8))
            case "/stream/movie/working.json":
                return (response, Data(#"{"streams":[{"title":"Recovered","url":"https://cdn.example.com/stream.mkv"}]}"#.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(state.paths == [
            "/manifest.json",
            "/catalog/movie/movies/search=Dune.json",
            "/catalog/movie/backup/search=Dune.json",
            "/stream/movie/working.json",
        ])
        #expect(results.count == 1)
        #expect(results[0].title == "Recovered")
    }

    @Test func searchByQueryReturnsEmptyWhenAllCatalogMetasAreWrongType() async throws {
        final class RequestState: @unchecked Sendable {
            var paths: [String] = []
        }
        let state = RequestState()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            state.paths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=The%20Matrix.json":
                let body = #"{"metas":[{"id":"wrong","name":"The Matrix","type":"series"},{"id":"alsoWrong","name":"Matrix Return","type":"anime"}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "The Matrix", type: .movie)

        #expect(state.paths == [
            "/manifest.json",
            "/catalog/movie/movies/search=The%20Matrix.json",
        ])
        #expect(results.isEmpty)
    }

    @Test func searchByQueryReturnsEmptyWhenManifestHasNoSearchableCatalogsForType() async throws {
        final class RequestState: @unchecked Sendable {
            var paths: [String] = []
        }
        let state = RequestState()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            state.paths.append(path)

            if path == "/manifest.json" {
                let body = #"{"catalogs":[{"id":"series","type":"series","extra":[{"name":"search"}]}]}"#
                return (
                    HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(body.utf8)
                )
            }

            throw URLError(.unsupportedURL)
        }

        let indexer = StremioIndexer(
            name: "Stremio",
            baseURL: "https://addon.example",
            endpointPath: "/manifest.json",
            session: session
        )

        let results = try await indexer.searchByQuery(query: "Dune", type: .movie)

        #expect(results.isEmpty)
        #expect(state.paths == ["/manifest.json"])
    }

    @Test func stremioManifestBuilderDoesNotDuplicateManifestPath() throws {
        let manifestURL = try StremioAddonURLBuilder.manifestURL(
            baseURL: "https://addon.example/streams/manifest.json",
            endpointPath: "/manifest.json"
        )
        #expect(manifestURL.absoluteString == "https://addon.example/streams/manifest.json")
    }

    @Test func stremioManifestBuilderNormalizesEndpointPathWithoutLeadingSlash() throws {
        let manifestURL = try StremioAddonURLBuilder.manifestURL(
            baseURL: "https://addon.example/streams/",
            endpointPath: "manifest.json"
        )
        #expect(manifestURL.absoluteString == "https://addon.example/streams/manifest.json")
    }

    @Test func stremioManifestBuilderDefaultsEmptyEndpointPathToManifestJSON() throws {
        let manifestURL = try StremioAddonURLBuilder.manifestURL(
            baseURL: "https://addon.example/streams",
            endpointPath: ""
        )
        #expect(manifestURL.absoluteString == "https://addon.example/streams/manifest.json")
    }

    @Test func stremioManifestBuilderHandlesUppercaseManifestEndpointPath() throws {
        let manifestURL = try StremioAddonURLBuilder.manifestURL(
            baseURL: "https://addon.example/streams/MANIFEST.JSON",
            endpointPath: "/manifest.json"
        )
        #expect(manifestURL.absoluteString == "https://addon.example/streams/MANIFEST.JSON")
    }

    @Test func stremioManifestBuilderAvoidsDuplicateNestedEndpointPathCaseInsensitively() throws {
        let manifestURL = try StremioAddonURLBuilder.manifestURL(
            baseURL: "https://addon.example/addon/API/Manifest.JSON",
            endpointPath: "/api/manifest.json"
        )
        #expect(manifestURL.absoluteString == "https://addon.example/addon/API/Manifest.JSON")
    }

    @Test func stremioManifestBuilderRejectsPublicHTTPBaseURL() throws {
        #expect(throws: URLError(.unsupportedURL)) {
            _ = try StremioAddonURLBuilder.manifestURL(
                baseURL: "http://addon.example",
                endpointPath: "/manifest.json"
            )
        }
    }

    @Test func normalizedAddonURLStringLeavesStremioURLsWithoutHostsUntouched() {
        let normalized = StremioAddonURLBuilder.normalizedAddonURLString("  stremio:///manifest.json  ")

        #expect(normalized == "stremio:///manifest.json")
    }

    @Test func searchByQueryEncodesCatalogIDInCatalogPath() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()
        let catalogID = "regional/4k"

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"\#(catalogID)","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/regional%2F4k/search=The%20Matrix.json":
                let body = #"{"metas":[{"id":"tt1111111","name":"The Matrix","type":"movie"}]}"#
                return (response, Data(body.utf8))
            case "/stream/movie/tt1111111.json":
                let body = #"{"streams":[{"title":"Direct","url":"https://cdn.example.com/stream.mkv","behaviorHints":{"videoSize":1}}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "The Matrix", type: .movie)

        #expect(requestLog.requestedPaths == [
            "/manifest.json",
            "/catalog/movie/regional%2F4k/search=The%20Matrix.json",
            "/stream/movie/tt1111111.json",
        ])
        #expect(results.count == 1)
    }

    @Test func searchByQueryEncodesCatalogIDWithWhitespaceInCatalogPath() async throws {
        final class RequestLog: @unchecked Sendable {
            var requestedPaths: [String] = []
        }
        let requestLog = RequestLog()
            let catalogID = "regional 4k"

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            requestLog.requestedPaths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"\#(catalogID)","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/regional%204k/search=The%20Matrix.json":
                let body = #"{"metas":[{"id":"tt2222222","name":"The Matrix","type":"movie"}]}"#
                return (response, Data(body.utf8))
            case "/stream/movie/tt2222222.json":
                let body = #"{"streams":[{"title":"Direct","url":"https://cdn.example.com/stream.mkv","behaviorHints":{"videoSize":1}}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "The Matrix", type: .movie)

        #expect(requestLog.requestedPaths == [
            "/manifest.json",
            "/catalog/movie/regional%204k/search=The%20Matrix.json",
            "/stream/movie/tt2222222.json",
        ])
        #expect(results.count == 1)
    }

    @Test func searchByQueryReturnsEmptyWhenNormalizedQueryIsEmpty() async throws {
        final class RequestState: @unchecked Sendable {
            var paths: [String] = []
        }
        let state = RequestState()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            state.paths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=2024.json":
                let body = #"{"metas":[{"id":"tt1111111","name":"A Film 2024","type":"movie"}]}"#
                return (response, Data(body.utf8))
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "2024", type: .movie)

        #expect(results.isEmpty)
        #expect(state.paths == [
            "/manifest.json",
            "/catalog/movie/movies/search=2024.json"
        ])
    }

    @Test func searchByQueryLimitsStreamFetchesToTopThreeCatalogMatches() async throws {
        final class RequestState: @unchecked Sendable {
            var paths: [String] = []
        }
        let state = RequestState()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
            state.paths.append(path)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch path {
            case "/manifest.json":
                let body = #"{"catalogs":[{"id":"movies","type":"movie","extra":[{"name":"search"}]}]}"#
                return (response, Data(body.utf8))
            case "/catalog/movie/movies/search=Dune.json":
                let body = """
                {
                  "metas":[
                    {"id":"tt-exact-match","name":"Dune","type":"movie","releaseInfo":"2024"},
                    {"id":"tt-prefix-match","name":"Dune 2","type":"movie"},
                    {"id":"tt-contains-match","name":"The Dune","type":"movie","releaseInfo":"2024"},
                    {"id":"tt-no-match","name":"Not Matching","type":"movie","releaseInfo":"2024"}
                  ]
                }
                """
                return (response, Data(body.utf8))
            case "/stream/movie/tt-exact-match.json":
                let body = #"{"streams":[{"title":"Exact","url":"https://cdn.example.com/stream.mkv","behaviorHints":{"videoSize":1}}]}"#
                return (response, Data(body.utf8))
            case "/stream/movie/tt-prefix-match.json":
                let body = #"{"streams":[{"title":"Prefix","url":"https://cdn.example.com/stream.mkv","behaviorHints":{"videoSize":1}}]}"#
                return (response, Data(body.utf8))
            case "/stream/movie/tt-contains-match.json":
                let body = #"{"streams":[{"title":"Contains","url":"https://cdn.example.com/stream.mkv","behaviorHints":{"videoSize":1}}]}"#
                return (response, Data(body.utf8))
            default:
                return (response, Data(#"{"streams":[]}"#.utf8))
            }
        }

        let indexer = StremioIndexer(name: "Stremio", baseURL: "https://addon.example", endpointPath: "/manifest.json", session: session)
        let results = try await indexer.searchByQuery(query: "Dune 2024", type: .movie)
        let streamRequests = state.paths.filter { $0.hasPrefix("/stream/movie/") }

        #expect(results.count == 3)
        #expect(Set(results.map(\.title)) == Set(["Exact", "Prefix", "Contains"]))
        #expect(streamRequests.count == 3)
        #expect(streamRequests.contains("/stream/movie/tt-exact-match.json"))
        #expect(streamRequests.contains("/stream/movie/tt-prefix-match.json"))
        #expect(streamRequests.contains("/stream/movie/tt-contains-match.json"))
        #expect(!streamRequests.contains("/stream/movie/tt-no-match.json"))
    }
}
