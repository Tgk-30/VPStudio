import Foundation
import Testing
@testable import VPStudio

@Suite("TorBoxService")
struct TorBoxServiceTests {
    @Test func validateTokenReturnsTrueForValidToken() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"success\":true,\"data\":{\"email\":\"test@example.com\",\"plan\":1}}"
            return (response, Data(body.utf8))
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        let isValid = try await service.validateToken()
        #expect(isValid == true)
    }

    @Test func getAccountInfoReturnsExpectedStructure() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"success\":true,\"data\":{\"email\":\"user@torbox.com\",\"plan\":1}}"
            return (response, Data(body.utf8))
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        let accountInfo = try await service.getAccountInfo()
        #expect(accountInfo.username == "user@torbox.com")
        #expect(accountInfo.email == "user@torbox.com")
        #expect(accountInfo.isPremium == true)
    }

    @Test func checkCacheReturnsCorrectStatusForCachedHashes() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"success\":true,\"data\":[{\"hash\":\"abc123\"},{\"hash\":\"def456\"}]}"
            return (response, Data(body.utf8))
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
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

        let service = TorBoxService(apiToken: "valid_token", session: session)
        let cacheStatus = try await service.checkCache(hashes: [])
        #expect(cacheStatus.isEmpty)
    }

    @Test func addMagnetConstructsCorrectRequest() async throws {
        final class State: @unchecked Sendable {
            var capturedContentType: String?
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.capturedContentType = request.value(forHTTPHeaderField: "Content-Type")
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let bodyResponse = "{\"success\":true,\"data\":{\"torrent_id\":123}}"
            return (response, Data(bodyResponse.utf8))
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        let requestId = try await service.addMagnet(hash: "ABC123DEF456abc123def456abc123def456abcd")

        #expect(requestId == "123")
        #expect(state.capturedContentType?.hasPrefix("multipart/form-data; boundary=") == true)
    }

    @Test func getStreamURLUsesSelectedFileMetadata() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/torrents/mylist") {
                let body = """
                {
                    "success": true,
                    "data": {
                        "name": "Show.Season.Pack",
                        "size": 9999,
                        "download_finished": true,
                        "files": [
                            {"id": 3, "name": "Show.S01E01.720p.WEB-DL.mkv", "size": 100},
                            {"id": 7, "name": "Show.S01E02.2160p.HDR10.WEB-DL.mkv", "size": 2222}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/torrents/requestdl") {
                #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains {
                    $0.name == "file_id" && $0.value == "7"
                } == true)
                return (response, Data(#"{"success":true,"data":"https://cdn.example.com/show-s01e02.mkv"}"#.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data(#"{"success":true,"data":null}"#.utf8))
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        try await service.selectFiles(torrentId: "321", fileIds: [7])
        let stream = try await service.getStreamURL(torrentId: "321")

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
            let body = "{\"success\":true,\"data\":{\"email\":\"test@example.com\"}}"
            return (response, Data(body.utf8))
        }

        let service = TorBoxService(apiToken: "test_token", session: session)
        _ = try await service.validateToken()

        #expect(state.authHeader == "Bearer test_token")
    }

    @Test func requestHandlesNetworkErrors() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.self) {
            _ = try await service.validateToken()
        }
    }

    @Test func requestMapsRateLimitToRateLimitedError() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{}"#.utf8))
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.rateLimited) {
            _ = try await service.validateToken()
        }
    }

    @Test func selectMatchingEpisodeFileReturnsFalseWhenNoEpisodeMatch() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/torrents/mylist") {
                let body = """
                {
                    "success": true,
                    "data": {
                        "files": [
                            {"id": 1, "name": "Show.S02E05.mkv", "size": 1000},
                            {"id": 2, "name": "Show.S02E06.mkv", "size": 2000}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        let matched = try await service.selectMatchingEpisodeFile(
            torrentId: "1",
            seasonNumber: 1,
            episodeNumber: 1
        )
        #expect(matched == false)
    }

    @Test func selectMatchingEpisodeFileFallsBackToSingleFileWhenOnlyOneFileExists() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/torrents/mylist") {
                let body = """
                {
                    "success": true,
                    "data": {
                        "files": [
                            {"id": 7, "name": "Not.episode.pack.zip", "size": 1000}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        let matched = try await service.selectMatchingEpisodeFile(
            torrentId: "1",
            seasonNumber: 1,
            episodeNumber: 1
        )
        #expect(matched == true)
    }

    @Test func selectMatchingEpisodeFileUsesExactMatchBySizeHint() async throws {
        final class State: @unchecked Sendable {
            var requestedFileID: String?
        }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            if url.path.hasSuffix("/torrents/mylist") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {
                    "success": true,
                    "data": {
                        "download_finished": true,
                        "files": [
                            {"id": 20, "name": "Show.S01E01.720p.WEB-DL.mkv", "size": 2500},
                            {"id": 21, "name": "Show.S01E01.720p.WEB-DL.mkv", "size": 1000}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/torrents/requestdl") {
                let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
                state.requestedFileID = components.queryItems?.first(where: { $0.name == "file_id" })?.value
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"success":true,"data":"https://cdn.example.com/video.mkv"}"#.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        let matched = try await service.selectMatchingEpisodeFile(
            torrentId: "123",
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "Show.S01E01.720p.WEB-DL.mkv",
            resolvedFileSizeHint: 1000
        )
        #expect(matched == true)
        _ = try await service.getStreamURL(torrentId: "123")
        #expect(state.requestedFileID == "21")
    }

    @Test func selectMatchingEpisodeFileFallsBackToLargestExactMatchWhenSizeHintDoesNotMatch() async throws {
        final class State: @unchecked Sendable {
            var requestedFileID: String?
        }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            if url.path.hasSuffix("/torrents/mylist") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {
                    "success": true,
                    "data": {
                        "download_finished": true,
                        "files": [
                            {"id": 30, "name": "Show.S01E02.720p.WEB-DL.mkv", "size": 2000},
                            {"id": 31, "name": "Show.S01E02.720p.WEB-DL.mkv", "size": 3000}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/torrents/requestdl") {
                let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
                state.requestedFileID = components.queryItems?.first(where: { $0.name == "file_id" })?.value
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"success":true,"data":"https://cdn.example.com/video.mkv"}"#.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        let matched = try await service.selectMatchingEpisodeFile(
            torrentId: "124",
            seasonNumber: 1,
            episodeNumber: 2,
            resolvedFileNameHint: "Show.S01E02.720p.WEB-DL.mkv",
            resolvedFileSizeHint: 1234
        )
        #expect(matched == true)
        _ = try await service.getStreamURL(torrentId: "124")
        #expect(state.requestedFileID == "31")
    }

    @Test func selectMatchingEpisodeFileFallsBackToEpisodeTokenMatch() async throws {
        final class State: @unchecked Sendable {
            var requestedFileID: String?
        }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            if url.path.hasSuffix("/torrents/mylist") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = """
                {
                    "success": true,
                    "data": {
                        "download_finished": true,
                        "files": [
                            {"id": 40, "name": "Movie.Trailer.mkv", "size": 100},
                            {"id": 41, "name": "Show.S01E03.720p.WEB-DL.mkv", "size": 2200},
                            {"id": 42, "name": "Show.S01E03.1080p.BluRay.mkv", "size": 5000}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/torrents/requestdl") {
                let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
                state.requestedFileID = components.queryItems?.first(where: { $0.name == "file_id" })?.value
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"success":true,"data":"https://cdn.example.com/video.mkv"}"#.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        let matched = try await service.selectMatchingEpisodeFile(
            torrentId: "125",
            seasonNumber: 1,
            episodeNumber: 3
        )
        #expect(matched == true)
        _ = try await service.getStreamURL(torrentId: "125")
        #expect(state.requestedFileID == "42")
    }

    @Test func getStreamURLFallsBackToLargestFileWhenNoSelectionState() async throws {
        final class State: @unchecked Sendable {
            var requestedFileID: String?
        }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/torrents/mylist") {
                let body = """
                {
                    "success": true,
                    "data": {
                        "name": "Pack.Name",
                        "download_finished": true,
                        "files": [
                            {"id": 50, "name": "Small.mkv", "size": 100},
                            {"id": 60, "name": "Large.mkv", "size": 5000}
                        ]
                    }
                }
                """
                return (response, Data(body.utf8))
            }
            if url.path.hasSuffix("/torrents/requestdl") {
                let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
                state.requestedFileID = components.queryItems?.first(where: { $0.name == "file_id" })?.value
                return (response, Data(#"{"success":true,"data":"https://cdn.example.com/pack/large.mkv"}"#.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        _ = try await service.getStreamURL(torrentId: "126")
        #expect(state.requestedFileID == "60")
    }

    @Test func getStreamURLThrowsWhenDownloadNotReady() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {
                "success": true,
                "data": {
                    "name": "Pack.Name",
                    "download_finished": false,
                    "files": []
                }
            }
            """
            return (response, Data(body.utf8))
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.fileNotReady("downloading")) {
            _ = try await service.getStreamURL(torrentId: "127")
        }
    }

    @Test func cleanupRemoteTransferMapsRateLimitError() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.rateLimited) {
            try await service.cleanupRemoteTransfer(torrentId: "128")
        }
    }

    @Test func cleanupRemoteTransferMapsUnauthorizedAndHTTPError() async throws {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = URLProtocolHarness.makeSession { request in
            state.requestCount += 1
            let url = try #require(request.url)
            if state.requestCount == 1 {
                let response = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!
                return (response, Data("forbidden".utf8))
            }
            let response = HTTPURLResponse(url: url, statusCode: 502, httpVersion: nil, headerFields: nil)!
            return (response, Data("bad gateway".utf8))
        }

        let service = TorBoxService(apiToken: "valid_token", session: session)

        await #expect(throws: DebridError.unauthorized) {
            try await service.cleanupRemoteTransfer(torrentId: "129")
        }
        await #expect(throws: DebridError.httpError(502, "bad gateway")) {
            try await service.cleanupRemoteTransfer(torrentId: "130")
        }
    }
}
