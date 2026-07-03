import Foundation

struct DiscoverFilters: Sendable {
    var genreId: Int?
    var year: Int?
    var minRating: Double?
    var sortBy: SortOption
    var page: Int
    var language: String?
    var releaseDateGte: String?
    var releaseDateLte: String?
    var originalLanguage: String?

    init(genreId: Int? = nil, year: Int? = nil, minRating: Double? = nil, sortBy: SortOption = .popularityDesc, page: Int = 1, language: String? = nil, releaseDateGte: String? = nil, releaseDateLte: String? = nil, originalLanguage: String? = nil) {
        self.genreId = genreId
        self.year = year
        self.minRating = minRating
        self.sortBy = sortBy
        self.page = page
        self.language = language
        self.releaseDateGte = releaseDateGte
        self.releaseDateLte = releaseDateLte
        self.originalLanguage = originalLanguage
    }

    enum SortOption: String, Sendable, CaseIterable {
        case popularityDesc = "popularity.desc"
        case popularityAsc = "popularity.asc"
        case ratingDesc = "vote_average.desc"
        case ratingAsc = "vote_average.asc"
        case releaseDateDesc = "primary_release_date.desc"
        case releaseDateAsc = "primary_release_date.asc"
        case titleAsc = "title.asc"

        var displayName: String {
            switch self {
            case .popularityDesc: return "Most Popular"
            case .popularityAsc: return "Least Popular"
            case .ratingDesc: return "Highest Rated"
            case .ratingAsc: return "Lowest Rated"
            case .releaseDateDesc: return "Newest"
            case .releaseDateAsc: return "Oldest"
            case .titleAsc: return "Title A-Z"
            }
        }
    }

    // MARK: - Date Helpers

    /// The current date formatted as yyyy-MM-dd, suitable for metadata date parameters.
    static func todayString(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: now)
    }

    /// A date string offset by the given number of days from `now`.
    static func dateString(daysFromNow days: Int, now: Date = Date()) -> String {
        guard let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: now) else {
            return todayString(now: now)
        }
        return todayString(now: date)
    }

    /// Extracts the ISO 639-1 language code from a locale identifier (e.g. "en-US" -> "en", "ja-JP" -> "ja").
    static func iso639LanguageCode(from localeCode: String) -> String {
        let parts = localeCode.split(separator: "-")
        return String(parts.first ?? Substring(localeCode)).lowercased()
    }
}

struct Genre: Codable, Sendable, Identifiable, Hashable {
    var id: Int
    var name: String
}

enum MetadataProviderPlan: String, CaseIterable, Identifiable, Codable, Sendable {
    case free
    case paid

    var id: String { rawValue }

    var usesPaidResources: Bool {
        self == .paid
    }

    static func fromStoredValue(_ value: String?) -> MetadataProviderPlan {
        guard let value else { return .free }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return MetadataProviderPlan(rawValue: normalized) ?? .free
    }
}

struct MetadataProviderConfiguration: Equatable, Sendable {
    var omdbApiKey: String?
    var tmdbApiKey: String?
    var omdbPlan: MetadataProviderPlan
    var tmdbPlan: MetadataProviderPlan

    init(
        omdbApiKey: String? = nil,
        tmdbApiKey: String? = nil,
        omdbPlan: MetadataProviderPlan = .free,
        tmdbPlan: MetadataProviderPlan = .free
    ) {
        self.omdbApiKey = Self.normalizedKey(omdbApiKey)
        self.tmdbApiKey = Self.normalizedKey(tmdbApiKey)
        self.omdbPlan = omdbPlan
        self.tmdbPlan = tmdbPlan
    }

    var isConfigured: Bool {
        hasOMDb
    }

    var hasOMDb: Bool { omdbApiKey != nil }
    var hasTMDb: Bool { tmdbApiKey != nil }
    var hasAnyProvider: Bool { hasOMDb || hasTMDb }

    var providerSummary: String {
        switch (hasOMDb, hasTMDb) {
        case (true, true): return "OMDb + legacy TMDb fallback"
        case (true, false): return "OMDb"
        case (false, true): return "Legacy TMDb fallback"
        case (false, false): return "None"
        }
    }

