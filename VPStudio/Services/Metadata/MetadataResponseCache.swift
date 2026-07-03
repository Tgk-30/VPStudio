import CryptoKit
import Foundation

/// In-memory cache for metadata provider responses.
///
/// Bounds memory three ways: a hard entry cap with least-recently-used
/// eviction, per-request-class TTLs so stale metadata ages out instead of
/// accumulating, and a full flush on system memory pressure. Concurrent
/// requests for the same key are coalesced into a single upstream fetch,
/// which is what turns Discover's N-rows-times-M-items fan-out into one
/// network call per unique title. Errors are never cached.
actor MetadataResponseCache {
    struct Configuration: Sendable {
        var maxEntries: Int
        var searchTTL: Duration
        var browseTTL: Duration
        var detailTTL: Duration
        var genresTTL: Duration
        var seasonsTTL: Duration
        var externalIDsTTL: Duration

        static let `default` = Configuration(
            maxEntries: 512,
            searchTTL: .seconds(10 * 60),
            browseTTL: .seconds(15 * 60),
            detailTTL: .seconds(60 * 60),
            genresTTL: .seconds(24 * 60 * 60),
            seasonsTTL: .seconds(60 * 60),
            externalIDsTTL: .seconds(24 * 60 * 60)
        )
    }

    enum RequestClass: String, Sendable {
        case search
        case browse
        case detail
        case genres
        case seasons
        case externalIDs
    }

    static let shared = MetadataResponseCache()

    private struct Entry {
        var value: any Sendable
        var expiresAt: ContinuousClock.Instant
        var lastAccess: UInt64
    }

    private let configuration: Configuration
    private let clock = ContinuousClock()
    private var entries: [String: Entry] = [:]
    private var inFlight: [String: Task<any Sendable, any Error>] = [:]
    private var accessCounter: UInt64 = 0
    private var pressureSource: (any DispatchSourceMemoryPressure)?

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    var entryCount: Int { entries.count }

    func value<T: Sendable>(
        class requestClass: RequestClass,
        key rawKey: String,
        fetch: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        startMemoryPressureMonitoringIfNeeded()
        let key = "\(requestClass.rawValue)|\(rawKey)"
        let now = clock.now

        if var entry = entries[key], entry.expiresAt > now, let cached = entry.value as? T {
            accessCounter += 1
            entry.lastAccess = accessCounter
            entries[key] = entry
            return cached
        }
        entries[key] = nil

        if let running = inFlight[key],
           let joined = try await running.value as? T {
            return joined
        }

        let task = Task<any Sendable, any Error> { try await fetch() }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let fetched = try await task.value
        guard let typed = fetched as? T else {
            // Two different result types under one key would be a caller bug;
            // fall through to an uncached fetch rather than trap.
            return try await fetch()
        }
        store(typed, class: requestClass, key: key)
        return typed
    }

    func removeAll() {
        entries.removeAll(keepingCapacity: false)
    }

    private func store(_ value: any Sendable, class requestClass: RequestClass, key: String) {
        accessCounter += 1
        entries[key] = Entry(
            value: value,
            expiresAt: clock.now + ttl(for: requestClass),
            lastAccess: accessCounter
        )
        evictIfNeeded()
    }

    private func ttl(for requestClass: RequestClass) -> Duration {
        switch requestClass {
        case .search: return configuration.searchTTL
        case .browse: return configuration.browseTTL
        case .detail: return configuration.detailTTL
        case .genres: return configuration.genresTTL
        case .seasons: return configuration.seasonsTTL
        case .externalIDs: return configuration.externalIDsTTL
        }
    }

    private func evictIfNeeded() {
        guard entries.count > configuration.maxEntries else { return }
        // Evict in a batch so the sort cost is amortized across many inserts.
        let batch = max(entries.count - configuration.maxEntries, configuration.maxEntries / 8)
        let victims = entries
            .sorted { $0.value.lastAccess < $1.value.lastAccess }
            .prefix(batch)
        for (key, _) in victims {
            entries[key] = nil
        }
    }

    private func startMemoryPressureMonitoringIfNeeded() {
        guard pressureSource == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.removeAll() }
        }
        source.activate()
        pressureSource = source
    }
}

/// Wraps a production `MetadataProvider` with `MetadataResponseCache`.
///
/// Only production factory paths wrap their providers; test-injected factories
/// return their stubs directly so call-counting tests observe every request.
struct CachingMetadataProvider: MetadataProvider {
    private let base: any MetadataProvider
    private let cache: MetadataResponseCache
    private let fingerprint: String

    init(
        wrapping base: any MetadataProvider,
        configuration: MetadataProviderConfiguration,
        cache: MetadataResponseCache = .shared
    ) {
        self.base = base
        self.cache = cache
        self.fingerprint = MetadataCacheKey.fingerprint(for: configuration)
    }

    var supportsPersonCreditSearch: Bool { base.supportsPersonCreditSearch }

