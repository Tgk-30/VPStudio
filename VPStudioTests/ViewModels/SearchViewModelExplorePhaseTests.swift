import Foundation
import SwiftUI
import Testing
@testable import VPStudio

@Suite("SearchViewModel - ExplorePhase & Recent Searches")
@MainActor
struct SearchViewModelExplorePhaseTests {

    // MARK: - Test Stubs

    private actor PhaseTestMetadataStub: MetadataProvider {
        struct SearchCall: Sendable, Equatable {
            let query: String
            let type: MediaType?
            let page: Int
            let year: Int?
            let language: String?
        }

        var searchQueries: [String] = []
        var searchCalls: [SearchCall] = []
        var searchResultByPage: [Int: MetadataSearchResult] = [:]
        var discoverResultByPage: [Int: MetadataSearchResult] = [:]
        var genresByType: [MediaType: [Genre]] = [:]

        func setSearchResults(_ results: [Int: MetadataSearchResult]) {
            searchResultByPage = results
        }

        func setDiscoverResults(_ results: [Int: MetadataSearchResult]) {
            discoverResultByPage = results
        }

        func setGenres(_ genres: [MediaType: [Genre]]) {
            genresByType = genres
        }

        func getSearchQueries() -> [String] {
            searchQueries
        }

        func getSearchCalls() -> [SearchCall] {
            searchCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchQueries.append(query)
            searchCalls.append(SearchCall(query: query, type: type, page: page, year: nil, language: nil))
            return searchResultByPage[page] ?? MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func search(
            query: String,
            type: MediaType?,
            page: Int,
            year: Int?,
            language: String?
        ) async throws -> MetadataSearchResult {
            searchQueries.append(query)
            searchCalls.append(SearchCall(query: query, type: type, page: page, year: year, language: language))
            return searchResultByPage[page] ?? MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverResultByPage[filters.page] ?? MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getGenres(type: MediaType) async throws -> [Genre] {
            genresByType[type] ?? []
        }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    private actor FailingSettingsManager: SearchSettingsStorage {
        enum SettingsManagerFailure: Error {
            case readFailure
            case writeFailure
        }

        private let readValue: String?
        private let shouldFailRead: Bool
        private let shouldFailWrite: Bool
        private var readCalls = 0
        private var writeCalls = 0

        init(readValue: String?, shouldFailRead: Bool = false, shouldFailWrite: Bool = false) {
            self.readValue = readValue
            self.shouldFailRead = shouldFailRead
            self.shouldFailWrite = shouldFailWrite
        }

        func getString(key: String) async throws -> String? {
            readCalls += 1
            if shouldFailRead {
                throw SettingsManagerFailure.readFailure
            }
            return readValue
        }

        func setString(key: String, value: String?) async throws {
            writeCalls += 1
            if shouldFailWrite {
                throw SettingsManagerFailure.writeFailure
            }
        }

        func getReadCallCount() -> Int {
            readCalls
        }

        func getWriteCallCount() -> Int {
            writeCalls
        }
    }

    /// Polls until `condition` returns true, yielding between checks. Fails after `timeout`.
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

    private static func waitUntil(
        timeout: Duration = .milliseconds(5000),
        _ condition: @MainActor () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while await !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("waitUntil timed out after \(timeout)")
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private static func makeRecentSearchSettingsManager() async throws -> SettingsManager {
        let database = try DatabaseManager(inMemoryNamed: UUID().uuidString)
        try await database.migrate()
        return SettingsManager(database: database, secretStore: TestSecretStore())
    }

    // MARK: - ExplorePhase Enum Cases

    @Test func explorePhaseHasFiveCases() {
        let cases: [ExplorePhase] = [.idle, .searching, .results, .empty, .error]
        #expect(cases.count == 5)
    }

    @Test func explorePhaseIdleCaseExists() {
        let phase = ExplorePhase.idle
        if case .idle = phase {
            // success
        } else {
            Issue.record("Expected .idle")
        }
    }

    @Test func explorePhaseSearchingCaseExists() {
        let phase = ExplorePhase.searching
        if case .searching = phase {
            // success
        } else {
            Issue.record("Expected .searching")
        }
    }

    @Test func explorePhaseResultsCaseExists() {
        let phase = ExplorePhase.results
        if case .results = phase {
            // success
        } else {
            Issue.record("Expected .results")
        }
    }

    @Test func explorePhaseEmptyCaseExists() {
        let phase = ExplorePhase.empty
        if case .empty = phase {
            // success
        } else {
            Issue.record("Expected .empty")
        }
    }

    @Test func explorePhaseErrorCaseExists() {
        let phase = ExplorePhase.error
        if case .error = phase {
            // success
        } else {
            Issue.record("Expected .error")
        }
    }

    // MARK: - Initial State

    @Test func initialPhaseIsIdle() {
        let viewModel = SearchViewModel()
        #expect(viewModel.explorePhase == .idle)
    }

    @Test func initialQueryIsEmpty() {
        let viewModel = SearchViewModel()
        #expect(viewModel.query.isEmpty)
    }

    @Test func initialResultsAreEmpty() {
        let viewModel = SearchViewModel()
        #expect(viewModel.results.isEmpty)
    }

    @Test func initialIsSearchingIsFalse() {
        let viewModel = SearchViewModel()
        #expect(viewModel.isSearching == false)
    }

    @Test func initialErrorIsNil() {
        let viewModel = SearchViewModel()
        #expect(viewModel.error == nil)
    }

    @Test func initialSelectedTypeIsNil() {
        let viewModel = SearchViewModel()
        #expect(viewModel.selectedType == nil)
    }

    @Test func initialCurrentPageIsOne() {
        let viewModel = SearchViewModel()
        #expect(viewModel.currentPage == 1)
    }

    @Test func initialTotalPagesIsOne() {
        let viewModel = SearchViewModel()
        #expect(viewModel.totalPages == 1)
    }

    @Test func initialHasMoreIsFalse() {
        let viewModel = SearchViewModel()
        #expect(viewModel.hasMore == false)
    }

    @Test func initialSearchGenerationIsZero() {
        let viewModel = SearchViewModel()
        #expect(viewModel.searchGeneration == 0)
    }

    @Test func initialIsLoadingMoreIsFalse() {
        let viewModel = SearchViewModel()
        #expect(viewModel.isLoadingMore == false)
    }

    @Test func initialScrollToTopTriggerIsZero() {
        let viewModel = SearchViewModel()
        #expect(viewModel.scrollToTopTrigger == 0)
    }

    @Test func initialRecentSearchesIsEmpty() {
        let viewModel = SearchViewModel()
        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func initialSelectedGenreIsNil() {
        let viewModel = SearchViewModel()
        #expect(viewModel.selectedGenre == nil)
    }

    @Test func initialSortOptionIsPopularityDesc() {
        let viewModel = SearchViewModel()
        #expect(viewModel.sortOption == .popularityDesc)
    }

    @Test func initialYearFilterIsNil() {
        let viewModel = SearchViewModel()
        #expect(viewModel.yearFilter == nil)
    }

    @Test func initialLanguageFiltersContainsEnUS() {
        let viewModel = SearchViewModel()
        #expect(viewModel.languageFilters == ["en-US"])
    }

    @Test func initialAiRecommendationsIsEmpty() {
        let viewModel = SearchViewModel()
        #expect(viewModel.aiRecommendations.isEmpty)
    }

    @Test func initialIsLoadingAIIsFalse() {
        let viewModel = SearchViewModel()
        #expect(viewModel.isLoadingAI == false)
    }

    @Test func initialAiErrorIsNil() {
        let viewModel = SearchViewModel()
        #expect(viewModel.aiError == nil)
    }

    @Test func initialIsGenreBrowsingIsFalse() {
        let viewModel = SearchViewModel()
        #expect(viewModel.isGenreBrowsing == false)
    }

    @Test func initialGenresIsEmpty() {
        let viewModel = SearchViewModel()
        #expect(viewModel.genres.isEmpty)
    }

    // MARK: - ExplorePhase Computed Property Transitions

    @Test func phaseIsSearchingWhenIsSearchingIsTrue() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.isSearching = true
        #expect(viewModel.explorePhase == .searching)
    }

    @Test func phaseIsResultsWhenResultsExist() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.results = [Fixtures.mediaPreview(id: "test-1")]
        #expect(viewModel.explorePhase == .results)
    }

    @Test func phaseIsResultsWhenAiRecommendationsExist() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Test", year: 2024, type: .movie, reason: "Good", tmdbId: 1)
        ]
        #expect(viewModel.explorePhase == .results)
    }

    @Test func phaseIsEmptyWhenGenreIsSelectedWithoutResults() async throws {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil { viewModel.explorePhase == .empty }
        #expect(viewModel.explorePhase == .empty)
        #expect(viewModel.emptyStateQuery == "Action")
    }

    @Test func phaseIsEmptyWhenMoodCardIsSelectedWithoutResults() async throws {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        viewModel.selectMoodCard(newReleasesCard)

        try await Self.waitUntil { viewModel.explorePhase == .empty }
        #expect(viewModel.explorePhase == .empty)
        #expect(viewModel.emptyStateQuery == "New Releases")
    }

    @Test func phaseStaysIdleWhenQueryExistsButSearchHasNotStarted() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.query = "no match query"
        #expect(viewModel.explorePhase == .idle)
    }

