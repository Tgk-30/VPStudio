import Testing
import Foundation
@testable import VPStudio

// MARK: - Stub Session Helper

private func makeTraktStubSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    URLProtocolHarness.makeSession(handler: handler)
}

// MARK: - Helper

private func readStream(_ stream: InputStream?) -> Data? {
    guard let stream else { return nil }
    stream.open()
    defer { stream.close() }

    var output = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: buffer.count)
        if read <= 0 { break }
        output.append(buffer, count: read)
    }
    return output
}

// MARK: - GET 401 Retry

@Suite("TraktSyncService - GET 401 Retry")
struct TraktSyncServiceGETRetryTests {

    @Test func getWatched401TriggersRefreshAndRetriesWithNewToken() async throws {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let url = request.url!
            let path = url.path

            if path.hasSuffix("/oauth/token") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"access_token":"refreshed-token","refresh_token":"refreshed-refresh"}"#
                return (response, Data(body.utf8))
            }

            if state.requestCount == 1 {
                let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "stale-token", refresh: "valid-refresh")
        let result: [TraktWatchedItem] = try await service.getWatched(type: .movie)

        #expect(state.requestCount == 3)
        #expect(result.isEmpty)
    }

    @Test func getWatchedSecond401AfterRefreshIsNotRetried() async {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let url = request.url!
            let path = url.path

            if path.hasSuffix("/oauth/token") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"access_token":"refreshed-token","refresh_token":"refreshed-refresh"}"#
                return (response, Data(body.utf8))
            }

            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "stale-token", refresh: "valid-refresh")

        do {
            _ = try await service.getWatched(type: .movie)
            Issue.record("Expected TraktError.unauthorized")
        } catch let error as TraktError {
            if case .unauthorized = error { /* OK */ }
            else { Issue.record("Unexpected TraktError: \(error)") }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(state.requestCount == 3)
    }

    @Test func getWatchedNon401ErrorIsNotRetried() async {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: "valid-refresh")

        do {
            _ = try await service.getWatched(type: .movie)
            Issue.record("Expected TraktError.httpError(500)")
        } catch let error as TraktError {
            if case .httpError(500) = error { /* OK */ }
            else { Issue.record("Unexpected TraktError: \(error)") }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(state.requestCount == 1)
    }

    @Test func getWatchedSuccessfulRequestPassesThrough() async throws {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let result: [TraktWatchedItem] = try await service.getWatched(type: .movie)

        #expect(state.requestCount == 1)
        #expect(result.isEmpty)
    }

    @Test func getWatched401WithoutRefreshTokenThrowsUnauthorized() async {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "stale-token", refresh: nil)

        do {
            _ = try await service.getWatched(type: .movie)
            Issue.record("Expected TraktError.unauthorized")
        } catch let error as TraktError {
            if case .unauthorized = error { /* OK */ }
            else { Issue.record("Unexpected TraktError: \(error)") }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(state.requestCount == 1)
    }
}

// MARK: - POST 401 Retry

@Suite("TraktSyncService - POST 401 Retry")
struct TraktSyncServicePOSTRetryTests {

    @Test func addRating401TriggersRefreshAndRetries() async throws {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let url = request.url!
            let path = url.path

            if path.hasSuffix("/oauth/token") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"access_token":"refreshed-token","refresh_token":"refreshed-refresh"}"#
                return (response, Data(body.utf8))
            }

            if state.requestCount == 1 {
                let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }

            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1,"shows":0,"episodes":0}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "stale-token", refresh: "valid-refresh")
        try await service.addRating(imdbId: "tt123", rating: 8, type: .movie)

        #expect(state.requestCount == 3)
    }

    @Test func addRatingSecond401AfterRefreshIsNotRetried() async {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let url = request.url!
            let path = url.path

            if path.hasSuffix("/oauth/token") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"access_token":"refreshed-token","refresh_token":"refreshed-refresh"}"#
                return (response, Data(body.utf8))
            }

            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "stale-token", refresh: "valid-refresh")

        do {
            try await service.addRating(imdbId: "tt123", rating: 8, type: .movie)
            Issue.record("Expected TraktError.unauthorized")
        } catch let error as TraktError {
            if case .unauthorized = error { /* OK */ }
            else { Issue.record("Unexpected TraktError: \(error)") }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(state.requestCount == 3)
    }

    @Test func addRatingNon401ErrorIsNotRetried() async {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: "valid-refresh")

        do {
            try await service.addRating(imdbId: "tt123", rating: 8, type: .movie)
            Issue.record("Expected TraktError.httpError(503)")
        } catch let error as TraktError {
            if case .httpError(503) = error { /* OK */ }
            else { Issue.record("Unexpected TraktError: \(error)") }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(state.requestCount == 1)
    }

    @Test func addRatingSuccessfulRequestPassesThrough() async throws {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1,"shows":0,"episodes":0}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addRating(imdbId: "tt123", rating: 8, type: .movie)

        #expect(state.requestCount == 1)
    }
}

