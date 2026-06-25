import Foundation

actor OMDbService: MetadataProvider {
    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        return URLSession(configuration: configuration)
    }()

    private let apiKey: String
    private let baseURL = "https://www.omdbapi.com/"
    private let session: URLSession

    init(apiKey: String, session: URLSession? = nil) {
        self.apiKey = apiKey
        self.session = session ?? Self.defaultSession
    }

    func search(query: String, type: MediaType?, page: Int = 1) async throws -> MetadataSearchResult {
        try await search(query: query, type: type, page: page, year: nil, language: nil)
    }

    func search(
        query: String,
        type: MediaType?,
        page: Int = 1,
        year: Int? = nil,
        language: String? = nil
    ) async throws -> MetadataSearchResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        var params = [
            "s": trimmedQuery,
            "page": String(max(1, page)),
        ]
        if let type {
            params["type"] = type.omdbType
        }
        if let year {
            params["y"] = String(year)
        }

        do {
            let response: OMDbSearchResponse = try await request(params: params)
            let totalResults = Int(response.totalResults ?? "") ?? response.search.count
            let totalPages = max(1, Int(ceil(Double(totalResults) / 10.0)))
            let items = await enrichedSearchPreviews(
                from: response.search.compactMap(\.mediaPreview),
                fallbackType: type
            )
            return MetadataSearchResult(
                items: items,
                page: max(1, page),
                totalPages: totalPages,
                totalResults: totalResults
            )
        } catch OMDbError.notFound {
            return MetadataSearchResult(items: [], page: max(1, page), totalPages: 1, totalResults: 0)
        }
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        let response: OMDbTitleResponse
        if let imdbID = Self.imdbID(from: id) {
            response = try await request(params: ["i": imdbID, "plot": "full"])
        } else {
            guard let lookup = Self.titleLookup(from: id) else { throw OMDbError.notFound }
            var params = ["t": lookup.title, "type": type.omdbType, "plot": "full"]
            if let year = lookup.year {
                params["y"] = String(year)
            }
            response = try await request(params: params)
        }
        return response.mediaItem(fallbackType: type)
    }

    func getTrending(type: MediaType, timeWindow: TrendingWindow = .week, page: Int = 1) async throws -> MetadataSearchResult {
        try await curatedResult(ids: OMDbDiscoveryCatalog.trendingIDs(for: type), type: type, page: page)
    }

    func getCategory(_ category: MediaCategory, type: MediaType, page: Int = 1) async throws -> MetadataSearchResult {
        try await curatedResult(ids: OMDbDiscoveryCatalog.ids(for: category, type: type), type: type, page: page)
    }

    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
        let query = OMDbDiscoveryCatalog.query(for: filters.genreId, type: type)
        let result = try await search(query: query, type: type, page: filters.page, year: filters.year, language: filters.language)
        let filteredItems = result.items.filter { item in
            Self.matchesMinimumRating(item, minRating: filters.minRating)
                && Self.matchesReleaseWindow(
                    item,
                    releaseDateGte: filters.releaseDateGte,
                    releaseDateLte: filters.releaseDateLte
                )
        }
        return MetadataSearchResult(
            items: MetadataSearchResultSortPolicy.sort(filteredItems, by: filters.sortBy),
            page: result.page,
            totalPages: result.totalPages,
            totalResults: result.totalResults
        )
    }

    func getGenres(type: MediaType) async throws -> [Genre] {
        OMDbDiscoveryCatalog.genres(for: type)
    }

    private static func matchesMinimumRating(_ item: MediaPreview, minRating: Double?) -> Bool {
        guard let minRating else { return true }
        guard let rating = item.imdbRating else { return false }
        return rating >= minRating
    }

    private static func matchesReleaseWindow(
        _ item: MediaPreview,
        releaseDateGte: String?,
        releaseDateLte: String?
    ) -> Bool {
        let minYear = releaseDateGte.flatMap(Self.yearPrefix)
        let maxYear = releaseDateLte.flatMap(Self.yearPrefix)
        guard minYear != nil || maxYear != nil else { return true }
        guard let itemYear = item.year else { return false }
        if let minYear, itemYear < minYear { return false }
        if let maxYear, itemYear > maxYear { return false }
        return true
    }

    private static func yearPrefix(from dateString: String) -> Int? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return nil }
        return Int(trimmed.prefix(4))
    }

    func getSeasons(tmdbId: Int) async throws -> [Season] {
        throw OMDbError.unsupported("OMDb season lookup requires an IMDb ID.")
    }

    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
        throw OMDbError.unsupported("OMDb episode lookup requires an IMDb ID.")
    }

    func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
        throw OMDbError.unsupported("OMDb external-ID lookup is already keyed by IMDb ID.")
    }

    func getSeasons(id: String, type: MediaType) async throws -> [Season] {
        guard let detail = try await seriesDetail(for: id, type: type) else { return [] }
        let totalSeasons = Int(detail.totalSeasons ?? "") ?? 0
        guard totalSeasons > 0 else { return [] }

        let seriesIMDbID = detail.normalizedIMDbID
        let episodeCounts = await seasonEpisodeCounts(
            seriesIMDbID: seriesIMDbID,
            totalSeasons: totalSeasons
        )
        var seasons: [Season] = []
        for season in 1...totalSeasons {
            seasons.append(Season(
                id: season,
                seasonNumber: season,
                name: "Season \(season)",
                overview: nil,
                posterPath: detail.poster.validOMDbArtworkPath,
                episodeCount: episodeCounts[season, default: 0],
                airDate: nil
            ))
        }
        return seasons
    }

    private func seasonEpisodeCounts(
        seriesIMDbID: String?,
        totalSeasons: Int,
        maxConcurrentRequests: Int = 3
    ) async -> [Int: Int] {
        guard let seriesIMDbID, totalSeasons > 0 else { return [:] }
        let batchSize = max(1, min(maxConcurrentRequests, totalSeasons))
        let seasons = Array(1...totalSeasons)
        var counts: [Int: Int] = [:]
        var startIndex = 0

        while startIndex < seasons.count {
            let endIndex = min(startIndex + batchSize, seasons.count)
            let batch = Array(seasons[startIndex..<endIndex])
            let batchCounts = await withTaskGroup(of: (Int, Int).self) { group in
                for season in batch {
                    group.addTask { [self] in
                        (
                            season,
                            await seasonEpisodeCount(
                                seriesIMDbID: seriesIMDbID,
                                season: season
                            )
                        )
                    }
                }

                var results: [Int: Int] = [:]
                for await result in group {
                    results[result.0] = result.1
                }
                return results
            }
            counts.merge(batchCounts) { _, new in new }
            startIndex = endIndex
        }

        return counts
    }

    private func seasonEpisodeCount(seriesIMDbID: String, season: Int) async -> Int {
        let response: OMDbSeasonResponse? = try? await request(params: [
            "i": seriesIMDbID,
            "Season": String(season),
        ])
        return response?.episodes.count ?? 0
    }

    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode] {
        guard season > 0 else { return [] }
        guard let imdbID = try await seriesIMDbID(for: id, type: type) else { return [] }
        let response: OMDbSeasonResponse = try await request(params: [
            "i": imdbID,
            "Season": String(season),
        ])
        return response.episodes.compactMap { episode in
            guard let episodeNumber = Int(episode.episode ?? "") else { return nil }
            let episodeID = episode.imdbID.validIMDbID ?? "\(imdbID)-s\(season)e\(episodeNumber)"
            return Episode(
                id: episodeID,
                mediaId: imdbID,
                seasonNumber: season,
                episodeNumber: episodeNumber,
                title: episode.title.nilIfPlaceholder,
                overview: nil,
                airDate: episode.released.nilIfPlaceholder,
                stillPath: nil,
                runtime: nil
            )
        }
    }

    private func seriesDetail(for id: String, type: MediaType) async throws -> OMDbTitleResponse? {
        guard type == .series else { return nil }
        if let imdbID = Self.imdbID(from: id) {
            return try await request(params: ["i": imdbID, "plot": "short"])
        }

        guard let lookup = Self.titleLookup(from: id) else { return nil }
        var params = [
            "t": lookup.title,
            "type": type.omdbType,
            "plot": "short",
        ]
        if let year = lookup.year {
            params["y"] = String(year)
        }
        return try await request(params: params)
    }

    private func seriesIMDbID(for id: String, type: MediaType) async throws -> String? {
        guard type == .series else { return nil }
        if let imdbID = Self.imdbID(from: id) {
            return imdbID
        }
        return try await seriesDetail(for: id, type: type)?.imdbID?.validIMDbID
    }

    private func curatedResult(ids: [String], type: MediaType, page: Int) async throws -> MetadataSearchResult {
        guard page <= 1 else {
            return MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: ids.count)
        }

        var items: [MediaPreview] = []
        for id in ids {
            guard !Task.isCancelled else { break }
            if let detail = try? await getDetail(id: id, type: type) {
                items.append(detail.mediaPreview)
            }
        }
        return MetadataSearchResult(items: items, page: 1, totalPages: 1, totalResults: items.count)
    }

    private func enrichedSearchPreviews(
        from previews: [MediaPreview],
        fallbackType: MediaType?
    ) async -> [MediaPreview] {
        guard !previews.isEmpty else { return [] }

        let maxConcurrentEnrichments = 3
        var indexed: [(Int, MediaPreview)] = []
        indexed.reserveCapacity(previews.count)
        var startIndex = previews.startIndex

        while startIndex < previews.endIndex {
            let endIndex = min(startIndex + maxConcurrentEnrichments, previews.endIndex)
            let batchResults = await withTaskGroup(of: (Int, MediaPreview).self) { group in
                for index in startIndex..<endIndex {
                    let preview = previews[index]
                    group.addTask { [self] in
                        let enriched = await enrichedSearchPreview(preview, fallbackType: fallbackType)
                        return (index, enriched)
                    }
                }

                var results: [(Int, MediaPreview)] = []
                results.reserveCapacity(endIndex - startIndex)
                for await item in group {
                    results.append(item)
                }
                return results
            }
            indexed.append(contentsOf: batchResults)
            startIndex = endIndex
        }

        return indexed.sorted { $0.0 < $1.0 }.map(\.1)
    }

    private func enrichedSearchPreview(
        _ preview: MediaPreview,
        fallbackType: MediaType?
    ) async -> MediaPreview {
        do {
            let response: OMDbTitleResponse = try await request(params: ["i": preview.id, "plot": "short"])
            guard response.normalizedIMDbID == preview.id else { return preview }
            var enriched = response.mediaItem(fallbackType: fallbackType ?? preview.type).mediaPreview
            if enriched.posterPath == nil {
                enriched.posterPath = preview.posterPath
            }
            if enriched.backdropPath == nil {
                enriched.backdropPath = preview.backdropPath
            }
            return enriched
        } catch {
            return preview
        }
    }

    private func request<T: Decodable & OMDbResponseChecking>(params: [String: String]) async throws -> T {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw OMDbError.unauthorized }
        guard var components = URLComponents(string: baseURL) else { throw OMDbError.invalidURL }

        var queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        queryItems.append(URLQueryItem(name: "apikey", value: trimmedKey))
        components.queryItems = queryItems

        guard let url = components.url else { throw OMDbError.invalidURL }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OMDbError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw OMDbError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(T.self, from: data)
        if decoded.isFalseResponse {
            let message = decoded.errorMessage ?? "OMDb request failed."
            if message.localizedCaseInsensitiveContains("not found") {
                throw OMDbError.notFound
            }
            if message.localizedCaseInsensitiveContains("invalid api key") {
                throw OMDbError.unauthorized
            }
            throw OMDbError.apiError(message)
        }
        return decoded
    }

    private static func imdbID(from id: String) -> String? {
        IMDbIdentifierPolicy.firstID(in: id)
    }

    private static func titleLookup(from id: String) -> (title: String, year: Int?)? {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return nil }

        if trimmedID.hasSuffix(")"),
           let openRange = trimmedID.range(of: " (", options: .backwards) {
            let yearStart = openRange.upperBound
            let yearEnd = trimmedID.index(before: trimmedID.endIndex)
            let yearString = String(trimmedID[yearStart..<yearEnd])
            let title = String(trimmedID[..<openRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if yearString.count == 4, let year = Int(yearString), !title.isEmpty {
                return (title, year)
            }
        }

        return (trimmedID, nil)
    }
}

