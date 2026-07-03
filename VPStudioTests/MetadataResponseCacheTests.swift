import Foundation
import Testing
@testable import VPStudio

private actor FetchCounter {
    private(set) var count = 0

    func next() -> Int {
        count += 1
        return count
    }
}

@Suite("Metadata Response Cache")
struct MetadataResponseCacheTests {
    @Test func servesSecondRequestFromCacheWithinTTL() async throws {
        let cache = MetadataResponseCache()
        let counter = FetchCounter()

        let first = try await cache.value(class: .detail, key: "a") { await counter.next() }
        let second = try await cache.value(class: .detail, key: "a") { await counter.next() }

        #expect(first == 1)
        #expect(second == 1)
        #expect(await counter.count == 1)
    }

    @Test func distinctKeysFetchIndependently() async throws {
        let cache = MetadataResponseCache()
        let counter = FetchCounter()

        _ = try await cache.value(class: .detail, key: "a") { await counter.next() }
        _ = try await cache.value(class: .detail, key: "b") { await counter.next() }

        #expect(await counter.count == 2)
    }

    @Test func sameKeyDifferentClassDoesNotCollide() async throws {
        let cache = MetadataResponseCache()
        let counter = FetchCounter()

        _ = try await cache.value(class: .detail, key: "a") { await counter.next() }
        _ = try await cache.value(class: .search, key: "a") { await counter.next() }

        #expect(await counter.count == 2)
    }

    @Test func expiredEntryRefetches() async throws {
        var configuration = MetadataResponseCache.Configuration.default
        configuration.detailTTL = .milliseconds(20)
        let cache = MetadataResponseCache(configuration: configuration)
        let counter = FetchCounter()

        _ = try await cache.value(class: .detail, key: "a") { await counter.next() }
        try await Task.sleep(for: .milliseconds(60))
        let refetched = try await cache.value(class: .detail, key: "a") { await counter.next() }

        #expect(refetched == 2)
        #expect(await counter.count == 2)
    }

    @Test func concurrentRequestsForSameKeyCoalesceIntoOneFetch() async throws {
        let cache = MetadataResponseCache()
        let counter = FetchCounter()

        let values = await withThrowingTaskGroup(of: Int.self) { group -> [Int] in
            for _ in 0..<8 {
                group.addTask {
                    try await cache.value(class: .detail, key: "a") {
                        try await Task.sleep(for: .milliseconds(30))
                        return await counter.next()
                    }
                }
            }
            var collected: [Int] = []
            while let value = try? await group.next() {
                collected.append(value)
            }
            return collected
        }

        #expect(values.count == 8)
        #expect(Set(values).count == 1)
        #expect(await counter.count == 1)
    }

    @Test func errorsAreNotCached() async throws {
        struct FetchFailure: Error {}
        let cache = MetadataResponseCache()
        let counter = FetchCounter()

        await #expect(throws: FetchFailure.self) {
            _ = try await cache.value(class: .detail, key: "a") { () -> Int in
                _ = await counter.next()
                throw FetchFailure()
            }
        }
        let recovered = try await cache.value(class: .detail, key: "a") { await counter.next() }

        #expect(recovered == 2)
        #expect(await counter.count == 2)
    }

    @Test func evictsLeastRecentlyUsedBeyondMaxEntries() async throws {
        var configuration = MetadataResponseCache.Configuration.default
        configuration.maxEntries = 8
        let cache = MetadataResponseCache(configuration: configuration)
        let counter = FetchCounter()

        for index in 0..<16 {
            _ = try await cache.value(class: .detail, key: "key-\(index)") { await counter.next() }
        }

        #expect(await cache.entryCount <= 8)

        // The newest entry must have survived eviction.
        let newest = try await cache.value(class: .detail, key: "key-15") { await counter.next() }
        #expect(newest == 16)
    }

    @Test func removeAllFlushesEverything() async throws {
        let cache = MetadataResponseCache()
        let counter = FetchCounter()

        _ = try await cache.value(class: .detail, key: "a") { await counter.next() }
        await cache.removeAll()
        #expect(await cache.entryCount == 0)

        let refetched = try await cache.value(class: .detail, key: "a") { await counter.next() }
        #expect(refetched == 2)
    }
}

private struct CountingCacheStubProvider: MetadataProvider {
    let counter: FetchCounter

    var supportsPersonCreditSearch: Bool { false }