// MARK: - DELETE 401 Retry

@Suite("TraktSyncService - DELETE 401 Retry")
struct TraktSyncServiceDELETERetryTests {

    @Test func deleteCustomList401TriggersRefreshAndRetries() async throws {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let url = request.url!
            let path = url.path

            if path.hasSuffix("/oauth/token") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"access_token":"refreshed-token","refresh_token":"refreshed-refresh"}"#
                return (response, Data(body.utf8))
            }

            if state.requestCount == 1 {
                let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }

            let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "stale-token", refresh: "valid-refresh")
        try await service.deleteCustomList(listId: 42)

        #expect(state.requestCount == 3)
    }

    @Test func deleteCustomListSecond401AfterRefreshIsNotRetried() async {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let url = request.url!
            let path = url.path

            if path.hasSuffix("/oauth/token") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"access_token":"refreshed-token","refresh_token":"refreshed-refresh"}"#
                return (response, Data(body.utf8))
            }

            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "stale-token", refresh: "valid-refresh")

        do {
            try await service.deleteCustomList(listId: 42)
            Issue.record("Expected TraktError.unauthorized")
        } catch let error as TraktError {
            if case .unauthorized = error { /* OK */ }
            else { Issue.record("Unexpected TraktError: \(error)") }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(state.requestCount == 3)
    }

    @Test func deleteCustomListNon401ErrorIsNotRetried() async {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: "valid-refresh")

        do {
            try await service.deleteCustomList(listId: 42)
            Issue.record("Expected TraktError.httpError(404)")
        } catch let error as TraktError {
            if case .httpError(404) = error { /* OK */ }
            else { Issue.record("Unexpected TraktError: \(error)") }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(state.requestCount == 1)
    }
}

// MARK: - Token Header Verification

@Suite("TraktSyncService - Token Header Verification")
struct TraktSyncServiceTokenHeaderTests {

    @Test func retryRequestUsesRefreshedTokenInAuthorizationHeader() async throws {
        final class State: @unchecked Sendable {
            var firstToken: String?
            var retryToken: String?
        }
        let state = State()

        let session = makeTraktStubSession { request in
            let url = request.url!
            let path = url.path

            if path.hasSuffix("/oauth/token") {
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, #"{"access_token":"new-token","refresh_token":"new-refresh"}"#.data(using: .utf8)!)
            }

            let auth = request.value(forHTTPHeaderField: "Authorization")
            if state.firstToken == nil {
                state.firstToken = auth
                let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }

            state.retryToken = auth
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "old-token", refresh: "valid-refresh")
        let _: [TraktWatchedItem] = try await service.getWatched(type: .movie)

        #expect(state.firstToken == "Bearer old-token")
        #expect(state.retryToken == "Bearer new-token")
    }

    @Test func originalRequestUsesCurrentTokenInAuthorizationHeader() async throws {
        final class State: @unchecked Sendable {
            var capturedToken: String?
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.capturedToken = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "current-token", refresh: nil)
        let _: [TraktWatchedItem] = try await service.getWatched(type: .movie)

        #expect(state.capturedToken == "Bearer current-token")
    }
}

// MARK: - EpisodeContext Parsing

@Suite("TraktSyncService - EpisodeContext Parsing")
struct TraktSyncServiceEpisodeContextTests {

    final class CapturedBodyState: @unchecked Sendable {
        var capturedBody: [String: Any]?
    }

