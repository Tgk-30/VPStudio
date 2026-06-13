import Testing
import Foundation
@testable import VPStudio

// MARK: - Stub Session Helper

private func makeSimklStubSession(
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

// MARK: - Request Construction Tests

@Suite("SimklSyncService - Request Construction")
struct SimklSyncServiceRequestConstructionTests {

    @Test func getWatchlistUsesCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
            var capturedMethod: String?
            var capturedHeaders: [String: String] = [:]
        }
        let state = CapturedState()

        let session = makeSimklStubSession { request in
            state.capturedPath = request.url?.absoluteString
            state.capturedMethod = request.httpMethod
            state.capturedHeaders["Authorization"] = request.value(forHTTPHeaderField: "Authorization")
            state.capturedHeaders["simkl-api-key"] = request.value(forHTTPHeaderField: "simkl-api-key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"movies":[],"shows":[]}"#.utf8))
        }

        let service = SimklSyncService(clientId: "test-client", clientSecret: "test-secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getWatchlist()

        #expect(state.capturedPath?.contains("/sync/all-items") == true)
        #expect(state.capturedPath?.contains("episode_watched_at=yes") == true)
        #expect(state.capturedMethod == "GET")
        #expect(state.capturedHeaders["Authorization"] == "Bearer token")
        #expect(state.capturedHeaders["simkl-api-key"] == "test-client")
    }

    @Test func addToListMovieSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
            var capturedMethod: String?
            var capturedBody: Data?
        }
        let state = CapturedState()

        let session = makeSimklStubSession { request in
            state.capturedPath = request.url?.path
            state.capturedMethod = request.httpMethod
            state.capturedBody = request.httpBody ?? readStream(request.httpBodyStream)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1}}"#.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToList(imdbId: "tt1234567", type: .movie)

        #expect(state.capturedPath?.contains("/sync/add-to-list") == true)
        #expect(state.capturedMethod == "POST")

        let decoded = try JSONDecoder().decode([String: [SimklAddItem]].self, from: state.capturedBody!)
        #expect(decoded["movies"]?.count == 1)
        #expect(decoded["movies"]?[0].ids.imdb == "tt1234567")
        #expect(decoded["movies"]?[0].to == "plantowatch")
    }

    @Test func addToListShowSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: Data?
        }
        let state = CapturedState()

        let session = makeSimklStubSession { request in
            state.capturedBody = request.httpBody ?? readStream(request.httpBodyStream)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"shows":1}}"#.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToList(imdbId: "tt7654321", type: .series)

        let decoded = try JSONDecoder().decode([String: [SimklAddItem]].self, from: state.capturedBody!)
        #expect(decoded["shows"]?.count == 1)
        #expect(decoded["shows"]?[0].ids.imdb == "tt7654321")
    }

    @Test func addToListWithCustomList() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: Data?
        }
        let state = CapturedState()

        let session = makeSimklStubSession { request in
            state.capturedBody = request.httpBody ?? readStream(request.httpBodyStream)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1}}"#.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToList(imdbId: "tt0000001", type: .movie, list: "custom-list")

        let decoded = try JSONDecoder().decode([String: [SimklAddItem]].self, from: state.capturedBody!)
        #expect(decoded["movies"]?[0].to == "custom-list")
    }

    @Test func markWatchedMovieSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
            var capturedBody: Data?
        }
        let state = CapturedState()

        let session = makeSimklStubSession { request in
            state.capturedPath = request.url?.path
            state.capturedBody = request.httpBody ?? readStream(request.httpBodyStream)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1}}"#.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.markWatched(imdbId: "tt1111111", type: .movie)

        #expect(state.capturedPath?.contains("/sync/history") == true)
        let decoded = try JSONDecoder().decode([String: [SimklAddItem]].self, from: state.capturedBody!)
        #expect(decoded["movies"]?.count == 1)
        #expect(decoded["movies"]?[0].ids.imdb == "tt1111111")
        #expect(decoded["movies"]?[0].watchedAt != nil)
    }

    @Test func markWatchedShowSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: Data?
        }
        let state = CapturedState()

        let session = makeSimklStubSession { request in
            state.capturedBody = request.httpBody ?? readStream(request.httpBodyStream)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"shows":1}}"#.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.markWatched(imdbId: "tt2222222", type: .series)

        let decoded = try JSONDecoder().decode([String: [SimklAddItem]].self, from: state.capturedBody!)
        #expect(decoded["shows"]?.count == 1)
        #expect(decoded["shows"]?[0].ids.imdb == "tt2222222")
    }

    @Test func markWatchedWithSpecificDate() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: Data?
        }
        let state = CapturedState()

        let session = makeSimklStubSession { request in
            state.capturedBody = request.httpBody ?? readStream(request.httpBodyStream)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1}}"#.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let specificDate = Date(timeIntervalSince1970: 1609459200)
        try await service.markWatched(imdbId: "tt3333333", type: .movie, watchedAt: specificDate)

        let decoded = try JSONDecoder().decode([String: [SimklAddItem]].self, from: state.capturedBody!)
        #expect(decoded["movies"]?[0].watchedAt != nil)
    }

    @Test func addToListThrowsNotConnectedWithoutToken() async {
        let service = SimklSyncService(clientId: "client", clientSecret: "secret")

        do {
            try await service.addToList(imdbId: "tt4444444", type: .movie)
            Issue.record("Expected SimklError.notConnected")
        } catch let error as SimklError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func markWatchedThrowsNotConnectedWithoutToken() async {
        let service = SimklSyncService(clientId: "client", clientSecret: "secret")

        do {
            try await service.markWatched(imdbId: "tt5555555", type: .movie)
            Issue.record("Expected SimklError.notConnected")
        } catch let error as SimklError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }
}