    var configuredProviderNames: [String] {
        var names: [String] = []
        if hasOMDb { names.append("OMDb") }
        if hasTMDb { names.append(hasOMDb ? "Legacy TMDb fallback" : "TMDb") }
        return names
    }

    private static func normalizedKey(_ key: String?) -> String? {
        guard let key else { return nil }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum MetadataProviderFactoryMode: String, Equatable, Sendable {
    case unconfigured
    case omdbOnly
    case tmdbOnly
    case dualProviderOMDbArtwork
    case dualProviderOMDbPaidArtwork

    var prefersOMDbArtwork: Bool {
        self == .dualProviderOMDbPaidArtwork || self == .dualProviderOMDbArtwork
    }
}

protocol MetadataProvider: Sendable {
    var supportsPersonCreditSearch: Bool { get }

    func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult
    func search(query: String, type: MediaType?, page: Int, year: Int?, language: String?) async throws -> MetadataSearchResult
    func getDetail(id: String, type: MediaType) async throws -> MediaItem
    func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult
    func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult
    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult
    func searchPersonCredits(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult
    func getGenres(type: MediaType) async throws -> [Genre]
    func getSeasons(tmdbId: Int) async throws -> [Season]
    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode]
    func getSeasons(id: String, type: MediaType) async throws -> [Season]
    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode]
    func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds
}

enum MetadataProviderFactory {
    static func mode(for configuration: MetadataProviderConfiguration) -> MetadataProviderFactoryMode {
        switch (configuration.hasOMDb, configuration.hasTMDb) {
        case (false, false):
            return .unconfigured
        case (true, false):
            return .omdbOnly
        case (false, true):
            return .tmdbOnly
        case (true, true):
            if configuration.omdbPlan.usesPaidResources,
               !configuration.tmdbPlan.usesPaidResources {
                return .dualProviderOMDbPaidArtwork
            }
            return .dualProviderOMDbArtwork
        }
    }

    static func make(configuration: MetadataProviderConfiguration) -> any MetadataProvider {
        let omdbProvider = configuration.omdbApiKey.map {
            OMDbService(apiKey: $0, includesPaidArtwork: configuration.omdbPlan.usesPaidResources)
        }
        let tmdbProvider = configuration.tmdbApiKey.map {
            TMDBService(apiKey: $0, plan: configuration.tmdbPlan)
        }

        if let omdbProvider, let tmdbProvider {
            return CompositeMetadataProvider(
                omdbProvider: omdbProvider,
                tmdbProvider: tmdbProvider,
                prefersOMDbArtwork: mode(for: configuration).prefersOMDbArtwork
            )
        }

        if let tmdbProvider {
            return tmdbProvider
        }

        return omdbProvider ?? UnconfiguredMetadataProvider()
    }
}

struct UnconfiguredMetadataProvider: MetadataProvider {
    private static let error = MetadataProviderError.unsupportedIdentifier("unconfigured")

    func search(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        throw Self.error
    }

    func search(
        query: String,
        type: MediaType?,
        page: Int,
        year: Int?,
        language: String?
    ) async throws -> MetadataSearchResult {
        throw Self.error
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        throw Self.error
    }

    func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
        throw Self.error
    }

    func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
        throw Self.error
    }

    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
        throw Self.error
    }

    func searchPersonCredits(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        throw Self.error
    }

    func getGenres(type: MediaType) async throws -> [Genre] {
        throw Self.error
    }

    func getSeasons(tmdbId: Int) async throws -> [Season] {
        throw Self.error
    }

    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
        throw Self.error
    }

    func getSeasons(id: String, type: MediaType) async throws -> [Season] {
        throw Self.error
    }

    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode] {
        throw Self.error
    }

    func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
        throw Self.error
    }
}

struct CompositeMetadataProvider: MetadataProvider {
    let omdbProvider: (any MetadataProvider)?
    let tmdbProvider: (any MetadataProvider)?
    let prefersOMDbArtwork: Bool

