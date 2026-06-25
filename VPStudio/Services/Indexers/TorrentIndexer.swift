import Foundation
import os

protocol TorrentIndexer: Sendable {
    nonisolated var name: String { get }
    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult]
    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult]
}

enum IndexerParseError: LocalizedError, Equatable {
    case invalidPayload(indexer: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidPayload(let indexer, let reason):
            return "\(indexer) returned an invalid response: \(reason)"
        }
    }
}

enum IndexerLogSanitizer {
    private static let sensitiveQueryNames: Set<String> = [
        "access_token", "api_key", "apikey", "auth", "authorization",
        "jwt", "key", "pass", "password", "refresh_token", "sig",
        "signature", "token"
    ]
    private static let urlPattern = try! NSRegularExpression(
        pattern: #"(https?|magnet):\/\/[^\s"']+|magnet:\?[^\s"']+"#,
        options: [.caseInsensitive]
    )
    private static let tokenLikeSegment = try! NSRegularExpression(
        pattern: #"^[A-Za-z0-9._~-]{16,}$"#,
        options: []
    )
    private static let looseTokenPattern = try! NSRegularExpression(
        pattern: #"(?<=(^|[\s\(\[\{<:=""'\-]))([A-Za-z0-9._~-]{16,})(?=($|[\s\)\]\}>"'!?.,:;]))"#,
        options: []
    )

    static func redactedURLString(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "nil" }
        guard let url = URL(string: value), isClearlyURLLike(value) else {
            if looksSensitive(value) || containsSuspiciousSeparators(value) {
                return "REDACTED"
            }
            return value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
        }
        return redactedURL(url)
    }

    static func redactedURL(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "<redacted-url>"
        }

        let absolute = url.absoluteString
        if components.scheme == nil,
           components.host == nil,
           !absolute.contains("."),
           !absolute.contains("/"),
           !absolute.lowercased().hasPrefix("magnet:") {
            return "<redacted-url>"
        }

        if components.user?.isEmpty == false {
            components.user = "REDACTED"
        }
        if components.password?.isEmpty == false {
            components.password = "REDACTED"
        }

        components.percentEncodedPath = sanitizedPath(from: components.percentEncodedPath)
        components.queryItems = components.queryItems?.map { item in
            URLQueryItem(
                name: item.name,
                value: shouldRedactQueryItem(named: item.name, value: item.value) ? "REDACTED" : item.value
            )
        }
        components.fragment = nil

        return components.string ?? "\(components.scheme ?? "unknown")://\(components.host ?? "<unknown-host>")"
    }

    static func redactedErrorMessage(_ error: Error) -> String {
        let localized = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return redactLooseString(localized)
    }

    private static func shouldRedactQueryItem(named name: String, value: String?) -> Bool {
        if sensitiveQueryNames.contains(name.lowercased()) {
            return true
        }
        guard let value else { return false }
        return looksSensitive(value)
    }

    private static func sanitizedPath(from path: String) -> String {
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        return segments.map { segment in
            let value = String(segment)
            return looksSensitive(value.removingPercentEncoding ?? value) ? "REDACTED" : value
        }
        .joined(separator: "/")
    }

    private static func redactLooseString(_ value: String) -> String {
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        let matches = urlPattern.matches(in: value, options: [], range: nsRange)
        if matches.isEmpty {
            return redactStandaloneTokens(from: value)
        }

        var redacted = value
        for match in matches.reversed() {
            guard let range = Range(match.range, in: redacted) else { continue }
            let candidate = String(redacted[range])
            redacted.replaceSubrange(range, with: redactedURLString(candidate))
        }
        return redactStandaloneTokens(from: redacted)
    }

    private static func redactStandaloneTokens(from value: String) -> String {
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        let matches = looseTokenPattern.matches(in: value, options: [], range: nsRange)
        guard !matches.isEmpty else { return value }

        var redacted = value
        for match in matches.reversed() {
            guard let range = Range(match.range, in: redacted) else { continue }
            redacted.replaceSubrange(range, with: "REDACTED")
        }
        return redacted
    }

    private static func looksSensitive(_ value: String) -> Bool {
        guard value.count >= 16 else { return false }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return tokenLikeSegment.firstMatch(in: value, options: [], range: range) != nil
    }

    private static func isClearlyURLLike(_ value: String) -> Bool {
        value.contains("://")
            || value.lowercased().hasPrefix("magnet:")
            || value.contains("/")
            || value.contains("?")
            || value.contains("#")
            || value.contains(".")
    }

    private static func containsSuspiciousSeparators(_ value: String) -> Bool {
        value.contains(where: { $0.isWhitespace })
            || value.contains("-")
            || value.contains(":")
            || value.contains("@")
            || value.contains("[")
            || value.contains("]")
            || value.contains("=")
    }
}

enum IndexerManagerError: LocalizedError {
    case allIndexersFailed(String)

    var errorDescription: String? {
        switch self {
        case .allIndexersFailed(let details):
            return "All indexers failed: \(details)"
        }
    }
}

private struct IndexerSearchTimeoutError: LocalizedError {
    var errorDescription: String? {
        "Timed out waiting for indexer response."
    }
}