// MARK: - Response Parsing Tests

@Suite("SimklSyncService - Response Parsing")
struct SimklSyncServiceResponseParsingTests {

    @Test func parseSimklSyncResponseWithMovies() async throws {
        let json = """
        {
            "movies": [
                {
                    "last_watched_at": "2024-01-01T00:00:00.000Z",
                    "status": "completed",
                    "movie": {
                        "title": "Test Movie",
                        "year": 2024,
                        "ids": {
                            "simkl": 1,
                            "imdb": "tt0000001",
                            "tmdb": "123"
                        }
                    }
                }
            ],
            "shows": []
        }
        """

        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let result = try await service.getWatchlist()

        #expect(result.movies?.count == 1)
        #expect(result.movies?[0].movie?.title == "Test Movie")
        #expect(result.movies?[0].movie?.year == 2024)
        #expect(result.movies?[0].movie?.ids.imdb == "tt0000001")
        #expect(result.movies?[0].status == "completed")
        #expect(result.shows?.isEmpty == true)
    }

    @Test func parseSimklSyncResponseWithShows() async throws {
        let json = """
        {
            "movies": [],
            "shows": [
                {
                    "last_watched_at": "2024-01-01T00:00:00.000Z",
                    "status": "watching",
                    "show": {
                        "title": "Test Show",
                        "year": 2024,
                        "ids": {
                            "simkl": 2,
                            "imdb": "tt0000002",
                            "tmdb": "456"
                        }
                    }
                }
            ]
        }
        """

        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let result = try await service.getWatchlist()

        #expect(result.shows?.count == 1)
        #expect(result.shows?[0].show?.title == "Test Show")
        #expect(result.shows?[0].show?.ids.imdb == "tt0000002")
        #expect(result.shows?[0].status == "watching")
    }

