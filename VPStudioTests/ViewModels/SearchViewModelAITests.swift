import Foundation
import SwiftUI
import Testing
@testable import VPStudio

@Suite(.serialized)
struct SearchViewModelAITests {
    private enum TestError: Error, LocalizedError {
        case aiFailure

        var errorDescription: String? {
            switch self {
            case .aiFailure: return "AI failure"
            }
        }
    }


    // MARK: - Helpers

    /// Polls until the condition is true or the timeout expires.
    @MainActor
    private static func waitUntil(
        timeout: Duration = .milliseconds(5000),
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("waitUntil timed out after \(timeout)")
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Builds a stub AI provider that returns a canned JSON recommendation array.
    private static func makeStubProvider() -> StubAIProvider {
        let jsonResponse = """
        [{"title":"AI Pick","year":2025,"type":"movie","reason":"Tailored","tmdbId":999}]
        """
        return StubAIProvider(
            providerKind: .anthropic,
            result: .success(AIProviderResponse(
                provider: .anthropic,
                content: jsonResponse,
                model: "test",
                inputTokens: 0,
                outputTokens: 0
            ))
        )
    }

    private actor DelayedAIProvider: AIProvider {
        let providerKind: AIProviderKind = .openAI
        private let response: AIProviderResponse
        private let delay: Duration

        init(delay: Duration = .milliseconds(500), response: AIProviderResponse? = nil) {
            self.delay = delay
            self.response = response ?? AIProviderResponse(
                provider: .openAI,
                content: """
                [{"title":"AI Pick","year":2025,"type":"movie","reason":"Tailored","tmdbId":999}]
                """,
                model: "test",
                inputTokens: 0,
                outputTokens: 0
            )
        }

        func complete(system: String, userMessage: String) async throws -> AIProviderResponse {
            try await Task.sleep(for: delay)
            return response
        }
    }

    private actor PromptAwareAIProvider: AIProvider {
        let providerKind: AIProviderKind = .openAI

        enum PromptAwareAIProviderError: Error {
            case missingResponseForMood
        }

        private var responsesByMood: [String: Result<AIProviderResponse, Error>] = [:]
        private var delaysByMood: [String: Duration] = [:]
        private var receivedMoods: [String] = []

        func setResponse(_ result: Result<AIProviderResponse, Error>, for mood: String) {
            responsesByMood[mood] = result
        }

        func setDelay(_ delay: Duration, for mood: String) {
            delaysByMood[mood] = delay
        }

        func totalCallCount() -> Int {
            receivedMoods.count
        }

        func complete(system: String, userMessage: String) async throws -> AIProviderResponse {
            let mood = Self.extractMood(from: userMessage)
            receivedMoods.append(mood)

            if let delay = delaysByMood[mood] {
                try await Task.sleep(for: delay)
            }

            guard let result = responsesByMood[mood] else {
                throw PromptAwareAIProviderError.missingResponseForMood
            }

            return try result.get()
        }

        static func extractMood(from userMessage: String) -> String {
            let marker = "I'm currently in the mood for: "
            guard let markerRange = userMessage.range(of: marker) else { return "" }

            let remainder = String(userMessage[markerRange.upperBound...])
            return remainder
                .split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        }
    }

    private actor NonCooperativePromptAwareAIProvider: AIProvider {
        let providerKind: AIProviderKind = .openAI

        enum ProviderError: Error {
            case missingResponseForMood
        }

        private var responsesByMood: [String: Result<AIProviderResponse, Error>] = [:]
        private var delaysByMood: [String: Duration] = [:]
        private var receivedMoods: [String] = []

        func setResponse(_ result: Result<AIProviderResponse, Error>, for mood: String) {
            responsesByMood[mood] = result
        }

        func setDelay(_ delay: Duration, for mood: String) {
            delaysByMood[mood] = delay
        }

        func totalCallCount() -> Int {
            receivedMoods.count
        }

        func complete(system: String, userMessage: String) async throws -> AIProviderResponse {
            let mood = PromptAwareAIProvider.extractMood(from: userMessage)
            receivedMoods.append(mood)
            let response = responsesByMood[mood]
            let delay = delaysByMood[mood] ?? .milliseconds(0)

            return try await withCheckedThrowingContinuation { continuation in
                Task.detached {
                    try? await Task.sleep(for: delay)
                    if let response {
                        continuation.resume(with: response)
                    } else {
                        continuation.resume(throwing: ProviderError.missingResponseForMood)
                    }
                }
            }
        }
    }

    private actor MessageCapturingAIProvider: AIProvider {
        let providerKind: AIProviderKind = .openAI
        private let response: AIProviderResponse
        private var messages: [String] = []

        init(response: AIProviderResponse) {
            self.response = response
        }

        func complete(system: String, userMessage: String) async throws -> AIProviderResponse {
            messages.append(userMessage)
            return response
        }

        func messageCount() -> Int {
            messages.count
        }

        func lastMessage() -> String {
            messages.last ?? ""
        }
    }

    private actor SearchMetadataStub: MetadataProvider {
        let searchResult: MetadataSearchResult
        let discoverResult: MetadataSearchResult

        init(
            searchResult: MetadataSearchResult = MetadataSearchResult(items: [Fixtures.mediaPreview(id: "search-result")], page: 1, totalPages: 1, totalResults: 1),
            discoverResult: MetadataSearchResult = MetadataSearchResult(items: [Fixtures.mediaPreview(id: "discover-result")], page: 1, totalPages: 1, totalResults: 1)
        ) {
            self.searchResult = searchResult
            self.discoverResult = discoverResult
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchResult
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverResult
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    /// Creates an `AIAssistantManager` backed by an in-memory database.
    private static func makeAIManager() async throws -> AIAssistantManager {
        let db = try DatabaseManager(inMemoryNamed: "search-ai-\(UUID().uuidString)")
        try await db.migrate()
        return AIAssistantManager(database: db)
    }

    // MARK: - Test 1: Empty query sets isLoadingAI true initially

    @Test
    @MainActor
    func fetchWithEmptyQuerySetsIsLoadingAITrue() async throws {
        let aiManager = try await Self.makeAIManager()
        let stubProvider = Self.makeStubProvider()
        await aiManager.registerProvider(kind: .anthropic, provider: stubProvider)

        let viewModel = SearchViewModel()
        viewModel.query = ""

        viewModel.fetchAIRecommendations(aiManager: aiManager)

        // Synchronous check — isLoadingAI should be true immediately after calling fetch.
        #expect(viewModel.isLoadingAI == true)

        // Wait for the async task to finish so we don't leak.
        try await Self.waitUntil { !viewModel.isLoadingAI }
    }

    // MARK: - Test 2: Query passes mood hint and loads recommendations

    @Test
    @MainActor
    func fetchWithQueryPassesMoodHintAndLoadsRecommendations() async throws {
        let aiManager = try await Self.makeAIManager()
        let stubProvider = Self.makeStubProvider()
        await aiManager.registerProvider(kind: .anthropic, provider: stubProvider)

        let viewModel = SearchViewModel()
        viewModel.query = "dark thriller"

        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil { !viewModel.aiRecommendations.isEmpty }
        #expect(viewModel.aiRecommendations.count == 1)
        #expect(viewModel.aiRecommendations[0].title == "AI Pick")
        #expect(viewModel.aiRecommendations[0].tmdbId == 999)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.aiError == nil)
    }

    // MARK: - Test 3: No provider registered sets aiError

    @Test
    @MainActor
    func fetchWithNoProviderSetsAIError() async throws {
        let aiManager = try await Self.makeAIManager()
        // No provider registered — should trigger AIError.noProviderConfigured

        let viewModel = SearchViewModel()
        viewModel.query = "anything"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil { viewModel.aiError != nil }
        #expect(viewModel.aiError == "No AI provider configured. Set one up in Settings \u{2192} AI Assistant.")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.isLoadingAI == false)
    }

    // MARK: - Test 4: explorePhase returns .results when isLoadingAI is true

    @Test
    @MainActor
    func explorePhaseIsResultsWhenLoadingAI() {
        let viewModel = SearchViewModel()
        // No query, no results, no genre — only isLoadingAI is true.
        viewModel.isLoadingAI = true

        #expect(viewModel.explorePhase == .results)
    }

    // MARK: - Test 5: explorePhase returns .idle by default

    @Test
    @MainActor
    func explorePhaseIsIdleByDefault() {
        let viewModel = SearchViewModel()

        #expect(viewModel.explorePhase == .idle)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.isLoadingAI == false)
    }

    // MARK: - Test 6: clearAIRecommendations resets all AI state

    @Test
    @MainActor
    func clearAIRecommendationsResetsAllAIState() {
        let viewModel = SearchViewModel()

        // Simulate populated AI state.
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Rec1", year: 2025, type: .movie, reason: "Good", tmdbId: 1),
            AIMovieRecommendation(title: "Rec2", year: 2024, type: .series, reason: "Great", tmdbId: 2),
        ]
        viewModel.aiError = "some error"
        viewModel.isLoadingAI = true

        viewModel.clearAIRecommendations()

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func clearCancelsInFlightAIRecommendationsAndResetsLoadingState() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = DelayedAIProvider(delay: .seconds(1))
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "dark fantasy"

        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.clear()

        // Should immediately clear AI state and loading status.
        #expect(viewModel.aiRecommendations.isEmpty == true)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.activeFilterCount == 0)

        // Give cancellation/callbacks a moment to settle and ensure no stale loading/error state
        // appears after the in-flight AI task gets canceled.
        try await Task.sleep(for: .milliseconds(150))
        #expect(viewModel.aiRecommendations.isEmpty == true)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
    }

    // MARK: - Test 7: Empty query still produces recommendations

    @Test
    @MainActor
    func fetchWithEmptyQueryStillProducesRecommendations() async throws {
        let aiManager = try await Self.makeAIManager()
        let stubProvider = Self.makeStubProvider()
        await aiManager.registerProvider(kind: .anthropic, provider: stubProvider)

        let viewModel = SearchViewModel()
        viewModel.query = "   " // whitespace-only, trimmed to empty

        viewModel.fetchAIRecommendations(aiManager: aiManager)

        // The key behavior change: empty/whitespace query does NOT short-circuit.
        // It proceeds to fetch recommendations (with nil moodHint).
        try await Self.waitUntil { !viewModel.aiRecommendations.isEmpty }
        #expect(viewModel.aiRecommendations.count == 1)
        #expect(viewModel.aiRecommendations[0].title == "AI Pick")
        #expect(viewModel.aiRecommendations[0].year == 2025)
        #expect(viewModel.aiRecommendations[0].type == .movie)
        #expect(viewModel.aiRecommendations[0].reason == "Tailored")
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.aiError == nil)
    }

    @Test
    @MainActor
    func inFlightAIRecommendationResultIgnoredAfterNewFetch() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = PromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Action Hit","year":2024,"type":"movie","reason":"Fast","tmdbId":101}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "action"
        )
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Comedy Hit","year":2024,"type":"movie","reason":"Light","tmdbId":202}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "comedy"
        )
        await provider.setDelay(.milliseconds(240), for: "action")
        await provider.setDelay(.milliseconds(20), for: "comedy")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "action"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            !viewModel.isLoadingAI && viewModel.aiRecommendations.count == 1
        }

        #expect(viewModel.aiRecommendations.count == 1)
        #expect(viewModel.aiRecommendations.first?.title == "Comedy Hit")
        #expect(viewModel.aiError == nil)
        #expect(await provider.totalCallCount() == 2)
    }

    @Test
    @MainActor
    func staleAIRecommendationErrorIgnoredAfterFreshFetch() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = PromptAwareAIProvider()
        await provider.setResponse(.failure(TestError.aiFailure), for: "horror")
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Comedy Gold","year":2023,"type":"movie","reason":"Fresh","tmdbId":303}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "comedy"
        )
        await provider.setDelay(.milliseconds(240), for: "horror")
        await provider.setDelay(.milliseconds(20), for: "comedy")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "horror"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            !viewModel.isLoadingAI && !viewModel.aiRecommendations.isEmpty
        }

        #expect(viewModel.aiRecommendations.first?.title == "Comedy Gold")
        #expect(viewModel.aiError == nil)
        #expect(await provider.totalCallCount() == 2)
    }

    @Test
    @MainActor
    func clearAIRecommendationsCancelsInFlightFetch() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = PromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Delayed Rec","year":2022,"type":"movie","reason":"Pending","tmdbId":404}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "drama"
        )
        await provider.setDelay(.milliseconds(200), for: "drama")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "drama"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.clearAIRecommendations()
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.aiRecommendations.isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.aiRecommendations.isEmpty)
    }

    @Test
    @MainActor
    func nonCooperativeInFlightAIRecommendationErrorIsIgnoredAfterFreshFetch() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .failure(TestError.aiFailure),
            for: "horror"
        )
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Comedy Gold","year":2023,"type":"movie","reason":"Fresh","tmdbId":303}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "comedy"
        )
        await provider.setDelay(.milliseconds(240), for: "horror")
        await provider.setDelay(.milliseconds(20), for: "comedy")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "horror"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            !viewModel.isLoadingAI && !viewModel.aiRecommendations.isEmpty
        }

        #expect(viewModel.aiRecommendations.first?.title == "Comedy Gold")
        #expect(viewModel.aiError == nil)
    }

    @Test
    @MainActor
    func clearAIRecommendationsCancelsNonCooperativeInFlightFetch() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .failure(TestError.aiFailure),
            for: "drama"
        )
        await provider.setDelay(.milliseconds(200), for: "drama")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "drama"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.clearAIRecommendations()
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.aiRecommendations.isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.aiRecommendations.isEmpty)
    }

    @Test
    @MainActor
    func configureWithEmptyApiKeyClearsAIState() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = DelayedAIProvider(delay: .milliseconds(250))
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel(metadataServiceFactory: { _ in
            SearchMetadataStub()
        })
        viewModel.configure(apiKey: "valid-key")

        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Legacy AI", year: 2022, type: .movie, reason: "Old", tmdbId: 77)
        ]
        viewModel.aiError = "Stale AI error"
        viewModel.isLoadingAI = true

        viewModel.query = "any"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        #expect(viewModel.isLoadingAI == true)

        viewModel.configure(apiKey: "   ")

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)

        try await Task.sleep(for: .milliseconds(320))
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func configureWithNewApiKeyClearsAIState() {
        let viewModel = SearchViewModel(metadataServiceFactory: { _ in
            SearchMetadataStub()
        })

        viewModel.configure(apiKey: "old-key")
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Legacy AI", year: 2022, type: .movie, reason: "Old", tmdbId: 88)
        ]
        viewModel.aiError = "AI stale error"
        viewModel.isLoadingAI = true

        viewModel.configure(apiKey: "new-key")

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func configureWithNewApiKeyClearsInFlightAIRequest() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = DelayedAIProvider(delay: .milliseconds(250))
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel(metadataServiceFactory: { _ in
            SearchMetadataStub()
        })
        viewModel.configure(apiKey: "old-key")

        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Legacy AI", year: 2021, type: .movie, reason: "Old", tmdbId: 99)
        ]

        viewModel.query = "drama"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.configure(apiKey: "new-key")

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)

        try await Task.sleep(for: .milliseconds(320))
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func nonCooperativeInFlightAIRecommendationResultIsIgnoredAfterNewFetch() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Action Hit","year":2024,"type":"movie","reason":"Fast","tmdbId":101}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "action"
        )
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Comedy Hit","year":2024,"type":"movie","reason":"Light","tmdbId":202}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "comedy"
        )
        await provider.setDelay(.milliseconds(240), for: "action")
        await provider.setDelay(.milliseconds(20), for: "comedy")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "action"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            !viewModel.isLoadingAI && !viewModel.aiRecommendations.isEmpty
        }

        #expect(viewModel.aiRecommendations.first?.title == "Comedy Hit")
        #expect(viewModel.aiError == nil)
        #expect(await provider.totalCallCount() == 2)
    }

    @Test
    @MainActor
    func freshAIRecommendationFailureKeepsStaleResultSuppressed() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = PromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Action Hit","year":2024,"type":"movie","reason":"Fast","tmdbId":101}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "action"
        )
        await provider.setResponse(
            .failure(TestError.aiFailure),
            for: "comedy"
        )
        await provider.setDelay(.milliseconds(240), for: "action")
        await provider.setDelay(.milliseconds(20), for: "comedy")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "action"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            !viewModel.isLoadingAI && viewModel.aiError != nil
        }

        #expect(viewModel.aiError == "AI failure")
        #expect(viewModel.aiRecommendations.isEmpty)

        try await Task.sleep(for: .milliseconds(300))

        #expect(viewModel.aiError == "AI failure")
        #expect(viewModel.aiRecommendations.isEmpty)
    }

    @Test
    @MainActor
    func nonCooperativeFreshAIRecommendationFailureKeepsStaleResultSuppressed() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Action Hit","year":2024,"type":"movie","reason":"Fast","tmdbId":101}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "action"
        )
        await provider.setResponse(
            .failure(TestError.aiFailure),
            for: "comedy"
        )
        await provider.setDelay(.milliseconds(240), for: "action")
        await provider.setDelay(.milliseconds(20), for: "comedy")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "action"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            !viewModel.isLoadingAI && viewModel.aiError != nil
        }

        #expect(viewModel.aiError == "AI failure")
        #expect(viewModel.aiRecommendations.isEmpty)

        try await Task.sleep(for: .milliseconds(300))

        #expect(viewModel.aiError == "AI failure")
        #expect(viewModel.aiRecommendations.isEmpty)
    }

    @Test
    @MainActor
    func cancelInFlightWorkStopsAILoadingStateWithoutApplyingStaleResult() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Action Hit","year":2024,"type":"movie","reason":"Fast","tmdbId":101}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "action"
        )
        await provider.setDelay(.milliseconds(220), for: "action")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "action"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.cancelInFlightWork()
        #expect(viewModel.isLoadingAI == false)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func freshAIRecommendationFailureClearsPreviouslyLoadedRecommendations() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = PromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Action Hit","year":2024,"type":"movie","reason":"Fast","tmdbId":101}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "action"
        )
        await provider.setResponse(.failure(TestError.aiFailure), for: "comedy")
        await provider.setDelay(.milliseconds(5), for: "action")
        await provider.setDelay(.milliseconds(5), for: "comedy")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "action"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            viewModel.aiRecommendations.first?.title == "Action Hit"
        }
        #expect(viewModel.aiRecommendations.count == 1)
        #expect(viewModel.aiError == nil)

        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            !viewModel.isLoadingAI && viewModel.aiError != nil
        }

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == "AI failure")
    }

    @Test
    @MainActor
    func invalidAIProviderPayloadSetsErrorAndClearsAIRecommendations() async throws {
        let aiManager = try await Self.makeAIManager()
        let stubProvider = StubAIProvider(
            providerKind: .openAI,
            result: .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: "not valid json",
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            )
        )
        await aiManager.registerProvider(kind: .openAI, provider: stubProvider)

        let viewModel = SearchViewModel()
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "FromHistory", year: 2024, type: .movie, reason: "Old", tmdbId: 9001)
        ]
        viewModel.aiError = "previous error"
        viewModel.query = "any"

        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            !viewModel.isLoadingAI && viewModel.aiError != nil
        }

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == "Invalid AI response")
    }

    @Test
    @MainActor
    func cancelInFlightWorkIncrementsAIGeneration() async throws {
        let aiManager = try await Self.makeAIManager()
        let stubProvider = Self.makeStubProvider()
        await aiManager.registerProvider(kind: .anthropic, provider: stubProvider)

        let viewModel = SearchViewModel()
        let initialGeneration = viewModel.aiGeneration
        #expect(viewModel.aiGeneration == initialGeneration)
        viewModel.query = "anything"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.aiGeneration == initialGeneration + 1)

        viewModel.cancelInFlightWork()
        #expect(viewModel.aiGeneration == initialGeneration + 2)

        try await Self.waitUntil { !viewModel.isLoadingAI }
    }

    @Test
    @MainActor
    func clearSuppressesStaleInFlightAIResultAfterFreshFetch() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = PromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Old Mood","year":2022,"type":"movie","reason":"Old","tmdbId":11}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "drama"
        )
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Fresh Mood","year":2024,"type":"movie","reason":"Fresh","tmdbId":22}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "comedy"
        )
        await provider.setDelay(.milliseconds(220), for: "drama")
        await provider.setDelay(.milliseconds(20), for: "comedy")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "drama"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.aiGeneration == 1)

        try await Task.sleep(for: .milliseconds(40))
        viewModel.clear()
        #expect(viewModel.aiGeneration == 3)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)

        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.aiGeneration == 4)

        try await Self.waitUntil {
            !viewModel.isLoadingAI && viewModel.aiRecommendations.count == 1
        }

        #expect(viewModel.aiRecommendations.first?.title == "Fresh Mood")
        #expect(viewModel.aiError == nil)
        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.aiRecommendations.first?.title == "Fresh Mood")
    }

    @Test
    @MainActor
    func emptyQueryDoesNotIncludeMoodPromptMarker() async throws {
        let aiManager = try await Self.makeAIManager()
        let response = AIProviderResponse(
            provider: .openAI,
            content: """
            [{"title":"No Mood","year":2025,"type":"movie","reason":"Quiet","tmdbId":333}]
            """,
            model: "test",
            inputTokens: 0,
            outputTokens: 0
        )
        let provider = MessageCapturingAIProvider(response: response)
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "   "
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        for _ in 0..<50 {
            if await provider.messageCount() == 1 { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(await provider.messageCount() == 1)
        let message = await provider.lastMessage()
        #expect(!message.contains("I'm currently in the mood for:"))
        #expect(viewModel.aiError == nil)
        #expect(viewModel.aiRecommendations.count == 1)
        #expect(viewModel.aiRecommendations.first?.title == "No Mood")
    }

    @Test
    @MainActor
    func clearAIRecommendationsResetsStateAndAdvancesGeneration() async throws {
        let aiManager = try await Self.makeAIManager()
        let viewModel = SearchViewModel()
        let stubbedProvider = MessageCapturingAIProvider(
            response: AIProviderResponse(
                provider: .openAI,
                content: """
                [{"title":"Old Rec","year":2025,"type":"movie","reason":"Old","tmdbId":1}]
                """,
                model: "test",
                inputTokens: 0,
                outputTokens: 0
            )
        )
        await aiManager.registerProvider(kind: .openAI, provider: stubbedProvider)

        viewModel.query = "drama"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        for _ in 0..<50 {
            if await stubbedProvider.messageCount() == 1 { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(await stubbedProvider.messageCount() == 1)
        #expect(viewModel.aiGeneration == 1)

        viewModel.clearAIRecommendations()
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.aiGeneration == 2)
    }

    @Test
    @MainActor
    func noProviderErrorIsRecoveredBySubsequentSuccessfulAIRequest() async throws {
        let aiManager = try await Self.makeAIManager()
        let response = AIProviderResponse(
            provider: .openAI,
            content: """
            [{"title":"Recovered Rec","year":2025,"type":"movie","reason":"Recovered","tmdbId":444}]
            """,
            model: "test",
            inputTokens: 0,
            outputTokens: 0
        )
        let provider = MessageCapturingAIProvider(response: response)

        let viewModel = SearchViewModel()
        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            viewModel.aiError != nil
        }
        #expect(viewModel.aiError == "No AI provider configured. Set one up in Settings \u{2192} AI Assistant.")
        #expect(viewModel.aiRecommendations.isEmpty)

        await aiManager.registerProvider(kind: .openAI, provider: provider)

        viewModel.fetchAIRecommendations(aiManager: aiManager)
        try await Self.waitUntil { !viewModel.isLoadingAI && !viewModel.aiRecommendations.isEmpty }

        #expect(viewModel.aiError == nil)
        #expect(viewModel.aiRecommendations.count == 1)
        #expect(viewModel.aiRecommendations.first?.title == "Recovered Rec")
    }

    @Test
    @MainActor
    func searchCancelsInFlightAIRecommendationBeforeApply() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Delayed Rec","year":2024,"type":"movie","reason":"Delayed","tmdbId":700}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "drama"
        )
        await provider.setDelay(.milliseconds(220), for: "drama")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let metadataService = SearchMetadataStub(
            searchResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result", year: 2024)],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)

        viewModel.query = "drama"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.search()

        try await Self.waitUntil {
            !viewModel.isSearching && !viewModel.results.isEmpty
        }

        #expect(viewModel.results.first?.id == "search-result")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func selectGenreCancelsInFlightAIRecommendationBeforeApply() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Delayed Genre Rec","year":2024,"type":"movie","reason":"Pending","tmdbId":701}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "romance"
        )
        await provider.setDelay(.milliseconds(220), for: "romance")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let metadataService = SearchMetadataStub(
            discoverResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)

        viewModel.query = "romance"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil {
            !viewModel.results.isEmpty
        }

        #expect(viewModel.results.first?.id == "genre-result")
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func queryWhitespaceIsTrimmedWhenConstructingAIPrompt() async throws {
        let aiManager = try await Self.makeAIManager()
        let response = AIProviderResponse(
            provider: .openAI,
            content: """
            [{"title":"Trimmed Rec","year":2025,"type":"movie","reason":"Trimmed","tmdbId":555}]
            """,
            model: "test",
            inputTokens: 0,
            outputTokens: 0
        )
        let provider = MessageCapturingAIProvider(response: response)
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "\n  thriller  "
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        for _ in 0..<50 {
            if await provider.messageCount() == 1 { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(await provider.messageCount() == 1)

        let capturedMessage = await provider.lastMessage()
        let extractedMood = PromptAwareAIProvider.extractMood(from: capturedMessage)
        #expect(extractedMood == "thriller")
    }

    @Test
    @MainActor
    func staleAIRecommendationFromMoodFetchIgnoredAfterEmptyQueryFetch() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = PromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Mood Rec","year":2024,"type":"movie","reason":"Mood","tmdbId":801}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "thriller"
        )
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Empty Rec","year":2025,"type":"movie","reason":"Quiet","tmdbId":802}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: ""
        )
        await provider.setDelay(.milliseconds(240), for: "thriller")
        await provider.setDelay(.milliseconds(20), for: "")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "thriller"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        viewModel.query = "   "
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil {
            !viewModel.isLoadingAI && !viewModel.aiRecommendations.isEmpty
        }

        #expect(viewModel.aiRecommendations.count == 1)
        #expect(viewModel.aiRecommendations.first?.title == "Empty Rec")
        #expect(viewModel.aiError == nil)
        #expect(await provider.totalCallCount() == 2)
    }

    @Test
    @MainActor
    func searchClearsInFlightAIErrorInsteadOfDisplayingIt() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = PromptAwareAIProvider()
        await provider.setResponse(
            .failure(TestError.aiFailure),
            for: "drama"
        )
        await provider.setDelay(.milliseconds(220), for: "drama")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let metadataService = SearchMetadataStub(
            searchResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result", year: 2024)],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)
        viewModel.query = "drama"

        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.search()

        try await Self.waitUntil {
            !viewModel.isSearching && !viewModel.results.isEmpty
        }

        #expect(viewModel.results.first?.id == "search-result")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func applySortOptionCancelsInFlightAIRecommendationBeforeApply() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Sort Delayed Rec","year":2024,"type":"movie","reason":"Slow","tmdbId":900}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "comedy"
        )
        await provider.setDelay(.milliseconds(220), for: "comedy")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let metadataService = SearchMetadataStub(
            searchResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result", year: 2010)],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)
        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        #expect(viewModel.isLoadingAI == true)

        viewModel.applySortOption(.releaseDateDesc)
        try await Self.waitUntil {
            !viewModel.isSearching && !viewModel.results.isEmpty
        }

        #expect(viewModel.sortOption == .releaseDateDesc)
        #expect(viewModel.results.first?.id == "search-result")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func toggleLanguageCancelsInFlightAIRecommendationBeforeApply() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Language Delayed Rec","year":2023,"type":"movie","reason":"Pending","tmdbId":901}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "thriller"
        )
        await provider.setDelay(.milliseconds(220), for: "thriller")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let metadataService = SearchMetadataStub(
            searchResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result", year: 2010)],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)
        viewModel.query = "thriller"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        #expect(viewModel.isLoadingAI == true)

        viewModel.toggleLanguage("es-ES")
        try await Self.waitUntil {
            !viewModel.isSearching && !viewModel.results.isEmpty
        }

        #expect(viewModel.primaryLanguage == "es-ES")
        #expect(viewModel.results.first?.id == "search-result")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func selectSpecialMoodCardCancelsInFlightAIRecommendationBeforeApply() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Mood Delayed Rec","year":2024,"type":"movie","reason":"Pending","tmdbId":902}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "drama"
        )
        await provider.setDelay(.milliseconds(220), for: "drama")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let metadataService = SearchMetadataStub(
            discoverResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        viewModel.query = "drama"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil {
            !viewModel.isSearching && !viewModel.results.isEmpty
        }

        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.first?.id == "mood-result")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeCancelsInFlightAIRecommendationWithSpecialMoodAndQueries() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Type change stale rec","year":2024,"type":"movie","reason":"Pending","tmdbId":903}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "thriller"
        )
        await provider.setDelay(.milliseconds(220), for: "thriller")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let metadataService = SearchMetadataStub(
            searchResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            discoverResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        viewModel.query = "thriller"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.selectMoodCard(specialCard)

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()
        #expect(viewModel.isSearching == true)

        try await Self.waitUntil {
            !viewModel.isSearching && viewModel.results.first?.id == "search-result"
        }

        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.first?.id == "search-result")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func applyYearFilterCancelsInFlightAIRecommendationBeforeApply() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Year Filter Delayed Rec","year":2025,"type":"movie","reason":"Pending","tmdbId":904}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "drama"
        )
        await provider.setDelay(.milliseconds(220), for: "drama")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let metadataService = SearchMetadataStub(
            searchResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result", year: 2024)],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)
        viewModel.query = "drama"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        #expect(viewModel.isLoadingAI == true)

        viewModel.applyYearFilter(2024)
        try await Self.waitUntil {
            !viewModel.isSearching && !viewModel.results.isEmpty
        }

        #expect(viewModel.yearFilter == 2024)
        #expect(viewModel.results.first?.id == "search-result")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func applyYearRangePresetCancelsInFlightAIRecommendationBeforeApply() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Preset Delayed Rec","year":2025,"type":"movie","reason":"Pending","tmdbId":905}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "comedy"
        )
        await provider.setDelay(.milliseconds(220), for: "comedy")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let metadataService = SearchMetadataStub(
            searchResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result", year: 2010)],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)
        viewModel.query = "comedy"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        #expect(viewModel.isLoadingAI == true)

        viewModel.applyYearRangePreset(.tens)
        try await Self.waitUntil {
            !viewModel.isSearching && !viewModel.results.isEmpty
        }

        #expect(viewModel.yearFilter == 2010)
        #expect(viewModel.yearRangePreset == .tens)
        #expect(viewModel.results.first?.id == "search-result")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func applyLanguageFiltersCancelsInFlightAIRecommendationBeforeApply() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Language Filter Delayed Rec","year":2025,"type":"movie","reason":"Pending","tmdbId":906}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "thriller"
        )
        await provider.setDelay(.milliseconds(220), for: "thriller")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let metadataService = SearchMetadataStub(
            searchResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)
        viewModel.query = "thriller"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        #expect(viewModel.isLoadingAI == true)

        viewModel.applyLanguageFilters(["es-ES"])
        try await Self.waitUntil {
            !viewModel.isSearching && !viewModel.results.isEmpty
        }

        #expect(viewModel.languageFilters == ["es-ES"])
        #expect(viewModel.results.first?.id == "search-result")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func searchClearsStaleAIState() async throws {
        let metadataService = SearchMetadataStub()
        let viewModel = SearchViewModel(metadataService: metadataService)
        let query = "new sci-fi"
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Stale Rec", year: 2020, type: .movie, reason: "Old", tmdbId: 12)
        ]
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = false

        viewModel.query = query
        viewModel.search()

        try await Self.waitUntil { !viewModel.results.isEmpty }

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.results.first?.id == "search-result")
        #expect(viewModel.query == query)
        #expect(viewModel.submittedQuery == query)
    }

    @Test
    @MainActor
    func searchWithoutMetadataServiceClearsStaleAIState() async throws {
        let viewModel = SearchViewModel()
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Stale Rec", year: 2020, type: .movie, reason: "Old", tmdbId: 21)
        ]
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = false
        viewModel.query = "new sci-fi"

        viewModel.search()

        try await Self.waitUntil { viewModel.error != nil }
        #expect(viewModel.error == .metadataSetupRequired(feature: "Search"))
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
    }

    @Test
    @MainActor
    func genreBrowseClearsStaleAIState() async throws {
        let metadataService = SearchMetadataStub(
            discoverResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Stale Genre Rec", year: 2019, type: .movie, reason: "Old", tmdbId: 13)
        ]
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = false

        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.results.first?.id == "genre-result")
    }

    @Test
    @MainActor
    func specialMoodCardBrowseClearsStaleAIState() async throws {
        let metadataService = SearchMetadataStub(
            discoverResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: metadataService)
        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Stale Mood Rec", year: 2018, type: .movie, reason: "Old", tmdbId: 14)
        ]
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = false

        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.results.first?.id == "mood-result")
    }

    @Test
    @MainActor
    func selectGenreNilClearsStaleAIStateWhenNoQueryIsActive() async throws {
        let metadataService = SearchMetadataStub()
        let viewModel = SearchViewModel(metadataService: metadataService)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil { viewModel.results.first?.id == "discover-result" }

        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Old Genre Rec", year: 2018, type: .movie, reason: "Old", tmdbId: 15)
        ]
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = false

        viewModel.selectGenre(nil)

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeClearsStaleAIStateWhenGenreContextIsInvalidForNewType() async throws {
        let metadataService = SearchMetadataStub()
        let viewModel = SearchViewModel(metadataService: metadataService)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil { viewModel.results.first?.id == "discover-result" }

        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Old Genre Rec", year: 2021, type: .movie, reason: "Old", tmdbId: 16)
        ]
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = false

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func clearAllFiltersClearsStaleAIStateWhenNoSearchContextRemains() async throws {
        let viewModel = SearchViewModel()
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Old Rec", year: 2018, type: .movie, reason: "Old", tmdbId: 17)
        ]
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = false

        viewModel.clearAllFilters()

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.yearFilter == nil)
        #expect(viewModel.languageFilters == ["en-US"])
    }

    @Test
    @MainActor
    func clearAllFiltersCancelsInFlightAIRecommendationInSearchContext() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Stale Mood Rec","year":2025,"type":"movie","reason":"Stale","tmdbId":101}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "apollo"
        )
        await provider.setDelay(.milliseconds(240), for: "apollo")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel(metadataService: SearchMetadataStub())
        viewModel.query = "apollo"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        for _ in 0..<40 {
            if await provider.totalCallCount() == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await provider.totalCallCount() == 1)

        viewModel.clearAllFilters()

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")

        try await Self.waitUntil {
            viewModel.results.first?.id == "search-result"
        }
        #expect(viewModel.results.first?.id == "search-result")
        #expect(await provider.totalCallCount() == 1)
        #expect(viewModel.aiRecommendations.isEmpty)
    }

    @Test
    @MainActor
    func clearAllFiltersWithGenreContextCancelsInFlightAIAndKeepsSearchPath() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Genre-Stale Rec","year":2024,"type":"movie","reason":"Stale","tmdbId":102}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "apollo"
        )
        await provider.setDelay(.milliseconds(240), for: "apollo")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel(metadataService: SearchMetadataStub())
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = "apollo"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        for _ in 0..<40 {
            if await provider.totalCallCount() == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await provider.totalCallCount() == 1)

        viewModel.clearAllFilters()

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)

        try await Self.waitUntil {
            viewModel.results.first?.id == "search-result"
        }
        #expect(viewModel.results.first?.id == "search-result")
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func clearAllFiltersWithSpecialMoodContextPreservesMoodAndCancelsInFlightAI() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Mood-Stale Rec","year":2023,"type":"movie","reason":"Stale","tmdbId":103}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: "apollo"
        )
        await provider.setDelay(.milliseconds(240), for: "apollo")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: SearchMetadataStub())
        viewModel.selectMoodCard(specialCard)

        #expect(viewModel.activeMoodCard?.id == specialCard.id)

        viewModel.query = "apollo"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        for _ in 0..<40 {
            if await provider.totalCallCount() == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await provider.totalCallCount() == 1)

        viewModel.clearAllFilters()

        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)

        try await Self.waitUntil {
            viewModel.results.first?.id == "search-result"
        }
        #expect(viewModel.results.first?.id == "search-result")
        #expect(await provider.totalCallCount() == 1)
    }

    @Test
    @MainActor
    func clearAllFiltersWithWhitespaceQueryClearsStaleAIStateAndCancelsInFlightFetch() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Whitespace Rec","year":2025,"type":"movie","reason":"Quiet","tmdbId":201}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: ""
        )
        await provider.setDelay(.milliseconds(240), for: "")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "   "
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Old Rec", year: 2018, type: .movie, reason: "Old", tmdbId: 17)
        ]
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = false

        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        for _ in 0..<40 {
            if await provider.totalCallCount() == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await provider.totalCallCount() == 1)

        viewModel.clearAllFilters()

        #expect(viewModel.query == "   ")
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.hasQueryText == false)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)

        #expect(viewModel.aiRecommendations.isEmpty)
    }

    @Test
    @MainActor
    func clearAllFiltersWithWhitespaceQueryNoSearchContextPreservesDraftAndClearsAIState() async throws {
        let viewModel = SearchViewModel()

        viewModel.query = "   "
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Old Rec", year: 2017, type: .movie, reason: "Old", tmdbId: 18)
        ]
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = false

        viewModel.clearAllFilters()

        #expect(viewModel.query == "   ")
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.hasQueryText == false)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func clearAllFiltersWithSpecialMoodAndWhitespaceQueryCancelsInFlightAIState() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .success(
                AIProviderResponse(
                    provider: .openAI,
                    content: """
                    [{"title":"Mood-Stale Rec","year":2023,"type":"movie","reason":"Stale","tmdbId":103}]
                    """,
                    model: "test",
                    inputTokens: 0,
                    outputTokens: 0
                )
            ),
            for: ""
        )
        await provider.setDelay(.milliseconds(240), for: "")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: SearchMetadataStub())
        viewModel.selectMoodCard(specialCard)
        viewModel.query = "   "
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        for _ in 0..<40 {
            if await provider.totalCallCount() == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await provider.totalCallCount() == 1)

        viewModel.clearAllFilters()

        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.query == "   ")
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.hasQueryText == false)

        try await Self.waitUntil {
            viewModel.results.first?.id == "discover-result"
        }
        #expect(viewModel.results.first?.id == "discover-result")
    }

    @Test
    @MainActor
    func clearAllFiltersWithWhitespaceQueryDiscardsInFlightAIError() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(.failure(TestError.aiFailure), for: "")
        await provider.setDelay(.milliseconds(240), for: "")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "   "
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = true

        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.clearAllFilters()

        #expect(viewModel.query == "   ")
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.hasQueryText == false)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.aiError == nil)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.isLoadingAI == false)

    }

    @Test
    @MainActor
    func clearAllFiltersIncrementsAIGenerationWhenAIRequestIsCleared() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = Self.makeStubProvider()
        await aiManager.registerProvider(kind: .anthropic, provider: provider)

        let viewModel = SearchViewModel(metadataService: SearchMetadataStub())
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        let initialGeneration = viewModel.aiGeneration
        viewModel.query = "   "
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.aiGeneration == initialGeneration + 1)
        #expect(viewModel.isLoadingAI == true)

        viewModel.clearAllFilters()

        #expect(viewModel.aiGeneration == initialGeneration + 3)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersWithGenreContextAndWhitespaceQueryKeepsGenreClearedAndDiscardsAIError() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = NonCooperativePromptAwareAIProvider()
        await provider.setResponse(
            .failure(TestError.aiFailure),
            for: ""
        )
        await provider.setDelay(.milliseconds(220), for: "")
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = "   "
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Old Rec", year: 2018, type: .movie, reason: "Old", tmdbId: 19)
        ]
        viewModel.aiError = "Previous AI problem"
        viewModel.isLoadingAI = true

        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        for _ in 0..<40 {
            if await provider.totalCallCount() == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await provider.totalCallCount() == 1)

        viewModel.clearAllFilters()

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.query == "   ")
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.hasQueryText == false)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await provider.totalCallCount() == 1)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func clearAllFiltersWithSearchContextAndNoMetadataPreservesQueryWhileReportingSearchSetupError() async throws {
        let aiManager = try await Self.makeAIManager()
        let provider = PromptAwareAIProvider()
        await provider.setResponse(
            .success(AIProviderResponse(
                provider: .openAI,
                content: """
                [{"title":"No Metadata Rec","year":2025,"type":"movie","reason":"Fresh","tmdbId":601}]
                """,
                model: "test",
                inputTokens: 0,
                outputTokens: 0
            )),
            for: "apollo"
        )
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let viewModel = SearchViewModel()
        viewModel.query = "apollo"
        viewModel.fetchAIRecommendations(aiManager: aiManager)
        #expect(viewModel.isLoadingAI == true)

        viewModel.clearAllFilters()

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)

        try await Self.waitUntil {
            viewModel.error == .metadataSetupRequired(feature: "Search")
        }

        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.error == .metadataSetupRequired(feature: "Search"))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.isSearching == false)
    }

    // MARK: - Natural-language search

    @Test
    @MainActor
    func fetchNaturalLanguageRecommendationsPopulatesAIRecommendations() async throws {
        let aiManager = try await Self.makeAIManager()
        let stubProvider = Self.makeStubProvider()
        await aiManager.registerProvider(kind: .anthropic, provider: stubProvider)

        let viewModel = SearchViewModel()
        viewModel.fetchNaturalLanguageRecommendations(
            query: "something cozy for a rainy night",
            aiManager: aiManager
        )

        #expect(viewModel.isLoadingAI == true)
        try await Self.waitUntil { !viewModel.aiRecommendations.isEmpty }
        #expect(viewModel.aiRecommendations.count == 1)
        #expect(viewModel.aiRecommendations[0].title == "AI Pick")
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.aiError == nil)
    }

    @Test
    @MainActor
    func fetchNaturalLanguageRecommendationsSendsLiteralPhraseToProvider() async throws {
        let aiManager = try await Self.makeAIManager()
        let response = AIProviderResponse(
            provider: .openAI,
            content: """
            [{"title":"NL Pick","year":2024,"type":"movie","reason":"Fits","tmdbId":12}]
            """,
            model: "test",
            inputTokens: 0,
            outputTokens: 0
        )
        let provider = MessageCapturingAIProvider(response: response)
        await aiManager.registerProvider(kind: .openAI, provider: provider)

        let phrase = "gritty 90s korean revenge thrillers"
        let viewModel = SearchViewModel()
        viewModel.fetchNaturalLanguageRecommendations(query: phrase, aiManager: aiManager)

        for _ in 0..<50 {
            if await provider.messageCount() == 1 { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(await provider.messageCount() == 1)
        let message = await provider.lastMessage()
        #expect(message.contains(phrase))
        #expect(viewModel.aiRecommendations.first?.title == "NL Pick")
    }

    @Test
    @MainActor
    func fetchNaturalLanguageRecommendationsWithNoProviderSetsAIError() async throws {
        let aiManager = try await Self.makeAIManager()

        let viewModel = SearchViewModel()
        viewModel.fetchNaturalLanguageRecommendations(query: "anything at all here", aiManager: aiManager)

        try await Self.waitUntil { viewModel.aiError != nil }
        #expect(viewModel.aiError == "No AI provider configured. Set one up in Settings \u{2192} AI Assistant.")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func fetchPersonalizedRecommendationsPopulatesAIRecommendations() async throws {
        let aiManager = try await Self.makeAIManager()
        let stubProvider = Self.makeStubProvider()
        await aiManager.registerProvider(kind: .anthropic, provider: stubProvider)

        let viewModel = SearchViewModel()
        viewModel.fetchPersonalizedRecommendations(aiManager: aiManager)

        #expect(viewModel.isLoadingAI == true)
        try await Self.waitUntil { !viewModel.aiRecommendations.isEmpty }
        #expect(viewModel.aiRecommendations.first?.title == "AI Pick")
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.aiError == nil)
    }

    @Test
    @MainActor
    func fetchPersonalizedRecommendationsWithNoProviderSetsAIError() async throws {
        let aiManager = try await Self.makeAIManager()

        let viewModel = SearchViewModel()
        viewModel.fetchPersonalizedRecommendations(aiManager: aiManager)

        try await Self.waitUntil { viewModel.aiError != nil }
        #expect(viewModel.aiError == "No AI provider configured. Set one up in Settings \u{2192} AI Assistant.")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.isLoadingAI == false)
    }
}