    var supportsPersonCreditSearch: Bool {
        tmdbProvider?.supportsPersonCreditSearch == true || omdbProvider?.supportsPersonCreditSearch == true
    }

    init(
        omdbProvider: (any MetadataProvider)?,
        tmdbProvider: (any MetadataProvider)?,
        prefersOMDbArtwork: Bool = false
    ) {
        self.omdbProvider = omdbProvider
        self.tmdbProvider = tmdbProvider
        self.prefersOMDbArtwork = prefersOMDbArtwork
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
        try await visualFirstResult(
            operation: { provider in
                try await provider.search(query: query, type: type, page: page, year: year, language: language)
            }
        )
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        guard let tmdbProvider, let omdbProvider else {
            return try await configuredProvider().getDetail(id: id, type: type)
        }

        if MetadataProviderIdentifierPolicy.tmdbID(from: id) != nil {
            return try await tmdbLedDetail(
                id: id,
                type: type,
                tmdbProvider: tmdbProvider,
                omdbProvider: omdbProvider
            )
        }

        do {
            let omdbItem = try await omdbProvider.getDetail(id: id, type: type)
            return await omdbDetailEnrichedByTMDb(
                omdbItem,
                type: type,
                tmdbProvider: tmdbProvider
            )
        } catch {
            if let tmdbItem = try? await tmdbProvider.getDetail(id: id, type: type) {
                let omdbItem = await Self.firstDetail(
                    from: omdbDetailLookupIDs(originalID: id, tmdbItem: tmdbItem),
                    provider: omdbProvider,
                    type: type
                )
                return Self.mergedDetail(
                    primary: tmdbItem,
                    secondary: omdbItem,
                    prefersSecondaryArtwork: prefersOMDbArtwork
                )
            }
            throw error
        }
    }

    private func tmdbLedDetail(
        id: String,
        type: MediaType,
        tmdbProvider: any MetadataProvider,
        omdbProvider: any MetadataProvider
    ) async throws -> MediaItem {
        let tmdbItem = try await tmdbProvider.getDetail(id: id, type: type)
        let omdbItem = await Self.firstDetail(
            from: omdbDetailLookupIDs(originalID: id, tmdbItem: tmdbItem),
            provider: omdbProvider,
            type: type
        )
        return Self.mergedDetail(
            primary: tmdbItem,
            secondary: omdbItem,
            prefersSecondaryArtwork: prefersOMDbArtwork
        )
    }

    private func omdbDetailEnrichedByTMDb(
        _ omdbItem: MediaItem,
        type: MediaType,
        tmdbProvider: any MetadataProvider
    ) async -> MediaItem {
        if let tmdbItem = try? await tmdbProvider.getDetail(id: omdbItem.id, type: type) {
            return Self.mergedDetail(
                primary: omdbItem,
                secondary: tmdbItem,
                prefersSecondaryArtwork: false,
                prefersPrimaryRating: true
            )
        }
        return omdbItem
    }

    func getTrending(type: MediaType, timeWindow: TrendingWindow, page: Int) async throws -> MetadataSearchResult {
        try await visualFirstResult { provider in
            try await provider.getTrending(type: type, timeWindow: timeWindow, page: page)
        }
    }

