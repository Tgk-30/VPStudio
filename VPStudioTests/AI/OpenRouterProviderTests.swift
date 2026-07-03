import Foundation
import Testing
@testable import VPStudio

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

private func makeUnexpectedOpenRouterSession() -> URLSession {
    URLProtocolHarness.makeSession { request in
        Issue.record("Unexpected OpenRouter request: \(request.url?.absoluteString ?? "nil")")
        let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        return (response, Data())
    }
}

@Suite("OpenRouterProvider")
struct OpenRouterProviderTests {
    @Test func completeReturnsResponseForValidRequest() async throws {
        let body = Data(#"{"choices":[{"message":{"content":"hello world"}}],"usage":{"prompt_tokens":10,"completion_tokens":5}}"#.utf8)
        let provider = OpenRouterProvider(
            apiKey: "test_key",
            model: "google/gemini-2.5-flash-lite-preview",
            baseURL: "https://openrouter.ai/api/v1/chat/completions",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, body)
            },
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "system", userMessage: "user")

        #expect(response.content == "hello world")
        #expect(response.inputTokens == 10)
        #expect(response.outputTokens == 5)
        #expect(response.model == "google/gemini-2.5-flash-lite-preview")
    }

    @Test func completeIncludesBearerTokenInAuthorizationHeader() async throws {
        final class State: @unchecked Sendable {
            var authHeader: String?
        }
        let state = State()

        let provider = OpenRouterProvider(
            apiKey: "my_secret_key",
            model: "google/gemini-2.5-flash-lite-preview",
            session: URLProtocolHarness.makeSession { request in
                state.authHeader = request.value(forHTTPHeaderField: "Authorization")
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"choices":[{"message":{"content":"test"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.authHeader == "Bearer my_secret_key")
    }

    @Test func completeSetsCorrectContentType() async throws {
        final class State: @unchecked Sendable {
            var contentType: String?
        }
        let state = State()

        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "google/gemini-2.5-flash-lite-preview",
            session: URLProtocolHarness.makeSession { request in
                state.contentType = request.value(forHTTPHeaderField: "Content-Type")
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"choices":[{"message":{"content":"test"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.contentType == "application/json")
    }

    @Test func completeSendsPOSTRequest() async throws {
        final class State: @unchecked Sendable {
            var method: String?
            var requestURL: URL?
        }
        let state = State()

        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "google/gemini-2.5-flash-lite-preview",
            session: URLProtocolHarness.makeSession { request in
                state.method = request.httpMethod
                state.requestURL = request.url
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"choices":[{"message":{"content":"test"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.method == "POST")
    }

    @Test func completeTrimsWhitespaceFromBaseURLBeforeRequest() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
        }
        let state = State()

        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "google/gemini-2.5-flash-lite-preview",
            baseURL: "  https://openrouter.ai/api/v1/chat/completions  ",
            session: URLProtocolHarness.makeSession { request in
                state.requestURL = request.url
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"choices":[{"message":{"content":"trimmed"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.requestURL?.absoluteString == "https://openrouter.ai/api/v1/chat/completions")
    }

    @Test func completeIncludesMessagesInBody() async throws {
        final class State: @unchecked Sendable {
            var messages: [[String: Any]]?
        }
        let state = State()

        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "google/gemini-2.5-flash-lite-preview",
            session: URLProtocolHarness.makeSession { request in
                if let body = request.httpBody ?? readStream(request.httpBodyStream),
                   let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                   let msgs = json["messages"] as? [[String: Any]] {
                    state.messages = msgs
                }
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"choices":[{"message":{"content":"test"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "system prompt", userMessage: "user message")

        #expect(state.messages?.count == 2)
        #expect(state.messages?[0]["role"] as? String == "system")
        #expect(state.messages?[0]["content"] as? String == "system prompt")
        #expect(state.messages?[1]["role"] as? String == "user")
        #expect(state.messages?[1]["content"] as? String == "user message")
    }

    @Test func completeTrimsAPIKey() async throws {
        final class State: @unchecked Sendable {
            var authHeader: String?
        }
        let state = State()

        let provider = OpenRouterProvider(
            apiKey: "  trimmed_key  ",
            model: "google/gemini-2.5-flash-lite-preview",
            session: URLProtocolHarness.makeSession { request in
                state.authHeader = request.value(forHTTPHeaderField: "Authorization")
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"choices":[{"message":{"content":"test"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.authHeader == "Bearer trimmed_key")
    }

    @Test func completeTrimsModel() async throws {
        let body = Data(#"{"choices":[{"message":{"content":"test"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#.utf8)
        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "  google/gemini-2.5-flash-lite-preview  ",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, body)
            },
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "sys", userMessage: "user")

        #expect(response.model == "google/gemini-2.5-flash-lite-preview")
    }

    @Test func completeThrowsForEmptyAPIKey() async throws {
        let provider = OpenRouterProvider(
            apiKey: "",
            model: "google/gemini-2.5-flash-lite-preview",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"choices":[{"message":{"content":"test"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsForEmptyModel() async throws {
        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "   ",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"choices":[{"message":{"content":"test"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsForEmptyBaseURLWithoutNetwork() async {
        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "google/gemini-2.5-flash-lite-preview",
            baseURL: " \n\t ",
            session: makeUnexpectedOpenRouterSession(),
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsForMalformedBaseURLWithoutNetwork() async {
        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "google/gemini-2.5-flash-lite-preview",
            baseURL: "http://[::1",
            session: makeUnexpectedOpenRouterSession(),
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsForNon2xxStatus() async throws {
        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "google/gemini-2.5-flash-lite-preview",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data("Unauthorized".utf8))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsHTTPErrorWithEmptyMessageForNonUTF8Body() async {
        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "google/gemini-2.5-flash-lite-preview",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data([0xC3, 0x28]))
            },
            sleep: { _ in }
        )

        do {
            _ = try await provider.complete(system: "sys", userMessage: "user")
            Issue.record("Expected HTTP error")
        } catch AIError.httpError(let status, let message) {
            #expect(status == 500)
            #expect(message == "")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func completeThrowsForMalformedPayloadShapes() async {
        let malformedBodies = [
            Data(#"[]"#.utf8),
            Data(#"{"choices":[]}"#.utf8),
            Data(#"{"choices":[{"message":{"content":""}}]}"#.utf8),
            Data(#"{"choices":[{"message":{"content":42}}]}"#.utf8)
        ]

        for body in malformedBodies {
            let provider = OpenRouterProvider(
                apiKey: "key",
                model: "google/gemini-2.5-flash-lite-preview",
                session: URLProtocolHarness.makeSession { request in
                    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                    return (response, body)
                },
                sleep: { _ in }
            )

            await #expect(throws: AIError.self) {
                _ = try await provider.complete(system: "sys", userMessage: "user")
            }
        }
    }

    @Test func completeHandlesUsageDefaults() async throws {
        let body = Data(#"{"choices":[{"message":{"content":"test"}}]}"#.utf8)
        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "google/gemini-2.5-flash-lite-preview",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, body)
            },
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "sys", userMessage: "user")

        #expect(response.inputTokens == 0)
        #expect(response.outputTokens == 0)
    }

    @Test func completeUsesCorrectProvider() async throws {
        let body = Data(#"{"choices":[{"message":{"content":"test"}}],"usage":{"prompt_tokens":1,"completion_tokens":1}}"#.utf8)
        let provider = OpenRouterProvider(
            apiKey: "key",
            model: "google/gemini-2.5-flash-lite-preview",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, body)
            },
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "sys", userMessage: "user")

        #expect(response.provider == .openRouter)
    }
}
