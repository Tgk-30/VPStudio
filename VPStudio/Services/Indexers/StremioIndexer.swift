import CryptoKit
import Foundation
import os

struct StremioIndexer: TorrentIndexer {
    private static let logger = Logger(subsystem: "com.vpstudio", category: "stremio-indexer")
    private static let requestLimiter = IndexerRequestLimiter()
    private static let maximumStreamResults = 500
    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        return URLSession(configuration: configuration)
    }()

    let name: String
    private let baseURL: String
    private let endpointPath: String
    private let session: URLSession

    init(name: String, baseURL: String, endpointPath: String = "/manifest.json", session: URLSession? = nil) {
        self.name = name
        self.baseURL = baseURL
        self.endpointPath = endpointPath
        self.session = session ?? Self.defaultSession
    }

    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
        #if DEBUG
        Self.logger.debug("[\(self.name, privacy: .public)] search entered imdbId=\(imdbId, privacy: .public)")
        #endif
        let streamURL = try makeStreamURL(type: type, mediaID: streamMediaID(baseID: imdbId, type: type, season: season, episode: episode))

        #if DEBUG
        Self.logger.debug("[\(self.name, privacy: .public)] fetching \(IndexerLogSanitizer.redactedURL(streamURL), privacy: .public)")
        #endif

        let (data, response) = try await Self.requestLimiter.data(from: streamURL, session: session)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            #if DEBUG
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            Self.logger.error("[\(self.name, privacy: .public)] HTTP \(code, privacy: .public) from \(streamURL.host ?? "", privacy: .public)")
            #endif
            throw URLError(.badServerResponse)
        }

        let results = try parseStreamPayload(data)
        #if DEBUG
        Self.logger.debug("[\(self.name, privacy: .public)] parsed \(results.count, privacy: .public) results (data: \(data.count, privacy: .public) bytes)")
        #endif
        return results
    }

    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
        let episodeContext = EpisodeTokenMatcher.context(fromQuery: query)
        let shouldAnnotateEpisodeContext = type == .series
        if let imdbID = extractIMDbID(from: query) {
            let results = try await search(
                imdbId: imdbID,
                type: type,
                season: episodeContext?.season,
                episode: episodeContext?.episode
            )
            if shouldAnnotateEpisodeContext {
                return annotateEpisodeContextIfNeeded(
                    in: results,
                    season: episodeContext?.season,
                    episode: episodeContext?.episode
                )
            }
            return results
        }

        let mediaIDs: [String]
        do {
            mediaIDs = try await searchCatalogMediaIDs(query: query, type: type)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Self.isNonSearchableCatalogFallback(error) {
                Self.logger.debug("Stremio search skipped — addon has no searchable catalogs for query: \(query, privacy: .private)")
                return []
            }
            throw error
        }
        guard !mediaIDs.isEmpty else {
            Self.logger.debug("Stremio search skipped — no catalog matches for query: \(query, privacy: .private)")
            return []
        }

        var collected: [TorrentResult] = []
        var firstError: Error?
        for mediaID in mediaIDs {
            do {
                let streamURL = try makeStreamURL(
                    type: type,
                    mediaID: streamMediaID(baseID: mediaID, type: type, season: episodeContext?.season, episode: episodeContext?.episode)
                )
                let (data, response) = try await Self.requestLimiter.data(from: streamURL, session: session)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                collected.append(contentsOf: try parseStreamPayload(data))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        if !collected.isEmpty {
            if shouldAnnotateEpisodeContext {
                return annotateEpisodeContextIfNeeded(
                    in: collected,
                    season: episodeContext?.season,
                    episode: episodeContext?.episode
                )
            }
            return collected
        }
        if let firstError {
            throw firstError
        }
        return []
    }

    private static func isNonSearchableCatalogFallback(_ error: Error) -> Bool {
        guard case let IndexerParseError.invalidPayload(_, reason) = error else {
            return false
        }
        let normalized = reason.lowercased()
        return normalized == "manifest did not include any catalogs"
            || normalized.contains("did not include any searchable")
    }

    private static let imdbIDPattern = SensitiveURLQueryPolicy.regularExpression(pattern: #"tt\d+"#, options: [.caseInsensitive])
    private static let catalogPathValueAllowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private struct ManifestResponse: Decodable {
        let catalogs: [CatalogDefinition]?
        let resources: [StremioManifestResource]?
        let idPrefixes: [String]?

        var capability: StremioManifestCapability {
            StremioManifestCapability(
                resources: resources ?? [],
                catalogs: (catalogs ?? []).map {
                    StremioManifestCapability.Catalog(type: $0.type, supportsSearch: $0.supportsSearch)
                },
                idPrefixes: idPrefixes ?? []
            )
        }
    }

    private struct CatalogDefinition: Decodable {
        let id: String
        let type: String
        let extra: [CatalogExtra]?

        var supportsSearch: Bool {
            extra?.contains(where: { $0.name.caseInsensitiveCompare("search") == .orderedSame }) == true
        }
    }

    private struct CatalogExtra: Decodable {
        let name: String
    }

    private struct CatalogSearchResponse: Decodable {
        let metas: [CatalogMeta]?
    }

    private struct CatalogMeta: Decodable {
        let id: String
        let name: String?
        let type: String?
        let releaseInfo: String?
    }

    private func searchCatalogMediaIDs(query: String, type: MediaType) async throws -> [String] {
        let manifest = try await fetchManifest()
        let catalogs = try validatedCatalogs(from: manifest, type: type)

        var metas: [CatalogMeta] = []
        var firstError: Error?
        for catalog in catalogs {
            do {
                metas.append(contentsOf: try await fetchCatalogMetas(query: query, type: type, catalogID: catalog.id))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        let selectedIDs = selectCatalogMediaIDs(from: metas, query: query, type: type)
        if !selectedIDs.isEmpty {
            return selectedIDs
        }
        if let firstError {
            throw firstError
        }
        return []
    }

    private func fetchManifest() async throws -> ManifestResponse {
        let manifestURL = try makeManifestURL()
        let (data, response) = try await Self.requestLimiter.data(from: manifestURL, session: session)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ManifestResponse.self, from: data)
        } catch {
            throw IndexerParseError.invalidPayload(
                indexer: name,
                reason: "manifest payload malformed JSON payload"
            )
        }
    }

    private func fetchCatalogMetas(query: String, type: MediaType, catalogID: String) async throws -> [CatalogMeta] {
        let catalogURL = try makeCatalogSearchURL(type: type, catalogID: catalogID, query: query)
        let (data, response) = try await Self.requestLimiter.data(from: catalogURL, session: session)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let payload: CatalogSearchResponse
        do {
            payload = try decoder.decode(CatalogSearchResponse.self, from: data)
        } catch {
            throw IndexerParseError.invalidPayload(
                indexer: name,
                reason: "catalog payload malformed JSON payload"
            )
        }
        return payload.metas ?? []
    }

    private func validatedCatalogs(from manifest: ManifestResponse, type: MediaType) throws -> [CatalogDefinition] {
        let catalogs = manifest.catalogs ?? []
        // A stream-only addon (declares the `stream` resource) without any
        // searchable catalogs cannot service free-text catalog lookups, but it
        // is still a valid, compatible addon. Degrade gracefully to no catalog
        // matches rather than surfacing it as a hard error.
        let supportsStream = StremioManifestCapabilityPolicy.supportsStreamResource(manifest.capability)

        guard !catalogs.isEmpty else {
            throw IndexerParseError.invalidPayload(
                indexer: name,
                reason: supportsStream
                    ? "manifest did not include any searchable catalogs (stream resource only)"
                    : "manifest did not include any catalogs"
            )
        }

        let compatible = catalogs.filter { catalog in
            catalog.type.caseInsensitiveCompare(stremioTypePath(for: type)) == .orderedSame && catalog.supportsSearch
        }
        guard !compatible.isEmpty else {
            throw IndexerParseError.invalidPayload(
                indexer: name,
                reason: "manifest did not include any searchable \(type == .movie ? "movie" : "series") catalogs"
            )
        }
        return compatible
    }

    private func makeCatalogSearchURL(type: MediaType, catalogID: String, query: String) throws -> URL {
        let base = try makeManifestURL().deletingLastPathComponent()
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        let basePath = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encodedCatalogID = catalogID.addingPercentEncoding(withAllowedCharacters: Self.catalogPathValueAllowedCharacters) ?? catalogID
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: Self.catalogPathValueAllowedCharacters) ?? query
        let suffix = "catalog/\(stremioTypePath(for: type))/\(encodedCatalogID)/search=\(encodedQuery).json"
        components.percentEncodedPath = basePath.isEmpty ? "/\(suffix)" : "/\(basePath)/\(suffix)"

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        guard IndexerURLSecurityPolicy.permits(url: url) else {
            throw URLError(.unsupportedURL)
        }
        return url
    }

    private func selectCatalogMediaIDs(from metas: [CatalogMeta], query: String, type: MediaType) -> [String] {
        let eligible = metas.filter { meta in
            meta.type == nil || (meta.type?.caseInsensitiveCompare(stremioTypePath(for: type)) == .orderedSame)
        }
        guard !eligible.isEmpty else { return [] }

        let normalizedQueryTitle = normalizedSearchTitle(from: query)
        guard !normalizedQueryTitle.isEmpty else { return [] }
        let queryYear = extractYear(from: query)
        let ranked = eligible.map { meta in
            (meta: meta, score: catalogScore(for: meta, normalizedQueryTitle: normalizedQueryTitle, queryYear: queryYear))
        }
        let source = ranked.filter { $0.score > 0 }
        guard !source.isEmpty else { return [] }

        let rankedIDs = source
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return ($0.meta.name ?? "") < ($1.meta.name ?? "")
            }
            .map { $0.meta.id }

        var selected: [String] = []
        var seen: Set<String> = []
        for id in rankedIDs {
            if seen.insert(id).inserted {
                selected.append(id)
                if selected.count == 3 { break }
            }
        }
        return selected
    }

    private func catalogScore(for meta: CatalogMeta, normalizedQueryTitle: String, queryYear: Int?) -> Int {
        let normalizedCandidateTitle = normalizedTitle(meta.name ?? "")
        var score = 0

        if !normalizedQueryTitle.isEmpty {
            if normalizedCandidateTitle == normalizedQueryTitle {
                score += 300
            } else if normalizedCandidateTitle.hasPrefix(normalizedQueryTitle) {
                score += 200
            } else if normalizedCandidateTitle.contains(normalizedQueryTitle) {
                score += 100
            }
        }

        if let queryYear, let releaseYear = extractYear(from: meta.releaseInfo), releaseYear == queryYear {
            score += 25
        }

        return score
    }

    private func normalizedSearchTitle(from query: String) -> String {
        let regexOptions: String.CompareOptions = [.regularExpression, .caseInsensitive]
        var trimmed = query.replacingOccurrences(of: #"tt\d+"#, with: " ", options: regexOptions)
        trimmed = trimmed.replacingOccurrences(of: #"s\s*\d{1,2}\s*e\s*\d{1,3}"#, with: " ", options: regexOptions)
        trimmed = trimmed.replacingOccurrences(of: #"\d{1,2}\s*x\s*\d{1,3}"#, with: " ", options: regexOptions)
        trimmed = trimmed.replacingOccurrences(of: #"season\D*\d{1,2}.{0,20}episode\D*\d{1,3}"#, with: " ", options: regexOptions)
        trimmed = trimmed.replacingOccurrences(of: #"\b(19|20)\d{2}\b"#, with: " ", options: regexOptions)
        return normalizedTitle(trimmed)
    }

    private func normalizedTitle(_ value: String) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let cleaned = folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " "
        }
        .joined()
        return cleaned
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func extractYear(from value: String?) -> Int? {
        guard let value else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = try? NSRegularExpression(pattern: #"\b(19|20)\d{2}\b"#)
            .firstMatch(in: value, options: [], range: range),
              let matchRange = Range(match.range, in: value) else {
            return nil
        }
        return Int(value[matchRange])
    }

    private func annotateEpisodeContextIfNeeded(
        in results: [TorrentResult],
        season: Int?,
        episode: Int?
    ) -> [TorrentResult] {
        guard let season, let episode else { return results }
        let episodeToken = String(format: " S%02dE%02d", season, episode)

        return results.map { result in
            guard !EpisodeTokenMatcher.matches(title: result.title, season: season, episode: episode),
                  EpisodeTokenMatcher.matchesIfPresent(title: result.title, season: season, episode: episode) else {
                return result
            }
            var copy = result
            copy.title += episodeToken
            return copy
        }
    }

    private func makeManifestURL() throws -> URL {
        try StremioAddonURLBuilder.manifestURL(baseURL: baseURL, endpointPath: endpointPath)
    }

    private func makeStreamURL(type: MediaType, mediaID: String) throws -> URL {
        let manifestURL = try makeManifestURL()
        let base = manifestURL.deletingLastPathComponent()
        let typePath = stremioTypePath(for: type)
        return base
            .appendingPathComponent("stream")
            .appendingPathComponent(typePath)
            .appendingPathComponent("\(mediaID).json")
    }

    private func streamMediaID(baseID: String, type: MediaType, season: Int?, episode: Int?) -> String {
        guard type == .series, let season, let episode else {
            return baseID
        }
        return "\(baseID):\(season):\(episode)"
    }

    private func stremioTypePath(for type: MediaType) -> String {
        type == .movie ? "movie" : "series"
    }

    private func parseStreamPayload(_ data: Data) throws -> [TorrentResult] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw IndexerParseError.invalidPayload(
                indexer: name,
                reason: "malformed JSON payload"
            )
        }

        guard let dictionary = object as? [String: Any] else {
            throw IndexerParseError.invalidPayload(
                indexer: name,
                reason: "payload was not a JSON object"
            )
        }

        guard let streams = dictionary["streams"] as? [[String: Any]] else {
            throw IndexerParseError.invalidPayload(
                indexer: name,
                reason: "payload missing streams array"
            )
        }

        return streams.prefix(Self.maximumStreamResults).compactMap { stream in
            let title = (stream["title"] as? String)
                ?? (stream["name"] as? String)
                ?? "Stremio Stream"
            let urlString = stream["url"] as? String
            let externalURLString = stream["externalUrl"] as? String
            let magnetString = stream["magnet"] as? String
            let sources = stream["sources"] as? [String]
            let directStreamURL = Self.preferredDirectStreamURL(urlString: urlString)
            let lookupURLString = urlString ?? externalURLString ?? ""
            let hints = stream["behaviorHints"] as? [String: Any]
            let requestHeaders = Self.requestHeaders(fromProxyHeaders: hints?["proxyHeaders"])

            let infoHash: String? = {
                if let declared = stream["infoHash"] as? String {
                    let normalized = declared.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let normalizedHash = DebridHashValidator.normalizedInfoHash(normalized),
                       !normalizedHash.isEmpty {
                        return normalizedHash
                    }
                }

                if let extracted = JSONValueParsing.extractInfoHash(from: lookupURLString).flatMap(DebridHashValidator.normalizedInfoHash) {
                    return extracted
                }

                if let external = stream["externalUrl"] as? String,
                   let extracted = JSONValueParsing.extractInfoHash(from: external).flatMap(DebridHashValidator.normalizedInfoHash) {
                    return extracted
                }

                if let extracted = JSONValueParsing.extractInfoHash(from: stream["magnet"] as? String).flatMap(DebridHashValidator.normalizedInfoHash) {
                    return extracted
                }

                return nil
            }()
            let resultHash = infoHash ?? Self.syntheticDirectStreamHash(
                urlString: directStreamURL,
                title: title,
                indexerName: name
            )
            guard let resultHash, !resultHash.isEmpty else { return nil }

            let size = JSONValueParsing.parseInt64(hints?["videoSize"]) ?? 0
            let seeders = JSONValueParsing.parseInt(hints?["seeders"]) ?? 0
            let leechers = JSONValueParsing.parseInt(hints?["leechers"]) ?? 0

            return TorrentResult.fromSearch(
                infoHash: resultHash,
                title: title,
                sizeBytes: size,
                seeders: seeders,
                leechers: leechers,
                indexerName: name,
                magnetURI: Self.preferredMagnetURI(
                    infoHash: resultHash,
                    urlString: urlString,
                    externalURLString: externalURLString,
                    magnetString: magnetString,
                    sources: sources,
                    title: title
                ),
                directStreamURL: directStreamURL,
                directStreamRequestHeaders: requestHeaders
            )
        }
    }

    private static func preferredMagnetURI(
        infoHash: String,
        urlString: String?,
        externalURLString: String?,
        magnetString: String?,
        sources: [String]?,
        title: String
    ) -> String? {
        guard let normalizedHash = DebridHashValidator.normalizedInfoHash(infoHash) else {
            return nil
        }

        for candidate in [urlString, externalURLString, magnetString] {
            guard let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty,
                  trimmed.lowercased().hasPrefix("magnet:"),
                  DebridHashValidator.normalizedInfoHash(normalizedHash) == JSONValueParsing
                    .extractInfoHash(from: trimmed)
                    .flatMap(DebridHashValidator.normalizedInfoHash) else {
                continue
            }
            return trimmed
        }

        var queryItems = ["xt=urn:btih:\(normalizedHash)"]
        let displayTitle = title
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let displayTitle, !displayTitle.isEmpty {
            queryItems.append("dn=\(percentEncodeMagnetQueryValue(displayTitle))")
        }

        for tracker in trackerURLs(from: sources) {
            queryItems.append("tr=\(percentEncodeMagnetQueryValue(tracker))")
        }

        return "magnet:?\(queryItems.joined(separator: "&"))"
    }

    private static func trackerURLs(from sources: [String]?) -> [String] {
        var trackers: [String] = []
        var seen: Set<String> = []

        for source in sources ?? [] {
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let rawTracker: String
            if trimmed.lowercased().hasPrefix("tracker:") {
                rawTracker = String(trimmed.dropFirst("tracker:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                rawTracker = trimmed
            }
            let tracker = rawTracker.removingPercentEncoding ?? rawTracker

            guard !tracker.isEmpty, Self.isLikelyHTTPSTracker(tracker) else {
                continue
            }

            let key = tracker.lowercased()
            guard seen.insert(key).inserted else { continue }
            trackers.append(tracker)
        }

        return trackers
    }

    private static func isLikelyHTTPSTracker(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https", "udp"].contains(scheme) else {
            return false
        }

        if scheme == "udp" {
            return true
        }

        guard let host = components.host?.lowercased(),
              !host.isEmpty else {
            return false
        }

        let normalizedPath = components.path.lowercased()
        if Self.hasVideoFileSuffix(normalizedPath) {
            return false
        }

        return host.contains("tracker")
            || normalizedPath.hasSuffix("/announce")
            || normalizedPath.contains("/announce.")
    }

    private static func hasVideoFileSuffix(_ path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        guard !ext.isEmpty else {
            return false
        }

        let videoFileExtensions: Set<String> = ["3gp", "avi", "flv", "m4v", "mkv", "mov", "mp4", "mpg", "mpeg", "webm", "mkv2"]
        return videoFileExtensions.contains(ext)
    }

    private static func percentEncodeMagnetQueryValue(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func preferredDirectStreamURL(urlString: String?) -> String? {
        TorrentResult.normalizedDirectStreamURLString(urlString)
    }

    private static func requestHeaders(fromProxyHeaders value: Any?) -> [String: String]? {
        guard let proxyHeaders = value as? [String: Any],
              let request = proxyHeaders["request"] as? [String: Any] else {
            return nil
        }

        let headers = request.reduce(into: [String: String]()) { result, pair in
            guard let headerValue = pair.value as? String else { return }
            result[pair.key] = headerValue
        }

        return StreamInfo.normalizedRequestHeaders(headers)
    }

    private static func syntheticDirectStreamHash(
        urlString: String?,
        title: String,
        indexerName: String
    ) -> String? {
        guard let urlString else { return nil }
        let key = "\(indexerName)\n\(title)\n\(urlString)"
        let digest = SHA256.hash(data: Data(key.utf8))
        return "direct-\(digest.map { String(format: "%02x", $0) }.joined().prefix(40))"
    }

    private func extractIMDbID(from query: String) -> String? {
        let range = NSRange(query.startIndex..<query.endIndex, in: query)
        guard let imdbIDPattern = Self.imdbIDPattern,
              let match = imdbIDPattern.firstMatch(in: query, options: [], range: range),
              let matchRange = Range(match.range, in: query) else {
            return nil
        }
        return String(query[matchRange])
    }
}

enum StremioAddonURLBuilder {
    static func normalizedAddonURLString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        guard var components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "stremio" else {
            return trimmed
        }

        guard let host = components.host, !host.isEmpty else {
            return trimmed
        }

        components.scheme = "https"
        return components.string ?? trimmed
    }

    static func manifestURL(baseURL: String, endpointPath: String = "/manifest.json") throws -> URL {
        guard let normalizedBaseURL = normalizedAddonURLString(baseURL),
              var components = URLComponents(string: normalizedBaseURL) else {
            throw URLError(.badURL)
        }
        guard IndexerURLSecurityPolicy.permitsBaseURL(normalizedBaseURL) else {
            throw URLError(.unsupportedURL)
        }

        let normalizedBase = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedEndpoint = normalizedEndpointPath(endpointPath)

        if normalizedBase.isEmpty {
            components.path = "/\(normalizedEndpoint)"
        } else if path(normalizedBase, endsWith: normalizedEndpoint) {
            components.path = "/\(normalizedBase)"
        } else {
            components.path = "/\(normalizedBase)/\(normalizedEndpoint)"
        }

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        guard IndexerURLSecurityPolicy.permits(url: url) else {
            throw URLError(.unsupportedURL)
        }
        return url
    }

    private static func normalizedEndpointPath(_ endpointPath: String) -> String {
        let trimmed = endpointPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? "manifest.json" : trimmed
    }

    private static func path(_ path: String, endsWith endpointPath: String) -> Bool {
        let pathSegments = path.split(separator: "/").map(String.init)
        let endpointSegments = endpointPath.split(separator: "/").map(String.init)
        guard pathSegments.count >= endpointSegments.count else {
            return false
        }
        let suffix = pathSegments.suffix(endpointSegments.count).map { $0.lowercased() }
        return suffix == endpointSegments.map { $0.lowercased() }
    }
}
