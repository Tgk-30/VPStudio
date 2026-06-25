import Foundation
import SwiftUI
import Testing
@testable import VPStudio

@Suite(.serialized)
struct SearchViewModelFilterTests {

    // MARK: - Test Stubs

    /// A configurable metadata stub that supports search, discover, and genre loading.
    private actor FilterTestMetadataStub: MetadataProvider {
        var searchResultByPage: [Int: MetadataSearchResult] = [:]
        var discoverResultByPage: [Int: MetadataSearchResult] = [:]
        var genresByType: [MediaType: [Genre]] = [:]
        var searchCallCount = 0
        var discoverCallCount = 0
        var genreCallCount = 0
        var lastDiscoverFilters: DiscoverFilters?
        var lastDiscoverType: MediaType?
        var shouldThrowOnGenres = false

        func setShouldThrowOnGenres(_ value: Bool) {
            shouldThrowOnGenres = value
        }

        func setSearchResults(_ results: [Int: MetadataSearchResult]) {
            searchResultByPage = results
        }

        func setDiscoverResults(_ results: [Int: MetadataSearchResult]) {
            discoverResultByPage = results
        }

        func setGenres(_ genres: [Genre], for type: MediaType) {
            genresByType[type] = genres
        }

        func getSearchCallCount() -> Int { searchCallCount }
        func getDiscoverCallCount() -> Int { discoverCallCount }
        func getGenreCallCount() -> Int { genreCallCount }
        func getLastDiscoverFilters() -> DiscoverFilters? { lastDiscoverFilters }
        func getLastDiscoverType() -> MediaType? { lastDiscoverType }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCallCount += 1
            return searchResultByPage[page] ?? MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            lastDiscoverFilters = filters
            lastDiscoverType = type
            return discoverResultByPage[filters.page] ?? MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            genreCallCount += 1
            if shouldThrowOnGenres { throw TestError.genreLoadFailed }
            return genresByType[type] ?? []
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    private actor BlockingDiscoverMetadataStub: MetadataProvider {
        private(set) var discoverResultByPage: [Int: MetadataSearchResult] = [:]
        private(set) var discoverCallCount = 0
        private let discoverDelay: Duration

        init(
            discoverDelay: Duration = .milliseconds(100),
            discoverResultByPage: [Int: MetadataSearchResult] = [:]
        ) {
            self.discoverDelay = discoverDelay
            self.discoverResultByPage = discoverResultByPage
        }

        func setDiscoverResults(_ results: [Int: MetadataSearchResult]) {
            discoverResultByPage = results
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            try await Task.sleep(for: discoverDelay)
            return discoverResultByPage[filters.page] ?? MetadataSearchResult(
                items: [],
                page: filters.page,
                totalPages: filters.page,
                totalResults: 0
            )
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            []
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    private actor DiscoverLoadMoreDelayMetadataStub: MetadataProvider {
        private var discoverResultByPage: [Int: MetadataSearchResult] = [:]
        private var discoverCallCount = 0
        private var discoverDelayByPage: [Int: Duration] = [:]

        func setDiscoverResults(_ results: [Int: MetadataSearchResult]) {
            discoverResultByPage = results
        }

        func setDelay(_ delay: Duration, for page: Int) {
            discoverDelayByPage[page] = delay
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            return MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            if let delay = discoverDelayByPage[filters.page] {
                try await Task.sleep(for: delay)
            }

            return discoverResultByPage[filters.page] ?? MetadataSearchResult(
                items: [],
                page: filters.page,
                totalPages: filters.page,
                totalResults: 0
            )
        }

        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    private enum TestError: Error, LocalizedError {
        case genreLoadFailed
        case aiFailure

        var errorDescription: String? {
            switch self {
            case .genreLoadFailed: return "Genre load failed"
            case .aiFailure: return "AI failure"
            }
        }
    }

    private static func ratedPreview(
        id: String,
        title: String,
        year: Int?,
        rating: Double?
    ) -> MediaPreview {
        MediaPreview(
            id: id,
            type: .movie,
            title: title,
            year: year,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: rating,
            tmdbId: nil
        )
    }

    /// Polls until `condition` returns true, yielding between checks. Fails after `timeout`.
    @MainActor
    private static func waitUntil(
        timeout: Duration = .milliseconds(5000),
        _ condition: @MainActor () -> Bool
    ) async throws {
        try await waitUntil(timeout: timeout) { @MainActor () async -> Bool in
            condition()
        }
    }

    @MainActor
    private static func waitUntil(
        timeout: Duration = .milliseconds(5000),
        _ condition: @MainActor () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !(await condition()) {
            guard ContinuousClock.now < deadline else {
                Issue.record("waitUntil timed out after \(timeout)")
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    // MARK: - Genre Loading & Caching

    @Test
    @MainActor
    func loadGenresPopulatesGenreList() async throws {
        let stub = FilterTestMetadataStub()
        let genres = [Genre(id: 28, name: "Action"), Genre(id: 35, name: "Comedy"), Genre(id: 18, name: "Drama")]
        await stub.setGenres(genres, for: .movie)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.loadGenres()

        try await Self.waitUntil { !viewModel.genres.isEmpty }
        #expect(viewModel.genres.count == 3)
        #expect(viewModel.genres.map(\.name) == ["Action", "Comedy", "Drama"])
    }

    @Test
    @MainActor
    func loadGenresCachesResultsAndDoesNotRefetch() async throws {
        let stub = FilterTestMetadataStub()
        let genres = [Genre(id: 28, name: "Action")]
        await stub.setGenres(genres, for: .movie)

        let viewModel = SearchViewModel(metadataService: stub)

        // First load
        viewModel.loadGenres()
        try await Self.waitUntil { !viewModel.genres.isEmpty }
        let firstCallCount = await stub.getGenreCallCount()
        #expect(firstCallCount == 1)

        // Second load should use cache
        viewModel.loadGenres()
        // Give it time to potentially make another call
        await Task.yield()
        try await Task.sleep(for: .milliseconds(100))
        let secondCallCount = await stub.getGenreCallCount()
        #expect(secondCallCount == 1)
        #expect(viewModel.genres.count == 1)
    }

    @Test
    @MainActor
    func loadGenresForDifferentTypeFetchesAgain() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 10765, name: "Sci-Fi & Fantasy")], for: .series)

        let viewModel = SearchViewModel(metadataService: stub)

        // Load for movies (default)
        viewModel.selectedType = .movie
        viewModel.loadGenres()
        try await Self.waitUntil { !viewModel.genres.isEmpty }
        #expect(viewModel.genres.first?.name == "Action")

        // Switch to TV
        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil { viewModel.genres.first?.name == "Sci-Fi & Fantasy" }
        #expect(viewModel.genres.count == 1)
        #expect(viewModel.genres.first?.name == "Sci-Fi & Fantasy")

        let callCount = await stub.getGenreCallCount()
        #expect(callCount == 2)
    }

    @Test
    @MainActor
    func selectGenreNilCancelsInFlightGenreBrowseResults() async throws {
        let stub = BlockingDiscoverMetadataStub(
            discoverDelay: .milliseconds(150),
            discoverResultByPage: [
                1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "discover-stale")], page: 1, totalPages: 1, totalResults: 1)
            ]
        )

        let genre = Genre(id: 28, name: "Action")
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectGenre(genre)
        let discoverCallStartDeadline = ContinuousClock.now + .milliseconds(500)
        while await stub.getDiscoverCallCount() < 1 && ContinuousClock.now < discoverCallStartDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await stub.getDiscoverCallCount() == 1)

