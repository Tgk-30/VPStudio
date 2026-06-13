import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct SearchViewModelBugCoverageTests {
    private enum BugProbeError: Error {
        case transientFailure
    }

    private actor GenreLoadFlakyMetadataStub: MetadataProvider {
        private let successfulGenres: [Genre]
        private var failNextGenresLoad: Bool
        private(set) var genresCallCount = 0

        init(successfulGenres: [Genre], failNextGenresLoad: Bool) {
            self.successfulGenres = successfulGenres
            self.failNextGenresLoad = failNextGenresLoad
        }

        func setFailNextGenresLoad(_ value: Bool) {
            failNextGenresLoad = value
        }

        func getGenresCallCount() -> Int {
            genresCallCount
        }

        func getSearchCallCount() -> Int {
            0
        }

        func getSearchCallCount(for page: Int) -> Int {
            0
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            genresCallCount += 1
            if failNextGenresLoad {
                failNextGenresLoad = false
                throw BugProbeError.transientFailure
            }
            return successfulGenres
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchCountingMetadataStub: MetadataProvider {
        private(set) var searchCallCount = 0
        private(set) var discoverCallCount = 0
        private(set) var genresCallCount = 0
        var discoverResult: MetadataSearchResult
        var searchResult: MetadataSearchResult

        init(
            discoverResult: MetadataSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0),
            searchResult: MetadataSearchResult = MetadataSearchResult(items: [Fixtures.mediaPreview(id: "search-result")], page: 1, totalPages: 1, totalResults: 1)
        ) {
            self.discoverResult = discoverResult
            self.searchResult = searchResult
        }

        func getSearchCallCount() -> Int {
            searchCallCount
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
        }

        func getGenresCallCount() -> Int {
            genresCallCount
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCallCount += 1
            return searchResult
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            return discoverResult
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            genresCallCount += 1
            return []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor DiscoverRetryMetadataStub: MetadataProvider {
        private(set) var discoverCallCount = 0
        private var shouldFailNextDiscover = true
        let successResult: MetadataSearchResult

        init(successResult: MetadataSearchResult) {
            self.successResult = successResult
        }

        func setShouldFailNextDiscover(_ value: Bool) {
            shouldFailNextDiscover = value
        }

        func getSearchCallCount() -> Int {
            0
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            if shouldFailNextDiscover {
                shouldFailNextDiscover = false
                throw BugProbeError.transientFailure
            }
            return successResult
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchQueryCaptureMetadataStub: MetadataProvider {
        struct SearchCall: Sendable, Equatable {
            let query: String
            let page: Int
            let year: Int?
            let language: String?
        }

        private(set) var discoverCallCount = 0
        private var searchCalls: [SearchCall] = []

        func getSearchCalls() -> [SearchCall] {
            searchCalls
        }

        func getSearchCallCount() -> Int {
            searchCalls.count
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
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
                items: [Fixtures.mediaPreview(id: "search-\(query)-p\(page)")],
                page: page,
                totalPages: 2,
                totalResults: 1
            )
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            return MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchResultByQueryCaptureMetadataStub: MetadataProvider {
        struct SearchCall: Sendable, Equatable {
            let query: String
            let page: Int
            let year: Int?
            let language: String?
        }

        private let searchResultByQuery: [String: [Int: MetadataSearchResult]]
        private(set) var discoverCallCount = 0
        private var searchCalls: [SearchCall] = []
        private var searchDelayByQuery: [String: Duration] = [:]

        init(searchResultByQuery: [String: [Int: MetadataSearchResult]]) {
            self.searchResultByQuery = searchResultByQuery
        }

        func setSearchDelay(_ delay: Duration, for query: String) {
            searchDelayByQuery[query] = delay
        }

        func getSearchCalls() -> [SearchCall] {
            searchCalls
        }

        func getSearchCallCount() -> Int {
            searchCalls.count
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
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
            if let delay = searchDelayByQuery[query] {
                try await Task.sleep(for: delay)
            }
            return searchResultByQuery[query]?[page] ?? MetadataSearchResult(
                items: [],
                page: page,
                totalPages: 1,
                totalResults: 0
            )
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            return MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchCaptureWithDelayMetadataStub: MetadataProvider {
        struct SearchCall: Sendable, Equatable {
            let query: String
            let page: Int
            let year: Int?
            let language: String?
        }

        private(set) var discoverCallCount = 0
        private var searchCalls: [SearchCall] = []
        private var searchResultByPage: [Int: MetadataSearchResult]
        private var searchDelayByPage: [Int: Duration] = [:]

        init(searchResultByPage: [Int: MetadataSearchResult]) {
            self.searchResultByPage = searchResultByPage
        }

        func getSearchCalls() -> [SearchCall] {
            searchCalls
        }

        func getSearchCallCount() -> Int {
            searchCalls.count
        }

        func setSearchDelay(_ delay: Duration, for page: Int) {
            searchDelayByPage[page] = delay
        }

        func setSearchResult(_ result: MetadataSearchResult, for page: Int) {
            searchResultByPage[page] = result
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
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

            if let delay = searchDelayByPage[page] {
                try await Task.sleep(for: delay)
            }

            return searchResultByPage[page] ?? MetadataSearchResult(
                items: [],
                page: page,
                totalPages: 1,
                totalResults: 0
            )
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            return MetadataSearchResult(items: [], page: filters.page, totalPages: 1, totalResults: 0)
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor GenreLoadDedupMetadataStub: MetadataProvider {
        private(set) var genresCallCount = 0
        private var genresByType: [MediaType: [Genre]]
        private var genreDelayByType: [MediaType: Duration] = [:]
        private var failGenresByType: Set<MediaType> = []

        init(genresByType: [MediaType: [Genre]] = [:]) {
            self.genresByType = genresByType
        }

        func setGenres(_ genres: [Genre], for type: MediaType) {
            genresByType[type] = genres
        }

        func setGenreLoadFailureOnce(for type: MediaType) {
            failGenresByType.insert(type)
        }

        func setGenreLoadDelay(_ delay: Duration, for type: MediaType) {
            genreDelayByType[type] = delay
        }

        func getGenresCallCount() -> Int {
            genresCallCount
        }

        func getSearchCallCount() -> Int {
            0
        }

        func getDiscoverCallCount() -> Int {
            0
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

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
            genresCallCount += 1
            if let delay = genreDelayByType[type] {
                try await Task.sleep(for: delay)
            }
            if failGenresByType.remove(type) != nil {
                throw BugProbeError.transientFailure
            }
            return genresByType[type] ?? []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor MoodLoadMoreMetadataStub: MetadataProvider {
        private(set) var discoverCallCount = 0
        private var discoverFilters: [DiscoverFilters] = []
        private let resultByPage: [Int: MetadataSearchResult]

        init(resultByPage: [Int: MetadataSearchResult] = [:]) {
            self.resultByPage = resultByPage
        }

        func getDiscoverFilters() -> [DiscoverFilters] {
            discoverFilters
        }

        func getSearchCallCount() -> Int {
            0
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            discoverFilters.append(filters)
            return resultByPage[filters.page] ?? MetadataSearchResult(
                items: [],
                page: filters.page,
                totalPages: filters.page,
                totalResults: 0
            )
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchAndDiscoverCaptureMetadataStub: MetadataProvider {
        struct SearchCall: Sendable, Equatable {
            let query: String
            let page: Int
            let year: Int?
            let language: String?
        }

        struct DiscoverCall: Sendable, Equatable {
            let genreId: Int?
            let page: Int
            let year: Int?
            let language: String?
            let sort: DiscoverFilters.SortOption
            let originalLanguage: String?
        }

        private(set) var searchCallCount = 0
        private(set) var discoverCallCount = 0
        private var searchCalls: [SearchCall] = []
        private var discoverCalls: [DiscoverCall] = []
        private var searchDelayByPage: [Int: Duration] = [:]
        private var discoverDelayByPage: [Int: Duration] = [:]
        private var searchFailureByPage: [Int: Int] = [:]
        private var discoverFailureByPage: [Int: Int] = [:]
        private var searchResultByPage: [Int: MetadataSearchResult]
        private var discoverResultByPage: [Int: MetadataSearchResult]

        init(
            searchResultByPage: [Int: MetadataSearchResult] = [:],
            discoverResultByPage: [Int: MetadataSearchResult] = [:]
        ) {
            self.searchResultByPage = searchResultByPage
            self.discoverResultByPage = discoverResultByPage
        }

        func getSearchCallCount() -> Int {
            searchCallCount
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
        }

        func getSearchCalls() -> [SearchCall] {
            searchCalls
        }

        func getDiscoverCalls() -> [DiscoverCall] {
            discoverCalls
        }

        func setSearchDelay(_ delay: Duration, for page: Int) {
            searchDelayByPage[page] = delay
        }

        func setDiscoverDelay(_ delay: Duration, for page: Int) {
            discoverDelayByPage[page] = delay
        }

        func setDiscoverResult(_ result: MetadataSearchResult, for page: Int) {
            discoverResultByPage[page] = result
        }

        func setSearchResult(_ result: MetadataSearchResult, for page: Int) {
            searchResultByPage[page] = result
        }

        func setDiscoverFailure(page: Int, times: Int) {
            discoverFailureByPage[page] = times
        }

        func setSearchFailure(page: Int, times: Int) {
            searchFailureByPage[page] = times
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCalls.append(SearchCall(query: query, page: page, year: nil, language: nil))
            searchCallCount += 1

            if let delay = searchDelayByPage[page] {
                try await Task.sleep(for: delay)
            }
            if let remainingFailures = searchFailureByPage[page], remainingFailures > 0 {
                searchFailureByPage[page] = remainingFailures - 1
                throw BugProbeError.transientFailure
            }

            return searchResultByPage[page] ?? MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCalls.append(DiscoverCall(
                genreId: filters.genreId,
                page: filters.page,
                year: filters.year,
                language: filters.language,
                sort: filters.sortBy,
                originalLanguage: filters.originalLanguage
            ))
            discoverCallCount += 1

            let page = filters.page
            if let delay = discoverDelayByPage[page] {
                try await Task.sleep(for: delay)
            }

            if let remainingFailures = discoverFailureByPage[page], remainingFailures > 0 {
                discoverFailureByPage[page] = remainingFailures - 1
                throw BugProbeError.transientFailure
            }

            return discoverResultByPage[page] ?? MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor RegularGenreBrowseFilterCaptureMetadataStub: MetadataProvider {
        struct DiscoverCall: Sendable, Equatable {
            let genreId: Int?
            let page: Int
            let year: Int?
            let language: String?
            let sort: DiscoverFilters.SortOption
            let originalLanguage: String?
            let releaseDateGte: String?
            let releaseDateLte: String?
        }

        private(set) var discoverCallCount = 0
        private var discoverCalls: [DiscoverCall] = []
        private let result: MetadataSearchResult

        init(result: MetadataSearchResult) {
            self.result = result
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
        }

        func getDiscoverCalls() -> [DiscoverCall] {
            discoverCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            discoverCalls.append(DiscoverCall(
                genreId: filters.genreId,
                page: filters.page,
                year: filters.year,
                language: filters.language,
                sort: filters.sortBy,
                originalLanguage: filters.originalLanguage,
                releaseDateGte: filters.releaseDateGte,
                releaseDateLte: filters.releaseDateLte
            ))
            return result
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor GenreRouteDiscoverMetadataStub: MetadataProvider {
        struct DiscoverCall: Sendable, Equatable {
            let genreId: Int?
            let page: Int
        }

        private(set) var discoverCallCount = 0
        private(set) var discoverCalls: [DiscoverCall] = []
        private let discoverResultByGenre: [Int: MetadataSearchResult]
        private var discoverDelayByGenre: [Int: Duration] = [:]

        init(discoverResultByGenre: [Int: MetadataSearchResult]) {
            self.discoverResultByGenre = discoverResultByGenre
        }

        func setDiscoverDelay(_ delay: Duration, for genreId: Int) {
            discoverDelayByGenre[genreId] = delay
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
        }

        func getDiscoverCalls() -> [DiscoverCall] {
            discoverCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCallCount += 1
            discoverCalls.append(DiscoverCall(
                genreId: filters.genreId,
                page: filters.page
            ))
            if let genreId = filters.genreId, let delay = discoverDelayByGenre[genreId] {
                try await Task.sleep(for: delay)
            }
            return discoverResultByGenre[filters.genreId ?? -1] ?? MetadataSearchResult(
                items: [],
                page: filters.page,
                totalPages: filters.page,
                totalResults: 0
            )
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor GenreAwareMetadataStub: MetadataProvider {
        struct SearchCall: Sendable, Equatable {
            let query: String
            let page: Int
            let year: Int?
            let language: String?
        }

        struct DiscoverCall: Sendable, Equatable {
            let genreId: Int?
            let page: Int
            let year: Int?
            let language: String?
            let sort: DiscoverFilters.SortOption
            let originalLanguage: String?
        }

        private let genresByType: [MediaType: [Genre]]
        private let discoverResultByPage: [Int: MetadataSearchResult]
        private let searchResultByPage: [Int: MetadataSearchResult]
        private(set) var genresCallCount = 0
        private(set) var searchCallCount = 0
        private(set) var discoverCallCount = 0
        private var searchCalls: [SearchCall] = []
        private var discoverCalls: [DiscoverCall] = []

        init(
            genresByType: [MediaType: [Genre]] = [:],
            searchResultByPage: [Int: MetadataSearchResult] = [:],
            discoverResultByPage: [Int: MetadataSearchResult] = [:]
        ) {
            self.genresByType = genresByType
            self.searchResultByPage = searchResultByPage
            self.discoverResultByPage = discoverResultByPage
        }

        func getGenresCallCount() -> Int {
            genresCallCount
        }

        func getSearchCallCount() -> Int {
            searchCallCount
        }

        func getDiscoverCallCount() -> Int {
            discoverCallCount
        }

        func getSearchCalls() -> [SearchCall] {
            searchCalls
        }

        func getDiscoverCalls() -> [DiscoverCall] {
            discoverCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCalls.append(SearchCall(query: query, page: page, year: nil, language: nil))
            searchCallCount += 1

            return searchResultByPage[page] ?? MetadataSearchResult(
                items: [],
                page: page,
                totalPages: page,
                totalResults: 0
            )
        }

        func search(
            query: String,
            type: MediaType?,
            page: Int,
            year: Int?,
            language: String?
        ) async throws -> MetadataSearchResult {
            searchCalls.append(SearchCall(query: query, page: page, year: year, language: language))
            searchCallCount += 1

            return searchResultByPage[page] ?? MetadataSearchResult(
                items: [],
                page: page,
                totalPages: page,
                totalResults: 0
            )
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCalls.append(DiscoverCall(
                genreId: filters.genreId,
                page: filters.page,
                year: filters.year,
                language: filters.language,
                sort: filters.sortBy,
                originalLanguage: filters.originalLanguage
            ))
            discoverCallCount += 1

            return discoverResultByPage[filters.page] ?? MetadataSearchResult(
                items: [],
                page: filters.page,
                totalPages: 1,
                totalResults: 0
            )
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            genresCallCount += 1
            return genresByType[type] ?? []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor ConfiguredKeyGenreMetadataStub: MetadataProvider {
        private let genresByType: [MediaType: [Genre]]
        private(set) var genresCallCount = 0

        init(genresByType: [MediaType: [Genre]] = [:]) {
            self.genresByType = genresByType
        }

        func getGenresCallCount() -> Int {
            genresCallCount
        }

        func getSearchCallCount() -> Int {
            0
        }

        func getDiscoverCallCount() -> Int {
            0
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            genresCallCount += 1
            return genresByType[type] ?? []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    private actor SearchYearFilterCaptureMetadataStub: MetadataProvider {
        private let searchResult: MetadataSearchResult
        private var searchCalls: [Int?] = []

        init(searchResult: MetadataSearchResult) {
            self.searchResult = searchResult
        }

        func getSearchCalls() -> [Int?] {
            searchCalls
        }

        func getSearchCallCount() -> Int {
            searchCalls.count
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCalls.append(nil)
            return searchResult
        }

        func search(
            query: String,
            type: MediaType?,
            page: Int,
            year: Int?,
            language: String?
        ) async throws -> MetadataSearchResult {
            searchCalls.append(year)
            return searchResult
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            fatalError("unused")
        }

        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
            fatalError("unused")
        }

        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
            fatalError("unused")
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0)
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] {
            []
        }

        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
            []
        }

        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
            ExternalIds(imdbId: nil, tvdbId: nil)
        }
    }

    /// Polls until `condition` returns true, yielding between checks. Fails after `timeout`.
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
    func loadGenresTransientFailureIsRetriable() async throws {
        let stub = GenreLoadFlakyMetadataStub(
            successfulGenres: [Genre(id: 18, name: "Drama")],
            failNextGenresLoad: true
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 1
        }
        #expect(viewModel.genres.isEmpty)
        #expect(await stub.getGenresCallCount() == 1)

        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 2
        }
        #expect(await stub.getGenresCallCount() == 2)
        try await Self.waitUntil {
            !viewModel.genres.isEmpty
        }
        #expect(viewModel.genres.map(\.name) == ["Drama"])
    }

    @Test
    @MainActor
    func configureChangingApiKeyClearsGenreCacheAndReloadsFromNewService() async throws {
        let keyAService = ConfiguredKeyGenreMetadataStub(
            genresByType: [
                .movie: [Genre(id: 28, name: "Action")]
            ]
        )
        let keyBService = ConfiguredKeyGenreMetadataStub(
            genresByType: [
                .movie: [Genre(id: 16, name: "Animation")]
            ]
        )
        let viewModel = SearchViewModel(metadataServiceFactory: { key in
            switch key {
            case "key-a": return keyAService
            case "key-b": return keyBService
            default: return keyAService
            }
        })

        viewModel.configure(apiKey: "key-a")
        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await keyAService.getGenresCallCount() == 1
        }

        #expect(await keyAService.getGenresCallCount() == 1)
        #expect(await keyBService.getGenresCallCount() == 0)
        #expect(viewModel.genres.map(\.id) == [28])

        viewModel.configure(apiKey: "  key-b  ")
        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await keyBService.getGenresCallCount() == 1
        }

        #expect(await keyBService.getGenresCallCount() == 1)
        #expect(await keyAService.getGenresCallCount() == 1)
        #expect(viewModel.genres.map(\.id) == [16])
    }

    @Test
    @MainActor
    func configureSameNormalizedKeyDoesNotDuplicateInFlightGenreLoad() async throws {
        let stub = GenreLoadDedupMetadataStub(genresByType: [.movie: [Genre(id: 28, name: "Action")]])
        await stub.setGenreLoadDelay(.milliseconds(220), for: .movie)
        let viewModel = SearchViewModel(metadataServiceFactory: { key in
            #expect(key == "key-a")
            return stub
        })

        viewModel.configure(apiKey: "  key-a  ")
        viewModel.loadGenres()
        try await Task.sleep(for: .milliseconds(40))
        #expect(await stub.getGenresCallCount() == 1)
        #expect(viewModel.genres.isEmpty)

        viewModel.configure(apiKey: "key-a")
        viewModel.loadGenres()
        #expect(await stub.getGenresCallCount() == 1)
        #expect(viewModel.genres.isEmpty)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 1
        }
        #expect(await stub.getGenresCallCount() == 1)
    }

    @Test
    @MainActor
    func configureEmptyKeyCancelsInFlightGenreLoadAndResetsGenreContext() async throws {
        let stub = GenreLoadDedupMetadataStub(genresByType: [.movie: [Genre(id: 28, name: "Action")]])
        await stub.setGenreLoadDelay(.milliseconds(220), for: .movie)
        let viewModel = SearchViewModel(metadataServiceFactory: { key in
            #expect(key == "key-a")
            return stub
        })

        viewModel.configure(apiKey: "key-a")
        viewModel.selectedType = .series
        viewModel.selectedGenre = Genre(id: 18, name: "Drama")
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        viewModel.selectMoodCard(specialCard)
        viewModel.results = [Fixtures.mediaPreview(id: "stale-result")]
        viewModel.loadGenres()
        try await Task.sleep(for: .milliseconds(40))

        #expect(await stub.getGenresCallCount() == 1)
        #expect(viewModel.results.map(\.id) == ["stale-result"])
        #expect(viewModel.genres.isEmpty)

        viewModel.configure(apiKey: "   ")
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.genres.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedType == .series)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getGenresCallCount() == 1)
        #expect(viewModel.genres.isEmpty)
        #expect(viewModel.results.isEmpty)

        viewModel.loadGenres()
        #expect(await stub.getGenresCallCount() == 1)

        viewModel.configure(apiKey: "key-a")
        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 2
        }
        #expect(await stub.getGenresCallCount() == 2)
    }

    @Test
    @MainActor
    func configureEmptyKeyCancelsInFlightSearchAndAllowsFreshSearchAfterReset() async throws {
        let stub = SearchCaptureWithDelayMetadataStub(searchResultByPage: [
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "apollo-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])
        await stub.setSearchDelay(.milliseconds(200), for: 1)

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                #expect(key == "key-a")
                return stub
            },
            paginationCooldown: .milliseconds(0)
        )

        viewModel.configure(apiKey: "key-a")
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        let generationAfterInitialSearch = viewModel.searchGeneration
        #expect(viewModel.results.isEmpty)

        viewModel.configure(apiKey: "   ")
        #expect(viewModel.searchGeneration == generationAfterInitialSearch + 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")

        // A delayed result from the canceled request should never be appended.
        try await Task.sleep(for: .milliseconds(240))
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.isSearching == false)

        viewModel.configure(apiKey: "key-a")
        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["apollo-page-1"])
    }

    @Test
    @MainActor
    func configureToDifferentKeyCancelsInFlightSearchWithoutAutomaticRerun() async throws {
        let keyAStub = SearchCaptureWithDelayMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "key-a-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await keyAStub.setSearchDelay(.milliseconds(240), for: 1)
        let keyBStub = SearchCaptureWithDelayMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "key-b-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                switch key {
                case "key-a": return keyAStub
                case "key-b": return keyBStub
                default: return keyAStub
                }
            },
            debounceInterval: .milliseconds(80),
            paginationCooldown: .milliseconds(0)
        )

        viewModel.configure(apiKey: "key-a")
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await keyAStub.getSearchCallCount() == 1
        }
        #expect(await keyAStub.getSearchCallCount() == 1)
        #expect(await keyBStub.getSearchCallCount() == 0)

        let generationAfterInitialSearch = viewModel.searchGeneration
        viewModel.configure(apiKey: "key-b")
        #expect(viewModel.searchGeneration == generationAfterInitialSearch + 1)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.results.isEmpty)
        #expect(await keyBStub.getSearchCallCount() == 0)

        // Delayed in-flight key-a response must not publish after key switch.
        try await Task.sleep(for: .milliseconds(280))
        #expect(await keyAStub.getSearchCallCount() == 1)
        #expect(await keyBStub.getSearchCallCount() == 0)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await keyBStub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["key-b-search-page-1"])
    }

    @Test
    @MainActor
    func selectGenreNilWithWhitespaceQueryDoesNotTriggerSearch() async {
        let stub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)
        let genre = Genre(id: 28, name: "Action")

        viewModel.selectedGenre = genre
        viewModel.results = [Fixtures.mediaPreview(id: "stale-item")]
        viewModel.queryDraft = "   "
        let priorSearchCount = await stub.getSearchCallCount()

        viewModel.selectGenre(nil)

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.isEmpty)
        #expect(await stub.getSearchCallCount() == priorSearchCount)
        #expect(viewModel.isSearching == false)
    }

    @Test
    @MainActor
    func assigningWhitespaceQueryInGenreContextFallsBackToGenreBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(viewModel.submittedQuery == "apollo")

        viewModel.query = "   "
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.selectedGenre?.id == 28)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(await stub.getSearchCallCount() == 1)
    }

    @Test
    @MainActor
    func selectGenreNilPreservesSpecialMoodContextUntilQueryIsCleared() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = "apollo"
        viewModel.selectGenre(nil)

        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.results.map { $0.id } == ["special-search-page-1"])

        viewModel.queryDraft = ""
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])
    }

    @Test
    @MainActor
    func selectGenreNilWithSpecialMoodAndWhitespaceQueryFallsBackToSpecialMoodBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.queryDraft = "   "
        viewModel.selectGenre(nil)

        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])
    }

    @Test
    @MainActor
    func selectGenreNilFromRegularMoodClearsGenreAndRegularMoodAndDoesNotReissueNetworkCall() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }

        #expect(viewModel.selectedGenre != nil)
        #expect(viewModel.activeMoodCard?.id == regularMoodCard.id)
        #expect(viewModel.results.map(\.id) == ["regular-mood-browse-page-1"])

        viewModel.selectGenre(nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func requeryFromRegularMoodWithEmptyQueryDoesNotReissueNetworkRequest() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.requery()

        #expect(viewModel.activeMoodCard?.id == regularMoodCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func requeryFromRegularMoodWithQueryReissuesSearchPath() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )

        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(regularMoodCard)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == regularMoodCard.id)
        #expect(viewModel.selectedGenre != nil)

        viewModel.queryDraft = "apollo"
        #expect(viewModel.query == "")
        viewModel.requery()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func selectGenreNilFromRegularMoodWithActiveQueryTriggersSearch() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == regularMoodCard.id)
        #expect(viewModel.selectedGenre != nil)
        #expect(viewModel.results.map(\.id) == ["regular-mood-browse-page-1"])

        viewModel.queryDraft = "apollo"
        viewModel.selectGenre(nil)
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getSearchCallCount() == 1
        }

        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])
    }

    @Test
    @MainActor
    func clearAllFiltersFromRegularMoodWithActiveQueryPreservesSearchPath() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == regularMoodCard.id)

        viewModel.queryDraft = "  apollo  "
        viewModel.clearAllFilters()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func clearAllFiltersDuringRegularMoodSearchPaginationIgnoresStaleResultAndKeepsSearchPath() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )

        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(200)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.error == nil)

        viewModel.clearAllFilters()
        try await Self.waitUntil {
            let searchCallCount = await stub.getSearchCallCount()
            return viewModel.selectedGenre == nil
                && viewModel.activeMoodCard == nil
                && viewModel.query == "apollo"
                && viewModel.queryDraft == "apollo"
                && searchCallCount == 3
                && !viewModel.results.isEmpty
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 3)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 4
                && viewModel.currentPage == 2
        }

        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1", "regular-mood-search-page-2"])
        #expect(viewModel.error == nil)
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func clearAllFiltersDuringRegularMoodSearchPaginationFailureDoesNotLeakErrorAndAllowsFreshRetryWithTrimmedQueryDraft() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 3,
                    totalResults: 3
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-2")],
                    page: 2,
                    totalPages: 3,
                    totalResults: 3
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchFailure(page: 2, times: 1)
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        viewModel.queryDraft = "   apollo-2   "
        viewModel.clearAllFilters()
        try await Self.waitUntil {
            let searchCallCount = await stub.getSearchCallCount()
            return viewModel.selectedGenre == nil
                && viewModel.activeMoodCard == nil
                && viewModel.query == "apollo-2"
                && viewModel.queryDraft == "apollo-2"
                && searchCallCount == 3
        }
        #expect(viewModel.totalPages == 3)
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 3)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.error == nil)

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 4
                && viewModel.currentPage == 2
        }
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1", "regular-mood-search-page-2"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersFromMixedRegularAndSpecialContextPreservesSpecialBrowseAndDoesNotLeakRegularBrowseFailure() async throws {
        let regularGenreCard = Genre(id: 28, name: "Action")
        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-browse-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverFailure(page: 2, times: 1)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == regularMoodCard.id)
        #expect(viewModel.selectedGenre?.id == regularGenreCard.id)
        #expect(viewModel.results.map(\.id) == ["regular-browse-page-1"])

        viewModel.selectMoodCard(specialCard)
        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "special-browse-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        viewModel.clearAllFilters()
        try await Self.waitUntil {
            let discoverCallCount = await stub.getDiscoverCallCount()
            return viewModel.activeMoodCard?.id == specialCard.id
                && viewModel.selectedGenre == nil
                && discoverCallCount == 3
                && viewModel.error == nil
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 2)
        #expect(viewModel.error == nil)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 3)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.error == nil)

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 4
                && viewModel.currentPage == 2
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1", "special-browse-page-2"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersSuppressesExplicitDebouncedSearch() async throws {
        let stub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(150),
            paginationCooldown: .milliseconds(0)
        )

        viewModel.queryDraft = "   "
        viewModel.debouncedSearch(queryText: "apollo")

        try await Task.sleep(for: .milliseconds(40))
        viewModel.clearAllFilters()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.results.isEmpty)

        try await Task.sleep(for: .milliseconds(220))
        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func clearAllFiltersWithSpecialMoodAndExplicitDebouncedQueryKeepsBrowseState() async throws {
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(150)
        )

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.queryDraft = "   "
        viewModel.debouncedSearch(queryText: "apollo")
        try await Task.sleep(for: .milliseconds(40))

        viewModel.clearAllFilters()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.activeMoodCard?.id == specialCard.id)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            let discoverCallCount = await stub.getDiscoverCallCount()
            let searchCallCount = await stub.getSearchCallCount()
            return discoverCallCount == 2
                && searchCallCount == 0
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersWithGenreSelectionAndExplicitDebouncedQueryClearsBrowseState() async throws {
        let genre = Genre(id: 28, name: "Action")
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(150))
        viewModel.selectGenre(genre)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.results.map(\.id) == ["genre-browse-page-1"])

        viewModel.queryDraft = "   "
        viewModel.debouncedSearch(queryText: "apollo")
        try await Task.sleep(for: .milliseconds(40))

        viewModel.clearAllFilters()
        try await Self.waitUntil {
            viewModel.selectedGenre == nil
                && viewModel.query.isEmpty
                && viewModel.queryDraft == "   "
                && viewModel.results.isEmpty
        }

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 0
        }
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func loadMoreFromRegularMoodSearchContextUsesSearchPagination() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1", "regular-mood-search-page-2"])
    }

    @Test
    @MainActor
    func loadMoreFromRegularMoodSearchContextDoesNotRunWhenQueryDraftChanges() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])

        viewModel.queryDraft = "apollo-2"
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(120))

        #expect(await stub.getSearchCallCount() == 1)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])
    }

    @Test
    @MainActor
    func assigningWhitespaceQueryInRegularMoodSearchContextFallsBackToGenreBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])
        #expect(viewModel.selectedGenre != nil)
        #expect(viewModel.activeMoodCard == nil)

        viewModel.query = "   "
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.selectedGenre != nil)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        #expect(viewModel.results.map(\.id) == ["regular-mood-browse-page-1"])
        #expect(viewModel.activeMoodCard == nil)
        #expect(await stub.getSearchCallCount() == 1)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromRegularMoodSearchFallsBackToSearchWhenGenreCacheIsMissing() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.selectedGenre != nil)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromGenreContextWithoutCacheDropsStaleBrowsePageDuringTransition() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.query = "apollo"
        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromRegularMoodContextWithoutCacheKeepsSearchModeAndDropsStaleBrowsePage() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.selectedGenre != nil)
        #expect(viewModel.activeMoodCard?.id == regularMoodCard.id)
        #expect(viewModel.results.map(\.id) == ["regular-mood-page-1"])

        viewModel.query = "apollo"
        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.results.map(\.id) == ["search-page-1"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromSpecialMoodBrowseWithoutCachedGenresCancelsInFlightPagination() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 3)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromSpecialMoodSearchWithoutCachedGenresCancelsInFlightPagination() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.results.map { $0.id } == ["special-search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.results.map { $0.id } == ["special-search-page-1"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 3)
        #expect(viewModel.results.map { $0.id } == ["special-search-page-1"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func regularMoodSearchLoadMoreFailureCanBeRetried() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchFailure(page: 2, times: 1)

        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])
        #expect(viewModel.selectedGenre != nil)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            viewModel.error != nil
        }
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])
        #expect(viewModel.error != nil)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getSearchCallCount() == 3
        }
        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1", "regular-mood-search-page-2"])
    }

    @Test
    @MainActor
    func queryWhitespaceClearedDuringRegularMoodSearchLoadMoreFallsBackToBrowseWithoutStaleAppend() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-2-stale")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setSearchDelay(.milliseconds(200), for: 2)

        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))
        #expect(await stub.getSearchCallCount() == 2)

        viewModel.query = "   "
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getDiscoverCallCount() == 2
        }

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.error == nil)
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["regular-mood-browse-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getDiscoverCallCount() == 3
        }
        #expect(viewModel.results.map(\.id) == ["regular-mood-browse-page-1", "regular-mood-browse-page-2"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func retryAfterRegularMoodSearchFailureRestoresSearchModeResults() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchFailure(page: 1, times: 1)

        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil {
            viewModel.error != nil
        }

        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.selectedGenre != nil)
        #expect(viewModel.isGenreBrowsing == false)

        viewModel.retry()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["regular-mood-search-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.isGenreBrowsing == false)
    }

    @Test
    @MainActor
    func assigningWhitespaceQueryInSpecialMoodContextFallsBackToSpecialMoodBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])
        #expect(viewModel.submittedQuery == "apollo")

        viewModel.query = "   "
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)

        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])
    }

    @Test
    @MainActor
    func retryAfterFailedGenreBrowseReloadsDiscoverResults() async throws {
        let expectedResult = MetadataSearchResult(
            items: [Fixtures.mediaPreview(id: "retry-genre-result")],
            page: 1,
            totalPages: 1,
            totalResults: 1
        )
        let stub = DiscoverRetryMetadataStub(successResult: expectedResult)
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        try await Self.waitUntil {
            viewModel.error != nil
        }

        viewModel.retry()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["retry-genre-result"])
    }

    @Test
    @MainActor
    func clearAllFiltersWithGenreSelectionAndQueryReexecutesSearchPath() async throws {
        let stub = SearchCountingMetadataStub(
            searchResult: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "query-retry-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.queryDraft = "  dune  "

        #expect(await stub.getSearchCallCount() == 0)
        viewModel.clearAllFilters()

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.map(\.id) == ["query-retry-result"])
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.query == "dune")
        #expect(viewModel.submittedQuery == "dune")
        #expect(await stub.getDiscoverCallCount() == 0)
    }

    @Test
    @MainActor
    func clearAllFiltersWithGenreSelectionAndSpecialMoodWithoutQueryFallsBackToSpecialMoodBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.selectedGenre = Genre(id: 28, name: "Action")

        viewModel.clearAllFilters()
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getDiscoverCallCount() == 2
        }

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func clearAllFiltersWithMixedGenreAndSpecialMoodContextReexecutesSearchPath() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-result")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "mood-result")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(specialCard)
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)

        viewModel.sortOption = .ratingDesc
        viewModel.languageFilters = ["fr-FR"]
        viewModel.yearRangePreset = .tens
        viewModel.query = "apollo"

        viewModel.clearAllFilters()

        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(viewModel.yearFilter == nil)
        #expect(viewModel.yearRangePreset == nil)
        #expect(viewModel.results.map(\.id) == ["search-result"])
        #expect(await stub.getSearchCalls().count == 1)
    }

    @Test
    @MainActor
    func applyYearRangePresetNilResetsRangeAndRequeriesCurrentSearch() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.queryDraft = "  dune  "
        viewModel.applyYearRangePreset(.twenties)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        let afterPresetCalls = await stub.getSearchCalls()
        #expect(afterPresetCalls.count == 1)
        #expect(afterPresetCalls[0].query == "dune")
        #expect(afterPresetCalls[0].year == 2020)
        #expect(viewModel.yearRangePreset == .twenties)
        #expect(viewModel.yearFilter == 2020)

        viewModel.applyYearRangePreset(nil)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        let afterClearCalls = await stub.getSearchCalls()
        #expect(afterClearCalls.count == 2)
        #expect(afterClearCalls[1].query == "dune")
        #expect(afterClearCalls[1].year == nil)
        #expect(viewModel.yearRangePreset == nil)
        #expect(viewModel.yearFilter == nil)
    }

    @Test
    @MainActor
    func applyYearRangePresetRecentDoesNotConstrainSearchApiYear() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.queryDraft = "  dune  "
        viewModel.applyYearRangePreset(.recent)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 1)
        #expect(calls[0].query == "dune")
        #expect(calls[0].year == nil)
        #expect(viewModel.yearRangePreset == .recent)
        #expect(viewModel.yearFilter == nil)
    }

    @Test
    @MainActor
    func applyYearRangePresetRecentKeepsGenreBrowseYearFilterUnset() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.yearFilter == nil)

        viewModel.applyYearRangePreset(.recent)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.count == 2)
        #expect(discoverCalls.last?.year == nil)
        #expect(viewModel.yearRangePreset == .recent)
        #expect(viewModel.yearFilter == nil)
    }

    @Test
    @MainActor
    func loadMoreForSpecialMoodCardPreservesDateWindowForSubsequentPages() async throws {
        let stub = MoodLoadMoreMetadataStub(resultByPage: [
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "special-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            2: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "special-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            )
        ])
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        viewModel.selectMoodCard(moodCard)

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }
        let initialFilters = await stub.getDiscoverFilters()
        #expect(initialFilters.count == 1)
        #expect(initialFilters[0].releaseDateGte == DiscoverFilters.dateString(daysFromNow: -90))
        #expect(initialFilters[0].releaseDateLte == DiscoverFilters.todayString())
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["special-page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        let filters = await stub.getDiscoverFilters()
        #expect(filters.count == 2)
        #expect(filters[1].page == 2)
        #expect(filters[1].releaseDateGte == initialFilters[0].releaseDateGte)
        #expect(filters[1].releaseDateLte == initialFilters[0].releaseDateLte)
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["special-page-1", "special-page-2"]
        }
    }

    @Test
    @MainActor
    func loadMoreGenreBrowseWhenSpecialMoodContextIsActivePreservesDateWindowOnSubsequentPages() async throws {
        let stub = MoodLoadMoreMetadataStub(resultByPage: [
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "special-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            2: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "special-genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            )
        ])
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        viewModel.selectMoodCard(moodCard)
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getDiscoverCallCount() == 1
        }

        let initialFilters = await stub.getDiscoverFilters()
        #expect(initialFilters.count == 1)
        #expect(initialFilters[0].genreId == nil)
        #expect(initialFilters[0].releaseDateGte == DiscoverFilters.dateString(daysFromNow: -90))
        #expect(initialFilters[0].releaseDateLte == DiscoverFilters.todayString())

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        let loadMoreFilters = await stub.getDiscoverFilters()
        #expect(loadMoreFilters.count == 2)
        #expect(loadMoreFilters[1].page == 2)
        #expect(loadMoreFilters[1].genreId == 28)
        #expect(loadMoreFilters[1].releaseDateGte == initialFilters[0].releaseDateGte)
        #expect(loadMoreFilters[1].releaseDateLte == initialFilters[0].releaseDateLte)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["special-page-1", "special-genre-page-2"])
    }

    @Test
    @MainActor
    func loadMoreSearchResultForStaleQueryContextIsDropped() async throws {
        let stub = SearchCaptureWithDelayMetadataStub(searchResultByPage: [
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "apollo-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            2: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "apollo-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            )
        ])
        await stub.setSearchDelay(.milliseconds(120), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["apollo-page-1"]
        }
        #expect(viewModel.currentPage == 1)

        viewModel.loadMore()
        viewModel.query = "other"

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        try await Task.sleep(for: .milliseconds(180))

        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["apollo-page-1"])
    }

    @Test
    @MainActor
    func loadMoreSearchInFlightResultIsDroppedAfterSearchRefresh() async throws {
        let stub = SearchCaptureWithDelayMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "apollo-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "apollo-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["apollo-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.currentPage == 2)

        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }

        #expect(await stub.getSearchCallCount() >= 3)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["apollo-page-1"])
    }

    @Test
    @MainActor
    func loadMoreSearchResultForStaleDraftIsDroppedWhileQueryRemains() async throws {
        let stub = SearchCaptureWithDelayMetadataStub(searchResultByPage: [
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "apollo-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            2: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "apollo-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            )
        ])
        await stub.setSearchDelay(.milliseconds(120), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["apollo-page-1"]
        }

        viewModel.loadMore()
        viewModel.queryDraft = "apollo 2"

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        try await Task.sleep(for: .milliseconds(180))

        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["apollo-page-1"])
    }

    @Test
    @MainActor
    func loadMoreGenreBrowseResultDoesNotAppendAfterSelectedGenreCleared() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(viewModel.currentPage == 2)

        viewModel.selectedGenre = nil
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func loadGenresIsDedupedPerTypeWhileRequestInFlight() async throws {
        let stub = GenreLoadDedupMetadataStub()
        await stub.setGenreLoadDelay(.milliseconds(200), for: .movie)
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Animation")], for: .series)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.loadGenres()
        await Task.yield()

        viewModel.loadGenres()
        try await Self.waitUntil {
            await stub.getGenresCallCount() == 1
        }

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            !viewModel.genres.isEmpty
        }

        #expect(await stub.getGenresCallCount() == 1)
        #expect(viewModel.genres.map(\.id) == [28])
    }

    @Test
    @MainActor
    func loadGenresForTypeChangeStartsNewRequestWhenCurrentTypeChanges() async throws {
        let stub = GenreLoadDedupMetadataStub()
        await stub.setGenreLoadDelay(.milliseconds(200), for: .movie)
        await stub.setGenreLoadDelay(.milliseconds(200), for: .series)
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Animation")], for: .series)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.loadGenres()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 1
        }
        #expect(viewModel.genres.map(\.id) == [28])

        viewModel.selectedType = .series
        viewModel.loadGenres()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 2
        }
        #expect(viewModel.selectedType == .series)
    }

    @Test
    @MainActor
    func staleGenreLoadInFlightForPreviousTypeDoesNotOverwriteCurrentGenreList() async throws {
        let stub = GenreLoadDedupMetadataStub()
        await stub.setGenreLoadDelay(.milliseconds(120), for: .movie)
        await stub.setGenreLoadDelay(.milliseconds(20), for: .series)
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Animation")], for: .series)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.loadGenres()
        await Task.yield()

        viewModel.selectedType = .series
        viewModel.loadGenres()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 2
        }
        #expect(viewModel.genres.map(\.id) == [16])

        try await Task.sleep(for: .milliseconds(180))
        #expect(viewModel.selectedType == .series)
        #expect(viewModel.genres.map(\.id) == [16])
    }

    @Test
    @MainActor
    func clearingQueryFromGenreSearchContextReenablesGenrePagination() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-query-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-browse-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-query-page-1"])

        viewModel.queryDraft = "   "
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-browse-page-1"])
        #expect(viewModel.currentPage == 1)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["genre-browse-page-1", "genre-browse-page-2"])
    }

    @Test
    @MainActor
    func staleGenreLoadMoreResultDoesNotOverwriteSearchWhenSearchRestarted() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(180), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["search-page-1"]
        }

        try await Task.sleep(for: .milliseconds(250))
        #expect(await stub.getSearchCallCount() == 1)
        #expect(await stub.getDiscoverCallCount() >= 2)
        #expect(!viewModel.results.contains(where: { $0.id == "genre-page-2" }))
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func browseGenrePassesExpectedFiltersForRegularGenreBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .series
        viewModel.sortOption = .ratingDesc
        viewModel.yearFilter = 2024
        viewModel.languageFilters = ["fr-FR"]

        viewModel.browseGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.count == 1)
        #expect(discoverCalls[0].genreId == 28)
        #expect(discoverCalls[0].page == 1)
        #expect(discoverCalls[0].year == 2024)
        #expect(discoverCalls[0].language == "fr-FR")
        #expect(discoverCalls[0].originalLanguage == "fr")
        #expect(discoverCalls[0].sort == .ratingDesc)
    }

    @Test
    @MainActor
    func genreLoadMoreTransientFailureCanBeRetried() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverFailure(page: 2, times: 1)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            viewModel.error != nil
        }
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            viewModel.currentPage == 2
        }
        #expect(await stub.getDiscoverCallCount() == 3)
        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["genre-page-1", "genre-page-2"])
    }

    @Test
    @MainActor
    func clearingQueryDraftPrioritizesGenreContextOverSpecialMoodCard() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "shared-page")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        let specialCalls = await stub.getDiscoverCalls()
        #expect(specialCalls[0].genreId == nil)
        #expect(specialCalls[0].sort == .releaseDateDesc)

        // Simulate a state where both a manual genre selection and a special mood card exist.
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = "apollo"
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.queryDraft = "   "

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.last?.genreId == 28)
        #expect(discoverCalls.last?.sort == .popularityDesc)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
    }

    @Test
    @MainActor
    func loadMoreWithoutSearchOrGenreContextDoesNothing() async throws {
        let stub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.currentPage = 1
        viewModel.totalPages = 2
        viewModel.query = ""
        viewModel.queryDraft = ""

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(120))

        #expect(await stub.getSearchCallCount() == 0)
        #expect(await stub.getDiscoverCallCount() == 0)
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func applyLanguageFiltersInGenreBrowseContextReissuesDiscoverWithUpdatedLanguage() async throws {
        let stub = MoodLoadMoreMetadataStub(resultByPage: [
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }

        let initialFilters = await stub.getDiscoverFilters()
        #expect(initialFilters[0].genreId == 28)
        #expect(initialFilters[0].language == nil)

        viewModel.applyLanguageFilters(["fr-FR"])
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        let filters = await stub.getDiscoverFilters()
        #expect(filters[1].genreId == 28)
        #expect(filters[1].language == "fr-FR")
        #expect(filters[1].page == 1)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
    }

    @Test
    @MainActor
    func applyYearRangePresetInGenreBrowseContextPassesMappedYearFilterToDiscover() async throws {
        let stub = MoodLoadMoreMetadataStub(resultByPage: [
            1: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        ])
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectGenre(Genre(id: 35, name: "Comedy"))
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.applyYearRangePreset(.tens)
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        let filters = await stub.getDiscoverFilters()
        #expect(filters[1].genreId == 35)
        #expect(filters[1].year == 2010)
    }

    @Test
    @MainActor
    func applyLanguageFiltersWithEquivalentNormalizedSetDoesNotRequerySearch() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        #expect(viewModel.languageFilters == ["en-US"])

        viewModel.applyLanguageFilters(["en-US", ""])
        // Empty filters are normalized away, so no state change should trigger requery.
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.languageFilters == ["en-US"])

        viewModel.applyLanguageFilters(["fr-FR", ""])
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 2)
        #expect(calls[1].language == "fr-FR")
        #expect(viewModel.languageFilters == ["fr-FR"])
    }

    @Test
    @MainActor
    func applyLanguageFiltersEmptySelectionResetsToDefaultLanguageAndRequeriesSearch() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.languageFilters = ["fr-FR"]
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(await stub.getSearchCalls() == [
            SearchQueryCaptureMetadataStub.SearchCall(query: "apollo", page: 1, year: nil, language: "fr-FR")
        ])

        viewModel.applyLanguageFilters([])
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(await stub.getSearchCalls() == [
            SearchQueryCaptureMetadataStub.SearchCall(query: "apollo", page: 1, year: nil, language: "fr-FR"),
            SearchQueryCaptureMetadataStub.SearchCall(query: "apollo", page: 1, year: nil, language: nil)
        ])
        #expect(viewModel.languageFilters == ["en-US"])
    }

    @Test
    @MainActor
    func toggleLanguageFromNonDefaultReturnsToDefaultLanguageAndRequeries() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.languageFilters = ["fr-FR"]
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(await stub.getSearchCalls() == [
            SearchQueryCaptureMetadataStub.SearchCall(query: "apollo", page: 1, year: nil, language: "fr-FR")
        ])
        #expect(viewModel.languageFilters == ["fr-FR"])

        viewModel.toggleLanguage("fr-FR")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(await stub.getSearchCalls() == [
            SearchQueryCaptureMetadataStub.SearchCall(query: "apollo", page: 1, year: nil, language: "fr-FR"),
            SearchQueryCaptureMetadataStub.SearchCall(query: "apollo", page: 1, year: nil, language: nil)
        ])
        #expect(viewModel.languageFilters == ["en-US"])
    }

    @Test
    @MainActor
    func applyLanguageFiltersInSearchContextForwardsPrimaryLanguageToSearch() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        viewModel.applyLanguageFilters(["fr-FR"])

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 1)
        #expect(calls[0].query == "apollo")
        #expect(calls[0].language == "fr-FR")
    }

    @Test
    @MainActor
    func applyLanguageFiltersToDefaultInGenreBrowseContextRemovesFilterAndRerunsBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }

        let firstFilters = await stub.getDiscoverCalls()
        #expect(firstFilters.count == 1)
        #expect(firstFilters[0].language == nil)

        viewModel.applyLanguageFilters(["fr-FR"])
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }
        let secondFilters = await stub.getDiscoverCalls()
        #expect(secondFilters[1].language == "fr-FR")

        viewModel.applyLanguageFilters([])
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 3
        }
        let thirdFilters = await stub.getDiscoverCalls()
        #expect(thirdFilters[2].language == nil)
        #expect(viewModel.languageFilters == ["en-US"])
    }

    @Test
    @MainActor
    func retryAfterSearchFailureRestoresSearchResults() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchFailure(page: 1, times: 1)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil {
            viewModel.error != nil
        }

        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.query == "apollo")

        viewModel.retry()
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getSearchCallCount() == 2
        }

        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
    }

    @Test
    @MainActor
    func sortChangeInGenreSearchContextKeepsPaginationInSearchMode() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
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
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1"])

        viewModel.applySortOption(.ratingDesc)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.sortOption == .ratingDesc)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }

        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["search-page-1", "search-page-2"])
    }

    @Test
    @MainActor
    func clearingSelectedGenreBeforeGenreLoadMoreResponsePreventsStaleAppend() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(180), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(viewModel.currentPage == 1)

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))
        viewModel.selectedGenre = nil

        try await Task.sleep(for: .milliseconds(220))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func loadMoreIsBlockedWhileInitialSearchIsInFlight() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setSearchDelay(.milliseconds(220), for: 1)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }
        #expect(await stub.getSearchCallCount() == 1)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func genreLoadMorePreservesOriginalLanguageForSingleNonEnglishLocale() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.languageFilters = ["fr-FR"]
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        viewModel.loadMore()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls[0].language == "fr-FR")
        #expect(discoverCalls[0].originalLanguage == "fr")
        #expect(discoverCalls[1].language == "fr-FR")
        #expect(discoverCalls[1].originalLanguage == "fr")
        #expect(discoverCalls[1].genreId == 28)
    }

    @Test
    @MainActor
    func searchLoadMoreFailureDoesNotBlockImmediateRetryWithCooldownReset() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
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
            ]
        )
        await stub.setSearchFailure(page: 2, times: 1)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(300))
        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            viewModel.currentPage == 2
        }

        #expect(await stub.getSearchCallCount() == 3)
        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["search-page-1", "search-page-2"])
    }

    @Test
    @MainActor
    func genreLoadMoreFailureDoesNotBlockImmediateRetryWithCooldownReset() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverFailure(page: 2, times: 1)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(300))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 1)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            viewModel.currentPage == 2
        }

        #expect(await stub.getDiscoverCallCount() == 3)
        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["genre-page-1", "genre-page-2"])
    }

    @Test
    @MainActor
    func loadMoreInEmptyContextShouldNotBlockImmediateSearchPaginationOnNextContext() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "next-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(300))
        viewModel.currentPage = 1
        viewModel.totalPages = 2

        #expect(await stub.getSearchCallCount() == 0)

        // No context means this should be a no-op and must not seed pagination cooldown
        // for a subsequent, real search-pagination request.
        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.currentPage == 1
        }

        viewModel.query = "apollo"
        viewModel.loadMore()

        // If the no-context call polluted pagination cooldown, this would remain 0 until
        // the cooldown window expires.
        try await Self.waitUntil(timeout: .milliseconds(120)) {
            await stub.getSearchCallCount() == 1
        }

        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.results.map(\.id) == ["next-search-page-2"])
    }

    @Test
    @MainActor
    func loadMoreSearchMustMatchCommittedQueryAndDraftBeforePaging() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
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
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1"])

        // Mutate the draft without committing a new query.
        // Pagination should require the committed query and draft to match.
        viewModel.queryDraft = "apollo-extended"
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(120))

        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
    }

    @Test
    @MainActor
    func loadMoreFromGenreSelectionHonorsCommittedQueryAndDraftBeforeReturningToBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-browse-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-search-page-1"])

        // Mutating draft only should not route to genre pagination while search is active.
        viewModel.queryDraft = "apollo-extended"
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(120))

        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.currentPage == 1)

        // Clearing the draft should restore genre browse context and allow pagination
        // through discover on the next request.
        viewModel.queryDraft = ""
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        #expect(viewModel.results.map(\.id) == ["genre-browse-page-1", "genre-browse-page-2"])
    }

    @Test
    @MainActor
    func loadMoreSearchRespectsMaxPageLimitAndStopsAtBoundary() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                500: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-500")],
                    page: 500,
                    totalPages: 600,
                    totalResults: 600
                ),
                501: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-501")],
                    page: 501,
                    totalPages: 600,
                    totalResults: 600
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.currentPage = 499
        viewModel.totalPages = 600

        #expect(viewModel.hasMore == true)
        viewModel.loadMore()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.currentPage == 500)
        #expect(viewModel.results.map(\.id) == ["search-page-500"])
        #expect(viewModel.hasMore == false)

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(120))

        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.currentPage == 500)
        #expect(viewModel.results.map(\.id) == ["search-page-500"])
    }

    @Test
    @MainActor
    func loadMoreSearchDeduplicatesOverlappingResultsUsingResultIdCache() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [
                        Fixtures.mediaPreview(id: "search-page-1"),
                        Fixtures.mediaPreview(id: "shared-page"),
                        Fixtures.mediaPreview(id: "search-page-1b")
                    ],
                    page: 1,
                    totalPages: 2,
                    totalResults: 3
                ),
                2: MetadataSearchResult(
                    items: [
                        Fixtures.mediaPreview(id: "shared-page"),
                        Fixtures.mediaPreview(id: "search-page-2"),
                        Fixtures.mediaPreview(id: "search-page-1b")
                    ],
                    page: 2,
                    totalPages: 2,
                    totalResults: 3
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1", "shared-page", "search-page-1b"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["search-page-1", "shared-page", "search-page-1b", "search-page-2"])
    }

    @Test
    @MainActor
    func loadMoreGenreBrowseRespectsMaxPageLimitAndStopsAtBoundary() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                500: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-browse-page-500")],
                    page: 500,
                    totalPages: 600,
                    totalResults: 600
                ),
                501: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-browse-page-501")],
                    page: 501,
                    totalPages: 600,
                    totalResults: 600
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.currentPage = 499
        viewModel.totalPages = 600

        #expect(viewModel.hasMore == true)
        #expect(viewModel.isGenreBrowsing == true)
        viewModel.loadMore()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.currentPage == 500)
        #expect(viewModel.results.map(\.id) == ["genre-browse-page-500"])
        #expect(viewModel.hasMore == false)

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(120))

        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.currentPage == 500)
        #expect(viewModel.results.map(\.id) == ["genre-browse-page-500"])
    }

    @Test
    @MainActor
    func replaceResultsResetsResultIdCacheBeforeApplyingSearch() async throws {
        let stub = SearchResultByQueryCaptureMetadataStub(
            searchResultByQuery: [
                "apollo": [
                    1: MetadataSearchResult(
                        items: [
                            Fixtures.mediaPreview(id: "shared-id"),
                            Fixtures.mediaPreview(id: "apollo-page-1")
                        ],
                        page: 1,
                        totalPages: 2,
                        totalResults: 3
                    ),
                    2: MetadataSearchResult(
                        items: [
                            Fixtures.mediaPreview(id: "apollo-page-2"),
                            Fixtures.mediaPreview(id: "shared-id")
                        ],
                        page: 2,
                        totalPages: 2,
                        totalResults: 3
                    )
                ],
                "dune": [
                    1: MetadataSearchResult(
                        items: [
                            Fixtures.mediaPreview(id: "shared-id"),
                            Fixtures.mediaPreview(id: "dune-page-1")
                        ],
                        page: 1,
                        totalPages: 2,
                        totalResults: 3
                    ),
                    2: MetadataSearchResult(
                        items: [
                            Fixtures.mediaPreview(id: "dune-page-2"),
                            Fixtures.mediaPreview(id: "shared-id")
                        ],
                        page: 2,
                        totalPages: 2,
                        totalResults: 3
                    )
                ]
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"

        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["shared-id", "apollo-page-1"])

        viewModel.search(queryText: "dune")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["shared-id", "dune-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }
        #expect(viewModel.results.map(\.id) == ["shared-id", "dune-page-1", "dune-page-2"])
    }

    @Test
    @MainActor
    func loadMoreGenreBrowseDeduplicatesOverlappingResultsUsingResultIdCache() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [
                        Fixtures.mediaPreview(id: "genre-page-1"),
                        Fixtures.mediaPreview(id: "shared-genre-page"),
                        Fixtures.mediaPreview(id: "genre-page-1b")
                    ],
                    page: 1,
                    totalPages: 2,
                    totalResults: 3
                ),
                2: MetadataSearchResult(
                    items: [
                        Fixtures.mediaPreview(id: "shared-genre-page"),
                        Fixtures.mediaPreview(id: "genre-page-2"),
                        Fixtures.mediaPreview(id: "genre-page-1b")
                    ],
                    page: 2,
                    totalPages: 2,
                    totalResults: 3
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedGenre = Genre(id: 28, name: "Action")

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1", "shared-genre-page", "genre-page-1b"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.results.map(\.id) == [
            "genre-page-1", "shared-genre-page", "genre-page-1b", "genre-page-2"
        ])
    }

    @Test
    @MainActor
    func applyFilterDraftNoopDoesNotReexecuteSearch() async {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        let draft = viewModel.currentFilterDraft
        #expect(await stub.getSearchCallCount() == 0)

        viewModel.applyFilterDraft(draft)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func applyFilterDraftNoopInSpecialMoodSearchContextDoesNotReexecuteSearchOrDiscover() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])
        #expect(viewModel.activeMoodCard?.id == specialCard.id)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])

        let draft = viewModel.currentFilterDraft
        let searchCallsBefore = await stub.getSearchCallCount()
        let discoverCallsBefore = await stub.getDiscoverCallCount()

        viewModel.applyFilterDraft(draft)
        #expect(await stub.getSearchCallCount() == searchCallsBefore)
        #expect(await stub.getDiscoverCallCount() == discoverCallsBefore)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
    }

    @Test
    @MainActor
    func applyFilterDraftInferredRecentYearTriggersSearchWithExpectedYearAndPreset() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        let draft = SearchFilterDraft(
            sortOption: .ratingDesc,
            selectedYear: 2025,
            selectedLanguages: ["fr-FR"],
            selectedGenre: nil
        )

        viewModel.applyFilterDraft(draft)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 1)
        #expect(calls[0].query == "apollo")
        #expect(calls[0].year == 2025)
        #expect(viewModel.sortOption == .ratingDesc)
        #expect(viewModel.yearFilter == 2025)
        #expect(viewModel.yearRangePreset == .recent)
        #expect(viewModel.languageFilters == ["fr-FR"])
    }

    @Test
    @MainActor
    func loadMoreSearchAtMaxPageLimitDoesNotIssueAnyRequest() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                500: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-500")],
                    page: 500,
                    totalPages: 600,
                    totalResults: 600
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.currentPage = 500
        viewModel.totalPages = 600

        #expect(viewModel.hasMore == false)
        viewModel.loadMore()

        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.currentPage == 500)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func loadMoreGenreBrowseAtMaxPageLimitDoesNotIssueAnyRequest() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                500: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-browse-page-500")],
                    page: 500,
                    totalPages: 600,
                    totalResults: 600
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.currentPage = 500
        viewModel.totalPages = 600

        #expect(viewModel.hasMore == false)
        viewModel.loadMore()

        #expect(await stub.getDiscoverCallCount() == 0)
        #expect(viewModel.currentPage == 500)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func configureEmptyApiKeyDoesNotClearInjectedMetadataService() async throws {
        let stub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.results.isEmpty == false)

        viewModel.configure(apiKey: "   ")
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")

        viewModel.search()
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func configureToNewKeyIsNoOpWhenMetadataServiceIsInjected() async throws {
        let injectedStub = SearchCountingMetadataStub()
        let factoryStub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(
            metadataService: injectedStub,
            metadataServiceFactory: { _ in
                factoryStub
            }
        )

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil {
            await injectedStub.getSearchCallCount() == 1
        }
        #expect(await injectedStub.getSearchCallCount() == 1)
        #expect(await factoryStub.getSearchCallCount() == 0)

        viewModel.configure(apiKey: "key-a")
        viewModel.search()
        try await Self.waitUntil {
            await injectedStub.getSearchCallCount() == 2
        }
        #expect(await injectedStub.getSearchCallCount() == 2)
        #expect(await factoryStub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func clearResetsSearchModeAndPreventsStaleSearchPagination() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
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
            ]
        )
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }

        viewModel.clear()
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.isEmpty)

        // If clear did not invalidate pagination context and request generation,
        // delayed page-2 response could append stale results after the clear.
        try await Task.sleep(for: .milliseconds(280))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.isEmpty)

        // Verify the view model is reusable for a fresh search after clear.
        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(await stub.getDiscoverCallCount() == 0)
    }

    @Test
    @MainActor
    func clearDuringGenreSearchModeCancelsInFlightPaginationAndPreservesFreshSearchesOnly() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.search(queryText: "apollo")

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-search-page-1"])
        #expect(viewModel.isGenreBrowsing == false)
        #expect(viewModel.currentPage == 1)

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.currentPage == 1)

        viewModel.clear()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        // If clear did not invalidate this pagination context, page-2 could append.
        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["genre-search-page-1"])
        #expect(await stub.getDiscoverCallCount() == 0)
    }

    @Test
    @MainActor
    func clearAllFiltersDuringGenreBrowsePaginationIgnoresStalePageAppend() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        viewModel.clearAllFilters()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)

        // Prevent delayed browse page-2 from reappearing after clear.
        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func clearAllFiltersDuringGenreBrowsePaginationFailureDoesNotLeakErrorAndAllowsFreshRetry() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 3,
                    totalResults: 3
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 3,
                    totalResults: 3
                )
            ]
        )
        await stub.setDiscoverFailure(page: 2, times: 1)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        viewModel.clearAllFilters()
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
        #expect(await stub.getSearchCallCount() == 0)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 3)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 4
            && viewModel.currentPage == 2
        }
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["genre-page-1", "genre-page-2"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func searchWithWhitespaceQueryDoesNotExecuteSearch() async throws {
        let stub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.search(queryText: "   ")
        #expect(viewModel.query == "")
        #expect(viewModel.queryDraft == "")
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func clearResetsSearchAttemptFlagsAndTextState() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.query = "  apollo  "
        viewModel.search()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.hasQueryText == true)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")

        viewModel.clear()
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.hasQueryText == false)
        #expect(viewModel.error == nil)
        #expect(viewModel.isSearching == false)
    }

    @Test
    @MainActor
    func assigningWhitespaceQueryWithoutContextClearsCommittedSearchState() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.hasQueryText == true)

        viewModel.query = "   "
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.hasQueryText == false)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func searchWhitespaceInGenreBrowseContextDoesNotSwitchToSearchPath() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.search(queryText: "   ")
        try await Task.sleep(for: .milliseconds(80))

        #expect(await stub.getSearchCallCount() == 0)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
    }

    @Test
    @MainActor
    func clearingQueryInSpecialMoodContextReissuesSpecialMoodBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "mood-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub)
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        let initialDiscover = await stub.getDiscoverCalls()
        #expect(initialDiscover.count == 1)
        #expect(initialDiscover[0].genreId == nil)
        #expect(initialDiscover[0].sort == .releaseDateDesc)
        #expect(viewModel.results.map(\.id) == ["mood-page-1"])

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")

        viewModel.queryDraft = ""
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        let afterClearDiscover = await stub.getDiscoverCalls()
        #expect(afterClearDiscover.count == 2)
        #expect(afterClearDiscover.last?.genreId == nil)
        #expect(afterClearDiscover.last?.sort == .releaseDateDesc)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.map(\.id) == ["mood-page-1"])
    }

    @Test
    @MainActor
    func searchWithWhitespaceQueryPreservesCommittedSearchState() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.hasQueryText == true)

        viewModel.search(queryText: "   ")
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.hasQueryText == true)
    }

    @Test
    @MainActor
    func clearCancelsPendingDebouncedSearch() async throws {
        let stub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(160),
            paginationCooldown: .milliseconds(0)
        )

        viewModel.queryDraft = "apollo"
        viewModel.debouncedSearch()

        // Debounce should schedule a search, but clear should cancel it before execution.
        viewModel.clear()
        try await Task.sleep(for: .milliseconds(220))

        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)
    }

    @Test
    @MainActor
    func clearCancelsPendingExplicitDebouncedSearch() async throws {
        let stub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(160),
            paginationCooldown: .milliseconds(0)
        )

        viewModel.debouncedSearch(queryText: "apollo")
        try await Task.sleep(for: .milliseconds(40))
        viewModel.clear()

        try await Task.sleep(for: .milliseconds(220))
        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.hasQueryText == false)
    }

    @Test
    @MainActor
    func debouncedSearchWithWhitespaceQueryDoesNotTriggerSearch() async throws {
        let stub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(120),
            paginationCooldown: .milliseconds(0)
        )

        viewModel.queryDraft = "   "
        viewModel.debouncedSearch()
        try await Task.sleep(for: .milliseconds(220))

        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.hasQueryText == false)
        #expect(viewModel.hasAttemptedTextSearch == false)
    }

    @Test
    @MainActor
    func mismatchQueryDraftAfterSearchFailureClearsAttemptStateAndError() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub()
        await stub.setSearchFailure(page: 1, times: 1)
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }

        #expect(viewModel.error != nil)
        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.hasQueryText == true)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")

        viewModel.queryDraft = "dune"
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "dune")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.error == nil)
        #expect(viewModel.hasQueryText == true)
    }

    @Test
    @MainActor
    func clearAllFiltersWithWhitespaceQueryAndSpecialMoodGenreContextFallsBackToSpecialMoodBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.queryDraft = "   "
        viewModel.clearAllFilters()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.count == 2)
        #expect(discoverCalls.last?.genreId == nil)
        #expect(discoverCalls.last?.sort == .releaseDateDesc)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.hasQueryText == false)
    }

    @Test
    @MainActor
    func clearAllFiltersWithWhitespaceQueryAndNoContextIssuingNoNetworkCall() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.queryDraft = "   "
        viewModel.clearAllFilters()

        try await Task.yield()
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.hasQueryText == false)
        #expect(await stub.getSearchCallCount() == 0)
        #expect(await stub.getDiscoverCallCount() == 0)
    }

    @Test
    @MainActor
    func requeryFromSpecialMoodContextWithEmptyDraftReloadsSpecialMoodDiscover() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)

        viewModel.requery()
        try await Self.waitUntil(timeout: .milliseconds(1200)) {
            await stub.getDiscoverCallCount() == 2
        }

        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.count == 2)
        #expect(discoverCalls[1].genreId == nil)
        #expect(discoverCalls[1].sort == .releaseDateDesc)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func requeryFromSpecialMoodContextWithTrimmedQueryReissuesSearchAndKeepsSearchPaginationPath() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(
            metadataService: stub,
            paginationCooldown: .milliseconds(0)
        )

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        let discoverCallsBefore = await stub.getDiscoverCallCount()
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.queryDraft = "  apollo  "
        let searchCallsBefore = await stub.getSearchCallCount()
        viewModel.requery()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == searchCallsBefore + 1
        }
        let calls = await stub.getSearchCalls()
        #expect(calls.count == 1)
        #expect(calls[0].query == "apollo")
        #expect(calls[0].page == 1)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])
        #expect(await stub.getDiscoverCallCount() == discoverCallsBefore)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == searchCallsBefore + 2
            && viewModel.currentPage == 2
            && viewModel.results.map(\.id) == ["special-search-page-1", "special-search-page-2"]
        }
        #expect(await stub.getDiscoverCallCount() == discoverCallsBefore)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.totalPages == 2)
        #expect(viewModel.results.map(\.id) == ["special-search-page-1", "special-search-page-2"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func requeryFromSpecialMoodContextWithManualGenreAndNonEmptyQueryPreservesSearchPath() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.queryDraft = "  apollo  "
        let searchCallsBefore = await stub.getSearchCallCount()
        viewModel.requery()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            let searchCallCount = await stub.getSearchCallCount()
            let discoverCallCount = await stub.getDiscoverCallCount()
            return searchCallCount == searchCallsBefore + 1
                && discoverCallCount == 1
        }
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])
    }

    @Test
    @MainActor
    func requeryFromSpecialMoodContextWithManualGenreAndEmptyDraftUsesGenreContextBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 2,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)

        let discoverBefore = await stub.getDiscoverCallCount()
        let searchBefore = await stub.getSearchCallCount()
        viewModel.requery()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            let discoverCallCount = await stub.getDiscoverCallCount()
            let searchCallCount = await stub.getSearchCallCount()
            return discoverCallCount == discoverBefore + 1
                && searchCallCount == searchBefore
        }

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
    }

    @Test
    @MainActor
    func requeryFromGenreContextWithEmptyDraftKeepsGenreBrowse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)
        let genre = Genre(id: 28, name: "Action")

        viewModel.selectGenre(genre)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        let discoverBefore = await stub.getDiscoverCallCount()
        let searchBefore = await stub.getSearchCallCount()
        viewModel.requery()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            let discoverCallCount = await stub.getDiscoverCallCount()
            let searchCallCount = await stub.getSearchCallCount()
            return discoverCallCount == discoverBefore + 1
                && searchCallCount == searchBefore
        }

        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
    }

    @Test
    @MainActor
    func requeryFromGenreContextWithNonEmptyQueryKeepsSearchPaginationPath() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
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
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(
            metadataService: stub,
            paginationCooldown: .milliseconds(0)
        )
        let genre = Genre(id: 28, name: "Action")

        viewModel.selectGenre(genre)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        let discoverBefore = await stub.getDiscoverCallCount()
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.queryDraft = "  apollo  "
        viewModel.requery()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            let searchCallCount = await stub.getSearchCallCount()
            let discoverCallCount = await stub.getDiscoverCallCount()
            return searchCallCount == 1
                && discoverCallCount == discoverBefore
        }

        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
            && viewModel.currentPage == 2
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1", "search-page-2"])
        #expect(await stub.getDiscoverCallCount() == discoverBefore)
    }

    @Test
    @MainActor
    func requeryFromNoContextWithEmptyDraftDoesNothing() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        let discoverCountBefore = await stub.getDiscoverCallCount()
        let searchCountBefore = await stub.getSearchCallCount()

        viewModel.requery()

        #expect(await stub.getDiscoverCallCount() == discoverCountBefore)
        #expect(await stub.getSearchCallCount() == searchCountBefore)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
    }

    @Test
    @MainActor
    func requeryFromNoContextWithNonEmptyDraftStartsSearch() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.queryDraft = "  apollo  "
        let searchCallsBefore = await stub.getSearchCallCount()

        viewModel.requery()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == searchCallsBefore + 1
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 1)
        #expect(calls[0].query == "apollo")
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersWithGenreSelectionAndWhitespaceQueryOnlyClearsGenreContext() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub)
        let genre = Genre(id: 28, name: "Action")

        viewModel.selectGenre(genre)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.selectedGenre = genre
        viewModel.queryDraft = "   "
        viewModel.clearAllFilters()

        try await Task.sleep(for: .milliseconds(120))
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft == "   ")
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.hasQueryText == false)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func debouncedSearchWithExplicitWhitespaceQueryTextDoesNotTouchStateOrTriggerSearch() async throws {
        let stub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(120),
            paginationCooldown: .milliseconds(0)
        )

        viewModel.queryDraft = "apollo"
        viewModel.debouncedSearch(queryText: "   ")
        try await Task.sleep(for: .milliseconds(220))

        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.hasQueryText == true)
    }

    @Test
    @MainActor
    func whitespaceQueryDraftAfterCommittedSearchClearsCommittedQueryContext() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }

        #expect(viewModel.query == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.hasQueryText == true)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])

        viewModel.queryDraft = "   "
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.hasQueryText == false)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func nonWhitespaceQueryDraftMismatchResetsAttemptStateButPreservesResultSet() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }

        #expect(viewModel.query == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.hasQueryText == true)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])

        viewModel.queryDraft = "apollo 2"
        #expect(viewModel.query == "apollo")
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.hasQueryText == true)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
        #expect(viewModel.error == nil)
        #expect(viewModel.queryDraft == "apollo 2")
    }

    @Test
    @MainActor
    func applyYearFilterLocallyFiltersWhenTypeIsNilAndDropsUnknownYearEntries() async throws {
        let stub = SearchYearFilterCaptureMetadataStub(
            searchResult: MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "result-2024", year: 2024),
                    Fixtures.mediaPreview(id: "result-2023", year: 2023),
                    Fixtures.mediaPreview(id: "result-unknown", year: nil),
                ],
                page: 1,
                totalPages: 1,
                totalResults: 3
            )
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "apollo"

        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.selectedType == nil)
        #expect(viewModel.results.map(\.id) == ["result-2024", "result-2023", "result-unknown"])

        viewModel.applyYearFilter(2024)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        #expect(await stub.getSearchCalls() == [nil, 2024])
        #expect(viewModel.results.map(\.id) == ["result-2024"])
    }

    @Test
    @MainActor
    func applyYearFilterNilAfterYearFilterClearsYearConstraintAndRequeries() async throws {
        let stub = SearchYearFilterCaptureMetadataStub(
            searchResult: MetadataSearchResult(
                items: [
                    Fixtures.mediaPreview(id: "result-2024", year: 2024),
                    Fixtures.mediaPreview(id: "result-2023", year: 2023),
                    Fixtures.mediaPreview(id: "result-unknown", year: nil),
                ],
                page: 1,
                totalPages: 1,
                totalResults: 3
            )
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "apollo"

        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        viewModel.applyYearFilter(2024)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        viewModel.applyYearFilter(nil)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }

        #expect(await stub.getSearchCalls() == [nil, 2024, nil])
        #expect(viewModel.yearFilter == nil)
    }

    @Test
    @MainActor
    func applyYearFilterLeavesResultShapeUntouchedWhenTypeIsSpecified() async throws {
        let result = MetadataSearchResult(
            items: [
                Fixtures.mediaPreview(id: "result-2024", year: 2024),
                Fixtures.mediaPreview(id: "result-2023", year: 2023),
                Fixtures.mediaPreview(id: "result-unknown", year: nil),
            ],
            page: 1,
            totalPages: 1,
            totalResults: 3
        )
        let stub = SearchYearFilterCaptureMetadataStub(searchResult: result)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .movie
        viewModel.query = "apollo"

        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results == result.items)

        viewModel.applyYearFilter(2024)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        #expect(await stub.getSearchCalls() == [nil, 2024])
        #expect(viewModel.yearFilter == 2024)
        #expect(viewModel.results.map(\.id) == ["result-2024", "result-2023", "result-unknown"])
    }

    @Test
    @MainActor
    func explicitDebouncedQueryTextTriggersTrimmedSearchAndStateSync() async throws {
        let stub = SearchCountingMetadataStub()
        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(120),
            paginationCooldown: .milliseconds(0)
        )

        viewModel.queryDraft = "  stale  "
        viewModel.debouncedSearch(queryText: "   dune  ")

        try await Self.waitUntil(timeout: .milliseconds(500)) {
            await stub.getSearchCallCount() == 1
        }

        #expect(viewModel.query == "dune")
        #expect(viewModel.queryDraft == "dune")
        #expect(viewModel.submittedQuery == "dune")
        #expect(viewModel.hasQueryText == true)
        #expect(viewModel.hasAttemptedTextSearch == true)
    }

    @Test
    @MainActor
    func debouncedSearchWithoutConfiguredMetadataServiceShowsSetupErrorWithoutMutatingQuery() async throws {
        let viewModel = SearchViewModel()
        viewModel.query = "apollo"
        viewModel.queryDraft = "apollo"

        viewModel.debouncedSearch(queryText: "dune")
        try await Task.sleep(for: .milliseconds(220))

        #expect(viewModel.error == .tmdbSetupRequired(feature: "Search"))
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.submittedQuery.isEmpty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.hasAttemptedTextSearch == false)
    }

    @Test
    @MainActor
    func searchWithoutConfiguredMetadataServiceShowsSetupErrorAndCommitsTrimmedQueryState() async throws {
        let viewModel = SearchViewModel()
        viewModel.search(queryText: "   dune  ")

        #expect(viewModel.error == .tmdbSetupRequired(feature: "Search"))
        #expect(viewModel.query == "dune")
        #expect(viewModel.queryDraft == "dune")
        #expect(viewModel.submittedQuery == "dune")
        #expect(viewModel.hasAttemptedTextSearch == true)
        #expect(viewModel.hasQueryText == true)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func debouncedSearchForOlderQueryIsDroppedWhenNewQueryOverridesIt() async throws {
        let stub = SearchResultByQueryCaptureMetadataStub(
            searchResultByQuery: [
                "apollo": [
                    1: MetadataSearchResult(
                        items: [Fixtures.mediaPreview(id: "apollo-page-1")],
                        page: 1,
                        totalPages: 1,
                        totalResults: 1
                    )
                ],
                "dune": [
                    1: MetadataSearchResult(
                        items: [Fixtures.mediaPreview(id: "dune-page-1")],
                        page: 1,
                        totalPages: 1,
                        totalResults: 1
                    )
                ]
            ]
        )
        await stub.setSearchDelay(.milliseconds(220), for: "apollo")
        await stub.setSearchDelay(.milliseconds(40), for: "dune")

        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(60),
            paginationCooldown: .milliseconds(0)
        )

        viewModel.debouncedSearch(queryText: "apollo")
        try await Task.sleep(for: .milliseconds(90))
        viewModel.debouncedSearch(queryText: "dune")

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(await stub.getSearchCalls().map(\.query) == ["apollo", "dune"])
        #expect(viewModel.results.map(\.id) == ["dune-page-1"])
        #expect(viewModel.query == "dune")
        #expect(viewModel.queryDraft == "dune")
        #expect(viewModel.submittedQuery == "dune")
    }


    @Test
    @MainActor
    func clearResetsFilterDefaultsAndSearchStateForFreshReuse() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.sortOption = .ratingDesc
        viewModel.yearFilter = 2025
        viewModel.yearRangePreset = .twenties
        viewModel.languageFilters = ["fr-FR", "es-ES"]
        viewModel.query = "apollo"

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1"])

        viewModel.clear()
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.yearFilter == nil)
        #expect(viewModel.yearRangePreset == nil)
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.submittedQuery == "")
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.hasAttemptedTextSearch == false)
        #expect(viewModel.hasQueryText == false)
        #expect(viewModel.isLoadingMore == false)

        #expect(await stub.getSearchCallCount() == 1)
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.sortOption == .popularityDesc)
        #expect(viewModel.yearFilter == nil)
        #expect(viewModel.yearRangePreset == nil)
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
    }

    @Test
    @MainActor
    func loadMoreInSpecialMoodSkipsWhenDraftChangesAndResumesSpecialMoodPaginationAfterClear() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])

        viewModel.queryDraft = "apollo-2"
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(120))

        #expect(await stub.getSearchCallCount() == 1)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.currentPage == 1)

        viewModel.queryDraft = ""
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
        }
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1", "special-browse-page-2"])
    }

    @Test
    @MainActor
    func applyLanguageFiltersWithMultipleSelectionsUsesPriorityLanguageInSearch() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        viewModel.applyLanguageFilters(["de-DE", "fr-FR", "es-ES"])

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 1)
        #expect(calls[0].language == "es-ES")
        #expect(viewModel.languageFilters == ["de-DE", "es-ES", "fr-FR"])
    }

    @Test
    @MainActor
    func toggleLanguageDefaultAfterMultiSelectResetsToDefaultAndRequeriesSearch() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        viewModel.applyLanguageFilters(["fr-FR", "es-ES"])
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        let firstCall = (await stub.getSearchCalls())[0]
        #expect(firstCall.language == "es-ES")

        viewModel.toggleLanguage("en-US")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        let allCalls = await stub.getSearchCalls()
        #expect(allCalls.count == 2)
        #expect(allCalls[1].language == nil)
        #expect(viewModel.languageFilters == ["en-US"])
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromSpecialMoodWithNoCachedGenresKeepsSpecialMoodBrowse() async throws {
        let stub = GenreAwareMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        let discoverCountBeforeTypeChange = await stub.getDiscoverCallCount()
        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == discoverCountBeforeTypeChange + 1
        }

        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.map(\.id) == ["special-page-1"])
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromRegularMoodWithNoCachedGenresReexecutesRegularGenreBrowse() async throws {
        let stub = GenreAwareMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let regularCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(regularCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        let originalGenreId = viewModel.selectedGenre?.id
        #expect(originalGenreId == regularCard.movieGenreId)

        let discoverCountBeforeTypeChange = await stub.getDiscoverCallCount()
        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == discoverCountBeforeTypeChange + 1
        }

        #expect(viewModel.activeMoodCard?.id == regularCard.id)
        #expect(viewModel.selectedGenre?.id == regularCard.tvGenreId)
        #expect(viewModel.selectedGenre?.name == regularCard.title)
        #expect(viewModel.results.map(\.id) == ["regular-page-1"])
    }

    @Test
    @MainActor
    func applyLanguageFiltersUnknownSelectionUsesUnknownAsPrimaryLanguage() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        viewModel.applyLanguageFilters(["xx-XX"])

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 1)
        #expect(calls[0].language == "xx-XX")
        #expect(viewModel.languageFilters == ["xx-XX"])
    }

    @Test
    @MainActor
    func toggleUnknownLanguageFromDefaultSelectsUnknownAndRequeries() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        #expect(await stub.getSearchCalls()[0].language == nil)

        viewModel.toggleLanguage("xx-XX")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 2)
        #expect(calls[1].language == "xx-XX")
        #expect(viewModel.languageFilters == ["xx-XX"])
    }

    @Test
    @MainActor
    func applyLanguageFiltersWithDefaultAndUnknownStillPrefersKnownNonDefaultForSearch() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        viewModel.applyLanguageFilters(["en-US", "xx-XX", "fr-FR"])

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 1)
        #expect(calls[0].language == "fr-FR")
    }

    @Test
    @MainActor
    func toggleUnknownLanguageFromMultiSelectRemovesOnlyTargetLanguage() async throws {
        let stub = SearchQueryCaptureMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(await stub.getSearchCalls()[0].language == nil)

        viewModel.applyLanguageFilters(["fr-FR", "xx-XX"])
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(await stub.getSearchCalls()[1].language == "fr-FR")
        #expect(viewModel.languageFilters == ["fr-FR", "xx-XX"])

        viewModel.toggleLanguage("xx-XX")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }

        let calls = await stub.getSearchCalls()
        #expect(calls.count == 3)
        #expect(calls[2].language == "fr-FR")
        #expect(viewModel.languageFilters == ["fr-FR"])
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromSpecialMoodWithActiveQueryKeepsSearchModeForMissingGenreCache() async throws {
        let stub = GenreAwareMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])

        let discoverCallCountBeforeTypeChange = await stub.getDiscoverCallCount()
        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(await stub.getSearchCallCount() == 2)
        #expect(await stub.getDiscoverCallCount() == discoverCallCountBeforeTypeChange)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])
    }

    @Test
    @MainActor
    func applyLanguageFiltersInSpecialMoodContextReissuesSpecialMoodDiscoverWithLanguage() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        let discoverCallsBefore = await stub.getDiscoverCalls()
        #expect(discoverCallsBefore[0].genreId == nil)
        #expect(discoverCallsBefore[0].language == nil)

        viewModel.applyLanguageFilters(["fr-FR"])
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        let discoverCallsAfter = await stub.getDiscoverCalls()
        #expect(discoverCallsAfter.count == 2)
        #expect(discoverCallsAfter[1].genreId == nil)
        #expect(discoverCallsAfter[1].language == "fr-FR")
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])
    }

    @Test
    @MainActor
    func loadGenresTypeChangeWhileRequestInflightKeepsNewestTypeGenresInResults() async throws {
        let stub = GenreLoadDedupMetadataStub()
        await stub.setGenreLoadDelay(.milliseconds(240), for: .movie)
        await stub.setGenreLoadDelay(.milliseconds(80), for: .series)
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Animation")], for: .series)

        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.loadGenres()
        await Task.yield()
        viewModel.selectedType = .series
        viewModel.loadGenres()

        try await Self.waitUntil {
            await stub.getGenresCallCount() == 2
        }
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            !viewModel.genres.isEmpty
        }

        #expect(viewModel.genres.map(\.id) == [16])

        let callCountAfterLoad = await stub.getGenresCallCount()
        viewModel.loadGenres()

        try await Self.waitUntil(timeout: .milliseconds(500)) {
            await stub.getGenresCallCount() == callCountAfterLoad
        }
        #expect(await stub.getGenresCallCount() == callCountAfterLoad)
    }

    @Test
    @MainActor
    func applyLanguageFiltersInSpecialMoodSearchContextReissuesSearchAndResetsToDefault() async throws {
        let stub = GenreAwareMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(specialCard)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        let initialSearchCalls = await stub.getSearchCalls()
        #expect(initialSearchCalls.count == 1)
        #expect(initialSearchCalls[0].language == nil)

        viewModel.applyLanguageFilters(["fr-FR"])
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        let languageFilteredSearchCalls = await stub.getSearchCalls()
        #expect(languageFilteredSearchCalls.count == 2)
        #expect(languageFilteredSearchCalls[1].language == "fr-FR")
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.applyLanguageFilters([])
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }

        let resetLanguageSearchCalls = await stub.getSearchCalls()
        #expect(resetLanguageSearchCalls.count == 3)
        #expect(resetLanguageSearchCalls[2].language == nil)
        #expect(viewModel.languageFilters == ["en-US"])
    }

    @Test
    @MainActor
    func toggleLanguageInSpecialMoodSearchContextPreservesSpecialMoodAndSearchContext() async throws {
        let stub = GenreAwareMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(specialCard)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)

        viewModel.toggleLanguage("fr-FR")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.languageFilters == ["fr-FR"])

        viewModel.toggleLanguage("fr-FR")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }

        let searchCalls = await stub.getSearchCalls()
        #expect(searchCalls.count == 3)
        #expect(searchCalls[0].language == nil)
        #expect(searchCalls[1].language == "fr-FR")
        #expect(searchCalls[2].language == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.isGenreBrowsing == false)
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func applyLanguageFiltersInSpecialMoodBrowseContextReissuesSpecialMoodDiscoverWithLanguageAndDefault() async throws {
        let stub = GenreAwareMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)

        viewModel.applyLanguageFilters(["fr-FR"])
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        let discoverCallsWithLanguage = await stub.getDiscoverCalls()
        #expect(discoverCallsWithLanguage.count == 2)
        #expect(discoverCallsWithLanguage[1].genreId == nil)
        #expect(discoverCallsWithLanguage[1].language == "fr-FR")

        viewModel.applyLanguageFilters([])
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
        }

        let discoverCallsReset = await stub.getDiscoverCalls()
        #expect(discoverCallsReset.count == 3)
        #expect(discoverCallsReset[2].genreId == nil)
        #expect(discoverCallsReset[2].language == nil)
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func toggleLanguageInSpecialMoodBrowseContextPreservesMoodAndReissuesDiscover() async throws {
        let stub = GenreAwareMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(await stub.getSearchCallCount() == 0)

        viewModel.toggleLanguage("fr-FR")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.count == 2)
        #expect(discoverCalls[1].language == "fr-FR")
        #expect(discoverCalls[1].genreId == nil)
        #expect(viewModel.languageFilters == ["fr-FR"])
        #expect(viewModel.activeMoodCard?.id == specialCard.id)

        viewModel.toggleLanguage("fr-FR")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
        }

        let discoverCallsAfterReset = await stub.getDiscoverCalls()
        #expect(discoverCallsAfterReset.count == 3)
        #expect(discoverCallsAfterReset[2].language == nil)
        #expect(discoverCallsAfterReset[2].genreId == nil)
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromSpecialMoodSearchWithGenreSelectionKeepsSearchMode() async throws {
        let stub = GenreAwareMetadataStub(
            genresByType: [
                .movie: [Genre(id: 28, name: "Action")],
                .series: [Genre(id: 28, name: "Action"), Genre(id: 16, name: "Animation")]
            ],
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.selectedType = .series
        let discoverCallsBefore = await stub.getDiscoverCallCount()
        let searchCallsBefore = await stub.getSearchCallCount()

        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            let searchCallCount = await stub.getSearchCallCount()
            let discoverCallCount = await stub.getDiscoverCallCount()
            return searchCallCount == searchCallsBefore + 1
                && discoverCallCount == discoverCallsBefore
        }

        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(await stub.getSearchCallCount() == searchCallsBefore + 1)
        #expect(await stub.getDiscoverCallCount() == discoverCallsBefore)
    }

    @Test
    @MainActor
    func applyFilterDraftInSpecialMoodSearchContextForwardsSearchAndPreservesSpecialMood() async throws {
        let stub = GenreAwareMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        let draft = SearchFilterDraft(
            sortOption: .ratingDesc,
            selectedYear: 2025,
            selectedLanguages: ["fr-FR"],
            selectedGenre: nil
        )
        let searchCountBefore = await stub.getSearchCallCount()
        let discoverCountBefore = await stub.getDiscoverCallCount()
        viewModel.applyFilterDraft(draft)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == searchCountBefore + 1
        }
        let searchCalls = await stub.getSearchCalls()
        #expect(searchCalls.count == 2)
        #expect(searchCalls[1].year == 2025)
        #expect(searchCalls[1].language == "fr-FR")
        #expect(searchCalls[1].query == "apollo")
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.sortOption == .ratingDesc)
        #expect(viewModel.yearFilter == 2025)
        #expect(viewModel.languageFilters == ["fr-FR"])
        #expect(await stub.getDiscoverCallCount() == discoverCountBefore)
    }

    @Test
    @MainActor
    func applyFilterDraftWithGenreFromSpecialMoodSearchForwardsToGenreBrowseAndClearsMoodContext() async throws {
        let stub = GenreAwareMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-2")],
                    page: 2,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        let draft = SearchFilterDraft(
            sortOption: .releaseDateDesc,
            selectedYear: 2010,
            selectedLanguages: ["fr-FR"],
            selectedGenre: Genre(id: 28, name: "Action")
        )
        let searchCountBefore = await stub.getSearchCallCount()
        let discoverCountBefore = await stub.getDiscoverCallCount()
        viewModel.applyFilterDraft(draft)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            let discoverCallCount = await stub.getDiscoverCallCount()
            let searchCallCount = await stub.getSearchCallCount()
            return discoverCallCount == discoverCountBefore + 1
                && searchCallCount == searchCountBefore
        }

        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.sortOption == .releaseDateDesc)
        #expect(viewModel.yearFilter == 2010)
        #expect(viewModel.languageFilters == ["fr-FR"])
        #expect(await stub.getSearchCallCount() == searchCountBefore)
        #expect(await stub.getDiscoverCallCount() == discoverCountBefore + 1)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])
    }

    @Test
    @MainActor
    func applyFilterDraftWithGenreClearedInSpecialMoodSearchReissuesSearchAndPreservesMood() async throws {
        let stub = GenreAwareMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        viewModel.selectedGenre = Genre(id: 28, name: "Action")

        let draft = SearchFilterDraft(
            sortOption: .popularityDesc,
            selectedYear: nil,
            selectedLanguages: ["fr-FR"],
            selectedGenre: nil
        )
        let searchCountBefore = await stub.getSearchCallCount()
        let discoverCountBefore = await stub.getDiscoverCallCount()

        viewModel.applyFilterDraft(draft)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            let searchCallCount = await stub.getSearchCallCount()
            let discoverCallCount = await stub.getDiscoverCallCount()
            return searchCallCount == searchCountBefore + 1
                && discoverCallCount == discoverCountBefore
        }

        let searchCalls = await stub.getSearchCalls()
        #expect(searchCalls.count == 2)
        #expect(searchCalls[1].query == "apollo")
        #expect(searchCalls[1].language == "fr-FR")
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])
    }

    @Test
    @MainActor
    func clearDuringSpecialMoodSearchModeCancelsInFlightPaginationAndAllowsFreshReseek() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        viewModel.clear()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)

        // Guard against stale page-2 response appending after clear.
        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }

        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])
    }

    @Test
    @MainActor
    func clearDuringSpecialMoodSearchModeFailureDoesNotLeakErrorAndAllowsFreshReseek() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchFailure(page: 2, times: 1)
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        viewModel.clear()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        // Guard against stale failed page-2 response appending after clear.
        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 2)
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func clearDuringSpecialMoodBrowseModeCancelsInFlightPaginationAndAllowsFreshReseek() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        viewModel.clear()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)

        // If clear did not invalidate the special-mood browse pagination generation, page-2 could append.
        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 4
        }
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1", "special-browse-page-2"])
    }

    @Test
    @MainActor
    func clearDuringRegularMoodSearchModeCancelsInFlightPaginationAndAllowsFreshReseek() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == regularMoodCard.id)
        #expect(viewModel.selectedGenre != nil)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["regular-search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        viewModel.clear()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        // Guard against stale page-2 response appending after clear.
        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["regular-search-page-1"])
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func clearDuringRegularMoodSearchModeFailureDoesNotLeakErrorAndAllowsFreshReseek() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "regular-mood-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchFailure(page: 2, times: 1)
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let regularMoodCard = ExploreGenreCatalog.cards.first(where: { !$0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(regularMoodCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == regularMoodCard.id)
        #expect(viewModel.selectedGenre != nil)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["regular-search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        viewModel.clear()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        // Guard against stale failed page-2 response appending after clear.
        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.error == nil)

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["regular-search-page-1"])
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func clearDuringSpecialMoodSearchModeFailureAllowsTransitionToRegularGenreBrowseWithoutLeak() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setSearchFailure(page: 2, times: 1)
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        viewModel.clear()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-browse-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-browse-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.count == 2)
        #expect(discoverCalls[1].genreId == 28)
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.results.map(\.id) == ["genre-browse-page-1"])
        #expect(viewModel.error == nil)

        // Ensure failed special search page-2 does not reappear after transition.
        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["genre-browse-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
                && viewModel.currentPage == 2
        }
        #expect(viewModel.results.map(\.id) == ["genre-browse-page-1", "genre-browse-page-2"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersDuringSpecialMoodBrowsePaginationKeepsMoodContextFresh() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        viewModel.clearAllFilters()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 3)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 4
            && viewModel.currentPage == 2
        }
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1", "special-browse-page-2"])
    }

    @Test
    @MainActor
    func clearAllFiltersDuringSpecialMoodBrowsePaginationFailureDoesNotLeakErrorAndAllowsFreshRetry() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 3,
                    totalResults: 3
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-2")],
                    page: 2,
                    totalPages: 3,
                    totalResults: 3
                )
            ]
        )
        await stub.setDiscoverFailure(page: 2, times: 1)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        viewModel.clearAllFilters()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 3)
        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 4
        }
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1", "special-browse-page-2"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersDuringSpecialMoodSearchPaginationFailureDoesNotLeakErrorAndAllowsFreshRetry() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-1")],
                    page: 1,
                    totalPages: 3,
                    totalResults: 3
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-search-page-2")],
                    page: 2,
                    totalPages: 3,
                    totalResults: 3
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "special-browse-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchFailure(page: 2, times: 1)
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let specialCard = ExploreGenreCatalog.cards.first(where: { $0.isSpecialCard })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectMoodCard(specialCard)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.results.map(\.id) == ["special-browse-page-1"])

        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        viewModel.clearAllFilters()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }
        #expect(viewModel.activeMoodCard?.id == specialCard.id)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.totalPages == 3)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["special-search-page-1"])
        #expect(viewModel.error == nil)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 3)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 3)
        #expect(viewModel.error == nil)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 4
            && viewModel.currentPage == 2
        }
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["special-search-page-1", "special-search-page-2"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersDuringRegularSearchPaginationFailureDoesNotLeakErrorAndAllowsFreshRetry() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 3,
                    totalResults: 3
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-2")],
                    page: 2,
                    totalPages: 3,
                    totalResults: 3
                )
            ]
        )
        await stub.setSearchFailure(page: 2, times: 1)
        await stub.setSearchDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
            && viewModel.results.map(\.id) == ["search-page-1"]
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 3)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 2
        }

        viewModel.clearAllFilters()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 3
        }
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 3)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 3)
        #expect(viewModel.error == nil)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 4
            && viewModel.currentPage == 2
        }
        #expect(viewModel.results.map(\.id) == ["search-page-1", "search-page-2"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func clearDuringRegularGenreBrowsePaginationDropsStalePageAndAllowsCleanRequery() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 2,
                    totalResults: 2
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 2,
                    totalResults: 2
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        viewModel.clear()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        // If clear failed to invalidate the browse pagination generation, page-2 would append.
        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
    }

    @Test
    @MainActor
    func clearDuringGenreBrowsePaginationFailureDoesNotLeakErrorAndAllowsFreshRetry() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 3,
                    totalResults: 3
                ),
                2: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-2")],
                    page: 2,
                    totalPages: 3,
                    totalResults: 3
                )
            ]
        )
        await stub.setDiscoverFailure(page: 2, times: 1)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(viewModel.currentPage == 1)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }

        viewModel.clear()
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        // If clear did not invalidate the browse pagination generation, page-2 failure/result could leak.
        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 3
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 3)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(viewModel.error == nil)

        viewModel.loadMore()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 4
            && viewModel.currentPage == 2
        }
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["genre-page-1", "genre-page-2"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func browseGenreCancelsInFlightSearchBeforeShowingGenreResults() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setSearchDelay(.milliseconds(220), for: 1)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedType == nil)

        viewModel.browseGenre(Genre(id: 28, name: "Action"))
        #expect(viewModel.selectedGenre?.id == 28)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
    }

    @Test
    @MainActor
    func browseGenreWithNoMetadataServiceSurfacesSetupError() {
        let viewModel = SearchViewModel()
        viewModel.query = "apollo"
        viewModel.queryDraft = "apollo"
        viewModel.search()

        viewModel.browseGenre(Genre(id: 28, name: "Action"))

        #expect(viewModel.error == .tmdbSetupRequired(feature: "Search"))
        #expect(viewModel.isSearching == false)
        #expect(viewModel.isGenreBrowsing == true)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
    }

    @Test
    @MainActor
    func browseGenreFailureThenRetrySucceeds() async throws {
        let stub = SearchAndDiscoverCaptureMetadataStub(
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setDiscoverFailure(page: 1, times: 1)
        let viewModel = SearchViewModel(metadataService: stub)
        let genre = Genre(id: 28, name: "Action")

        viewModel.browseGenre(genre)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            viewModel.error == .network(.transport("Genre browse failed."))
        }
        #expect(viewModel.results.isEmpty)

        viewModel.browseGenre(genre)
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func browseGenreSendsRegularDiscoverWindowConstraints() async throws {
        let stub = RegularGenreBrowseFilterCaptureMetadataStub(
            result: MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.browseGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        let calls = await stub.getDiscoverCalls()
        #expect(calls.count == 1)
        #expect(calls[0].releaseDateGte == nil)
        #expect(calls[0].releaseDateLte == DiscoverFilters.todayString())
        #expect(calls[0].genreId == 28)
        #expect(calls[0].page == 1)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromGenreContextRemapsByGenreName() async throws {
        let stub = GenreAwareMetadataStub(
            genresByType: [
                .series: [Genre(id: 99, name: "Action")]
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "series-genre-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        #expect(viewModel.selectedGenre?.id == 28)

        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 1
        }
        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.genres.map(\.id) == [99])

        viewModel.handleSelectedTypeChange()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }

        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.selectedGenre?.id == 99)
        #expect(viewModel.selectedGenre?.name == "Action")
        #expect(viewModel.results.map(\.id) == ["series-genre-page-1"])
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromGenreContextWithoutGenreMatchClearsGenreState() async throws {
        let stub = GenreAwareMetadataStub(
            genresByType: [
                .series: [Genre(id: 16, name: "Animation")]
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.results = [Fixtures.mediaPreview(id: "stale-result")]
        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 1
        }

        viewModel.handleSelectedTypeChange()

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.activeMoodCard == nil)
        #expect(await stub.getDiscoverCallCount() == 0)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromGenreContextWithGenreMatchFailureFallsBackToSearch() async throws {
        let stub = GenreAwareMetadataStub(
            genresByType: [
                .series: [Genre(id: 16, name: "Animation")]
            ],
            searchResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "search-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "series-discover-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = "apollo"
        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 1
        }

        viewModel.handleSelectedTypeChange()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getSearchCallCount() == 1
        }

        #expect(await stub.getDiscoverCallCount() == 0)
        #expect(await stub.getSearchCallCount() == 1)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.map(\.id) == ["search-page-1"])
    }

    @Test
    @MainActor
    func browseGenreRaceUsesLatestRequestAndDropsStaleInFlightResult() async throws {
        let stub = GenreRouteDiscoverMetadataStub(
            discoverResultByGenre: [
                28: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-28-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                ),
                16: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "genre-16-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 28)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.browseGenre(Genre(id: 28, name: "Action"))
        viewModel.browseGenre(Genre(id: 16, name: "Animation"))

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(await stub.getDiscoverCallCount() == 2)

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            viewModel.results.map(\.id) == ["genre-16-page-1"]
        }
        #expect(viewModel.results.map(\.id) == ["genre-16-page-1"])

        let calls = await stub.getDiscoverCalls()
        #expect(calls.count == 2)
        #expect(calls[0].genreId == 28)
        #expect(calls[1].genreId == 16)
        #expect(viewModel.isGenreBrowsing == true)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func handleSelectedTypeChangeFromGenreContextRemapsByCaseInsensitiveGenreName() async throws {
        let stub = GenreAwareMetadataStub(
            genresByType: [
                .series: [Genre(id: 99, name: "Action")]
            ],
            discoverResultByPage: [
                1: MetadataSearchResult(
                    items: [Fixtures.mediaPreview(id: "series-page-1")],
                    page: 1,
                    totalPages: 1,
                    totalResults: 1
                )
            ]
        )
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))

        viewModel.selectedGenre = Genre(id: 28, name: "action")
        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 1
        }

        viewModel.handleSelectedTypeChange()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.selectedGenre?.id == 99)
        #expect(viewModel.selectedGenre?.name == "Action")
        #expect(viewModel.results.map(\.id) == ["series-page-1"])
    }


    @Test
    @MainActor
    func staleGenreLoadInFlightForPreviousTypeFailureDoesNotOverwriteCurrentGenreList() async throws {
        let stub = GenreLoadDedupMetadataStub()
        await stub.setGenreLoadDelay(.milliseconds(160), for: .movie)
        await stub.setGenreLoadDelay(.milliseconds(40), for: .series)
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Animation")], for: .series)
        await stub.setGenreLoadFailureOnce(for: .movie)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.loadGenres()

        viewModel.selectedType = .series
        viewModel.loadGenres()

        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 2
        }
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            viewModel.genres.count == 1 && viewModel.genres[0].id == 16
        }

        #expect(viewModel.genres.count == 1)
        #expect(viewModel.genres[0].id == 16)
        #expect(await stub.getGenresCallCount() == 2)

        try await Task.sleep(for: .milliseconds(240))
        #expect(await stub.getGenresCallCount() == 2)
        #expect(viewModel.genres.count == 1)
        #expect(viewModel.genres[0].id == 16)
    }

    @Test
    @MainActor
    func loadGenresCanReturnToPreviouslyLoadedTypeUsingCachedResult() async throws {
        let stub = GenreLoadDedupMetadataStub()
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 16, name: "Animation")], for: .series)

        let viewModel = SearchViewModel(metadataService: stub)

        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 1
        }
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            !viewModel.genres.isEmpty
        }
        #expect(viewModel.genres[0].id == 28)

        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            await stub.getGenresCallCount() == 2
        }
        try await Self.waitUntil(timeout: .milliseconds(1000)) {
            viewModel.genres[0].id == 16
        }
        #expect(viewModel.genres[0].id == 16)

        let callCountAfterSeries = await stub.getGenresCallCount()
        viewModel.selectedType = .movie
        viewModel.loadGenres()

        #expect(await stub.getGenresCallCount() == callCountAfterSeries)
        #expect(viewModel.genres[0].id == 28)
    }

}
