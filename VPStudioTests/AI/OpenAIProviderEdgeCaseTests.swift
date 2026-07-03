import Testing
import Foundation
@testable import VPStudio

// MARK: - Helpers

private final class CapturedRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?

    func record(_ request: URLRequest) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    func jsonBody() throws -> [String: Any] {
        lock.lock()
        let body = request?.httpBody
        lock.unlock()
        let data = try #require(body)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func requestURL() -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return request?.url
    }
}

private func makeSession(body: Data) -> URLSession {
    URLProtocolHarness.makeSession { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, body)
    }
}

private func makeFailingSession(statusCode: Int, body: Data) -> URLSession {
    URLProtocolHarness.makeSession { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (response, body)
    }
}

private func makeUnexpectedNetworkSession(_ label: String = "OpenAI") -> URLSession {
    URLProtocolHarness.makeSession { request in
        Issue.record("Unexpected \(label) request: \(request.url?.absoluteString ?? "nil")")
        let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        return (response, Data())
    }
}

private func captureSession(capture: CapturedRequest, responseData: Data) -> URLSession {
    URLProtocolHarness.makeSession { request in
        capture.record(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, responseData)
    }
}

private func chatCompletionsResponseData(content: String, usage: [String: Any]? = nil) -> Data {
    var json: [String: Any] = [
        "choices": [
            ["message": ["content": content]]
        ]
    ]
    if let usage {
        json["usage"] = usage
    }
    return try! JSONSerialization.data(withJSONObject: json)
}

private func responsesOutputTextData(content: String, usage: [String: Any]? = nil) -> Data {
    var json: [String: Any] = [
        "output_text": content
    ]
    if let usage {
        json["usage"] = usage
    }
    return try! JSONSerialization.data(withJSONObject: json)
}

// MARK: - Endpoint Style & Request Body

@Suite("OpenAIProvider Endpoint Style")
struct OpenAIProviderEndpointStyleTests {

    @Test func defaultBaseURLUsesResponsesStyle() {
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test")
        #expect(provider.endpointStyle == .responses)

        let body = provider.requestBody(system: "sys", userMessage: "msg")
        #expect(body["max_output_tokens"] as? Int == 4096)
        #expect(body["max_completion_tokens"] == nil)
        #expect(body["instructions"] as? String == "sys")
    }

    @Test func chatCompletionsURLUsesMaxCompletionTokens() {
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "https://api.openai.test/v1/chat/completions"
        )
        #expect(provider.endpointStyle == .chatCompletions)

        let body = provider.requestBody(system: "sys", userMessage: "msg")
        #expect(body["max_completion_tokens"] as? Int == 4096)
        #expect(body["max_output_tokens"] == nil)
    }

    @Test func responsesURLUsesMaxOutputTokens() {
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "https://api.openai.test/v1/responses"
        )
        #expect(provider.endpointStyle == .responses)

        let body = provider.requestBody(system: "sys", userMessage: "msg")
        #expect(body["max_output_tokens"] as? Int == 4096)
        #expect(body["max_completion_tokens"] == nil)
    }

    @Test func trimsWhitespaceFromBaseURLBeforeEndpointDetectionAndRequest() async throws {
        let capture = CapturedRequest()
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "  https://api.openai.test/v1/chat/completions  ",
            session: captureSession(capture: capture, responseData: chatCompletionsResponseData(content: "trimmed")),
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "message")

        #expect(provider.endpointStyle == .chatCompletions)
        #expect(capture.requestURL()?.absoluteString == "https://api.openai.test/v1/chat/completions")
    }

    @Test func modelTrimmedInChatCompletionsRequestBody() {
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "  gpt-trimmed  ",
            baseURL: "https://api.openai.test/v1/chat/completions"
        )
        let body = provider.requestBody(system: "sys", userMessage: "msg")
        #expect(body["model"] as? String == "gpt-trimmed")
    }

    @Test func modelTrimmedInResponsesRequestBody() {
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "  gpt-trimmed  ",
            baseURL: "https://api.openai.test/v1/responses"
        )
        let body = provider.requestBody(system: "sys", userMessage: "msg")
        #expect(body["model"] as? String == "gpt-trimmed")
    }

    @Test func urlWithChatCompletionsInPathIsChatCompletionsStyle() {
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "https://api.openai.test/v1/chat/completions"
        )
        #expect(provider.endpointStyle == .chatCompletions)

        let body = provider.requestBody(system: "sys", userMessage: "msg")
        #expect(body["messages"] != nil)
        #expect(body["max_completion_tokens"] as? Int == 4096)
    }

    @Test func urlWithChatCompletionsInMiddleOfPathIsChatCompletionsStyle() {
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "https://api.openai.test/prefix/chat/completions/suffix"
        )
        #expect(provider.endpointStyle == .chatCompletions)

        let body = provider.requestBody(system: "sys", userMessage: "msg")
        #expect(body["max_completion_tokens"] as? Int == 4096)
    }

    @Test func urlWithChatInPathButNotChatCompletionsIsResponsesStyle() {
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "https://api.openai.test/v1/chat/something"
        )
        #expect(provider.endpointStyle == .responses)

        let body = provider.requestBody(system: "sys", userMessage: "msg")
        #expect(body["max_output_tokens"] as? Int == 4096)
        #expect(body["max_completion_tokens"] == nil)
    }

    @Test func urlWithCompletionsButNotChatIsResponsesStyle() {
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "https://api.openai.test/v1/completions"
        )
        #expect(provider.endpointStyle == .responses)

        let body = provider.requestBody(system: "sys", userMessage: "msg")
        #expect(body["max_output_tokens"] as? Int == 4096)
        #expect(body["max_completion_tokens"] == nil)
    }
}

