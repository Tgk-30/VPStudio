import Foundation

struct MistralProvider: AIProvider, Sendable {
    let providerKind: AIProviderKind = .mistral
    private let provider: OpenAICompatibleChatProvider

    init(
        apiKey: String,
        model: String = "mistral-small-latest",
        baseURL: String = "https://api.mistral.ai/v1/chat/completions",
        session: URLSession = AIHTTPTransport.defaultSession,
        sleep: @escaping AIHTTPSleep = AIHTTPTransport.defaultSleep
    ) {
        provider = OpenAICompatibleChatProvider(
            providerKind: .mistral,
            apiKey: apiKey,
            model: model,
            chatCompletionsURL: baseURL,
            session: session,
            sleep: sleep
        )
    }

    func complete(system: String, userMessage: String) async throws -> AIProviderResponse {
        try await provider.complete(system: system, userMessage: userMessage)
    }
}