        try await Task.sleep(for: .milliseconds(20))
        viewModel.selectGenre(nil)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
    }

    @Test
    @MainActor
    func selectGenreNilResetsSearchStateWhenCancellingBrowse() async throws {
        let stub = BlockingDiscoverMetadataStub(
            discoverDelay: .milliseconds(150),
            discoverResultByPage: [
                1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "discover-stale")], page: 1, totalPages: 1, totalResults: 1)
            ]
        )

        let genre = Genre(id: 28, name: "Action")
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectGenre(genre)
        for _ in 0..<20 {
            if viewModel.isSearching {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(viewModel.isSearching == true)

        viewModel.selectGenre(nil)

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.results.isEmpty)

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeCancelsInFlightGenreBrowseWithoutRemapFallback() async throws {
        let stub = BlockingDiscoverMetadataStub(
            discoverDelay: .milliseconds(150),
            discoverResultByPage: [
                1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "discover-stale")], page: 1, totalPages: 1, totalResults: 1)
            ]
        )
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "discover-stale")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let genre = Genre(id: 28, name: "Action")
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectGenre(genre)
        let discoverCallStartDeadline = ContinuousClock.now + .milliseconds(500)
        while await stub.getDiscoverCallCount() < 1 && ContinuousClock.now < discoverCallStartDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await stub.getDiscoverCallCount() == 1)

        try await Task.sleep(for: .milliseconds(20))
        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.results.isEmpty)

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
    }

    @Test
    @MainActor
    func loadGenresWithEmptyResultKeepsEmptyList() async throws {
        let stub = FilterTestMetadataStub()
        // No genres set — will return empty

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.loadGenres()

        await Task.yield()
        try await Task.sleep(for: .milliseconds(150))
        #expect(viewModel.genres.isEmpty)
    }

    @Test
    @MainActor
    func loadGenresFailureSilentlyHandled() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setShouldThrowOnGenres(true)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.loadGenres()

        await Task.yield()
        try await Task.sleep(for: .milliseconds(150))
        #expect(viewModel.genres.isEmpty)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersClearsStaleBrowseErrorState() {
        let viewModel = SearchViewModel()
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.error = .unknown("Genre browse failed")

        viewModel.clearAllFilters()

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.error == nil)
        #expect(viewModel.explorePhase == .idle)
    }

    @Test
    @MainActor
    func selectGenreNilClearsRegularMoodCardContext() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "select-genre-nil-action")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let card = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!

        viewModel.selectMoodCard(card)
        try await Self.waitUntil {
            viewModel.selectedGenre?.id == 28 && !viewModel.results.isEmpty
        }

        viewModel.selectGenre(nil)

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
    }

    @Test
    @MainActor
    func clearAllFiltersResetsRegularMoodCardContext() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "clear-all-filters-action")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let card = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!

        viewModel.selectMoodCard(card)
        try await Self.waitUntil {
            viewModel.selectedGenre?.id == 28 && !viewModel.results.isEmpty
        }

        viewModel.sortOption = .ratingDesc
        viewModel.languageFilters = ["ja-JP"]
        viewModel.yearFilter = 2024

        viewModel.clearAllFilters()

        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.yearFilter == nil)
        #expect(viewModel.yearRangePreset == nil)
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersRequeriesSearchWhenGenreIsClearedAndQueryExists() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let genre = Genre(id: 28, name: "Action")
        viewModel.sortOption = .ratingDesc
        viewModel.query = "Dune"

        viewModel.selectGenre(genre)
        try await Self.waitUntil { viewModel.results.first?.id == "genre-result" }

        viewModel.clearAllFilters()

        try await Self.waitUntil { viewModel.results.first?.id == "search-result" }
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.results.map(\.id) == ["search-result"])
    }

    @Test
    @MainActor
    func clearAllFiltersRequeriesSearchWhenSpecialMoodContextHasActiveQuery() async throws {
        let stub = FilterTestMetadataStub()
        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil { viewModel.results.first?.id == "mood-result" }
        #expect(viewModel.activeMoodCard?.id == "new")

        viewModel.query = "dune"
        viewModel.search()
        try await Self.waitUntil { viewModel.results.first?.id == "search-result" }

        let discoverCallsBefore = await stub.getDiscoverCallCount()
        let searchCallsBefore = await stub.getSearchCallCount()

        viewModel.sortOption = .ratingDesc
        viewModel.clearAllFilters()

        try await Self.waitUntil { viewModel.results.first?.id == "search-result" }

        #expect(viewModel.activeMoodCard?.id == "new")
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(await stub.getDiscoverCallCount() == discoverCallsBefore)
        #expect(await stub.getSearchCallCount() == searchCallsBefore + 1)
    }

    @Test
    @MainActor
    func clearAllFiltersPreservesSpecialMoodContextWhenNoQuery() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        viewModel.sortOption = .ratingDesc
        viewModel.yearFilter = 2024
        viewModel.languageFilters = ["fr-FR"]
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil { viewModel.results.first?.id == "mood-result" }
        #expect(viewModel.activeMoodCard?.id == "new")

        viewModel.clearAllFilters()

        try await Self.waitUntil { viewModel.results.first?.id == "mood-result" }
        #expect(viewModel.activeMoodCard?.id == "new")
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.sortOption == .releaseDateDesc)
    }

    @Test
    @MainActor
    func clearAllFiltersRequeriesTextSearchWhenNoGenreAndQueryPresent() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "Dune"
        viewModel.sortOption = .ratingDesc

        let initialSearchCount = await stub.getSearchCallCount()
        #expect(initialSearchCount == 0)

        viewModel.clearAllFilters()

        try await Self.waitUntil { await stub.getSearchCallCount() == 1 }
        #expect(viewModel.results.first?.id == "search-1")
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.languageFilters == ["en-US"])
    }

    // MARK: - Genre Selection → Discover

    @Test
    @MainActor
    func selectGenreTriggersDiscoverInsteadOfSearch() async throws {
        let stub = FilterTestMetadataStub()
        let genre = Genre(id: 28, name: "Action")
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "discover-1", title: "Action Movie")],
                page: 1, totalPages: 1, totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(genre)

        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(viewModel.results.count == 1)
        #expect(viewModel.results.first?.id == "discover-1")
        #expect(viewModel.selectedGenre?.id == 28)

        let discoverCount = await stub.getDiscoverCallCount()
        let searchCount = await stub.getSearchCallCount()
        #expect(discoverCount == 1)
        #expect(searchCount == 0)
    }

    @Test
    @MainActor
    func selectGenrePassesCorrectFilters() async throws {
        let stub = FilterTestMetadataStub()
        let genre = Genre(id: 35, name: "Comedy")
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "comedy-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .series
        viewModel.sortOption = .ratingDesc
        viewModel.yearFilter = 2024
        viewModel.selectGenre(genre)

        try await Self.waitUntil { !viewModel.results.isEmpty }

        let lastFilters = await stub.getLastDiscoverFilters()
        let lastType = await stub.getLastDiscoverType()
        #expect(lastFilters?.genreId == 35)
        #expect(lastFilters?.sortBy == .ratingDesc)
        #expect(lastFilters?.year == 2024)
        #expect(lastType == .series)
    }

    @Test
    @MainActor
    func deselectGenreWithTextQueryReTriggersSearch() async throws {
        let stub = FilterTestMetadataStub()
        let genre = Genre(id: 28, name: "Action")
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "discover-1")], page: 1, totalPages: 1, totalResults: 1)
        ])
        await stub.setSearchResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "search-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "test query"

        // Select genre first
        viewModel.selectGenre(genre)
        try await Self.waitUntil { viewModel.results.first?.id == "discover-1" }

        // Deselect genre — should fall back to text search
        viewModel.selectGenre(nil)
        try await Self.waitUntil { viewModel.results.first?.id == "search-1" }

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.first?.id == "search-1")
    }

    @Test
    @MainActor
    func deselectGenreWithoutQueryClearsResults() async throws {
        let stub = FilterTestMetadataStub()
        let genre = Genre(id: 28, name: "Action")
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "discover-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(genre)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        viewModel.selectGenre(nil)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
    }

    @Test
    @MainActor
    func genreBrowsePaginationUsesDiscover() async throws {
        let stub = FilterTestMetadataStub()
        let genre = Genre(id: 28, name: "Action")
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "disc-p1")], page: 1, totalPages: 2, totalResults: 2),
            2: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "disc-p2")], page: 2, totalPages: 2, totalResults: 2),
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(genre)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        viewModel.loadMore()
        try await Self.waitUntil { viewModel.results.count >= 2 }

        #expect(viewModel.results.count == 2)
        #expect(viewModel.results.map(\.id) == ["disc-p1", "disc-p2"])
        #expect(viewModel.currentPage == 2)

        // All calls should be discover, not search
        let searchCount = await stub.getSearchCallCount()
        #expect(searchCount == 0)
    }

    @Test
    @MainActor
    func genreBrowsePaginationDeduplicatesOverlappingPageResults() async throws {
        let stub = FilterTestMetadataStub()
        let genre = Genre(id: 28, name: "Action")
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "disc-page1-a"),
                    Fixtures.mediaPreview(id: "disc-page1-b"),
                ],
                page: 1,
                totalPages: 2,
                totalResults: 3
            ),
            2: MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "disc-page1-b"),
                    Fixtures.mediaPreview(id: "disc-page2-c"),
                ],
                page: 2,
                totalPages: 2,
                totalResults: 3
            ),
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(genre)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        #expect(viewModel.results.map(\.id) == ["disc-page1-a", "disc-page1-b"])

        viewModel.loadMore()
        try await Self.waitUntil { viewModel.currentPage == 2 }

        #expect(viewModel.results.map(\.id) == ["disc-page1-a", "disc-page1-b", "disc-page2-c"])
        #expect(await stub.getDiscoverCallCount() == 2)
    }

    @Test
    @MainActor
    func genreBrowseLoadMoreResultIgnoredAfterGenreCleared() async throws {
        let stub = DiscoverLoadMoreDelayMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "disc-page1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            2: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "disc-page2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            )
        ])
        await stub.setDelay(.milliseconds(180), for: 2)

        let genre = Genre(id: 28, name: "Action")
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectGenre(genre)
        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(viewModel.currentPage == 1)

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))
        viewModel.selectGenre(nil)

        try await Task.sleep(for: .milliseconds(230))

        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.isEmpty)
        #expect(await stub.getDiscoverCallCount() == 2)
    }

    @Test
    @MainActor
    func loadMoreFallsBackToSearchWhenSpecialMoodQueryIsActive() async throws {
        let stub = FilterTestMetadataStub()
        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            2: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            )
        ])
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            2: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(moodCard)
        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.query = "dune"
        viewModel.search()
        try await Self.waitUntil { viewModel.results.first?.id == "search-page-1" }

        let discoverCallsBeforeLoadMore = await stub.getDiscoverCallCount()
        let searchCallsBeforeLoadMore = await stub.getSearchCallCount()
        #expect(searchCallsBeforeLoadMore == 1)

        viewModel.loadMore()

        var attempts = 0
        while await stub.getSearchCallCount() < 2 && attempts < 20 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(await stub.getSearchCallCount() == 2)
        #expect(await stub.getDiscoverCallCount() == discoverCallsBeforeLoadMore)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["search-page-1", "search-page-2"])
    }

    @Test
    @MainActor
    func loadMoreUsesDiscoverForSpecialMoodContextWhenNoQueryIsActive() async throws {
        let stub = FilterTestMetadataStub()
        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            2: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(moodCard)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        #expect(viewModel.queryDraft.isEmpty)
        #expect(await stub.getSearchCallCount() == 0)
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.loadMore()
        try await Self.waitUntil { viewModel.currentPage == 2 }

        #expect(viewModel.results.map(\.id) == ["mood-page-1", "mood-page-2"])
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeKeepsSearchModeForSpecialMoodQueryContext() async throws {
        let stub = FilterTestMetadataStub()
        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(moodCard)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let discoverCallsAfterMoodBrowse = await stub.getDiscoverCallCount()
        let searchCallsBeforeTypeChange = await stub.getSearchCallCount()

        viewModel.query = "dune"
        viewModel.search()
        try await Self.waitUntil { viewModel.results.first?.id == "search-page-1" }

        let discoverCallsAfterSearch = await stub.getDiscoverCallCount()
        let searchCallsAfterSearch = await stub.getSearchCallCount()
        #expect(discoverCallsAfterSearch == discoverCallsAfterMoodBrowse)
        #expect(searchCallsAfterSearch == searchCallsBeforeTypeChange + 1)
        #expect(viewModel.activeMoodCard?.id == moodCard.id)

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        var attempts = 0
        while await stub.getSearchCallCount() < searchCallsAfterSearch + 1 && attempts < 20 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(await stub.getSearchCallCount() == searchCallsAfterSearch + 1)
        #expect(await stub.getDiscoverCallCount() == discoverCallsAfterSearch)
        #expect(viewModel.selectedType == .series)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeKeepsSpecialMoodWhenNoQueryAndGenresCached() async throws {
        let stub = FilterTestMetadataStub()
        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Animation")], for: .series)
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil { !viewModel.genres.isEmpty }

        viewModel.selectedType = .movie
        viewModel.selectMoodCard(moodCard)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let discoverCallsAfterInitialMood = await stub.getDiscoverCallCount()
        #expect(discoverCallsAfterInitialMood == 1)

        viewModel.selectedType = .series
        viewModel.loadGenres()

        viewModel.handleSelectedTypeChange()

        var attempts = 0
        while await stub.getDiscoverCallCount() < discoverCallsAfterInitialMood + 1 && attempts < 20 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(await stub.getDiscoverCallCount() == discoverCallsAfterInitialMood + 1)
        #expect(viewModel.activeMoodCard?.id == moodCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(!viewModel.results.isEmpty)
        #expect(viewModel.selectedType == .series)
    }

    @Test
    @MainActor
    func requeryFallsBackToSearchWhenSpecialMoodHasQuery() async throws {
        let stub = FilterTestMetadataStub()
        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(moodCard)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        viewModel.query = "dune"
        viewModel.search()
        try await Self.waitUntil { viewModel.results.first?.id == "search-page-1" }

        let discoverCallsBeforeFilter = await stub.getDiscoverCallCount()
        let searchCallsBeforeFilter = await stub.getSearchCallCount()

        viewModel.applySortOption(.ratingDesc)

        var attempts = 0
        while await stub.getSearchCallCount() < searchCallsBeforeFilter + 1 && attempts < 20 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(await stub.getSearchCallCount() == searchCallsBeforeFilter + 1)
        #expect(await stub.getDiscoverCallCount() == discoverCallsBeforeFilter)
        #expect(viewModel.sortOption == .ratingDesc)
        #expect(viewModel.results.first?.id == "search-page-1")
    }

    // MARK: - Sort Option

    @Test
    @MainActor
    func applyFilterDraftIsNoopWhenNoStateChange() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "inception"
        viewModel.search()
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let initialSearchCount = await stub.getSearchCallCount()
        #expect(initialSearchCount == 1)

        let draft = SearchFilterDraft(
            sortOption: .popularityDesc,
            selectedYear: nil,
            selectedLanguages: ["en-US"],
            selectedGenre: nil
        )

        viewModel.applyFilterDraft(draft)
        try await Self.waitUntil { await stub.getSearchCallCount() == initialSearchCount }

        #expect(await stub.getSearchCallCount() == initialSearchCount)
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.yearFilter == nil)
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(viewModel.selectedGenre == nil)
    }

    @Test
    @MainActor
    func applyFilterDraftSwitchesFromSpecialMoodToGenreBrowse() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "browse-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let actionCard = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!

        viewModel.selectMoodCard(actionCard)
        try await Self.waitUntil {
            let discoverCallCount = await stub.getDiscoverCallCount()
            return viewModel.activeMoodCard?.id == "action"
                && viewModel.selectedGenre?.id == 28
                && discoverCallCount == 1
        }

        let discoverCallsBefore = await stub.getDiscoverCallCount()
        #expect(discoverCallsBefore == 1)

        let draft = SearchFilterDraft(
            sortOption: .releaseDateDesc,
            selectedYear: nil,
            selectedLanguages: ["en-US"],
            selectedGenre: Genre(id: 35, name: "Comedy")
        )
        viewModel.applyFilterDraft(draft)

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() >= 2
        }

        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre?.id == 35)
        #expect(viewModel.sortOption == .releaseDateDesc)
    }

    @Test
    @MainActor
    func applySortOptionRequeriesGenreBrowse() async throws {
        let stub = FilterTestMetadataStub()
        let genre = Genre(id: 28, name: "Action")
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "sorted-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(genre)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let firstDiscoverCount = await stub.getDiscoverCallCount()
        #expect(firstDiscoverCount == 1)

        // Change sort — should requery. Wait for isSearching to transition (true then false again).
        viewModel.applySortOption(.ratingDesc)
        // The requery will set isSearching=true then false. Wait for it to settle.
        try await Self.waitUntil { !viewModel.isSearching && viewModel.sortOption == .ratingDesc }

        let secondDiscoverCount = await stub.getDiscoverCallCount()
        #expect(secondDiscoverCount >= 2)
        let lastFilters = await stub.getLastDiscoverFilters()
        #expect(lastFilters?.sortBy == .ratingDesc)
        #expect(viewModel.sortOption == .ratingDesc)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeClearsInvalidMoodContextWhenGenreCannotBeRemapped() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Animation")], for: .series)
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "browse-page")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let actionCard = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!

        viewModel.selectMoodCard(actionCard)
        try await Self.waitUntil { viewModel.activeMoodCard?.id == "action" }

        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil { !viewModel.genres.isEmpty }
        viewModel.handleSelectedTypeChange()

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeClearsUnmatchedGenreWhenNoQuery() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Animation")], for: .series)
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "browse-legacy")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)

        let staleGenre = Genre(id: 999, name: "Unmapped")
        viewModel.selectGenre(staleGenre)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let discoverCallsBeforeTypeChange = await stub.getDiscoverCallCount()
        #expect(discoverCallsBeforeTypeChange == 1)

        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil { !viewModel.genres.isEmpty }

        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            viewModel.selectedGenre == nil
                && viewModel.activeMoodCard == nil
                && viewModel.results.isEmpty
        }

        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(await stub.getDiscoverCallCount() == discoverCallsBeforeTypeChange)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeRemapsGenreByName() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Action")], for: .series)
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "m-genre-series")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectedType = .movie
        viewModel.selectGenre(Genre(id: 999, name: "Action"))
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let discoverCallsAfterStaleGenre = await stub.getDiscoverCallCount()
        #expect(discoverCallsAfterStaleGenre == 1)
        #expect(viewModel.selectedGenre?.id == 999)

        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil { !viewModel.genres.isEmpty }

        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            let discoverCallCount = await stub.getDiscoverCallCount()
            return discoverCallCount == discoverCallsAfterStaleGenre + 1
                && viewModel.selectedGenre?.id == 16
        }

        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre?.id == 16)
        #expect(viewModel.selectedGenre?.name == "Action")
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFallsBackToSearchForStaleSelectedGenreWhenActiveQueryExists() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Drama")], for: .series)
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "browse-stale")], page: 1, totalPages: 1, totalResults: 1)
        ])
        await stub.setSearchResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "search-fallback")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "dune"

        viewModel.selectGenre(Genre(id: 999, name: "Action"))
        try await Self.waitUntil { !viewModel.results.isEmpty }

        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil { !viewModel.genres.isEmpty }

        let discoverCallsBeforeTypeChange = await stub.getDiscoverCallCount()
        let searchCallsBeforeTypeChange = await stub.getSearchCallCount()

        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            await stub.getSearchCallCount() == searchCallsBeforeTypeChange + 1
        }

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(await stub.getSearchCallCount() == searchCallsBeforeTypeChange + 1)
        #expect(await stub.getDiscoverCallCount() == discoverCallsBeforeTypeChange)
        #expect(viewModel.results.first?.id == "search-fallback")
    }

    @Test
    @MainActor
    func selectMoodCardSpecialUsesExpectedNewReleasesDateWindow() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-release")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let filters = await stub.getLastDiscoverFilters()
        #expect(filters?.sortBy == .releaseDateDesc)
        #expect(filters?.releaseDateGte == DiscoverFilters.dateString(daysFromNow: -90))
        #expect(filters?.releaseDateLte == DiscoverFilters.todayString())
    }

    @Test
    @MainActor
    func selectMoodCardSpecialUsesExpectedUpcomingDateWindow() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "upcoming-release")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let upcomingCard = ExploreGenreCatalog.cards.first(where: { $0.id == "upcoming" })!

        viewModel.selectMoodCard(upcomingCard)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let filters = await stub.getLastDiscoverFilters()
        #expect(filters?.sortBy == .popularityDesc)
        #expect(filters?.releaseDateGte == DiscoverFilters.dateString(daysFromNow: 1))
        #expect(filters?.releaseDateLte == DiscoverFilters.dateString(daysFromNow: 365))
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFallsBackToSearchForRegularMoodWithActiveQueryWhenRemapFails() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Animation")], for: .series)
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "discover-1")], page: 1, totalPages: 1, totalResults: 1)
        ])
        await stub.setSearchResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "search-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let actionCard = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil { viewModel.results.first?.id == "search-1" }
        let searchCountBeforeMoodChange = await stub.getSearchCallCount()
        #expect(searchCountBeforeMoodChange == 1)

        viewModel.selectMoodCard(actionCard)
        try await Self.waitUntil {
            viewModel.activeMoodCard?.id == "action" && viewModel.results.first?.id == "discover-1"
        }

        let discoverCountAfterMood = await stub.getDiscoverCallCount()
        #expect(discoverCountAfterMood == 1)
        #expect(viewModel.selectedGenre?.id == 28)

        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil { !viewModel.genres.isEmpty }
        viewModel.handleSelectedTypeChange()

        var attempts = 0
        while await stub.getSearchCallCount() < searchCountBeforeMoodChange + 1 && attempts < 20 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(await stub.getSearchCallCount() == searchCountBeforeMoodChange + 1)
        #expect(await stub.getDiscoverCallCount() == discoverCountAfterMood)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.results.first?.id == "search-1")
    }

    @Test
    @MainActor
    func applySortOptionRequeriesTextSearch() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "search-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "inception"
        viewModel.search()
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let firstSearchCount = await stub.getSearchCallCount()
        viewModel.applySortOption(.releaseDateDesc)
        // Wait for requery to settle
        try await Self.waitUntil { !viewModel.isSearching && viewModel.sortOption == .releaseDateDesc }

        let secondSearchCount = await stub.getSearchCallCount()
        #expect(secondSearchCount > firstSearchCount)
        #expect(viewModel.sortOption == .releaseDateDesc)
    }

    @Test
    @MainActor
    func textSearchAppliesLocalRatingSortToOMDbBackedResults() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [
                    Self.ratedPreview(id: "tt-low", title: "Low", year: 2024, rating: 6.2),
                    Self.ratedPreview(id: "tt-missing", title: "Missing", year: 2024, rating: nil),
                    Self.ratedPreview(id: "tt-high", title: "High", year: 2024, rating: 8.7),
                ],
                page: 1,
                totalPages: 1,
                totalResults: 3
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.sortOption = .ratingDesc
        viewModel.query = "dune"
        viewModel.search()

        try await Self.waitUntil { !viewModel.isSearching && viewModel.results.count == 3 }

        #expect(viewModel.results.map(\.id) == ["tt-high", "tt-low", "tt-missing"])
    }

    @Test
    @MainActor
    func loadMoreKeepsTextSearchRatingSortAcrossPages() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [
                    Self.ratedPreview(id: "tt-mid", title: "Mid", year: 2024, rating: 7.1),
                    Self.ratedPreview(id: "tt-low", title: "Low", year: 2024, rating: 6.4),
                ],
                page: 1,
                totalPages: 2,
                totalResults: 4
            ),
            2: MetadataSearchResult(
                items: [
                    Self.ratedPreview(id: "tt-high", title: "High", year: 2024, rating: 9.0),
                    Self.ratedPreview(id: "tt-missing", title: "Missing", year: 2024, rating: nil),
                ],
                page: 2,
                totalPages: 2,
                totalResults: 4
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.sortOption = .ratingDesc
        viewModel.query = "dune"
        viewModel.search()
        try await Self.waitUntil { !viewModel.isSearching && viewModel.results.count == 2 }

        viewModel.loadMore()
        try await Self.waitUntil { !viewModel.isLoadingMore && viewModel.currentPage == 2 }

        #expect(viewModel.results.map(\.id) == ["tt-high", "tt-mid", "tt-low", "tt-missing"])
    }

    @Test
    @MainActor
    func loadMoreGenreBrowseKeepsRatingSortAcrossPages() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [
                    Self.ratedPreview(id: "tt-mid", title: "Mid", year: 2024, rating: 7.1),
                    Self.ratedPreview(id: "tt-low", title: "Low", year: 2024, rating: 6.4),
                ],
                page: 1,
                totalPages: 2,
                totalResults: 4
            ),
            2: MetadataSearchResult(
                items: [
                    Self.ratedPreview(id: "tt-high", title: "High", year: 2024, rating: 9.0),
                    Self.ratedPreview(id: "tt-missing", title: "Missing", year: 2024, rating: nil),
                ],
                page: 2,
                totalPages: 2,
                totalResults: 4
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.sortOption = .ratingDesc
        viewModel.selectGenre(Genre(id: 18, name: "Drama"))
        try await Self.waitUntil { !viewModel.isSearching && viewModel.results.count == 2 }

        viewModel.loadMore()
        try await Self.waitUntil { !viewModel.isLoadingMore && viewModel.currentPage == 2 }

        #expect(viewModel.results.map(\.id) == ["tt-high", "tt-mid", "tt-low", "tt-missing"])
        #expect(await stub.getLastDiscoverFilters()?.sortBy == .ratingDesc)
    }

    @Test
    @MainActor
    func applyYearFilterRequeriesGenreBrowse() async throws {
        let stub = FilterTestMetadataStub()
        let genre = Genre(id: 18, name: "Drama")
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "year-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(genre)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        viewModel.applyYearFilter(2023)
        try await Self.waitUntil { !viewModel.isSearching && viewModel.yearFilter == 2023 }

        let discoverCount = await stub.getDiscoverCallCount()
        #expect(discoverCount >= 2)
        let lastFilters = await stub.getLastDiscoverFilters()
        #expect(lastFilters?.year == 2023)
        #expect(viewModel.yearFilter == 2023)
    }

    @Test
    @MainActor
    func clearYearFilterRequeriesWithoutYear() async throws {
        let stub = FilterTestMetadataStub()
        let genre = Genre(id: 18, name: "Drama")
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "noyear-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.yearFilter = 2023
        viewModel.selectGenre(genre)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        viewModel.applyYearFilter(nil)
        try await Self.waitUntil { !viewModel.isSearching && viewModel.yearFilter == nil }

        let discoverCount = await stub.getDiscoverCallCount()
        #expect(discoverCount >= 2)
        let lastFilters = await stub.getLastDiscoverFilters()
        #expect(lastFilters?.year == nil)
        #expect(viewModel.yearFilter == nil)
    }

    // MARK: - AI Recommendations

    @Test
    @MainActor
    func fetchAIRecommendationsPopulatesResults() async throws {
        let db = try DatabaseManager(inMemoryNamed: "search-filter-ai-\(UUID().uuidString)")
        try await db.migrate()
        let aiManager = AIAssistantManager(database: db)
        let jsonResponse = """
        [{"title":"Interstellar","year":2014,"type":"movie","reason":"Epic sci-fi","tmdbId":157336},\
        {"title":"The Expanse","year":2015,"type":"series","reason":"Hard sci-fi show","tmdbId":63639}]
        """
        let stubProvider = StubAIProvider(
            providerKind: .openAI,
            result: .success(AIProviderResponse(provider: .openAI, content: jsonResponse, model: "test", inputTokens: 10, outputTokens: 20))
        )
        await aiManager.registerProvider(kind: .openAI, provider: stubProvider)

        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        viewModel.query = "sci-fi space exploration"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil { !viewModel.aiRecommendations.isEmpty }
        #expect(viewModel.aiRecommendations.count == 2)
        #expect(viewModel.aiRecommendations[0].title == "Interstellar")
        #expect(viewModel.aiRecommendations[0].type == .movie)
        #expect(viewModel.aiRecommendations[1].title == "The Expanse")
        #expect(viewModel.aiRecommendations[1].type == .series)
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func fetchAIRecommendationsWithNoProviderSetsError() async throws {
        let db = try DatabaseManager(inMemoryNamed: "search-filter-ai-noprov-\(UUID().uuidString)")
        try await db.migrate()
        let aiManager = AIAssistantManager(database: db)
        // No provider registered

        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        viewModel.query = "something"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil { viewModel.aiError != nil }
        #expect(viewModel.aiError == "No AI provider configured. Set one up in Settings \u{2192} AI Assistant.")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func fetchAIRecommendationsWithEmptyQueryDoesNothing() async throws {
        let db = try DatabaseManager(inMemoryNamed: "search-filter-ai-empty-\(UUID().uuidString)")
        try await db.migrate()
        let aiManager = AIAssistantManager(database: db)

        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        viewModel.query = "   "
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        await Task.yield()
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.aiError == "No AI provider configured. Set one up in Settings \u{2192} AI Assistant.")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func fetchAIRecommendationsWithEmptyQueryFetchesRecommendations() async throws {
        let db = try DatabaseManager(inMemoryNamed: "search-filter-ai-empty-ok-\(UUID().uuidString)")
        try await db.migrate()
        let aiManager = AIAssistantManager(database: db)
        let stubProvider = StubAIProvider(
            providerKind: .openAI,
            result: .success(AIProviderResponse(provider: .openAI, content: """
            [{"title":"Edge Case","year":2025,"type":"movie","reason":"Works", "tmdbId":111}]
            """, model: "test", inputTokens: 0, outputTokens: 0))
        )
        await aiManager.registerProvider(kind: .openAI, provider: stubProvider)

        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        viewModel.query = "   "
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        await Task.yield()
        try await Self.waitUntil { !viewModel.isLoadingAI }
        #expect(viewModel.aiError == nil)
        #expect(viewModel.aiRecommendations.count == 1)
        #expect(viewModel.aiRecommendations[0].title == "Edge Case")
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func fetchAIRecommendationsWithProviderErrorSetsError() async throws {
        let db = try DatabaseManager(inMemoryNamed: "search-filter-ai-err-\(UUID().uuidString)")
        try await db.migrate()
        let aiManager = AIAssistantManager(database: db)
        let stubProvider = StubAIProvider(
            providerKind: .openAI,
            result: .failure(TestError.aiFailure)
        )
        await aiManager.registerProvider(kind: .openAI, provider: stubProvider)

        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        viewModel.query = "recommendation query"
        viewModel.fetchAIRecommendations(aiManager: aiManager)

        try await Self.waitUntil { viewModel.aiError != nil }
        #expect(viewModel.aiError == "AI failure")
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.isLoadingAI == false)
    }

    @Test
    @MainActor
    func clearAIRecommendationsResetsState() async throws {
        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        // Simulate populated AI state
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Test", year: 2024, type: .movie, reason: "Good", tmdbId: 1)
        ]
        viewModel.aiError = "some error"

        viewModel.clearAIRecommendations()

        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
    }

    // MARK: - Clear Resets All State

    @Test
    @MainActor
    func clearResetsAllFilterState() async throws {
        let stub = FilterTestMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        // Set up state
        viewModel.query = "test"
        viewModel.results = [Fixtures.mediaPreview(id: "r1")]
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.sortOption = .ratingDesc
        viewModel.yearFilter = 2023
        viewModel.aiRecommendations = [
            AIMovieRecommendation(title: "Test", year: 2024, type: .movie, reason: "Good", tmdbId: 1)
        ]
        viewModel.aiError = "error"
        viewModel.isLoadingAI = true

        viewModel.clear()

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.yearFilter == nil)
        #expect(viewModel.aiRecommendations.isEmpty)
        #expect(viewModel.aiError == nil)
        #expect(viewModel.isLoadingAI == false)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
    }

    @Test
    @MainActor
    func clearResetsQueryTypingSignalFlags() {
        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())

        viewModel.query = "  noir  "
        #expect(viewModel.hasQueryText == true)
        #expect(viewModel.queryDraft == "  noir  ")

        viewModel.search()

        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.submittedQuery == "noir")
        #expect(viewModel.queryDraft == "noir")
        #expect(viewModel.hasQueryText == true)

        viewModel.clear()

        #expect(viewModel.hasQueryText == false)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.submittedQuery.isEmpty == true)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
    }

    @Test
    @MainActor
    func clearIncrementsSearchGenerationAfterGenreBrowse() async throws {
        let stub = BlockingDiscoverMetadataStub(
            discoverDelay: .milliseconds(150),
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-cleared")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub)

        let generationBefore = viewModel.searchGeneration
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        #expect(viewModel.searchGeneration == generationBefore + 1)

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.clear()
        #expect(viewModel.searchGeneration == generationBefore + 2)
    }

    @Test
    @MainActor
    func clearIncrementsSearchGenerationAfterSearch() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-cleared")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let generationBefore = viewModel.searchGeneration
        viewModel.query = "blade runner"
        viewModel.search()
        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(viewModel.searchGeneration == generationBefore + 1)

        viewModel.clear()
        #expect(viewModel.searchGeneration == generationBefore + 2)
    }

    @Test
    @MainActor
    func clearDoesNotRelaunchGenreBrowseAfterClearingQuery() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-leak")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-leak")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }
        viewModel.query = "batman"
        viewModel.search()

        try await Self.waitUntil { await stub.getSearchCallCount() == 1 }
        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.clear()
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.results.isEmpty)

        try await Task.sleep(for: .milliseconds(50))
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func clearResetsSearchingStateForInFlightGenreBrowse() async throws {
        let stub = BlockingDiscoverMetadataStub(
            discoverDelay: .milliseconds(150),
            discoverResultByPage: [
                1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "browse-while-clearing")], page: 1, totalPages: 1, totalResults: 1)
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        #expect(viewModel.selectedGenre != nil)

        for _ in 0..<20 {
            if viewModel.isSearching { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(viewModel.isSearching == true)

        // Ensure clear() doesn't rely on query change to reset isSearching.
        viewModel.query = ""
        viewModel.clear()

        #expect(viewModel.isSearching == false)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.explorePhase == .idle)

        try await Task.sleep(for: .milliseconds(220))
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func inFlightSpecialMoodLoadMoreResultIgnoredAfterClear() async throws {
        let stub = BlockingDiscoverMetadataStub(
            discoverDelay: .milliseconds(150),
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "mood-page-1")],
                    page: 1,
                    totalPages: 3,
                    totalResults: 3
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "mood-page-2")],
                    page: 2,
                    totalPages: 3,
                    totalResults: 3
                )
            ]
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        try await Task.sleep(for: .milliseconds(40))
        viewModel.clear()

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.explorePhase == .idle)

        try await Task.sleep(for: .milliseconds(220))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.activeMoodCard == nil)
        #expect(!viewModel.results.contains(where: { $0.id == "mood-page-2" }))
        #expect(await stub.getDiscoverCallCount() == 2)
    }

    // MARK: - isGenreBrowsing Computed Property

    @Test
    @MainActor
    func isGenreBrowsingTrueWhenGenreSelectedAndNoQuery() {
        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = ""
        #expect(viewModel.isGenreBrowsing == true)
    }

    @Test
    @MainActor
    func isGenreBrowsingFalseWhenNoGenreSelected() {
        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        viewModel.selectedGenre = nil
        viewModel.query = "test"
        #expect(viewModel.isGenreBrowsing == false)
    }

    @Test
    @MainActor
    func isGenreBrowsingFalseWhenGenreSelectedButQueryPresent() {
        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = "action movies"
        #expect(viewModel.isGenreBrowsing == true)
    }

    @Test
    @MainActor
    func isGenreBrowsingTreatsNewlineOnlyQueryDraftAsEmpty() {
        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.queryDraft = "\n"
        #expect(viewModel.isGenreBrowsing == true)
    }

    @Test
    @MainActor
    func clearingQueryDraftReturnsToGenreBrowseResults() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-browse-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "action"
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.browseGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(viewModel.results.count == 1)

        viewModel.queryDraft = ""

        try await Task.sleep(for: .milliseconds(200))
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.isGenreBrowsing == true)
        #expect(viewModel.results.count == 1)
        #expect(viewModel.results.first?.id == "genre-browse-result")
    }

    @Test
    @MainActor
    func clearingQueryDraftReturnsToSpecialMoodBrowseResults() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-browse-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "gritty"
        let card = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        viewModel.selectMoodCard(card)

        try await Self.waitUntil { !viewModel.results.isEmpty }
        #expect(viewModel.results.count == 1)
        #expect(viewModel.activeMoodCard?.id == card.id)

        viewModel.queryDraft = ""

        try await Task.sleep(for: .milliseconds(200))
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.activeMoodCard?.id == card.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.count == 1)
        #expect(viewModel.results.first?.id == "mood-browse-result")
    }

    // MARK: - Default Sort Option

    @Test
    @MainActor
    func defaultSortOptionIsPopularityDesc() {
        let viewModel = SearchViewModel(metadataService: FilterTestMetadataStub())
        #expect(viewModel.sortOption == .popularityDesc)
    }

    // MARK: - No Metadata Service Configured

    @Test
    @MainActor
    func loadGenresWithNoServiceDoesNotCrash() async throws {
        let viewModel = SearchViewModel()
        // No metadata service configured
        viewModel.loadGenres()

        await Task.yield()
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.genres.isEmpty)
    }

    @Test
    @MainActor
    func selectGenreWithNoServiceDoesNotCrash() async throws {
        let viewModel = SearchViewModel()
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        await Task.yield()
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre?.id == 28)
    }

    // MARK: - AIMovieRecommendation → MediaPreview

    @Test
    func aiRecommendationToMediaPreviewWithTmdbId() {
        let rec = AIMovieRecommendation(title: "Dune", year: 2021, type: .movie, reason: "Great", tmdbId: 438631)
        let preview = rec.toMediaPreview()
        #expect(preview.id == "movie-tmdb-438631")
        #expect(preview.title == "Dune")
        #expect(preview.year == 2021)
        #expect(preview.type == .movie)
        #expect(preview.tmdbId == 438631)
    }

    @Test
    func aiRecommendationToMediaPreviewWithoutTmdbId() {
        let rec = AIMovieRecommendation(title: "Unknown Film", year: 2020, type: .series, reason: "Interesting")
        let preview = rec.toMediaPreview()
        #expect(preview.id == "unknown-film-2020-series")
        #expect(preview.title == "Unknown Film")
        #expect(preview.type == .series)
        #expect(preview.tmdbId == nil)
    }

    // MARK: - Interaction: Genre + Sort Combined

    @Test
    @MainActor
    func genreAndSortCombinedInDiscover() async throws {
        let stub = FilterTestMetadataStub()
        let genre = Genre(id: 878, name: "Science Fiction")
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "scifi-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.sortOption = .releaseDateDesc
        viewModel.yearFilter = 2025
        viewModel.selectedType = .movie
        viewModel.selectGenre(genre)

        try await Self.waitUntil { !viewModel.results.isEmpty }

        let lastFilters = await stub.getLastDiscoverFilters()
        #expect(lastFilters?.genreId == 878)
        #expect(lastFilters?.sortBy == .releaseDateDesc)
        #expect(lastFilters?.year == 2025)
        #expect(lastFilters?.page == 1)
    }

    @Test
    @MainActor
    func applyFilterDraftBatchesTextSearchFilterChangesIntoSingleRequery() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setSearchResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "search-initial")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "inception"
        viewModel.search()
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let initialSearchCount = await stub.getSearchCallCount()
        #expect(initialSearchCount == 1)

        let draft = SearchFilterDraft(
            sortOption: .releaseDateDesc,
            selectedYear: 2024,
            selectedLanguages: ["fr-FR"],
            selectedGenre: nil
        )
        viewModel.applyFilterDraft(draft)

        try await Self.waitUntil {
            !viewModel.isSearching &&
                viewModel.sortOption == .releaseDateDesc &&
                viewModel.yearFilter == 2024 &&
                viewModel.languageFilters == ["fr-FR"]
        }

        let finalSearchCount = await stub.getSearchCallCount()
        #expect(finalSearchCount == 2)
        #expect(viewModel.sortOption == .releaseDateDesc)
        #expect(viewModel.yearFilter == 2024)
        #expect(viewModel.yearRangePreset == .recent)
        #expect(viewModel.languageFilters == ["fr-FR"])
    }

    @Test
    @MainActor
    func applyFilterDraftClearsSpecialMoodContextBeforeManualGenreBrowse() async throws {
        let stub = FilterTestMetadataStub()
        await stub.setDiscoverResults([
            1: MetadataSearchResult(items: [Fixtures.mediaPreview(id: "discover-1")], page: 1, totalPages: 1, totalResults: 1)
        ])

        let viewModel = SearchViewModel(metadataService: stub)
        let newReleasesCard = ExploreMoodCard(
            id: "new",
            title: "New Releases",
            subtitle: "JUST DROPPED",
            symbol: "flame.fill",
            color: .red,
            movieGenreId: -1,
            tvGenreId: -1
        )

        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil { !viewModel.results.isEmpty }

        let initialDiscoverCount = await stub.getDiscoverCallCount()
        #expect(initialDiscoverCount == 1)
        #expect(viewModel.activeMoodCard?.id == "new")

        let draft = SearchFilterDraft(
            sortOption: .ratingDesc,
            selectedYear: 2023,
            selectedLanguages: ["es-ES"],
            selectedGenre: Genre(id: 28, name: "Action")
        )
        viewModel.applyFilterDraft(draft)

        try await Self.waitUntil {
            !viewModel.isSearching &&
                viewModel.selectedGenre?.id == 28 &&
                viewModel.activeMoodCard == nil
        }

        let finalDiscoverCount = await stub.getDiscoverCallCount()
        #expect(finalDiscoverCount == 2)
        let lastFilters = await stub.getLastDiscoverFilters()
        #expect(lastFilters?.genreId == 28)
        #expect(lastFilters?.sortBy == .ratingDesc)
        #expect(lastFilters?.year == 2023)
        #expect(lastFilters?.releaseDateGte == nil)
        #expect(lastFilters?.releaseDateLte == DiscoverFilters.todayString())
    }
}
