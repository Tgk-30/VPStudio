import Testing
import Foundation
@testable import VPStudio

// MARK: - Helpers

private func makeSimklStubSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    URLProtocolHarness.makeSession(handler: handler)
}

private final class SimklRawURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handlers: [String: (URLRequest) throws -> (URLResponse, Data)] = [:]
    static let lock = NSLock()
    static let handlerHeader = "X-VPStudio-Simkl-Raw-Harness-ID"

    static func makeSession(
        handler: @escaping (URLRequest) throws -> (URLResponse, Data)
    ) -> URLSession {
        let id = UUID().uuidString
        lock.lock()
        handlers[id] = handler
        lock.unlock()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SimklRawURLProtocolStub.self]
        config.httpAdditionalHeaders = [handlerHeader: id]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: handlerHeader) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handlerID = request.value(forHTTPHeaderField: Self.handlerHeader) else {
            client?.urlProtocol(self, didFailWithError: URLProtocolHarnessError.missingHandler)
            return
        }

        Self.lock.lock()
        let handler = Self.handlers[handlerID]
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLProtocolHarnessError.missingHandler)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

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

private func parseFormBody(_ data: Data?) -> [String: String]? {
    guard let data, let string = String(data: data, encoding: .utf8) else { return nil }
    var components = URLComponents()
    components.query = string
    return components.queryItems?.reduce(into: [:]) { $0[$1.name] = $1.value }
}

// MARK: - Authorization URL

@Suite("SimklSyncService - Authorization URL")
struct SimklAuthorizationURLTests {

