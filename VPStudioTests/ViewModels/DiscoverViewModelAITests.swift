import Foundation
import Testing
@testable import VPStudio

@Suite("DiscoverViewModel AI Recommendations", .serialized)
struct DiscoverViewModelAITests {
    private actor SequencedAIProvider: AIProvider {
        let providerKind: AIProviderKind
        private var queuedResults: [Result<AIProviderResponse, Error>]
        private var receivedMessages: [String] = []

        init(providerKind: AIProviderKind = .anthropic, jsonResponses: [String]) {
            self.providerKind = providerKind
            self.queuedResults = jsonResponses.map {
                .success(
                    AIProviderResponse(
                        provider: providerKind,
                        content: $0,
                        model: "test",
                        inputTokens: 0,
                        outputTokens: 0
                    )
                )
            }
        }

        func complete(system: String, userMessage: String) async throws -> AIProviderResponse {
            receivedMessages.append(userMessage)
            guard !queuedResults.isEmpty else {
                throw AIError.invalidResponse
            }

            let result = queuedResults.removeFirst()
            switch result {
            case .success(let response):
                return response
            case .failure(let error):
                throw error
            }
        }

        func messages() -> [String] {
            receivedMessages
        }
    }

    /// An AIProvider whose `complete(...)` blocks until released, so a test can deterministically
    /// suspend the in-flight LLM fetch, cancel the calling task (simulating the Discover tab being
    /// torn down), and then assert the cache latch survived. Cancellation-aware: cancelling the
    /// caller throws `CancellationError` out of `complete`, mirroring a real cancelled `.task`.
    private actor GatedAIProvider: AIProvider {
        let providerKind: AIProviderKind
        private let jsonResponse: String
        private(set) var completeCallCount = 0
        private var startedContinuations: [CheckedContinuation<Void, Never>] = []
        private var hasStarted = false
        private var releaseContinuation: CheckedContinuation<Void, Never>?
        private var isReleased = false

        init(providerKind: AIProviderKind = .anthropic, jsonResponse: String) {
            self.providerKind = providerKind
            self.jsonResponse = jsonResponse
        }

        func complete(system: String, userMessage: String) async throws -> AIProviderResponse {
            completeCallCount += 1
            markStarted()

            try await withTaskCancellationHandler {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    if isReleased {
                        continuation.resume()
                    } else {
                        releaseContinuation = continuation
                    }
                }
                try Task.checkCancellation()
            } onCancel: {
                Task { await self.release() }
            }

            return AIProviderResponse(
                provider: providerKind,
                content: jsonResponse,
                model: "test",
                inputTokens: 0,
                outputTokens: 0
            )
        }

        /// Suspends until `complete(...)` has been entered (i.e. the synchronous latch in
        /// `loadAIRecommendationsIfNeeded` has already run and we're parked on the await).
        func waitUntilStarted() async {
            if hasStarted { return }
            await withCheckedContinuation { continuation in
                startedContinuations.append(continuation)
            }
        }

        func release() {
            isReleased = true
            releaseContinuation?.resume()
            releaseContinuation = nil
        }

        func callCount() -> Int { completeCallCount }