    func getCategory(_ category: MediaCategory, type: MediaType, page: Int) async throws -> MetadataSearchResult {
        try await visualFirstResult { provider in
            try await provider.getCategory(category, type: type, page: page)
        }
    }

    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
        try await visualFirstResult { provider in
            try await provider.discover(type: type, filters: filters)
        }
    }

    func searchPersonCredits(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        try await visualFirstResult { provider in
            try await provider.searchPersonCredits(query: query, type: type, page: page)
        }
    }

    func getGenres(type: MediaType) async throws -> [Genre] {
        try await visualFirst { provider in
            try await provider.getGenres(type: type)
        }
    }

    func getSeasons(tmdbId: Int) async throws -> [Season] {
        if let tmdbProvider {
            return try await tmdbProvider.getSeasons(tmdbId: tmdbId)
        }
        return try await configuredProvider().getSeasons(tmdbId: tmdbId)
    }

    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
        if let tmdbProvider {
            return try await tmdbProvider.getEpisodes(tmdbId: tmdbId, season: season)
        }
        return try await configuredProvider().getEpisodes(tmdbId: tmdbId, season: season)
    }

    func getSeasons(id: String, type: MediaType) async throws -> [Season] {
        let seasons: [Season]
        do {
            seasons = try await episodeFirst(id: id) { provider in
                try await provider.getSeasons(id: id, type: type)
            }
        } catch {
            if let fallback = try? await tmdbSeasonCatalogFallback(id: id, type: type) {
                return fallback
            }
            throw error
        }
        guard seasons.isEmpty else { return seasons }
        return try await tmdbSeasonCatalogFallback(id: id, type: type) ?? seasons
    }

    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode] {
        let episodes: [Episode]
        do {
            episodes = try await episodeFirst(id: id) { provider in
                try await provider.getEpisodes(id: id, type: type, season: season)
            }
        } catch {
            if let fallback = try? await tmdbEpisodeCatalogFallback(id: id, type: type, season: season) {
                return fallback
            }
            throw error
        }
        guard episodes.isEmpty else { return episodes }
        return (try? await tmdbEpisodeCatalogFallback(id: id, type: type, season: season)) ?? episodes
    }

    /// OMDb has no episode catalog for many niche or newly-airing series (its
    /// series detail reports totalSeasons "N/A" and Season lookups return
    /// "Series or season not found!"), which surfaces as an empty seasons list
    /// or a thrown error rather than routing anywhere else. When a legacy TMDb
    /// provider is configured, resolve the title there (TMDb getDetail accepts
    /// IMDb ids via /find) and serve its season/episode catalog instead.
    private func tmdbSeasonCatalogFallback(id: String, type: MediaType) async throws -> [Season]? {
        guard let tmdbID = await tmdbCatalogFallbackID(id: id, type: type) else { return nil }
        let seasons = try await tmdbProvider?.getSeasons(tmdbId: tmdbID) ?? []
        return seasons.isEmpty ? nil : seasons
    }

    private func tmdbEpisodeCatalogFallback(id: String, type: MediaType, season: Int) async throws -> [Episode]? {
        guard let tmdbID = await tmdbCatalogFallbackID(id: id, type: type) else { return nil }
        let episodes = try await tmdbProvider?.getEpisodes(tmdbId: tmdbID, season: season) ?? []
        return episodes.isEmpty ? nil : episodes
    }

    private func tmdbCatalogFallbackID(id: String, type: MediaType) async -> Int? {
        guard type == .series,
              let tmdbProvider,
              MetadataProviderIdentifierPolicy.tmdbID(from: id) == nil else {
            return nil
        }
        return (try? await tmdbProvider.getDetail(id: id, type: type))?.tmdbId
    }

    func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
        guard let tmdbProvider else {
            return try await configuredProvider().getExternalIds(tmdbId: tmdbId, type: type)
        }
        return try await tmdbProvider.getExternalIds(tmdbId: tmdbId, type: type)
    }

    private func omdbDetailLookupIDs(originalID: String, tmdbItem: MediaItem) -> [String] {
        var ids: [String] = []

        func append(_ candidate: String?) {
            guard let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty,
                  !ids.contains(trimmed) else {
                return
            }
            ids.append(trimmed)
        }

        append(omdbCompatibleLookupID(from: originalID))
        append(IMDbIdentifierPolicy.appScopedID(in: tmdbItem.id))
        append(OMDbTitleLookupPolicy.lookupID(title: tmdbItem.title, year: tmdbItem.year))

        return ids
    }

    private func omdbCompatibleLookupID(from id: String) -> String? {
        if let imdbID = IMDbIdentifierPolicy.appScopedID(in: id) {
            return imdbID
        }

        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              MetadataProviderIdentifierPolicy.tmdbID(from: trimmed) == nil else {
            return nil
        }
        return OMDbTitleLookupPolicy.titleLookup(from: trimmed) == nil ? nil : trimmed
    }

    private static func firstDetail(
        from ids: [String],
        provider: any MetadataProvider,
        type: MediaType
    ) async -> MediaItem? {
        for id in ids {
            if let item = try? await provider.getDetail(id: id, type: type) {
                return item
            }
        }
        return nil
    }

    private func visualFirst<T>(
        operation: (any MetadataProvider) async throws -> T
    ) async throws -> T {
        try await firstAvailable(
            primary: omdbProvider ?? tmdbProvider,
            fallback: omdbProvider == nil ? nil : tmdbProvider,
            operation: operation
        )
    }

    private func visualFirstResult(
        operation: (any MetadataProvider) async throws -> MetadataSearchResult
    ) async throws -> MetadataSearchResult {
        let primaryIsOMDb = omdbProvider != nil
        guard let primary = primaryIsOMDb ? omdbProvider : tmdbProvider else {
            throw MetadataProviderError.unsupportedIdentifier("unconfigured")
        }

        do {
            let result = try await operation(primary)
            guard !primaryIsOMDb, omdbProvider != nil else {
                return result
            }
            return await enrichedResultWithOMDb(result)
        } catch {
            guard let fallback = primaryIsOMDb ? tmdbProvider : omdbProvider else {
                throw error
            }
            return try await operation(fallback)
        }
    }

    private func episodeFirst<T>(
        id: String,
        operation: (any MetadataProvider) async throws -> T
    ) async throws -> T {
        let hasTMDBID = MetadataProviderIdentifierPolicy.tmdbID(from: id) != nil
        let primary = hasTMDBID ? tmdbProvider ?? omdbProvider : omdbProvider ?? tmdbProvider
        let fallback = hasTMDBID ? omdbProvider : tmdbProvider
        return try await firstAvailable(primary: primary, fallback: fallback, operation: operation)
    }

    private func firstAvailable<T>(
        primary: (any MetadataProvider)?,
        fallback: (any MetadataProvider)?,
        operation: (any MetadataProvider) async throws -> T
    ) async throws -> T {
        guard let primary else {
            throw MetadataProviderError.unsupportedIdentifier("unconfigured")
        }

        do {
            return try await operation(primary)
        } catch {
            guard let fallback else { throw error }
            return try await operation(fallback)
        }
    }

    private func configuredProvider() throws -> any MetadataProvider {
        if let omdbProvider { return omdbProvider }
        if let tmdbProvider { return tmdbProvider }
        throw MetadataProviderError.unsupportedIdentifier("unconfigured")
    }

    private func enrichedResultWithOMDb(_ result: MetadataSearchResult) async -> MetadataSearchResult {
        guard let omdbProvider, !result.items.isEmpty else {
            return result
        }

        var enrichedItems = result.items
        let enrichmentLimit = min(enrichedItems.count, 8)
        var startIndex = 0

        while startIndex < enrichmentLimit {
            let endIndex = min(startIndex + 3, enrichmentLimit)
            let batchResults = await withTaskGroup(of: (Int, MediaPreview).self) { group in
                for index in startIndex..<endIndex {
                    let preview = enrichedItems[index]
                    group.addTask {
                        let enriched = await Self.enrichedPreview(
                            preview,
                            omdbProvider: omdbProvider,
                            prefersSecondaryArtwork: prefersOMDbArtwork
                        )
                        return (index, enriched)
                    }
                }

                var results: [(Int, MediaPreview)] = []
                for await item in group {
                    results.append(item)
                }
                return results
            }

            for (index, preview) in batchResults {
                enrichedItems[index] = preview
            }
            startIndex = endIndex
        }

        return MetadataSearchResult(
            items: enrichedItems,
            page: result.page,
            totalPages: result.totalPages,
            totalResults: result.totalResults
        )
    }

    private static func enrichedPreview(
        _ preview: MediaPreview,
        omdbProvider: any MetadataProvider,
        prefersSecondaryArtwork: Bool
    ) async -> MediaPreview {
        let lookupIDs = omdbPreviewLookupIDs(for: preview)
        guard let omdbItem = await firstDetail(from: lookupIDs, provider: omdbProvider, type: preview.type),
              isIdentityCompatible(primary: preview, secondary: omdbItem) else {
            return preview
        }
        return mergedPreview(
            primary: preview,
            secondary: omdbItem,
            prefersSecondaryArtwork: prefersSecondaryArtwork
        )
    }

    private static func omdbPreviewLookupIDs(for preview: MediaPreview) -> [String] {
        var ids: [String] = []

        func append(_ candidate: String?) {
            guard let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty,
                  !ids.contains(trimmed) else {
                return
            }
            ids.append(trimmed)
        }

        append(IMDbIdentifierPolicy.appScopedID(in: preview.id))
        append(OMDbTitleLookupPolicy.lookupID(title: preview.title, year: preview.year))

        return ids
    }

    private static func mergedPreview(
        primary: MediaPreview,
        secondary: MediaItem,
        prefersSecondaryArtwork: Bool
    ) -> MediaPreview {
        let posterPath = prefersSecondaryArtwork
            ? (secondary.posterPath ?? primary.posterPath)
            : (primary.posterPath ?? secondary.posterPath)
        let backdropPath = prefersSecondaryArtwork
            ? (secondary.backdropPath ?? primary.backdropPath)
            : (primary.backdropPath ?? secondary.backdropPath)

        return MediaPreview(
            id: primary.id,
            type: primary.type,
            title: primary.title.isEmpty ? secondary.title : primary.title,
            year: primary.year ?? secondary.year,
            posterPath: posterPath,
            backdropPath: backdropPath,
            imdbRating: secondary.imdbRating ?? primary.imdbRating,
            tmdbId: primary.tmdbId ?? secondary.tmdbId,
            episodeId: primary.episodeId,
            seasonNumber: primary.seasonNumber,
            episodeNumber: primary.episodeNumber
        )
    }

    private static func mergedDetail(
        primary: MediaItem,
        secondary: MediaItem?,
        prefersSecondaryArtwork: Bool = false,
        prefersPrimaryRating: Bool = false
    ) -> MediaItem {
        guard let secondary else { return primary }
        let trustedSecondary = isIdentityCompatible(primary: primary, secondary: secondary) ? secondary : nil
        let posterPath = prefersSecondaryArtwork
            ? (trustedSecondary?.posterPath ?? primary.posterPath)
            : (primary.posterPath ?? trustedSecondary?.posterPath)
        let backdropPath = prefersSecondaryArtwork
            ? (trustedSecondary?.backdropPath ?? primary.backdropPath)
            : (primary.backdropPath ?? trustedSecondary?.backdropPath)

        return MediaItem(
            id: mergedDetailID(primary: primary, trustedSecondary: trustedSecondary),
            type: primary.type,
            title: primary.title.isEmpty ? (trustedSecondary?.title ?? primary.title) : primary.title,
            year: primary.year ?? trustedSecondary?.year,
            posterPath: posterPath,
            backdropPath: backdropPath,
            overview: primary.overview ?? trustedSecondary?.overview,
            genres: primary.genres.isEmpty ? (trustedSecondary?.genres ?? primary.genres) : primary.genres,
            imdbRating: prefersPrimaryRating
                ? (primary.imdbRating ?? trustedSecondary?.imdbRating)
                : (trustedSecondary?.imdbRating ?? primary.imdbRating),
            runtime: primary.runtime ?? trustedSecondary?.runtime,
            status: primary.status ?? trustedSecondary?.status,
            tmdbId: primary.tmdbId ?? trustedSecondary?.tmdbId,
            lastFetched: Date()
        )
    }

    private static func mergedDetailID(primary: MediaItem, trustedSecondary: MediaItem?) -> String {
        if let imdbID = IMDbIdentifierPolicy.appScopedID(in: primary.id) {
            return omdbMediaID(imdbID: imdbID, type: primary.type)
        }

        if let secondary = trustedSecondary,
           let imdbID = IMDbIdentifierPolicy.appScopedID(in: secondary.id) {
            return omdbMediaID(imdbID: imdbID, type: secondary.type)
        }

        return primary.id
    }

    private static func omdbMediaID(imdbID: String, type: MediaType) -> String {
        "\(type.rawValue)-omdb-\(normalizedIMDbID(imdbID))"
    }

    private static func normalizedIMDbID(_ imdbID: String) -> String {
        IMDbIdentifierPolicy.normalizedID(from: imdbID) ?? imdbID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isIdentityCompatible(primary: MediaPreview, secondary: MediaItem) -> Bool {
        guard primary.type == secondary.type else { return false }

        if let primaryIMDb = IMDbIdentifierPolicy.appScopedID(in: primary.id),
           let secondaryIMDb = IMDbIdentifierPolicy.appScopedID(in: secondary.id) {
            return primaryIMDb == secondaryIMDb
        }

        if let primaryTMDB = primary.tmdbId,
           let secondaryTMDB = secondary.tmdbId {
            return primaryTMDB == secondaryTMDB
        }

        let primaryTitle = normalizedTitle(primary.title)
        let secondaryTitle = normalizedTitle(secondary.title)
        guard !primaryTitle.isEmpty,
              primaryTitle == secondaryTitle else {
            return false
        }

        if let primaryYear = primary.year, let secondaryYear = secondary.year {
            return primaryYear == secondaryYear
        }
        return true
    }

    private static func isIdentityCompatible(primary: MediaItem, secondary: MediaItem) -> Bool {
        guard primary.type == secondary.type else { return false }

        if let primaryIMDb = IMDbIdentifierPolicy.appScopedID(in: primary.id),
           let secondaryIMDb = IMDbIdentifierPolicy.appScopedID(in: secondary.id) {
            return primaryIMDb == secondaryIMDb
        }

        if let primaryTMDB = primary.tmdbId,
           let secondaryTMDB = secondary.tmdbId {
            return primaryTMDB == secondaryTMDB
        }

        let primaryTitle = normalizedTitle(primary.title)
        let secondaryTitle = normalizedTitle(secondary.title)
        guard !primaryTitle.isEmpty,
              primaryTitle == secondaryTitle else {
            return false
        }

        if let primaryYear = primary.year, let secondaryYear = secondary.year {
            return primaryYear == secondaryYear
        }
        return true
    }

    private static func normalizedTitle(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

extension MetadataProvider {
    var supportsPersonCreditSearch: Bool { false }

    /// Default: delegates to the 3-param search (ignoring year/language) for backward compatibility.
    func search(query: String, type: MediaType?, page: Int, year: Int?, language: String?) async throws -> MetadataSearchResult {
        try await search(query: query, type: type, page: page)
    }

    func searchPersonCredits(query: String, type: MediaType?, page: Int) async throws -> MetadataSearchResult {
        MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
    }

    func getSeasons(tmdbId: Int) async throws -> [Season] {
        throw MetadataProviderIdentifierPolicy.unsupportedIdentifierError("tmdb-\(tmdbId)")
    }

    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
        throw MetadataProviderIdentifierPolicy.unsupportedIdentifierError("tmdb-\(tmdbId)")
    }

    func getSeasons(id: String, type: MediaType) async throws -> [Season] {
        guard let tmdbId = MetadataProviderIdentifierPolicy.tmdbID(from: id) else {
            throw MetadataProviderIdentifierPolicy.unsupportedIdentifierError(id)
        }
        return try await getSeasons(tmdbId: tmdbId)
    }

    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode] {
        guard let tmdbId = MetadataProviderIdentifierPolicy.tmdbID(from: id) else {
            throw MetadataProviderIdentifierPolicy.unsupportedIdentifierError(id)
        }
        return try await getEpisodes(tmdbId: tmdbId, season: season)
    }

    func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
        throw MetadataProviderIdentifierPolicy.unsupportedIdentifierError("tmdb-\(tmdbId)")
    }
}