    private func stubItem() async -> MediaItem {
        _ = await counter.next()
        return MediaItem(id: "tt0000001", type: .movie, title: "Stub")
    }

    private func stubResult() async -> MetadataSearchResult {
        _ = await counter.next()
        return MetadataSearchResult(items: [], page: 1, totalPages: 1, totalResults: 0)
    }

    func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        await stubResult()
    }

    func search(query: String, type: MediaType?, page: Int, year: Int?, language: String?) async throws -> MetadataSearchResult {
        await stubResult()
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        await stubItem()
    }

    func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
        await stubResult()
    }

    func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
        await stubResult()
    }

    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
        await stubResult()
    }

    func searchPersonCredits(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        await stubResult()
    }

    func getGenres(type: MediaType) async throws -> [Genre] {
        _ = await counter.next()
        return []
    }

    func getSeasons(tmdbId: Int) async throws -> [Season] {
        _ = await counter.next()
        return []
    }

    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
        _ = await counter.next()
        return []
    }

    func getSeasons(id: String, type: MediaType) async throws -> [Season] {
        _ = await counter.next()
        return []
    }

    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode] {
        _ = await counter.next()
        return []
    }

    func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
        _ = await counter.next()
        return ExternalIds(imdbId: nil, tvdbId: nil)
    }
}

@Suite("Caching Metadata Provider")
struct CachingMetadataProviderTests {
    private func makeProvider(
        counter: FetchCounter,
        omdbKey: String = "key-a"
    ) -> CachingMetadataProvider {
        CachingMetadataProvider(
            wrapping: CountingCacheStubProvider(counter: counter),
            configuration: MetadataProviderConfiguration(omdbApiKey: omdbKey),
            cache: MetadataResponseCache()
        )
    }

    @Test func repeatedDetailLookupHitsUpstreamOnce() async throws {
        let counter = FetchCounter()
        let sharedCache = MetadataResponseCache()
        let provider = CachingMetadataProvider(
            wrapping: CountingCacheStubProvider(counter: counter),
            configuration: MetadataProviderConfiguration(omdbApiKey: "key-a"),
            cache: sharedCache
        )

        _ = try await provider.getDetail(id: "tt0000001", type: .movie)
        _ = try await provider.getDetail(id: "tt0000001", type: .movie)

        #expect(await counter.count == 1)
    }

    @Test func differentArgumentsFetchSeparately() async throws {
        let counter = FetchCounter()
        let cache = MetadataResponseCache()
        let provider = CachingMetadataProvider(
            wrapping: CountingCacheStubProvider(counter: counter),
            configuration: MetadataProviderConfiguration(omdbApiKey: "key-a"),
            cache: cache
        )

        _ = try await provider.getDetail(id: "tt0000001", type: .movie)
        _ = try await provider.getDetail(id: "tt0000002", type: .movie)
        _ = try await provider.getDetail(id: "tt0000001", type: .series)

        #expect(await counter.count == 3)
    }

    @Test func differentConfigurationsDoNotShareEntries() async throws {
        let counter = FetchCounter()
        let sharedCache = MetadataResponseCache()
        let first = CachingMetadataProvider(
            wrapping: CountingCacheStubProvider(counter: counter),
            configuration: MetadataProviderConfiguration(omdbApiKey: "key-a"),
            cache: sharedCache
        )
        let second = CachingMetadataProvider(
            wrapping: CountingCacheStubProvider(counter: counter),
            configuration: MetadataProviderConfiguration(omdbApiKey: "key-b"),
            cache: sharedCache
        )

        _ = try await first.getDetail(id: "tt0000001", type: .movie)
        _ = try await second.getDetail(id: "tt0000001", type: .movie)

        #expect(await counter.count == 2)
    }

    @Test func trendingAndCategoryAndDiscoverAreCached() async throws {
        let counter = FetchCounter()
        let provider = makeProvider(counter: counter)

        _ = try await provider.getTrending(type: .movie, timeWindow: .week, page: 1)
        _ = try await provider.getTrending(type: .movie, timeWindow: .week, page: 1)
        _ = try await provider.discover(type: .movie, filters: DiscoverFilters(page: 1))
        _ = try await provider.discover(type: .movie, filters: DiscoverFilters(page: 1))
        _ = try await provider.discover(type: .movie, filters: DiscoverFilters(page: 2))

        #expect(await counter.count == 3)
    }
}
