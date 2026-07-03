import Foundation

struct MiniMaxProvider: AIProvider, Sendable {
    let providerKind: AIProviderKind = .minimax
    private let provider: OpenAICompatibleChatProvider

    init(
        apiKey: String,
        model: String = "MiniMax-M3",
        baseURL: String = "https://api.minimax.io/v1/chat/completions",
        session: URLSession = AIHTTPTransport.defaultSession,
        sleep: @escaping AIHTTPSleep = AIHTTPTransport.defaultSleep
    ) {
        provider = OpenAICompatibleChatProvider(
            providerKind: .minimax,
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