private protocol OMDbResponseChecking {
    var response: String? { get }
    var errorMessage: String? { get }
}

private extension OMDbResponseChecking {
    var isFalseResponse: Bool { response?.localizedCaseInsensitiveCompare("False") == .orderedSame }
}

private enum OMDbArtworkURLPolicy {
    private static let allowedExactHosts: Set<String> = [
        "img.omdbapi.com",
        "ia.media-imdb.com",
        "images-na.ssl-images-amazon.com",
        "m.media-amazon.com",
    ]

    static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https",
              url.port == nil || url.port == 443,
              let host = url.host?.lowercased(),
              !host.isEmpty else {
            return false
        }
        return allowedExactHosts.contains(host) || host.hasSuffix(".media-amazon.com")
    }
}

private struct OMDbSearchResponse: Decodable, OMDbResponseChecking {
    let search: [OMDbSearchItem]
    let totalResults: String?
    let response: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case search = "Search"
        case totalResults
        case response = "Response"
        case errorMessage = "Error"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        search = try container.decodeIfPresent([OMDbSearchItem].self, forKey: .search) ?? []
        totalResults = try container.decodeIfPresent(String.self, forKey: .totalResults)
        response = try container.decodeIfPresent(String.self, forKey: .response)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }
}

private struct OMDbSearchItem: Decodable {
    let title: String
    let year: String?
    let imdbID: String
    let type: String?
    let poster: String?

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case year = "Year"
        case imdbID
        case type = "Type"
        case poster = "Poster"
    }

    var mediaPreview: MediaPreview? {
        guard let mediaType = MediaType(omdbType: type), let stableID = imdbID.validIMDbID else { return nil }
        return MediaPreview(
            id: stableID,
            type: mediaType,
            title: title.nilIfPlaceholder ?? "Unknown",
            year: year.omdbYear,
            posterPath: poster.validOMDbArtworkPath,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: nil
        )
    }
}