    @Test func authorizationURLIncludesRequiredQueryItems() async throws {
        let service = SimklSyncService(clientId: "test-client-auth")
        let authStart = await service.beginAuthorization()
        let start = try #require(authStart)
        let components = URLComponents(url: start.url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        #expect(items.first(where: { $0.name == "response_type" })?.value == "code")
        #expect(items.first(where: { $0.name == "client_id" })?.value == "test-client-auth")
        #expect(items.first(where: { $0.name == "redirect_uri" })?.value == "urn:ietf:wg:oauth:2.0:oob")
        #expect(items.first(where: { $0.name == "state" })?.value == start.state)
    }

    @Test func authorizationURLIncludesPKCEParameters() async throws {
        let service = SimklSyncService(clientId: "test-client-pkce")
        let authStart = await service.beginAuthorization()
        let start = try #require(authStart)
        let components = URLComponents(url: start.url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        #expect(items.first(where: { $0.name == "code_challenge" })?.value?.isEmpty == false)
        #expect(items.first(where: { $0.name == "code_challenge_method" })?.value == "S256")
    }

    @Test func authorizationURLUsesURLSafePKCEValuesAndRotatesSessions() async throws {
        let service = SimklSyncService(clientId: "test-client-pkce-shape")

        let first = try #require(await service.beginAuthorization())
        let second = try #require(await service.beginAuthorization())

        let firstItems = URLComponents(url: first.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let secondItems = URLComponents(url: second.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let firstChallenge = try #require(firstItems.first(where: { $0.name == "code_challenge" })?.value)
        let secondChallenge = try #require(secondItems.first(where: { $0.name == "code_challenge" })?.value)

        #expect(first.state != second.state)
        #expect(firstChallenge != secondChallenge)
        #expect(first.state.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil)
        #expect(firstChallenge.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil)
        #expect(!first.state.contains("="))
        #expect(!firstChallenge.contains("="))
        #expect(firstChallenge.count == 43)
        #expect(secondItems.first(where: { $0.name == "state" })?.value == second.state)
        #expect(secondItems.first(where: { $0.name == "code_challenge_method" })?.value == "S256")
    }

    @Test func authorizationURLReturnsNilForEmptyClientId() async {
        let service = SimklSyncService(clientId: "   ")
        let beginResult = await service.beginAuthorization()
        #expect(beginResult == nil)
        let authURL = await service.getAuthorizationURL()
        #expect(authURL == nil)
    }
}

// MARK: - exchangeAuthorizationCode

@Suite("SimklSyncService - exchangeAuthorizationCode")
struct SimklExchangeCodeTests {

    @Test func sendsCorrectFormParametersIncludingCodeVerifier() async throws {
        let service = SimklSyncService(clientId: "test-client-exchange", clientSecret: "secret")
        let authStart = await service.beginAuthorization()
        let start = try #require(authStart)

        final class CaptureState: @unchecked Sendable {
            var form: [String: String]?
            var path: String?
        }
        let state = CaptureState()

        let session = makeSimklStubSession { request in
            state.path = request.url?.path
            state.form = parseFormBody(request.httpBody ?? readStream(request.httpBodyStream))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"access_token":"new-access","refresh_token":"new-refresh"}"#
            return (response, Data(body.utf8))
        }

        let networkService = SimklSyncService(clientId: "test-client-exchange", clientSecret: "secret", session: session)
        _ = try await networkService.exchangeAuthorizationCode("auth-code", returnedState: start.state)

        #expect(state.path?.hasSuffix("/oauth/token") == true)
        #expect(state.form?["grant_type"] == "authorization_code")
        #expect(state.form?["client_id"] == "test-client-exchange")
        #expect(state.form?["client_secret"] == "secret")
        #expect(state.form?["code"] == "auth-code")
        #expect(state.form?["redirect_uri"] == "urn:ietf:wg:oauth:2.0:oob")
        #expect(state.form?["code_verifier"]?.isEmpty == false)
    }

    @Test func throwsInvalidAuthorizationCodeForEmptyCode() async {
        let service = SimklSyncService(clientId: "test-client-empty-code", clientSecret: "secret")
        do {
            _ = try await service.exchangeAuthorizationCode("   ")
            Issue.record("Expected SimklError.invalidAuthorizationCode")
        } catch let error as SimklError {
            if case .invalidAuthorizationCode = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func throwsMissingClientSecret() async throws {
        let service = SimklSyncService(clientId: "test-client-missing-secret", clientSecret: "   ")
        let authStart = await service.beginAuthorization()
        let start = try #require(authStart)
        do {
            _ = try await service.exchangeAuthorizationCode("code", returnedState: start.state)
            Issue.record("Expected SimklError.missingClientSecret")
        } catch let error as SimklError {
            if case .missingClientSecret = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func throwsSessionMissingWhenNotStarted() async {
        let service = SimklSyncService(clientId: "test-client-no-session", clientSecret: "secret")
        do {
            _ = try await service.exchangeAuthorizationCode("code", returnedState: "state")
            Issue.record("Expected SimklError.authorizationSessionMissing")
        } catch let error as SimklError {
            if case .authorizationSessionMissing = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func throwsStateMismatchForWrongState() async throws {
        let service = SimklSyncService(clientId: "test-client-state", clientSecret: "secret")
        _ = await service.beginAuthorization()
        do {
            _ = try await service.exchangeAuthorizationCode("code", returnedState: "wrong-state")
            Issue.record("Expected SimklError.authorizationStateMismatch")
        } catch let error as SimklError {
            if case .authorizationStateMismatch = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func storesTokensAndClearsSessionOnSuccess() async throws {
        let service = SimklSyncService(clientId: "test-client-store", clientSecret: "secret")
        let authStart = await service.beginAuthorization()
        let start = try #require(authStart)

        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"access_token":"acc-tok","refresh_token":"ref-tok"}"#
            return (response, Data(body.utf8))
        }

        let networkService = SimklSyncService(clientId: "test-client-store", clientSecret: "secret", session: session)
        let result = try await networkService.exchangeAuthorizationCode("code", returnedState: start.state)

        #expect(result.accessToken == "acc-tok")
        #expect(result.refreshToken == "ref-tok")
        let tokens = await networkService.currentTokens()
        #expect(tokens.access == "acc-tok")
        #expect(tokens.refresh == "ref-tok")
    }

    @Test func callsOnTokensRefreshedWithNewTokens() async throws {
        let service = SimklSyncService(clientId: "test-client-cb", clientSecret: "secret")
        let authStart = await service.beginAuthorization()
        let start = try #require(authStart)

        final class CallbackState: @unchecked Sendable {
            var access: String?
            var refresh: String?
        }
        let callback = CallbackState()

        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"access_token":"cb-access","refresh_token":"cb-refresh"}"#
            return (response, Data(body.utf8))
        }

        let networkService = SimklSyncService(
            clientId: "test-client-cb",
            clientSecret: "secret",
            session: session,
            onTokensRefreshed: { access, refresh in
                callback.access = access
                callback.refresh = refresh
            }
        )

        _ = try await networkService.exchangeAuthorizationCode("code", returnedState: start.state)
        #expect(callback.access == "cb-access")
        #expect(callback.refresh == "cb-refresh")
    }

    @Test func throwsInvalidResponseForEmptyAccessToken() async throws {
        let service = SimklSyncService(clientId: "test-client-empty-acc", clientSecret: "secret")
        let authStart = await service.beginAuthorization()
        let start = try #require(authStart)

        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"access_token":"   ","refresh_token":"ref"}"#
            return (response, Data(body.utf8))
        }

        let networkService = SimklSyncService(clientId: "test-client-empty-acc", clientSecret: "secret", session: session)
        do {
            _ = try await networkService.exchangeAuthorizationCode("code", returnedState: start.state)
            Issue.record("Expected SimklError.invalidAuthorizationResponse")
        } catch let error as SimklError {
            if case .invalidAuthorizationResponse = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch { Issue.record("Unexpected error: \(error)") }
    }
}

// MARK: - Token Refresh

@Suite("SimklSyncService - Token Refresh")
struct SimklTokenRefreshTests {

    @Test func autoRefreshesWhenAccessTokenMissingButRefreshTokenPresent() async throws {
        final class CaptureState: @unchecked Sendable {
            var requestCount = 0
        }
        let state = CaptureState()

        let session = makeSimklStubSession { request in
            state.requestCount += 1
            let path = request.url?.path ?? ""

            if path.hasSuffix("/oauth/token") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"access_token":"refreshed-access","refresh_token":"refreshed-refresh"}"#
                return (response, Data(body.utf8))
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"movies":[],"shows":[]}"#
            return (response, Data(body.utf8))
        }

        let service = SimklSyncService(clientId: "test-client-auto-refresh", clientSecret: "secret", session: session)
        await service.setTokens(access: "", refresh: "valid-refresh")
        let result = try await service.getWatchlist()

        #expect(state.requestCount == 2)
        #expect(result.movies != nil)
    }

    @Test func refreshSendsCorrectFormParameters() async throws {
        final class CaptureState: @unchecked Sendable {
            var form: [String: String]?
        }
        let state = CaptureState()

        let session = makeSimklStubSession { request in
            if request.url?.path.hasSuffix("/oauth/token") == true {
                state.form = parseFormBody(request.httpBody ?? readStream(request.httpBodyStream))
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"access_token":"new-access","refresh_token":"new-refresh"}"#
                return (response, Data(body.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(clientId: "test-client-refresh-form", clientSecret: "secret", session: session)
        await service.setTokens(access: "", refresh: "my-refresh-token")
        _ = try await service.getWatchlist()

        #expect(state.form?["grant_type"] == "refresh_token")
        #expect(state.form?["client_id"] == "test-client-refresh-form")
        #expect(state.form?["client_secret"] == "secret")
        #expect(state.form?["redirect_uri"] == "urn:ietf:wg:oauth:2.0:oob")
        #expect(state.form?["refresh_token"] == "my-refresh-token")
    }

    @Test func refreshUpdatesAccessToken() async throws {
        let session = makeSimklStubSession { request in
            if request.url?.path.hasSuffix("/oauth/token") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"access_token":"updated-access"}"#.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(clientId: "test-client-upd-acc", clientSecret: "secret", session: session)
        await service.setTokens(access: "", refresh: "refresh")
        _ = try await service.getWatchlist()

        let tokens = await service.currentTokens()
        #expect(tokens.access == "updated-access")
    }

    @Test func refreshUpdatesRefreshTokenWhenNewOneProvided() async throws {
        let session = makeSimklStubSession { request in
            if request.url?.path.hasSuffix("/oauth/token") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"access_token":"acc","refresh_token":"new-refresh"}"#.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(clientId: "test-client-upd-ref", clientSecret: "secret", session: session)
        await service.setTokens(access: "", refresh: "old-refresh")
        _ = try await service.getWatchlist()

        let tokens = await service.currentTokens()
        #expect(tokens.refresh == "new-refresh")
    }

    @Test func refreshCallsOnTokensRefreshed() async throws {
        final class CallbackState: @unchecked Sendable {
            var access: String?
            var refresh: String?
        }
        let callback = CallbackState()

        let session = makeSimklStubSession { request in
            if request.url?.path.hasSuffix("/oauth/token") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"access_token":"cb-acc","refresh_token":"cb-ref"}"#.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(
            clientId: "test-client-refresh-cb",
            clientSecret: "secret",
            session: session,
            onTokensRefreshed: { access, refresh in
                callback.access = access
                callback.refresh = refresh
            }
        )
        await service.setTokens(access: "", refresh: "refresh")
        _ = try await service.getWatchlist()

        #expect(callback.access == "cb-acc")
        #expect(callback.refresh == "cb-ref")
    }

    @Test func refreshThrowsMissingClientSecret() async {
        let session = makeSimklStubSession { request in
            Issue.record("Should not reach network with missing client secret: \(request)")
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = SimklSyncService(clientId: "test-client-refresh-secret", clientSecret: "   ", session: session)
        await service.setTokens(access: "", refresh: "refresh")
        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.missingClientSecret")
        } catch let error as SimklError {
            if case .missingClientSecret = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func refreshThrowsNotConnectedWhenNoRefreshToken() async {
        let session = makeSimklStubSession { request in
            Issue.record("Should not reach network without refresh token: \(request)")
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = SimklSyncService(clientId: "test-client-no-refresh", clientSecret: "secret", session: session)
        await service.setTokens(access: "", refresh: nil)
        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.notConnected")
        } catch let error as SimklError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch { Issue.record("Unexpected error: \(error)") }
    }
}

// MARK: - Authenticated Request Headers

@Suite("SimklSyncService - Authenticated Request Headers")
struct SimklAuthenticatedRequestTests {

    @Test func getWatchlistInjectsBearerToken() async throws {
        final class CaptureState: @unchecked Sendable {
            var authHeader: String?
            var apiKeyHeader: String?
        }
        let state = CaptureState()

        let session = makeSimklStubSession { request in
            state.authHeader = request.value(forHTTPHeaderField: "Authorization")
            state.apiKeyHeader = request.value(forHTTPHeaderField: "simkl-api-key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(clientId: "test-client-bearer", clientSecret: "secret", session: session)
        await service.setTokens(access: "my-token", refresh: nil)
        _ = try await service.getWatchlist()

        #expect(state.authHeader == "Bearer my-token")
        #expect(state.apiKeyHeader == "test-client-bearer")
    }

    @Test func addToListInjectsBearerToken() async throws {
        final class CaptureState: @unchecked Sendable {
            var authHeader: String?
        }
        let state = CaptureState()

        let session = makeSimklStubSession { request in
            state.authHeader = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1}}"#.utf8))
        }

        let service = SimklSyncService(clientId: "test-client-add", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToList(imdbId: "tt123", type: .movie)

        #expect(state.authHeader == "Bearer token")
    }

    @Test func markWatchedInjectsBearerToken() async throws {
        final class CaptureState: @unchecked Sendable {
            var authHeader: String?
        }
        let state = CaptureState()

        let session = makeSimklStubSession { request in
            state.authHeader = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1}}"#.utf8))
        }

        let service = SimklSyncService(clientId: "test-client-mark", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.markWatched(imdbId: "tt123", type: .movie)

        #expect(state.authHeader == "Bearer token")
    }

    @Test func getWatchlistThrowsNotConnectedWhenNoTokens() async {
        let service = SimklSyncService(clientId: "test-client-not-conn", clientSecret: "secret")
        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.notConnected")
        } catch let error as SimklError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch { Issue.record("Unexpected error: \(error)") }
    }
}

// MARK: - URL Construction and Response Validation

@Suite("SimklSyncService - URL Construction and Response Validation")
struct SimklURLConstructionAndResponseValidationTests {

    @Test func getWatchlistJoinsBasePathWithTrailingSlashWithoutDroppingQuery() async throws {
        final class CaptureState: @unchecked Sendable {
            var url: URL?
        }
        let state = CaptureState()
        let session = makeSimklStubSession { request in
            state.url = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(
            clientId: "test-client-base-path-trailing",
            clientSecret: "secret",
            baseURL: " https://proxy.example/simkl/ ",
            session: session
        )
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getWatchlist()

        #expect(state.url?.scheme == "https")
        #expect(state.url?.host == "proxy.example")
        #expect(URLComponents(url: try #require(state.url), resolvingAgainstBaseURL: false)?
            .percentEncodedPath == "/simkl/sync/all-items/")
        #expect(URLComponents(url: try #require(state.url), resolvingAgainstBaseURL: false)?
            .queryItems?
            .contains(URLQueryItem(name: "episode_watched_at", value: "yes")) == true)
    }

    @Test func getWatchlistJoinsBasePathWithoutTrailingSlash() async throws {
        final class CaptureState: @unchecked Sendable {
            var percentEncodedPath: String?
        }
        let state = CaptureState()
        let session = makeSimklStubSession { request in
            state.percentEncodedPath = request.url.flatMap {
                URLComponents(url: $0, resolvingAgainstBaseURL: false)?.percentEncodedPath
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(
            clientId: "test-client-base-path",
            clientSecret: "secret",
            baseURL: "https://proxy.example/simkl",
            session: session
        )
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getWatchlist()

        #expect(state.percentEncodedPath == "/simkl/sync/all-items/")
    }

    @Test(arguments: [
        "",
        "   ",
        "ftp://api.simkl.com",
        "https://api.simkl.com/[",
        "https://api.simkl.com/]",
        "https:///missing-host",
    ])
    func invalidBaseURLsFailBeforeNetwork(baseURL: String) async {
        let session = makeSimklStubSession { request in
            Issue.record("Should not reach network for invalid base URL: \(request)")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(
            clientId: "test-client-invalid-base",
            clientSecret: "secret",
            baseURL: baseURL,
            session: session
        )
        await service.setTokens(access: "token", refresh: nil)

        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.invalidURL")
        } catch let error as SimklError {
            if case .invalidURL = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func nonHTTPAuthenticatedResponseMapsToHTTPZeroError() async {
        let session = SimklRawURLProtocolStub.makeSession { request in
            let response = URLResponse(
                url: request.url!,
                mimeType: "application/json",
                expectedContentLength: 0,
                textEncodingName: nil
            )
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(
            clientId: "test-client-non-http",
            clientSecret: "secret",
            session: session
        )
        await service.setTokens(access: "token", refresh: nil)

        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.httpError(0)")
        } catch let error as SimklError {
            if case .httpError(0) = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

// MARK: - 401 Refresh and Retry

@Suite("SimklSyncService - 401 Refresh and Retry")
struct Simkl401RefreshTests {

    @Test func getWatchlist401TriggersRefreshAndRetry() async throws {
        final class CaptureState: @unchecked Sendable {
            var requestCount = 0
        }
        let state = CaptureState()

        let session = makeSimklStubSession { request in
            state.requestCount += 1
            if request.url?.path.hasSuffix("/oauth/token") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"access_token":"new-token"}"#.utf8))
            }
            if state.requestCount == 1 {
                let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(clientId: "test-client-401", clientSecret: "secret", session: session)
        await service.setTokens(access: "expired", refresh: "valid-refresh")
        let result = try await service.getWatchlist()

        #expect(state.requestCount == 3)
        #expect(result.movies != nil)
    }

    @Test func retryUsesNewAccessToken() async throws {
        final class CaptureState: @unchecked Sendable {
            var authHeaders: [String?] = []
            var requestCount = 0
        }
        let state = CaptureState()

        let session = makeSimklStubSession { request in
            state.requestCount += 1
            if request.url?.path.hasSuffix("/oauth/token") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"access_token":"fresh-token"}"#.utf8))
            }
            state.authHeaders.append(request.value(forHTTPHeaderField: "Authorization"))
            if state.requestCount == 1 {
                let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(clientId: "test-client-retry-tok", clientSecret: "secret", session: session)
        await service.setTokens(access: "old-token", refresh: "valid-refresh")
        _ = try await service.getWatchlist()

        #expect(state.authHeaders.count == 2)
        #expect(state.authHeaders[0] == "Bearer old-token")
        #expect(state.authHeaders[1] == "Bearer fresh-token")
    }

    @Test func double401ThrowsUnauthorized() async {
        let session = makeSimklStubSession { request in
            if request.url?.path.hasSuffix("/oauth/token") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"access_token":"token"}"#.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = SimklSyncService(clientId: "test-client-dbl-401", clientSecret: "secret", session: session)
        await service.setTokens(access: "expired", refresh: "valid-refresh")
        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.unauthorized")
        } catch let error as SimklError {
            if case .unauthorized = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func test401WithoutRefreshTokenThrowsUnauthorized() async {
        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = SimklSyncService(clientId: "test-client-401-no-ref", clientSecret: "secret", session: session)
        await service.setTokens(access: "expired", refresh: nil)
        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.unauthorized")
        } catch let error as SimklError {
            if case .unauthorized = error { /* OK */ }
            else { Issue.record("Unexpected SimklError: \(error)") }
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func getWatchlist500ThrowsHttpError() async {
        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = SimklSyncService(clientId: "test-client-500", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.httpError")
        } catch let error as SimklError {
            if case .httpError(let code) = error {
                #expect(code == 500)
            } else {
                Issue.record("Unexpected SimklError: \(error)")
            }
        } catch { Issue.record("Unexpected error: \(error)") }
    }
}

// MARK: - Token Store

@Suite("SimklSyncService - Token Store")
struct SimklTokenStoreTests {

    @Test func currentTokensReflectExchange() async throws {
        let service = SimklSyncService(clientId: "test-client-tok-ex", clientSecret: "secret")
        let authStart = await service.beginAuthorization()
        let start = try #require(authStart)

        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"access_token":"ex-acc","refresh_token":"ex-ref"}"#.utf8))
        }

        let networkService = SimklSyncService(clientId: "test-client-tok-ex", clientSecret: "secret", session: session)
        _ = try await networkService.exchangeAuthorizationCode("code", returnedState: start.state)

        let tokens = await networkService.currentTokens()
        #expect(tokens.access == "ex-acc")
        #expect(tokens.refresh == "ex-ref")
    }

    @Test func currentTokensReflectRefresh() async throws {
        let session = makeSimklStubSession { request in
            if request.url?.path.hasSuffix("/oauth/token") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"access_token":"ref-acc","refresh_token":"ref-ref"}"#.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(clientId: "test-client-tok-ref", clientSecret: "secret", session: session)
        await service.setTokens(access: "", refresh: "old")
        _ = try await service.getWatchlist()

        let tokens = await service.currentTokens()
        #expect(tokens.access == "ref-acc")
        #expect(tokens.refresh == "ref-ref")
    }
}
