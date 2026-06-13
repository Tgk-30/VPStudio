import Testing
import Foundation
@testable import VPStudio

// MARK: - Stub Session Helper

private func makeTraktStubSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    URLProtocolHarness.makeSession(handler: handler)
}

// MARK: - Request Body Parsing Helper

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

@Suite("TraktSyncService - Request Construction")
struct TraktSyncServiceRequestConstructionTests {

    @Test func getWatchlistMoviesUsesCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
            var capturedMethod: String?
            var capturedHeaders: [String: String] = [:]
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            state.capturedMethod = request.httpMethod
            state.capturedHeaders["Authorization"] = request.value(forHTTPHeaderField: "Authorization")
            state.capturedHeaders["trakt-api-key"] = request.value(forHTTPHeaderField: "trakt-api-key")
            state.capturedHeaders["trakt-api-version"] = request.value(forHTTPHeaderField: "trakt-api-version")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "test-client", clientSecret: "test-secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getWatchlist(type: .movie)

        #expect(state.capturedPath?.contains("/sync/watchlist/movies") == true)
        #expect(state.capturedMethod == "GET")
        #expect(state.capturedHeaders["Authorization"] == "Bearer token")
        #expect(state.capturedHeaders["trakt-api-key"] == "test-client")
        #expect(state.capturedHeaders["trakt-api-version"] == "2")
    }

    @Test func getWatchlistShowsUsesCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getWatchlist(type: .series)

        #expect(state.capturedPath?.contains("/sync/watchlist/shows") == true)
    }

    @Test func getHistoryMoviesUsesCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getHistory(type: .movie)

        #expect(state.capturedPath?.contains("/sync/history/movies") == true)
    }

    @Test func getHistoryShowsUsesCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getHistory(type: .series)

        #expect(state.capturedPath?.contains("/sync/history/shows") == true)
    }

    @Test func getRatingsMoviesUsesCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getRatings(type: .movie)

        #expect(state.capturedPath?.contains("/sync/ratings/movies") == true)
    }

    @Test func getWatchedMoviesUsesCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getWatched(type: .movie)

        #expect(state.capturedPath?.contains("/sync/watched/movies") == true)
    }

    @Test func getWatchedShowsUsesCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getWatched(type: .series)

        #expect(state.capturedPath?.contains("/sync/watched/shows") == true)
    }

    @Test func addToWatchlistMovieSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
            var capturedPath: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToWatchlist(imdbId: "tt0000001", type: .movie)

        #expect(state.capturedPath?.contains("/sync/watchlist") == true)
        let movies = state.capturedBody?["movies"] as? [[String: Any]]
        #expect(movies?.count == 1)
        let ids = movies?[0]["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt0000001")
    }

    @Test func addToWatchlistShowSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"shows":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToWatchlist(imdbId: "tt0000002", type: .series)

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        let ids = shows?[0]["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt0000002")
    }

    @Test func removeFromWatchlistMovieSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
            var capturedPath: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"deleted":{"movies":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.removeFromWatchlist(imdbId: "tt0000003", type: .movie)

        #expect(state.capturedPath?.contains("/sync/watchlist/remove") == true)
        let movies = state.capturedBody?["movies"] as? [[String: Any]]
        #expect(movies?.count == 1)
    }

    @Test func removeFromWatchlistShowSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"deleted":{"shows":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.removeFromWatchlist(imdbId: "tt0000004", type: .series)

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
    }

    @Test func addRatingMovieSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addRating(imdbId: "tt0000005", rating: 9, type: .movie)

        let movies = state.capturedBody?["movies"] as? [[String: Any]]
        #expect(movies?.count == 1)
        #expect(movies?[0]["rating"] as? Int == 9)
    }

    @Test func addRatingShowSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"shows":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addRating(imdbId: "tt0000006", rating: 7, type: .series)

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        #expect(shows?[0]["rating"] as? Int == 7)
    }

    @Test func addToHistoryMovieSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let watchedAt = Date(timeIntervalSince1970: 1609459200)
        try await service.addToHistory(imdbId: "tt0000007", type: .movie, watchedAt: watchedAt)

        let movies = state.capturedBody?["movies"] as? [[String: Any]]
        #expect(movies?.count == 1)
        #expect(movies?[0]["ids"] as? [String: String] == ["imdb": "tt0000007"])
        #expect(movies?[0]["watched_at"] != nil)
    }

    @Test func addToHistoryShowWithEpisodeIdUsesEpisodesFormat() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"episodes":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt0000008", type: .series, episodeId: "tt001")

        let episodes = state.capturedBody?["episodes"] as? [[String: Any]]
        #expect(episodes?.count == 1)
        let ids = episodes?[0]["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt001")
    }

    @Test func addToHistoryShowWithSeasonEpisodeParsesCorrectly() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"episodes":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToHistory(imdbId: "tt0000009", type: .series, episodeId: "S03E05")

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        let seasons = shows?[0]["seasons"] as? [[String: Any]]
        #expect(seasons?.count == 1)
        #expect(seasons?[0]["number"] as? Int == 3)
        let episodes = seasons?[0]["episodes"] as? [[String: Any]]
        #expect(episodes?.count == 1)
        #expect(episodes?[0]["number"] as? Int == 5)
    }
}