private struct OMDbTitleResponse: Decodable, OMDbResponseChecking {
    let title: String?
    let year: String?
    let rated: String?
    let released: String?
    let runtime: String?
    let genre: String?
    let plot: String?
    let poster: String?
    let imdbRating: String?
    let imdbID: String?
    let type: String?
    let totalSeasons: String?
    let response: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case year = "Year"
        case rated = "Rated"
        case released = "Released"
        case runtime = "Runtime"
        case genre = "Genre"
        case plot = "Plot"
        case poster = "Poster"
        case imdbRating
        case imdbID
        case type = "Type"
        case totalSeasons
        case response = "Response"
        case errorMessage = "Error"
    }

    func mediaItem(fallbackType: MediaType) -> MediaItem {
        let mediaType = MediaType(omdbType: type) ?? fallbackType
        let normalizedTitle = title.nilIfPlaceholder
        let displayTitle = normalizedTitle ?? "Unknown"
        let parsedYear = year.omdbYear
        let stableID: String
        if let imdbID = imdbID?.validIMDbID {
            stableID = imdbID
        } else if let normalizedTitle {
            stableID = parsedYear.map { "\(normalizedTitle) (\($0))" } ?? normalizedTitle
        } else {
            stableID = parsedYear.map { "Unknown (\($0))" } ?? "Unknown"
        }
        return MediaItem(
            id: stableID,
            type: mediaType,
            title: displayTitle,
            year: parsedYear,
            posterPath: poster.validOMDbArtworkPath,
            backdropPath: nil,
            overview: plot.nilIfPlaceholder,
            genres: genre.omdbGenres,
            imdbRating: Double(imdbRating.nilIfPlaceholder ?? ""),
            runtime: runtime.omdbRuntimeMinutes,
            status: rated.nilIfPlaceholder,
            tmdbId: nil,
            lastFetched: Date()
        )
    }

    var normalizedIMDbID: String? {
        imdbID?.validIMDbID
    }
}