    private func makeBodyCaptureSession(state: CapturedBodyState) -> URLSession {
        makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":0,"shows":0,"episodes":1}}"#.utf8))
        }
    }

    @Test func episodeContextParsesS01E01() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "S01E01")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        let seasons = shows?[0]["seasons"] as? [[String: Any]]
        #expect(seasons?.count == 1)
        #expect(seasons?[0]["number"] as? Int == 1)
        let episodes = seasons?[0]["episodes"] as? [[String: Any]]
        #expect(episodes?.count == 1)
        #expect(episodes?[0]["number"] as? Int == 1)
    }

    @Test func episodeContextParsesS12E123() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "s12e123")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        let seasons = shows?[0]["seasons"] as? [[String: Any]]
        #expect(seasons?[0]["number"] as? Int == 12)
        let episodes = seasons?[0]["episodes"] as? [[String: Any]]
        #expect(episodes?[0]["number"] as? Int == 123)
    }

    @Test func episodeContextParsesS1E1() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "S1E1")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        let seasons = shows?[0]["seasons"] as? [[String: Any]]
        #expect(seasons?[0]["number"] as? Int == 1)
        let episodes = seasons?[0]["episodes"] as? [[String: Any]]
        #expect(episodes?[0]["number"] as? Int == 1)
    }

    @Test func episodeContextParsesLowercaseS01E01() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "s01e01")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        let seasons = shows?[0]["seasons"] as? [[String: Any]]
        #expect(seasons?[0]["number"] as? Int == 1)
        let episodes = seasons?[0]["episodes"] as? [[String: Any]]
        #expect(episodes?[0]["number"] as? Int == 1)
    }

    @Test func episodeContextParsesMixedCaseS01e01() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "S01e01")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        let seasons = shows?[0]["seasons"] as? [[String: Any]]
        #expect(seasons?[0]["number"] as? Int == 1)
        let episodes = seasons?[0]["episodes"] as? [[String: Any]]
        #expect(episodes?[0]["number"] as? Int == 1)
    }

    @Test func episodeContextParsesS99E999() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "S99E999")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        let seasons = shows?[0]["seasons"] as? [[String: Any]]
        #expect(seasons?[0]["number"] as? Int == 99)
        let episodes = seasons?[0]["episodes"] as? [[String: Any]]
        #expect(episodes?[0]["number"] as? Int == 999)
    }

    @Test func episodeContextReturnsNilForNilInput() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: nil)

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        #expect(shows?[0]["seasons"] == nil)
        #expect(state.capturedBody?["episodes"] == nil)
    }

    @Test func episodeContextReturnsNilForEmptyString() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        #expect(shows?[0]["seasons"] == nil)
    }

    @Test func episodeContextReturnsNilForS01Only() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "S01")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        #expect(shows?[0]["seasons"] == nil)
    }

    @Test func episodeContextReturnsNilForE01Only() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "E01")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        #expect(shows?[0]["seasons"] == nil)
    }

    @Test func episodeContextReturnsNilForS01X01() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "S01X01")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        #expect(shows?[0]["seasons"] == nil)
    }

    @Test func episodeContextReturnsNilForPlainText() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "Season 1 Episode 1")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        #expect(shows?[0]["seasons"] == nil)
    }

    @Test func episodeContextReturnsNilForRandomString() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "abc123")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        #expect(shows?[0]["seasons"] == nil)
    }

    @Test func episodeContextParsesSubstringMatch() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "prefixS01E01suffix")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        let seasons = shows?[0]["seasons"] as? [[String: Any]]
        #expect(seasons?[0]["number"] as? Int == 1)
        let episodes = seasons?[0]["episodes"] as? [[String: Any]]
        #expect(episodes?[0]["number"] as? Int == 1)
    }

    @Test func episodeContextPrefersImdbEpisodeId() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "tt456")

        let episodes = state.capturedBody?["episodes"] as? [[String: Any]]
        #expect(episodes?.count == 1)
        let ids = episodes?[0]["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt456")
        #expect(state.capturedBody?["shows"] == nil)
    }

    @Test func episodeContextParsesS00E00() async throws {
        let state = CapturedBodyState()
        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: makeBodyCaptureSession(state: state))
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt123", type: .series, episodeId: "S00E00")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        let seasons = shows?[0]["seasons"] as? [[String: Any]]
        #expect(seasons?[0]["number"] as? Int == 0)
        let episodes = seasons?[0]["episodes"] as? [[String: Any]]
        #expect(episodes?[0]["number"] as? Int == 0)
    }
}
