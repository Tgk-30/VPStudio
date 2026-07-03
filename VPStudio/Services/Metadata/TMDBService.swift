import Foundation
import os

private enum TMDBResponseLimits {
    static let pageResults = 50
    static let imageAssets = 80
    static let expandedImagePreviewEnrichmentItems = 8
    static let personCredits = 160
    static let seasonEpisodes = 256
}

actor TMDBService: MetadataProvider {
    nonisolated var supportsPersonCreditSearch: Bool { true }

    private static let qaLogger = Logger(subsystem: "com.tgk30.VPStudio", category: "qa.tmdb")
    private static let maximumRateLimitAttempts = 3
    private static let initialBackoffNanoseconds: UInt64 = 500_000_000
    private static let maximumBackoffNanoseconds: UInt64 = 4_000_000_000

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
    private let baseURL = "https://api.themoviedb.org/3"
    private let plan: MetadataProviderPlan
    private let session: URLSession
    private let sleeper: @Sendable (UInt64) async throws -> Void

    private enum Authentication {
        case bearerToken(String)
        case apiKeyQuery(String)
    }

    init(
        apiKey: String,
        plan: MetadataProviderPlan = .free,
        session: URLSession? = nil,
        sleeper: @escaping @Sendable (UInt64) async throws -> Void = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.apiKey = apiKey
        self.plan = plan
        self.session = session ?? Self.defaultSession
        self.sleeper = sleeper
    }

    func search(query: String, type: MediaType?, page: Int = 1) async throws -> MetadataSearchResult {
        try await search(query: query, type: type, page: page, year: nil, language: nil)
    }

    func search(query: String, type: MediaType?, page: Int = 1, year: Int? = nil, language: String? = nil) async throws -> MetadataSearchResult {
        let path = type.map { "/search/\($0.tmdbPath)" } ?? "/search/multi"
        var params = ["query": query, "page": String(page), "include_adult": "false", "language": language ?? "en-US"]
        if let year, let type {
            params[type.tmdbSearchYearParameterName] = String(year)
        }
        let response: TMDBPagedResponse<TMDBSearchResult> = try await request(path: path, params: params)
        return await metadataSearchResult(from: response)
    }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem {
        let tmdbId: String
        if let extracted = extractTMDBID(from: id) { tmdbId = extracted }
        else if id.allSatisfy(\.isNumber) { tmdbId = id }
        else if let found = try await findByImdbId(id, type: type) { tmdbId = String(found) }
        else { throw TMDBError.notFound(id) }

        let response: TMDBDetailResponse = try await request(
            path: "/\(type.tmdbPath)/\(tmdbId)",
            params: [
                "append_to_response": plan.usesPaidResources ? "external_ids,credits,images" : "external_ids,credits",
                "language": "en-US",
            ]
        )
        return response.toMediaItem(type: type, prefersExpandedImages: plan.usesPaidResources)
    }

    func getTrending(type: MediaType, timeWindow: TrendingWindow = .week, page: Int = 1) async throws -> MetadataSearchResult {
        let response: TMDBPagedResponse<TMDBSearchResult> = try await request(
            path: "/trending/\(type.tmdbPath)/\(timeWindow.rawValue)",
            params: ["page": String(page), "language": "en-US"]
        )
        return await metadataSearchResult(from: response)
    }

    func getCategory(_ category: MediaCategory, type: MediaType, page: Int = 1) async throws -> MetadataSearchResult {
        let response: TMDBPagedResponse<TMDBSearchResult> = try await request(
            path: "/\(type.tmdbPath)/\(category.rawValue)",
            params: ["page": String(page), "language": "en-US"]
        )
        return await metadataSearchResult(from: response)
    }

    func discover(type: MediaType, filters: DiscoverFilters) async throws -> MetadataSearchResult {
        var params: [String: String] = [
            "page": String(filters.page), "sort_by": filters.sortBy.tmdbValue(for: type),
            "language": filters.language ?? "en-US", "include_adult": "false",
        ]
        if let g = filters.genreId { params["with_genres"] = String(g) }
        if let y = filters.year { params[type == .movie ? "primary_release_year" : "first_air_date_year"] = String(y) }
        if let r = filters.minRating { params["vote_average.gte"] = String(r); params["vote_count.gte"] = "100" }

        // Date range bounds
        let gteKey = type == .movie ? "release_date.gte" : "first_air_date.gte"
        let lteKey = type == .movie ? "release_date.lte" : "first_air_date.lte"
        if let gte = filters.releaseDateGte { params[gteKey] = gte }
        if let lte = filters.releaseDateLte { params[lteKey] = lte }

        // Original language filter (ISO 639-1)
        if let lang = filters.originalLanguage { params["with_original_language"] = lang }

        let response: TMDBPagedResponse<TMDBSearchResult> = try await request(path: "/discover/\(type.tmdbPath)", params: params)
        return await metadataSearchResult(from: response)
    }

    func searchPersonCredits(query: String, type: MediaType?, page: Int = 1) async throws -> MetadataSearchResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return MetadataSearchResult(items: [], page: page, totalPages: 1, totalResults: 0)
        }

        let personResponse: TMDBPagedResponse<TMDBPersonSearchResult> = try await request(
            path: "/search/person",
            params: [
                "query": trimmedQuery,
                "page": String(max(1, page)),
                "include_adult": "false",
                "language": "en-US",
            ]
        )

        var credits: [TMDBPersonCredit] = []
        let people = personResponse.results.prefix(page == 1 ? 3 : 1)
        for person in people {
            do {
                let response: TMDBPersonCombinedCreditsResponse = try await request(
                    path: "/person/\(person.id)/combined_credits",
                    params: ["language": "en-US"]
                )
                credits.append(contentsOf: response.cast)
                credits.append(contentsOf: response.crew.filter(\.isDirectorLikeCredit))
            } catch {
                credits.append(contentsOf: person.knownFor ?? [])
            }
        }

        var seenIDs: Set<String> = []
        let items = credits
            .compactMap { $0.toMediaPreview() }
            .filter { preview in
                guard type == nil || preview.type == type else { return false }
                return seenIDs.insert(preview.id).inserted
            }
            .sorted { lhs, rhs in
                if (lhs.year ?? 0) != (rhs.year ?? 0) {
                    return (lhs.year ?? 0) > (rhs.year ?? 0)
                }
                return (lhs.imdbRating ?? 0) > (rhs.imdbRating ?? 0)
            }

        let limitedItems = Array(items.prefix(24))
        return MetadataSearchResult(
            items: limitedItems,
            page: 1,
            totalPages: 1,
            totalResults: limitedItems.count
        )
    }

    func getGenres(type: MediaType) async throws -> [Genre] {
        let response: TMDBGenresResponse = try await request(path: "/genre/\(type.tmdbPath)/list", params: ["language": "en-US"])
        return response.genres.map { Genre(id: $0.id, name: $0.name) }
    }

    func getSeasons(tmdbId: Int) async throws -> [Season] {
        let response: TMDBTVDetailResponse = try await request(path: "/tv/\(tmdbId)", params: ["language": "en-US"])
        return response.seasons?.map { Season(
            id: $0.id, seasonNumber: $0.seasonNumber, name: $0.name,
            overview: $0.overview, posterPath: $0.posterPath,
            episodeCount: $0.episodeCount, airDate: $0.airDate
        ) } ?? []
    }

    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] {
        let response: TMDBSeasonResponse = try await request(path: "/tv/\(tmdbId)/season/\(season)", params: ["language": "en-US"])
        return response.episodes.map { Episode(
            id: "\(tmdbId)-s\(season)e\($0.episodeNumber)", mediaId: "tmdb-\(tmdbId)",
            seasonNumber: season, episodeNumber: $0.episodeNumber,
            title: $0.name, overview: $0.overview, airDate: $0.airDate,
            stillPath: $0.stillPath, runtime: $0.runtime
        ) }
    }

    func getExternalIds(tmdbId: Int, type: MediaType) async throws -> ExternalIds {
        try await request(path: "/\(type.tmdbPath)/\(tmdbId)/external_ids", params: [:])
    }

    func findByImdbId(_ imdbId: String, type: MediaType) async throws -> Int? {
        let response: TMDBFindResponse = try await request(path: "/find/\(imdbId)", params: ["external_source": "imdb_id"])
        return type == .movie ? response.movieResults.first?.id : response.tvResults.first?.id
    }

    private func request<T: Decodable>(path: String, params: [String: String]) async throws -> T {
        guard var components = URLComponents(string: baseURL + path) else { throw TMDBError.invalidURL(path) }
        guard let authentication = authenticationMode() else { throw TMDBError.unauthorized }

        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        if case .apiKeyQuery(let apiKey) = authentication {
            components.queryItems?.append(URLQueryItem(name: "api_key", value: apiKey))
        }

        guard let url = components.url else { throw TMDBError.invalidURL(path) }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if case .bearerToken(let token) = authentication {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            // Legacy v3 API keys must ride in the query string for compatibility.
            // Mark those requests as non-cacheable so local/remote intermediaries
            // are less likely to retain full URLs containing the credential.
            request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        }

        let responseData = try await responseData(for: request, path: path)
        Self.logQAResponse(path: path, byteCount: responseData.count)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: responseData)
    }

    private static func logQAResponse(path: String, byteCount: Int) {
        guard QARuntimeOptions.isEnabled else { return }
        qaLogger.info("QA-TMDB path=\(path, privacy: .public) bytes=\(byteCount, privacy: .public)")
    }

    private func responseData(for request: URLRequest, path: String, attempt: Int = 0) async throws -> Data {
        let (data, response) = try await BoundedHTTPResponseLoader.data(
            for: request,
            session: session,
            maximumBytes: HTTPResponseBudget.metadataProvider
        )
        guard let http = response as? HTTPURLResponse else { throw TMDBError.invalidResponse }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw TMDBError.unauthorized
        case 404:
            throw TMDBError.notFound(path)
        case 429:
            guard attempt < Self.maximumRateLimitAttempts - 1 else {
                throw TMDBError.rateLimited
            }

            let delay = Self.retryDelayNanoseconds(
                from: http.value(forHTTPHeaderField: "Retry-After"),
                attempt: attempt
            )
            try await sleeper(delay)
            return try await responseData(for: request, path: path, attempt: attempt + 1)
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TMDBError.httpError(http.statusCode, TMDBErrorRedactionPolicy.sanitized(body))
        }
    }

    private func authenticationMode() -> Authentication? {
        let trimmedCredential = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCredential.isEmpty else { return nil }

        if trimmedCredential.lowercased().hasPrefix("bearer ") {
            let token = trimmedCredential.dropFirst("bearer ".count).trimmingCharacters(in: .whitespacesAndNewlines)
            return token.isEmpty ? nil : .bearerToken(token)
        }

        if Self.looksLikeReadAccessToken(trimmedCredential) {
            return .bearerToken(trimmedCredential)
        }

        return .apiKeyQuery(trimmedCredential)
    }

    private static func looksLikeReadAccessToken(_ credential: String) -> Bool {
        let allowedJWTCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        let segments = credential.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { return false }

        return segments.allSatisfy { segment in
            !segment.isEmpty && segment.unicodeScalars.allSatisfy { allowedJWTCharacters.contains($0) }
        }
    }

    private static func retryDelayNanoseconds(from retryAfter: String?, attempt: Int) -> UInt64 {
        let exponentialDelay = min(
            maximumBackoffNanoseconds,
            initialBackoffNanoseconds * UInt64(1 << min(attempt, 3))
        )

        guard let parsedDelay = retryAfterDelay(from: retryAfter) else {
            return exponentialDelay
        }

        // Cap in Double space BEFORE converting — a hostile `Retry-After: 1e12` would make
        // UInt64(1e21) trap before the min() clamp runs.
        let cappedDelay = min(parsedDelay, Double(maximumBackoffNanoseconds) / 1_000_000_000)
        let retryAfterNanoseconds = UInt64((cappedDelay * 1_000_000_000).rounded())
        return min(maximumBackoffNanoseconds, max(exponentialDelay, retryAfterNanoseconds))
    }

    private static func retryAfterDelay(from headerValue: String?) -> TimeInterval? {
        guard let rawHeader = headerValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawHeader.isEmpty else {
            return nil
        }

        if let retryAfterSeconds = TimeInterval(rawHeader), retryAfterSeconds > 0 {
            return retryAfterSeconds
        }

        for format in [
            "EEE',' dd MMM yyyy HH':'mm':'ss zzz",
            "EEEE',' dd-MMM-yy HH':'mm':'ss zzz",
            "EEE MMM d HH':'mm':'ss yyyy",
        ] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format

            if let date = formatter.date(from: rawHeader) {
                let delay = date.timeIntervalSinceNow
                if delay > 0 {
                    return delay
                }
                return nil
            }
        }

        return nil
    }

    private func extractTMDBID(from id: String) -> String? {
        MetadataProviderIdentifierPolicy.tmdbID(from: id).map(String.init)
    }

    private func metadataSearchResult(from response: TMDBPagedResponse<TMDBSearchResult>) async -> MetadataSearchResult {
        let previews = response.results.compactMap { $0.toMediaPreview() }
        let items = await expandedImagePreviewsIfNeeded(previews)
        return MetadataSearchResult(
            items: items,
            page: response.page,
            totalPages: response.totalPages,
            totalResults: response.totalResults
        )
    }

    private func expandedImagePreviewsIfNeeded(_ previews: [MediaPreview]) async -> [MediaPreview] {
        guard plan.usesPaidResources, !previews.isEmpty else { return previews }

        let enrichmentLimit = min(previews.count, TMDBResponseLimits.expandedImagePreviewEnrichmentItems)
        let maxConcurrentEnrichments = 3
        var enriched = previews
        var startIndex = 0

        while startIndex < enrichmentLimit {
            let endIndex = min(startIndex + maxConcurrentEnrichments, enrichmentLimit)
            let batchResults = await withTaskGroup(of: (Int, MediaPreview).self) { group in
                for index in startIndex..<endIndex {
                    let preview = previews[index]
                    group.addTask { [self] in
                        let enrichedPreview = await expandedImagePreview(preview)
                        return (index, enrichedPreview)
                    }
                }

                var results: [(Int, MediaPreview)] = []
                results.reserveCapacity(endIndex - startIndex)
                for await item in group {
                    results.append(item)
                }
                return results
            }

            for (index, preview) in batchResults {
                enriched[index] = preview
            }
            startIndex = endIndex
        }

        return enriched
    }

    private func expandedImagePreview(_ preview: MediaPreview) async -> MediaPreview {
        guard let tmdbId = preview.tmdbId,
              let detail = try? await getDetail(id: "tmdb-\(tmdbId)", type: preview.type) else {
            return preview
        }

        var enriched = preview
        enriched.posterPath = detail.posterPath ?? preview.posterPath
        enriched.backdropPath = detail.backdropPath ?? preview.backdropPath
        return enriched
    }
}