private struct OMDbSeasonResponse: Decodable, OMDbResponseChecking {
    let title: String?
    let season: String?
    let episodes: [OMDbEpisodeItem]
    let response: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case season = "Season"
        case episodes = "Episodes"
        case response = "Response"
        case errorMessage = "Error"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        season = try container.decodeIfPresent(String.self, forKey: .season)
        episodes = try container.decodeIfPresent([OMDbEpisodeItem].self, forKey: .episodes) ?? []
        response = try container.decodeIfPresent(String.self, forKey: .response)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }
}

private struct OMDbEpisodeItem: Decodable {
    let title: String?
    let released: String?
    let episode: String?
    let imdbRating: String?
    let imdbID: String?

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case released = "Released"
        case episode = "Episode"
        case imdbRating
        case imdbID
    }
}

enum OMDbError: LocalizedError, Equatable, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case unsupported(String)
    case apiError(String)
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OMDb URL."
        case .invalidResponse:
            return "Invalid OMDb response."
        case .unauthorized:
            return "Invalid OMDb API key."
        case .notFound:
            return "OMDb title not found."
        case .unsupported(let message):
            return message
        case .apiError(let message):
            return message
        case .httpError(let status, let message):
            return "OMDb HTTP \(status): \(message)"
        }
    }
}