enum MetadataProviderIdentifierPolicy {
    static func tmdbID(from id: String) -> Int? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let direct = positiveInteger(from: trimmed) {
            return direct
        }

        let normalized = trimmed.lowercased()
        for prefix in ["tmdb-", "movie-tmdb-", "series-tmdb-", "episode-tmdb-", "tmdb-episode-"] {
            guard normalized.hasPrefix(prefix) else { continue }
            // A shorter prefix like "tmdb-" can match ahead of a more specific one
            // like "tmdb-episode-"; if the remainder isn't a bare positive integer,
            // keep trying the remaining prefixes rather than bailing out.
            if let value = positiveInteger(from: String(normalized.dropFirst(prefix.count))) {
                return value
            }
        }

        return nil
    }

    static func unsupportedIdentifierError(_ id: String) -> Error {
        MetadataProviderError.unsupportedIdentifier(id)
    }

    private static func positiveInteger(from value: String) -> Int? {
        guard !value.isEmpty, value.allSatisfy(\.isNumber), let number = Int(value), number > 0 else {
            return nil
        }
        return number
    }
}

enum MetadataProviderError: LocalizedError, Equatable, Sendable {
    case unsupportedIdentifier(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedIdentifier(let id):
            return "Unsupported metadata identifier: \(id)"
        }
    }
}

