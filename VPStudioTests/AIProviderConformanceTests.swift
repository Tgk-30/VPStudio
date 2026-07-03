import Foundation
import Testing
@testable import VPStudio

// MARK: - AIProvider Protocol Conformance Tests

private func acceptsAIProvider<T: AIProvider>(_ value: T) -> Bool {
    _ = value
    return true
}

@Suite("AIProvider Conformance")
struct AIProviderConformanceTests {

    @Test func openAIProviderConformsToAIProvider() {
        let provider = OpenAIProvider(apiKey: "test-key")
        #expect(acceptsAIProvider(provider))
    }

    @Test func openRouterProviderConformsToAIProvider() {
        let provider = OpenRouterProvider(apiKey: "test-key")
        #expect(acceptsAIProvider(provider))
    }

    @Test func ollamaProviderConformsToAIProvider() {
        let provider = OllamaProvider(baseURL: "http://localhost:11434")
        #expect(acceptsAIProvider(provider))
    }

    @Test func geminiProviderConformsToAIProvider() {
        let provider = GeminiProvider(apiKey: "test-key")
        #expect(acceptsAIProvider(provider))
    }

    @Test func anthropicProviderConformsToAIProvider() {
        let provider = AnthropicProvider(apiKey: "test-key")
        #expect(acceptsAIProvider(provider))
    }

    @Test func mistralProviderConformsToAIProvider() {
        let provider = MistralProvider(apiKey: "test-key")
        #expect(acceptsAIProvider(provider))
    }

    @Test func minimaxProviderConformsToAIProvider() {
        let provider = MiniMaxProvider(apiKey: "test-key")
        #expect(acceptsAIProvider(provider))
    }
}

// MARK: - AIProviderKind Display Name Tests

@Suite("AIProviderKind Display Names")
struct AIProviderKindDisplayNameTests {

    @Test func allProviderKindsHaveNonEmptyDisplayNames() {
        for kind in AIProviderKind.allCases {
            #expect(!kind.displayName.isEmpty)
        }
    }

    @Test func openAIHasCorrectDisplayName() {
        #expect(AIProviderKind.openAI.displayName == "OpenAI")
    }

    @Test func anthropicHasCorrectDisplayName() {
        #expect(AIProviderKind.anthropic.displayName == "Anthropic")
    }

    @Test func ollamaHasCorrectDisplayName() {
        #expect(AIProviderKind.ollama.displayName == "Ollama")
    }

    @Test func openRouterHasCorrectDisplayName() {
        #expect(AIProviderKind.openRouter.displayName == "OpenRouter")
    }

    @Test func geminiHasCorrectDisplayName() {
        #expect(AIProviderKind.gemini.displayName == "Google Gemini")
    }

    @Test func mistralHasCorrectDisplayName() {
        #expect(AIProviderKind.mistral.displayName == "Mistral")
    }

    @Test func minimaxHasCorrectDisplayName() {
        #expect(AIProviderKind.minimax.displayName == "MiniMax")
    }

    @Test func localMLXHasCorrectDisplayName() {
        #expect(AIProviderKind.local.displayName == "On-Device (Local)")
    }
}

// MARK: - AIProviderResponse Tests

@Suite("AIProviderResponse")
struct AIProviderResponseTests {

    @Test func responseStoresProviderKind() {
        let response = AIProviderResponse(
            provider: .openAI,
            content: "Hello",
            model: "gpt-4o",
            inputTokens: 10,
            outputTokens: 5
        )
        #expect(response.provider == .openAI)
    }

    @Test func responseStoresContent() {
        let response = AIProviderResponse(
            provider: .anthropic,
            content: "Response content",
            model: "claude-3",
            inputTokens: 20,
            outputTokens: 15
        )
        #expect(response.content == "Response content")
    }

    @Test func responseStoresModel() {
        let response = AIProviderResponse(
            provider: .openRouter,
            content: "test",
            model: "anthropic/claude-3-haiku",
            inputTokens: 5,
            outputTokens: 10
        )
        #expect(response.model == "anthropic/claude-3-haiku")
    }

    @Test func responseStoresTokenCounts() {
        let response = AIProviderResponse(
            provider: .ollama,
            content: "output",
            model: "llama3",
            inputTokens: 100,
            outputTokens: 50
        )
        #expect(response.inputTokens == 100)
        #expect(response.outputTokens == 50)
    }
}

// MARK: - LocalMLXProvider Conformance Tests

@Suite("LocalMLXProvider Conformance")
struct LocalMLXProviderConformanceTests {

    @Test func localMLXProviderConformsToAIProvider() {
        let database = try! DatabaseManager(inMemoryNamed: "local-mlx-provider-\(UUID().uuidString)")
        let engine = LocalInferenceEngine(catalogStore: LocalModelCatalogStore(database: database))
        let provider = LocalMLXProvider(inferenceEngine: engine, modelID: "test-model")
        #expect(acceptsAIProvider(provider))
    }

    @Test func localMLXProviderProviderKindIsLocalMLX() {
        let database = try! DatabaseManager(inMemoryNamed: "local-mlx-provider-kind-\(UUID().uuidString)")
        let engine = LocalInferenceEngine(catalogStore: LocalModelCatalogStore(database: database))
        let provider = LocalMLXProvider(inferenceEngine: engine, modelID: "test-model")
        #expect(provider.providerKind == .local)
    }
}