// MARK: - TMDB Response Models

struct TMDBPagedResponse<T: Decodable & Sendable>: Sendable, Decodable {
    let page: Int; let results: [T]; let totalPages: Int; let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages
        case totalResults
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        results = Array((try container.decodeIfPresent([T].self, forKey: .results) ?? [])
            .prefix(TMDBResponseLimits.pageResults))
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) ?? 1
        totalResults = try container.decodeIfPresent(Int.self, forKey: .totalResults) ?? results.count
    }
}

struct TMDBSearchResult: Sendable {
    let id: Int; let title: String?; let name: String?; let mediaType: String?
    let overview: String?; let posterPath: String?; let backdropPath: String?
    let releaseDate: String?; let firstAirDate: String?; let voteAverage: Double?

    nonisolated func toMediaPreview() -> MediaPreview? {
        let displayTitle = title ?? name ?? ""
        guard !displayTitle.isEmpty else { return nil }
        let type: MediaType
        if let mt = mediaType {
            switch mt { case "movie": type = .movie; case "tv": type = .series; default: return nil }
        } else { type = title != nil ? .movie : .series }
        let year = (releaseDate ?? firstAirDate).flatMap { $0.count >= 4 ? Int($0.prefix(4)) : nil }
        return MediaPreview(
            id: "\(type.rawValue)-tmdb-\(id)",
            type: type,
            title: displayTitle,
            year: year,
            posterPath: posterPath,
            backdropPath: backdropPath,
            imdbRating: voteAverage,
            tmdbId: id
        )
    }
}
extension TMDBSearchResult: Decodable {}

