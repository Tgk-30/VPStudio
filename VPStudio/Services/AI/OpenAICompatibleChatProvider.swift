import Foundation

struct OpenAICompatibleChatProvider: Sendable {
    let providerKind: AIProviderKind
    let apiKey: String
    let model: String
    let chatCompletionsURL: String
    let session: URLSession
    let sleep: AIHTTPSleep

    func complete(system: String, userMessage: String) async throws -> AIProviderResponse {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseURL = chatCompletionsURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty, !trimmedModel.isEmpty else {
            throw AIError.invalidResponse
        }
        guard !trimmedBaseURL.isEmpty else {
            throw AIError.invalidResponse
        }
        guard let url = AICloudEndpointPolicy.validatedEndpoint(from: trimmedBaseURL) else {
            throw AIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(system: system, userMessage: userMessage))

        let (data, http) = try await AIHTTPTransport.perform(request, using: session, sleep: sleep)
        guard (200...299).contains(http.statusCode) else {
            let msg = AIHTTPTransport.sanitizedHTTPErrorMessage(from: data)
            throw AIError.httpError(http.statusCode, msg)
        }

        let parsed = try Self.parseChatCompletion(data: data)
        return AIProviderResponse(
            provider: providerKind,
            content: parsed.content,
            model: trimmedModel,
            inputTokens: parsed.inputTokens,
            outputTokens: parsed.outputTokens
        )
    }

    func requestBody(system: String, userMessage: String) -> [String: Any] {
        [
            "model": model.trimmingCharacters(in: .whitespacesAndNewlines),
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": userMessage],
            ],
            "max_tokens": 4096,
        ]
    }

    static func parseChatCompletion(data: Data) throws -> (content: String, inputTokens: Int, outputTokens: Int) {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let content = message?["content"] as? String, !content.isEmpty else {
            throw AIError.invalidResponse
        }
        let usage = json?["usage"] as? [String: Any]
        return (
            content,
            usage?["prompt_tokens"] as? Int ?? 0,
            usage?["completion_tokens"] as? Int ?? 0
        )
    }
}
