import Testing
@testable import VPStudio

@Suite("SearchViewModel - Regression Coverage")
struct SearchViewModelRegressionTests {
    private actor SearchRegressionMetadataStub: MetadataProvider {
        private var searchCalls: [String] = []

        func reset() {
            searchCalls.removeAll()
        }

        func getSearchCalls() -> [String] {
            searchCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCalls.append(query)
            return MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "result-\(query)-p\(page)")],
                page: page,
                totalPages: page,
                totalResults: 1
            )
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchTrackingMetadataStub: MetadataProvider {
        private var searchCalls = 0

        func getSearchCallCount() -> Int {
            searchCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCalls += 1
            return MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "result-\(page)")],
                page: page,
                totalPages: page,
                totalResults: 1
            )
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchFilterAwareMetadataStub: MetadataProvider {
        struct SearchCall: Sendable, Equatable {
            let query: String
            let page: Int
            let year: Int?
            let language: String?
        }

        private var searchCalls: [SearchCall] = []
        private var discoverCalls: [DiscoverFilters] = []

        func reset() {
            searchCalls.removeAll()
            discoverCalls.removeAll()
        }

        func getSearchCalls() -> [SearchCall] {
            searchCalls
        }

        func getDiscoverCalls() -> [DiscoverFilters] {
            discoverCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            try await search(query: query, type: type, page: page, year: nil, language: nil)
        }

        func search(
            query: String,
            type: MediaType?,
            page: Int,
            year: Int?,
            language: String?
        ) async throws -> MetadataSearchResult {
            searchCalls.append(SearchCall(query: query, page: page, year: year, language: language))
            return MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "result-\(query)-p\(page)")],
                page: page,
                totalPages: page,
                totalResults: 1
            )
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCalls.append(filters)
            return MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchMetadataDelayStub: MetadataProvider {
        private var responses: [Int: MetadataSearchResult] = [:]
        private var delays: [Int: Duration] = [:]
        private var searchCalls: [(query: String, page: Int)] = []

        func setSearchResponse(
            _ result: MetadataSearchResult,
            for page: Int,
            delay: Duration? = nil
        ) {
            responses[page] = result
            if let delay {
                delays[page] = delay
            }
        }

        func getSearchCalls() -> [(query: String, page: Int)] {
            searchCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCalls.append((query, page))

            if let delay = delays[page] {
                try await Task.sleep(for: delay)
            }

            return responses[page] ?? MetadataSearchResult(
                items: [],
                page: page,
                totalPages: page,
                totalResults: 0
            )
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    private actor SearchGenreLoadDelayMetadataStub: MetadataProvider {
        private var genres: [MediaType: [Genre]] = [:]
        private var delays: [MediaType: Duration] = [:]
        private var genreLoadCalls: [MediaType] = []

        func setGenres(_ genres: [Genre], for type: MediaType = .movie) {
            self.genres[type] = genres
        }

        func setGenreLoadDelay(_ delay: Duration, for type: MediaType = .movie) {
            delays[type] = delay
        }

        func getGenreLoadCalls() -> [MediaType] {
            genreLoadCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getGenres(type: MediaType) async throws -> [Genre] {
            genreLoadCalls.append(type)

            if let delay = delays[type] {
                try await Task.sleep(for: delay)
            }

            return genres[type] ?? []
        }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchAndGenreDelayMetadataStub: MetadataProvider {
        private var searchResponses: [Int: MetadataSearchResult] = [:]
        private var searchDelays: [Int: Duration] = [:]
        private var genreResponse: [MediaType: [Genre]] = [:]
        private var genreDelays: [MediaType: Duration] = [:]
        private var searchCalls: [Int] = []
        private var genreCalls: [MediaType] = []

        func setSearchResponse(_ result: MetadataSearchResult, for page: Int, delay: Duration? = nil) {
            searchResponses[page] = result
            if let delay {
                searchDelays[page] = delay
            }
        }

        func setGenres(_ genres: [Genre], for type: MediaType = .movie, delay: Duration? = nil) {
            genreResponse[type] = genres
            if let delay {
                genreDelays[type] = delay
            }
        }

        func getSearchCalls() -> [Int] {
            searchCalls
        }

        func getGenreLoadCalls() -> [MediaType] {
            genreCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCalls.append(page)
            if let delay = searchDelays[page] {
                try await Task.sleep(for: delay)
            }
            return searchResponses[page] ?? MetadataSearchResult(
                items: [],
                page: page,
                totalPages: page,
                totalResults: 0
            )
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }
        func getGenres(type: MediaType) async throws -> [Genre] {
            genreCalls.append(type)
            if let delay = genreDelays[type] {
                try await Task.sleep(for: delay)
            }
            return genreResponse[type] ?? []
        }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchDiscoverDelayMetadataStub: MetadataProvider {
        private var searchCalls = 0
        private var discoverResponses: [Int: MetadataSearchResult] = [:]
        private var discoverDelays: [Int: Duration] = [:]
        private var discoverCalls: [Int] = []
        private var defaultSearchResponse = MetadataSearchResult(
            items: [],
            page: 1,
            totalPages: 1,
            totalResults: 0
        )

        func getSearchCalls() -> Int {
            searchCalls
        }

        func getDiscoverCalls() -> [Int] {
            discoverCalls
        }

        func setSearchResponse(_ result: MetadataSearchResult) {
            defaultSearchResponse = result
        }

        func setDiscoverResponse(_ result: MetadataSearchResult, for page: Int, delay: Duration? = nil) {
            discoverResponses[page] = result
            if let delay {
                discoverDelays[page] = delay
            }
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCalls += 1
            return defaultSearchResponse
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCalls.append(filters.page)
            if let delay = discoverDelays[filters.page] {
                try await Task.sleep(for: delay)
            }
            return discoverResponses[filters.page] ?? MetadataSearchResult(
                items: [],
                page: filters.page,
                totalPages: filters.page,
                totalResults: 0
            )
        }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchCallIndexedMetadataStub: MetadataProvider {
        private var callResponses: [Int: MetadataSearchResult] = [:]
        private var callDelays: [Int: Duration] = [:]
        private var searchCallCount = 0

        func setSearchResult(_ result: MetadataSearchResult, forCall call: Int, delay: Duration? = nil) {
            callResponses[call] = result
            if let delay {
                callDelays[call] = delay
            }
        }

        func getSearchCalls() -> Int {
            searchCallCount
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCallCount += 1
            let callNumber = searchCallCount

            if let delay = callDelays[callNumber] {
                try await Task.sleep(for: delay)
            }

            return callResponses[callNumber] ?? MetadataSearchResult(
                items: [],
                page: page,
                totalPages: 1,
                totalResults: 0
            )
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchFailureMetadataStub: MetadataProvider {
        struct Call: Hashable {
            let query: String
            let page: Int
        }

        private struct SearchFailure: Error {}

        private var responses: [String: [Int: MetadataSearchResult]] = [:]
        private var delays: [Call: Duration] = [:]
        private var failingCalls: Set<Call> = []
        private var searchCalls: [Call] = []
        private let defaultResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

        func setSearchResult(_ result: MetadataSearchResult, for query: String, page: Int) {
            responses[query, default: [:]][page] = result
        }

        func setSearchDelay(_ delay: Duration, for query: String, page: Int) {
            delays[Call(query: query, page: page)] = delay
        }

        func setSearchFailure(_ fail: Bool, for query: String, page: Int) {
            let call = Call(query: query, page: page)
            if fail {
                failingCalls.insert(call)
            } else {
                failingCalls.remove(call)
            }
        }

        func getSearchCalls() -> [Call] {
            searchCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCalls.append(Call(query: query, page: page))

            if let delay = delays[Call(query: query, page: page)] {
                try await Task.sleep(for: delay)
            }

            if failingCalls.contains(Call(query: query, page: page)) {
                throw SearchFailure()
            }

            return responses[query]?[page] ?? defaultResult
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor DiscoverTrackingMetadataStub: MetadataProvider {
        private var discoverCalls: Int = 0
        private var discoverFilters: [DiscoverFilters] = []

        func getDiscoverCallCount() -> Int {
            discoverCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCalls += 1
            discoverFilters.append(filters)
            return MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-\(filters.page)")],
                page: filters.page,
                totalPages: 1,
                totalResults: 1
            )
        }
    }

    private final class MetadataServiceFactorySpy: @unchecked Sendable {
        private(set) var createdKeys: [String] = []

        func callAsFunction(_ key: String) -> any MetadataProvider {
            createdKeys.append(key)
            return SearchRegressionMetadataStub()
        }
    }

    @MainActor
    private static func waitUntil(
        timeout: Duration = .milliseconds(2000),
        _ condition: @MainActor () -> Bool
    ) async throws {
        try await Self.waitUntil(timeout: timeout) { () async -> Bool in
            condition()
        }
    }

    @MainActor
    private static func waitUntil(
        timeout: Duration = .milliseconds(2000),
        _ condition: @MainActor () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !(await condition()) {
            guard ContinuousClock.now < deadline else {
                Issue.record("waitUntil timed out after \(timeout)")
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test
    @MainActor
    func configureTrimsApiKeyBeforeFactoryInvocation() {
        let factorySpy = MetadataServiceFactorySpy()
        let viewModel = SearchViewModel(metadataServiceFactory: factorySpy.callAsFunction)

        viewModel.configure(apiKey: "  spaced-api-key  ")

        #expect(factorySpy.createdKeys == ["spaced-api-key"])
    }

    @Test
    @MainActor
    func searchQueryTextArgCommitsTrimmedValueAndHitsService() async throws {
        let stub = SearchRegressionMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.search(queryText: "   matrix   ")

        try await Self.waitUntil { !viewModel.results.isEmpty }
        let calls = await stub.getSearchCalls()

        #expect(calls == ["matrix"])
        #expect(viewModel.query == "matrix")
        #expect(viewModel.queryDraft == "matrix")
        #expect(viewModel.submittedQuery == "matrix")
    }

    @Test
    @MainActor
    func searchQueryTextArgWithWhitespaceOnlyDoesNothingAndLeavesStateIntact() async throws {
        let stub = SearchRegressionMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "orig"
        viewModel.queryDraft = "orig"
        await stub.reset()

        viewModel.search(queryText: "   \t   ")
        await Task.yield()
        try await Task.sleep(for: .milliseconds(80))

        #expect(await stub.getSearchCalls().isEmpty)
        #expect(viewModel.query == "orig")
        #expect(viewModel.queryDraft == "orig")
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func configureWithWhitespaceOnInjectedServicePreservesStateAndCallCount() async throws {
        let trackingStub = SearchTrackingMetadataStub()
        let viewModel = SearchViewModel(metadataService: trackingStub)
        let initialGeneration = viewModel.searchGeneration

        viewModel.configure(apiKey: "   ")
        #expect(viewModel.searchGeneration == initialGeneration)

        viewModel.query = "no-op"
        viewModel.search()

        for _ in 0..<20 {
            if await trackingStub.getSearchCallCount() == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(await trackingStub.getSearchCallCount() == 1)
        #expect(viewModel.searchGeneration == initialGeneration + 1)
    }

    @Test
    @MainActor
    func configureWhitespaceResetsConfiguredServiceContextAndStopsServiceCalls() async throws {
        let service = SearchRegressionMetadataStub()
        let viewModel = SearchViewModel(metadataServiceFactory: { _ in
            service
        })

        viewModel.configure(apiKey: "abc-123")
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.selectMoodCard(ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!)
        viewModel.error = .network(.transport("stale"))
        viewModel.results = [Fixtures.mediaPreview(id: "stale")]
        viewModel.query = "Dune"

        viewModel.search()

        var calls = await service.getSearchCalls()
        for _ in 0..<40 {
            if calls.count == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
            calls = await service.getSearchCalls()
        }

        #expect(await service.getSearchCalls().count == 1)
        let generationAfterSearch = viewModel.searchGeneration

        viewModel.configure(apiKey: "   ")

        #expect(viewModel.searchGeneration == generationAfterSearch + 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.genres.isEmpty)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.totalPages == 1)

        viewModel.search()
        #expect(viewModel.searchGeneration == generationAfterSearch + 1)
        #expect(viewModel.error == .metadataSetupRequired(feature: "Search"))
        #expect(await service.getSearchCalls().count == 1)
    }

    @Test
    @MainActor
    func shouldTriggerPaginationRespectsGlobalPageCap() {
        let viewModel = SearchViewModel()
        viewModel.results = (0..<7).map { Fixtures.mediaPreview(id: "item-\($0)") }
        viewModel.currentPage = SearchViewModel.maxPageLimit
        viewModel.totalPages = SearchViewModel.maxPageLimit + 100

        #expect(viewModel.hasMore == false)
        #expect(viewModel.shouldTriggerPagination(for: "item-6") == false)
    }

    @Test
    @MainActor
    func configureWithSameNormalizedApiKeyIsNoop() {
        let factorySpy = MetadataServiceFactorySpy()
        let viewModel = SearchViewModel(metadataServiceFactory: factorySpy.callAsFunction)

        viewModel.configure(apiKey: "original-key")
        viewModel.configure(apiKey: "  original-key  ")

        #expect(factorySpy.createdKeys == ["original-key"])
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func configureWithDifferentApiKeyReplacesFactoryServiceAndBumpsSearchState() async {
        actor CountingMetadataStub: MetadataProvider {
            private var calls = 0

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                calls += 1
                return MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "counted-\(page)")],
                    page: page,
                    totalPages: page,
                    totalResults: 1
                )
            }
            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }

            func getCallCount() async -> Int { calls }
        }

        final class StubFactory: @unchecked Sendable {
            private var serviceA = CountingMetadataStub()
            private var serviceB = CountingMetadataStub()
            private(set) var calls: [String] = []

            func create(_ key: String) -> any MetadataProvider {
                calls.append(key)
                return key == "key-one" ? serviceA : serviceB
            }

            func firstServiceCalls() async -> Int {
                await serviceA.getCallCount()
            }

            func secondServiceCalls() async -> Int {
                await serviceB.getCallCount()
            }
        }

        let factory = StubFactory()
        let viewModel = SearchViewModel(metadataServiceFactory: { key in
            factory.create(key)
        })

        viewModel.configure(apiKey: "key-one")
        viewModel.query = "first"
        viewModel.search()
        #expect(viewModel.searchGeneration == 1)

        viewModel.configure(apiKey: "key-two")
        viewModel.query = "second"
        viewModel.search()
        #expect(viewModel.searchGeneration == 3)

        #expect(factory.calls == ["key-one", "key-two"])

        var attempts = 0
        while attempts < 100 {
            let firstServiceCalls = await factory.firstServiceCalls()
            let secondServiceCalls = await factory.secondServiceCalls()
            if firstServiceCalls == 1 && secondServiceCalls == 1 {
                break
            }
            attempts += 1
            try? await Task.sleep(for: .milliseconds(20))
        }

        #expect(await factory.firstServiceCalls() == 1)
        #expect(await factory.secondServiceCalls() == 1)
    }

    @Test
    @MainActor
    func searchWhitespaceQueryDoesNotMutateCommittedTextOrGeneration() async throws {
        let stub = SearchTrackingMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "interstellar"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.searchGeneration == 1)
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.submittedQuery == "interstellar")
        #expect(viewModel.query == "interstellar")
        #expect(viewModel.queryDraft == "interstellar")

        viewModel.search(queryText: "\n  \t")

        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.searchGeneration == 1)
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.submittedQuery == "interstellar")
        #expect(viewModel.query == "interstellar")
        #expect(viewModel.queryDraft == "interstellar")
    }

    @Test
    @MainActor
    func loadMoreSearchResultIsIgnoredIfQueryChangesBeforePage2Returns() async throws {
        let stub = SearchMetadataDelayStub()
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2,
            delay: .milliseconds(200)
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        viewModel.loadMore()
        viewModel.query = "beta"

        try await Task.sleep(for: .milliseconds(260))

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 2)
        #expect(calls.first?.query == "alpha")
        #expect(calls.first?.page == 1)
        #expect(calls.dropFirst().first?.query == "alpha")
        #expect(calls.dropFirst().first?.page == 2)

        #expect(viewModel.results.map(\.id) == ["alpha-page-1"])
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func staleSearchErrorDoesNotOverwriteSubsequentSearchResult() async throws {
        let stub = SearchFailureMetadataStub()
        await stub.setSearchDelay(.milliseconds(220), for: "alpha", page: 1)
        await stub.setSearchFailure(true, for: "alpha", page: 1)

        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "beta-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "beta",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.search(queryText: "alpha")
        try await Task.sleep(for: .milliseconds(20))

        viewModel.search(queryText: "beta")
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["beta-page-1"]
        }

        try await Task.sleep(for: .milliseconds(260))

        #expect(viewModel.results.map(\.id) == ["beta-page-1"])
        #expect(viewModel.error == nil)

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 2)
        #expect(calls[0].query == "alpha")
        #expect(calls[1].query == "beta")
    }

    @Test
    @MainActor
    func clearDoesNotTriggerGenreBrowseWhenResettingQueryDraft() async throws {
        let stub = DiscoverTrackingMetadataStub()
        let genre = Genre(id: 28, name: "Action")
        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(genre)

        var discoverCalls = await stub.getDiscoverCallCount()
        for _ in 0..<60 {
            if discoverCalls >= 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
            discoverCalls = await stub.getDiscoverCallCount()
        }

        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.clear()

        await Task.yield()
        try await Task.sleep(for: .milliseconds(80))

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.isEmpty)
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func clearAllFiltersCancelsStaleDebouncedSearch() async throws {
        let stub = SearchRegressionMetadataStub()
        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(120)
        )
        viewModel.queryDraft = "alpha"

        viewModel.debouncedSearch()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.clearAllFilters()
        #expect(viewModel.sortOption == .popularityDesc)

        var searchCalls = await stub.getSearchCalls().count
        for _ in 0..<60 {
            if searchCalls == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
            searchCalls = await stub.getSearchCalls().count
        }

        try await Task.sleep(for: .milliseconds(180))
        #expect((await stub.getSearchCalls()).count == 1)
        #expect(viewModel.query == "alpha")
        #expect(viewModel.queryDraft == "alpha")
        #expect(viewModel.results.map(\.id) == ["result-alpha-p1"])
    }

    @Test
    @MainActor
    func clearAllFiltersIncrementsSearchGenerationWhenRerunningInProgressSearch() async throws {
        let stub = SearchCallIndexedMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result-stale")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1,
            delay: .milliseconds(220)
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result-fresh")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2,
            delay: nil
        )

        let viewModel = SearchViewModel(metadataService: stub)
        let generationBefore = viewModel.searchGeneration
        #expect(generationBefore == 0)

        viewModel.query = "apollo"
        viewModel.search()
        #expect(viewModel.searchGeneration == 1)

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.clearAllFilters()

        #expect(viewModel.searchGeneration == 4)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query == "apollo")

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["search-result-fresh"]
        }

        #expect(await stub.getSearchCalls() == 2)
        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.map(\.id) == ["search-result-fresh"])
    }

    @Test
    @MainActor
    func clearAllFiltersResetsSearchFiltersBeforeTextSearchRequery() async throws {
        let stub = SearchFilterAwareMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.yearFilter = 2017
        viewModel.languageFilters = ["fr-FR"]
        viewModel.query = "apollo"

        viewModel.search()

        var initialCallCount = await stub.getSearchCalls().count
        for _ in 0..<60 {
            if initialCallCount == 1 { break }
            try await Task.sleep(for: .milliseconds(20))
            initialCallCount = await stub.getSearchCalls().count
        }

        let initialSearch = await stub.getSearchCalls().first
        #expect(initialCallCount == 1)
        #expect(initialSearch?.year == 2017)
        #expect(initialSearch?.language == "fr-FR")

        viewModel.clearAllFilters()

        var calls = await stub.getSearchCalls()
        for _ in 0..<80 {
            if calls.count == 2 { break }
            try await Task.sleep(for: .milliseconds(25))
            calls = await stub.getSearchCalls()
        }

        let secondSearch = calls.last
        #expect(calls.count == 2)
        #expect(secondSearch?.year == nil)
        #expect(secondSearch?.language == nil)
        #expect(viewModel.yearFilter == nil)
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.query == "apollo")
    }

    @Test
    @MainActor
    func clearAllFiltersResetsFiltersWhenGenreContextIsCleared() async throws {
        let stub = SearchFilterAwareMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)
        let genre = Genre(id: 28, name: "Action")

        viewModel.yearFilter = 2017
        viewModel.languageFilters = ["fr-FR"]
        viewModel.query = "neon"
        viewModel.selectGenre(genre)

        var discoverCalls = await stub.getDiscoverCalls()
        for _ in 0..<80 {
            if discoverCalls.count == 1 { break }
            try await Task.sleep(for: .milliseconds(25))
            discoverCalls = await stub.getDiscoverCalls()
        }
        #expect(discoverCalls.count == 1)
        #expect(discoverCalls[0].year == 2017)
        #expect(discoverCalls[0].language == "fr-FR")

        viewModel.clearAllFilters()

        var calls = await stub.getSearchCalls()
        for _ in 0..<80 {
            if calls.count == 1 { break }
            try await Task.sleep(for: .milliseconds(25))
            calls = await stub.getSearchCalls()
        }

        let searchCall = calls.first
        #expect(calls.count == 1)
        #expect(searchCall?.year == nil)
        #expect(searchCall?.language == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.query == "neon")
    }

    @Test
    @MainActor
    func clearAllFiltersResetsFiltersBeforeSpecialMoodCardSearchRerun() async throws {
        let stub = SearchFilterAwareMetadataStub()
        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.yearFilter = 2017
        viewModel.languageFilters = ["fr-FR"]
        viewModel.query = "space"
        viewModel.selectMoodCard(moodCard)

        viewModel.clearAllFilters()

        var calls = await stub.getSearchCalls()
        for _ in 0..<80 {
            if calls.count == 1 { break }
            try await Task.sleep(for: .milliseconds(25))
            calls = await stub.getSearchCalls()
        }

        let searchCall = calls.first
        #expect(calls.count == 1)
        #expect(searchCall?.year == nil)
        #expect(searchCall?.language == nil)
        #expect(viewModel.activeMoodCard?.id == moodCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.sortOption == .popularityDesc)
    }

    @Test
    @MainActor
    func clearAllFiltersResetsFiltersBeforeSpecialMoodDiscoverReplay() async throws {
        let stub = SearchFilterAwareMetadataStub()
        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.sortOption = .ratingDesc
        viewModel.yearFilter = 2020
        viewModel.languageFilters = ["fr-FR"]

        viewModel.selectMoodCard(moodCard)

        var discoverCalls = await stub.getDiscoverCalls()
        for _ in 0..<80 {
            if discoverCalls.count == 1 { break }
            try await Task.sleep(for: .milliseconds(25))
            discoverCalls = await stub.getDiscoverCalls()
        }
        #expect(discoverCalls.count == 1)
        #expect(discoverCalls[0].year == 2020)
        #expect(discoverCalls[0].language == "fr-FR")

        viewModel.clearAllFilters()

        discoverCalls = await stub.getDiscoverCalls()
        for _ in 0..<80 {
            if discoverCalls.count == 2 { break }
            try await Task.sleep(for: .milliseconds(25))
            discoverCalls = await stub.getDiscoverCalls()
        }

        let replayDiscover = discoverCalls.last
        #expect(discoverCalls.count == 2)
        #expect(replayDiscover?.year == nil)
        #expect(replayDiscover?.language == nil)
        #expect(viewModel.sortOption == .releaseDateDesc)
        #expect(replayDiscover?.sortBy == .releaseDateDesc)
    }

    @Test
    @MainActor
    func clearAllFiltersCancelsInFlightSearchLoadMoreAndKeepsFreshSearchContext() async throws {
        let stub = SearchMetadataDelayStub()
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-1")],
                page: 1,
                totalPages: 3,
                totalResults: 3
            ),
            for: 1
        )
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-2")],
                page: 2,
                totalPages: 3,
                totalResults: 3
            ),
            for: 2,
            delay: .milliseconds(220)
        )

        let viewModel = SearchViewModel(
            metadataService: stub,
            paginationCooldown: .milliseconds(0)
        )

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["search-page-1"]
        }

        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 3)

        viewModel.loadMore()
        #expect(viewModel.isLoadingMore == true)

        viewModel.clearAllFilters()
        try await Self.waitUntil {
            viewModel.isLoadingMore == false
        }

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)

        try await Self.waitUntil {
            let calls = await stub.getSearchCalls()
            return calls.count == 3 && viewModel.results.map(\.id) == ["search-page-1"]
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 3)
        #expect(calls.map { $0.page } == [1, 2, 1])
        #expect(viewModel.totalPages == 3)
    }

    @Test
    @MainActor
    func clearAllFiltersWithGenreContextCancelsInFlightLoadMoreAndPreservesSearchState() async throws {
        let stub = SearchMetadataDelayStub()
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-search-page-1")],
                page: 1,
                totalPages: 3,
                totalResults: 3
            ),
            for: 1
        )
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-search-page-2")],
                page: 2,
                totalPages: 3,
                totalResults: 3
            ),
            for: 2,
            delay: .milliseconds(220)
        )

        let viewModel = SearchViewModel(
            metadataService: stub,
            paginationCooldown: .milliseconds(0)
        )
        let genre = Genre(id: 28, name: "Action")

        viewModel.selectedGenre = genre
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-search-page-1"]
        }

        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 3)
        #expect(viewModel.searchGeneration == 2)

        viewModel.loadMore()
        #expect(viewModel.isLoadingMore == true)

        viewModel.clearAllFilters()
        try await Self.waitUntil {
            viewModel.isLoadingMore == false
        }

        #expect(viewModel.searchGeneration == 4)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.currentPage == 1)

        try await Self.waitUntil {
            let calls = await stub.getSearchCalls()
            return calls.count == 3 && viewModel.results.map(\.id) == ["genre-search-page-1"]
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 3)
        #expect(calls[0].query == "apollo")
        #expect(calls[1].query == "apollo")
        #expect(calls[2].query == "apollo")
        #expect(calls.map { $0.page } == [1, 2, 1])
    }

    @Test
    @MainActor
    func clearAllFiltersCancelsInFlightGenreLoadAndAllowsImmediateReload() async throws {
        let stub = SearchGenreLoadDelayMetadataStub()
        let genreList = [Genre(id: 28, name: "Action"), Genre(id: 35, name: "Comedy")]
        await stub.setGenres(genreList)
        await stub.setGenreLoadDelay(.milliseconds(220))

        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.loadGenres()
        try await Task.sleep(for: .milliseconds(40))

        var calls = await stub.getGenreLoadCalls()
        #expect(calls.count == 1)
        #expect(viewModel.genres.isEmpty)

        viewModel.clearAllFilters()
        viewModel.loadGenres()

        try await Self.waitUntil {
            await stub.getGenreLoadCalls().count == 2
        }

        try await Task.sleep(for: .milliseconds(280))
        calls = await stub.getGenreLoadCalls()
        #expect(calls.count == 2)
        #expect(viewModel.genres == genreList)
    }

    @Test
    @MainActor
    func clearCancelsInFlightSearchAndGenreLoad() async throws {
        let stub = SearchAndGenreDelayMetadataStub()
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1,
            delay: .milliseconds(260)
        )
        await stub.setGenres(
            [Genre(id: 28, name: "Action")],
            delay: .milliseconds(260)
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        let initialGeneration = viewModel.searchGeneration

        viewModel.search(queryText: "apollo")
        viewModel.loadGenres()
        try await Task.sleep(for: .milliseconds(40))

        #expect(viewModel.isSearching == true)
        #expect(await stub.getSearchCalls().count == 1)
        #expect(await stub.getGenreLoadCalls().count == 1)

        viewModel.clear()
        #expect(viewModel.searchGeneration == initialGeneration + 2)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.genres.isEmpty)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.isLoadingMore == false)

        try await Task.sleep(for: .milliseconds(300))
        #expect(await stub.getSearchCalls().count == 1)
        #expect(await stub.getGenreLoadCalls().count == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.genres.isEmpty)
    }

    @Test
    @MainActor
    func staleLoadMoreFailureDoesNotRestoreErrorAfterClear() async throws {
        let stub = SearchFailureMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 1
        )
        await stub.setSearchFailure(true, for: "alpha", page: 2)
        await stub.setSearchDelay(.milliseconds(220), for: "alpha", page: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.search(queryText: "alpha")

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["alpha-page-1"]
        }
        #expect(viewModel.error == nil)

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.clear()
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
        #expect(viewModel.query.isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.error == nil)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func clearCancelsInFlightSearchTaskAndPreventsLateResult() async throws {
        let stub = SearchMetadataDelayStub()
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1,
            delay: .milliseconds(220)
        )

        let viewModel = SearchViewModel(metadataService: stub)
        let generationBeforeClear = viewModel.searchGeneration

        viewModel.search(queryText: "alpha")
        #expect(viewModel.searchGeneration == generationBeforeClear + 1)
        #expect(viewModel.query == "alpha")
        #expect(viewModel.queryDraft == "alpha")
        #expect(viewModel.isSearching == true)

        try await Task.sleep(for: .milliseconds(40))
        viewModel.clear()

        #expect(viewModel.searchGeneration == generationBeforeClear + 2)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.isSearching == false)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCalls().count == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func clearDuringInFlightSearchErrorDoesNotLeakErrorState() async throws {
        let stub = SearchFailureMetadataStub()
        await stub.setSearchFailure(true, for: "beta", page: 1)
        await stub.setSearchDelay(.milliseconds(220), for: "beta", page: 1)

        let viewModel = SearchViewModel(metadataService: stub)
        let generationBeforeClear = viewModel.searchGeneration

        viewModel.search(queryText: "beta")

        try await Task.sleep(for: .milliseconds(40))
        viewModel.clear()

        #expect(viewModel.searchGeneration == generationBeforeClear + 2)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.error == nil)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCalls().count == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
        #expect(viewModel.hasAttemptedTextSearch == false)
    }

    @Test
    @MainActor
    func clearingQueryDraftWhileSpecialMoodCardIsActiveReloadsMoodDiscover() async throws {
        let stub = DiscoverTrackingMetadataStub()
        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "space"
        viewModel.selectMoodCard(moodCard)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        let discoverCallsBeforeClear = await stub.getDiscoverCallCount()
        #expect(discoverCallsBeforeClear == 1)
        #expect(viewModel.activeMoodCard?.id == "new")
        #expect(viewModel.selectedGenre == nil)

        viewModel.queryDraft = "   "

        var discoverCallsAfterClear = await stub.getDiscoverCallCount()
        for _ in 0..<60 {
            if discoverCallsAfterClear >= discoverCallsBeforeClear + 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
            discoverCallsAfterClear = await stub.getDiscoverCallCount()
        }

        #expect(discoverCallsAfterClear == discoverCallsBeforeClear + 1)
        #expect(viewModel.activeMoodCard?.id == "new")
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.sortOption == .releaseDateDesc)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
    }

    @Test
    @MainActor
    func failedSearchErrorAndAttemptedStateClearWhenQueryDraftIsEmptied() async throws {
        let stub = SearchFailureMetadataStub()
        await stub.setSearchFailure(true, for: "alpha", page: 1)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.queryDraft = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.submittedQuery == "alpha")
        #expect(viewModel.query == "alpha")
        #expect(viewModel.queryDraft == "alpha")

        viewModel.queryDraft = "   "

        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func searchLocallyFiltersByYearOnlyWhenMediaTypeIsUnspecified() async throws {
        let stub = SearchFailureMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "apollo-2024", year: 2024),
                    Fixtures.mediaPreview(id: "apollo-2023", year: 2023),
                    Fixtures.mediaPreview(id: "apollo-no-year", year: nil)
                ],
                page: 1,
                totalPages: 1,
                totalResults: 3
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = nil
        viewModel.yearFilter = 2024
        viewModel.search(queryText: "apollo")

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["apollo-2024"]
        }

        #expect(viewModel.results.map(\.id) == ["apollo-2024"])
        #expect(viewModel.results.first?.year == 2024)

        viewModel.selectedType = .movie
        viewModel.search(queryText: "apollo")

        try await Self.waitUntil {
            viewModel.results.map(\.id).count == 3
        }

        #expect(viewModel.results.map(\.id) == ["apollo-2024", "apollo-2023", "apollo-no-year"])
        #expect(await stub.getSearchCalls().count == 2)
    }

    @Test
    @MainActor
    func clearCancelsInFlightSpecialMoodLoadMoreAndKeepsEmptyState() async throws {
        let stub = SearchDiscoverDelayMetadataStub()
        await stub.setDiscoverResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2,
            delay: .milliseconds(240)
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        viewModel.selectMoodCard(moodCard)
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }

        let generationBeforeClear = viewModel.searchGeneration
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        #expect(await stub.getDiscoverCalls().count == 2)

        viewModel.clear()

        #expect(viewModel.searchGeneration == generationBeforeClear + 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.isLoadingMore == false)

        try await Task.sleep(for: .milliseconds(280))
        #expect(await stub.getDiscoverCalls().count == 2)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func loadMoreSearchLocallyFiltersByYearAcrossPagesWhenTypeIsUnspecified() async throws {
        let stub = SearchMetadataDelayStub()
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "apollo-page-1-year-2024", year: 2024),
                    Fixtures.mediaPreview(id: "apollo-page-1-year-2023", year: 2023),
                    Fixtures.mediaPreview(id: "apollo-page-1-no-year", year: nil)
                ],
                page: 1,
                totalPages: 2,
                totalResults: 3
            ),
            for: 1
        )
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "apollo-page-1-year-2024", year: 2024),
                    Fixtures.mediaPreview(id: "apollo-page-2-year-2024", year: 2024),
                    Fixtures.mediaPreview(id: "apollo-page-2-year-2023", year: 2023)
                ],
                page: 2,
                totalPages: 2,
                totalResults: 3
            ),
            for: 2,
            delay: .milliseconds(180)
        )

        let viewModel = SearchViewModel(
            metadataService: stub,
            paginationCooldown: .milliseconds(0)
        )

        viewModel.selectedType = nil
        viewModel.yearFilter = 2024
        viewModel.search(queryText: "apollo")

        try await Self.waitUntil {
            await stub.getSearchCalls().count == 1
        }

        #expect(viewModel.results.map(\.id) == ["apollo-page-1-year-2024"])

        viewModel.loadMore()
        try await Self.waitUntil {
            let calls = await stub.getSearchCalls()
            return calls.count == 2 && viewModel.currentPage == 2
        }

        #expect(viewModel.results.map(\.id) == ["apollo-page-1-year-2024", "apollo-page-2-year-2024"])
    }

    @Test
    @MainActor
    func explicitDebouncedSearchQueryDoesNotMutateStateAfterClear() async throws {
        let stub = SearchMetadataDelayStub()
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "dune-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1,
            delay: .milliseconds(260)
        )

        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(180)
        )
        let initialGeneration = viewModel.searchGeneration

        viewModel.debouncedSearch(queryText: "  dune  ")
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)

        try await Task.sleep(for: .milliseconds(60))
        viewModel.clear()

        #expect(viewModel.searchGeneration == initialGeneration + 1)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCalls().count == 0)
    }

    @Test
    @MainActor
    func clearingQueryDraftInGenreContextReloadsGenreBrowse() async throws {
        let stub = SearchFilterAwareMetadataStub()
        let genre = Genre(id: 28, name: "Action")
        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(genre)

        var discoverCalls = await stub.getDiscoverCalls()
        for _ in 0..<80 {
            if discoverCalls.count == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
            discoverCalls = await stub.getDiscoverCalls()
        }
        #expect(discoverCalls.count == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == genre)

        viewModel.queryDraft = "   "

        discoverCalls = await stub.getDiscoverCalls()
        for _ in 0..<80 {
            if discoverCalls.count > 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
            discoverCalls = await stub.getDiscoverCalls()
        }

        #expect(viewModel.selectedGenre == genre)
        #expect(discoverCalls.count == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.queryDraft == "   ")
    }

    @Test
    @MainActor
    func selectedTypeChangeAfterYearFilteredSearchAffectsLoadMoreFiltering() async throws {
        let stub = SearchMetadataDelayStub()
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "orion-page-1-year-2024", year: 2024),
                    Fixtures.mediaPreview(id: "orion-page-1-year-2023", year: 2023)
                ],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "orion-page-2-year-2023", year: 2023)
                ],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedType = nil
        viewModel.yearFilter = 2024
        viewModel.search(queryText: "orion")

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["orion-page-1-year-2024"]
        }

        #expect(await stub.getSearchCalls().count == 1)
        #expect(viewModel.results.map(\.id) == ["orion-page-1-year-2024"])

        viewModel.selectedType = .movie
        viewModel.loadMore()

        try await Self.waitUntil {
            let calls = await stub.getSearchCalls()
            return calls.count == 2 && viewModel.currentPage == 2
        }

        #expect(viewModel.results.map(\.id) == ["orion-page-1-year-2024", "orion-page-2-year-2023"])
    }

    @Test
    @MainActor
    func loadMoreSearchDeduplicatesOverlappingItemsById() async throws {
        let stub = SearchMetadataDelayStub()
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "omega-page-1-a"),
                    Fixtures.mediaPreview(id: "omega-page-1-b")
                ],
                page: 1,
                totalPages: 2,
                totalResults: 3
            ),
            for: 1
        )
        await stub.setSearchResponse(
            MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "omega-page-1-b"),
                    Fixtures.mediaPreview(id: "omega-page-2-c")
                ],
                page: 2,
                totalPages: 2,
                totalResults: 3
            ),
            for: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.search(queryText: "omega")

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["omega-page-1-a", "omega-page-1-b"]
        }

        viewModel.loadMore()

        try await Self.waitUntil {
            let calls = await stub.getSearchCalls()
            return calls.count == 2 && viewModel.currentPage == 2
        }

        #expect(viewModel.results.map(\.id) == ["omega-page-1-a", "omega-page-1-b", "omega-page-2-c"])
    }

    @Test
    @MainActor
    func clearAllFiltersInGenreContextWithEmptyQueryReturnsEmptyResults() async throws {
        let stub = SearchFilterAwareMetadataStub()
        let genre = Genre(id: 35, name: "Comedy")
        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.yearFilter = 2021
        viewModel.languageFilters = ["fr-FR"]
        viewModel.selectGenre(genre)

        var discoverCalls = await stub.getDiscoverCalls()
        for _ in 0..<80 {
            if discoverCalls.count == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
            discoverCalls = await stub.getDiscoverCalls()
        }
        #expect(discoverCalls.count == 1)

        viewModel.queryDraft = "   "

        try await Task.sleep(for: .milliseconds(80))
        discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.count == 1)

        viewModel.clearAllFilters()

        try await Task.sleep(for: .milliseconds(80))
        discoverCalls = await stub.getDiscoverCalls()

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.yearFilter == nil)
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(discoverCalls.count == 1)
    }
}