    func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        try await cache.value(
            class: .search,
            key: "\(fingerprint)|search|\(MetadataCacheKey.escaped(query))|\(type?.rawValue ?? "-")|\(page)"
        ) {
            try await base.search(query: query, type: type, page: page)
        }
    }

    func search(
        query: String,
        type: MediaType?,
        page: Int,
        year: Int?,
        language: String?
    ) async throws -> MetadataSearchResult {
        try await cache.value(
            class: .search,
            key: "\(fingerprint)|searchFiltered|\(MetadataCacheKey.escaped(query))|\(type?.rawValue ?? "-")|\(page)|\(year.map(String.init) ?? "-")|\(MetadataCacheKey.escaped(language ?? "-"))"
        ) {
            try await base.search(query: query, type: type, page: page, year: year, language: language)
        }
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        try await cache.value(
            class: .detail,
            key: "\(fingerprint)|detail|\(MetadataCacheKey.escaped(id))|\(type.rawValue)"
        ) {
            try await base.getDetail(id: id, type: type)
        }
    }

    func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
        try await cache.value(
            class: .browse,
            key: "\(fingerprint)|trending|\(type.rawValue)|\(timeWindow.rawValue)|\(page)"
        ) {
            try await base.getTrending(type: type, timeWindow: timeWindow, page: page)
        }
    }

    func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
        try await cache.value(
            class: .browse,
            key: "\(fingerprint)|category|\(category.rawValue)|\(type.rawValue)|\(page)"
        ) {
            try await base.getCategory(category, type: type, page: page)
        }
    }

    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
        try await cache.value(
            class: .browse,
            key: "\(fingerprint)|discover|\(type.rawValue)|\(MetadataCacheKey.component(for: filters))"
        ) {
            try await base.discover(type: type, filters: filters)
        }
    }

    func searchPersonCredits(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        try await cache.value(
            class: .search,
            key: "\(fingerprint)|personCredits|\(MetadataCacheKey.escaped(query))|\(type?.rawValue ?? "-")|\(page)"
        ) {
            try await base.searchPersonCredits(query: query, type: type, page: page)
        }
    }

    func getGenres(type: MediaType) async throws -> [Genre] {
        try await cache.value(
            class: .genres,
            key: "\(fingerprint)|genres|\(type.rawValue)"
        ) {
            try await base.getGenres(type: type)
        }
    }

    func getSeasons(tmdbId: Int) async throws -> [Season] {
        try await cache.value(
            class: .seasons,
            key: "\(fingerprint)|seasonsTMDB|\(tmdbId)"
        ) {
            try await base.getSeasons(tmdbId: tmdbId)
        }
    }

    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
        try await cache.value(
            class: .seasons,
            key: "\(fingerprint)|episodesTMDB|\(tmdbId)|\(season)"
        ) {
            try await base.getEpisodes(tmdbId: tmdbId, season: season)
        }
    }

    func getSeasons(id: String, type: MediaType) async throws -> [Season] {
        try await cache.value(
            class: .seasons,
            key: "\(fingerprint)|seasons|\(MetadataCacheKey.escaped(id))|\(type.rawValue)"
        ) {
            try await base.getSeasons(id: id, type: type)
        }
    }

    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode] {
        try await cache.value(
            class: .seasons,
            key: "\(fingerprint)|episodes|\(MetadataCacheKey.escaped(id))|\(type.rawValue)|\(season)"
        ) {
            try await base.getEpisodes(id: id, type: type, season: season)
        }
    }

    func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
        try await cache.value(
            class: .externalIDs,
            key: "\(fingerprint)|externalIds|\(tmdbId)|\(type.rawValue)"
        ) {
            try await base.getExternalIds(tmdbId: tmdbId, type: type)
        }
    }
}

/// Wraps a production `DetailMetadataProviding` with the shared response cache.
struct CachingDetailMetadataProvider: DetailMetadataProviding {
    private let base: any DetailMetadataProviding
    private let cache: MetadataResponseCache
    private let fingerprint: String

    init(
        wrapping base: any DetailMetadataProviding,
        configuration: MetadataProviderConfiguration,
        cache: MetadataResponseCache = .shared
    ) {
        self.base = base
        self.cache = cache
        self.fingerprint = MetadataCacheKey.fingerprint(for: configuration)
    }

    var detailLookupPreference: DetailMetadataLookupPreference { base.detailLookupPreference }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        try await cache.value(
            class: .detail,
            key: "\(fingerprint)|detail|\(MetadataCacheKey.escaped(id))|\(type.rawValue)"
        ) {
            try await base.getDetail(id: id, type: type)
        }
    }

    func getSeasons(id: String, type: MediaType) async throws -> [Season] {
        try await cache.value(
            class: .seasons,
            key: "\(fingerprint)|seasons|\(MetadataCacheKey.escaped(id))|\(type.rawValue)"
        ) {
            try await base.getSeasons(id: id, type: type)
        }
    }

    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode] {
        try await cache.value(
            class: .seasons,
            key: "\(fingerprint)|episodes|\(MetadataCacheKey.escaped(id))|\(type.rawValue)|\(season)"
        ) {
            try await base.getEpisodes(id: id, type: type, season: season)
        }
    }
}

enum MetadataCacheKey {
    /// Escapes the key delimiter in user-influenced components (search text,
    /// media ids, language/date filters) so crafted values can never collide
    /// two different requests onto one cache entry.
    static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: "|", with: "%7C")
    }

    /// Cache keys never embed raw API keys: configurations are partitioned by
    /// a stable SHA-256 digest, so distinct keys can never collide onto one
    /// partition and a key change naturally points lookups at fresh entries.
    static func fingerprint(for configuration: MetadataProviderConfiguration) -> String {
        let canonical = [
            "omdb", configuration.omdbApiKey ?? "-", configuration.omdbPlan.rawValue,
            "tmdb", configuration.tmdbApiKey ?? "-", configuration.tmdbPlan.rawValue,
        ].map { "\($0.count):\($0)" }.joined(separator: "|")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    static func component(for filters: DiscoverFilters) -> String {
        [
            filters.genreId.map(String.init) ?? "-",
            filters.year.map(String.init) ?? "-",
            filters.minRating.map { String($0) } ?? "-",
            filters.sortBy.rawValue,
            String(filters.page),
            escaped(filters.language ?? "-"),
            escaped(filters.releaseDateGte ?? "-"),
            escaped(filters.releaseDateLte ?? "-"),
            escaped(filters.originalLanguage ?? "-"),
        ].joined(separator: "|")
    }
}