extension DiscoverFilters.SortOption {
    nonisolated func tmdbValue(for type: MediaType) -> String {
        switch (self, type) {
        case (.releaseDateDesc, .series):
            return "first_air_date.desc"
        case (.releaseDateAsc, .series):
            return "first_air_date.asc"
        case (.titleAsc, .series):
            return "name.asc"
        default:
            return rawValue
        }
    }
}

extension MediaType {
    nonisolated var tmdbSearchYearParameterName: String {
        switch self {
        case .movie:
            return "year"
        case .series:
            return "first_air_date_year"
        }
    }
}

struct MetadataSearchResult: Sendable {
    var items: [MediaPreview]
    var page: Int
    var totalPages: Int
    var totalResults: Int
}

enum MetadataSearchResultSortPolicy {
    static func sort(_ items: [MediaPreview], by option: DiscoverFilters.SortOption) -> [MediaPreview] {
        switch option {
        case .ratingDesc:
            return sorted(items, ascending: false) { $0.imdbRating }
        case .ratingAsc:
            return sorted(items, ascending: true) { $0.imdbRating }
        case .releaseDateDesc:
            return sorted(items, ascending: false) { $0.year }
        case .releaseDateAsc:
            return sorted(items, ascending: true) { $0.year }
        case .titleAsc:
            return sorted(items, ascending: true) { normalizedTitle($0.title) }
        case .popularityDesc, .popularityAsc:
            return items
        }
    }

