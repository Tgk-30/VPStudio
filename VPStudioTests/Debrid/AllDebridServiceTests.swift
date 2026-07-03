import Foundation
import Testing
@testable import VPStudio

@Suite("AllDebridService")
struct AllDebridServiceTests {
    @Test func validateTokenReturnsTrueForValidToken() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"status\":\"success\",\"data\":{\"user\":{\"username\":\"testuser\",\"email\":\"test@example.com\",\"isPremium\":true}}}"
            return (response, Data(body.utf8))
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let isValid = try await service.validateToken()
        #expect(isValid == true)
    }

    @Test func getAccountInfoReturnsExpectedStructure() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"status\":\"success\",\"data\":{\"user\":{\"username\":\"alldebrid_user\",\"email\":\"user@alldebrid.com\",\"isPremium\":true}}}"
            return (response, Data(body.utf8))
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let accountInfo = try await service.getAccountInfo()
        #expect(accountInfo.username == "alldebrid_user")
        #expect(accountInfo.email == "user@alldebrid.com")
        #expect(accountInfo.isPremium == true)
    }

    @Test func checkCacheReturnsCorrectStatusForCachedHashes() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                \"status\":\"success\",
                \"data\":{
                    \"magnets\":[
                        {\"hash\":\"abc123\",\"instant\":true},
                        {\"hash\":\"def456\",\"instant\":false}
                    ]
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let hashes = ["ABC123", "def456", "ghi789"]
        let cacheStatus = try await service.checkCache(hashes: hashes)

        #expect(cacheStatus["abc123"] == .cached(fileId: nil, fileName: nil, fileSize: nil))
        #expect(cacheStatus["def456"] == .notCached)
        #expect(cacheStatus["ghi789"] == .notCached)
    }

    @Test func checkCacheReturnsEmptyForEmptyInput() async throws {
        let session = URLProtocolHarness.makeSession { request in
            Issue.record("Unexpected request for empty hashes")
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let cacheStatus = try await service.checkCache(hashes: [])
        #expect(cacheStatus.isEmpty)
    }

    @Test func checkCacheSkipsProviderEntriesWithoutHashes() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "status": "success",
                "data": {
                    "magnets": [
                        {"instant": true},
                        {"hash": "", "instant": true},
                        {"hash": "ABC123", "instant": true}
                    ]
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let cacheStatus = try await service.checkCache(hashes: ["abc123", "missing"])

        #expect(cacheStatus["abc123"] == .cached(fileId: nil, fileName: nil, fileSize: nil))
        #expect(cacheStatus["missing"] == .notCached)
        #expect(cacheStatus.keys.count == 2)
    }

    @Test func addMagnetConstructsCorrectRequest() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let bodyResponse = "{\"status\":\"success\",\"data\":{\"magnets\":[{\"id\":123}]}}"
            return (response, Data(bodyResponse.utf8))
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let hash40 = "ABC123DEF456abc123def456abc123def456abcd"
        let requestId = try await service.addMagnet(hash: hash40)

        #expect(requestId == "123")
    }

    @Test func getStreamURLUsesSelectedLinkFilenameAndSize() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/magnet/status") {
                let body = """
                {
                    "status": "success",
                    "data": {
                        "id": 123,
                        "filename": "Show.Season.Pack",
                        "size": 9999,
                        "statusCode": 4,
                        "links": [
                            {"link": "https://alldebrid.example/restricted-s01e01", "filename": "Show.S01E01.720p.WEB-DL.mkv", "size": 100},
                            {"link": "https://alldebrid.example/restricted-s01e02", "filename": "Show.S01E02.2160p.HDR10.WEB-DL.mkv", "size": 2222}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/link/unlock") {
                let body = #"{"status":"success","data":{"link":"https://cdn.example.com/show-s01e02.mkv"}}"#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data(#"{"status":"success","data":{}}"#.utf8))
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        try await service.selectFiles(torrentId: "123", fileIds: [2])
        let stream = try await service.getStreamURL(torrentId: "123")

        #expect(stream.streamURL.absoluteString == "https://cdn.example.com/show-s01e02.mkv")
        #expect(stream.fileName == "Show.S01E02.2160p.HDR10.WEB-DL.mkv")
        #expect(stream.sizeBytes == 2222)
        #expect(stream.quality == .uhd4k)
        #expect(stream.hdr == .hdr10)
    }

    @Test func requestURLConstructionIncludesAuthHeader() async throws {
        final class State: @unchecked Sendable {
            var authHeader: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.authHeader = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"status\":\"success\",\"data\":{\"user\":{\"username\":\"testuser\"}}}"
            return (response, Data(body.utf8))
        }

        let service = AllDebridService(apiToken: "test_token", session: session)
        _ = try await service.validateToken()

        #expect(state.authHeader == "Bearer test_token")
    }

    @Test func selectMatchingEpisodeFileReturnsFalseWhenLinksAreMissing() async throws {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.requestCount += 1
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"status":"success","data":{"id":1,"filename":"Show.S01.Pack","statusCode":4}}"#
            return (response, Data(body.utf8))
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)

        let withoutHints = try await service.selectMatchingEpisodeFile(
            torrentId: "1",
            seasonNumber: 1,
            episodeNumber: 1
        )
        let withHints = try await service.selectMatchingEpisodeFile(
            torrentId: "1",
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "Show.S01E01.mkv",
            resolvedFileSizeHint: 1000
        )

        #expect(withoutHints == false)
        #expect(withHints == false)
        #expect(state.requestCount == 2)
    }

    @Test func requestHandlesNetworkErrors() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.self) {
            _ = try await service.validateToken()
        }
    }

    @Test func selectMatchingEpisodeFileUsesExactMatchBySizeHint() async throws {
        final class State: @unchecked Sendable {
            var unlockedFor: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/magnet/status") {
                let body = """
                {
                    "status": "success",
                    "data": {
                        "id": 1,
                        "filename": "S01E01.Pack",
                        "size": 3000,
                        "statusCode": 4,
                        "links": [
                            {"link": "https://alldebrid.example/restricted-low", "filename": "Show.S01E01.720p.mkv", "size": 1000},
                            {"link": "https://alldebrid.example/restricted-high", "filename": "Show.S01E01.720p.mkv", "size": 2000}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/link/unlock") {
                let link = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "link" })?
                    .value
                state.unlockedFor = link
                let body = #"{"status":"success","data":{"link":"https://cdn.example/show-s01e01.mp4"}}"#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let selected = try await service.selectMatchingEpisodeFile(
            torrentId: "1",
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "Show.S01E01.720p.mkv",
            resolvedFileSizeHint: 2000
        )

        #expect(selected == true)
        _ = try await service.getStreamURL(torrentId: "1")
        #expect(state.unlockedFor?.contains("restricted-high") == true)
    }

    @Test func selectMatchingEpisodeFileFallsBackToLargestExactMatchWhenSizeHintDoesNotMatch() async throws {
        final class State: @unchecked Sendable {
            var unlockedFor: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/magnet/status") {
                let body = """
                {
                    "status": "success",
                    "data": {
                        "id": 1,
                        "filename": "S01E01.Pack",
                        "size": 3000,
                        "statusCode": 4,
                        "links": [
                            {"link": "https://alldebrid.example/restricted-small", "filename": "Show.S01E01.720p.mkv", "size": 1000},
                            {"link": "https://alldebrid.example/restricted-large", "filename": "Show.S01E01.720p.mkv", "size": 2000}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/link/unlock") {
                let link = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "link" })?
                    .value
                state.unlockedFor = link
                let body = #"{"status":"success","data":{"link":"https://cdn.example/show-s01e01.mp4"}}"#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let selected = try await service.selectMatchingEpisodeFile(
            torrentId: "1",
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "Show.S01E01.720p.mkv",
            resolvedFileSizeHint: 1234
        )

        #expect(selected == true)
        _ = try await service.getStreamURL(torrentId: "1")
        #expect(state.unlockedFor?.contains("restricted-large") == true)
    }

    @Test func selectMatchingEpisodeFileReturnsFalseWhenNoMatchAndMultipleLinks() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "status": "success",
                "data": {
                    "id": 1,
                    "filename": "S01E99.Pack",
                    "size": 3000,
                    "statusCode": 4,
                    "links": [
                        {"link": "https://alldebrid.example/unrelated-one", "filename": "Movie Trailer", "size": 1000},
                        {"link": "https://alldebrid.example/unrelated-two", "filename": "Another Clip", "size": 2000}
                    ]
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let selected = try await service.selectMatchingEpisodeFile(
            torrentId: "1",
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "Show.S01E01.mkv",
            resolvedFileSizeHint: 1500
        )

        #expect(selected == false)
    }

    @Test func selectMatchingEpisodeFileIgnoresBlankResolvedNameHint() async throws {
        final class State: @unchecked Sendable {
            var unlockedFor: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/magnet/status") {
                let body = """
                {
                    "status": "success",
                    "data": {
                        "id": 1,
                        "filename": "Show.S01.Pack",
                        "size": 3000,
                        "statusCode": 4,
                        "links": [
                            {"link": "https://alldebrid.example/small", "filename": "Show.S01E04.720p.mkv", "size": 1000},
                            {"link": "https://alldebrid.example/large", "filename": "Show.S01E04.1080p.mkv", "size": 2000}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/link/unlock") {
                let link = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "link" })?
                    .value
                state.unlockedFor = link
                let body = #"{"status":"success","data":{"link":"https://cdn.example/show-s01e04.mp4"}}"#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let selected = try await service.selectMatchingEpisodeFile(
            torrentId: "1",
            seasonNumber: 1,
            episodeNumber: 4,
            resolvedFileNameHint: "   ",
            resolvedFileSizeHint: 1000
        )

        #expect(selected == true)
        _ = try await service.getStreamURL(torrentId: "1")
        #expect(state.unlockedFor?.contains("large") == true)
    }

    @Test func selectMatchingEpisodeFileFallsBackToOnlyLinkWhenNoEpisodeMatchExists() async throws {
        final class State: @unchecked Sendable {
            var unlockedFor: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/magnet/status") {
                let body = """
                {
                    "status": "success",
                    "data": {
                        "id": 1,
                        "filename": "Single.Link.Pack",
                        "size": 3000,
                        "statusCode": 4,
                        "links": [
                            {"link": "https://alldebrid.example/only-link", "filename": "Unrelated.Featurette.mkv", "size": 1000}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/link/unlock") {
                let link = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "link" })?
                    .value
                state.unlockedFor = link
                let body = #"{"status":"success","data":{"link":"https://cdn.example/only-link.mkv"}}"#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let selected = try await service.selectMatchingEpisodeFile(
            torrentId: "1",
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "Show.S01E01.mkv",
            resolvedFileSizeHint: nil
        )

        #expect(selected == true)
        _ = try await service.getStreamURL(torrentId: "1")
        #expect(state.unlockedFor?.contains("only-link") == true)
    }

    @Test func getStreamURLFallsBackToStatusMetadataWhenLinkMetadataIsMissing() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/magnet/status") {
                let body = """
                {
                    "status": "success",
                    "data": {
                        "id": 1,
                        "filename": "Status.Movie.1080p.BluRay.mkv",
                        "size": 4321,
                        "statusCode": 4,
                        "links": [
                            {"link": "https://alldebrid.example/restricted-status"}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/link/unlock") {
                let body = #"{"status":"success","data":{"link":"https://cdn.example/status/movie.bin"}}"#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        let stream = try await service.getStreamURL(torrentId: "1")

        #expect(stream.fileName == "Status.Movie.1080p.BluRay.mkv")
        #expect(stream.sizeBytes == 4321)
        #expect(stream.quality == .hd1080p)
        #expect(stream.source == .bluRay)
    }

    @Test func getStreamURLUsesDefaultProcessingStatusWhenProviderStatusIsMissing() async {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"status":"success","data":{"id":1,"links":[{"link":"https://alldebrid.example/restricted"}]}}"#
            return (response, Data(body.utf8))
        }

        let service = AllDebridService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.fileNotReady("processing")) {
            _ = try await service.getStreamURL(torrentId: "1")
        }
    }
}