actor IndexerManager {
    nonisolated static let bootstrapSettingKey = "indexer_defaults_seeded"
    private static let logger = Logger(subsystem: "com.vpstudio", category: "indexer-manager")

    private let database: DatabaseManager
    private let secretStore: any SecretStore
    private let perIndexerSearchTimeout: Duration
    private var indexers: [any TorrentIndexer] = []
    private(set) var lastSearchErrors: [(indexer: String, error: String)] = []
    private var hasInitialized = false

    init(
        database: DatabaseManager,
        secretStore: any SecretStore = KeychainSecretStore(serviceName: "com.vpstudio.credentials"),
        indexers: [any TorrentIndexer] = [],
        hasInitialized: Bool = false,
        perIndexerSearchTimeout: Duration = .seconds(12)
    ) {
        self.database = database
        self.secretStore = secretStore
        self.perIndexerSearchTimeout = perIndexerSearchTimeout
        self.indexers = indexers
        self.hasInitialized = hasInitialized
    }

    func initialize() async throws {
        var fetchedConfigs = try await database.fetchAllIndexerConfigs().sorted { $0.priority < $1.priority }

        if fetchedConfigs.isEmpty,
           (try await database.getSetting(key: Self.bootstrapSettingKey)) == nil {
            let seededDefaults = IndexerDefaultRanking.defaultConfigs()
            try await database.saveIndexerConfigs(seededDefaults)
            try? await database.setSetting(key: Self.bootstrapSettingKey, value: "true")
            fetchedConfigs = seededDefaults
        }

        let hydratedConfigs = try await Self.hydratedConfigs(from: fetchedConfigs, secretStore: secretStore)
        if hydratedConfigs != fetchedConfigs {
            try await database.saveIndexerConfigs(hydratedConfigs)
        }

        let runtimeConfigs = try await Self.runtimeConfigs(from: hydratedConfigs, secretStore: secretStore)
        let activeConfigs = runtimeConfigs.filter(\.isActive)
        indexers = activeConfigs.compactMap { IndexerFactory.create(from: $0) }

        #if DEBUG
        let createdIndexerCount = self.indexers.count
        Self.logger.debug("Fetched configs=\(fetchedConfigs.count, privacy: .public) hydrated=\(hydratedConfigs.count, privacy: .public) active=\(activeConfigs.count, privacy: .public) created=\(createdIndexerCount, privacy: .public)")
        for config in activeConfigs {
            let created = IndexerFactory.create(from: config) != nil
            let baseURL = IndexerLogSanitizer.redactedURLString(config.baseURL)
            Self.logger.debug("\(config.name, privacy: .public) (\(config.indexerType.rawValue, privacy: .public)) baseURL=\(baseURL, privacy: .public) created=\(created, privacy: .public)")
        }
        #endif

        hasInitialized = true
    }

    func ensureInitialized() async throws {
        if !hasInitialized {
            try await initialize()
        }
    }

    func search(imdbId: String, type: MediaType, season: Int? = nil, episode: Int? = nil) async throws -> [TorrentResult] {
        let normalizedIMDbID = IMDbIdentifierPolicy.firstID(in: imdbId) ?? imdbId
        return try await runConcurrentSearch { indexer in
            let results = try await indexer.search(imdbId: normalizedIMDbID, type: type, season: season, episode: episode)
            if type == .series, let season, let episode {
                return results.filter {
                    EpisodeTokenMatcher.matchesIfPresent(title: $0.title, season: season, episode: episode)
                }
            }
            return results
        }
    }

    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
        return try await runConcurrentSearch { indexer in
            let results = try await indexer.searchByQuery(query: query, type: type)
            if type == .series, let context = EpisodeTokenMatcher.context(fromQuery: query) {
                return results.filter {
                    EpisodeTokenMatcher.matches(title: $0.title, season: context.season, episode: context.episode)
                }
            }
            return results
        }
    }

    private func runConcurrentSearch(
        _ fetch: @escaping @Sendable (any TorrentIndexer) async throws -> [TorrentResult]
    ) async throws -> [TorrentResult] {
        var allResults: [TorrentResult] = []
        var errors: [(indexer: String, error: String)] = []

        let indexers = self.indexers
        let perIndexerSearchTimeout = self.perIndexerSearchTimeout

        await withTaskGroup(of: ([TorrentResult], String?, String?).self) { group in
            for indexer in indexers {
                group.addTask { [indexer] in
                    #if DEBUG
                    Self.logger.debug("Dispatching \(indexer.name, privacy: .public)")
                    #endif
                    do {
                        let results = try await Self.withTimeout(after: perIndexerSearchTimeout) {
                            try await fetch(indexer)
                        }
                        #if DEBUG
                        Self.logger.debug("\(indexer.name, privacy: .public) returned \(results.count, privacy: .public) results")
                        #endif
                        return (results, indexer.name, nil)
                    } catch {
                        let sanitizedError = IndexerLogSanitizer.redactedErrorMessage(error)
                        #if DEBUG
                        Self.logger.error("\(indexer.name, privacy: .public) error: \(sanitizedError, privacy: .public)")
                        #endif
                        return ([], indexer.name, sanitizedError)
                    }
                }
            }
            for await (results, indexerName, errorMessage) in group {
                allResults.append(contentsOf: results)
                if let errorMessage, let indexerName {
                    errors.append((indexer: indexerName, error: errorMessage))
                }
            }
        }

        lastSearchErrors = errors

        #if DEBUG
        if !errors.isEmpty {
            for e in errors {
                Self.logger.error("\(e.indexer, privacy: .public) failed: \(e.error, privacy: .public)")
            }
        }
        Self.logger.debug("Search complete results=\(allResults.count, privacy: .public) indexers=\(indexers.count, privacy: .public) errors=\(errors.count, privacy: .public)")
        #endif

        if allResults.isEmpty, let firstError = errors.first {
            throw IndexerManagerError.allIndexersFailed("\(firstError.indexer): \(firstError.error)")
        }

        return Self.deduplicateAndSort(allResults)
    }

    nonisolated private static func withTimeout<T: Sendable>(
        after timeout: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw IndexerSearchTimeoutError()
            }

            guard let result = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return result
        }
    }

    func configuredIndexerNames() -> [String] {
        indexers.map(\.name)
    }

    nonisolated static func deduplicateAndSort(_ results: [TorrentResult]) -> [TorrentResult] {
        var seen: [String: TorrentResult] = [:]
        for result in results {
            let hash = result.infoHash.lowercased()
            if let existing = seen[hash] {
                if shouldPrefer(result, over: existing) {
                    seen[hash] = result
                }
            } else {
                seen[hash] = result
            }
        }

        return Array(seen.values).sorted { lhs, rhs in
            if lhs.isCached != rhs.isCached { return lhs.isCached }
            if lhs.quality != rhs.quality { return lhs.quality > rhs.quality }
            if lhs.seeders != rhs.seeders { return lhs.seeders > rhs.seeders }
            return lhs.id < rhs.id
        }
    }

    private static func shouldPrefer(_ lhs: TorrentResult, over rhs: TorrentResult) -> Bool {
        if lhs.isCached != rhs.isCached { return lhs.isCached }
        if lhs.quality != rhs.quality { return lhs.quality > rhs.quality }
        if lhs.seeders != rhs.seeders { return lhs.seeders > rhs.seeders }
        return lhs.id < rhs.id
    }

    private static func defaultBuiltInIndexers() -> [any TorrentIndexer] {
        IndexerDefaultRanking.defaultConfigs().compactMap { config in
            IndexerFactory.create(from: config)
        }
    }

    private static func hydratedConfigs(from configs: [IndexerConfig], secretStore: any SecretStore) async throws -> [IndexerConfig] {
        guard !configs.isEmpty else {
            return []
        }

        // Canonicalize legacy built-in definitions (e.g. old torznab-format
        // configs that should now be stremio) but do NOT force-add missing
        // built-ins back — if the user deleted one, it stays deleted.
        let canonicalized = IndexerDefaultRanking.canonicalizingKnownDefaults(in: configs)
        var persisted: [IndexerConfig] = []
        persisted.reserveCapacity(canonicalized.count)

        for config in canonicalized {
            let stored = try await config.persistedCopy(using: secretStore).config
            persisted.append(stored)
        }

        return persisted
    }

    private static func runtimeConfigs(from configs: [IndexerConfig], secretStore: any SecretStore) async throws -> [IndexerConfig] {
        var runtime: [IndexerConfig] = []
        runtime.reserveCapacity(configs.count)

        for config in configs {
            runtime.append(try await config.resolvedCopy(using: secretStore))
        }

        return runtime
    }
}