private enum OMDbDiscoveryCatalog {
    static func trendingIDs(for type: MediaType) -> [String] {
        switch type {
        case .movie:
            return ["tt15239678", "tt15398776", "tt9362722", "tt6263850", "tt1517268", "tt16426418", "tt17526714", "tt6718170"]
        case .series:
            return ["tt11280740", "tt3581920", "tt11198330", "tt0944947", "tt0903747", "tt14452776", "tt12637874", "tt2861424"]
        }
    }

    static func ids(for category: MediaCategory, type: MediaType) -> [String] {
        switch (category, type) {
        case (.topRated, .movie):
            return ["tt0111161", "tt0068646", "tt0468569", "tt0167260", "tt0108052", "tt0137523", "tt0120737", "tt1375666"]
        case (.topRated, .series):
            return ["tt0903747", "tt0185906", "tt5491994", "tt7366338", "tt0306414", "tt0944947", "tt2395695", "tt2098220"]
        case (.nowPlaying, .movie), (.upcoming, .movie):
            return ["tt15239678", "tt6263850", "tt17526714", "tt16426418", "tt14230458", "tt19847976", "tt9218128", "tt14948432"]
        case (.airingToday, .series), (.onTheAir, .series):
            return ["tt11280740", "tt3581920", "tt14452776", "tt12637874", "tt11198330", "tt2861424", "tt2085059", "tt10986410"]
        default:
            return trendingIDs(for: type)
        }
    }