struct TMDBDetailResponse: Sendable {
    let id: Int; let title: String?; let name: String?; let overview: String?
    let posterPath: String?; let backdropPath: String?; let releaseDate: String?
    let firstAirDate: String?; let voteAverage: Double?; let runtime: Int?
    let episodeRunTime: [Int]?; let status: String?; let genres: [TMDBGenre]?
    let externalIds: ExternalIds?; var images: TMDBImagesResponse? = nil

    nonisolated func toMediaItem(type: MediaType, prefersExpandedImages: Bool = false) -> MediaItem {
        let displayTitle = title ?? name ?? "Unknown"
        let year = (releaseDate ?? firstAirDate).flatMap { $0.count >= 4 ? Int($0.prefix(4)) : nil }
        let itemId = externalIds?.imdbId.flatMap { $0.isEmpty ? nil : $0 } ?? "tmdb-\(id)"
        let rt = (runtime ?? 0) > 0 ? runtime : episodeRunTime?.first
        let expandedPosterPath = prefersExpandedImages ? (images?.preferredPosterPath ?? posterPath) : posterPath
        let expandedBackdropPath = prefersExpandedImages ? (images?.preferredBackdropPath ?? backdropPath) : backdropPath
        return MediaItem(id: itemId, type: type, title: displayTitle, year: year, posterPath: expandedPosterPath,
                         backdropPath: expandedBackdropPath, overview: overview, genres: genres?.map(\.name) ?? [],
                         imdbRating: voteAverage, runtime: rt, status: status, tmdbId: id, lastFetched: Date())
    }
}
extension TMDBDetailResponse: Decodable {}

