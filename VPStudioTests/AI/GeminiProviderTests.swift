import Testing
import Foundation
@testable import VPStudio

// MARK: - GeminiProvider Tests

@Suite("GeminiProvider")
struct GeminiProviderTests {
    private final class CapturedRequest: @unchecked Sendable {
        private let lock = NSLock()
        private var url: URL?
        private var apiKeyHeader: String?

        func record(url: URL, apiKeyHeader: String?) {
            lock.lock()
            self.url = url
            self.apiKeyHeader = apiKeyHeader
            lock.unlock()
        }

        func capturedPath() -> String? {
            lock.lock()
            defer { lock.unlock() }
            return url?.path
        }

        func capturedAPIKeyHeader() -> String? {
            lock.lock()
            defer { lock.unlock() }
            return apiKeyHeader
        }
    }
    private final class SleepRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var recordedDelays: [TimeInterval] = []

        func record(_ delay: TimeInterval) {
            lock.lock()
            recordedDelays.append(delay)
            lock.unlock()
        }

        func values() -> [TimeInterval] {
            lock.lock()
            defer { lock.unlock() }
            return recordedDelays
        }
    }

    private func makeProvider(session: URLSession, model: String = "gemini-2.5-flash") -> GeminiProvider {
        GeminiProvider(apiKey: "test-key", model: model, session: session)
    }

    private func stubSession(
        statusCode: Int = 200,
        json: [String: Any]
    ) -> URLSession {
        URLProtocolHarness.makeSession { _ in
            let data = try JSONSerialization.data(withJSONObject: json)
            let response = HTTPURLResponse(
                url: URL(string: "https://generativelanguage.googleapis.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
    }

    private func rawSession(statusCode: Int = 200, body: Data) -> URLSession {
        URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
    }

    private func requestBodyData(from request: URLRequest) -> Data? {
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
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private func unexpectedNetworkSession(_ label: String) -> URLSession {
        URLProtocolHarness.makeSession { request in
            Issue.record("Unexpected Gemini request for \(label): \(request.url?.absoluteString ?? "nil")")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
    }

    // MARK: - Successful Response

    @Test func successfulResponseParsing() async throws {
        let responseJSON: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [["text": "Hello from Gemini!"]]
                    ]
                ]
            ],
            "usageMetadata": [
                "promptTokenCount": 42,
                "candidatesTokenCount": 15
            ]
        ]

        let session = stubSession(json: responseJSON)
        let provider = makeProvider(session: session)
        let result = try await provider.complete(system: "You are helpful.", userMessage: "Hi")

        #expect(result.provider == .gemini)
        #expect(result.content == "Hello from Gemini!")
        #expect(result.model == "gemini-2.5-flash")
        #expect(result.inputTokens == 42)
        #expect(result.outputTokens == 15)
    }

    @Test func trimsWhitespaceFromModelBeforeRequestAndResponse() async throws {
        let capture = CapturedRequest()
        let responseJSON: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [["text": "Hello from Gemini!"]]
                    ]
                ]
            ],
            "usageMetadata": [
                "promptTokenCount": 42,
                "candidatesTokenCount": 15
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: responseJSON)
        let provider = GeminiProvider(
            apiKey: "  test-key  ",
            model: "  gemini-2.5-flash  ",
            session: URLProtocolHarness.makeSession { request in
                capture.record(url: request.url!, apiKeyHeader: request.value(forHTTPHeaderField: "x-goog-api-key"))
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, data)
            },
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "You are helpful.", userMessage: "Hi")

        #expect(response.model == "gemini-2.5-flash")
        #expect(capture.capturedAPIKeyHeader() == "test-key")
        #expect(capture.capturedPath() == "/v1beta/models/gemini-2.5-flash:generateContent")
        #expect(response.inputTokens == 42)
        #expect(response.outputTokens == 15)
    }

    @Test func requestBodyIncludesSystemUserAndGenerationConfig() async throws {
        final class BodyCapture: @unchecked Sendable {
            private let lock = NSLock()
            private var body: Data?

            func record(_ data: Data?) {
                lock.lock()
                body = data
                lock.unlock()
            }

            func json() throws -> [String: Any] {
                lock.lock()
                let data = body
                lock.unlock()
                let requestData = try #require(data)
                return try #require(JSONSerialization.jsonObject(with: requestData) as? [String: Any])
            }
        }

        let capture = BodyCapture()
        let data = try JSONSerialization.data(withJSONObject: [
            "candidates": [["content": ["parts": [["text": "ok"]]]]]
        ])
        let provider = GeminiProvider(
            apiKey: "test-key",
            model: "gemini-2.5-flash",
            session: URLProtocolHarness.makeSession { request in
                capture.record(requestBodyData(from: request))
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, data)
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "system prompt", userMessage: "user prompt")
        let body = try capture.json()
        let systemInstruction = try #require(body["system_instruction"] as? [String: Any])
        let systemParts = try #require(systemInstruction["parts"] as? [[String: Any]])
        let contents = try #require(body["contents"] as? [[String: Any]])
        let firstContentParts = try #require(contents.first?["parts"] as? [[String: Any]])
        let config = try #require(body["generationConfig"] as? [String: Any])

        #expect(systemParts.first?["text"] as? String == "system prompt")
        #expect(firstContentParts.first?["text"] as? String == "user prompt")
        #expect(config["maxOutputTokens"] as? Int == 4096)
    }

    // MARK: - HTTP Error Handling

    @Test func httpErrorReturnsStatusAndBody() async throws {
        let errorJSON: [String: Any] = [
            "error": ["message": "Bad request", "code": 400]
        ]

        let session = stubSession(statusCode: 400, json: errorJSON)
        let provider = makeProvider(session: session)

        do {
            _ = try await provider.complete(system: "s", userMessage: "u")
            Issue.record("Expected AIError.httpError")
        } catch let error as AIError {
            if case .httpError(let code, let msg) = error {
                #expect(code == 400)
                #expect(msg.contains("Bad request"))
            } else {
                Issue.record("Unexpected AIError: \(error)")
            }
        }
    }

    @Test func httpErrorWithNonUTF8BodyUsesEmptyMessage() async {
        let provider = makeProvider(
            session: rawSession(statusCode: 500, body: Data([0xC3, 0x28]))
        )

        do {
            _ = try await provider.complete(system: "s", userMessage: "u")
            Issue.record("Expected AIError.httpError")
        } catch AIError.httpError(let status, let message) {
            #expect(status == 500)
            #expect(message == "")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Rate Limiting

    @Test func rateLimitedOn429() async throws {
        let session = stubSession(statusCode: 429, json: ["error": "rate limited"])
        let provider = makeProvider(session: session)

        do {
            _ = try await provider.complete(system: "s", userMessage: "u")
            Issue.record("Expected AIError.rateLimited")
        } catch let error as AIError {
            if case .rateLimited = error { /* OK */ }
            else { Issue.record("Expected rateLimited, got \(error)") }
        }
    }

    @Test func retriesRateLimitUsingRetryAfterHeader() async throws {
        final class Sequence: @unchecked Sendable {
            private let lock = NSLock()
            private var count = 0

            func makeSession() -> URLSession {
                URLProtocolHarness.makeSession { request in
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    self.count += 1

                    if self.count == 1 {
                        let response = HTTPURLResponse(
                            url: request.url!,
                            statusCode: 429,
                            httpVersion: nil,
                            headerFields: ["Retry-After": "0"]
                        )!
                        return (response, Data("{\"error\":\"slow down\"}".utf8))
                    }

                    let data = try JSONSerialization.data(withJSONObject: [
                        "candidates": [
                            [
                                "content": [
                                    "parts": [["text": "Retried Gemini!"]]
                                ]
                            ]
                        ]
                    ])
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    return (response, data)
                }
            }

            func requestCount() -> Int {
                lock.lock()
                defer { lock.unlock() }
                return count
            }
        }

        let sequence = Sequence()
        let sleepRecorder = SleepRecorder()
        let provider = GeminiProvider(
            apiKey: "test-key",
            model: "gemini-2.5-flash",
            session: sequence.makeSession(),
            sleep: { delay in sleepRecorder.record(delay) }
        )

        let result = try await provider.complete(system: "s", userMessage: "u")

        #expect(result.content == "Retried Gemini!")
        #expect(sequence.requestCount() == 2)
        #expect(sleepRecorder.values() == [0])
    }

    // MARK: - Blank Inputs

    @Test func blankAPIKeyThrowsBeforeNetwork() async {
        let provider = GeminiProvider(
            apiKey: " \n\t ",
            model: "gemini-2.5-flash",
            session: unexpectedNetworkSession("blank API key")
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "u")
        }
    }

    @Test func blankModelThrowsBeforeNetwork() async {
        let provider = GeminiProvider(
            apiKey: "test-key",
            model: " \n\t ",
            session: unexpectedNetworkSession("blank model")
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "s", userMessage: "u")
        }
    }

    // MARK: - Invalid Response

    @Test func invalidResponseOnMissingContent() async throws {
        let responseJSON: [String: Any] = [
            "candidates": [
                [
                    "content": ["parts": []]
                ]
            ]
        ]
        let session = stubSession(json: responseJSON)
        let provider = makeProvider(session: session)

        do {
            _ = try await provider.complete(system: "s", userMessage: "u")
            Issue.record("Expected AIError.invalidResponse")
        } catch let error as AIError {
            if case .invalidResponse = error { /* OK */ }
            else { Issue.record("Expected invalidResponse, got \(error)") }
        }
    }

    @Test func invalidResponseOnEmptyText() async throws {
        let responseJSON: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [["text": ""]]
                    ]
                ]
            ]
        ]
        let session = stubSession(json: responseJSON)
        let provider = makeProvider(session: session)

        do {
            _ = try await provider.complete(system: "s", userMessage: "u")
            Issue.record("Expected AIError.invalidResponse")
        } catch let error as AIError {
            if case .invalidResponse = error { /* OK */ }
            else { Issue.record("Expected invalidResponse, got \(error)") }
        }
    }

    @Test func malformedPayloadShapesThrowInvalidResponse() async {
        let malformedBodies = [
            Data(#"[]"#.utf8),
            Data(#"{"candidates":[]}"#.utf8),
            Data(#"{"candidates":[{"content":{"parts":[{}]}}]}"#.utf8),
            Data(#"{"candidates":[{"content":{"parts":[{"text":42}]}}]}"#.utf8)
        ]

        for body in malformedBodies {
            let provider = makeProvider(session: rawSession(body: body))
            await #expect(throws: AIError.self) {
                _ = try await provider.complete(system: "s", userMessage: "u")
            }
        }
    }

    @Test func missingUsageMetadataDefaultsToZero() async throws {
        let responseJSON: [String: Any] = [
            "candidates": [
                ["content": ["parts": [["text": "response"]]]]
            ]
        ]

        let session = stubSession(json: responseJSON)
        let provider = makeProvider(session: session)
        let result = try await provider.complete(system: "s", userMessage: "u")

        #expect(result.inputTokens == 0)
        #expect(result.outputTokens == 0)
    }

    @Test func missingPromptTokenCountDefaultsOnlyInputTokensToZero() async throws {
        let responseJSON: [String: Any] = [
            "candidates": [
                ["content": ["parts": [["text": "response"]]]]
            ],
            "usageMetadata": [
                "candidatesTokenCount": 12
            ]
        ]

        let session = stubSession(json: responseJSON)
        let provider = makeProvider(session: session)
        let result = try await provider.complete(system: "s", userMessage: "u")

        #expect(result.inputTokens == 0)
        #expect(result.outputTokens == 12)
    }

    @Test func missingCandidatesTokenCountDefaultsOnlyOutputTokensToZero() async throws {
        let responseJSON: [String: Any] = [
            "candidates": [
                ["content": ["parts": [["text": "response"]]]]
            ],
            "usageMetadata": [
                "promptTokenCount": 9
            ]
        ]

        let session = stubSession(json: responseJSON)
        let provider = makeProvider(session: session)
        let result = try await provider.complete(system: "s", userMessage: "u")

        #expect(result.inputTokens == 9)
        #expect(result.outputTokens == 0)
    }
}

// MARK: - AIProviderKind Gemini Tests

@Suite("AIProviderKind - Gemini")
struct AIProviderKindGeminiTests {

    @Test func geminiRawValue() {
        #expect(AIProviderKind.gemini.rawValue == "gemini")
    }

    @Test func geminiDisplayName() {
        #expect(AIProviderKind.gemini.displayName == "Google Gemini")
    }

    @Test func geminiIdMatchesRawValue() {
        #expect(AIProviderKind.gemini.id == "gemini")
    }
}

// MARK: - GeminiProvider Init Tests

@Suite("GeminiProvider Initialization")
struct GeminiProviderInitTests {

    @Test func defaultModel() {
        let provider = GeminiProvider(apiKey: "test-key")
        #expect(provider.providerKind == .gemini)
    }

    @Test func customModel() {
        let provider = GeminiProvider(apiKey: "test-key", model: "gemini-2.5-pro")
        #expect(provider.providerKind == .gemini)
    }
}
