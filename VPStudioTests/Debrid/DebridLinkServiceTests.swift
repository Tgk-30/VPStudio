import Foundation
import Testing
@testable import VPStudio

@Suite("DebridLinkService")
struct DebridLinkServiceTests {
    @Test func validateTokenReturnsTrueForValidToken() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"success\":true,\"value\":{\"pseudo\":\"testuser\",\"email\":\"test@example.com\",\"premiumLeft\":3600}}"
            return (response, Data(body.utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        let isValid = try await service.validateToken()
        #expect(isValid == true)
    }

    @Test func getAccountInfoReturnsExpectedStructure() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"success\":true,\"value\":{\"pseudo\":\"debridlink_user\",\"email\":\"user@debridlink.com\",\"premiumLeft\":86400}}"
            return (response, Data(body.utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        let accountInfo = try await service.getAccountInfo()
        #expect(accountInfo.username == "debridlink_user")
        #expect(accountInfo.email == "user@debridlink.com")
        #expect(accountInfo.isPremium == true)
        #expect(accountInfo.premiumExpiry != nil)
    }

    @Test func checkCacheReturnsCorrectStatusForCachedHashes() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                \"success\":true,
                \"value\":{
                    \"abc123\":{\"files\":[{\"id\":1,\"name\":\"file.mkv\"}]},
                    \"def456\":{\"files\":null}
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
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

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        let cacheStatus = try await service.checkCache(hashes: [])
        #expect(cacheStatus.isEmpty)
    }

    @Test func addMagnetConstructsCorrectRequest() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let bodyResponse = "{\"success\":true,\"value\":{\"id\":\"torrent123\"}}"
            return (response, Data(bodyResponse.utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        let hash40 = "ABC123DEF456abc123def456abc123def456abcd"
        let requestId = try await service.addMagnet(hash: hash40)

        #expect(requestId == "torrent123")
    }

    @Test func getStreamURLUsesChosenFileSize() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/seedbox/list") {
                let body = """
                {
                    "success": true,
                    "value": [
                        {
                            "name": "Show.Season.Pack",
                            "totalSize": 9999,
                            "downloadPercent": 100,
                            "files": [
                                {"id": 1, "name": "Show.S01E01.720p.WEB-DL.mkv", "size": 100, "downloadUrl": "https://cdn.example.com/show-s01e01.mkv"},
                                {"id": 2, "name": "Show.S01E02.2160p.HDR10.WEB-DL.mkv", "size": 2222, "downloadUrl": "https://cdn.example.com/show-s01e02.mkv"}
                            ]
                        }
                    ]
                }
                """
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data(#"{"success":true,"value":[]}"#.utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        try await service.selectFiles(torrentId: "torrent123", fileIds: [2])
        let stream = try await service.getStreamURL(torrentId: "torrent123")

        #expect(stream.streamURL.absoluteString == "https://cdn.example.com/show-s01e02.mkv")
        #expect(stream.fileName == "Show.S01E02.2160p.HDR10.WEB-DL.mkv")
        #expect(stream.sizeBytes == 2222)
        #expect(stream.quality == .uhd4k)
        #expect(stream.hdr == .hdr10)
    }

    @Test func addMagnetThrowsWhenAPIRejectsOrOmitsTorrentID() async throws {
        final class State: @unchecked Sendable { var callCount = 0 }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.callCount += 1
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if state.callCount == 1 {
                return (response, Data(#"{"success":false,"error":"quota reached"}"#.utf8))
            }
            return (response, Data(#"{"success":true,"value":{"id":""}}"#.utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)

        await #expect(throws: DebridError.networkError("quota reached")) {
            _ = try await service.addMagnet(hash: "ABC123DEF456abc123def456abc123def456abcd")
        }
        await #expect(throws: DebridError.networkError("Debrid-Link did not return a torrent id")) {
            _ = try await service.addMagnet(hash: "ABC123DEF456abc123def456abc123def456abcd")
        }
    }

    @Test func cleanupRemoteTransferClearsSelectionAndMapsHTTPFailures() async throws {
        final class State: @unchecked Sendable { var callCount = 0 }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.callCount += 1
            if state.callCount == 1 {
                let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data("unauthorized".utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, Data("bad cleanup".utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        try await service.selectFiles(torrentId: "torrent123", fileIds: [2])

        await #expect(throws: DebridError.unauthorized) {
            try await service.cleanupRemoteTransfer(torrentId: "torrent123")
        }
        await #expect(throws: DebridError.httpError(400, "bad cleanup")) {
            try await service.cleanupRemoteTransfer(torrentId: "torrent123")
        }
    }

    @Test func getStreamURLFallsBackToDownloadURLNameAndTorrentSize() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "success": true,
                "value": [
                    {
                        "name": "Fallback Pack",
                        "totalSize": 7777,
                        "downloadPercent": 100,
                        "files": [
                            {"id": 1, "name": null, "size": null, "downloadUrl": "https://cdn.example.com/path/Fallback.File.1080p.mkv"}
                        ]
                    }
                ]
            }
            """
            return (response, Data(body.utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        let stream = try await service.getStreamURL(torrentId: "torrent123")

        #expect(stream.fileName == "Fallback.File.1080p.mkv")
        #expect(stream.sizeBytes == 7777)
        #expect(stream.quality == .hd1080p)
    }

    @Test func getStreamURLUsesEpisodeExactSizeHintAndOnlyFileFallback() async throws {
        final class State: @unchecked Sendable { var callCount = 0 }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.callCount += 1
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if state.callCount == 1 {
                let body = """
                {
                    "success": true,
                    "value": [
                        {
                            "name": "Show Pack",
                            "totalSize": 9999,
                            "downloadPercent": 100,
                            "files": [
                                {"id": 1, "name": "Show.S01E02.mkv", "size": 1000, "downloadUrl": "https://cdn.example.com/small.mkv"},
                                {"id": 2, "name": "Show.S01E02.mkv", "size": 2000, "downloadUrl": "https://cdn.example.com/exact.mkv"}
                            ]
                        }
                    ]
                }
                """
                return (response, Data(body.utf8))
            }
            let body = """
            {
                "success": true,
                "value": [
                    {
                        "name": "Single File Pack",
                        "totalSize": 3333,
                        "downloadPercent": 100,
                        "files": [
                            {"id": 9, "name": "Movie.Feature.mkv", "size": 3333, "downloadUrl": "https://cdn.example.com/single.mkv"}
                        ]
                    }
                ]
            }
            """
            return (response, Data(body.utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        _ = try await service.selectMatchingEpisodeFile(
            torrentId: "torrent123",
            seasonNumber: 1,
            episodeNumber: 2,
            resolvedFileNameHint: "Show.S01E02.mkv",
            resolvedFileSizeHint: 2000
        )
        let exact = try await service.getStreamURL(torrentId: "torrent123")

        _ = try await service.selectMatchingEpisodeFile(
            torrentId: "torrent456",
            seasonNumber: 8,
            episodeNumber: 8,
            resolvedFileNameHint: nil,
            resolvedFileSizeHint: nil
        )
        let onlyFile = try await service.getStreamURL(torrentId: "torrent456")

        #expect(exact.streamURL.absoluteString == "https://cdn.example.com/exact.mkv")
        #expect(exact.sizeBytes == 2000)
        #expect(onlyFile.streamURL.absoluteString == "https://cdn.example.com/single.mkv")
        #expect(onlyFile.fileName == "Movie.Feature.mkv")
    }

    @Test func getStreamURLThrowsWhenEpisodeSelectionCannotResolveDownloadLink() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "success": true,
                "value": [
                    {
                        "name": "Ambiguous Pack",
                        "totalSize": 9999,
                        "downloadPercent": 100,
                        "files": [
                            {"id": 1, "name": "Movie.A.mkv", "size": 1000, "downloadUrl": null},
                            {"id": 2, "name": "Movie.B.mkv", "size": 2000, "downloadUrl": null}
                        ]
                    }
                ]
            }
            """
            return (response, Data(body.utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        _ = try await service.selectMatchingEpisodeFile(
            torrentId: "torrent123",
            seasonNumber: 1,
            episodeNumber: 2,
            resolvedFileNameHint: nil,
            resolvedFileSizeHint: nil
        )

        await #expect(
            throws: DebridError.networkError("Debrid-Link could not deterministically select the requested episode file.")
        ) {
            _ = try await service.getStreamURL(torrentId: "torrent123")
        }
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
            let body = "{\"success\":true,\"value\":{\"pseudo\":\"testuser\"}}"
            return (response, Data(body.utf8))
        }

        let service = DebridLinkService(apiToken: "test_token", session: session)
        _ = try await service.validateToken()

        #expect(state.authHeader == "Bearer test_token")
    }

    @Test func requestHandlesNetworkErrors() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.self) {
            _ = try await service.validateToken()
        }
    }

    @Test func requestHandlesRateLimitError() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"success":false,"error":"rate limited"}"#.utf8))
        }

        let service = DebridLinkService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.rateLimited) {
            _ = try await service.validateToken()
        }
    }
}
