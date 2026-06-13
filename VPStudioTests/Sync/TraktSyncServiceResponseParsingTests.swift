import Testing
import Foundation
@testable import VPStudio

// MARK: - Response Parsing Tests

@Suite("TraktSyncService - Response Parsing")
struct TraktSyncServiceResponseParsingTests {

    @Test func parseTraktItemWithMovie() async throws {
        let json = """
        [
            {
                "rank": 1,
                "listed_at": "2024-01-01T00:00:00.000Z",
                "type": "movie",
                "movie": {
                    "title": "Test Movie",
                    "year": 2024,
                    "ids": {
                        "trakt": 1,
                        "slug": "test-movie",
                        "imdb": "tt0000001",
                        "tmdb": 123
                    }
                }
            }
        ]
        """

        final class CapturedState: @unchecked Sendable {
            var items: [TraktItem] = []
        }
        let state = CapturedState()

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        state.items = try await service.getWatchlist(type: .movie)

        #expect(state.items.count == 1)
        #expect(state.items[0].movie?.title == "Test Movie")
        #expect(state.items[0].movie?.year == 2024)
        #expect(state.items[0].movie?.ids.imdb == "tt0000001")
    }

    @Test func parseTraktItemWithShow() async throws {
        let json = """
        [
            {
                "rank": 1,
                "listed_at": "2024-01-01T00:00:00.000Z",
                "type": "show",
                "show": {
                    "title": "Test Show",
                    "year": 2024,
                    "ids": {
                        "trakt": 2,
                        "slug": "test-show",
                        "imdb": "tt0000002",
                        "tmdb": 456
                    }
                }
            }
        ]
        """

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let items = try await service.getWatchlist(type: .series)

        #expect(items.count == 1)
        #expect(items[0].show?.title == "Test Show")
        #expect(items[0].show?.ids.imdb == "tt0000002")
    }

    @Test func parseTraktHistoryItemMovie() async throws {
        let json = """
        [
            {
                "id": 1,
                "watched_at": "2024-01-01T00:00:00.000Z",
                "action": "new",
                "movie": {
                    "title": "History Movie",
                    "year": 2024,
                    "ids": {
                        "imdb": "tt0000003"
                    }
                }
            }
        ]
        """

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let items = try await service.getHistory(type: .movie)

        #expect(items.count == 1)
        #expect(items[0].movie?.title == "History Movie")
        #expect(items[0].action == "new")
    }

    @Test func parseTraktHistoryItemShow() async throws {
        let json = """
        [
            {
                "id": 2,
                "watched_at": "2024-01-01T00:00:00.000Z",
                "action": "scrobble",
                "show": {
                    "title": "History Show",
                    "year": 2024,
                    "ids": {
                        "imdb": "tt0000004"
                    }
                },
                "episode": {
                    "season": 1,
                    "number": 5,
                    "title": "Episode 5",
                    "ids": {
                        "imdb": "tt001"
                    }
                }
            }
        ]
        """

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let items = try await service.getHistory(type: .series)

        #expect(items.count == 1)
        #expect(items[0].show?.title == "History Show")
        #expect(items[0].episode?.season == 1)
        #expect(items[0].episode?.number == 5)
    }

    @Test func parseTraktRatingItem() async throws {
        let json = """
        [
            {
                "rating": 8,
                "rated_at": "2024-01-01T00:00:00.000Z",
                "movie": {
                    "title": "Rated Movie",
                    "year": 2024,
                    "ids": {
                        "imdb": "tt0000005"
                    }
                }
            }
        ]
        """

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let items = try await service.getRatings(type: .movie)

        #expect(items.count == 1)
        #expect(items[0].rating == 8)
        #expect(items[0].movie?.title == "Rated Movie")
    }

    @Test func parseTraktWatchedItem() async throws {
        let json = """
        [
            {
                "plays": 5,
                "last_watched_at": "2024-01-01T00:00:00.000Z",
                "last_updated_at": "2024-01-02T00:00:00.000Z",
                "movie": {
                    "title": "Watched Movie",
                    "year": 2024,
                    "ids": {
                        "imdb": "tt0000006"
                    }
                }
            }
        ]
        """

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let items = try await service.getWatched(type: .movie)

        #expect(items.count == 1)
        #expect(items[0].plays == 5)
        #expect(items[0].movie?.title == "Watched Movie")
    }

    @Test func parseTraktCustomList() async throws {
        let json = """
        [
            {
                "ids": {
                    "trakt": 1,
                    "slug": "my-list"
                },
                "name": "My List",
                "description": "A test list",
                "privacy": "private",
                "item_count": 10,
                "updated_at": "2024-01-01T00:00:00.000Z"
            }
        ]
        """

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let lists = try await service.getCustomLists()

        #expect(lists.count == 1)
        #expect(lists[0].name == "My List")
        #expect(lists[0].ids.slug == "my-list")
        #expect(lists[0].itemCount == 10)
    }

    @Test func parseTraktListItem() async throws {
        let json = """
        [
            {
                "rank": 1,
                "listed_at": "2024-01-01T00:00:00.000Z",
                "type": "movie",
                "movie": {
                    "title": "List Movie",
                    "year": 2024,
                    "ids": {
                        "imdb": "tt0000007"
                    }
                }
            }
        ]
        """

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let items = try await service.getListItems(listId: 1)

        #expect(items.count == 1)
        #expect(items[0].movie?.title == "List Movie")
        #expect(items[0].type == "movie")
    }

    @Test func parseScrobbleResponse() async throws {
        let json = #"{"id": 12345, "action": "start"}"#

        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = URLProtocolHarness.makeSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.startScrobble(imdbId: "tt0000008", type: .movie, progress: 50.0)

        #expect(state.capturedBody?["progress"] as? Double == 50.0)
    }

    @Test func parseEmptyArray() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let items = try await service.getWatchlist(type: .movie)

        #expect(items.isEmpty)
    }

    @Test func parseMultipleItems() async throws {
        let json = """
        [
            {"movie": {"title": "Movie 1", "ids": {"imdb": "tt001"}}},
            {"movie": {"title": "Movie 2", "ids": {"imdb": "tt002"}}},
            {"movie": {"title": "Movie 3", "ids": {"imdb": "tt003"}}}
        ]
        """

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let items = try await service.getWatchlist(type: .movie)

        #expect(items.count == 3)
    }

    @Test func parseTraktItemWithNullFields() async throws {
        let json = """
        [
            {
                "rank": null,
                "listed_at": null,
                "movie": {
                    "title": "Minimal Movie",
                    "year": null,
                    "ids": {
                        "trakt": null,
                        "slug": null,
                        "imdb": "tt004",
                        "tmdb": null
                    }
                }
            }
        ]
        """

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let items = try await service.getWatchlist(type: .movie)

        #expect(items.count == 1)
        #expect(items[0].movie?.title == "Minimal Movie")
        #expect(items[0].movie?.ids.imdb == "tt004")
    }

    @Test func parseTraktShowWithNameField() async throws {
        let json = """
        [
            {
                "show": {
                    "name": "Show With Name Field",
                    "year": 2024,
                    "ids": {
                        "imdb": "tt005"
                    }
                }
            }
        ]
        """

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        let items = try await service.getWatchlist(type: .series)

        #expect(items.count == 1)
        #expect(items[0].show?.title == "Show With Name Field")
    }
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