// MARK: - Validation & HTTP Errors

@Suite("OpenAIProvider Validation & HTTP Errors")
struct OpenAIProviderValidationAndHTTPErrorTests {

    @Test func blankBaseURLThrowsInvalidResponseWithoutNetwork() async {
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: " \n\t ",
            session: makeUnexpectedNetworkSession(),
            sleep: { _ in }
        )

        do {
            _ = try await provider.complete(system: "s", userMessage: "u")
            Issue.record("Expected invalidResponse")
        } catch AIError.invalidResponse {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func nonUTF8HTTPErrorBodyFallsBackToEmptyMessage() async {
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            session: makeFailingSession(statusCode: 500, body: Data([0xC3, 0x28])),
            sleep: { _ in }
        )

        do {
            _ = try await provider.complete(system: "s", userMessage: "u")
            Issue.record("Expected HTTP error")
        } catch AIError.httpError(let status, let message) {
            #expect(status == 500)
            #expect(message == "")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

// MARK: - Chat Completions Response Parsing

@Suite("OpenAIProvider Chat Completions Parsing")
struct OpenAIProviderChatCompletionsParsingTests {

    @Test func parsesMessageContentFromChoices() async throws {
        let body = Data(#"{"choices":[{"message":{"content":"hello"}}],"usage":{"prompt_tokens":10,"completion_tokens":5}}"#.utf8)
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "https://api.openai.test/v1/chat/completions",
            session: makeSession(body: body),
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.content == "hello")
        #expect(response.inputTokens == 10)
        #expect(response.outputTokens == 5)
    }

    @Test func missingUsageDefaultsToZeroForChatCompletions() async throws {
        let body = Data(#"{"choices":[{"message":{"content":"zero"}}]}"#.utf8)
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "https://api.openai.test/v1/chat/completions",
            session: makeSession(body: body),
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.content == "zero")
        #expect(response.inputTokens == 0)
        #expect(response.outputTokens == 0)
    }

    @Test func legacyUsageKeysParsedForChatCompletions() async throws {
        let body = Data(#"{"choices":[{"message":{"content":"legacy"}}],"usage":{"prompt_tokens":7,"completion_tokens":2}}"#.utf8)
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "https://api.openai.test/v1/chat/completions",
            session: makeSession(body: body),
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.inputTokens == 7)
        #expect(response.outputTokens == 2)
    }

    @Test func emptyMessageContentThrowsInvalidResponse() async {
        let body = Data(#"{"choices":[{"message":{"content":""}}],"usage":{}}"#.utf8)
        let provider = OpenAIProvider(
            apiKey: "key",
            model: "gpt-test",
            baseURL: "https://api.openai.test/v1/chat/completions",
            session: makeSession(body: body),
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "u")
        }
    }

    @Test func malformedPayloadShapesThrowInvalidResponse() async {
        let malformedBodies = [
            Data(#"[]"#.utf8),
            Data(#"{"choices":[]}"#.utf8),
            Data(#"{"choices":[{"message":{"content":42}}],"usage":{}}"#.utf8)
        ]

        for body in malformedBodies {
            let provider = OpenAIProvider(
                apiKey: "key",
                model: "gpt-test",
                baseURL: "https://api.openai.test/v1/chat/completions",
                session: makeSession(body: body),
                sleep: { _ in }
            )

            await #expect(throws: AIError.self) {
                _ = try await provider.complete(system: "s", userMessage: "u")
            }
        }
    }
}

// MARK: - Responses Output Text Parsing

@Suite("OpenAIProvider Responses Output Text Parsing")
struct OpenAIProviderResponsesOutputTextParsingTests {

    @Test func parsesOutputTextWithModernUsage() async throws {
        let body = Data(#"{"output_text":"modern","usage":{"input_tokens":3,"output_tokens":1}}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.content == "modern")
        #expect(response.inputTokens == 3)
        #expect(response.outputTokens == 1)
    }

    @Test func missingUsageDefaultsToZeroForOutputText() async throws {
        let body = Data(#"{"output_text":"no usage"}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.content == "no usage")
        #expect(response.inputTokens == 0)
        #expect(response.outputTokens == 0)
    }

    @Test func emptyOutputTextFallsBackToOutputArray() async throws {
        let body = Data(#"{"output_text":"","output":[{"type":"message","content":[{"text":"fallback"}]}],"usage":{"input_tokens":2,"output_tokens":1}}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.content == "fallback")
        #expect(response.inputTokens == 2)
        #expect(response.outputTokens == 1)
    }
}

// MARK: - Responses Output Array Parsing

@Suite("OpenAIProvider Responses Output Array Parsing")
struct OpenAIProviderResponsesOutputArrayParsingTests {

    @Test func parsesOutputArrayWithNestedText() async throws {
        let body = Data(#"{"output":[{"type":"message","content":[{"text":"nested"}]}],"usage":{"input_tokens":4,"output_tokens":2}}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.content == "nested")
        #expect(response.inputTokens == 4)
        #expect(response.outputTokens == 2)
    }

    @Test func filtersNonMessageOutputTypes() async throws {
        let body = Data(#"{"output":[{"type":"function_call"},{"type":"message","content":[{"text":"only message"}]}],"usage":{"input_tokens":1,"output_tokens":1}}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.content == "only message")
    }

    @Test func skipsContentItemsLackingTextKey() async throws {
        let body = Data(#"{"output":[{"type":"message","content":[{"type":"input_text"},{"text":"visible"}]}],"usage":{"input_tokens":1,"output_tokens":1}}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.content == "visible")
    }

    @Test func multipleTextContentItemsAreJoined() async throws {
        let body = Data(#"{"output":[{"type":"message","content":[{"text":"part1"},{"text":"part2"}]}],"usage":{"input_tokens":1,"output_tokens":1}}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.content == "part1part2")
    }

    @Test func legacyUsageKeysParsedForOutputArray() async throws {
        let body = Data(#"{"output":[{"type":"message","content":[{"text":"legacy"}]}],"usage":{"prompt_tokens":6,"completion_tokens":3}}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.inputTokens == 6)
        #expect(response.outputTokens == 3)
    }

    @Test func missingUsageDefaultsToZeroForOutputArray() async throws {
        let body = Data(#"{"output":[{"type":"message","content":[{"text":"zero"}]}]}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        let response = try await provider.complete(system: "s", userMessage: "u")

        #expect(response.content == "zero")
        #expect(response.inputTokens == 0)
        #expect(response.outputTokens == 0)
    }

    @Test func allNonMessageTypesThrowsInvalidResponse() async {
        let body = Data(#"{"output":[{"type":"function_call"},{"type":"reasoning"}],"usage":{}}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "u")
        }
    }

    @Test func messageTypeWithAllContentMissingTextThrowsInvalidResponse() async {
        let body = Data(#"{"output":[{"type":"message","content":[{"type":"input_text"},{"type":"refusal"}]}],"usage":{}}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "u")
        }
    }

    @Test func emptyOutputArrayThrowsInvalidResponse() async {
        let body = Data(#"{"output":[],"usage":{}}"#.utf8)
        let provider = OpenAIProvider(apiKey: "key", model: "gpt-test", session: makeSession(body: body), sleep: { _ in })

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "u")
        }
    }
}
