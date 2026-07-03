import Foundation
import Testing
@testable import VPStudio

@Suite("OpenAI-Compatible Chat Provider")
struct OpenAICompatibleChatProviderTests {
    @Test func requestBodyUsesChatCompletionShape() throws {
        let provider = OpenAICompatibleChatProvider(
            providerKind: .mistral,
            apiKey: "test-key",
            model: " mistral-small-latest ",
            chatCompletionsURL: "https://api.example.com/v1/chat/completions",
            session: .shared,
            sleep: { _ in }
        )

        let body = provider.requestBody(system: "System", userMessage: "User")

        #expect(body["model"] as? String == "mistral-small-latest")
        #expect(body["max_tokens"] as? Int == 4096)
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages[0] == ["role": "system", "content": "System"])
        #expect(messages[1] == ["role": "user", "content": "User"])
    }

    @Test func parseChatCompletionReadsContentAndTokenUsage() throws {
        let json = """
        {
          "choices": [
            { "message": { "role": "assistant", "content": "Done" } }
          ],
          "usage": {
            "prompt_tokens": 12,
            "completion_tokens": 7
          }
        }
        """
        let result = try OpenAICompatibleChatProvider.parseChatCompletion(data: Data(json.utf8))

        #expect(result.content == "Done")
        #expect(result.inputTokens == 12)
        #expect(result.outputTokens == 7)
    }

    @Test func parseChatCompletionDefaultsMissingUsageToZeroTokens() throws {
        let json = """
        {
          "choices": [
            { "message": { "content": "No usage block" } }
          ]
        }
        """
        let result = try OpenAICompatibleChatProvider.parseChatCompletion(data: Data(json.utf8))

        #expect(result.content == "No usage block")
        #expect(result.inputTokens == 0)
        #expect(result.outputTokens == 0)
    }

    @Test func completeSetsBearerAuthorizationTimeoutAndChatBody() async throws {
        let session = URLProtocolHarness.makeSession { request in
            #expect(request.httpMethod == "POST")
            #expect(request.timeoutInterval == 90)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer trimmed-key")

            let bodyData = try #require(Self.requestBodyData(from: request))
            let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            #expect(body["model"] as? String == "mistral-small-latest")
            let messages = try #require(body["messages"] as? [[String: String]])
            #expect(messages == [
                ["role": "system", "content": "System"],
                ["role": "user", "content": "User"],
            ])
            #expect(body["max_tokens"] as? Int == 4096)

            let json = """
            {
              "choices": [
                { "message": { "content": "Complete" } }
              ],
              "usage": {
                "prompt_tokens": 3,
                "completion_tokens": 4
              }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
        let provider = OpenAICompatibleChatProvider(
            providerKind: .mistral,
            apiKey: " trimmed-key ",
            model: " mistral-small-latest ",
            chatCompletionsURL: "https://api.example.com/v1/chat/completions",
            session: session,
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "System", userMessage: "User")

        #expect(response.provider == .mistral)
        #expect(response.content == "Complete")
        #expect(response.model == "mistral-small-latest")
        #expect(response.inputTokens == 3)
        #expect(response.outputTokens == 4)
    }

    @Test func mistralProviderCompleteDelegatesToConfiguredChatEndpoint() async throws {
        let session = URLProtocolHarness.makeSession { request in
            #expect(request.url?.absoluteString == "https://api.example.com/mistral/chat")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer wrapped-key")

            let bodyData = try #require(Self.requestBodyData(from: request))
            let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            #expect(body["model"] as? String == "mistral-test-model")

            let json = """
            {
              "choices": [
                { "message": { "content": "Mistral response" } }
              ],
              "usage": {
                "prompt_tokens": 5,
                "completion_tokens": 6
              }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
        let provider = MistralProvider(
            apiKey: " wrapped-key ",
            model: "mistral-test-model",
            baseURL: "https://api.example.com/mistral/chat",
            session: session,
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "System", userMessage: "User")

        #expect(response.provider == .mistral)
        #expect(response.content == "Mistral response")
        #expect(response.model == "mistral-test-model")
        #expect(response.inputTokens == 5)
        #expect(response.outputTokens == 6)
    }

    @Test func miniMaxProviderCompleteDelegatesToConfiguredChatEndpoint() async throws {
        let session = URLProtocolHarness.makeSession { request in
            #expect(request.url?.absoluteString == "https://api.example.com/minimax/chat")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer minimax-key")

            let bodyData = try #require(Self.requestBodyData(from: request))
            let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            #expect(body["model"] as? String == "MiniMax-test-model")

            let json = """
            {
              "choices": [
                { "message": { "content": "MiniMax response" } }
              ],
              "usage": {
                "prompt_tokens": 7,
                "completion_tokens": 8
              }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
        let provider = MiniMaxProvider(
            apiKey: " minimax-key ",
            model: "MiniMax-test-model",
            baseURL: "https://api.example.com/minimax/chat",
            session: session,
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "System", userMessage: "User")

        #expect(response.provider == .minimax)
        #expect(response.content == "MiniMax response")
        #expect(response.model == "MiniMax-test-model")
        #expect(response.inputTokens == 7)
        #expect(response.outputTokens == 8)
    }

    @Test func completeThrowsHTTPErrorWithResponseBody() async {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data("bad key".utf8))
        }
        let provider = OpenAICompatibleChatProvider(
            providerKind: .minimax,
            apiKey: "key",
            model: "model",
            chatCompletionsURL: "https://api.example.com/v1/chat/completions",
            session: session,
            sleep: { _ in }
        )

        do {
            _ = try await provider.complete(system: "s", userMessage: "m")
            Issue.record("Expected HTTP error")
        } catch AIError.httpError(let status, let message) {
            #expect(status == 401)
            #expect(message == "bad key")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func completeRedactsSecretsFromHTTPErrorBody() async {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let bearerSecret = "sk_" + "test_secret"
            let authorizationPrefix = "Authorization: " + "Bearer"
            let body = """
            auth failed \(authorizationPrefix) \(bearerSecret) callback=https://api.example.com/error?token=secret-token&quality=1080p
            """
            return (response, Data(body.utf8))
        }
        let provider = OpenAICompatibleChatProvider(
            providerKind: .minimax,
            apiKey: "key",
            model: "model",
            chatCompletionsURL: "https://api.example.com/v1/chat/completions",
            session: session,
            sleep: { _ in }
        )

        do {
            _ = try await provider.complete(system: "s", userMessage: "m")
            Issue.record("Expected HTTP error")
        } catch AIError.httpError(let status, let message) {
            #expect(status == 401)
            #expect(message.contains("Bearer REDACTED"))
            #expect(message.contains("token=REDACTED"))
            #expect(message.contains("quality=1080p"))
            #expect(!message.contains("sk_" + "test_secret"))
            #expect(!message.contains("secret-token"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func completeThrowsHTTPErrorWithEmptyMessageForNonUTF8Body() async {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 502, httpVersion: nil, headerFields: nil)!
            return (response, Data([0xFF, 0xFE, 0xFD]))
        }
        let provider = OpenAICompatibleChatProvider(
            providerKind: .mistral,
            apiKey: "key",
            model: "model",
            chatCompletionsURL: "https://api.example.com/v1/chat/completions",
            session: session,
            sleep: { _ in }
        )

        do {
            _ = try await provider.complete(system: "s", userMessage: "m")
            Issue.record("Expected HTTP error")
        } catch AIError.httpError(let status, let message) {
            #expect(status == 502)
            #expect(message.isEmpty)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func completeRejectsBlankCredentialsModelAndMalformedURL() async {
        let validSession = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{}".utf8))
        }

        let blankKeyProvider = OpenAICompatibleChatProvider(
            providerKind: .mistral,
            apiKey: " ",
            model: "model",
            chatCompletionsURL: "https://api.example.com/v1/chat/completions",
            session: validSession,
            sleep: { _ in }
        )
        let blankModelProvider = OpenAICompatibleChatProvider(
            providerKind: .mistral,
            apiKey: "key",
            model: " ",
            chatCompletionsURL: "https://api.example.com/v1/chat/completions",
            session: validSession,
            sleep: { _ in }
        )
        let malformedURLProvider = OpenAICompatibleChatProvider(
            providerKind: .mistral,
            apiKey: "key",
            model: "model",
            chatCompletionsURL: "not a url",
            session: validSession,
            sleep: { _ in }
        )
        let blankURLProvider = OpenAICompatibleChatProvider(
            providerKind: .mistral,
            apiKey: "key",
            model: "model",
            chatCompletionsURL: "  ",
            session: validSession,
            sleep: { _ in }
        )

        for provider in [blankKeyProvider, blankModelProvider, malformedURLProvider, blankURLProvider] {
            do {
                _ = try await provider.complete(system: "s", userMessage: "m")
                Issue.record("Expected invalid response")
            } catch AIError.invalidResponse {
                continue
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test func completeTrimsWhitespaceFromBaseURLBeforeRequest() async throws {
        let session = URLProtocolHarness.makeSession { request in
            #expect(request.url?.absoluteString == "https://api.example.com/v1/chat/completions")
            let json = """
            {
              "choices": [
                { "message": { "content": "trimmed" } }
              ]
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let provider = OpenAICompatibleChatProvider(
            providerKind: .minimax,
            apiKey: "key",
            model: "model",
            chatCompletionsURL: "  https://api.example.com/v1/chat/completions  ",
            session: session,
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "System", userMessage: "User")
        #expect(response.content == "trimmed")
    }

    @Test func parseChatCompletionThrowsWhenContentIsMissingOrEmpty() {
        let missingContent = Data("""
        { "choices": [ { "message": { "role": "assistant" } } ] }
        """.utf8)
        let emptyContent = Data("""
        { "choices": [ { "message": { "content": "" } } ] }
        """.utf8)

        for payload in [missingContent, emptyContent] {
            do {
                _ = try OpenAICompatibleChatProvider.parseChatCompletion(data: payload)
                Issue.record("Expected invalid response")
            } catch AIError.invalidResponse {
                continue
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test func parseChatCompletionThrowsForInvalidPayloadShapes() {
        let nonDictionaryRoot = Data("""
        [ { "choices": [] } ]
        """.utf8)
        let emptyChoices = Data("""
        { "choices": [] }
        """.utf8)
        let nonStringContent = Data("""
        { "choices": [ { "message": { "content": 42 } } ] }
        """.utf8)

        for payload in [nonDictionaryRoot, emptyChoices, nonStringContent] {
            do {
                _ = try OpenAICompatibleChatProvider.parseChatCompletion(data: payload)
                Issue.record("Expected invalid response")
            } catch AIError.invalidResponse {
                continue
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    private static func requestBodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 {
                return nil
            }
            if count == 0 {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}