struct TMDBImagesResponse: Sendable, Decodable {
    let backdrops: [TMDBImageAsset]?
    let posters: [TMDBImageAsset]?

    enum CodingKeys: String, CodingKey {
        case backdrops
        case posters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backdrops = Array((try container.decodeIfPresent([TMDBImageAsset].self, forKey: .backdrops) ?? [])
            .prefix(TMDBResponseLimits.imageAssets))
        posters = Array((try container.decodeIfPresent([TMDBImageAsset].self, forKey: .posters) ?? [])
            .prefix(TMDBResponseLimits.imageAssets))
    }

    var preferredBackdropPath: String? {
        Self.preferredPath(from: backdrops)
    }

    var preferredPosterPath: String? {
        Self.preferredPath(from: posters)
    }

    private static func preferredPath(from assets: [TMDBImageAsset]?) -> String? {
        assets?
            .filter { $0.filePath?.isEmpty == false }
            .sorted {
                if $0.voteAverage != $1.voteAverage {
                    return ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0)
                }
                return ($0.voteCount ?? 0) > ($1.voteCount ?? 0)
            }
            .first?
            .filePath
    }
}

struct TMDBImageAsset: Sendable, Decodable {
    let filePath: String?
    let voteAverage: Double?
    let voteCount: Int?
}