    @Test func phaseIsIdleWhenQueryIsEmptyAndNoResults() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.query = ""
        viewModel.results = []
        #expect(viewModel.explorePhase == .idle)
    }

    @Test func phaseIsIdleWhenQueryIsWhitespaceOnly() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.query = "   "
        #expect(viewModel.explorePhase == .idle)
    }

    @Test func phaseIsIdleWhenQueryIsNewlineOnly() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.query = "\n"
        #expect(viewModel.explorePhase == .idle)
    }

    @Test func phaseIsEmptyAfterSubmittedSearchReturnsNoResults() async throws {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.query = "no match query"
        viewModel.search()

        try await Self.waitUntil { viewModel.explorePhase == .empty }
        #expect(viewModel.explorePhase == .empty)
    }

    @Test func explicitSearchRunsWhenQueryAlreadyInRecentSearches() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "cid-season-2")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.addRecentSearch("CID season 2")
        viewModel.query = "CID season 2"

        viewModel.search()

        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(await stub.getSearchQueries() == ["CID season 2"])
        #expect(viewModel.submittedQuery == "CID season 2")
        #expect(viewModel.query == "CID season 2")
        #expect(viewModel.results.isEmpty == false)
        #expect(viewModel.explorePhase == .results)
        #expect(viewModel.explorePhase != .idle)
    }

    @Test func phaseIsErrorAfterSearchAttemptWithoutConfiguration() {
        let viewModel = SearchViewModel()
        viewModel.query = "no key query"
        viewModel.search()

        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.submittedQuery == "no key query")
        #expect(viewModel.error == .metadataSetupRequired(feature: "Search"))
        #expect(viewModel.explorePhase == .error)
    }

    @Test func queryEditAfterUnconfiguredAttemptReturnsPhaseToIdleUntilNextSearch() {
        let viewModel = SearchViewModel()
        viewModel.query = "first query"
        viewModel.search()

        #expect(viewModel.explorePhase == .error)

        viewModel.query = "second query"
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.error == nil)
        #expect(viewModel.explorePhase == .idle)
    }

    @Test func queryEditAfterEmptySearchReturnsPhaseToIdleUntilNextSearch() async throws {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.query = "first query"
        viewModel.search()
        try await Self.waitUntil { viewModel.explorePhase == .empty }

        viewModel.query = "second query"
        #expect(viewModel.explorePhase == .idle)
    }

    @Test func searchingTakesPriorityOverResults() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.isSearching = true
        viewModel.results = [Fixtures.mediaPreview(id: "test-1")]
        #expect(viewModel.explorePhase == .searching)
    }

    @Test func searchingTakesPriorityOverEmpty() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.isSearching = true
        viewModel.query = "something"
        #expect(viewModel.explorePhase == .searching)
    }

    @Test func resultsTakesPriorityOverEmpty() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.query = "something"
        viewModel.results = [Fixtures.mediaPreview(id: "test-1")]
        #expect(viewModel.explorePhase == .results)
    }

    @Test func phaseIsErrorWhenErrorExistsAndNoResults() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.error = .network(.transport("Search failed."))
        viewModel.results = []
        #expect(viewModel.explorePhase == .error)
    }

    @Test func phaseIsResultsWhenErrorExistsButResultsAlsoExist() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.error = .network(.transport("Partial failure"))
        viewModel.results = [Fixtures.mediaPreview(id: "test-1")]
        #expect(viewModel.explorePhase == .results)
    }

    @Test func searchingTakesPriorityOverError() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.isSearching = true
        viewModel.error = .network(.transport("Error"))
        #expect(viewModel.explorePhase == .searching)
    }

    @Test func errorTakesPriorityOverEmptyAndIdle() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.error = .network(.transport("Error"))
        viewModel.query = ""
        viewModel.results = []
        // error != nil && results.isEmpty => .error (checked before hasQuery)
        #expect(viewModel.explorePhase == .error)
    }

    // MARK: - primaryLanguage Computed Property

    @Test func primaryLanguageReturnsPreferredLanguageWhenMultipleLanguagesAreSelected() {
        let viewModel = SearchViewModel()
        viewModel.languageFilters = ["fr-FR", "en-US"]
        #expect(viewModel.primaryLanguage == "fr-FR")
    }

    @Test func primaryLanguageReturnsSingleLanguage() {
        let viewModel = SearchViewModel()
        viewModel.languageFilters = ["ja-JP"]
        #expect(viewModel.primaryLanguage == "ja-JP")
    }

    @Test func primaryLanguageReturnsNilWhenEmpty() {
        let viewModel = SearchViewModel()
        viewModel.languageFilters = []
        #expect(viewModel.primaryLanguage == nil)
    }

    // MARK: - Recent Searches: Add

    @Test func addRecentSearchInsertsAtFront() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("Interstellar")
        viewModel.addRecentSearch("Dune")
        #expect(viewModel.recentSearches == ["Dune", "Interstellar"])
    }

    @Test func addRecentSearchTrimsWhitespace() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("  Inception  ")
        #expect(viewModel.recentSearches == ["Inception"])
    }

    @Test func addRecentSearchIgnoresEmptyString() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("")
        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func addRecentSearchIgnoresWhitespaceOnly() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("   ")
        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func addRecentSearchIgnoresNewlineOnlyWhitespace() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("\n")
        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func addRecentSearchDeduplicatesCaseInsensitive() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("inception")
        viewModel.addRecentSearch("INCEPTION")
        #expect(viewModel.recentSearches.count == 1)
        #expect(viewModel.recentSearches.first == "INCEPTION")
    }

    @Test func addRecentSearchMovesDuplicateToFront() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("Dune")
        viewModel.addRecentSearch("Interstellar")
        viewModel.addRecentSearch("Dune")
        #expect(viewModel.recentSearches == ["Dune", "Interstellar"])
    }

    @Test func addRecentSearchCapsAtTwenty() {
        let viewModel = SearchViewModel()
        for i in 1...25 {
            viewModel.addRecentSearch("Search \(i)")
        }
        #expect(viewModel.recentSearches.count == 20)
        #expect(viewModel.recentSearches.first == "Search 25")
        #expect(viewModel.recentSearches.last == "Search 6")
    }

    @Test func addRecentSearchPreservesExistingOrder() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("Alpha")
        viewModel.addRecentSearch("Beta")
        viewModel.addRecentSearch("Gamma")
        #expect(viewModel.recentSearches == ["Gamma", "Beta", "Alpha"])
    }

    // MARK: - Recent Searches: Remove

    @Test func removeRecentSearchRemovesExactMatch() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("Alpha")
        viewModel.addRecentSearch("Beta")
        viewModel.removeRecentSearch("Alpha")
        #expect(viewModel.recentSearches == ["Beta"])
    }

    @Test func removeRecentSearchDoesNothingForNonexistent() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("Alpha")
        viewModel.removeRecentSearch("Beta")
        #expect(viewModel.recentSearches == ["Alpha"])
    }

    @Test func removeRecentSearchIsCaseSensitive() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("Alpha")
        viewModel.removeRecentSearch("alpha")
        // removeAll uses exact match ($0 == term), not lowercased
        #expect(viewModel.recentSearches == ["Alpha"])
    }

    // MARK: - Recent Searches: Clear

    @Test func clearRecentSearchesRemovesAll() {
        let viewModel = SearchViewModel()
        viewModel.addRecentSearch("Alpha")
        viewModel.addRecentSearch("Beta")
        viewModel.addRecentSearch("Gamma")
        viewModel.clearRecentSearches()
        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func clearRecentSearchesOnEmptyListIsNoop() {
        let viewModel = SearchViewModel()
        viewModel.clearRecentSearches()
        #expect(viewModel.recentSearches.isEmpty)
    }

    // MARK: - Recent Searches: Load

    @Test func loadRecentSearchesTrimsWhitespaceAndDeduplicatesPersistedValues() async throws {
        let settingsManager = try await Self.makeRecentSearchSettingsManager()
        let savedSearches = [
            "  Dune  ",
            "   ",
            "\n",
            "Inception",
            "\t",
            "dune",
            "  Interstellar ",
            "",
            "Interstellar",
            "Blade Runner  "
        ]
        let json = String(data: try JSONEncoder().encode(savedSearches), encoding: .utf8)!
        try await settingsManager.setString(key: SettingsKeys.recentSearches, value: json)

        let viewModel = SearchViewModel()
        await viewModel.loadRecentSearchesAndAwait(from: settingsManager)

        #expect(viewModel.recentSearches == ["Dune", "Inception", "Interstellar", "Blade Runner"])
    }

    @Test func loadRecentSearchesCapsToTwentyEntries() async throws {
        let settingsManager = try await Self.makeRecentSearchSettingsManager()
        let savedSearches = (1...25).map { " Search \($0) " }
        let json = String(data: try JSONEncoder().encode(savedSearches), encoding: .utf8)!
        try await settingsManager.setString(key: SettingsKeys.recentSearches, value: json)

        let viewModel = SearchViewModel()
        await viewModel.loadRecentSearchesAndAwait(from: settingsManager)

        #expect(viewModel.recentSearches.count == 20)
        #expect(viewModel.recentSearches == (1...20).map { "Search \($0)" })
    }

    @Test func loadRecentSearchesAndAwaitWithNoStoredValueClearsList() async throws {
        let settingsManager = try await Self.makeRecentSearchSettingsManager()
        let viewModel = SearchViewModel()
        viewModel.recentSearches = ["stale"]

        await viewModel.loadRecentSearchesAndAwait(from: settingsManager)

        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func loadRecentSearchesAndAwaitWithMalformedJSONFallsBackToEmpty() async throws {
        let settingsManager = try await Self.makeRecentSearchSettingsManager()
        try await settingsManager.setString(key: SettingsKeys.recentSearches, value: "1234")

        let viewModel = SearchViewModel()
        viewModel.recentSearches = ["stale"]

        await viewModel.loadRecentSearchesAndAwait(from: settingsManager)

        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func loadRecentSearchesHandlesMalformedStoredJSON() async throws {
        let settingsManager = try await Self.makeRecentSearchSettingsManager()
        try await settingsManager.setString(key: SettingsKeys.recentSearches, value: "not-json")

        let viewModel = SearchViewModel()
        await viewModel.loadRecentSearchesAndAwait(from: settingsManager)

        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func loadRecentSearchesAndAwaitWithSettingsReadFailureClearsExistingRecentSearches() async throws {
        let settingsManager = FailingSettingsManager(
            readValue: "[\"Interstellar\", \"Dune\"]",
            shouldFailRead: true
        )
        let viewModel = SearchViewModel()
        viewModel.recentSearches = ["stale", "legacy"]

        await viewModel.loadRecentSearchesAndAwait(from: settingsManager)

        #expect(viewModel.recentSearches.isEmpty)
        #expect(await settingsManager.getReadCallCount() == 1)
    }

    @Test func loadRecentSearchesFromManagerWithSettingsReadFailureEmitsEmptyList() async throws {
        let settingsManager = FailingSettingsManager(
            readValue: "[\"Interstellar\", \"Dune\"]",
            shouldFailRead: true
        )
        let viewModel = SearchViewModel()
        viewModel.recentSearches = ["stale"]

        viewModel.loadRecentSearches(from: settingsManager)

        try await Task.sleep(for: .milliseconds(80))

        #expect(viewModel.recentSearches.isEmpty)
        #expect(await settingsManager.getReadCallCount() == 1)
    }

    @Test func loadRecentSearchesFromManagerIsAsyncAndNormalizesTerms() async throws {
        let settingsManager = try await Self.makeRecentSearchSettingsManager()
        let savedSearches = ["  dune  ", "\n", "Inception", "DUNE", "blade runner ", "  "]
        let json = String(data: try JSONEncoder().encode(savedSearches), encoding: .utf8)!
        try await settingsManager.setString(key: SettingsKeys.recentSearches, value: json)

        let viewModel = SearchViewModel()
        viewModel.recentSearches = ["stale"]

        viewModel.loadRecentSearches(from: settingsManager)

        #expect(viewModel.recentSearches == ["stale"])

        try await Self.waitUntil { viewModel.recentSearches == ["dune", "Inception", "blade runner"] }
    }

    @Test func loadRecentSearchesFromManagerOnlyEmptyTermsClearsList() async throws {
        let settingsManager = try await Self.makeRecentSearchSettingsManager()
        let savedSearches = ["   ", "", "\n", "\t", ""]
        let json = String(data: try JSONEncoder().encode(savedSearches), encoding: .utf8)!
        try await settingsManager.setString(key: SettingsKeys.recentSearches, value: json)

        let viewModel = SearchViewModel()
        viewModel.recentSearches = ["stale", "legacy"]

        viewModel.loadRecentSearches(from: settingsManager)
        #expect(viewModel.recentSearches == ["stale", "legacy"])

        try await Self.waitUntil { viewModel.recentSearches.isEmpty }
        #expect(viewModel.recentSearches.isEmpty)
    }

    @Test func saveRecentSearchesPersistsNormalizedListToSettingsManager() async throws {
        let settingsManager = try await Self.makeRecentSearchSettingsManager()
        let viewModel = SearchViewModel()

        viewModel.addRecentSearch("  Inception  ")
        viewModel.addRecentSearch("Dune")
        viewModel.saveRecentSearches(to: settingsManager)

        var restored: [String] = []
        for _ in 0..<20 {
            if let json = try await settingsManager.getString(key: SettingsKeys.recentSearches),
               let decoded = try? JSONDecoder().decode([String].self, from: json.data(using: .utf8)!) {
                restored = decoded
                if !restored.isEmpty {
                    break
                }
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(restored == ["Dune", "Inception"])
    }

    @Test func saveRecentSearchesCapturesStateAtCallTime() async throws {
        let settingsManager = try await Self.makeRecentSearchSettingsManager()
        let viewModel = SearchViewModel()

        viewModel.recentSearches = ["first", "second"]
        viewModel.saveRecentSearches(to: settingsManager)
        viewModel.recentSearches = ["changed"]

        var restored: [String] = []
        for _ in 0..<20 {
            if let json = try await settingsManager.getString(key: SettingsKeys.recentSearches),
               let decoded = try? JSONDecoder().decode([String].self, from: json.data(using: .utf8)!) {
                restored = decoded
                if !restored.isEmpty {
                    break
                }
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(restored == ["first", "second"])
    }

    @Test func saveRecentSearchesWithSettingsWriteFailurePreservesInMemoryState() async throws {
        let settingsManager = FailingSettingsManager(readValue: nil, shouldFailWrite: true)
        let viewModel = SearchViewModel()

        viewModel.addRecentSearch("  Inception  ")
        viewModel.saveRecentSearches(to: settingsManager)

        try await Task.sleep(for: .milliseconds(80))

        #expect(viewModel.recentSearches == ["Inception"])
        #expect(await settingsManager.getWriteCallCount() == 1)
    }

    @Test func saveRecentSearchesPersistsClearedListAsEmptyArray() async throws {
        let settingsManager = try await Self.makeRecentSearchSettingsManager()
        let viewModel = SearchViewModel()

        viewModel.recentSearches = ["first", "second"]
        viewModel.clearRecentSearches()
        viewModel.saveRecentSearches(to: settingsManager)

        var restored: [String]?
        for _ in 0..<20 {
            if let json = try await settingsManager.getString(key: SettingsKeys.recentSearches),
               let decoded = try? JSONDecoder().decode([String].self, from: json.data(using: .utf8)!) {
                restored = decoded
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(restored == [])
    }

    // MARK: - hasMore Computed Property

    @Test func hasMoreTrueWhenMorePagesExist() {
        let viewModel = SearchViewModel()
        viewModel.currentPage = 1
        viewModel.totalPages = 3
        #expect(viewModel.hasMore == true)
    }

    @Test func hasMoreFalseWhenOnLastPage() {
        let viewModel = SearchViewModel()
        viewModel.currentPage = 3
        viewModel.totalPages = 3
        #expect(viewModel.hasMore == false)
    }

    @Test func hasMoreFalseWhenSinglePage() {
        let viewModel = SearchViewModel()
        viewModel.currentPage = 1
        viewModel.totalPages = 1
        #expect(viewModel.hasMore == false)
    }

    // MARK: - Mood Card Selection

    @Test func selectNewReleasesMoodCardSetsSortToReleaseDateDesc() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "new-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        viewModel.selectMoodCard(newReleasesCard)

        #expect(viewModel.sortOption == .releaseDateDesc)
        #expect(viewModel.selectedGenre == nil)
    }

    @Test func selectGenreMoodCardSetsSelectedGenre() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "action-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let actionCard = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!
        viewModel.selectMoodCard(actionCard)

        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(viewModel.selectedGenre != nil)
        // For movies (default), uses movieGenreId
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.selectedGenre?.name == "Action")
    }

    @Test func selectMoodCardUsesTvGenreIdForSeries() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "action-tv")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .series
        let actionCard = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!
        viewModel.selectMoodCard(actionCard)

        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(viewModel.selectedGenre?.id == 10759)
    }

    @Test func selectMoodCardUsesMovieGenreIdForMovies() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "action-movie")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .movie
        let actionCard = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!
        viewModel.selectMoodCard(actionCard)

        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(viewModel.selectedGenre?.id == 28)
    }

    @Test func selectMoodCardUsesMovieGenreIdWhenSelectedTypeIsNil() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "scifi-default")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = nil
        let scifiCard = ExploreGenreCatalog.cards.first(where: { $0.id == "scifi" })!
        viewModel.selectMoodCard(scifiCard)

        try await Self.waitUntil { !viewModel.results.isEmpty }
        // selectedType nil defaults to .movie in selectMoodCard
        #expect(viewModel.selectedGenre?.id == 878)
    }

    // MARK: - Clear Resets Language Filters

    @Test func clearResetsLanguageFiltersToDefault() {
        let viewModel = SearchViewModel()
        viewModel.languageFilters = ["ja-JP", "ko-KR"]
        viewModel.clear()
        #expect(viewModel.languageFilters == ["en-US"])
    }


    private final class MetadataFactoryCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var callCountValue = 0
        private var lastKeyValue: String?

        func record(key: String) {
            lock.lock()
            callCountValue += 1
            lastKeyValue = key
            lock.unlock()
        }

        func callCount() -> Int {
            lock.lock(); defer { lock.unlock() }
            return callCountValue
        }

        func lastKey() -> String? {
            lock.lock(); defer { lock.unlock() }
            return lastKeyValue
        }
    }

    // MARK: - Configure

    @Test func configureWithSameKeyDoesNotRecreateService() async throws {
        let capture = MetadataFactoryCapture()
        let viewModel = SearchViewModel(metadataServiceFactory: { key in
            capture.record(key: key)
            return PhaseTestMetadataStub()
        })
        viewModel.configure(apiKey: "my-key")
        let firstCount = capture.callCount()
        viewModel.configure(apiKey: "my-key")
        #expect(capture.callCount() == firstCount, "Factory should not be called again for same key")
    }

    @Test func configureTrimsApiKey() async throws {
        let capture = MetadataFactoryCapture()
        let viewModel = SearchViewModel(metadataServiceFactory: { key in
            capture.record(key: key)
            return PhaseTestMetadataStub()
        })
        viewModel.configure(apiKey: "  my-key  ")
        #expect(capture.lastKey() == "my-key")
    }

    // MARK: - Apply Language Filters

    @Test func applyLanguageFiltersUpdatesFilters() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.applyLanguageFilters(["ja-JP", "ko-KR"])
        #expect(viewModel.languageFilters == ["ja-JP", "ko-KR"])
    }

    @Test func applyLanguageFiltersReplacesExistingSelection() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.languageFilters = ["fr-FR"]
        viewModel.applyLanguageFilters(["ja-JP"])

        #expect(viewModel.languageFilters == ["ja-JP"])
        #expect(viewModel.primaryLanguage == "ja-JP")
    }

    @Test func applyLanguageFiltersFiltersOutEmptyValuesAndRequeriesSearch() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "dune"
        viewModel.search()
        try await Self.waitUntil { !viewModel.results.isEmpty }
        let initialSearchCalls = await stub.getSearchQueries().count

        viewModel.applyLanguageFilters(["", "fr-FR"])
        let expectedSearchCalls = initialSearchCalls + 1
        for _ in 0..<100 {
            if await stub.getSearchQueries().count == expectedSearchCalls {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(viewModel.languageFilters == ["fr-FR"])
        #expect(viewModel.primaryLanguage == "fr-FR")
        #expect(await stub.getSearchQueries().count == expectedSearchCalls)
    }

    @Test func applyLanguageFiltersDoesNotRequeryWhenSelectionUnchanged() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.languageFilters = ["en-US", "fr-FR"]
        viewModel.query = "dune"
        viewModel.search()

        for _ in 0..<100 {
            if await stub.getSearchQueries().count > 0 {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        let initialSearchCalls = await stub.getSearchQueries().count

        viewModel.applyLanguageFilters(["fr-FR", "en-US", "", "fr-FR"])
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(await stub.getSearchQueries().count == initialSearchCalls)
    }

    @Test func applyLanguageFiltersToEmptySet() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.applyLanguageFilters([])
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(viewModel.primaryLanguage == nil)
    }

    @Test func applySortOptionTriggersRequeryForActiveSearch() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "initial")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "Dune"
        viewModel.search()
        try await Self.waitUntil { (await stub.getSearchQueries()).count > 0 }

        let callsBefore = (await stub.getSearchQueries()).count
        viewModel.applySortOption(.releaseDateDesc)
        try await Self.waitUntil { (await stub.getSearchQueries()).count == callsBefore + 1 }

        #expect(viewModel.sortOption == .releaseDateDesc)
    }

    @Test func applyYearFilterLocallyFiltersResultsWhenTypeIsNil() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "match", year: 2024),
                    Fixtures.mediaPreview(id: "nomatch", year: 2023)
                ],
                page: 1,
                totalPages: 1,
                totalResults: 2
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "Dune"
        viewModel.search()
        try await Self.waitUntil { viewModel.results.count == 2 }

        viewModel.applyYearFilter(2024)
        try await Self.waitUntil { viewModel.results.count == 1 }

        #expect(viewModel.yearFilter == 2024)
        #expect(viewModel.results.map(\.id) == ["match"])
    }

    @Test func applyYearRangePresetUsesStartYearHintAndLocallyFiltersRange() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "twenties", year: 2022),
                    Fixtures.mediaPreview(id: "nineties", year: 1994)
                ],
                page: 1,
                totalPages: 1,
                totalResults: 2
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "classic"
        viewModel.search()
        try await Self.waitUntil { !viewModel.results.isEmpty }
        let callsBefore = (await stub.getSearchQueries()).count

        viewModel.applyYearRangePreset(.classic)
        try await Self.waitUntil { (await stub.getSearchQueries()).count == callsBefore + 1 }
        let searchCalls = await stub.getSearchCalls()
        #expect(viewModel.yearRangePreset == .classic)
        #expect(viewModel.yearFilter == 1900)
        #expect(searchCalls.last?.year == 1900)
        #expect(viewModel.results.map(\.id) == ["nineties"])
    }

    @Test func toggleLanguageCodeSwitchesDefaultAndPreservesNonDefaultSelection() {
        let viewModel = SearchViewModel()

        viewModel.toggleLanguage("en-US")
        #expect(viewModel.languageFilters.isEmpty)

        viewModel.toggleLanguage("en-US")
        #expect(viewModel.languageFilters == ["en-US"])

        viewModel.toggleLanguage("fr-FR")
        #expect(viewModel.languageFilters == ["fr-FR"])

        viewModel.toggleLanguage("fr-FR")
        #expect(viewModel.languageFilters == ["en-US"])
    }

    @Test func applyFilterDraftWithGenreChangesSelection() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedGenre = Genre(id: 10, name: "Old")
        let draft = SearchFilterDraft(
            sortOption: .releaseDateDesc,
            selectedYear: nil,
            selectedLanguages: ["en-US"],
            selectedGenre: Genre(id: 18, name: "Drama")
        )

        viewModel.applyFilterDraft(draft)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        #expect(viewModel.selectedGenre?.id == 18)
        #expect(viewModel.sortOption == .releaseDateDesc)
        #expect(viewModel.results.first?.id == "genre-result")
    }

    @Test func clearAllFiltersWithoutGenreAndActiveQueryRequeriesSearch() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fresh")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "dune"
        viewModel.search()
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let queriesBefore = (await stub.getSearchQueries()).count
        viewModel.clearAllFilters()

        let expectedQueries = queriesBefore + 1
        try await Self.waitUntil { (await stub.getSearchQueries()).count == expectedQueries }
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.yearFilter == nil)
        #expect(viewModel.yearRangePreset == nil)
        #expect(viewModel.languageFilters == ["en-US"])
    }

    @Test func handleSelectedTypeChangeWithoutGenreCacheClearsSelectionForEmptyQuery() {
        let viewModel = SearchViewModel(metadataService: PhaseTestMetadataStub())
        viewModel.selectedGenre = Genre(id: 18, name: "Drama")
        viewModel.selectedType = .movie
        viewModel.results = [Fixtures.mediaPreview(id: "stale")]

        viewModel.handleSelectedTypeChange()

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
    }

    @Test func handleSelectedTypeChangeUsesCachedGenreRemap() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "remapped-browse-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])
        await stub.setGenres([
            .movie: [Genre(id: 28, name: "Movie Action")],
            .series: [Genre(id: 28, name: "Series Action"), Genre(id: 18, name: "Drama")]
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .movie
        viewModel.loadGenres()
        try await Task.sleep(for: .milliseconds(20))

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Task.sleep(for: .milliseconds(20))

        viewModel.handleSelectedTypeChange()
        try await Self.waitUntil { !viewModel.results.isEmpty }

        #expect(viewModel.selectedGenre?.name == "Series Action")
        #expect(viewModel.results.first?.id == "remapped-browse-result")
    }

    @Test func clearAllFiltersWithActiveGenreRequeriesTextSearchIfQueryPresent() async throws {
        let stub = PhaseTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-requery")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = "dune"
        viewModel.search()
        try await Self.waitUntil { !viewModel.results.isEmpty }
        let queryCallsBefore = (await stub.getSearchQueries()).count

        viewModel.clearAllFilters()
        try await Self.waitUntil { (await stub.getSearchQueries()).count == queryCallsBefore + 1 }

        #expect(viewModel.selectedGenre == nil)
    }

    @Test func shouldTriggerPaginationUsesTailWindow() {
        let viewModel = SearchViewModel()
        viewModel.currentPage = 1
        viewModel.totalPages = 3
        viewModel.results = (0..<10).map { Fixtures.mediaPreview(id: "item-\($0)") }

        #expect(viewModel.hasMore == true)
        #expect(viewModel.shouldTriggerPagination(for: "item-8") == true)
        #expect(viewModel.shouldTriggerPagination(for: "item-4") == false)
    }
}