    static func query(for genreId: Int?, type: MediaType) -> String {
        guard let genreId else { return type == .movie ? "movie" : "series" }
        switch genreId {
        case 28, 10759: return "action"
        case 12: return "adventure"
        case 16: return "animated"
        case 35: return "comedy"
        case 80: return "crime"
        case 99: return "documentary"
        case 18: return "drama"
        case 14, 10765: return "fantasy"
        case 27: return "horror"
        case 9648: return "mystery"
        case 10749: return "romance"
        case 878: return "sci-fi"
        case 53: return "thriller"
        default: return type == .movie ? "movie" : "series"
        }
    }

    static func genres(for type: MediaType) -> [Genre] {
        switch type {
        case .movie:
            return [
                Genre(id: 28, name: "Action"), Genre(id: 12, name: "Adventure"),
                Genre(id: 16, name: "Animation"), Genre(id: 35, name: "Comedy"),
                Genre(id: 80, name: "Crime"), Genre(id: 99, name: "Documentary"),
                Genre(id: 18, name: "Drama"), Genre(id: 14, name: "Fantasy"),
                Genre(id: 27, name: "Horror"), Genre(id: 9648, name: "Mystery"),
                Genre(id: 10749, name: "Romance"), Genre(id: 878, name: "Science Fiction"),
                Genre(id: 53, name: "Thriller"),
            ]
        case .series:
            return [
                Genre(id: 10759, name: "Action & Adventure"), Genre(id: 16, name: "Animation"),
                Genre(id: 35, name: "Comedy"), Genre(id: 80, name: "Crime"),
                Genre(id: 99, name: "Documentary"), Genre(id: 18, name: "Drama"),
                Genre(id: 10765, name: "Sci-Fi & Fantasy"), Genre(id: 9648, name: "Mystery"),
            ]
        }
    }
}

private extension MediaItem {
    var mediaPreview: MediaPreview {
        MediaPreview(
            id: id,
            type: type,
            title: title,
            year: year,
            posterPath: posterPath,
            backdropPath: backdropPath,
            imdbRating: imdbRating,
            tmdbId: tmdbId
        )
    }
}

private extension MediaType {
    var omdbType: String {
        switch self {
        case .movie: return "movie"
        case .series: return "series"
        }
    }

    init?(omdbType: String?) {
        switch omdbType?.lowercased() {
        case "movie": self = .movie
        case "series": self = .series
        default: return nil
        }
    }
}

private extension Optional where Wrapped == String {
    var validIMDbID: String? {
        guard let value = self else { return nil }
        return value.validIMDbID
    }

    var validOMDbArtworkPath: String? {
        guard let value = self else { return nil }
        return value.validOMDbArtworkPath
    }

    var nilIfPlaceholder: String? {
        guard let value = self else { return nil }
        return value.nilIfPlaceholder
    }

    var omdbYear: Int? {
        guard let value = self else { return nil }
        return value.omdbYear
    }

    var omdbRuntimeMinutes: Int? {
        guard let value = self else { return nil }
        return value.omdbRuntimeMinutes
    }

    var omdbGenres: [String] {
        guard let value = self else { return [] }
        return value.omdbGenres
    }
}

private extension String {
    var validIMDbID: String? {
        IMDbIdentifierPolicy.normalizedID(from: self)
    }

    var validOMDbArtworkPath: String? {
        guard let trimmed = nilIfPlaceholder else { return nil }
        guard let url = URL(string: trimmed),
              OMDbArtworkURLPolicy.isAllowed(url) else {
            return nil
        }
        return trimmed
    }

    var nilIfPlaceholder: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "n/a" else { return nil }
        return trimmed
    }

    var omdbYear: Int? {
        guard let value = nilIfPlaceholder else { return nil }
        let prefix = value.prefix(4)
        return prefix.count == 4 ? Int(prefix) : nil
    }

    var omdbRuntimeMinutes: Int? {
        guard let value = nilIfPlaceholder,
              let number = value.split(separator: " ").first.flatMap({ Int($0) }),
              number > 0 else {
            return nil
        }
        return number
    }

    var omdbGenres: [String] {
        split(separator: ",")
            .compactMap { String($0).nilIfPlaceholder }
    }
}