struct TMDBGenre: Sendable { let id: Int; let name: String }
extension TMDBGenre: Decodable {}

struct TMDBGenresResponse: Sendable { let genres: [TMDBGenre] }
extension TMDBGenresResponse: Decodable {}

struct TMDBTVDetailResponse: Sendable { let id: Int; let seasons: [TMDBSeason]? }
extension TMDBTVDetailResponse: Decodable {}

struct TMDBSeason: Sendable { let id: Int; let seasonNumber: Int; let name: String; let overview: String?; let posterPath: String?; let episodeCount: Int; let airDate: String? }
extension TMDBSeason: Decodable {}

struct TMDBSeasonResponse: Sendable, Decodable {
    let episodes: [TMDBEpisode]

    enum CodingKeys: String, CodingKey {
        case episodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episodes = Array((try container.decodeIfPresent([TMDBEpisode].self, forKey: .episodes) ?? [])
            .prefix(TMDBResponseLimits.seasonEpisodes))
    }
}

struct TMDBEpisode: Sendable { let id: Int; let episodeNumber: Int; let name: String?; let overview: String?; let airDate: String?; let stillPath: String?; let runtime: Int? }
extension TMDBEpisode: Decodable {}

struct TMDBFindResponse: Sendable { let movieResults: [TMDBSearchResult]; let tvResults: [TMDBSearchResult] }
extension TMDBFindResponse: Decodable {}

struct TMDBPersonSearchResult: Sendable {
    let id: Int
    let name: String
    let knownFor: [TMDBPersonCredit]?
}
extension TMDBPersonSearchResult: Decodable {}

struct TMDBPersonCombinedCreditsResponse: Sendable, Decodable {
    let cast: [TMDBPersonCredit]
    let crew: [TMDBPersonCredit]

    enum CodingKeys: String, CodingKey {
        case cast
        case crew
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cast = Array((try container.decodeIfPresent([TMDBPersonCredit].self, forKey: .cast) ?? [])
            .prefix(TMDBResponseLimits.personCredits))
        crew = Array((try container.decodeIfPresent([TMDBPersonCredit].self, forKey: .crew) ?? [])
            .prefix(TMDBResponseLimits.personCredits))
    }
}