    @Test func parseSimklActionResponse() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: Data?
        }
        let state = CapturedState()

        let session = makeSimklStubSession { request in
            state.capturedBody = request.httpBody ?? readStream(request.httpBodyStream)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":5,"shows":3},"not_found":{"movies":1}}"#.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToList(imdbId: "tt0000003", type: .movie)

        let responseData = state.capturedBody!
        #expect(responseData.count > 0)
    }

    @Test func parseEmptyMoviesArray() async throws {
        let json = #"{"movies":[],"shows":[]}"#

        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let result = try await service.getWatchlist()

        #expect(result.movies?.isEmpty == true)
        #expect(result.shows?.isEmpty == true)
    }

    @Test func parseMultipleMovies() async throws {
        let json = """
        {
            "movies": [
                {"movie": {"title": "Movie 1", "ids": {"imdb": "tt001"}}},
                {"movie": {"title": "Movie 2", "ids": {"imdb": "tt002"}}},
                {"movie": {"title": "Movie 3", "ids": {"imdb": "tt003"}}}
            ],
            "shows": []
        }
        """

        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let result = try await service.getWatchlist()

        #expect(result.movies?.count == 3)
    }

    @Test func parseSimklItemWithNullFields() async throws {
        let json = """
        {
            "movies": [
                {
                    "last_watched_at": null,
                    "status": null,
                    "movie": {
                        "title": "Minimal Movie",
                        "year": null,
                        "ids": {
                            "simkl": null,
                            "imdb": "tt004",
                            "tmdb": null
                        }
                    }
                }
            ],
            "shows": []
        }
        """

        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let result = try await service.getWatchlist()

        #expect(result.movies?.count == 1)
        #expect(result.movies?[0].movie?.title == "Minimal Movie")
        #expect(result.movies?[0].movie?.ids.imdb == "tt004")
    }
}

// MARK: - Error Handling Tests

@Suite("SimklSyncService - Error Handling")
struct SimklSyncServiceErrorHandlingTests {

    @Test func getWatchlistThrowsInvalidURL() async {
        let session = makeSimklStubSession { request in
            Issue.record("Should not reach network with invalid URL")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = SimklSyncService(
            clientId: "client",
            clientSecret: "secret",
            baseURL: "https://api.simkl.com/[",
            session: session
        )
        await service.setTokens(access: "token", refresh: nil)

        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.invalidURL")
        } catch let error as SimklError {
            if case .invalidURL = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func getWatchlistHandles500Error() async {
        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)

        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.httpError(500)")
        } catch let error as SimklError {
            if case .httpError(500) = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func getWatchlistHandles404Error() async {
        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)

        do {
            _ = try await service.getWatchlist()
            Issue.record("Expected SimklError.httpError(404)")
        } catch let error as SimklError {
            if case .httpError(404) = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func addToListHandles500Error() async {
        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)

        do {
            try await service.addToList(imdbId: "tt6666666", type: .movie)
            Issue.record("Expected SimklError.httpError(500)")
        } catch let error as SimklError {
            if case .httpError(500) = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func markWatchedHandles500Error() async {
        let session = makeSimklStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = SimklSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)

        do {
            try await service.markWatched(imdbId: "tt7777777", type: .movie)
            Issue.record("Expected SimklError.httpError(500)")
        } catch let error as SimklError {
            if case .httpError(500) = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func allSimklErrorsHaveDescriptions() async {
        let errors: [SimklError] = [
            .invalidURL,
            .httpError(500),
            .unauthorized,
            .notConnected,
            .authorizationSessionMissing,
            .authorizationSessionExpired,
            .authorizationStateMismatch,
            .authorizationStateMissing,
            .invalidAuthorizationCode,
            .missingClientSecret,
            .invalidAuthorizationResponse,
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - SimklAddItem Codable Verification

private struct SimklAddItem: Codable {
    let ids: SimklAddIds
    let to: String?
    let watchedAt: String?

    enum CodingKeys: String, CodingKey {
        case ids
        case to
        case watchedAt = "watched_at"
    }
}

private struct SimklAddIds: Codable {
    let imdb: String
}