    private static func sorted<Value: Comparable>(
        _ items: [MediaPreview],
        ascending: Bool,
        value: (MediaPreview) -> Value?
    ) -> [MediaPreview] {
        items.enumerated().sorted { lhs, rhs in
            let lhsValue = value(lhs.element)
            let rhsValue = value(rhs.element)

            switch (lhsValue, rhsValue) {
            case let (lhsValue?, rhsValue?):
                if lhsValue == rhsValue {
                    return lhs.offset < rhs.offset
                }
                return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return lhs.offset < rhs.offset
            }
        }
        .map(\.element)
    }

    private static func normalizedTitle(_ title: String) -> String {
        title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TrendingWindow: String, Sendable {
    case day, week
}

enum MediaCategory: String, Sendable, CaseIterable {
    case popular
    case topRated = "top_rated"
    case nowPlaying = "now_playing"
    case upcoming
    case airingToday = "airing_today"
    case onTheAir = "on_the_air"

    var displayName: String {
        switch self {
        case .popular: return "Popular"
        case .topRated: return "Top Rated"
        case .nowPlaying: return "Now Playing"
        case .upcoming: return "Upcoming"
        case .airingToday: return "Airing Today"
        case .onTheAir: return "On The Air"
        }
    }

    static func categories(for type: MediaType) -> [MediaCategory] {
        switch type {
        case .movie: return [.popular, .topRated, .nowPlaying, .upcoming]
        case .series: return [.popular, .topRated, .airingToday, .onTheAir]
        }
    }
}

struct ExternalIds: Sendable {
    var imdbId: String?
    var tvdbId: Int?
}
nonisolated extension ExternalIds: Codable {}