struct TMDBPersonCredit: Sendable {
    let id: Int
    let title: String?
    let name: String?
    let mediaType: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let department: String?
    let job: String?

    var isDirectorLikeCredit: Bool {
        let normalizedDepartment = department?.lowercased() ?? ""
        let normalizedJob = job?.lowercased() ?? ""
        return normalizedDepartment == "directing"
            || normalizedJob.contains("director")
            || normalizedJob.contains("creator")
            || normalizedJob.contains("showrunner")
    }

    func toMediaPreview() -> MediaPreview? {
        let displayTitle = title ?? name ?? ""
        guard !displayTitle.isEmpty else { return nil }
        let type: MediaType
        switch mediaType {
        case "movie":
            type = .movie
        case "tv":
            type = .series
        default:
            type = title != nil ? .movie : .series
        }

        let year = (releaseDate ?? firstAirDate).flatMap { value in
            value.count >= 4 ? Int(value.prefix(4)) : nil
        }

        return MediaPreview(
            id: "\(type.rawValue)-tmdb-\(id)",
            type: type,
            title: displayTitle,
            year: year,
            posterPath: posterPath,
            backdropPath: backdropPath,
            imdbRating: voteAverage,
            tmdbId: id
        )
    }
}
extension TMDBPersonCredit: Decodable {}

private enum TMDBErrorRedactionPolicy {
    private static let urlPattern = SensitiveURLQueryPolicy.regularExpression(
        pattern: #"(https?):\/\/[^\s"']+"#,
        options: [.caseInsensitive]
    )

    private static let sensitiveAssignmentPattern = SensitiveURLQueryPolicy.regularExpression(
        pattern: #"(?i)(?<![A-Za-z0-9_-])(?:"# + SensitiveURLQueryPolicy.assignmentNameAlternationPattern + #")=([^\s&]+)"#,
        options: []
    )

    static func sanitized(_ message: String) -> String {
        let urlRedacted = redactURLs(in: message)
        let assignmentRedacted = redactSensitiveAssignments(in: urlRedacted)
        return SensitiveURLQueryPolicy.redactedBearerTokens(in: assignmentRedacted)
    }

    private static func redactURLs(in message: String) -> String {
        guard let urlPattern else { return message }
        let nsRange = NSRange(message.startIndex..<message.endIndex, in: message)
        let matches = urlPattern.matches(in: message, options: [], range: nsRange)
        guard !matches.isEmpty else { return message }

        var redacted = message
        for match in matches.reversed() {
            guard let range = Range(match.range, in: redacted) else { continue }
            let candidate = String(redacted[range])
            redacted.replaceSubrange(range, with: redactedURLString(candidate))
        }
        return redacted
    }

    private static func redactedURLString(_ value: String) -> String {
        guard var components = URLComponents(string: value) else { return "<redacted-url>" }
        if components.user?.isEmpty == false {
            components.user = "REDACTED"
        }
        if components.password?.isEmpty == false {
            components.password = "REDACTED"
        }
        components.queryItems = components.queryItems?.map { item in
            URLQueryItem(
                name: item.name,
                value: SensitiveURLQueryPolicy.isSensitiveName(item.name) ? "REDACTED" : item.value
            )
        }
        components.fragment = nil
        return components.string ?? "<redacted-url>"
    }

    private static func redactSensitiveAssignments(in message: String) -> String {
        guard let sensitiveAssignmentPattern else { return message }
        let nsRange = NSRange(message.startIndex..<message.endIndex, in: message)
        let matches = sensitiveAssignmentPattern.matches(in: message, options: [], range: nsRange)
        guard !matches.isEmpty else { return message }

        var redacted = message
        for match in matches.reversed() {
            guard match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: redacted) else {
                continue
            }
            redacted.replaceSubrange(valueRange, with: "REDACTED")
        }
        return redacted
    }
}

enum TMDBError: LocalizedError, Equatable {
    case invalidURL(String), invalidResponse, unauthorized, notFound(String), rateLimited, httpError(Int, String)
    var errorDescription: String? {
        switch self {
        case .invalidURL(let p): return "Invalid TMDB URL: \(p)"
        case .invalidResponse: return "Invalid response"
        case .unauthorized: return "Invalid TMDb API key or read token"
        case .notFound(let id): return "Not found: \(id)"
        case .rateLimited: return "Rate limited"
        case .httpError(let c, let m): return "HTTP \(c): \(m)"
        }
    }
}
