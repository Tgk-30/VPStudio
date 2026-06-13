import Testing
import Foundation
@testable import VPStudio

// MARK: - Stub Session Helper

private func makeTraktStubSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    URLProtocolHarness.makeSession(handler: handler)
}

// MARK: - Stream Reading Helper

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

// MARK: - Authorization URL Tests

@Suite("TraktSyncService - Authorization URL")
struct TraktSyncServiceAuthorizationURLTests {

    @Test func getAuthorizationURLReturnsValidURL() async {
        let service = TraktSyncService(clientId: "test-client", clientSecret: "test-secret")
        let url = await service.getAuthorizationURL()

        #expect(url != nil)
        #expect(url?.scheme == "https")
        #expect(url?.host == "trakt.tv")
    }

    @Test func getAuthorizationURLContainsRequiredQueryItems() async {
        let service = TraktSyncService(clientId: "test-client-query", clientSecret: "test-secret")
        let url = await service.getAuthorizationURL()
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        #expect(items.first(where: { $0.name == "response_type" })?.value == "code")
        #expect(items.first(where: { $0.name == "client_id" })?.value == "test-client-query")
        #expect(items.first(where: { $0.name == "redirect_uri" })?.value == "urn:ietf:wg:oauth:2.0:oob")
        #expect(items.first(where: { $0.name == "code_challenge_method" })?.value == "S256")
        #expect(items.first(where: { $0.name == "code_challenge" })?.value?.isEmpty == false)
        #expect(items.first(where: { $0.name == "state" })?.value?.isEmpty == false)
    }

    @Test func getAuthorizationURLUsesURLSafePKCEValuesAndRotatesSessions() async throws {
        let service = TraktSyncService(clientId: "test-client-pkce", clientSecret: "test-secret")

        let firstURL = try #require(await service.getAuthorizationURL())
        let secondURL = try #require(await service.getAuthorizationURL())

        let firstItems = URLComponents(url: firstURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let secondItems = URLComponents(url: secondURL, resolvingAgainstBaseURL: false)?.queryItems ?? []

        let firstState = try #require(firstItems.first(where: { $0.name == "state" })?.value)
        let secondState = try #require(secondItems.first(where: { $0.name == "state" })?.value)
        let firstChallenge = try #require(firstItems.first(where: { $0.name == "code_challenge" })?.value)
        let secondChallenge = try #require(secondItems.first(where: { $0.name == "code_challenge" })?.value)

        #expect(firstState != secondState)
        #expect(firstChallenge != secondChallenge)
        #expect(firstState.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil)
        #expect(firstChallenge.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil)
        #expect(!firstState.contains("="))
        #expect(!firstChallenge.contains("="))
        #expect(firstChallenge.count == 43)
        #expect(firstItems.first(where: { $0.name == "code_challenge_method" })?.value == "S256")
    }

    @Test func getAuthorizationURLPathIsOAuthAuthorize() async {
        let service = TraktSyncService(clientId: "test-client-path", clientSecret: "test-secret")
        let url = await service.getAuthorizationURL()

        #expect(url?.path == "/oauth/authorize")
    }
}

// MARK: - Exchange Code Tests

@Suite("TraktSyncService - Exchange Code")
struct TraktSyncServiceExchangeCodeTests {

