import Foundation
import SwiftUI
import Testing
@testable import VPStudio

@Suite(.serialized)
struct SearchViewModelAsyncBehaviorTests {
    actor DebouncedSearchMetadataStub: MetadataProvider {
        private var searchResultsByQuery: [String: [Int: MetadataSearchResult]] = [:]
        private var searchCallLog: [String] = []
        private var searchCallsByPage: [Int: Int] = [:]
        private var searchDelaysByQuery: [String: [Int: Duration]] = [:]
        private let defaultSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

        func setSearchResult(_ result: MetadataSearchResult, for query: String, page: Int) {
            searchResultsByQuery[query] = searchResultsByQuery[query, default: [:]].merging([page: result], uniquingKeysWith: { current, _ in current })
        }

        func setSearchDelay(_ delay: Duration, for query: String, page: Int) {
            searchDelaysByQuery[query] = (searchDelaysByQuery[query] ?? [:]).merging([page: delay], uniquingKeysWith: { current, _ in current })
        }

        func getSearchCalls() -> [String] {
            searchCallLog
        }

        func getSearchCallCount() -> Int {
            searchCallLog.count
        }

        func getSearchCallCount(for page: Int) -> Int {
            searchCallsByPage[page] ?? 0
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCallLog.append(query)
            if let delay = searchDelaysByQuery[query]?[page] {
                try await Task.sleep(for: delay)
            }
            searchCallsByPage[page, default: 0] += 1
            return searchResultsByQuery[query]?[page] ?? defaultSearchResult
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    actor NonCooperativeSearchMetadataStub: MetadataProvider {
        struct Call: Hashable {
            let query: String
            let page: Int
        }

        struct SearchFailure: Error {}

        private var searchResultsByQuery: [String: [Int: MetadataSearchResult]] = [:]
        private var searchDelaysByQuery: [Call: Duration] = [:]
        private var searchFailures: Set<Call> = []
        private var searchCalls: [Call] = []
        private let defaultSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

        func setSearchResult(_ result: MetadataSearchResult, for query: String, page: Int) {
            searchResultsByQuery[query] = searchResultsByQuery[query, default: [:]].merging([page: result], uniquingKeysWith: { current, _ in current })
        }

        func setSearchDelay(_ delay: Duration, for query: String, page: Int) {
            searchDelaysByQuery[Call(query: query, page: page)] = delay
        }

        func getSearchCalls() -> [Call] {
            searchCalls
        }

        func getSearchCallCount(for page: Int) -> Int {
            searchCalls.filter { $0.page == page }.count
        }

        func setSearchFailure(_ fail: Bool, for query: String, page: Int) {
            let call = Call(query: query, page: page)
            if fail { searchFailures.insert(call) } else { searchFailures.remove(call) }
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            let call = Call(query: query, page: page)
            searchCalls.append(call)
            let result = searchResultsByQuery[query]?[page] ?? defaultSearchResult
            let delay = searchDelaysByQuery[call] ?? .milliseconds(0)
            let shouldFail = searchFailures.contains(call)

            return try await withCheckedThrowingContinuation { continuation in
                Task.detached {
                    try await Task.sleep(for: delay)
                    if shouldFail {
                        continuation.resume(throwing: SearchFailure())
                    } else {
                        continuation.resume(returning: result)
                    }
                }
            }
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    actor StaleSearchMetadataStub: MetadataProvider {
        struct Call: Hashable {
            let query: String
            let page: Int
        }

        private var searchResultsByQuery: [String: [Int: MetadataSearchResult]] = [:]
        private var delays: [Call: Duration] = [:]
        private var searchCalls: [Call] = []
        private let defaultSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

        func setSearchResult(_ result: MetadataSearchResult, for query: String, page: Int) {
            searchResultsByQuery[query] = searchResultsByQuery[query, default: [:]].merging([page: result], uniquingKeysWith: { current, _ in current })
        }

        func setDelay(_ delay: Duration, for query: String, page: Int) {
            delays[Call(query: query, page: page)] = delay
        }

        func getSearchCallCount() -> Int {
            searchCalls.count
        }

        func getSearchCallCount(for page: Int) -> Int {
            searchCalls.filter { $0.page == page }.count
        }

        func getSearchCallLog() -> [Call] {
            searchCalls
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            let call = Call(query: query, page: page)
            searchCalls.append(call)
            if let delay = delays[call] {
                try await Task.sleep(for: delay)
            }
            return searchResultsByQuery[query]?[page] ?? defaultSearchResult
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    actor GenreSearchMetadataStub: MetadataProvider {
        struct SearchCall: Equatable, Hashable {
            let query: String
            let page: Int
        }

        struct DiscoverCall: Equatable {
            let page: Int
        }

        private struct DiscoverResultKey: Hashable {
            let genreId: Int?
            let page: Int
        }

        private var discoverResultByPage: [Int: MetadataSearchResult] = [:]
        private var discoverResultByGenreAndPage: [DiscoverResultKey: MetadataSearchResult] = [:]
        private var searchResultByQueryAndPage: [String: [Int: MetadataSearchResult]] = [:]
        private var discoverDelayByPage: [Int: Duration] = [:]
        private var searchDelayByQuery: [String: Duration] = [:]
        private var searchDelayByQueryAndPage: [String: [Int: Duration]] = [:]
        private var searchFailuresByQuery: Set<SearchCall> = []
        private var discoverFailures: Set<Int> = []
        private var discoverCalls: [DiscoverCall] = []
        private var searchCalls: [SearchCall] = []

        private let defaultSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
        private let defaultDiscoverResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

        func setDiscoverResult(_ result: MetadataSearchResult, for page: Int) {
            discoverResultByPage[page] = result
        }

        func setDiscoverResult(_ result: MetadataSearchResult, for page: Int, genreId: Int?) {
            discoverResultByGenreAndPage[DiscoverResultKey(genreId: genreId, page: page)] = result
        }

        func setSearchResult(_ result: MetadataSearchResult, for query: String, page: Int) {
            searchResultByQueryAndPage[query] = (searchResultByQueryAndPage[query] ?? [:]).merging([page: result], uniquingKeysWith: { current, _ in current })
        }

        func setDiscoverDelay(_ delay: Duration, for page: Int) {
            discoverDelayByPage[page] = delay
        }

        func setDiscoverFailure(_ fail: Bool, for page: Int) {
            if fail {
                discoverFailures.insert(page)
            } else {
                discoverFailures.remove(page)
            }
        }

        func setSearchDelay(_ delay: Duration, for query: String) {
            searchDelayByQuery[query] = delay
        }

        func setSearchDelay(_ delay: Duration, for query: String, page: Int) {
            searchDelayByQueryAndPage[query] = (searchDelayByQueryAndPage[query] ?? [:]).merging([page: delay], uniquingKeysWith: { current, _ in current })
        }

        func setSearchFailure(_ fail: Bool, for query: String, page: Int) {
            let call = SearchCall(query: query, page: page)
            if fail {
                searchFailuresByQuery.insert(call)
            } else {
                searchFailuresByQuery.remove(call)
            }
        }

        func getDiscoverCallCount() -> Int {
            discoverCalls.count
        }

        func getSearchCallCount(for query: String) -> Int {
            searchCalls.filter { $0.query == query }.count
        }

        func getSearchCallCount(for page: Int) -> Int {
            searchCalls.filter { $0.page == page }.count
        }

        func getDiscoverCallCount(for page: Int) -> Int {
            discoverCalls.filter { $0.page == page }.count
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCalls.append(SearchCall(query: query, page: page))
            if let delay = searchDelayByQueryAndPage[query]?[page] {
                try await Task.sleep(for: delay)
            } else if let delay = searchDelayByQuery[query] {
                try await Task.sleep(for: delay)
            }
            let call = SearchCall(query: query, page: page)
            if searchFailuresByQuery.contains(call) {
                struct SearchFailure: Error {}
                throw SearchFailure()
            }

            return searchResultByQueryAndPage[query]?[page] ?? defaultSearchResult
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCalls.append(DiscoverCall(page: filters.page))
            if let delay = discoverDelayByPage[filters.page] {
                try await Task.sleep(for: delay)
            }
            if discoverFailures.contains(filters.page) {
                struct DiscoverFailure: Error {}
                throw DiscoverFailure()
            }

            return discoverResultByGenreAndPage[DiscoverResultKey(genreId: filters.genreId, page: filters.page)]
                ?? discoverResultByPage[filters.page]
                ?? defaultDiscoverResult
        }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    actor GenreBrowseMetadataStub: MetadataProvider {
        struct SearchCall: Equatable {
            let query: String
            let page: Int
        }

        struct DiscoverCall: Equatable {
            let type: MediaType
            let page: Int
            let genreId: Int?
        }

        private var searchResultsByQuery: [String: [Int: MetadataSearchResult]] = [:]
        private var searchCallLog: [String] = []
        private var searchCallsByPage: [Int: Int] = [:]
        private var searchDelaysByQuery: [String: [Int: Duration]] = [:]
        private var genresByType: [MediaType: [Genre]] = [:]
        private var genreLoadDelay: [MediaType: Duration] = [:]
        private var genresCallCountByType: [MediaType: Int] = [:]
        private var discoverResultByPage: [Int: MetadataSearchResult] = [:]
        private var discoverDelayByPage: [Int: Duration] = [:]
        private var discoverCalls: [DiscoverCall] = []
        private var discoverFailures: Set<Int> = []

        private let defaultSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
        private let defaultDiscoverResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

        func setSearchResult(_ result: MetadataSearchResult, for query: String, page: Int) {
            searchResultsByQuery[query] = searchResultsByQuery[query, default: [:]].merging([page: result], uniquingKeysWith: { current, _ in current })
        }

        func setSearchDelay(_ delay: Duration, for query: String, page: Int) {
            searchDelaysByQuery[query] = (searchDelaysByQuery[query] ?? [:]).merging([page: delay], uniquingKeysWith: { current, _ in current })
        }

        func setGenres(_ genres: [Genre], for type: MediaType) {
            genresByType[type] = genres
        }

        func setGenreDelay(_ delay: Duration, for type: MediaType) {
            genreLoadDelay[type] = delay
        }

        func setDiscoverResult(_ result: MetadataSearchResult, for page: Int) {
            discoverResultByPage[page] = result
        }

        func setDiscoverDelay(_ delay: Duration, for page: Int) {
            discoverDelayByPage[page] = delay
        }

        func setDiscoverFailure(_ fail: Bool, for page: Int) {
            if fail { discoverFailures.insert(page) } else { discoverFailures.remove(page) }
        }

        func getSearchCalls() -> [String] {
            searchCallLog
        }

        func getSearchCallCount() -> Int {
            searchCallLog.count
        }

        func getSearchCallCount(for page: Int) -> Int {
            searchCallsByPage[page] ?? 0
        }

        func getGenresCallCount(for type: MediaType) -> Int {
            genresCallCountByType[type] ?? 0
        }

        func getDiscoverCallCount() -> Int {
            discoverCalls.count
        }

        func getDiscoverCallCount(for page: Int) -> Int {
            discoverCalls.filter { $0.page == page }.count
        }

        func getDiscoverCalls() -> [DiscoverCall] {
            discoverCalls
        }

        func getDiscoverCallGenreIDs() -> [Int?] {
            discoverCalls.map(\.genreId)
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCallLog.append(query)
            if let delay = searchDelaysByQuery[query]?[page] {
                try await Task.sleep(for: delay)
            }
            searchCallsByPage[page, default: 0] += 1
            return searchResultsByQuery[query]?[page] ?? defaultSearchResult
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            discoverCalls.append(DiscoverCall(type: type, page: filters.page, genreId: filters.genreId))
            if let delay = discoverDelayByPage[filters.page] {
                try await Task.sleep(for: delay)
            }
            if discoverFailures.contains(filters.page) {
                struct DiscoverFailure: Error {}
                throw DiscoverFailure()
            }

            return discoverResultByPage[filters.page] ?? defaultDiscoverResult
        }

        func getGenres(type: MediaType) async throws -> [Genre] {
            genresCallCountByType[type, default: 0] += 1
            if let delay = genreLoadDelay[type] {
                try await Task.sleep(for: delay)
            }
            return genresByType[type] ?? []
        }

        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    actor GenreBrowseCallSequencerStub: MetadataProvider {
        struct SearchCall: Equatable {
            let query: String
            let page: Int
        }

        struct DiscoverCall: Equatable {
            let type: MediaType
            let page: Int
            let genreId: Int?
        }

        struct DiscoverFailure: Error {}

        private var discoverResultByCall: [Int: MetadataSearchResult] = [:]
        private var discoverDelayByCall: [Int: Duration] = [:]
        private var discoverFailures: Set<Int> = []
        private var discoverCalls: [DiscoverCall] = []
        private var searchCallLog: [SearchCall] = []
        private var genresByType: [MediaType: [Genre]] = [:]
        private var genreLoadDelay: [MediaType: Duration] = [:]
        private var genresCallCountByType: [MediaType: Int] = [:]
        private var defaultDiscoverResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

        func setDiscoverResult(_ result: MetadataSearchResult, forCall callIndex: Int) {
            discoverResultByCall[callIndex] = result
        }

        func setDiscoverDelay(_ delay: Duration, forCall callIndex: Int) {
            discoverDelayByCall[callIndex] = delay
        }

        func setGenres(_ genres: [Genre], for type: MediaType) {
            genresByType[type] = genres
        }

        func setGenreDelay(_ delay: Duration, for type: MediaType) {
            genreLoadDelay[type] = delay
        }

        func setDiscoverFailure(_ fail: Bool, forCall callIndex: Int) {
            if fail {
                discoverFailures.insert(callIndex)
            } else {
                discoverFailures.remove(callIndex)
            }
        }

        func setDefaultDiscoverResult(_ result: MetadataSearchResult) {
            defaultDiscoverResult = result
        }

        func getSearchCalls() -> [SearchCall] {
            searchCallLog
        }

        func getDiscoverCalls() -> [DiscoverCall] {
            discoverCalls
        }

        func getDiscoverCallCount() -> Int {
            discoverCalls.count
        }

        func getGenresCallCount(for type: MediaType) -> Int {
            genresCallCountByType[type] ?? 0
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            searchCallLog.append(SearchCall(query: query, page: page))
            return MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
        }

        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
            let callIndex = discoverCalls.count
            discoverCalls.append(DiscoverCall(type: type, page: filters.page, genreId: filters.genreId))

            if let delay = discoverDelayByCall[callIndex] {
                try await Task.sleep(for: delay)
            }

            if discoverFailures.contains(callIndex) {
                throw DiscoverFailure()
            }

            return discoverResultByCall[callIndex] ?? defaultDiscoverResult
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getGenres(type: MediaType) async throws -> [Genre] {
            genresCallCountByType[type, default: 0] += 1
            if let delay = genreLoadDelay[type] {
                try await Task.sleep(for: delay)
            }
            return genresByType[type] ?? []
        }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    actor FailingSearchMetadataStub: MetadataProvider {
        struct Call: Hashable {
            let query: String
            let page: Int
        }

        private var searchResultsByQuery: [String: [Int: MetadataSearchResult]] = [:]
        private var searchDelaysByQuery: [Call: Duration] = [:]
        private var searchFailures: Set<Call> = []
        private var searchCalls: [Call] = []
        private let defaultSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

        func setSearchResult(_ result: MetadataSearchResult, for query: String, page: Int) {
            searchResultsByQuery[query] = searchResultsByQuery[query, default: [:]].merging([page: result], uniquingKeysWith: { current, _ in current })
        }

        func setSearchDelay(_ delay: Duration, for query: String, page: Int) {
            searchDelaysByQuery[Call(query: query, page: page)] = delay
        }

        func setSearchFailure(_ fail: Bool, for query: String, page: Int) {
            let call = Call(query: query, page: page)
            if fail {
                searchFailures.insert(call)
            } else {
                searchFailures.remove(call)
            }
        }

        func getSearchCalls() -> [Call] {
            searchCalls
        }

        func getSearchCallCount() -> Int {
            searchCalls.count
        }

        func getSearchCallCount(for page: Int) -> Int {
            searchCalls.filter { $0.page == page }.count
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
            let call = Call(query: query, page: page)
            searchCalls.append(call)

            if let delay = searchDelaysByQuery[call] {
                try await Task.sleep(for: delay)
            }

            if searchFailures.contains(call) {
                struct SearchFailure: Error {}
                throw SearchFailure()
            }

            return searchResultsByQuery[query]?[page] ?? defaultSearchResult
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
        func getGenres(type: MediaType) async throws -> [Genre] { [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    actor DelayedGenresMetadataStub: MetadataProvider {
        private var genresByType: [MediaType: [Genre]] = [:]
        private var genreLoadDelay: [MediaType: Duration] = [:]
        private var getGenresCallCountByType: [MediaType: Int] = [:]

        func setGenres(_ genres: [Genre], for type: MediaType) {
            genresByType[type] = genres
        }

        func setGenreDelay(_ delay: Duration, for type: MediaType) {
            genreLoadDelay[type] = delay
        }

        func getGenresCallCount(for type: MediaType) -> Int {
            getGenresCallCountByType[type] ?? 0
        }

        func getTotalGenreCalls() -> Int {
            getGenresCallCountByType.values.reduce(0, +)
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }

        func getGenres(type: MediaType) async throws -> [Genre] {
            getGenresCallCountByType[type, default: 0] += 1
            if let delay = genreLoadDelay[type] {
                try await Task.sleep(for: delay)
            }

            return genresByType[type] ?? []
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    actor FailingGenresMetadataStub: MetadataProvider {
        struct GenreFailure: Error {}

        private var genresByType: [MediaType: [Genre]] = [:]
        private var genreLoadDelay: [MediaType: Duration] = [:]
        private var failingGenres: Set<MediaType> = []
        private var getGenresCallCountByType: [MediaType: Int] = [:]

        func setGenres(_ genres: [Genre], for type: MediaType) {
            genresByType[type] = genres
        }

        func setGenreDelay(_ delay: Duration, for type: MediaType) {
            genreLoadDelay[type] = delay
        }

        func setGenreFailure(_ fail: Bool, for type: MediaType) {
            if fail {
                failingGenres.insert(type)
            } else {
                failingGenres.remove(type)
            }
        }

        func getGenresCallCount(for type: MediaType) -> Int {
            getGenresCallCountByType[type] ?? 0
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }

        func getGenres(type: MediaType) async throws -> [Genre] {
            getGenresCallCountByType[type, default: 0] += 1
            if let delay = genreLoadDelay[type] {
                try await Task.sleep(for: delay)
            }
            if failingGenres.contains(type) {
                throw GenreFailure()
            }
            return genresByType[type] ?? []
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    actor NonCooperativeGenresMetadataStub: MetadataProvider {
        private var genresByType: [MediaType: [Genre]] = [:]
        private var genreLoadDelay: [MediaType: Duration] = [:]
        private var getGenresCallCountByType: [MediaType: Int] = [:]

        func setGenres(_ genres: [Genre], for type: MediaType) {
            genresByType[type] = genres
        }

        func setGenreDelay(_ delay: Duration, for type: MediaType) {
            genreLoadDelay[type] = delay
        }

        func getGenresCallCount(for type: MediaType) -> Int {
            getGenresCallCountByType[type] ?? 0
        }

        func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
        func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }

        func getGenres(type: MediaType) async throws -> [Genre] {
            getGenresCallCountByType[type, default: 0] += 1
            let genres = genresByType[type] ?? []
            let delay = genreLoadDelay[type] ?? .milliseconds(0)

            return try await withCheckedThrowingContinuation { continuation in
                Task.detached {
                    try await Task.sleep(for: delay)
                    continuation.resume(returning: genres)
                }
            }
        }

        func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
        func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { fatalError("unused") }
        func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
        func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
    }

    /// Polls until `condition` returns true, yielding between checks. Fails after `timeout`.
    @MainActor
    private static func waitUntil(
        timeout: Duration = .milliseconds(5000),
        _ condition: @MainActor () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while true {
            if await condition() {
                return
            }
            guard ContinuousClock.now < deadline else {
                Issue.record("waitUntil timed out after \(timeout)")
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    @Test
    @MainActor
    func debouncedSearchCancelsPreviousAndExecutesOnlyLatestQuery() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(items: [Fixtures.mediaPreview(id: "first-result")], page: 1, totalPages: 1, totalResults: 1),
            for: "first",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(items: [Fixtures.mediaPreview(id: "second-result")], page: 1, totalPages: 1, totalResults: 1),
            for: "second",
            page: 1
        )

        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(120)
        )

        viewModel.debouncedSearch(queryText: "first")
        try await Task.sleep(for: .milliseconds(20))
        viewModel.debouncedSearch(queryText: "second")

        try await Self.waitUntil(timeout: .seconds(2)) {
            await stub.getSearchCallCount() == 1
        }

        #expect(await stub.getSearchCalls() == ["second"])
        #expect(viewModel.results.count == 1)
        #expect(viewModel.results.first?.id == "second-result")
    }

    @Test
    @MainActor
    func debouncedSearchNoopForWhitespaceQuery() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(items: [Fixtures.mediaPreview(id: "ignored")], page: 1, totalPages: 1, totalResults: 1),
            for: "",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(80))
        viewModel.debouncedSearch(queryText: "   ")

        try await Task.sleep(for: .milliseconds(150))

        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func debouncedSearchCancelsPendingSearchWhenWhitespaceArrives() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(items: [Fixtures.mediaPreview(id: "pending")], page: 1, totalPages: 1, totalResults: 1),
            for: "dune",
            page: 1
        )

        let viewModel = SearchViewModel(
            metadataServiceFactory: { _ in stub },
            debounceInterval: .milliseconds(120)
        )

        viewModel.debouncedSearch(queryText: "dune")
        try await Task.sleep(for: .milliseconds(20))
        viewModel.debouncedSearch(queryText: "  ")

        try await Task.sleep(for: .milliseconds(180))

        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func debouncedSearchWithoutMetadataServiceSurfacesSetupError() {
        let viewModel = SearchViewModel()
        viewModel.debouncedSearch(queryText: "no key")

        #expect(viewModel.error == .tmdbSetupRequired(feature: "Search"))
        #expect(!viewModel.isSearching)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func debouncedSearchTrimsQueryBeforeExecuting() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(items: [Fixtures.mediaPreview(id: "trimmed")], page: 1, totalPages: 1, totalResults: 1),
            for: "hello",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(50))
        viewModel.debouncedSearch(queryText: "  hello  ")

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }

        #expect(await stub.getSearchCalls() == ["hello"])
        #expect(viewModel.results.first?.id == "trimmed")
    }

    @Test
    @MainActor
    func explicitSearchCancelsInflightDebouncedSearch() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(items: [Fixtures.mediaPreview(id: "manual-result")], page: 1, totalPages: 1, totalResults: 1),
            for: "manual",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(items: [Fixtures.mediaPreview(id: "debounced-result")], page: 1, totalPages: 1, totalResults: 1),
            for: "queued",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(150))

        viewModel.debouncedSearch(queryText: "queued")
        viewModel.search(queryText: "manual")

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }

        #expect(await stub.getSearchCalls().last == "manual")
        #expect(viewModel.results.first?.id == "manual-result")
    }

    @Test
    @MainActor
    func explicitSearchCancelsInflightDebouncedSearchWithNonCooperativeProvider() async throws {
        let stub = NonCooperativeSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(items: [Fixtures.mediaPreview(id: "debounced-result")], page: 1, totalPages: 1, totalResults: 1),
            for: "queued",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(items: [Fixtures.mediaPreview(id: "manual-result")], page: 1, totalPages: 1, totalResults: 1),
            for: "manual",
            page: 1
        )
        await stub.setSearchDelay(.milliseconds(220), for: "queued", page: 1)

        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(150))

        viewModel.debouncedSearch(queryText: "queued")
        viewModel.search(queryText: "manual")

        try await Self.waitUntil {
            await stub.getSearchCallCount(for: 1) == 1
        }

        let searchCalls = await stub.getSearchCalls()
        #expect(searchCalls.map(\.query) == ["manual"])
        #expect(viewModel.results.first?.id == "manual-result")
    }

    @Test
    @MainActor
    func loadMoreRespectsPaginationCooldown() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "page-1")],
                page: 1,
                totalPages: 3,
                totalResults: 3
            ),
            for: "cooldown",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "page-2")],
                page: 2,
                totalPages: 3,
                totalResults: 3
            ),
            for: "cooldown",
            page: 2
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "page-3")],
                page: 3,
                totalPages: 3,
                totalResults: 3
            ),
            for: "cooldown",
            page: 3
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(200))
        viewModel.query = "cooldown"

        viewModel.search()
        try await Self.waitUntil {
            await stub.getSearchCallCount(for: 1) == 1
        }
        #expect(await stub.getSearchCallCount(for: 1) == 1)

        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.currentPage == 2
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(80))
        #expect(await stub.getSearchCallCount(for: 3) == 0)

        try await Task.sleep(for: .milliseconds(170))
        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.currentPage == 3
        }

        #expect(await stub.getSearchCallCount(for: 3) == 1)
        #expect(viewModel.currentPage == 3)
        #expect(viewModel.results.last?.id == "page-3")
    }

    @Test
    @MainActor
    func loadMoreStaleResultIsIgnoredAfterSearchQueryChanges() async throws {
        let stub = StaleSearchMetadataStub()

        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "a-p1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "a-p2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
        await stub.setDelay(.milliseconds(160), for: "alpha", page: 2)

        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "b-p1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "beta",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.currentPage == 1 && viewModel.results.map(\.id) == ["a-p1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(30))

        viewModel.query = "beta"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.currentPage == 1 && viewModel.results.map(\.id) == ["b-p1"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(!viewModel.results.contains(where: { $0.id == "a-p2" }))
    }

    @Test
    @MainActor
    func staleSearchLoadMoreResultIgnoredWhenTypingQueryDraftWithoutSearching() async throws {
        let stub = StaleSearchMetadataStub()

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
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
        await stub.setDelay(.milliseconds(220), for: "alpha", page: 2)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.currentPage == 1 && viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.queryDraft = "alph"

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.results.map(\.id) == ["alpha-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "alpha-page-2" }))
    }

    @Test
    @MainActor
    func staleSearchLoadMoreFailureIgnoredWhenTypingQueryDraftWithoutSearching() async throws {
        let stub = FailingSearchMetadataStub()

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
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
        await stub.setSearchFailure(true, for: "alpha", page: 2)
        await stub.setSearchDelay(.milliseconds(220), for: "alpha", page: 2)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.currentPage == 1 && viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.queryDraft = "alph"

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.results.map(\.id) == ["alpha-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func inFlightLoadMoreSuccessIgnoredAfterClear() async throws {
        let stub = StaleSearchMetadataStub()
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
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
        await stub.setDelay(.milliseconds(220), for: "alpha", page: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.currentPage == 1 && viewModel.results.map(\.id) == ["alpha-page-1"]
        }
        #expect(viewModel.totalPages == 2)

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))
        viewModel.clear()

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.error == nil)

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "alpha-page-2" }))
    }

    @Test
    @MainActor
    func typingQueryDraftWhileSpecialMoodIsOpenDoesNotTriggerSearchPaginationRequest() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1,
            genreId: 28
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2,
            genreId: 28
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }

        viewModel.queryDraft = "drama"
        viewModel.loadMore()

        try await Task.sleep(for: .milliseconds(80))
        #expect(await stub.getSearchCallCount(for: "") == 0)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["mood-page-1"])
    }

    @Test
    @MainActor
    func staleSearchLoadMoreIgnoredAfterSortFilterChange() async throws {
        let stub = StaleSearchMetadataStub()
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
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
        await stub.setDelay(.milliseconds(220), for: "alpha", page: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.currentPage == 1 && viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(30))

        viewModel.applySortOption(.ratingDesc)
        try await Self.waitUntil {
            await stub.getSearchCallCount(for: 1) == 2
        }

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["alpha-page-1"])
        #expect(!viewModel.results.contains(where: { $0.id == "alpha-page-2" }))
    }

    @Test
    @MainActor
    func staleGenreLoadMoreIgnoredAfterLanguageFilterChange() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.applyLanguageFilters(["fr-FR"])
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 3
        }

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.currentPage == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "genre-page-2" }))
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
    }

    @Test
    @MainActor
    func staleGenreLoadMoreIgnoredAfterSwitchingGenreDuringPagination() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "action-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1,
            genreId: 28
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "action-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2,
            genreId: 28
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "comedy-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1,
            genreId: 35
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["action-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))
        viewModel.selectGenre(Genre(id: 35, name: "Comedy"))

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["comedy-page-1"]
        }

        try await Task.sleep(for: .milliseconds(250))
        #expect(!viewModel.results.contains(where: { $0.id == "action-page-2" }))
    }

    @Test
    @MainActor
    func staleSearchLoadMoreIgnoredAfterYearFilterChange() async throws {
        let stub = StaleSearchMetadataStub()
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
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
        await stub.setDelay(.milliseconds(220), for: "alpha", page: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.currentPage == 1 && viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(30))
        viewModel.applyYearFilter(2024)

        try await Self.waitUntil {
            await stub.getSearchCallCount(for: 1) == 2
        }

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.currentPage == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "alpha-page-2" }))
        #expect(viewModel.results.map(\.id) == ["alpha-page-1"])
    }

    @Test
    @MainActor
    func staleGenreLoadMoreFailureIgnoredAfterClearAllFilters() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverFailure(true, for: 2)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))
        viewModel.clearAllFilters()

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func loadMoreAfterSelectingGenreFromSearchContextShouldNotUseTextPaginationPath() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 2
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["search-page-1"]
        }

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }
        #expect(await stub.getSearchCallCount(for: 1) == 1)
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        #expect(await stub.getSearchCallCount(for: 1) == 1)
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["genre-page-1", "genre-page-2"])
        #expect(!viewModel.results.contains(where: { $0.id == "search-page-2" }))
    }

    @Test
    @MainActor
    func emptySearchTextWhileGenreContextKeepsGenrePaginationPath() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(await stub.getSearchCallCount(for: "") == 0)

        viewModel.search(queryText: "   ")
        #expect(await stub.getSearchCallCount(for: "") == 0)

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        #expect(await stub.getSearchCallCount(for: "") == 0)
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["genre-page-1", "genre-page-2"])
    }

    @Test
    @MainActor
    func explicitSearchAfterGenreSelectionStillPaginatesSearchPath() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 2
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.queryDraft = "apollo"
        viewModel.search()
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["search-page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getSearchCallCount(for: "apollo") == 2
        }

        #expect(await stub.getSearchCallCount(for: "apollo") == 2)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["search-page-1", "search-page-2"])
    }

    @Test
    @MainActor
    func clearingQueryAfterSearchingWithinGenreContextReturnsToGenrePaginationPath() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 2
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["search-page-1"]
        }

        #expect(await stub.getSearchCallCount(for: 1) == 1)
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.queryDraft = ""
        try await Self.waitUntil {
            viewModel.query.isEmpty && viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 3
        }

        #expect(await stub.getSearchCallCount(for: 1) == 1)
        #expect(await stub.getDiscoverCallCount() == 3)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["genre-page-1", "genre-page-2"])
        #expect(!viewModel.results.contains(where: { $0.id == "search-page-2" }))
    }

    @Test
    @MainActor
    func loadMoreNoopAfterSearchReachesLastPage() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "single-page")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["single-page"]
        }
        #expect(!viewModel.hasMore)

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(80))

        #expect(await stub.getSearchCallCount(for: 1) == 1)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["single-page"])
    }

    @Test
    @MainActor
    func loadMoreNoopAfterGenreBrowseReachesLastPage() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-single-page")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-single-page"]
        }
        #expect(!viewModel.hasMore)

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(80))

        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["genre-single-page"])
    }

    @Test
    @MainActor
    func loadMoreIgnoresConcurrentSecondRequestWhenAlreadyLoading() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "s1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "dup",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "s2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "dup",
            page: 2
        )
        await stub.setSearchDelay(.milliseconds(180), for: "dup", page: 2)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "dup"

        viewModel.search()
        try await Self.waitUntil {
            await stub.getSearchCallCount(for: 1) == 1
                && viewModel.results.map(\.id) == ["s1"]
        }

        viewModel.loadMore()
        viewModel.loadMore()

        try await Task.sleep(for: .milliseconds(40))
        #expect(await stub.getSearchCallCount(for: 2) == 1)

        try await Self.waitUntil {
            viewModel.currentPage == 2
        }
        #expect(await stub.getSearchCallCount(for: 2) == 1)
        #expect(viewModel.results.map(\.id) == ["s1", "s2"])
    }

    @Test
    @MainActor
    func staleSearchResultAfterQueryChangeDoesNotOverwriteLatestResults() async throws {
        let stub = StaleSearchMetadataStub()

        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "alpha",
            page: 1
        )
        await stub.setDelay(.milliseconds(160), for: "alpha", page: 1)

        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "beta-page1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "beta",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "alpha"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.query = "beta"
        viewModel.search()

        try await Self.waitUntil {
            let hasCallLog = await !stub.getSearchCallLog().isEmpty
            return hasCallLog && viewModel.results.map(\.id) == ["beta-page1"]
        }

        try await Task.sleep(for: .milliseconds(220))
        #expect(!viewModel.results.contains(where: { $0.id == "alpha-page1" }))
    }

    @Test
    @MainActor
    func clearingQueryDuringInFlightSearchReturnsToGenreBrowseWithoutApplyingStaleSearchResults() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 3,
                totalResults: 3
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "alpha",
            page: 1
        )
        await stub.setSearchDelay(.milliseconds(200), for: "alpha")

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.query = "alpha"
        viewModel.search()
        try await Self.waitUntil {
            await stub.getSearchCallCount(for: "alpha") == 1
        }

        try await Task.sleep(for: .milliseconds(40))
        viewModel.query = ""

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        try await Task.sleep(for: .milliseconds(220))
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(await stub.getSearchCallCount(for: "alpha") == 1)
    }

    @Test
    @MainActor
    func staleSpecialMoodLoadMoreResultIsIgnoredAfterSwitchingToTextSearch() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "drama",
            page: 1
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil { viewModel.results.map(\.id) == ["mood-page-1"] }

        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        viewModel.loadMore()

        try await Task.sleep(for: .milliseconds(40))
        viewModel.query = "drama"
        viewModel.search()
        try await Self.waitUntil { viewModel.results.map(\.id) == ["text-page-1"] }

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.results.map(\.id) == ["text-page-1"])
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func staleSpecialMoodLoadMoreResultIgnoredWhenTypingQueryWithoutSearching() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil { viewModel.results.map(\.id) == ["mood-page-1"] }

        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.query = "drama"

        try await Task.sleep(for: .milliseconds(240))
        #expect(viewModel.results.map(\.id) == ["mood-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "mood-page-2" }))
    }

    @Test
    @MainActor
    func staleSpecialMoodLoadMoreFailureIgnoredWhenTypingQueryWithoutSearching() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil { viewModel.results.map(\.id) == ["mood-page-1"] }

        await stub.setDiscoverFailure(true, for: 2)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.query = "drama"

        try await Task.sleep(for: .milliseconds(240))
        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["mood-page-1"])
    }

    @Test
    @MainActor
    func staleGenreLoadMoreResultIsIgnoredAfterSwitchingToTextSearch() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "drama",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.search(queryText: "drama")
        try await Self.waitUntil { viewModel.results.map(\.id) == ["text-page-1"] }

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.results.map(\.id) == ["text-page-1"])
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func staleGenreLoadMoreResultIgnoredWhenTypingQueryWithoutSearching() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.query = "action"

        try await Task.sleep(for: .milliseconds(240))
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "genre-page-2" }))
    }

    @Test
    @MainActor
    func staleGenreLoadMoreFailureIgnoredWhenTypingQueryWithoutSearching() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        await stub.setDiscoverFailure(true, for: 2)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.query = "action"

        try await Task.sleep(for: .milliseconds(240))
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func staleGenreLoadMoreResultIsIgnoredAfterSwitchingToSpecialMood() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil {
            viewModel.activeMoodCard?.id == "new" &&
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        try await Task.sleep(for: .milliseconds(250))
        #expect(viewModel.currentPage == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "genre-page-2" }))
    }

    @Test
    @MainActor
    func inFlightLoadMoreResultFromGenrePaginationIsIgnoredAfterClear() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.clear()
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.currentPage == 1)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "genre-page-2" }))
    }

    @Test
    @MainActor
    func inFlightLoadMoreResultFromSpecialMoodPaginationIsIgnoredAfterClear() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 3,
                totalResults: 3
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-2")],
                page: 2,
                totalPages: 3,
                totalResults: 3
            ),
            for: 2
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil {
            let hasResult = viewModel.results.map(\.id) == ["mood-page-1"]
            let discoverCalls = await stub.getDiscoverCallCount()
            return hasResult && discoverCalls == 1
        }

        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.clear()
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.currentPage == 1)
        #expect(await stub.getDiscoverCallCount() == 2)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.activeMoodCard == nil)
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(!viewModel.results.contains(where: { $0.id == "mood-page-2" }))
    }

    @Test
    @MainActor
    func inFlightSearchRequestIsIgnoredAfterClear() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "alpha",
            page: 1
        )
        await stub.setSearchDelay(.milliseconds(220), for: "alpha", page: 1)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "alpha"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.clear()

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.submittedQuery.isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(await stub.getSearchCallCount() == 1)
    }

    @Test
    @MainActor
    func debouncedGenreSearchIsCancelledWhenQueryIsCleared() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "alpha",
            page: 1
        )
        await stub.setSearchDelay(.milliseconds(180), for: "alpha")

        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(120))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil { viewModel.results.map(\.id) == ["genre-page-1"] }

        viewModel.debouncedSearch(queryText: "alpha")
        try await Task.sleep(for: .milliseconds(20))
        viewModel.queryDraft = "   "

        try await Task.sleep(for: .milliseconds(280))
        #expect(await stub.getSearchCallCount(for: "alpha") == 0)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
    }

    @Test
    @MainActor
    func staleSearchLoadMoreResultIsIgnoredAfterSwitchingToGenreBrowse() async throws {
        let stub = GenreSearchMetadataStub()
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
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
        await stub.setSearchDelay(.milliseconds(160), for: "alpha")
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        await stub.setSearchDelay(.milliseconds(180), for: "alpha")
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        try await Task.sleep(for: .milliseconds(240))
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "alpha-page-2" }))
    }

    @Test
    @MainActor
    func stalePaginatedSearchErrorDoesNotOverwriteNewQueryState() async throws {
        let stub = FailingSearchMetadataStub()
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
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
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
        await stub.setSearchFailure(true, for: "alpha", page: 2)
        await stub.setSearchDelay(.milliseconds(180), for: "alpha", page: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.search(queryText: "beta")
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["beta-page-1"]
        }

        try await Task.sleep(for: .milliseconds(240))
        #expect(viewModel.results.map(\.id) == ["beta-page-1"])
        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "alpha-page-2" }))
    }

    @Test
    @MainActor
    func staleSearchResultFromPreviousMetadataServiceDoesNotOverwritePostConfigureSearch() async throws {
        let oldService = DebouncedSearchMetadataStub()
        let newService = DebouncedSearchMetadataStub()

        await oldService.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "drama",
            page: 1
        )
        await oldService.setSearchDelay(.milliseconds(220), for: "drama", page: 1)

        await newService.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "drama",
            page: 1
        )

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                if key == "new-key" { return newService }
                return oldService
            }
        )

        viewModel.configure(apiKey: "old-key")
        viewModel.query = "drama"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.configure(apiKey: "new-key")
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["new-page-1"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.map(\.id) == ["new-page-1"])
        #expect(await newService.getSearchCalls() == ["drama"])
    }

    @Test
    @MainActor
    func staleGenreLoadMoreResultIsIgnoredAfterClearAllFilters() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        let genre = Genre(id: 28, name: "Action")
        viewModel.selectGenre(genre)
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.clearAllFilters()
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
    }

    @Test
    @MainActor
    func clearAllFiltersDoesNotAllowStaleSearchResultToOverwriteQuery() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "alpha",
            page: 1
        )
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
        await stub.setSearchDelay(.milliseconds(220), for: "alpha", page: 1)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.sortOption = .ratingDesc
        viewModel.query = "alpha"
        viewModel.search()
        viewModel.query = "beta"

        try await Task.sleep(for: .milliseconds(20))
        viewModel.clearAllFilters()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["beta-page-1"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.map(\.id) == ["beta-page-1"])
        #expect(!viewModel.results.contains(where: { $0.id == "alpha-page-1" }))
        #expect(viewModel.sortOption == .popularityDesc)
    }

    @Test
    @MainActor
    func clearAllFiltersWhileSpecialMoodDiscoverIsInFlightKeepsLatestDiscover() async throws {
        let stub = GenreBrowseCallSequencerStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-stale")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 0
        )
        await stub.setDiscoverDelay(.milliseconds(220), forCall: 0)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-latest")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)

        viewModel.clearAllFilters()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-latest"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["mood-page-latest"])
        #expect(!viewModel.results.contains(where: { $0.id == "mood-page-stale" }))
        #expect(viewModel.activeMoodCard?.id == "new")
        #expect(viewModel.selectedGenre == nil)
    }

    @Test
    @MainActor
    func clearAllFiltersAfterSpecialMoodQueryChangePreservesNewestSearchResult() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-search-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "alpha",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "beta-search-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "beta",
            page: 1
        )
        await stub.setSearchDelay(.milliseconds(220), for: "alpha")

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }

        viewModel.query = "alpha"
        viewModel.search()
        try await Task.sleep(for: .milliseconds(20))
        viewModel.query = "beta"

        viewModel.clearAllFilters()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["beta-search-page-1"]
        }

        #expect(viewModel.activeMoodCard?.id == newReleasesCard.id)
        #expect(await stub.getSearchCallCount(for: "alpha") == 1)
        #expect(await stub.getSearchCallCount(for: "beta") == 1)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.map(\.id) == ["beta-search-page-1"])
        #expect(!viewModel.results.contains(where: { $0.id == "alpha-search-page-1" }))
        #expect(viewModel.query == "beta")
    }

    @Test
    @MainActor
    func staleSpecialMoodLoadMoreResultIgnoredAfterSwitchingSpecialMood() async throws {
        let stub = GenreBrowseCallSequencerStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-page-1")],
                page: 1,
                totalPages: 3,
                totalResults: 3
            ),
            forCall: 0
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-page-2")],
                page: 2,
                totalPages: 3,
                totalResults: 3
            ),
            forCall: 1
        )
        await stub.setDiscoverDelay(.milliseconds(220), forCall: 1)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "upcoming-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            forCall: 2
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let upcomingCard = ExploreGenreCatalog.cards.first(where: { $0.id == "upcoming" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["new-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.selectMoodCard(upcomingCard)
        try await Self.waitUntil {
            viewModel.activeMoodCard?.id == "upcoming" && viewModel.results.map(\.id) == ["upcoming-page-1"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 3)
        #expect(viewModel.activeMoodCard?.id == "upcoming")
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["upcoming-page-1"])
        #expect(!viewModel.results.contains(where: { $0.id == "new-page-2" }))
    }

    @Test
    @MainActor
    func selectedTypeChangeFromGenreWithoutCachedMatchFallsBackToSearch() async throws {
        let stub = GenreBrowseMetadataStub()
        await stub.setGenres(
            [
                Genre(id: 28, name: "Action")
            ],
            for: .movie
        )
        await stub.setGenres(
            [
                Genre(id: 18, name: "Drama")
            ],
            for: .series
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.queryDraft = "apollo"
        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["text-page-1"]
        }

        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.query == "apollo")
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(await stub.getSearchCallCount(for: 1) == 1)
    }

    @Test
    @MainActor
    func clearAllFiltersInGenreContextWithActiveTextQueryKeepsTextSearchPath() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.queryDraft = "apollo"
        viewModel.clearAllFilters()
        try await Self.waitUntil {
            viewModel.selectedGenre == nil && viewModel.results.map(\.id) == ["text-page-1"]
        }

        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(await stub.getSearchCallCount(for: 1) == 1)
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func inFlightGenreLoadMoreFailureDoesNotSetErrorAfterClear() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverFailure(true, for: 2)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))
        viewModel.clear()

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.error == nil)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func inFlightSpecialMoodLoadMoreFailureDoesNotSetErrorAfterClear() async throws {
        let stub = GenreSearchMetadataStub()
        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverFailure(true, for: 2)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))
        viewModel.clear()

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.error == nil)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
    }

    @Test
    @MainActor
    func staleGenreBrowseResultIgnoredWhenSelectedTypeChangeForcesRequery() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-old-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setDiscoverDelay(.milliseconds(220), for: 1)

        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "alpha",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "alpha"

        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Task.sleep(for: .milliseconds(30))

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.map(\.id) == ["alpha-page-1"])
        #expect(!viewModel.results.contains(where: { $0.id == "genre-old-page-1" }))
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query == "alpha")
    }

    @Test
    @MainActor
    func selectedTypeChangeFromGenreWithCachedGenresRemapsByIdAndKeepsGenrePagination() async throws {
        let stub = GenreBrowseMetadataStub()
        await stub.setGenres(
            [
                Genre(id: 28, name: "Action"),
            ],
            for: .movie
        )
        await stub.setGenres(
            [
                Genre(id: 28, name: "Action & Adventure"),
            ],
            for: .series
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "movie-genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["movie-genre-page-1"]
        }

        viewModel.queryDraft = "apollo"
        viewModel.selectedType = .series
        await Task.yield()
        viewModel.loadGenres()

        try await Self.waitUntil {
            await stub.getGenresCallCount(for: .series) == 1
        }

        viewModel.handleSelectedTypeChange()
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.last?.genreId == 28)
        #expect(viewModel.selectedGenre?.id == 28)
        #expect(await stub.getSearchCallCount(for: 1) == 0)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func selectedTypeChangeFromGenreWithCachedGenresRemapsByNameWhenIdDiffers() async throws {
        let stub = GenreBrowseMetadataStub()
        await stub.setGenres(
            [
                Genre(id: 28, name: "Action"),
            ],
            for: .movie
        )
        await stub.setGenres(
            [
                Genre(id: 9999, name: "Action"),
            ],
            for: .series
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "movie-genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["movie-genre-page-1"]
        }

        viewModel.queryDraft = "apollo"
        viewModel.selectedType = .series
        viewModel.loadGenres()

        try await Self.waitUntil {
            await stub.getGenresCallCount(for: .series) == 1
        }

        viewModel.handleSelectedTypeChange()
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.last?.genreId == 9999)
        #expect(viewModel.selectedGenre?.id == 9999)
        #expect(await stub.getSearchCallCount(for: 1) == 0)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func selectedTypeChangeFromGenreWithCachedGenresNoMatchAndEmptyQueryClearsState() async throws {
        let stub = GenreBrowseMetadataStub()
        await stub.setGenres(
            [
                Genre(id: 28, name: "Action"),
            ],
            for: .movie
        )
        await stub.setGenres(
            [
                Genre(id: 9999, name: "Comedy"),
            ],
            for: .series
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "movie-genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["movie-genre-page-1"]
        }

        viewModel.selectedType = .series
        viewModel.loadGenres()

        try await Self.waitUntil {
            await stub.getGenresCallCount(for: .series) == 1
        }

        viewModel.handleSelectedTypeChange()
        try await Self.waitUntil {
            viewModel.selectedGenre == nil && viewModel.results.isEmpty
        }

        #expect(viewModel.activeMoodCard == nil)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(await stub.getSearchCallCount(for: 1) == 0)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func selectedTypeChangeFromRegularMoodCardWithCachedGenresRemapsById() async throws {
        let stub = GenreBrowseMetadataStub()
        await stub.setGenres(
            [
                Genre(id: 28, name: "Action"),
            ],
            for: .movie
        )
        await stub.setGenres(
            [
                Genre(id: 10759, name: "Action & Adventure"),
            ],
            for: .series
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "movie-mood-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let actionCard = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!
        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .movie
        viewModel.selectMoodCard(actionCard)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["movie-mood-page-1"]
        }
        #expect(viewModel.activeMoodCard?.id == "action")
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.queryDraft = "apollo"
        viewModel.selectedType = .series
        viewModel.loadGenres()

        try await Self.waitUntil {
            await stub.getGenresCallCount(for: .series) == 1
        }

        viewModel.handleSelectedTypeChange()
        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.last?.genreId == 10759)
        #expect(viewModel.selectedGenre?.id == 10759)
        #expect(await stub.getSearchCallCount(for: 1) == 0)
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func selectedTypeChangeFromRegularMoodCardWithoutCachedGenresFallsBackToGenreBrowse() async throws {
        let stub = GenreBrowseMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "movie-action-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setGenreDelay(.milliseconds(220), for: .series)

        let actionCard = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedType = .movie
        viewModel.queryDraft = "apollo"
        viewModel.selectMoodCard(actionCard)

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.selectedType = .series
        viewModel.loadGenres()
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.last?.genreId == 10759)
        #expect(viewModel.selectedGenre?.id == 10759)
        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.activeMoodCard?.id == "action")
    }

    @Test
    @MainActor
    func selectedTypeChangeFromRegularMoodCardWithoutCachedGenresCancelsStaleMovieBrowseResult() async throws {
        let stub = GenreBrowseCallSequencerStub()
        await stub.setDefaultDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fallback-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            )
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "movie-action-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 0
        )
        await stub.setDiscoverDelay(.milliseconds(220), forCall: 0)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "series-action-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setDiscoverDelay(.milliseconds(20), forCall: 1)
        await stub.setGenreDelay(.milliseconds(220), for: .series)

        let actionCard = ExploreGenreCatalog.cards.first(where: { $0.id == "action" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedType = .movie
        viewModel.selectMoodCard(actionCard)

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }

        viewModel.selectedType = .series
        viewModel.loadGenres()
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }
        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.count == 2)
        guard discoverCalls.count == 2 else { return }
        #expect(discoverCalls[0].type == .movie)
        #expect(discoverCalls[0].genreId == 28)
        #expect(discoverCalls[1].type == .series)
        #expect(discoverCalls[1].genreId == 10759)
        #expect(viewModel.selectedGenre?.id == 10759)
        #expect(viewModel.activeMoodCard?.id == "action")
        #expect(viewModel.results.map(\.id) == ["series-action-page-1"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.map(\.id) == ["series-action-page-1"])
    }

    @Test
    @MainActor
    func staleGenreLoadMoreResultFromOldTypeIgnoredAfterSelectedTypeChangeRemap() async throws {
        let stub = GenreBrowseCallSequencerStub()
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenres([Genre(id: 10759, name: "Action")], for: .series)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "movie-genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            forCall: 0
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "movie-genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            forCall: 1
        )
        await stub.setDiscoverDelay(.milliseconds(220), forCall: 1)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "series-genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            forCall: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedType = .movie
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["movie-genre-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))

        viewModel.selectedType = .series
        viewModel.loadGenres()
        try await Self.waitUntil {
            await stub.getGenresCallCount(for: .series) == 1
        }
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["series-genre-page-1"]
        }

        try await Task.sleep(for: .milliseconds(260))

        let discoverCalls = await stub.getDiscoverCalls()
        #expect(discoverCalls.count == 3)
        #expect(discoverCalls[0].type == .movie)
        #expect(discoverCalls[0].genreId == 28)
        #expect(discoverCalls[1].type == .movie)
        #expect(discoverCalls[1].genreId == 28)
        #expect(discoverCalls[1].page == 2)
        #expect(discoverCalls[2].type == .series)
        #expect(discoverCalls[2].genreId == 10759)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["series-genre-page-1"])
        #expect(!viewModel.results.contains(where: { $0.id == "movie-genre-page-2" }))
        #expect(viewModel.selectedGenre?.id == 10759)
    }

    @Test
    @MainActor
    func selectedTypeChangeFromSpecialMoodCardWithQueryUsesTextSearchPath() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 2
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(await stub.getSearchCallCount(for: "apollo") == 0)

        viewModel.queryDraft = "apollo"
        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["text-page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            await stub.getSearchCallCount(for: "apollo") == 2
        }

        #expect(await stub.getSearchCallCount(for: "apollo") == 2)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.results.map(\.id) == ["text-page-1", "text-page-2"])
        #expect(!viewModel.results.contains(where: { $0.id == "mood-page-2" }))
    }

    @Test
    @MainActor
    func selectedTypeChangeFromSpecialMoodCardWithEmptyQueryReloadsSpecialCardDiscovery() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(await stub.getSearchCallCount(for: "apollo") == 0)

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(await stub.getSearchCallCount(for: "apollo") == 0)
        #expect(viewModel.results.map(\.id) == ["mood-page-1"])
    }

    @Test
    @MainActor
    func selectedTypeChangeFromSpecialMoodCardWithWhitespaceQueryReloadsSpecialCardDiscovery() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }
        #expect(await stub.getDiscoverCallCount() == 1)

        viewModel.queryDraft = "   "
        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(await stub.getSearchCallCount(for: "apollo") == 0)
        #expect(viewModel.results.map(\.id) == ["mood-page-1"])
    }

    @Test
    @MainActor
    func staleMovieGenreLoadDoesNotOverwriteSeriesGenresAfterTypeChange() async throws {
        let stub = DelayedGenresMetadataStub()
        await stub.setGenres(
            [
                Genre(id: 28, name: "Old Action"),
            ],
            for: .movie
        )
        await stub.setGenres(
            [
                Genre(id: 14, name: "Series Comedy"),
            ],
            for: .series
        )
        await stub.setGenreDelay(.milliseconds(180), for: .movie)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .movie
        viewModel.loadGenres()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.selectedType = .series
        viewModel.loadGenres()

        try await Self.waitUntil {
            viewModel.genres.first?.id == 14
        }

        try await Task.sleep(for: .milliseconds(220))
        #expect(viewModel.genres.map(\.id) == [14])
        #expect(await stub.getGenresCallCount(for: .movie) == 1)
        #expect(await stub.getGenresCallCount(for: .series) == 1)
    }

    @Test
    @MainActor
    func nonCooperativeGenreLoadDoesNotOverwriteSeriesGenresAfterTypeChange() async throws {
        let stub = NonCooperativeGenresMetadataStub()
        await stub.setGenres(
            [
                Genre(id: 28, name: "Old Action"),
            ],
            for: .movie
        )
        await stub.setGenres(
            [
                Genre(id: 14, name: "Series Comedy"),
            ],
            for: .series
        )
        await stub.setGenreDelay(.milliseconds(180), for: .movie)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .movie
        viewModel.loadGenres()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.selectedType = .series
        viewModel.loadGenres()

        try await Self.waitUntil {
            viewModel.genres.map(\.id) == [14]
        }

        try await Task.sleep(for: .milliseconds(220))
        #expect(viewModel.genres.map(\.id) == [14])
        #expect(await stub.getGenresCallCount(for: .movie) == 1)
        #expect(await stub.getGenresCallCount(for: .series) == 1)
    }

    @Test
    @MainActor
    func staleGenreLoadIsCancelledWhenMetadataServiceReconfigured() async throws {
        let oldService = DelayedGenresMetadataStub()
        let newService = DelayedGenresMetadataStub()

        await oldService.setGenres([
            Genre(id: 28, name: "Old Action"),
            Genre(id: 35, name: "Old Comedy"),
        ], for: .movie)
        await oldService.setGenreDelay(.milliseconds(220), for: .movie)

        await newService.setGenres([
            Genre(id: 28, name: "New Action"),
            Genre(id: 12, name: "New Adventure"),
        ], for: .movie)

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                if key == "new-key" { newService }
                return oldService
            }
        )

        viewModel.configure(apiKey: "old-key")
        viewModel.loadGenres()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.configure(apiKey: "new-key")
        viewModel.loadGenres()

        try await Self.waitUntil {
            viewModel.genres.count == 2 && viewModel.genres.contains(where: { $0.name == "New Action" })
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.genres.map(\.id) == [28, 12])
        #expect(await newService.getGenresCallCount(for: .movie) == 1)
    }

    @Test
    @MainActor
    func staleGenreLoadFailureDoesNotOverwriteSeriesGenresAfterTypeChange() async throws {
        let stub = FailingGenresMetadataStub()
        await stub.setGenres(
            [
                Genre(id: 28, name: "Movie Action"),
            ],
            for: .movie
        )
        await stub.setGenres(
            [
                Genre(id: 14, name: "Series Comedy"),
            ],
            for: .series
        )
        await stub.setGenreFailure(true, for: .movie)
        await stub.setGenreDelay(.milliseconds(180), for: .movie)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .movie
        viewModel.loadGenres()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.selectedType = .series
        viewModel.loadGenres()

        try await Self.waitUntil {
            await stub.getGenresCallCount(for: .series) == 1 && viewModel.genres.map(\.id) == [14]
        }

        try await Task.sleep(for: .milliseconds(240))
        #expect(await stub.getGenresCallCount(for: .movie) == 1)
        #expect(await stub.getGenresCallCount(for: .series) == 1)
        #expect(viewModel.genres.map(\.id) == [14])
    }

    @Test
    @MainActor
    func staleSearchErrorDoesNotOverwriteLatestSearchResult() async throws {
        let stub = FailingSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "alpha",
            page: 1
        )
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
        await stub.setSearchFailure(true, for: "alpha", page: 1)
        await stub.setSearchDelay(.milliseconds(220), for: "alpha", page: 1)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "alpha"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.query = "beta"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["beta-page-1"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.map(\.id) == ["beta-page-1"])
        #expect(viewModel.error == nil)
        #expect(await stub.getSearchCallCount() == 2)
    }

    @Test
    @MainActor
    func nonCooperativePaginatedSearchErrorDoesNotOverwriteNewQueryState() async throws {
        let stub = NonCooperativeSearchMetadataStub()
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
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
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
        await stub.setSearchFailure(true, for: "alpha", page: 2)
        await stub.setSearchDelay(.milliseconds(180), for: "alpha", page: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.search(queryText: "beta")
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["beta-page-1"]
        }

        try await Task.sleep(for: .milliseconds(240))
        #expect(viewModel.results.map(\.id) == ["beta-page-1"])
        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
        #expect(await stub.getSearchCallCount(for: 2) == 1)
    }

    @Test
    @MainActor
    func nonCooperativePaginatedSearchResultDoesNotOverwriteNewQueryState() async throws {
        let stub = NonCooperativeSearchMetadataStub()
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
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
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
        await stub.setSearchDelay(.milliseconds(180), for: "alpha", page: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.search(queryText: "beta")
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["beta-page-1"]
        }

        try await Task.sleep(for: .milliseconds(240))
        #expect(viewModel.results.map(\.id) == ["beta-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(!viewModel.results.contains(where: { $0.id == "alpha-page-2" }))
        #expect(await stub.getSearchCallCount(for: 2) == 1)
    }

    @Test
    @MainActor
    func debouncedSearchDoesNotFireAfterClear() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "alpha",
            page: 1
        )
        await stub.setSearchDelay(.milliseconds(220), for: "alpha", page: 1)

        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(120))
        viewModel.debouncedSearch(queryText: "alpha")

        try await Task.sleep(for: .milliseconds(40))
        viewModel.clear()

        #expect(viewModel.query.isEmpty)
        #expect(viewModel.queryDraft.isEmpty)
        #expect(viewModel.results.isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 0)
    }

    @Test
    @MainActor
    func staleGenreBrowseResultFromPreviousMetadataServiceDoesNotOverwritePostConfigureGenreBrowse() async throws {
        let oldService = GenreSearchMetadataStub()
        let newService = GenreSearchMetadataStub()

        await oldService.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await oldService.setDiscoverDelay(.milliseconds(220), for: 1)

        await newService.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                if key == "new-key" { newService }
                return oldService
            }
        )

        let genre = Genre(id: 28, name: "Action")
        viewModel.configure(apiKey: "old-key")
        viewModel.selectGenre(genre)

        try await Task.sleep(for: .milliseconds(20))
        viewModel.configure(apiKey: "new-key")
        viewModel.selectGenre(genre)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["new-genre-page-1"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.map(\.id) == ["new-genre-page-1"])
        #expect(await newService.getDiscoverCallCount() == 1)
        #expect(await oldService.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func clearCancelsInFlightGenreLoadAndLeavesNoStaleGenres() async throws {
        let stub = DelayedGenresMetadataStub()
        await stub.setGenres(
            [Genre(id: 28, name: "Action")],
            for: .movie
        )
        await stub.setGenreDelay(.milliseconds(220), for: .movie)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .movie
        viewModel.loadGenres()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.clear()

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.genres.isEmpty)
        #expect(await stub.getGenresCallCount(for: .movie) == 1)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.genres.isEmpty)
    }

    @Test
    @MainActor
    func inFlightLoadMoreFailureDoesNotSetErrorAfterClear() async throws {
        let stub = FailingSearchMetadataStub()
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
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "alpha",
            page: 2
        )
        await stub.setSearchFailure(true, for: "alpha", page: 2)
        await stub.setSearchDelay(.milliseconds(220), for: "alpha", page: 2)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "alpha"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["alpha-page-1"]
        }
        #expect(await stub.getSearchCallCount(for: 1) == 1)

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))
        viewModel.clear()

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.error == nil)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.error == nil)
        #expect(await stub.getSearchCallCount(for: 2) == 1)
    }

    @Test
    @MainActor
    func nonCooperativeGenreLoadFromReconfiguredServiceDoesNotOverwriteFreshGenres() async throws {
        let oldService = NonCooperativeGenresMetadataStub()
        let newService = NonCooperativeGenresMetadataStub()

        await oldService.setGenres(
            [Genre(id: 1, name: "Old Movie")],
            for: .movie
        )
        await newService.setGenres(
            [Genre(id: 2, name: "New Movie")],
            for: .movie
        )

        await oldService.setGenreDelay(.milliseconds(220), for: .movie)
        await newService.setGenreDelay(.milliseconds(20), for: .movie)

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                key == "new-key" ? newService : oldService
            }
        )

        viewModel.configure(apiKey: "old-key")
        viewModel.selectedType = .movie
        viewModel.loadGenres()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.configure(apiKey: "new-key")
        viewModel.loadGenres()

        try await Self.waitUntil {
            await newService.getGenresCallCount(for: .movie) == 1 && viewModel.genres.map(\.id) == [2]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.genres.map(\.id) == [2])
        #expect(await oldService.getGenresCallCount(for: .movie) == 1)
        #expect(await newService.getGenresCallCount(for: .movie) == 1)
    }

    @Test
    @MainActor
    func nonCooperativeSearchResultFromPreviousMetadataServiceDoesNotOverwriteAfterReconfigure() async throws {
        let oldService = NonCooperativeSearchMetadataStub()
        let newService = NonCooperativeSearchMetadataStub()

        await oldService.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "drama",
            page: 1
        )
        await oldService.setSearchDelay(.milliseconds(220), for: "drama", page: 1)

        await newService.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "drama",
            page: 1
        )

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                key == "new-key" ? newService : oldService
            }
        )
        viewModel.configure(apiKey: "old-key")
        viewModel.query = "drama"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.configure(apiKey: "new-key")

        #expect(await oldService.getSearchCalls().count == 1)
        #expect(await newService.getSearchCalls().isEmpty)
        #expect(viewModel.results.isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.isEmpty)
        #expect(await oldService.getSearchCalls().count == 1)
        #expect(await newService.getSearchCalls().isEmpty)
    }

    @Test
    @MainActor
    func nonCooperativePaginatedSearchResultFromPreviousMetadataServiceDoesNotOverwritePostConfigureSearch() async throws {
        let oldService = NonCooperativeSearchMetadataStub()
        let newService = NonCooperativeSearchMetadataStub()

        await oldService.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "drama",
            page: 1
        )
        await oldService.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "drama",
            page: 2
        )
        await oldService.setSearchDelay(.milliseconds(220), for: "drama", page: 2)

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                if key == "new-key" { newService } else { oldService }
            }
        )

        viewModel.configure(apiKey: "old-key")
        viewModel.query = "drama"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["old-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))
        viewModel.configure(apiKey: "new-key")

        #expect(await oldService.getSearchCallCount(for: 2) == 1)
        #expect(await newService.getSearchCalls().isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.map(\.id) == ["old-page-1"])
        #expect(viewModel.currentPage == 1)
        #expect(await oldService.getSearchCallCount(for: 2) == 1)
        #expect(await newService.getSearchCalls().isEmpty)
    }

    @Test
    @MainActor
    func nonCooperativeSearchResultFromReconfiguredServiceCanWinWhenRefetched() async throws {
        let oldService = NonCooperativeSearchMetadataStub()
        let newService = NonCooperativeSearchMetadataStub()

        await oldService.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "drama",
            page: 1
        )
        await oldService.setSearchDelay(.milliseconds(220), for: "drama", page: 1)

        await newService.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "drama",
            page: 1
        )

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                key == "new-key" ? newService : oldService
            }
        )
        viewModel.configure(apiKey: "old-key")
        viewModel.query = "drama"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.configure(apiKey: "new-key")
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["new-search-result"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.map(\.id) == ["new-search-result"])
        #expect(await oldService.getSearchCalls().count == 1)
        #expect(await newService.getSearchCalls().count == 1)
    }

    @Test
    @MainActor
    func loadMoreNoopWhileInitialSearchIsInFlight() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "search-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 2
        )
        await stub.setSearchDelay(.milliseconds(220), for: "apollo", page: 1)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(40))
        #expect(await stub.getSearchCallCount(for: 1) == 1)
        #expect(await stub.getSearchCallCount(for: 2) == 0)

        try await Self.waitUntil {
            viewModel.currentPage == 1 && viewModel.results.map(\.id) == ["search-page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.currentPage == 2
        }

        #expect(await stub.getSearchCallCount(for: 2) == 1)
        #expect(viewModel.results.map(\.id) == ["search-page-1", "search-page-2"])
    }

    @Test
    @MainActor
    func selectGenreNilWithActiveTextQueryReentersTextSearch() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverDelay(.milliseconds(220), for: 1)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Task.sleep(for: .milliseconds(30))

        viewModel.queryDraft = "apollo"
        viewModel.selectGenre(nil)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["text-page-1"]
        }

        #expect(await stub.getSearchCallCount(for: 1) == 1)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.activeMoodCard == nil)
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func failedSearchErrorClearsOnRetry() async throws {
        let stub = FailingSearchMetadataStub()
        await stub.setSearchFailure(true, for: "apollo", page: 1)
        await stub.setSearchDelay(.milliseconds(160), for: "apollo", page: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "alpha-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.search(queryText: "apollo")

        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(viewModel.results.isEmpty)

        await stub.setSearchFailure(false, for: "apollo", page: 1)
        viewModel.search(queryText: "apollo")

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["alpha-page-1"]
        }

        #expect(viewModel.error == nil)
        #expect(await stub.getSearchCallCount(for: 1) == 2)
    }

    @Test
    @MainActor
    func textSearchLoadMoreFailureCanBeRetried() async throws {
        let stub = FailingSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchFailure(true, for: "apollo", page: 2)
        await stub.setSearchDelay(.milliseconds(220), for: "apollo", page: 2)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(viewModel.currentPage == 1)

        await stub.setSearchFailure(false, for: "apollo", page: 2)
        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.currentPage == 2
        }

        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["page-1", "page-2"])
        #expect(await stub.getSearchCallCount(for: 2) == 2)
    }

    @Test
    @MainActor
    func genreLoadMoreFailureCanBeRetried() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverFailure(true, for: 2)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.selectedGenre?.id == 28)

        await stub.setDiscoverFailure(false, for: 2)
        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.currentPage == 2
        }

        #expect(viewModel.error == nil)
        #expect(viewModel.results.map(\.id) == ["genre-page-1", "genre-page-2"])
        #expect(await stub.getDiscoverCallCount(for: 2) == 2)
    }

    @Test
    @MainActor
    func retryAfterSearchLoadMoreFailureRequeriesSearchPath() async throws {
        let stub = FailingSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchFailure(true, for: "apollo", page: 2)
        await stub.setSearchDelay(.milliseconds(220), for: "apollo", page: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.search(queryText: "apollo")
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(viewModel.currentPage == 1)
        #expect(await stub.getSearchCallCount(for: 2) == 1)

        viewModel.retry()
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["page-1"]
        }

        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
        #expect(await stub.getSearchCallCount(for: 1) == 2)
        #expect(await stub.getSearchCallCount(for: 2) == 1)
    }

    @Test
    @MainActor
    func retryAfterGenreLoadMoreFailureRequeriesGenreBrowse() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverFailure(true, for: 2)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(viewModel.currentPage == 1)
        #expect(await stub.getDiscoverCallCount(for: 2) == 1)

        viewModel.retry()
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
        #expect(await stub.getDiscoverCallCount(for: 1) == 2)
        #expect(await stub.getDiscoverCallCount(for: 2) == 1)
    }

    @Test
    @MainActor
    func retryAfterSpecialMoodLoadMoreFailureRequeriesMoodDiscovery() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverFailure(true, for: 2)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(await stub.getDiscoverCallCount(for: 2) == 1)

        viewModel.retry()
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }

        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.activeMoodCard?.id == "new")
        #expect(await stub.getDiscoverCallCount(for: 1) == 2)
        #expect(await stub.getDiscoverCallCount(for: 2) == 1)
    }

    @Test
    @MainActor
    func loadGenresForSameTypeDuringFlightDoesNotDuplicateRequest() async throws {
        let stub = GenreBrowseMetadataStub()
        await stub.setGenres(
            [Genre(id: 28, name: "Action"), Genre(id: 35, name: "Comedy")],
            for: .movie
        )
        await stub.setGenreDelay(.milliseconds(220), for: .movie)

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedType = .movie
        viewModel.loadGenres()
        viewModel.loadGenres()

        try await Self.waitUntil {
            await stub.getGenresCallCount(for: .movie) == 1
        }

        #expect(await stub.getGenresCallCount(for: .movie) == 1)
        #expect(viewModel.genres.map(\.id) == [28, 35])
    }

    @Test
    @MainActor
    func loadGenresWithoutMetadataServiceIsNoop() async throws {
        let viewModel = SearchViewModel()

        viewModel.loadGenres()

        try await Task.yield()
        #expect(viewModel.genres.isEmpty)
    }

    @Test
    @MainActor
    func searchWithoutServiceInFlightPathPreservesState() async throws {
        let viewModel = SearchViewModel()
        viewModel.query = "apollo"
        viewModel.results = [Fixtures.mediaPreview(id: "existing-page-1")]
        viewModel.currentPage = 1
        viewModel.totalPages = 2

        viewModel.search()
        #expect(viewModel.error == .tmdbSetupRequired(feature: "Search"))
        #expect(viewModel.submittedQuery == "apollo")
        #expect(viewModel.query == "apollo")
        #expect(viewModel.queryDraft == "apollo")
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func loadMoreWithoutServiceDoesNotMutateState() async throws {
        let viewModel = SearchViewModel()
        viewModel.results = [Fixtures.mediaPreview(id: "existing-page-1")]
        viewModel.currentPage = 1
        viewModel.totalPages = 2
        viewModel.query = "apollo"

        viewModel.loadMore()

        try await Task.yield()
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 2)
        #expect(viewModel.results.map(\.id) == ["existing-page-1"])
        #expect(viewModel.hasMore == true)
        #expect(viewModel.isSearching == false)
    }

    @Test
    @MainActor
    func debouncedSearchAfterMetadataServiceReconfigureExecutesOnlyLatestService() async throws {
        let oldService = DebouncedSearchMetadataStub()
        let newService = DebouncedSearchMetadataStub()

        await oldService.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-debounced")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )
        await newService.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-debounced")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                key == "new-key" ? newService : oldService
            },
            debounceInterval: .milliseconds(120)
        )

        viewModel.configure(apiKey: "old-key")
        viewModel.debouncedSearch(queryText: "apollo")
        try await Task.sleep(for: .milliseconds(20))

        viewModel.configure(apiKey: "new-key")
        viewModel.debouncedSearch(queryText: "apollo")

        try await Self.waitUntil {
            await newService.getSearchCallCount() == 1
        }

        #expect(await newService.getSearchCallCount() == 1)
        #expect(await oldService.getSearchCallCount() == 0)
        #expect(viewModel.results.map(\.id) == ["new-debounced"])
    }

    @Test
    @MainActor
    func configureWithEquivalentApiKeyIsNoopAndDoesNotRestartInFlightSearch() async throws {
        let service = DebouncedSearchMetadataStub()
        await service.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "apollo-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )
        await service.setSearchDelay(.milliseconds(180), for: "apollo", page: 1)

        let viewModel = SearchViewModel(
            metadataServiceFactory: { _ in
                service
            }
        )

        viewModel.configure(apiKey: "  old-key ")
        #expect(await service.getSearchCallCount(for: 1) == 0)

        viewModel.search(queryText: "apollo")
        try await Task.sleep(for: .milliseconds(20))
        #expect(await service.getSearchCallCount(for: 1) == 1)

        viewModel.configure(apiKey: "old-key")
        #expect(await service.getSearchCallCount(for: 1) == 1)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["apollo-page-1"]
        }

        #expect(viewModel.results.map(\.id) == ["apollo-page-1"])
        #expect(await service.getSearchCallCount(for: 1) == 1)
    }

    @Test
    @MainActor
    func configureWhitespaceOnlyOnInjectedServicePreservesServiceAndSearchStillWorks() async throws {
        let service = DebouncedSearchMetadataStub()
        await service.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "injected-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: service)
        viewModel.configure(apiKey: "   ")
        viewModel.search(queryText: "apollo")

        try await Self.waitUntil {
            await service.getSearchCallCount(for: 1) == 1
        }

        #expect(await service.getSearchCallCount(for: 1) == 1)
        #expect(viewModel.results.map(\.id) == ["injected-page-1"])
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func debouncedSearchDefaultsToQueryDraftWhenNilArgument() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "draft-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(80))
        viewModel.queryDraft = "  apollo "
        viewModel.debouncedSearch()

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 1
        }

        #expect(await stub.getSearchCalls() == ["apollo"])
        #expect(viewModel.results.map(\.id) == ["draft-result"])
        #expect(viewModel.results.count == 1)
    }

    @Test
    @MainActor
    func debouncedSearchFromEmptyQueryDraftDoesNothing() async throws {
        let stub = DebouncedSearchMetadataStub()
        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(80))

        viewModel.queryDraft = "   "
        viewModel.debouncedSearch()

        try await Task.sleep(for: .milliseconds(150))

        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    @MainActor
    func configureWhitespaceOnlyApiKeyCancelsActiveSearchWork() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "apollo-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchDelay(.milliseconds(220), for: "apollo", page: 1)

        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(120))
        viewModel.configure(apiKey: "old-key")
        viewModel.search(queryText: "apollo")

        try await Task.sleep(for: .milliseconds(20))
        viewModel.configure(apiKey: "   ")

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.error == nil)

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(await stub.getSearchCallCount(for: 1) == 1)
    }

    @Test
    @MainActor
    func debouncedSearchCancelledByClearingApiKey() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "apollo-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, debounceInterval: .milliseconds(120))
        viewModel.configure(apiKey: "old-key")
        viewModel.debouncedSearch(queryText: "apollo")
        try await Task.sleep(for: .milliseconds(40))

        viewModel.configure(apiKey: " ")
        try await Task.sleep(for: .milliseconds(200))

        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.error == nil)
    }

    @Test
    @MainActor
    func configureWhitespaceOnlyWhileGenresLoadInFlightClearsGenres() async throws {
        let stub = DelayedGenresMetadataStub()
        await stub.setGenres([Genre(id: 28, name: "Action")], for: .movie)
        await stub.setGenreDelay(.milliseconds(220), for: .movie)

        let viewModel = SearchViewModel(
            metadataServiceFactory: { _ in stub },
            debounceInterval: .milliseconds(120)
        )
        viewModel.configure(apiKey: "api-key")
        viewModel.selectedType = .movie
        viewModel.loadGenres()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.configure(apiKey: " ")

        #expect(viewModel.genres.isEmpty)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getGenresCallCount(for: .movie) == 1)
        #expect(viewModel.genres.isEmpty)
    }

    @Test
    @MainActor
    func configureWhitespaceOnlyDuringGenreBrowseKeepsStaleLoadMoreFromMutatingState() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverDelay(.milliseconds(20), for: 1)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )
        await stub.setDiscoverDelay(.milliseconds(240), for: 2)

        let viewModel = SearchViewModel(
            metadataServiceFactory: { _ in stub },
            paginationCooldown: .milliseconds(0)
        )
        viewModel.configure(apiKey: "old-key")
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))

        viewModel.configure(apiKey: "  ")
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.error == nil)

        try await Task.sleep(for: .milliseconds(280))
        #expect(await stub.getDiscoverCallCount(for: 2) == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func configureToNewServiceWhileGenreLoadMoreInFlightKeepsOnlyLatestBrowseContext() async throws {
        let oldService = GenreSearchMetadataStub()
        let newService = GenreSearchMetadataStub()

        await oldService.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await oldService.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )
        await oldService.setDiscoverDelay(.milliseconds(240), for: 2)

        await newService.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await newService.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )

        let viewModel = SearchViewModel(
            metadataServiceFactory: { key in
                key == "new-key" ? newService : oldService
            },
            paginationCooldown: .milliseconds(0)
        )

        viewModel.configure(apiKey: "old-key")
        viewModel.selectedType = .movie
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["old-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))
        viewModel.configure(apiKey: "new-key")
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["new-page-1"]
        }

        try await Task.sleep(for: .milliseconds(280))
        #expect(await oldService.getDiscoverCallCount(for: 2) == 1)
        #expect(await newService.getDiscoverCallCount(for: 1) == 1)
        #expect(await newService.getDiscoverCallCount(for: 2) == 0)
        #expect(viewModel.results.map(\.id) == ["new-page-1"])
    }

    @Test
    @MainActor
    func configureWhitespaceOnlyWhileSpecialMoodPaginationInFlightClearsMoodState() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: 2
        )
        await stub.setDiscoverDelay(.milliseconds(20), for: 1)
        await stub.setDiscoverDelay(.milliseconds(240), for: 2)

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(
            metadataServiceFactory: { _ in stub },
            paginationCooldown: .milliseconds(0)
        )
        viewModel.configure(apiKey: "old-key")
        viewModel.selectMoodCard(newReleasesCard)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))

        viewModel.configure(apiKey: "  ")
        #expect(viewModel.activeMoodCard == nil)
        #expect(viewModel.selectedGenre == nil)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)

        try await Task.sleep(for: .milliseconds(280))
        #expect(await stub.getDiscoverCallCount(for: 2) == 1)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.activeMoodCard == nil)
    }

    @Test
    @MainActor
    func filterDraftUpdateCancelsStaleSearchResultsWhenRequeryReplacesInFlightSearch() async throws {
        actor SearchFilterRaceStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var searchCalls = 0

            private let defaultResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int {
                searchCalls
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = SearchFilterRaceStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fresh-search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "apollo"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applySortOption(.ratingDesc)

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["fresh-search-result"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["fresh-search-result"])
        #expect(!viewModel.results.contains(where: { $0.id == "stale-search-result" }))
    }

    @Test
    @MainActor
    func filterChangeRequeryAfterGenreSelectionKeepsNewestDiscoverResult() async throws {
        actor GenreFilterRaceStub: MetadataProvider {
            private var discoverResultByCall: [Int: MetadataSearchResult] = [:]
            private var discoverDelayByCall: [Int: Duration] = [:]
            private var discoverCalls = 0

            private let defaultResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setDiscoverResult(_ result: MetadataSearchResult, forCall call: Int) {
                discoverResultByCall[call] = result
            }

            func setDiscoverDelay(_ delay: Duration, forCall call: Int) {
                discoverDelayByCall[call] = delay
            }

            func getDiscoverCallCount() -> Int {
                discoverCalls
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
            }

            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
                discoverCalls += 1
                let call = discoverCalls
                if let delay = discoverDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return discoverResultByCall[call] ?? defaultResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = GenreFilterRaceStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-stale")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setDiscoverDelay(.milliseconds(220), forCall: 1)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-fresh")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.browseGenre(viewModel.selectedGenre!)

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applyYearFilter(2024)

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }

        #expect(viewModel.results.map(\.id) == ["genre-page-fresh"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["genre-page-fresh"])
        #expect(!viewModel.results.contains(where: { $0.id == "genre-page-stale" }))
    }

    @Test
    @MainActor
    func filterDraftGenreSelectionCancelsInFlightSearchAndKeepsLatestGenreBrowseResult() async throws {
        actor SearchToGenreFilterDraftStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var discoverResultByCall: [Int: MetadataSearchResult] = [:]
            private var discoverDelayByCall: [Int: Duration] = [:]
            private var searchCalls = 0
            private var discoverCalls = 0
            private let defaultSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
            private let defaultDiscoverResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func setDiscoverResult(_ result: MetadataSearchResult, forCall call: Int) {
                discoverResultByCall[call] = result
            }

            func setDiscoverDelay(_ delay: Duration, forCall call: Int) {
                discoverDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int { searchCalls }
            func getDiscoverCallCount() -> Int { discoverCalls }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultSearchResult
            }

            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
                discoverCalls += 1
                let call = discoverCalls
                if let delay = discoverDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return discoverResultByCall[call] ?? defaultDiscoverResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = SearchToGenreFilterDraftStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-search-page")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-latest")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        let draft = SearchFilterDraft(
            sortOption: .popularityDesc,
            selectedYear: nil,
            selectedLanguages: ["en-US"],
            selectedGenre: Genre(id: 28, name: "Action")
        )
        viewModel.applyFilterDraft(draft)

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(viewModel.results.map(\.id) == ["genre-page-latest"])
        #expect(viewModel.selectedGenre?.id == 28)

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 1)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.results.map(\.id) == ["genre-page-latest"])
        #expect(!viewModel.results.contains(where: { $0.id == "stale-search-page" }))
    }

    @Test
    @MainActor
    func staleSearchResultFromLanguageFilterChangeDoesNotOverwriteLatestSearch() async throws {
        actor SearchLanguageRaceStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var searchCalls = 0
            private let defaultSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int { searchCalls }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultSearchResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = SearchLanguageRaceStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-language-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "new-language-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "apollo"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applyLanguageFilters(["fr-FR"])

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["new-language-result"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["new-language-result"])
        #expect(!viewModel.results.contains(where: { $0.id == "old-language-result" }))
    }

    @Test
    @MainActor
    func staleGenreBrowseResultFromLanguageFilterChangeKeepsLatestDiscoverContext() async throws {
        actor GenreLanguageRaceStub: MetadataProvider {
            private var discoverResultByCall: [Int: MetadataSearchResult] = [:]
            private var discoverDelayByCall: [Int: Duration] = [:]
            private var discoverCalls = 0
            private let defaultDiscoverResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setDiscoverResult(_ result: MetadataSearchResult, forCall call: Int) {
                discoverResultByCall[call] = result
            }

            func setDiscoverDelay(_ delay: Duration, forCall call: Int) {
                discoverDelayByCall[call] = delay
            }

            func getDiscoverCallCount() -> Int {
                discoverCalls
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
            }

            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
                discoverCalls += 1
                let call = discoverCalls
                if let delay = discoverDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return discoverResultByCall[call] ?? defaultDiscoverResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = GenreLanguageRaceStub()
        let staleGenrePage = MetadataSearchResult(
            items: [Fixtures.mediaPreview(id: "genre-stale-language")],
            page: 1,
            totalPages: 1,
            totalResults: 1
        )
        let freshGenrePage = MetadataSearchResult(
            items: [Fixtures.mediaPreview(id: "genre-fresh-language")],
            page: 1,
            totalPages: 1,
            totalResults: 1
        )
        await stub.setDiscoverResult(staleGenrePage, forCall: 1)
        await stub.setDiscoverDelay(.milliseconds(220), forCall: 1)
        await stub.setDiscoverResult(freshGenrePage, forCall: 2)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applyLanguageFilters(["fr-FR"])

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["genre-fresh-language"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["genre-fresh-language"])
        #expect(!viewModel.results.contains(where: { $0.id == "genre-stale-language" }))
    }

    @Test
    @MainActor
    func applyUnchangedFilterDraftDoesNotTriggerRequery() async throws {
        actor FilterDraftNoopStub: MetadataProvider {
            private var discoverResultByCall: [Int: MetadataSearchResult] = [:]
            private var discoverCalls = 0
            private var searchCalls = 0
            private let defaultResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setDiscoverResult(_ result: MetadataSearchResult, forCall call: Int) {
                discoverResultByCall[call] = result
            }

            func getDiscoverCallCount() -> Int {
                discoverCalls
            }

            func getSearchCallCount() -> Int {
                searchCalls
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                searchCalls += 1
                return defaultResult
            }

            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
                discoverCalls += 1
                return discoverResultByCall[discoverCalls] ?? defaultResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = FilterDraftNoopStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.selectGenre(viewModel.selectedGenre)

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(await stub.getSearchCallCount() == 0)
        #expect(viewModel.selectedGenre?.id == 28)

        let discoverCallsBeforeDraftChange = await stub.getDiscoverCallCount()
        let currentDraft = viewModel.currentFilterDraft
        viewModel.applyFilterDraft(currentDraft)

        try await Task.sleep(for: .milliseconds(180))
        #expect(await stub.getSearchCallCount() == 0)
        #expect(await stub.getDiscoverCallCount() == discoverCallsBeforeDraftChange)
    }

    @Test
    @MainActor
    func staleSearchResultFromSortChangeDoesNotOverwriteLatestSearch() async throws {
        actor SearchSortRaceStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var searchCalls = 0

            private let defaultSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int {
                searchCalls
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultSearchResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = SearchSortRaceStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-sort-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fresh-sort-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "apollo"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applySortOption(.ratingDesc)

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["fresh-sort-result"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["fresh-sort-result"])
        #expect(!viewModel.results.contains(where: { $0.id == "stale-sort-result" }))
    }

    @Test
    @MainActor
    func staleSearchResultFromYearFilterChangeDoesNotOverwriteLatestSearch() async throws {
        actor SearchYearFilterRaceStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var searchCalls = 0

            private let defaultSearchResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int {
                searchCalls
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultSearchResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = SearchYearFilterRaceStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-year-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fresh-year-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "apollo"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applyYearFilter(2024)

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["fresh-year-result"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["fresh-year-result"])
        #expect(!viewModel.results.contains(where: { $0.id == "stale-year-result" }))
    }

    @Test
    @MainActor
    func staleSearchResultFromYearRangePresetChangeDoesNotOverwriteLatestSearch() async throws {
        actor SearchYearRangePresetRaceStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var searchCalls = 0
            private var usedYears: [Int?] = []

            private let defaultResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int {
                searchCalls
            }

            func getUsedYears() -> [Int?] {
                usedYears
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                try await search(query: query, type: type, page: page, year: nil, language: nil)
            }

            func search(query: String, type: MediaType?, page: Int, year: Int?, language: String?) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                usedYears.append(year)
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = SearchYearRangePresetRaceStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-year-range-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fresh-year-range-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "apollo"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applyYearRangePreset(.twenties)

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["fresh-year-range-result"])
        #expect(await stub.getUsedYears() == [nil, 2020])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["fresh-year-range-result"])
        #expect(!viewModel.results.contains(where: { $0.id == "stale-year-range-result" }))
    }

    @Test
    @MainActor
    func staleSearchResultFromTogglingYearRangePresetKeepsLatestSearch() async throws {
        actor SearchYearRangePresetToggleStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var searchCalls = 0
            private var usedYears: [Int?] = []

            private let defaultResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int {
                searchCalls
            }

            func getUsedYears() -> [Int?] {
                usedYears
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                try await search(query: query, type: type, page: page, year: nil, language: nil)
            }

            func search(query: String, type: MediaType?, page: Int, year: Int?, language: String?) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                usedYears.append(year)
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = SearchYearRangePresetToggleStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-range-on-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fresh-range-off-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let viewModel = SearchViewModel(metadataService: stub)
        viewModel.query = "apollo"

        viewModel.applyYearRangePreset(.twenties)
        try await Task.sleep(for: .milliseconds(20))
        viewModel.applyYearRangePreset(.twenties)

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["fresh-range-off-result"])
        #expect(await stub.getUsedYears() == [2020, nil])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["fresh-range-off-result"])
        #expect(!viewModel.results.contains(where: { $0.id == "stale-range-on-result" }))
    }

    @Test
    @MainActor
    func staleGenreBrowseResultFromYearRangePresetChangeDoesNotOverwriteLatestGenreBrowse() async throws {
        actor GenreYearRangePresetRaceStub: MetadataProvider {
            private var discoverResultByCall: [Int: MetadataSearchResult] = [:]
            private var discoverDelayByCall: [Int: Duration] = [:]
            private var discoverCalls = 0
            private var usedYears: [Int?] = []

            private let defaultDiscoverResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setDiscoverResult(_ result: MetadataSearchResult, forCall call: Int) {
                discoverResultByCall[call] = result
            }

            func setDiscoverDelay(_ delay: Duration, forCall call: Int) {
                discoverDelayByCall[call] = delay
            }

            func getDiscoverCallCount() -> Int {
                discoverCalls
            }

            func getUsedYears() -> [Int?] {
                usedYears
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0)
            }

            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
                discoverCalls += 1
                let call = discoverCalls
                usedYears.append(filters.year)
                if let delay = discoverDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return discoverResultByCall[call] ?? defaultDiscoverResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = GenreYearRangePresetRaceStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-genre-year-preset-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setDiscoverDelay(.milliseconds(220), forCall: 1)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fresh-genre-year-preset-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.selectGenre(viewModel.selectedGenre)

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applyYearRangePreset(.twenties)

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["fresh-genre-year-preset-result"])
        #expect(await stub.getUsedYears() == [nil, 2020])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 2)
        #expect(viewModel.results.map(\.id) == ["fresh-genre-year-preset-result"])
        #expect(!viewModel.results.contains(where: { $0.id == "stale-genre-year-preset-result" }))
    }

    @Test
    @MainActor
    func staleSearchResultFromSpecialMoodSortChangeDoesNotOverwriteLatestQuerySearch() async throws {
        actor SpecialMoodSortRaceStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var discoverResultByCall: [Int: MetadataSearchResult] = [:]
            private var discoverDelayByCall: [Int: Duration] = [:]
            private var searchCalls = 0
            private var discoverCalls = 0

            private let defaultResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func setDiscoverResult(_ result: MetadataSearchResult, forCall call: Int) {
                discoverResultByCall[call] = result
            }

            func setDiscoverDelay(_ delay: Duration, forCall call: Int) {
                discoverDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int {
                searchCalls
            }

            func getDiscoverCallCount() -> Int {
                discoverCalls
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
                discoverCalls += 1
                let call = discoverCalls
                if let delay = discoverDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return discoverResultByCall[call] ?? defaultResult
            }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = SpecialMoodSortRaceStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-mood-page")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setDiscoverDelay(.milliseconds(300), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-sort-search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fresh-sort-search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)

        try await Self.waitUntil {
            await stub.getDiscoverCallCount() == 1
        }
        #expect(await stub.getSearchCallCount() == 0)

        viewModel.query = "apollo"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applySortOption(.ratingDesc)

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(viewModel.results.map(\.id) == ["fresh-sort-search-result"])

        try await Task.sleep(for: .milliseconds(280))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.results.map(\.id) == ["fresh-sort-search-result"])
        #expect(!viewModel.results.contains(where: { $0.id == "stale-sort-search-result" }))
        #expect(!viewModel.results.contains(where: { $0.id == "stale-mood-page" }))
    }

    @Test
    @MainActor
    func staleSearchResultFromSpecialMoodLanguageChangeDoesNotOverwriteLatestQuerySearch() async throws {
        actor SpecialMoodLanguageRaceStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var discoverResultByCall: [Int: MetadataSearchResult] = [:]
            private var discoverDelayByCall: [Int: Duration] = [:]
            private var usedLanguages: [String?] = []
            private var searchCalls = 0
            private var discoverCalls = 0

            private let defaultResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func setDiscoverResult(_ result: MetadataSearchResult, forCall call: Int) {
                discoverResultByCall[call] = result
            }

            func setDiscoverDelay(_ delay: Duration, forCall call: Int) {
                discoverDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int {
                searchCalls
            }

            func getDiscoverCallCount() -> Int {
                discoverCalls
            }

            func getUsedLanguages() -> [String?] {
                usedLanguages
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                try await search(query: query, type: type, page: page, year: nil, language: nil)
            }

            func search(query: String, type: MediaType?, page: Int, year: Int?, language: String?) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                usedLanguages.append(language)
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
                discoverCalls += 1
                let call = discoverCalls
                if let delay = discoverDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return discoverResultByCall[call] ?? defaultResult
            }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = SpecialMoodLanguageRaceStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-mood-language-page")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setDiscoverDelay(.milliseconds(300), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "old-language-search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fresh-language-search-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        viewModel.query = "apollo"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applyLanguageFilters(["fr-FR"])

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(await stub.getUsedLanguages() == [nil, "fr-FR"])
        #expect(viewModel.results.map(\.id) == ["fresh-language-search-result"])

        try await Task.sleep(for: .milliseconds(280))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.results.map(\.id) == ["fresh-language-search-result"])
        #expect(!viewModel.results.contains(where: { $0.id == "old-language-search-result" }))
        #expect(!viewModel.results.contains(where: { $0.id == "stale-mood-language-page" }))
    }

    @Test
    @MainActor
    func staleSearchResultFromSpecialMoodYearRangePresetChangeDoesNotOverwriteLatestQuerySearch() async throws {
        actor SpecialMoodYearRangePresetRaceStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var discoverResultByCall: [Int: MetadataSearchResult] = [:]
            private var discoverDelayByCall: [Int: Duration] = [:]
            private var usedYears: [Int?] = []
            private var searchCalls = 0
            private var discoverCalls = 0

            private let defaultResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func setDiscoverResult(_ result: MetadataSearchResult, forCall call: Int) {
                discoverResultByCall[call] = result
            }

            func setDiscoverDelay(_ delay: Duration, forCall call: Int) {
                discoverDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int {
                searchCalls
            }

            func getDiscoverCallCount() -> Int {
                discoverCalls
            }

            func getUsedYears() -> [Int?] {
                usedYears
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                try await search(query: query, type: type, page: page, year: nil, language: nil)
            }

            func search(query: String, type: MediaType?, page: Int, year: Int?, language: String?) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                usedYears.append(year)
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
                discoverCalls += 1
                let call = discoverCalls
                if let delay = discoverDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return discoverResultByCall[call] ?? defaultResult
            }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = SpecialMoodYearRangePresetRaceStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-mood-year-preset-page")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setDiscoverDelay(.milliseconds(300), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-mood-year-preset-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fresh-mood-year-preset-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)
        viewModel.query = "apollo"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.applyYearRangePreset(.twenties)

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 2
        }
        #expect(await stub.getUsedYears() == [nil, 2020])
        #expect(viewModel.results.map(\.id) == ["fresh-mood-year-preset-result"])

        try await Task.sleep(for: .milliseconds(280))
        #expect(await stub.getSearchCallCount() == 2)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.results.map(\.id) == ["fresh-mood-year-preset-result"])
        #expect(!viewModel.results.contains(where: { $0.id == "stale-mood-year-preset-result" }))
        #expect(!viewModel.results.contains(where: { $0.id == "stale-mood-year-preset-page" }))
    }

    @Test
    @MainActor
    func staleSearchResultFromToggleLanguageDoesNotOverwriteLatestSearch() async throws {
        actor ToggleLanguageRaceStub: MetadataProvider {
            private var searchResultByCall: [Int: MetadataSearchResult] = [:]
            private var searchDelayByCall: [Int: Duration] = [:]
            private var usedLanguages: [String?] = []
            private var searchCalls = 0

            private let defaultResult = MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)

            func setSearchResult(_ result: MetadataSearchResult, forCall call: Int) {
                searchResultByCall[call] = result
            }

            func setSearchDelay(_ delay: Duration, forCall call: Int) {
                searchDelayByCall[call] = delay
            }

            func getSearchCallCount() -> Int {
                searchCalls
            }

            func getUsedLanguages() -> [String?] {
                usedLanguages
            }

            func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
                try await search(query: query, type: type, page: page, year: nil, language: nil)
            }

            func search(query: String, type: MediaType?, page: Int, year: Int?, language: String?) async throws -> MetadataSearchResult {
                searchCalls += 1
                let call = searchCalls
                usedLanguages.append(language)
                if let delay = searchDelayByCall[call] {
                    try await Task.sleep(for: delay)
                }
                return searchResultByCall[call] ?? defaultResult
            }

            func getDetail(id: String, type: MediaType) async throws -> MediaItem { fatalError("unused") }
            func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: page, totalPages: page, totalResults: 0) }
            func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult { MetadataSearchResult(items: [], page: filters.page, totalPages: filters.page, totalResults: 0) }
            func getGenres(type: MediaType) async throws -> [Genre] { [] }
            func getSeasons(tmdbId: Int) async throws -> [Season] { [] }
            func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { [] }
            func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds { ExternalIds(imdbId: nil, tvdbId: nil) }
        }

        let stub = ToggleLanguageRaceStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "stale-toggle-language-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 1
        )
        await stub.setSearchDelay(.milliseconds(220), forCall: 1)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "fr-language-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "default-language-result")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 3
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.query = "apollo"
        viewModel.search()

        try await Task.sleep(for: .milliseconds(20))
        viewModel.toggleLanguage("fr-FR")
        viewModel.toggleLanguage("fr-FR")

        try await Self.waitUntil {
            await stub.getSearchCallCount() == 3
        }
        #expect(await stub.getUsedLanguages() == [nil, "fr-FR", nil])
        #expect(viewModel.results.map(\.id) == ["default-language-result"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount() == 3)
        #expect(!viewModel.results.contains(where: { $0.id == "stale-toggle-language-result" }))
        #expect(!viewModel.results.contains(where: { $0.id == "fr-language-result" }))
    }

    @Test
    @MainActor
    func specialMoodLoadMoreInFlightIsIgnoredAfterTypeChangeToSeries() async throws {
        let stub = GenreBrowseCallSequencerStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "movie-mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            forCall: 0
        )
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "movie-mood-page-2-stale")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            forCall: 1
        )
        await stub.setDiscoverDelay(.milliseconds(220), forCall: 1)
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "series-mood-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            forCall: 2
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["movie-mood-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))

        viewModel.selectedType = .series
        viewModel.handleSelectedTypeChange()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["series-mood-page-1"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getDiscoverCallCount() == 3)
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.results.map(\.id) == ["series-mood-page-1"])
        #expect(!viewModel.results.contains(where: { $0.id == "movie-mood-page-2-stale" }))
    }

    @Test
    @MainActor
    func debouncedSearchFromGenreContextDoesNotApplyAfterQueryIsCleared() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchDelay(.milliseconds(220), for: "apollo", page: 1)

        let viewModel = SearchViewModel(
            metadataService: stub,
            debounceInterval: .milliseconds(150)
        )
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.queryDraft = "apollo"
        viewModel.debouncedSearch()

        try await Task.sleep(for: .milliseconds(40))
        viewModel.queryDraft = "   "
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])

        try await Task.sleep(for: .milliseconds(260))
        #expect(await stub.getSearchCallCount(for: "apollo") == 0)
        #expect(viewModel.results.map(\.id) == ["genre-page-1"])
        #expect(viewModel.submittedQuery == "")
        #expect(viewModel.query.isEmpty)
        #expect(viewModel.currentPage == 1)
    }

    @Test
    @MainActor
    func staleSpecialMoodLoadMoreFailureIgnoredAfterSwitchingToTextSearch() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "mood-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setDiscoverFailure(true, for: 2)
        await stub.setDiscoverDelay(.milliseconds(220), for: 2)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )

        let newReleasesCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!
        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectMoodCard(newReleasesCard)

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["mood-page-1"]
        }

        viewModel.loadMore()
        try await Task.sleep(for: .milliseconds(20))
        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["text-page-1"]
        }

        try await Task.sleep(for: .milliseconds(260))
        #expect(viewModel.error == nil)
        #expect(viewModel.currentPage == 1)
        #expect(await stub.getSearchCallCount(for: "apollo") == 1)
        #expect(await stub.getDiscoverCallCount(for: 2) == 1)
        #expect(viewModel.results.map(\.id) == ["text-page-1"])
        #expect(!viewModel.results.contains(where: { $0.id == "mood-page-1" }))
    }

    @Test
    @MainActor
    func retryAfterSearchFailureInGenreContextRequeriesSearchPath() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 1,
                totalResults: 1
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchFailure(true, for: "apollo", page: 1)
        await stub.setSearchDelay(.milliseconds(220), for: "apollo", page: 1)

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.query = "apollo"
        viewModel.search()

        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(await stub.getSearchCallCount(for: 1) == 1)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.results.isEmpty)

        await stub.setSearchFailure(false, for: "apollo", page: 1)
        viewModel.retry()

        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["text-page-1"]
        }

        #expect(viewModel.error == nil)
        #expect(await stub.getSearchCallCount(for: "apollo") == 2)
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func retryAfterSearchLoadMoreFailureInGenreContextRequeriesSearchPath() async throws {
        let stub = GenreSearchMetadataStub()
        await stub.setDiscoverResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "genre-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-1")],
                page: 1,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchFailure(true, for: "apollo", page: 2)
        await stub.setSearchDelay(.milliseconds(220), for: "apollo", page: 2)
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "text-page-2")],
                page: 2,
                totalPages: 2,
                totalResults: 2
            ),
            for: "apollo",
            page: 2
        )

        let viewModel = SearchViewModel(metadataService: stub, paginationCooldown: .milliseconds(0))
        viewModel.selectGenre(Genre(id: 28, name: "Action"))
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["genre-page-1"]
        }

        viewModel.query = "apollo"
        viewModel.search()
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["text-page-1"]
        }

        viewModel.loadMore()
        try await Self.waitUntil {
            viewModel.error != nil
        }
        #expect(await stub.getSearchCallCount(for: "apollo") == 2)
        #expect(await stub.getDiscoverCallCount() == 1)
        #expect(viewModel.currentPage == 1)

        viewModel.retry()
        try await Self.waitUntil {
            viewModel.results.map(\.id) == ["text-page-1"]
        }

        #expect(viewModel.currentPage == 1)
        #expect(viewModel.error == nil)
        #expect(await stub.getSearchCallCount(for: "apollo") == 3)
        #expect(await stub.getDiscoverCallCount() == 1)
    }

    @Test
    @MainActor
    func loadMoreIsBlockedByPageLimitAtHardCap() async throws {
        let stub = DebouncedSearchMetadataStub()
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "page-1")],
                page: 1,
                totalPages: 600,
                totalResults: 600
            ),
            for: "apollo",
            page: 1
        )
        await stub.setSearchResult(
            MetadataSearchResult(
                items: [Fixtures.mediaPreview(id: "page-501")],
                page: 501,
                totalPages: 600,
                totalResults: 600
            ),
            for: "apollo",
            page: 501
        )

        let viewModel = SearchViewModel(
            metadataService: stub,
            paginationCooldown: .milliseconds(0)
        )
        viewModel.currentPage = 500
        viewModel.totalPages = 600
        viewModel.query = "apollo"
        viewModel.results = [Fixtures.mediaPreview(id: "page-1")]

        #expect(!viewModel.hasMore)
        viewModel.loadMore()

        #expect(viewModel.currentPage == 500)
        #expect(await stub.getSearchCallCount(for: 501) == 0)
    }
}
