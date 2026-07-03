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

// MARK: - Custom Lists Tests

@Suite("TraktSyncService - Custom Lists")
struct TraktSyncServiceCustomListsTests {

    @Test func getCustomListsCallsCorrectPath() async throws {
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
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.getCustomLists()

        #expect(state.capturedPath?.contains("/users/me/lists") == true)
        #expect(state.capturedMethod == "GET")
        #expect(state.capturedHeaders["Authorization"] == "Bearer token")
    }

    @Test func getListItemsCallsCorrectPath() async throws {
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
        _ = try await service.getListItems(listId: 42)

        #expect(state.capturedPath?.contains("/users/me/lists/42/items") == true)
    }

    @Test func createCustomListSendsCorrectBody() async throws {
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
            return (response, Data(#"{"ids":{"trakt":1,"slug":"test-list"},"name":"Test List","privacy":"private"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.createCustomList(name: "Test List", description: "A test description")

        #expect(state.capturedPath?.contains("/users/me/lists") == true)
        #expect(state.capturedMethod == "POST")
        #expect(state.capturedBody?["name"] as? String == "Test List")
        #expect(state.capturedBody?["description"] as? String == "A test description")
        #expect(state.capturedBody?["privacy"] as? String == "private")
    }

    @Test func createCustomListWithoutDescription() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"ids":{"trakt":2},"name":"No Desc","privacy":"private"}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        _ = try await service.createCustomList(name: "No Desc")

        #expect(state.capturedBody?["description"] == nil)
        #expect(state.capturedBody?["name"] as? String == "No Desc")
    }

    @Test func addToCustomListWithMovies() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
            var capturedBody: [String: Any]?
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
        try await service.addToCustomList(listId: 1, imdbIds: [("tt0000001", .movie)])

        #expect(state.capturedPath?.contains("/users/me/lists/1/items") == true)
        let movies = state.capturedBody?["movies"] as? [[String: Any]]
        #expect(movies?.count == 1)
        let ids = movies?[0]["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt0000001")
    }

    @Test func addToCustomListWithShows() async throws {
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
        try await service.addToCustomList(listId: 1, imdbIds: [("tt0000002", .series)])

        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(shows?.count == 1)
        let ids = shows?[0]["ids"] as? [String: String]
        #expect(ids?["imdb"] == "tt0000002")
    }

    @Test func addToCustomListWithMixedTypes() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1,"shows":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToCustomList(listId: 1, imdbIds: [("tt0000003", .movie), ("tt0000004", .series)])

        let movies = state.capturedBody?["movies"] as? [[String: Any]]
        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        #expect(movies?.count == 1)
        #expect(shows?.count == 1)
    }

    @Test func addToCustomListNormalizesOMDbCompositeMediaIDs() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"added":{"movies":1,"shows":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.addToCustomList(
            listId: 1,
            imdbIds: [
                ("movie-omdb-TT1160419", .movie),
                ("series-omdb-TT0903747", .series),
            ]
        )

        let movies = state.capturedBody?["movies"] as? [[String: Any]]
        let movieIds = movies?[0]["ids"] as? [String: String]
        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        let showIds = shows?[0]["ids"] as? [String: String]
        #expect(movieIds?["imdb"] == "tt1160419")
        #expect(showIds?["imdb"] == "tt0903747")
    }

    @Test func removeFromCustomListSendsCorrectBody() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
            var capturedBody: [String: Any]?
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
        try await service.removeFromCustomList(listId: 1, imdbIds: [("tt0000005", .movie)])

        #expect(state.capturedPath?.contains("/users/me/lists/1/items/remove") == true)
        let movies = state.capturedBody?["movies"] as? [[String: Any]]
        #expect(movies?.count == 1)
    }

    @Test func removeFromCustomListNormalizesOMDbCompositeMediaIDs() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedBody: [String: Any]?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            if let body = request.httpBody ?? readStream(request.httpBodyStream) {
                state.capturedBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"deleted":{"movies":1,"shows":1}}"#.utf8))
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.removeFromCustomList(
            listId: 1,
            imdbIds: [
                ("movie-omdb-TT1160419", .movie),
                ("series-omdb-TT0903747", .series),
            ]
        )

        let movies = state.capturedBody?["movies"] as? [[String: Any]]
        let movieIds = movies?[0]["ids"] as? [String: String]
        let shows = state.capturedBody?["shows"] as? [[String: Any]]
        let showIds = shows?[0]["ids"] as? [String: String]
        #expect(movieIds?["imdb"] == "tt1160419")
        #expect(showIds?["imdb"] == "tt0903747")
    }

    @Test func deleteCustomListCallsCorrectPath() async throws {
        final class CapturedState: @unchecked Sendable {
            var capturedPath: String?
            var capturedMethod: String?
        }
        let state = CapturedState()

        let session = makeTraktStubSession { request in
            state.capturedPath = request.url?.path
            state.capturedMethod = request.httpMethod
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = TraktSyncService(clientId: "client", clientSecret: "secret", session: session)
        await service.setTokens(access: "token", refresh: nil)
        try await service.deleteCustomList(listId: 99)

        #expect(state.capturedPath?.contains("/users/me/lists/99") == true)
        #expect(state.capturedMethod == "DELETE")
    }

    @Test func addToCustomListThrowsNotConnectedWithoutToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")

        do {
            try await service.addToCustomList(listId: 1, imdbIds: [("tt0000006", .movie)])
            Issue.record("Expected TraktError.notConnected")
        } catch let error as TraktError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func removeFromCustomListThrowsNotConnectedWithoutToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")

        do {
            try await service.removeFromCustomList(listId: 1, imdbIds: [("tt0000007", .movie)])
            Issue.record("Expected TraktError.notConnected")
        } catch let error as TraktError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func deleteCustomListThrowsNotConnectedWithoutToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")

        do {
            try await service.deleteCustomList(listId: 1)
            Issue.record("Expected TraktError.notConnected")
        } catch let error as TraktError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func getCustomListsThrowsNotConnectedWithoutToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")

        do {
            _ = try await service.getCustomLists()
            Issue.record("Expected TraktError.notConnected")
        } catch let error as TraktError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func getListItemsThrowsNotConnectedWithoutToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")

        do {
            _ = try await service.getListItems(listId: 1)
            Issue.record("Expected TraktError.notConnected")
        } catch let error as TraktError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }

    @Test func createCustomListThrowsNotConnectedWithoutToken() async {
        let service = TraktSyncService(clientId: "client", clientSecret: "secret")

        do {
            _ = try await service.createCustomList(name: "Test")
            Issue.record("Expected TraktError.notConnected")
        } catch let error as TraktError {
            if case .notConnected = error { /* OK */ }
            else { Issue.record("Unexpected error: \(error)") }
        } catch { Issue.record("Unexpected error type: \(error)") }
    }
}