        private func markStarted() {
            hasStarted = true
            let waiters = startedContinuations
            startedContinuations.removeAll()
            for waiter in waiters { waiter.resume() }
        }
    }

    private static func makeGatedDependencies(
        jsonResponse: String = """
        [{"title":"Gated Movie","year":2024,"type":"movie","reason":"Great","tmdbId":555}]
        """
    ) async throws -> (db: DatabaseManager, settings: SettingsManager, aiManager: AIAssistantManager, provider: GatedAIProvider) {
        let db = try DatabaseManager(inMemoryNamed: "vpstudio-discover-ai-gated-tests-\(UUID().uuidString)")
        try await db.migrate()
        let secretStore = TestSecretStore()
        let settings = SettingsManager(database: db, secretStore: secretStore)
        let aiManager = AIAssistantManager(database: db)
        let provider = GatedAIProvider(jsonResponse: jsonResponse)
        await aiManager.registerProvider(kind: .anthropic, provider: provider)
        return (db, settings, aiManager, provider)
    }

    // MARK: - Helpers

    /// Builds an in-memory database, settings manager, and AI manager with a registered stub provider.
    private static func makeDependencies(
        jsonResponse: String = """
        [{"title":"Test Movie","year":2024,"type":"movie","reason":"Great","tmdbId":123}]
        """
    ) async throws -> (db: DatabaseManager, settings: SettingsManager, aiManager: AIAssistantManager) {
        let db = try DatabaseManager(inMemoryNamed: "vpstudio-discover-ai-tests-\(UUID().uuidString)")
        try await db.migrate()
        let secretStore = TestSecretStore()
        let settings = SettingsManager(database: db, secretStore: secretStore)
        let aiManager = AIAssistantManager(database: db)
        let stubProvider = StubAIProvider(
            providerKind: .anthropic,
            result: .success(AIProviderResponse(
                provider: .anthropic,
                content: jsonResponse,
                model: "test",
                inputTokens: 0,
                outputTokens: 0
            ))
        )
        await aiManager.registerProvider(kind: .anthropic, provider: stubProvider)
        return (db, settings, aiManager)
    }

    private static func makeSequencedDependencies(
        jsonResponses: [String]
    ) async throws -> (db: DatabaseManager, settings: SettingsManager, aiManager: AIAssistantManager, provider: SequencedAIProvider) {
        let db = try DatabaseManager(inMemoryNamed: "vpstudio-discover-ai-sequenced-tests-\(UUID().uuidString)")
        try await db.migrate()
        let secretStore = TestSecretStore()
        let settings = SettingsManager(database: db, secretStore: secretStore)
        let aiManager = AIAssistantManager(database: db)
        let provider = SequencedAIProvider(jsonResponses: jsonResponses)
        await aiManager.registerProvider(kind: .anthropic, provider: provider)
        return (db, settings, aiManager, provider)
    }

    private static func makeUnconfiguredDependencies()
        async throws -> (db: DatabaseManager, settings: SettingsManager, aiManager: AIAssistantManager)
    {
        let db = try DatabaseManager(inMemoryNamed: "vpstudio-discover-ai-unconfigured-tests-\(UUID().uuidString)")
        try await db.migrate()
        let secretStore = TestSecretStore()
        let settings = SettingsManager(database: db, secretStore: secretStore)
        let aiManager = AIAssistantManager(database: db)
        return (db, settings, aiManager)
    }

    /// Creates a DiscoverViewModel with the given database so filterOutWatchedAndRated can query it.
    @MainActor
    private static func makeViewModel(database: DatabaseManager) -> DiscoverViewModel {
        DiscoverViewModel(database: database)
    }

    /// Builds a sample `AIMovieRecommendation`.
    private static func sampleRecommendation(
        title: String = "Test Movie",
        year: Int? = 2024,
        type: MediaType = .movie,
        reason: String = "Great",
        imdbId: String? = nil,
        tmdbId: Int? = 123
    ) -> AIMovieRecommendation {
        AIMovieRecommendation(
            title: title,
            year: year,
            type: type,
            reason: reason,
            imdbId: imdbId,
            tmdbId: tmdbId
        )
    }

    @Test
    func getRecommendationsNormalizesEmbeddedIMDbIDsFromProviderOutput() async throws {
        let deps = try await Self.makeDependencies(jsonResponse: """
        [{"title":"Dune","year":2021,"type":"movie","reason":"Epic scale","imdbId":"https://www.imdb.com/title/TT1160419/","tmdbId":438631}]
        """)

        let recommendations = try await deps.aiManager.getRecommendations(context: AssistantContext())

        let recommendation = try #require(recommendations.first)
        #expect(recommendation.imdbId == "tt1160419")
        #expect(recommendation.tmdbId == nil)
        #expect(recommendation.id == "movie-imdb-tt1160419")
    }

    // MARK: - Initial State

    @Test
    @MainActor
    func initialStateHasEmptyAIRecommendations() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)
        #expect(vm.aiRecommendations.isEmpty)
    }

    @Test
    @MainActor
    func aiRecommendationsEnabledDefaultsToFalse() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)
        #expect(vm.aiRecommendationsEnabled == false)
    }

    @Test
    @MainActor
    func isLoadingAIRecommendationsDefaultsToFalse() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)
        #expect(vm.isLoadingAIRecommendations == false)
    }

    // MARK: - loadAIRecommendationsIfNeeded

    @Test
    @MainActor
    func loadAIRecommendationsIfNeededDoesNothingWhenDisabled() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        // Explicitly disable to guard against state pollution from prior test runs
        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: false)

        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty)
        #expect(vm.aiRecommendationsEnabled == false)
        #expect(vm.isLoadingAIRecommendations == false)
    }

    @Test
    @MainActor
    func loadAIRecommendationsIfNeededSetsEnabledTrueWhenSettingIsOn() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        // Enable the setting
        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)

        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendationsEnabled == true)
    }

    @Test
    @MainActor
    func loadAIRecommendationsIfNeededHidesAIRowWhenNoProviderIsConfigured() async throws {
        let deps = try await Self.makeUnconfiguredDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)

        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty)
        #expect(vm.aiRecommendationsEnabled == false)
        #expect(vm.isLoadingAIRecommendations == false)
    }

    @Test
    @MainActor
    func loadAIRecommendationsIfNeededDoesNotDoubleLoad() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)

        // First call loads
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)
        let countAfterFirst = vm.aiRecommendations.count

        // Manually clear to detect if second call refetches
        vm.aiRecommendations = []

        // Second call should be a no-op because aiRecommendationsLoaded is true
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty, "Second call should not reload — guard prevents re-fetch")
        _ = countAfterFirst // Suppress unused warning
    }

    // MARK: - refreshAIRecommendations

    @Test
    @MainActor
    func refreshAIRecommendationsReloadsEvenAfterLoaded() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)

        // Initial load
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)
        #expect(!vm.aiRecommendations.isEmpty)

        // Clear manually
        vm.aiRecommendations = []
        #expect(vm.aiRecommendations.isEmpty)

        // refresh should re-fetch even though aiRecommendationsLoaded was true
        await vm.refreshAIRecommendations(aiManager: deps.aiManager)

        #expect(!vm.aiRecommendations.isEmpty, "Refresh should reload recommendations")
        #expect(vm.isLoadingAIRecommendations == false)
    }

    // MARK: - removeAIRecommendation(matchingMediaId:)

    @Test
    @MainActor
    func removeByMediaIdRemovesMatchingItem() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        let rec = Self.sampleRecommendation(title: "Test Movie", tmdbId: 123)
        vm.aiRecommendations = [rec]
        let mediaId = rec.toMediaPreview().id

        vm.removeAIRecommendation(matchingMediaId: mediaId)

        #expect(vm.aiRecommendations.isEmpty)
    }

    @Test
    @MainActor
    func removeByMediaIdLeavesNonMatchingItems() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        let rec1 = Self.sampleRecommendation(title: "Movie A", tmdbId: 100)
        let rec2 = Self.sampleRecommendation(title: "Movie B", tmdbId: 200)
        vm.aiRecommendations = [rec1, rec2]

        // Remove only rec1's media ID
        let mediaId = rec1.toMediaPreview().id
        vm.removeAIRecommendation(matchingMediaId: mediaId)

        #expect(vm.aiRecommendations.count == 1)
        #expect(vm.aiRecommendations.first?.title == "Movie B")
    }

    // MARK: - removeAIRecommendation(matchingTitle:)

    @Test
    @MainActor
    func removeByTitleIsCaseInsensitive() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        let rec = Self.sampleRecommendation(title: "Inception", tmdbId: 27205)
        vm.aiRecommendations = [rec]

        // Remove with different casing
        vm.removeAIRecommendation(matchingTitle: "INCEPTION")

        #expect(vm.aiRecommendations.isEmpty, "Removal should be case-insensitive")
    }

    @Test
    @MainActor
    func removeByTitleLeavesNonMatchingItems() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        let rec1 = Self.sampleRecommendation(title: "Arrival", tmdbId: 329865)
        let rec2 = Self.sampleRecommendation(title: "Interstellar", tmdbId: 157336)
        vm.aiRecommendations = [rec1, rec2]

        vm.removeAIRecommendation(matchingTitle: "arrival")

        #expect(vm.aiRecommendations.count == 1)
        #expect(vm.aiRecommendations.first?.title == "Interstellar")
    }

    // MARK: - Library Filtering (filterOutWatchedAndRated)

    /// Helper: adds a library entry and its cached media item so both mediaId and title matching work.
    private static func addLibraryEntry(
        db: DatabaseManager,
        mediaId: String,
        title: String,
        type: MediaType = .movie,
        listType: UserLibraryEntry.ListType = .watchlist,
        tmdbId: Int? = nil
    ) async throws {
        // Cache the media item so title-based lookup resolves
        let item = MediaItem(id: mediaId, type: type, title: title, tmdbId: tmdbId)
        try await db.saveMediaItem(item)

        let entry = UserLibraryEntry(
            id: "\(mediaId)-\(listType.rawValue)",
            mediaId: mediaId,
            folderId: "",
            listType: listType,
            addedAt: Date()
        )
        try await db.addToLibrary(entry)
    }

    @Test
    @MainActor
    func filterRemovesWatchlistItemByMediaId() async throws {
        let json = """
        [{"title":"Inception","year":2010,"type":"movie","reason":"Classic","tmdbId":27205},
         {"title":"Arrival","year":2016,"type":"movie","reason":"Thoughtful","tmdbId":329865}]
        """
        let deps = try await Self.makeDependencies(jsonResponse: json)
        let vm = Self.makeViewModel(database: deps.db)

        // Add Inception to watchlist
        try await Self.addLibraryEntry(
            db: deps.db,
            mediaId: "movie-tmdb-27205",
            title: "Inception",
            listType: .watchlist,
            tmdbId: 27205
        )

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.count == 1, "Watchlist item should be filtered out")
        #expect(vm.aiRecommendations.first?.title == "Arrival")
    }

    @Test
    @MainActor
    func filterRemovesFavoritesItemByMediaId() async throws {
        let json = """
        [{"title":"Arrival","year":2016,"type":"movie","reason":"Thoughtful","tmdbId":329865}]
        """
        let deps = try await Self.makeDependencies(jsonResponse: json)
        let vm = Self.makeViewModel(database: deps.db)

        // Add Arrival to favorites
        try await Self.addLibraryEntry(
            db: deps.db,
            mediaId: "movie-tmdb-329865",
            title: "Arrival",
            listType: .favorites,
            tmdbId: 329865
        )

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty, "Favorites item should be filtered out")
    }

    @Test
    @MainActor
    func filterRemovesLibraryItemByTitleWhenTmdbIdMissing() async throws {
        // Recommendation has no tmdbId — only title-based matching can filter it
        let json = """
        [{"title":"Inception","year":2010,"type":"movie","reason":"Classic"}]
        """
        let deps = try await Self.makeDependencies(jsonResponse: json)
        let vm = Self.makeViewModel(database: deps.db)

        // Add with a different mediaId format (e.g. IMDb-style) — title match should still catch it
        try await Self.addLibraryEntry(
            db: deps.db,
            mediaId: "movie-imdb-tt1375666",
            title: "Inception",
            listType: .watchlist
        )

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty, "Title-based library match should filter out recommendation")
    }

    @Test
    @MainActor
    func filterRemovesOMDbLibraryItemByResolvedIMDbCacheTitle() async throws {
        let json = """
        [{"title":"The Matrix","year":1999,"type":"movie","reason":"Essential sci-fi"}]
        """
        let deps = try await Self.makeDependencies(jsonResponse: json)
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.db.saveMediaItem(
            MediaItem(
                id: "tt0133093",
                type: .movie,
                title: "The Matrix",
                year: 1999
            )
        )
        try await deps.db.addToLibrary(
            UserLibraryEntry(
                id: "matrix-omdb-watchlist",
                mediaId: "movie-omdb-tt0133093",
                folderId: "",
                listType: .watchlist,
                addedAt: Date()
            )
        )

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty, "Resolved OMDb/IMDb title should filter library items")
    }

    @Test
    @MainActor
    func filterKeepsItemsNotInLibrary() async throws {
        let json = """
        [{"title":"Arrival","year":2016,"type":"movie","reason":"Thoughtful","tmdbId":329865},
         {"title":"Interstellar","year":2014,"type":"movie","reason":"Epic","tmdbId":157336}]
        """
        let deps = try await Self.makeDependencies(jsonResponse: json)
        let vm = Self.makeViewModel(database: deps.db)

        // Add only Arrival to watchlist — Interstellar should survive
        try await Self.addLibraryEntry(
            db: deps.db,
            mediaId: "movie-tmdb-329865",
            title: "Arrival",
            listType: .watchlist,
            tmdbId: 329865
        )

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.count == 1)
        #expect(vm.aiRecommendations.first?.title == "Interstellar")
    }

    @Test
    @MainActor
    func filterRemovesLibraryItemCaseInsensitiveTitle() async throws {
        let json = """
        [{"title":"INCEPTION","year":2010,"type":"movie","reason":"Classic","tmdbId":99999}]
        """
        let deps = try await Self.makeDependencies(jsonResponse: json)
        let vm = Self.makeViewModel(database: deps.db)

        // Library has lowercase title; recommendation has uppercase
        try await Self.addLibraryEntry(
            db: deps.db,
            mediaId: "movie-tmdb-27205",
            title: "inception",
            listType: .favorites,
            tmdbId: 27205
        )

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty, "Case-insensitive title match should filter library items")
    }

    @Test
    @MainActor
    func filterCombinesLibraryAndRatedAndWatched() async throws {
        let json = """
        [{"title":"Movie A","year":2024,"type":"movie","reason":"A","tmdbId":100},
         {"title":"Movie B","year":2024,"type":"movie","reason":"B","tmdbId":200},
         {"title":"Movie C","year":2024,"type":"movie","reason":"C","tmdbId":300}]
        """
        let deps = try await Self.makeDependencies(jsonResponse: json)
        let vm = Self.makeViewModel(database: deps.db)

        // Movie A: in library (watchlist)
        try await Self.addLibraryEntry(
            db: deps.db,
            mediaId: "movie-tmdb-100",
            title: "Movie A",
            listType: .watchlist,
            tmdbId: 100
        )

        // Movie B: rated via taste event
        let tasteEvent = TasteEvent(
            mediaId: "movie-tmdb-200",
            eventType: .rated,
            metadata: ["title": "Movie B", "rating": "8"]
        )
        try await deps.db.saveTasteEvent(tasteEvent)

        // Movie C: not in library, not rated, not watched — should survive
        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.count == 1, "Only Movie C should survive filtering")
        #expect(vm.aiRecommendations.first?.title == "Movie C")
    }

    @Test
    @MainActor
    func filterRemovesIMDbRecommendationWhenLegacyTMDBRatingResolvesThroughCache() async throws {
        let json = """
        [{"title":"Dune","year":2021,"type":"movie","reason":"Epic scale","imdbId":"tt1160419"}]
        """
        let deps = try await Self.makeDependencies(jsonResponse: json)
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.db.saveMediaItem(
            MediaItem(
                id: "tt1160419",
                type: .movie,
                title: "Dune",
                year: 2021,
                tmdbId: 438631
            )
        )
        try await deps.db.saveTasteEvent(
            TasteEvent(
                mediaId: "movie-tmdb-438631",
                eventType: .rated,
                feedbackScale: .oneToTen,
                feedbackValue: 8
            )
        )

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty, "Legacy TMDb ratings should suppress IMDb/OMDb recommendations for the same cached item")
    }

    @Test
    @MainActor
    func filterRemovesIMDbRecommendationWhenLegacyTMDBLibraryEntryResolvesThroughCache() async throws {
        let json = """
        [{"title":"Dune: Part One","year":2021,"type":"movie","reason":"Epic scale","imdbId":"tt1160419"}]
        """
        let deps = try await Self.makeDependencies(jsonResponse: json)
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.db.saveMediaItem(
            MediaItem(
                id: "tt1160419",
                type: .movie,
                title: "Dune",
                year: 2021,
                tmdbId: 438631
            )
        )
        try await deps.db.addToLibrary(
            UserLibraryEntry(
                id: "dune-legacy-watchlist",
                mediaId: "movie-tmdb-438631",
                folderId: "",
                listType: .watchlist,
                addedAt: Date()
            )
        )

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty, "Legacy TMDb library entries should suppress IMDb/OMDb recommendations for the same cached item")
    }

    @Test
    @MainActor
    func filterRemovesIMDbRecommendationWhenLegacyTMDBWatchHistoryResolvesThroughCache() async throws {
        let json = """
        [{"title":"Dune: Part One","year":2021,"type":"movie","reason":"Epic scale","imdbId":"tt1160419"}]
        """
        let deps = try await Self.makeDependencies(jsonResponse: json)
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.db.saveMediaItem(
            MediaItem(
                id: "tt1160419",
                type: .movie,
                title: "Dune",
                year: 2021,
                tmdbId: 438631
            )
        )
        try await deps.db.saveWatchHistory(
            WatchHistory(
                id: "dune-legacy-watch",
                mediaId: "movie-tmdb-438631",
                title: "Legacy Cached Title",
                progress: 7200,
                duration: 7200,
                watchedAt: Date(),
                isCompleted: true
            )
        )

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty, "Legacy TMDb watch history should suppress IMDb/OMDb recommendations for the same cached item")
    }

    @Test
    @MainActor
    func refreshLocalPersonalizationStateReloadsContinueWatchingAndReappliesFilters() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        vm.aiRecommendations = [
            Self.sampleRecommendation(title: "Watched Movie", tmdbId: 100),
            Self.sampleRecommendation(title: "Rated Movie", tmdbId: 200),
            Self.sampleRecommendation(title: "Watchlist Movie", tmdbId: 300),
            Self.sampleRecommendation(title: "Fresh Movie", tmdbId: 400),
        ]

        try await deps.db.saveMediaItem(
            MediaItem(
                id: "ttcontinue1",
                type: .movie,
                title: "Continue Watching",
                tmdbId: 900
            )
        )
        try await deps.db.saveWatchHistory(
            WatchHistory(
                id: "continue-watching-history",
                mediaId: "ttcontinue1",
                title: "Continue Watching",
                progress: 1800,
                duration: 3600,
                watchedAt: Date(),
                isCompleted: false
            )
        )

        try await deps.db.saveWatchHistory(
            WatchHistory(
                id: "watched-movie-history",
                mediaId: "movie-tmdb-100",
                title: "Watched Movie",
                progress: 7200,
                duration: 7200,
                watchedAt: Date(),
                isCompleted: true
            )
        )

        try await deps.db.saveTasteEvent(
            TasteEvent(
                mediaId: "movie-tmdb-200",
                eventType: .rated,
                metadata: ["title": "Rated Movie", "rating": "8"]
            )
        )

        try await Self.addLibraryEntry(
            db: deps.db,
            mediaId: "movie-tmdb-300",
            title: "Watchlist Movie",
            listType: .watchlist,
            tmdbId: 300
        )

        await vm.refreshLocalPersonalizationState()

        #expect(vm.continueWatching.count == 1)
        #expect(vm.continueWatching.first?.preview.title == "Continue Watching")
        #expect(vm.aiRecommendations.map(\.title) == ["Fresh Movie"])
    }

    // MARK: - Auto-generate Toggle

    @Test
    @MainActor
    func aiAutoGenerateDefaultsToTrue() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)
        #expect(vm.aiAutoGenerate == true, "aiAutoGenerate should default to true")
    }

    @Test
    @MainActor
    func autoGenerateOffSkipsAIFetchAndLoadsCachedRecommendations() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        // Enable AI row, disable auto-generate
        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        try await deps.settings.setBool(key: SettingsKeys.aiAutoGenerate, value: false)

        // Pre-cache some recommendations
        let cached = [Self.sampleRecommendation(title: "Cached Movie", tmdbId: 999)]
        let data = try JSONEncoder().encode(cached)
        let json = String(data: data, encoding: .utf8)!
        try await deps.settings.setString(key: SettingsKeys.aiCachedRecommendations, value: json)

        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiAutoGenerate == false, "aiAutoGenerate should be false after loading setting")
        #expect(vm.aiRecommendations.count == 1, "Should load cached recommendations")
        #expect(vm.aiRecommendations.first?.title == "Cached Movie", "Should show cached title")
    }

    @Test
    @MainActor
    func autoGenerateOffWithNoCacheResultsInEmptyRecommendations() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        // Enable AI row, disable auto-generate, explicitly clear any cached recommendations
        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        try await deps.settings.setBool(key: SettingsKeys.aiAutoGenerate, value: false)
        try await deps.settings.setString(key: SettingsKeys.aiCachedRecommendations, value: nil)

        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.isEmpty, "No cache means empty recommendations when auto-generate is off")
    }

    @Test
    @MainActor
    func regenerateAIRecommendationsWorksRegardlessOfToggleState() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        // Enable AI row, disable auto-generate, clear any cached data from prior tests
        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        try await deps.settings.setBool(key: SettingsKeys.aiAutoGenerate, value: false)
        try await deps.settings.setString(key: SettingsKeys.aiCachedRecommendations, value: nil)

        // Initial load should use cache (empty since no cache exists)
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)
        #expect(vm.aiRecommendations.isEmpty)

        // Regenerate should force-fetch from AI regardless of auto-generate being off
        await vm.regenerateAIRecommendations(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(!vm.aiRecommendations.isEmpty, "Regenerate should fetch new recommendations even when auto-generate is off")
        #expect(vm.aiRecommendations.first?.title == "Test Movie")
    }

    @Test
    @MainActor
    func regenerateAIRecommendationsCachesResults() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        // Regenerate fetches and should cache
        await vm.regenerateAIRecommendations(aiManager: deps.aiManager, settingsManager: deps.settings)
        #expect(!vm.aiRecommendations.isEmpty)

        // Verify cache was written by reading it back
        let cachedJSON = try await deps.settings.getString(key: SettingsKeys.aiCachedRecommendations)
        #expect(cachedJSON != nil, "Regenerate should cache recommendations")

        let data = cachedJSON!.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([AIMovieRecommendation].self, from: data)
        #expect(decoded.first?.title == "Test Movie", "Cached recommendations should match fetched ones")
    }

    @Test
    @MainActor
    func regenerateAIRecommendationsAvoidsPriorTitlesAndPassesExplicitExclusions() async throws {
        let deps = try await Self.makeSequencedDependencies(
            jsonResponses: [
                """
                [{"title":"Arrival","year":2016,"type":"movie","reason":"Thoughtful sci-fi","tmdbId":329865},
                 {"title":"Dune","year":2021,"type":"movie","reason":"Epic scale","tmdbId":438631}]
                """,
                """
                [{"title":"Arrival","year":2016,"type":"movie","reason":"Still thoughtful","tmdbId":329865},
                 {"title":"Dune","year":2021,"type":"movie","reason":"Still epic","tmdbId":438631}]
                """,
                """
                [{"title":"Arrival","year":2016,"type":"movie","reason":"Repeat","tmdbId":329865},
                 {"title":"Ex Machina","year":2014,"type":"movie","reason":"Sharp AI thriller","tmdbId":264660}]
                """
            ]
        )
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)

        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)
        #expect(vm.aiRecommendations.map(\.title) == ["Arrival", "Dune"])

        await vm.regenerateAIRecommendations(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiRecommendations.map(\.title) == ["Ex Machina"])

        let messages = await deps.provider.messages()
        #expect(messages.count == 4)
        #expect(messages.dropFirst().allSatisfy { $0.contains("Do not recommend any of these titles again: Arrival, Dune") })
    }

    @Test
    @MainActor
    func cachedRecommendationsRoundTripEncodeDecode() async throws {
        let recommendations = [
            Self.sampleRecommendation(title: "Movie A", year: 2024, type: .movie, reason: "Great", tmdbId: 100),
            Self.sampleRecommendation(title: "Show B", year: 2023, type: .series, reason: "Amazing", tmdbId: 200),
            Self.sampleRecommendation(title: "No TMDB", year: nil, type: .movie, reason: "Interesting", tmdbId: nil),
        ]

        let data = try JSONEncoder().encode(recommendations)
        let decoded = try JSONDecoder().decode([AIMovieRecommendation].self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded[0].title == "Movie A")
        #expect(decoded[0].year == 2024)
        #expect(decoded[0].type == .movie)
        #expect(decoded[0].reason == "Great")
        #expect(decoded[0].tmdbId == 100)
        #expect(decoded[1].title == "Show B")
        #expect(decoded[1].type == .series)
        #expect(decoded[2].title == "No TMDB")
        #expect(decoded[2].year == nil)
        #expect(decoded[2].tmdbId == nil)
    }

    @Test
    @MainActor
    func autoGenerateOnFetchesAndCachesRecommendations() async throws {
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        // Enable AI row, explicitly set auto-generate on (guards against prior test pollution)
        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
        try await deps.settings.setBool(key: SettingsKeys.aiAutoGenerate, value: true)

        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        #expect(vm.aiAutoGenerate == true)
        #expect(!vm.aiRecommendations.isEmpty, "Auto-generate on should fetch from AI")

        // Verify it also cached the result
        let cachedJSON = try await deps.settings.getString(key: SettingsKeys.aiCachedRecommendations)
        #expect(cachedJSON != nil, "Auto-generate on should also cache recommendations")
    }

    // MARK: - Sticky Cache Latch (BUG 5: re-fetch on every Discover tab switch)

    @Test
    @MainActor
    func loadAIRecommendationsIfNeededLatchesSynchronouslyBeforeAwait() async throws {
        // The latch must be set BEFORE the awaited fetch. Even though the fetch hasn't completed
        // (the gated provider is still suspended), a concurrent second call must already see the
        // latch and bail — this is what makes the cache survive a tab-leave that cancels the task
        // mid-flight.
        let deps = try await Self.makeGatedDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)

        let firstCall = Task { @MainActor in
            await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)
        }

        // Wait until we're parked inside the provider — at this point the synchronous latch ran.
        await deps.provider.waitUntilStarted()

        // A second call while the first is still in-flight must be a no-op (latch already set).
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        // Let the first fetch finish and settle.
        await deps.provider.release()
        await firstCall.value

        let callCount = await deps.provider.callCount()
        #expect(callCount == 1, "Provider must be invoked exactly once — the second call should short-circuit on the latch")
        #expect(vm.aiRecommendations.first?.title == "Gated Movie")
    }

    @Test
    @MainActor
    func cancellingInFlightLoadDoesNotUndoLatchOrRefetchOnReentry() async throws {
        // Simulates the BUG 5 scenario: the Discover tab is left mid-fetch (ContentView's
        // switch-based host tears DiscoverView down and cancels its `.task`). The latch was set
        // synchronously before the await, so it must survive cancellation — re-entering on the
        // next tab tap must NOT re-fire the slow LLM request.
        let deps = try await Self.makeGatedDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)

        let inFlight = Task { @MainActor in
            await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)
        }

        // Parked inside the provider await — the latch has already been set synchronously.
        await deps.provider.waitUntilStarted()

        // Tab teardown: cancel the in-flight task.
        inFlight.cancel()
        await inFlight.value

        // The cancelled fetch produced no recommendations…
        #expect(vm.aiRecommendations.isEmpty, "Cancelled fetch should not have populated recommendations")

        // …but re-entering (next tab tap) must be a no-op: the latch stuck through cancellation.
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)

        let callCount = await deps.provider.callCount()
        #expect(callCount == 1, "Re-entry after a cancelled load must not re-fire the LLM request — latch is sticky")
        #expect(vm.aiRecommendations.isEmpty)
    }

    @Test
    @MainActor
    func reloadAIRecommendationSettingsStillResetsLatchOnRealConfigChange() async throws {
        // Sticky latch must not block a deliberate re-fetch on a real config change.
        let deps = try await Self.makeDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)

        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)
        #expect(!vm.aiRecommendations.isEmpty)

        // Clear manually to detect a re-fetch.
        vm.aiRecommendations = []

        // A real settings change resets the latch and re-fetches.
        await vm.reloadAIRecommendationSettings(aiManager: deps.aiManager, settingsManager: deps.settings)
        #expect(!vm.aiRecommendations.isEmpty, "Config-change path must reset the sticky latch and reload")

        // And after that reload, the load-once guard is sticky again.
        vm.aiRecommendations = []
        await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)
        #expect(vm.aiRecommendations.isEmpty, "After a config-change reload, loadIfNeeded should be a no-op again")
    }

    // MARK: - Initial-Load Latch Policy (sticky across tab teardown)

    @Test
    func initialLoadPolicyStartsWhenNotYetLoaded() {
        #expect(DiscoverInitialLoadPolicy.shouldStart(hasPerformedInitialLoad: false))
        #expect(!DiscoverInitialLoadPolicy.shouldStart(hasPerformedInitialLoad: true))
    }

    @Test
    @MainActor
    func initialLoadLatchSetBeforeFetchSurvivesTabTeardown() async throws {
        // The fix sets `hasPerformedInitialLoad` synchronously BEFORE the awaited fetch (in the
        // DiscoverView `.task`). Model the latch+guard semantics directly: once latched, the
        // start-policy refuses to restart even though a cancelled `.task` never completed its fetch.
        let deps = try await Self.makeGatedDependencies()
        let vm = Self.makeViewModel(database: deps.db)

        #expect(DiscoverInitialLoadPolicy.shouldStart(hasPerformedInitialLoad: vm.hasPerformedInitialLoad))

        // Mirror the `.task`: latch first, then start the (cancellable) fetch.
        vm.hasPerformedInitialLoad = true
        let inFlight = Task { @MainActor in
            try await deps.settings.setBool(key: SettingsKeys.discoverAIRecommendationsEnabled, value: true)
            await vm.loadAIRecommendationsIfNeeded(aiManager: deps.aiManager, settingsManager: deps.settings)
        }
        await deps.provider.waitUntilStarted()
        inFlight.cancel()
        try? await inFlight.value

        // Tab returns: the start-policy must NOT restart the slow initial load.
        #expect(
            !DiscoverInitialLoadPolicy.shouldStart(hasPerformedInitialLoad: vm.hasPerformedInitialLoad),
            "A tab-leave that cancelled the .task mid-fetch must not re-arm the initial load"
        )
    }
}