    @Test func exchangeCodeSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
            var capturedMethod: String?
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            state.capturedMethod = request.httpMethod
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"access_token":"test-access","refresh_token":"test-refresh","token_type":"Bearer","expires_in":7776000,"created_at":1600000000}
            """
            return (response, Data(body.utf8))
        }

        let service = TraktSyncService(clientId: "test-client-exchange", clientSecret: "test-secret", session: session)
        _ = await service.getAuthorizationURL()
        try await service.exchangeCode("auth-code-123")

        #expect(state.capturedPath?.hasSuffix("/oauth/token") == true)
        #expect(state.capturedMethod == "POST")
        #expect(state.capturedBody?["code"] as? String == "auth-code-123")
        #expect(state.capturedBody?["client_id"] as? String == "test-client-exchange")
        #expect(state.capturedBody?["client_secret"] as? String == "test-secret")
        #expect(state.capturedBody?["redirect_uri"] as? String == "urn:ietf:wg:oauth:2.0:oob")
        #expect(state.capturedBody?["grant_type"] as? String == "authorization_code")
        #expect((state.capturedBody?["code_verifier"] as? String)?.isEmpty == false)
    }

    @Test func exchangeCodeStoresTokensOnSuccess() async throws {
        let session = makeTraktStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"access_token":"new-access","refresh_token":"new-refresh"}"#
            return (response, Data(body.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        _ = await service.getAuthorizationURL()
        try await service.exchangeCode("code")

        let tokens = await service.currentTokens()
        #expect(tokens.access == "new-access")
        #expect(tokens.refresh == "new-refresh")
    }

    @Test func exchangeCodeCallsOnTokensRefreshed() async throws {
        final class CallbackState: @unchecked Sendable {
            var access: String?
            var refresh: String?
        }
        let callback = CallbackState()

        let session = makeTraktStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"access_token":"cb-access","refresh_token":"cb-refresh"}"#.utf8))
        }

        let service = TraktSyncService(
            clientId: "client",
            clientSecret: "secret",
            session: session,
            onTokensRefreshed: { access, refresh in
                callback.access = access
                callback.refresh = refresh
            }
        )

        _ = await service.getAuthorizationURL()
        try await service.exchangeCode("code")

        #expect(callback.access == "cb-access")
        #expect(callback.refresh == "cb-refresh")
    }

    @Test func exchangeCodeTrimsWhitespace() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"access_token":"token","refresh_token":"refresh"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        _ = await service.getAuthorizationURL()
        try await service.exchangeCode("  whitespace-code  ")

        #expect(state.capturedBody?["code"] as? String == "whitespace-code")
    }

    @Test func exchangeCodeThrowsNotConnectedWithoutTokenSet() async {
        let service = TraktSyncService(clientId: "client-missing-session", clientSecret: "secret")

        do {
            try await service.exchangeCode("code-without-session")
            Issue.record("Expected TraktError.authorizationSessionMissing")
        } catch let error as TraktError {
            if case .authorizationSessionMissing = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func exchangeCodeThrowsStateMismatchWithWrongState() async {
        let service = TraktSyncService(clientId: "client-state", clientSecret: "secret")
        _ = await service.getAuthorizationURL()

        do {
            try await service.exchangeCode("code", returnedState: "wrong-state")
            Issue.record("Expected TraktError.authorizationStateMismatch")
        } catch let error as TraktError {
            if case .authorizationStateMismatch = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func exchangeCodeThrowsUnauthorizedOn401() async {
        let session = makeTraktStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        _ = await service.getAuthorizationURL()

        do {
            try await service.exchangeCode("code")
            Issue.record("Expected TraktError.unauthorized")
        } catch let error as TraktError {
            if case .unauthorized = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func exchangeCodeThrowsHttpErrorOn500() async {
        let session = makeTraktStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        _ = await service.getAuthorizationURL()

        do {
            try await service.exchangeCode("code")
            Issue.record("Expected TraktError.httpError(500)")
        } catch let error as TraktError {
            if case .httpError(500) = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }
}

// MARK: - Token Management Tests

@Suite("TraktSyncService - Token Management")
struct TraktSyncServiceTokenManagementTests {

    @Test func setTokensStoresAccessToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")
        await service.setTokens(access: "my-access", refresh: "my-refresh")

        let tokens = await service.currentTokens()
        #expect(tokens.access == "my-access")
        #expect(tokens.refresh == "my-refresh")
    }

    @Test func setTokensStoresOnlyAccessToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")
        await service.setTokens(access: "only-access", refresh: nil)

        let tokens = await service.currentTokens()
        #expect(tokens.access == "only-access")
        #expect(tokens.refresh == nil)
    }

    @Test func refreshAccessTokenSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var refreshPath: String?
            var refreshMethod: String?
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if request.url?.path.hasSuffix("/oauth/token") == true {
                state.refreshPath = request.url?.path
                state.refreshMethod = request.httpMethod
                if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                    state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
                }
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"access_token":"refreshed-token","refresh_token":"refreshed-refresh"}"#
                return (response, Data(body.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "expired", refresh: "valid-refresh")
        _ = try await service.getWatchlist(type: .movie)

        #expect(state.refreshPath?.hasSuffix("/oauth/token") == true)
        #expect(state.refreshMethod == "POST")
        #expect(state.capturedBody?["refresh_token"] as? String == "valid-refresh")
        #expect(state.capturedBody?["grant_type"] as? String == "refresh_token")
    }

    @Test func refreshUpdatesAccessToken() async throws {
        let session = makeTraktStubSession { request in
            if request.url?.path.hasSuffix("/oauth/token") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"access_token":"updated-access","refresh_token":"updated-refresh"}"#.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "expired", refresh: "valid-refresh")
        _ = try await service.getWatchlist(type: .movie)

        let tokens = await service.currentTokens()
        #expect(tokens.access == "updated-access")
        #expect(tokens.refresh == "updated-refresh")
    }

    @Test func refreshCallsOnTokensRefreshed() async throws {
        final class CallbackState: @unchecked Sendable {
            var access: String?
            var refresh: String?
            var callCount = 0
        }
        let callback = CallbackState()

        let session = makeTraktStubSession { request in
            if request.url?.path.hasSuffix("/oauth/token") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"access_token":"cb-acc","refresh_token":"cb-ref"}"#.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(
            clientId: "client",
            clientSecret: "secret",
            session: session,
            onTokensRefreshed: { access, refresh in
                callback.access = access
                callback.refresh = refresh
                callback.callCount += 1
            }
        )
        await service.setTokens(access: "expired", refresh: "valid-refresh")
        _ = try await service.getWatchlist(type: .movie)

        #expect(callback.callCount == 1)
        #expect(callback.access == "cb-acc")
        #expect(callback.refresh == "cb-ref")
    }

    @Test func refreshThrowsUnauthorizedWithoutRefreshToken() async {
        let session = makeTraktStubSession { request in
            Issue.record("Should not reach network without refresh token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "expired", refresh: nil)

        do {
            _ = try await service.getWatchlist(type: .movie)
            Issue.record("Expected TraktError.unauthorized")
        } catch let error as TraktError {
            if case .unauthorized = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func refreshThrowsNotConnectedWhenNoTokens() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")

        do {
            _ = try await service.getWatchlist(type: .movie)
            Issue.record("Expected TraktError.notConnected")
        } catch let error as TraktError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }
}

// MARK: - API Key Header Tests

@Suite("TraktSyncService - API Key Header")
struct TraktSyncServiceAPIKeyHeaderTests {

    @Test func allAuthenticatedRequestsIncludeAPIKey() async throws {
        final class CapturedState: @unchecked Sendable {
            var apiKeys: [String?] = []
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.apiKeys.append(request.value(forHTTPHeaderField: "trakt-api-key"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "my-api-key", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getWatchlist(type: .movie)
        _ = try await service.getHistory(type: .movie)
        _ = try await service.getRatings(type: .movie)

        for apiKey in state.apiKeys {
            #expect(apiKey == "my-api-key")
        }
    }

    @Test func allAuthenticatedRequestsIncludeTraktAPIVersion() async throws {
        final class CapturedState: @unchecked Sendable {
            var versions: [String?] = []
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.versions.append(request.value(forHTTPHeaderField: "trakt-api-version"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getWatchlist(type: .movie)

        #expect(state.versions.allSatisfy { $0 == "2" })
    }

    @Test func bearerTokenFormatIsCorrect() async throws {
        final class CapturedState: @unchecked Sendable {
            var authHeaders: [String?] = []
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.authHeaders.append(request.value(forHTTPHeaderField: "Authorization"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "my-bearer-token", refresh: nil)
        _ = try await service.getWatchlist(type: .movie)

        #expect(state.authHeaders.first == "Bearer my-bearer-token")
    }
}
