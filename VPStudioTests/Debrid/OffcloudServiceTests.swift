import Foundation
import Testing
@testable import VPStudio

@Suite("OffcloudService")
struct OffcloudServiceTests {
    @Test func validateTokenReturnsTrueForValidToken() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "[]"
            return (response, Data(body.utf8))
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        let isValid = try await service.validateToken()
        #expect(isValid == true)
    }

    @Test func validateTokenReturnsFalseForUnauthorized() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "invalid_token", session: session)
        let isValid = try await service.validateToken()
        #expect(isValid == false)
    }

    @Test func getAccountInfoReturnsExpectedStructure() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "[]"
            return (response, Data(body.utf8))
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        let accountInfo = try await service.getAccountInfo()
        #expect(accountInfo.username == "Offcloud User")
        #expect(accountInfo.email == nil)
        #expect(accountInfo.premiumExpiry == nil)
        #expect(accountInfo.isPremium == true)
    }

    @Test func checkCacheReturnsCorrectStatusForCachedHashes() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"cachedItems\":[\"abc123\",\"def456\"]}"
            return (response, Data(body.utf8))
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        let hashes = ["ABC123", "def456", "ghi789"]
        let cacheStatus = try await service.checkCache(hashes: hashes)

        #expect(cacheStatus["abc123"] == .cached(fileId: nil, fileName: nil, fileSize: nil))
        #expect(cacheStatus["def456"] == .cached(fileId: nil, fileName: nil, fileSize: nil))
        #expect(cacheStatus["ghi789"] == .notCached)
    }

    @Test func checkCacheReturnsEmptyForEmptyInput() async throws {
        let session = URLProtocolHarness.makeSession { request in
            Issue.record("Unexpected request for empty hashes")
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        let cacheStatus = try await service.checkCache(hashes: [])
        #expect(cacheStatus.isEmpty)
    }

    @Test func addMagnetConstructsCorrectRequest() async throws {
        final class State: @unchecked Sendable {
            var capturedBody: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let body = String(data: request.httpBody ?? Data(), encoding: .utf8)
            state.capturedBody = body
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let bodyResponse = "{\"requestId\":\"req123\"}"
            return (response, Data(bodyResponse.utf8))
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        let requestId = try await service.addMagnet(hash: "ABC123DEF456abc123def456abc123def456abcd")

        #expect(requestId == "req123")
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
            return (response, Data("[]".utf8))
        }

        let service = OffcloudService(apiToken: "test_token", session: session)
        _ = try await service.validateToken()

        #expect(state.authHeader == "Bearer test_token")
    }

    @Test func requestHandlesNetworkErrors() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.self) {
            _ = try await service.validateToken()
        }
    }

    @Test func selectFilesWithEmptyListClearsSelectionState() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            if url.path.hasSuffix("/cloud/status") {
                let body = #"{"status":"downloaded"}"#
                return (response, Data(body.utf8))
            }

            if url.path.hasSuffix("/cloud/explore/123") {
                let body = """
                [
                    "https://offcloud.example/stream",
                    "https://offcloud.example/show.s01e01.mp4"
                ]
                """
                return (response, Data(body.utf8))
            }

            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data("{}".utf8))
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        try await service.selectFiles(torrentId: "123", fileIds: [1])
        try await service.selectFiles(torrentId: "123", fileIds: [])
        let stream = try await service.getStreamURL(torrentId: "123")

        #expect(stream.streamURL.absoluteString == "https://offcloud.example/show.s01e01.mp4")
    }

    @Test func requestFallsBackToRootBaseURLOn404() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)

            if url.path == "/api/cloud/history" {
                let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (response, Data("{}".utf8))
            }

            if url.path == "/cloud/history" {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("[]".utf8))
            }

            Issue.record("Unexpected request: \(url.absoluteString)")
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        let isValid = try await service.validateToken()
        #expect(isValid == true)
    }

    @Test func requestMapsRateLimitedResponsesToRateLimitedError() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.rateLimited) {
            _ = try await service.validateToken()
        }
    }

    @Test func cleanupRemoteTransferMapsUnauthorizedAndRateLimitedResponses() async throws {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            state.requestCount += 1
            let url = try #require(request.url)
            let statusCode = state.requestCount == 1 ? 401 : 429
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)

        await #expect(throws: DebridError.unauthorized) {
            try await service.cleanupRemoteTransfer(torrentId: "cleanup-401")
        }
        await #expect(throws: DebridError.rateLimited) {
            try await service.cleanupRemoteTransfer(torrentId: "cleanup-429")
        }
    }

    @Test func bestEpisodeMatchReturnsSingleMatchingLink() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/cloud/status") {
                let body = #"{"status":"downloaded"}"#
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/cloud/explore/abc") {
                let body = #"""
                [
                    "https://offcloud.example/Show.S01E01.mkv",
                    "https://offcloud.example/Show.S01E02.mkv"
                ]
                """#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        _ = try await service.selectMatchingEpisodeFile(torrentId: "abc", seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        let stream = try await service.getStreamURL(torrentId: "abc")

        #expect(stream.streamURL.absoluteString == "https://offcloud.example/Show.S01E01.mkv")
    }

    @Test func bestEpisodeMatchReturnsLargestMatchingLinkByEstimatedSize() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/cloud/status") {
                let body = #"{"status":"downloaded"}"#
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/cloud/explore/def") {
                let body = #"""
                [
                    "https://offcloud.example/Show.S01E01.mkv?size=120",
                    "https://offcloud.example/Show.S01E01.mkv?size=980"
                ]
                """#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        _ = try await service.selectMatchingEpisodeFile(torrentId: "def", seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        let stream = try await service.getStreamURL(torrentId: "def")

        #expect(stream.streamURL.absoluteString == "https://offcloud.example/Show.S01E01.mkv?size=980")
    }

    @Test func exactNameMatchUsesResolvedSizeHintBeforeLargestFallback() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/cloud/status") {
                let body = #"{"status":"downloaded"}"#
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/cloud/explore/exact-size") {
                let body = #"""
                [
                    "https://offcloud.example/Show.S01E02.mkv?size=999",
                    "https://offcloud.example/Show.S01E02.mkv?size=222"
                ]
                """#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        _ = try await service.selectMatchingEpisodeFile(
            torrentId: "exact-size",
            seasonNumber: 1,
            episodeNumber: 2,
            resolvedFileNameHint: "Show.S01E02.mkv",
            resolvedFileSizeHint: 222
        )
        let stream = try await service.getStreamURL(torrentId: "exact-size")

        #expect(stream.streamURL.absoluteString == "https://offcloud.example/Show.S01E02.mkv?size=222")
    }

    @Test func bestEpisodeMatchFallsBackToSoleLinkWhenNoEpisodeMatches() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/cloud/status") {
                let body = #"{"status":"downloaded"}"#
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/cloud/explore/ghi") {
                let body = #"["https://offcloud.example/extras/show.s02e99.mkv"]"#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        _ = try await service.selectMatchingEpisodeFile(torrentId: "ghi", seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        let stream = try await service.getStreamURL(torrentId: "ghi")

        #expect(stream.streamURL.absoluteString == "https://offcloud.example/extras/show.s02e99.mkv")
    }

    @Test func deterministicEpisodeMatchUsesNormalizedResolvedNameHint() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/cloud/status") {
                let body = """
                {
                    "status":"downloaded",
                    "url":"https://offcloud.example/Show%20S01E01.mkv"
                }
                """
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        _ = try await service.selectMatchingEpisodeFile(
            torrentId: "jkl",
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "  show s01e01.mkv ",
            resolvedFileSizeHint: nil
        )
        let stream = try await service.getStreamURL(torrentId: "jkl")
        #expect(stream.streamURL.absoluteString == "https://offcloud.example/Show%20S01E01.mkv")
    }

    @Test func resolvedDisplayFileNamePrefersStatusFileNameForGenericLinks() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/cloud/status") {
                let body = """
                {
                    "status":"downloaded",
                    "fileName":"Episode.Name.S01E01.mkv",
                    "url":"https://offcloud.example/download"
                }
                """
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        _ = try await service.selectMatchingEpisodeFile(
            torrentId: "mno",
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "Episode.Name.S01E01.mkv",
            resolvedFileSizeHint: nil
        )
        let stream = try await service.getStreamURL(torrentId: "mno")

        #expect(stream.fileName == "Episode.Name.S01E01.mkv")
    }

    @Test func resolvedDisplayFileNameUsesLinkNameWhenStatusFileNameIsMissing() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/cloud/status") {
                let body = #"{"status":"downloaded"}"#
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/cloud/explore/link-name") {
                let body = #"["https://offcloud.example/folder/Episode.Link.Name.720p.mkv"]"#
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = OffcloudService(apiToken: "valid_token", session: session)
        let stream = try await service.getStreamURL(torrentId: "link-name")

        #expect(stream.fileName == "Episode.Link.Name.720p.mkv")
        #expect(stream.quality == .hd720p)
    }
}
