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

@Suite("OllamaProvider")
struct OllamaProviderTests {
    @Test func completeReturnsResponseForValidRequest() async throws {
        let body = Data(#"{"message":{"content":"hello from ollama"}},"#.utf8)
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, body)
            },
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "system", userMessage: "user")

        #expect(response.content == "hello from ollama")
        #expect(response.model == "llama3.1")
        #expect(response.provider == .ollama)
    }

    @Test func completeParsesFirstObjectFromNoisyStreamingResponseWithEscapes() async throws {
        let body = Data(#"event: {"message":{"content":"brace } and escaped \" quote"}}\n{"done":true}"#.utf8)
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, body)
            },
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "system", userMessage: "user")

        #expect(response.content == #"brace } and escaped " quote"#)
    }

    @Test func completeConstructsCorrectURL() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
        }
        let state = State()

        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                state.requestURL = request.url
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"content":"test"}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.requestURL?.absoluteString == "http://localhost:11434/api/chat")
    }

    @Test func completeTrimsBaseURL() async throws {
        final class State: @unchecked Sendable {
            var requestURL: URL?
        }
        let state = State()

        let provider = OllamaProvider(
            baseURL: "  http://localhost:11434  ",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                state.requestURL = request.url
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"content":"test"}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.requestURL?.absoluteString == "http://localhost:11434/api/chat")
    }

    @Test func completeTrimsModel() async throws {
        let body = Data(#"{"message":{"content":"test"}}"#.utf8)
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "  llama3.1  ",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, body)
            },
            sleep: { _ in }
        )

        let response = try await provider.complete(system: "sys", userMessage: "user")

        #expect(response.model == "llama3.1")
    }

    @Test func completeSendsPOSTRequest() async throws {
        final class State: @unchecked Sendable {
            var method: String?
        }
        let state = State()

        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                state.method = request.httpMethod
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"content":"test"}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.method == "POST")
    }

    @Test func completeIncludesMessagesInBody() async throws {
        final class State: @unchecked Sendable {
            var messages: [[String: Any]]?
        }
        let state = State()

        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                if let body = request.httpBody ?? readStream(request.httpBodyStream),
                   let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                   let msgs = json["messages"] as? [[String: Any]] {
                    state.messages = msgs
                }
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"content":"test"}}"#
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

    @Test func completeSetsCorrectContentType() async throws {
        final class State: @unchecked Sendable {
            var contentType: String?
        }
        let state = State()

        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                state.contentType = request.value(forHTTPHeaderField: "Content-Type")
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"content":"test"}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.contentType == "application/json")
    }

    @Test func completeSetsStreamToFalse() async throws {
        final class State: @unchecked Sendable {
            var streamValue: Bool?
        }
        let state = State()

        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                if let body = request.httpBody ?? readStream(request.httpBodyStream),
                   let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                    state.streamValue = json["stream"] as? Bool
                }
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"content":"test"}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.streamValue == false)
    }

    @Test func completeUsesLongerTimeout() async throws {
        final class State: @unchecked Sendable {
            var timeout: TimeInterval?
        }
        let state = State()

        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                state.timeout = request.timeoutInterval
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"content":"test"}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        _ = try await provider.complete(system: "sys", userMessage: "user")

        #expect(state.timeout == 120)
    }

    @Test func completeThrowsForEmptyBaseURL() async throws {
        let provider = OllamaProvider(
            baseURL: "",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"content":"test"}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsForEmptyModel() async throws {
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "   ",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"content":"test"}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsForNon2xxStatus() async throws {
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data("Internal Server Error".utf8))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsHTTPErrorWithEmptyMessageForNonUTF8Body() async {
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 502, httpVersion: nil, headerFields: nil)!
                return (response, Data([0xC3, 0x28]))
            },
            sleep: { _ in }
        )

        do {
            _ = try await provider.complete(system: "sys", userMessage: "user")
            Issue.record("Expected HTTP error")
        } catch AIError.httpError(let status, let message) {
            #expect(status == 502)
            #expect(message == "")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func completeThrowsForInvalidJSONResponse() async throws {
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("invalid json".utf8))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsForMalformedLeadingStreamingObject() async throws {
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"event: {"message":{"content":"broken"}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsForNonUTF8SuccessBody() async throws {
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data([0xC3, 0x28]))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsForMissingMessageContent() async throws {
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"role":"assistant"}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }

    @Test func completeThrowsForEmptyMessageContent() async throws {
        let provider = OllamaProvider(
            baseURL: "http://localhost:11434",
            model: "llama3.1",
            session: URLProtocolHarness.makeSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body = #"{"message":{"content":""}}"#
                return (response, Data(body.utf8))
            },
            sleep: { _ in }
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.complete(system: "sys", userMessage: "user")
        }
    }
}