enum IndexerFactory {
    static func create(from config: IndexerConfig, session: URLSession? = nil) -> (any TorrentIndexer)? {
        let resolvedEndpointPath: String = {
            guard !config.endpointPath.isEmpty else {
                return config.indexerType.defaultEndpointPath
            }
            return config.endpointPath
        }()

        switch config.indexerType {
        case .apiBay:
            return APIBayIndexer(baseURL: config.baseURL, session: session)
        case .yts:
            return YTSIndexer(baseURLs: config.baseURL.map { [$0] }, session: session)
        case .eztv:
            return EZTVIndexer(baseURL: config.baseURL ?? "https://eztvx.to/api", session: session)
        case .jackett, .prowlarr, .torznab:
            guard let url = config.baseURL else { return nil }
            return TorznabIndexer(
                name: config.name,
                baseURL: url,
                endpointPath: resolvedEndpointPath,
                apiKey: config.apiKey,
                categoryFilter: config.categoryFilter,
                apiKeyTransport: config.apiKeyTransport,
                session: session ?? .shared
            )
        case .zilean:
            guard let url = config.baseURL else { return nil }
            return ZileanIndexer(baseURL: url, endpointPath: config.endpointPath, session: session)
        case .stremio:
            guard let url = config.baseURL else { return nil }
            return StremioIndexer(
                name: config.name,
                baseURL: url,
                endpointPath: config.endpointPath,
                session: session ?? .shared
            )
        }
    }
}
