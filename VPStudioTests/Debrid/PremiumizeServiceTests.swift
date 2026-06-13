import Foundation
import Testing
@testable import VPStudio

@Suite("PremiumizeService")
struct PremiumizeServiceTests {
    @Test func validateTokenReturnsTrueForValidToken() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"status\":\"success\",\"customer_id\":\"cust123\",\"premium_until\":1735689600}"
            return (response, Data(body.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)
        let isValid = try await service.validateToken()
        #expect(isValid == true)
    }

    @Test func getAccountInfoReturnsExpectedStructure() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"status\":\"success\",\"customer_id\":\"premiumize_user\",\"premium_until\":1735689600}"
            return (response, Data(body.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)
        let accountInfo = try await service.getAccountInfo()
        #expect(accountInfo.username == "premiumize_user")
        #expect(accountInfo.email == nil)
        #expect(accountInfo.isPremium == true)
        #expect(accountInfo.premiumExpiry != nil)
    }

    @Test func getAccountInfoDefaultsUnknownAndNonPremiumWhenFieldsAreMissing() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"success"}"#.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)
        let accountInfo = try await service.getAccountInfo()

        #expect(accountInfo.username == "Unknown")
        #expect(accountInfo.isPremium == false)
        #expect(accountInfo.premiumExpiry == nil)
    }

    @Test func checkCacheReturnsCorrectStatusForCachedHashes() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"status\":\"success\",\"response\":[true,false,false]}"
            return (response, Data(body.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)
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

        let service = PremiumizeService(apiToken: "valid_token", session: session)
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
            let bodyResponse = "{\"status\":\"success\",\"id\":\"transfer123\"}"
            return (response, Data(bodyResponse.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)
        let requestId = try await service.addMagnet(hash: "ABC123DEF456abc123def456abc123def456abcd")

        #expect(requestId == "transfer123")
    }

    @Test func addMagnetFallsBackToNormalizedHashWhenResponseOmitsID() async throws {
        final class State: @unchecked Sendable { var capturedBody: String? }
        let state = State()
        let hash = "ABC123DEF456abc123def456abc123def456abcd"
        let fullMagnet = "magnet:?xt=urn:btih:\(hash)&dn=Premiumize Test&tr=udp://tracker.example/announce"
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.capturedBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"success"}"#.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)
        let requestId = try await service.addMagnet(hash: hash, magnetURI: fullMagnet)

        #expect(requestId == hash.lowercased())
        #expect(state.capturedBody?.contains("src=magnet") == true)
        #expect(state.capturedBody?.contains("%26tr") == true)
        #expect(state.capturedBody?.contains("&tr=") == false)
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
            let body = "{\"status\":\"success\",\"customer_id\":\"testuser\"}"
            return (response, Data(body.utf8))
        }

        let service = PremiumizeService(apiToken: "test_token", session: session)
        _ = try await service.validateToken()

        #expect(state.authHeader == "Bearer test_token")
    }

    @Test func requestHandlesNetworkErrors() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.self) {
            _ = try await service.validateToken()
        }
    }

    @Test func selectMatchingEpisodeFileReturnsFalseWhenSelectionCannotBeMatched() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path.hasSuffix("/transfer/list") {
                let body = """
                {
                    "transfers": [
                        {"id":"transfer123", "name":"Movie Collection", "status":"finished", "link":"https://premiumize.example/movie"}
                    ]
                }
                """
                return (response, Data(body.utf8))
            }
            Issue.record("Unexpected request: \(url.absoluteString)")
            return (response, Data())
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)
        let matched = try await service.selectMatchingEpisodeFile(
            torrentId: "transfer123",
            seasonNumber: 1,
            episodeNumber: 1,
            resolvedFileNameHint: "S01E01.mkv",
            resolvedFileSizeHint: nil
        )

        #expect(matched == false)
    }

    @Test func selectMatchingEpisodeFileAcceptsMissingTransferExactNameAndTokenMatch() async throws {
        final class State: @unchecked Sendable { var callCount = 0 }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.callCount += 1
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body: String
            switch state.callCount {
            case 1:
                body = #"{"status":"success","transfers":[]}"#
            case 2:
                body = #"{"status":"success","transfers":[{"id":"exact","name":"/folder/Show.S01E02.mkv","status":"finished","link":"https://premiumize.example/exact.mkv"}]}"#
            default:
                body = #"{"status":"success","transfers":[{"id":"token","name":"Show.S02E05.1080p.mkv","status":"finished","link":"https://premiumize.example/token.mkv"}]}"#
            }
            return (response, Data(body.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)

        let missing = try await service.selectMatchingEpisodeFile(
            torrentId: "missing",
            seasonNumber: 1,
            episodeNumber: 2,
            resolvedFileNameHint: nil,
            resolvedFileSizeHint: nil
        )
        let exact = try await service.selectMatchingEpisodeFile(
            torrentId: "exact",
            seasonNumber: 1,
            episodeNumber: 2,
            resolvedFileNameHint: "Show.S01E02.mkv",
            resolvedFileSizeHint: nil
        )
        let token = try await service.selectMatchingEpisodeFile(
            torrentId: "token",
            seasonNumber: 2,
            episodeNumber: 5,
            resolvedFileNameHint: nil,
            resolvedFileSizeHint: nil
        )

        #expect(missing)
        #expect(exact)
        #expect(token)
    }

    @Test func getStreamURLThrowsWhenStoredEpisodeSelectionMismatchesTransferName() async throws {
        final class State: @unchecked Sendable { var callCount = 0 }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.callCount += 1
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if state.callCount == 1 {
                return (response, Data(#"{"status":"success","transfers":[]}"#.utf8))
            }
            let body = #"{"status":"success","transfers":[{"id":"mismatch","name":"Movie.Collection.mkv","status":"finished","link":"https://premiumize.example/movie.mkv"}]}"#
            return (response, Data(body.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)
        _ = try await service.selectMatchingEpisodeFile(
            torrentId: "mismatch",
            seasonNumber: 1,
            episodeNumber: 2,
            resolvedFileNameHint: "Show.S01E02.mkv",
            resolvedFileSizeHint: nil
        )

        await #expect(
            throws: DebridError.networkError("Premiumize could not deterministically select the requested episode file.")
        ) {
            _ = try await service.getStreamURL(torrentId: "mismatch")
        }
    }

    @Test func getStreamURLThrowsForMissingTransferNotReadyStatusAndInvalidLink() async throws {
        final class State: @unchecked Sendable { var callCount = 0 }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.callCount += 1
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body: String
            switch state.callCount {
            case 1:
                body = #"{"status":"success","transfers":[]}"#
            case 2:
                body = #"{"status":"success","transfers":[{"id":"pending","name":"Pending.mkv","status":null,"link":null}]}"#
            default:
                body = #"{"status":"success","transfers":[{"id":"bad-link","name":"Bad.mkv","status":"finished","link":"http://[::1"}]}"#
            }
            return (response, Data(body.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)

        await #expect(throws: DebridError.torrentNotFound("missing")) {
            _ = try await service.getStreamURL(torrentId: "missing")
        }
        await #expect(throws: DebridError.fileNotReady("unknown")) {
            _ = try await service.getStreamURL(torrentId: "pending")
        }
        await #expect(throws: DebridError.networkError("Invalid URL")) {
            _ = try await service.getStreamURL(torrentId: "bad-link")
        }
    }

    @Test func cleanupRemoteTransferEncodesIDAndRejectsErrorStatus() async throws {
        final class State: @unchecked Sendable { var capturedBody: String? }
        let state = State()
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            state.capturedBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"status":"error","message":"delete denied"}"#
            return (response, Data(body.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)

        await #expect(throws: DebridError.networkError("delete denied")) {
            try await service.cleanupRemoteTransfer(torrentId: "transfer id&1")
        }
        #expect(state.capturedBody == "id=transfer%20id%261")
    }

    @Test func requestMapsRateLimitedResponseToRateLimitedError() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"error","message":"rate limited"}"#.utf8))
        }

        let service = PremiumizeService(apiToken: "valid_token", session: session)
        await #expect(throws: DebridError.rateLimited) {
            _ = try await service.validateToken()
        }
    }
}
