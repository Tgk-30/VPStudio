import Foundation

/// Ollama local LLM provider
struct OllamaProvider: AIProvider, Sendable {
    let providerKind: AIProviderKind = .ollama
    private let baseURL: String
    private let model: String
    private let session: URLSession
    private let sleep: AIHTTPSleep

    init(
        baseURL: String = "http://localhost:11434",
        model: String = "llama3.1",
        session: URLSession = AIHTTPTransport.defaultSession,
        sleep: @escaping AIHTTPSleep = AIHTTPTransport.defaultSleep
    ) {
        self.baseURL = baseURL
        self.model = model
        self.session = session
        self.sleep = sleep
    }

    func complete(system: String, userMessage: String) async throws -> AIProviderResponse {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBaseURL.isEmpty, !trimmedModel.isEmpty else {
            throw AIError.invalidResponse
        }

        let body: [String: Any] = [
            "model": trimmedModel,
            "stream": false,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": userMessage]
            ]
        ]

        guard let url = AIOllamaEndpointPolicy.appendingPath(to: trimmedBaseURL, path: "api/chat") else {
            throw AIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120 // Ollama can be slow

        let (data, http) = try await AIHTTPTransport.perform(request, using: session, sleep: sleep)

        guard (200...299).contains(http.statusCode) else {
            let msg = AIHTTPTransport.sanitizedHTTPErrorMessage(from: data)
            throw AIError.httpError(http.statusCode, msg)
        }

        let json = try Self.parseResponseJSON(from: data)
        let message = json?["message"] as? [String: Any]
        guard let content = message?["content"] as? String, !content.isEmpty else {
            throw AIError.invalidResponse
        }

        return AIProviderResponse(
            provider: .ollama,
            content: content,
            model: trimmedModel,
            inputTokens: 0,
            outputTokens: 0
        )
    }

    private static func parseResponseJSON(from data: Data) throws -> [String: Any]? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        } catch {
            // Ollama may stream newline-delimited JSON objects even when stream=false.
            // Fall through and try extracting the first complete object.
        }

        guard let leadingObjectData = firstJSONObjectData(in: data) else {
            throw AIError.invalidResponse
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: leadingObjectData) as? [String: Any] else {
                throw AIError.invalidResponse
            }
            return json
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.invalidResponse
        }
    }

    private static func firstJSONObjectData(in data: Data) -> Data? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }

        var depth = 0
        var startIndex: String.Index?
        var isInsideString = false
        var isEscaping = false

        for index in string.indices {
            let character = string[index]

            if isInsideString {
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == "\"" {
                    isInsideString = false
                }
                continue
            }

            switch character {
            case "\"":
                isInsideString = true
            case "{":
                if depth == 0 {
                    startIndex = index
                }
                depth += 1
            case "}":
                guard depth > 0 else { continue }
                depth -= 1
                if depth == 0, let startIndex {
                    let endIndex = string.index(after: index)
                    return String(string[startIndex..<endIndex]).data(using: .utf8)
                }
            default:
                continue
            }
        }

        return nil
    }
}
