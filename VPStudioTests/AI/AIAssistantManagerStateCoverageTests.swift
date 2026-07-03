import Foundation
import Testing
@testable import VPStudio

@Suite("AI Assistant Manager State Coverage")
struct AIAssistantManagerStateCoverageTests {
    @Test
    func clearProvidersRemovesRegisteredProvidersAndConfiguredModels() async throws {
        let database = try DatabaseManager(inMemoryNamed: "ai-clear-providers-\(UUID().uuidString)")
        let manager = AIAssistantManager(database: database)
        let provider = StubAIProvider(
            providerKind: .openAI,
            result: .success(AIProviderResponse(
                provider: .openAI,
                content: "[]",
                model: AIModelCatalog.gpt4oMini.id,
                inputTokens: 1,
                outputTokens: 1
            ))
        )

        await manager.registerProvider(kind: .openAI, provider: provider)
        #expect(await manager.hasConfiguredProvider)

        await manager.clearProviders()
        #expect(await manager.hasConfiguredProvider == false)
    }

    @Test
    func assistantContextBudgetConstantsStayWithinSnapshotLimits() {
        #expect(AssistantContextAssembler.maxContextNotes == 30)
        #expect(AssistantContextAssembler.maxCandidateTitles == 100)
        #expect(AssistantContextAssembler.maxWatchHistoryEntries == 80)
        #expect(AssistantContextAssembler.maxTasteEvents == 100)
        #expect(AssistantContextAssembler.maxWatchlistTitles == 50)
        #expect(AssistantContextAssembler.maxFavoritesTitles == 50)
        #expect(AssistantContextAssembler.maxSearchQueries == 20)
        #expect(AssistantContextAssembler.maxFolderNames == 20)
        #expect(AssistantContextAssembler.recencyWindowDays == 90)
        #expect(AssistantContextAssembler.recencyFloor == 0.1)
    }

    @Test
    func aiHTTPTransportDefaultsUseEphemeralSessionAndClampNegativeSleep() async throws {
        let configuration = AIHTTPTransport.defaultSession.configuration

        #expect(configuration.timeoutIntervalForRequest == 60)
        #expect(configuration.timeoutIntervalForResource == 120)
        #expect(configuration.httpShouldSetCookies == false)

        try await AIHTTPTransport.defaultSleep(-1)
    }

    @Test
    func aiHTTPTransportRedactsSecretsFromHTTPErrorBodies() {
        let bearerSecret = "sk_" + "test_secret"
        let authorizationPrefix = "Authorization: " + "Bearer"
        let apiKeyName = "api_" + "key"
        let message = """
        upstream echoed \(authorizationPrefix) \(bearerSecret) and https://api.example.com/fail?\(apiKeyName)=leaked-token&detail=bad
        """
        let redacted = AIHTTPTransport.sanitizedHTTPErrorMessage(from: Data(message.utf8))

        #expect(redacted.contains("Bearer REDACTED"))
        #expect(redacted.contains("\(apiKeyName)=REDACTED"))
        #expect(redacted.contains("detail=bad"))
        #expect(!redacted.contains(bearerSecret))
        #expect(!redacted.contains("leaked-token"))
    }

    @Test
    func aiHTTPTransportPerformRetriesOneRateLimitResponse() async throws {
        let state = TransportState()
        let session = URLProtocolHarness.makeSession { request in
            let attempt = state.nextAttempt()
            let url = try #require(request.url)
            if attempt == 1 {
                return (
                    HTTPURLResponse(
                        url: url,
                        statusCode: 429,
                        httpVersion: nil,
                        headerFields: ["Retry-After": "0.25"]
                    )!,
                    Data()
                )
            }

            return (
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://api.example.test/v1/chat")!)

        let (data, response) = try await AIHTTPTransport.perform(
            request,
            using: session,
            sleep: { delay in state.recordDelay(delay) }
        )

        #expect(String(data: data, encoding: .utf8) == "ok")
        #expect(response.statusCode == 200)
        #expect(state.attemptCount == 2)
        #expect(state.recordedDelays == [0.25])
    }

    private final class TransportState: @unchecked Sendable {
        private let lock = NSLock()
        private var attempts = 0
        private var delays: [TimeInterval] = []

        var attemptCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return attempts
        }

        var recordedDelays: [TimeInterval] {
            lock.lock()
            defer { lock.unlock() }
            return delays
        }

        func nextAttempt() -> Int {
            lock.lock()
            defer { lock.unlock() }
            attempts += 1
            return attempts
        }

        func recordDelay(_ delay: TimeInterval) {
            lock.lock()
            delays.append(delay)
            lock.unlock()
        }
    }
}
