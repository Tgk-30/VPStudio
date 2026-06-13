import Testing
import Foundation
@testable import VPStudio

@Suite("AnthropicProvider Request")
struct AnthropicProviderRequestTests {

    private final class CapturedRequest: @unchecked Sendable {
        private let lock = NSLock()
        private var request: URLRequest?

        func record(_ request: URLRequest) {
            lock.lock()
            self.request = request
            lock.unlock()
        }

        func header(_ name: String) -> String? {
            lock.lock()
            defer { lock.unlock() }
            return request?.value(forHTTPHeaderField: name)
        }

        func requestURL() -> URL? {
            lock.lock()
            defer { lock.unlock() }
            return request?.url
        }

        func method() -> String? {
            lock.lock()
            defer { lock.unlock() }
            return request?.httpMethod
        }

        func timeout() -> TimeInterval? {
            lock.lock()
            defer { lock.unlock() }
            return request?.timeoutInterval
        }

        func jsonBody() throws -> [String: Any] {
            lock.lock()
            let body = request.flatMap(Self.bodyData(from:))
            lock.unlock()
            let data = try #require(body)
            return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }

        private static func bodyData(from request: URLRequest) -> Data? {
            if let body = request.httpBody {
                return body
            }
            guard let stream = request.httpBodyStream else {
                return nil
            }
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read > 0 {
                    data.append(buffer, count: read)
                } else {
                    break
                }
            }
            return data.isEmpty ? nil : data
        }
    }

    private func makeSession(capturing capture: CapturedRequest, responseBody: Data) -> URLSession {
        URLProtocolHarness.makeSession { request in
            capture.record(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseBody)
        }
    }

    private func makeUnexpectedNetworkSession(_ label: String) -> URLSession {
        URLProtocolHarness.makeSession { request in
            Issue.record("Unexpected network request for \(label): \(request.url?.absoluteString ?? "nil")")
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
    }

    private func anthropicResponseJSON(content: String, usage: [String: Any]? = ["input_tokens": 7, "output_tokens": 3]) -> Data {
        var json: [String: Any] = [
            "content": [["text": content]]
        ]
        if let usage {
            json["usage"] = usage
        }
        return try! JSONSerialization.data(withJSONObject: json)
    }

    // MARK: - Request Body JSON Structure

    @Test func requestBodyIncludesModel() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "claude-test",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        _ = try await provider.complete(system: "s", userMessage: "m")
        let body = try capture.jsonBody()
        #expect(body["model"] as? String == "claude-test")
    }

    @Test func requestBodyIncludesMaxTokens4096() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "claude-test",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        _ = try await provider.complete(system: "s", userMessage: "m")
        let body = try capture.jsonBody()
        #expect(body["max_tokens"] as? Int == 4096)
    }

    @Test func requestBodyIncludesSystemPrompt() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "claude-test",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        _ = try await provider.complete(system: "system prompt", userMessage: "m")
        let body = try capture.jsonBody()
        #expect(body["system"] as? String == "system prompt")
    }

    @Test func requestBodyIncludesMessagesArrayWithUserRole() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "claude-test",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        _ = try await provider.complete(system: "s", userMessage: "hello")
        let body = try capture.jsonBody()
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages.first?["role"] as? String == "user")
        #expect(messages.first?["content"] as? String == "hello")
    }

    // MARK: - Trimming

    @Test func trimsWhitespaceFromAPIKeyBeforeValidationAndHeader() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "  key  ",
            model: "claude-test",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        _ = try await provider.complete(system: "s", userMessage: "m")
        #expect(capture.header("x-api-key") == "key")
    }

    @Test func trimsWhitespaceFromModelBeforeValidationAndBody() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "  claude-test  ",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        let response = try await provider.complete(system: "s", userMessage: "m")
        let body = try capture.jsonBody()
        #expect(body["model"] as? String == "claude-test")
        #expect(response.model == "claude-test")
    }

    @Test func trimsWhitespaceFromBaseURLBeforeRequest() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "claude-test",
            baseURL: "  https://api.anthropic.test/v1/messages  ",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        _ = try await provider.complete(system: "s", userMessage: "m")
        #expect(capture.requestURL()?.absoluteString == "https://api.anthropic.test/v1/messages")
    }

    // MARK: - Request Headers

    @Test func requestIncludesContentTypeHeader() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "claude-test",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        _ = try await provider.complete(system: "s", userMessage: "m")
        #expect(capture.header("Content-Type") == "application/json")
    }

    @Test func requestIncludesAnthropicVersionHeader() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "claude-test",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        _ = try await provider.complete(system: "s", userMessage: "m")
        #expect(capture.header("anthropic-version") == "2023-06-01")
    }

    @Test func requestUsesPOSTMethod() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "claude-test",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        _ = try await provider.complete(system: "s", userMessage: "m")
        #expect(capture.method() == "POST")
    }

    @Test func requestUses60SecondTimeout() async throws {
        let capture = CapturedRequest()
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "claude-test",
            session: makeSession(capturing: capture, responseBody: anthropicResponseJSON(content: "ok")),
            sleep: { _ in }
        )
        _ = try await provider.complete(system: "s", userMessage: "m")
        #expect(capture.timeout() == 60)
    }

    // MARK: - Blank Inputs Throw Before Network

    @Test func blankAPIKeyThrowsBeforeNetwork() async {
        let provider = AnthropicProvider(
            apiKey: "   ",
            model: "claude-test",
            session: URLProtocolHarness.makeSession { request in
                Issue.record("Unexpected network request for blank API key")
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
        )
        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "m")
        }
    }

    @Test func blankModelThrowsBeforeNetwork() async {
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "   ",
            session: URLProtocolHarness.makeSession { request in
                Issue.record("Unexpected network request for blank model")
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
        )
        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "m")
        }
    }

    @Test func blankAPIKeyAndModelThrowBeforeNetwork() async {
        let provider = AnthropicProvider(
            apiKey: "   ",
            model: "   ",
            session: URLProtocolHarness.makeSession { request in
                Issue.record("Unexpected network request for blank credentials")
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
        )
        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "m")
        }
    }

    @Test func blankBaseURLThrowsBeforeNetwork() async {
        let provider = AnthropicProvider(
            apiKey: "key",
            model: "claude-test",
            baseURL: " \n\t ",
            session: makeUnexpectedNetworkSession("blank base URL")
        )
        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "m")
        }
    }

    // MARK: - Response Parsing: Multiple Content Items

    @Test func usesOnlyFirstContentItemText() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"content":[{"text":"first"},{"text":"second"}],"usage":{"input_tokens":5,"output_tokens":2}}
            """
            return (response, Data(body.utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })
        let result = try await provider.complete(system: "s", userMessage: "m")
        #expect(result.content == "first")
    }

    @Test func ignoresNonTextKeysInFirstContentItem() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"content":[{"type":"text","text":"expected"}],"usage":{"input_tokens":1,"output_tokens":1}}
            """
            return (response, Data(body.utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })
        let result = try await provider.complete(system: "s", userMessage: "m")
        #expect(result.content == "expected")
    }

    // MARK: - Response Parsing: Missing Usage Fields

    @Test func defaultsInputTokensToZeroWhenMissing() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"content":[{"text":"ok"}],"usage":{"output_tokens":3}}"#
            return (response, Data(body.utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })
        let result = try await provider.complete(system: "s", userMessage: "m")
        #expect(result.inputTokens == 0)
        #expect(result.outputTokens == 3)
    }

    @Test func defaultsOutputTokensToZeroWhenMissing() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"content":[{"text":"ok"}],"usage":{"input_tokens":4}}"#
            return (response, Data(body.utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })
        let result = try await provider.complete(system: "s", userMessage: "m")
        #expect(result.inputTokens == 4)
        #expect(result.outputTokens == 0)
    }

    @Test func defaultsBothTokensToZeroWhenUsageMissing() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"content":[{"text":"ok"}]}"#
            return (response, Data(body.utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })
        let result = try await provider.complete(system: "s", userMessage: "m")
        #expect(result.inputTokens == 0)
        #expect(result.outputTokens == 0)
    }

    @Test func defaultsTokensToZeroWhenUsageValuesAreNull() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"content":[{"text":"ok"}],"usage":{"input_tokens":null,"output_tokens":null}}"#
            return (response, Data(body.utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })
        let result = try await provider.complete(system: "s", userMessage: "m")
        #expect(result.inputTokens == 0)
        #expect(result.outputTokens == 0)
    }

    // MARK: - Response Parsing: Empty Content Array

    @Test func emptyContentArrayThrowsInvalidResponse() async {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"content":[],"usage":{"input_tokens":1,"output_tokens":1}}"#
            return (response, Data(body.utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })
        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "m")
        }
    }

    @Test func malformedContentPayloadShapesThrowInvalidResponse() async {
        let malformedBodies = [
            Data(#"[]"#.utf8),
            Data(#"{"content":[{}],"usage":{}}"#.utf8),
            Data(#"{"content":[{"text":42}],"usage":{}}"#.utf8)
        ]

        for body in malformedBodies {
            let session = URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, body)
            }
            let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })

            await #expect(throws: AIError.self) {
                _ = try await provider.complete(system: "s", userMessage: "m")
            }
        }
    }

    // MARK: - Response Structure

    @Test func responseIncludesCorrectProviderKind() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"content":[{"text":"ok"}],"usage":{"input_tokens":1,"output_tokens":1}}"#
            return (response, Data(body.utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })
        let result = try await provider.complete(system: "s", userMessage: "m")
        #expect(result.provider == .anthropic)
    }

    @Test func responseIncludesTrimmedModel() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"content":[{"text":"ok"}],"usage":{"input_tokens":1,"output_tokens":1}}"#
            return (response, Data(body.utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "  claude-model  ", session: session, sleep: { _ in })
        let result = try await provider.complete(system: "s", userMessage: "m")
        #expect(result.model == "claude-model")
    }

    @Test func responsePassesThroughContentText() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"content":[{"text":"parsed content"}],"usage":{"input_tokens":2,"output_tokens":5}}"#
            return (response, Data(body.utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })
        let result = try await provider.complete(system: "s", userMessage: "m")
        #expect(result.content == "parsed content")
    }

    // MARK: - HTTP Errors

    @Test func httpErrorThrowsWithStatusAndMessage() async {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("internal error".utf8))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })
        do {
            _ = try await provider.complete(system: "s", userMessage: "m")
            Issue.record("Expected HTTP error")
        } catch AIError.httpError(let status, let message) {
            #expect(status == 500)
            #expect(message == "internal error")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func httpErrorWithNonUTF8BodyUsesEmptyMessage() async {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 502, httpVersion: nil, headerFields: nil)!
            return (response, Data([0xC3, 0x28]))
        }
        let provider = AnthropicProvider(apiKey: "key", model: "claude-test", session: session, sleep: { _ in })

        do {
            _ = try await provider.complete(system: "s", userMessage: "m")
            Issue.record("Expected HTTP error")
        } catch AIError.httpError(let status, let message) {
            #expect(status == 502)
            #expect(message == "")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
