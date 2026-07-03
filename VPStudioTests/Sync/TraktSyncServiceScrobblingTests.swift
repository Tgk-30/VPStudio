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

// MARK: - Scrobbling Tests

@Suite("TraktSyncService - Scrobbling")
struct TraktSyncServiceScrobblingTests {

    @Test func startScrobbleMovieSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
            var capturedMethod: String?
            var capturedBody: [String: Any]?
            var capturedHeaders: [String: String] = [:]
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            state.capturedMethod = request.httpMethod
            state.capturedHeaders["Authorization"] = request.value(forHTTPHeaderField: "Authorization")
            state.capturedHeaders["trakt-api-key"] = request.value(forHTTPHeaderField: "trakt-api-key")
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":1,"action":"start"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.startScrobble(imdbId: "tt1234567", type: .movie, progress: 25.5)

        #expect(state.capturedPath?.contains("/scrobble/start") == true)
        #expect(state.capturedMethod == "POST")
        #expect(state.capturedHeaders["Authorization"] == "Bearer token")
        #expect(state.capturedHeaders["trakt-api-key"] == "client")

        let movie = state.capturedBody?["movie"] as? [String: Any]
        #expect(movie != nil)
        let ids = movie?["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt1234567")
        #expect(state.capturedBody?["progress"] as? Double == 25.5)
    }

    @Test func startScrobbleNormalizesOMDbCompositeMediaID() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":11,"action":"start"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.startScrobble(imdbId: "movie-omdb-TT1160419", type: .movie, progress: 11.0)

        let movie = state.capturedBody?["movie"] as? [String: Any]
        let ids = movie?["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt1160419")
    }

    @Test func startScrobbleAcceptsTMDbCompositeMediaID() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":12,"action":"start"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.startScrobble(imdbId: "movie-tmdb-438631", type: .movie, progress: 12.0)

        let movie = state.capturedBody?["movie"] as? [String: Any]
        let ids = movie?["ids"] as? [String: Any]
        #expect(ids?["tmdb"] as? Int == 438_631)
        #expect(ids?["imdb"] == nil)
    }

    @Test func startScrobbleShowSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":2,"action":"start"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.startScrobble(imdbId: "tt7654321", type: .series, progress: 10.0)

        let show = state.capturedBody?["show"] as? [String: Any]
        #expect(show != nil)
        let ids = show?["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt7654321")
    }

    @Test func startScrobbleSeriesEpisodeUsesEpisodeIdentityWhenAvailable() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":22,"action":"start"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.startScrobble(
            imdbId: "tt7654321",
            type: .series,
            progress: 10.0,
            episodeId: "episode-imdb-TT1234567"
        )

        #expect(state.capturedBody?["show"] == nil)
        let episode = state.capturedBody?["episode"] as? [String: Any]
        let ids = episode?["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt1234567")
        #expect(state.capturedBody?["progress"] as? Double == 10.0)
    }

    @Test func pauseScrobbleSeriesEpisodeAcceptsTMDBEpisodeIdentity() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":23,"action":"pause"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.pauseScrobble(
            imdbId: "tt7654321",
            type: .series,
            progress: 50.0,
            episodeId: "tmdb-456"
        )

        let episode = state.capturedBody?["episode"] as? [String: Any]
        let ids = episode?["ids"] as? [String: Any]
        #expect(ids?["tmdb"] as? Int == 456)
    }

    @Test func stopScrobbleSeriesEpisodeAcceptsOMDbEpisodeIdentity() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":24,"action":"stop"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.stopScrobble(
            imdbId: "series-omdb-tt7654321",
            type: .series,
            progress: 90.0,
            episodeId: "episode-omdb-TT1234567"
        )

        #expect(state.capturedBody?["show"] == nil)
        let episode = state.capturedBody?["episode"] as? [String: Any]
        let ids = episode?["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt1234567")
    }

    @Test func pauseScrobbleSendsCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":3,"action":"pause"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.pauseScrobble(imdbId: "tt1111111", type: .movie, progress: 50.0)

        #expect(state.capturedPath?.contains("/scrobble/pause") == true)
    }

    @Test func pauseScrobbleSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":4,"action":"pause"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.pauseScrobble(imdbId: "tt2222222", type: .movie, progress: 75.5)

        #expect(state.capturedBody?["progress"] as? Double == 75.5)
    }

    @Test func pauseScrobbleNormalizesOMDbCompositeMediaID() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":12,"action":"pause"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.pauseScrobble(imdbId: "movie-omdb-TT1160419", type: .movie, progress: 42.0)

        let movie = state.capturedBody?["movie"] as? [String: Any]
        let ids = movie?["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt1160419")
    }

    @Test func stopScrobbleSendsCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":5,"action":"stop"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.stopScrobble(imdbId: "tt3333333", type: .movie, progress: 95.0)

        #expect(state.capturedPath?.contains("/scrobble/stop") == true)
    }

    @Test func stopScrobbleSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":6,"action":"stop"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.stopScrobble(imdbId: "tt4444444", type: .movie, progress: 100.0)

        let movie = state.capturedBody?["movie"] as? [String: Any]
        let ids = movie?["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt4444444")
        #expect(state.capturedBody?["progress"] as? Double == 100.0)
    }

    @Test func stopScrobbleNormalizesOMDbCompositeMediaID() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":13,"action":"stop"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.stopScrobble(imdbId: "movie-omdb-TT1160419", type: .movie, progress: 96.0)

        let movie = state.capturedBody?["movie"] as? [String: Any]
        let ids = movie?["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt1160419")
    }

    @Test func scrobbleThrowsNotConnectedWithoutToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")

        do {
            try await service.startScrobble(imdbId: "tt5555555", type: .movie, progress: 25.0)
            Issue.record("Expected TraktError.notConnected")
        } catch let error as TraktError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func pauseScrobbleThrowsNotConnectedWithoutToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")

        do {
            try await service.pauseScrobble(imdbId: "tt6666666", type: .movie, progress: 50.0)
            Issue.record("Expected TraktError.notConnected")
        } catch let error as TraktError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func stopScrobbleThrowsNotConnectedWithoutToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")

        do {
            try await service.stopScrobble(imdbId: "tt7777777", type: .movie, progress: 90.0)
            Issue.record("Expected TraktError.notConnected")
        } catch let error as TraktError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func scrobbleHandles500Error() async {
        let session = makeTraktStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)

        do {
            try await service.startScrobble(imdbId: "tt8888888", type: .movie, progress: 25.0)
            Issue.record("Expected TraktError.httpError(500)")
        } catch let error as TraktError {
            if case .httpError(500) = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func scrobbleHandles401Error() async {
        let session = makeTraktStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)

        do {
            try await service.pauseScrobble(imdbId: "tt9999999", type: .movie, progress: 50.0)
            Issue.record("Expected TraktError.unauthorized")
        } catch let error as TraktError {
            if case .unauthorized = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func startScrobble401TriggersRefreshAndRetry() async throws {
        final class State: @unchecked Sendable {
            var requestCount = 0
        }
        let state = State()

        let session = makeTraktStubSession { request in
            state.requestCount += 1
            let path = request.url?.path ?? ""

            if path.hasSuffix("/oauth/token") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"access_token":"new-token","refresh_token":"new-refresh"}"#.utf8))
            }

            if state.requestCount == 1 {
                let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"id":10,"action":"start"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "stale-token", refresh: "valid-refresh")
        try await service.startScrobble(imdbId: "tt0000001", type: .movie, progress: 25.0)

        #expect(state.requestCount == 3)
    }
}
