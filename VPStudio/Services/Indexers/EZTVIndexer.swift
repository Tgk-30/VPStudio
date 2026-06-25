import Foundation

struct EZTVIndexer: TorrentIndexer {
    let name = "EZTV"
    private let baseURL: String
    private static let requestLimiter = IndexerRequestLimiter()
    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    private let session: URLSession

    init(baseURL: String = "https://eztvx.to/api", session: URLSession? = nil) {
        self.baseURL = baseURL
        self.session = session ?? Self.defaultSession
    }

    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
        guard type == .series else { return [] }
        guard let normalizedIMDbID = IMDbIdentifierPolicy.firstID(in: imdbId) else { return [] }
        let cleanId = String(normalizedIMDbID.dropFirst(2))

        var results: [TorrentResult] = []
        let maxPages = 3

        for page in 1...maxPages {
            let url = try buildURL(queryItems: [
                URLQueryItem(name: "imdb_id", value: cleanId),
                URLQueryItem(name: "limit", value: "100"),
                URLQueryItem(name: "page", value: String(page)),
            ])

            let (data, response) = try await Self.requestLimiter.data(from: url, session: session)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let eztvResponse = try decoder.decode(EZTVResponse.self, from: data)

            guard let torrents = eztvResponse.torrents, !torrents.isEmpty else { break }

            for torrent in torrents {
                guard let hash = torrent.hash, !hash.isEmpty else { continue }

                if let season,
                   let epSeason = positiveEpisodeComponent(from: torrent.season),
                   epSeason != season {
                    continue
                }
                if let episode,
                   let epNum = positiveEpisodeComponent(from: torrent.episode),
                   epNum != episode {
                    continue
                }
                if let season, let episode {
                    let titleForMatch = torrent.title ?? torrent.filename ?? ""
                    guard EpisodeTokenMatcher.matches(title: titleForMatch, season: season, episode: episode) else { continue }
                }

                let title = torrent.title ?? torrent.filename ?? "Unknown"
                let sizeBytes = torrent.sizeBytes.flatMap { Int64($0) } ?? 0

                results.append(TorrentResult.fromSearch(
                    infoHash: hash,
                    title: title,
                    sizeBytes: sizeBytes,
                    seeders: torrent.seeds ?? 0,
                    leechers: torrent.peers ?? 0,
                    indexerName: name,
                    magnetURI: torrent.magnetUrl
                ))
            }

            if torrents.count < 100 { break }
        }

        return results
    }

    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
        guard type == .series else { return [] }

        let context = EpisodeTokenMatcher.context(fromQuery: query)
        let maxPages = 3
        var allResults: [TorrentResult] = []

        for page in 1...maxPages {
            let url = try buildURL(queryItems: [
                URLQueryItem(name: "search", value: query),
                URLQueryItem(name: "limit", value: "100"),
                URLQueryItem(name: "page", value: String(page)),
            ])

            let (data, response) = try await Self.requestLimiter.data(from: url, session: session)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let eztvResponse = try decoder.decode(EZTVResponse.self, from: data)
            let torrents = eztvResponse.torrents ?? []
            if torrents.isEmpty { break }

            for torrent in torrents {
                guard let hash = torrent.hash, !hash.isEmpty else { continue }

                if let context {
                    if let epSeason = positiveEpisodeComponent(from: torrent.season), epSeason != context.season {
                        continue
                    }
                    if let epNum = positiveEpisodeComponent(from: torrent.episode), epNum != context.episode {
                        continue
                    }
                    let titleForMatch = torrent.title ?? torrent.filename ?? ""
                    guard EpisodeTokenMatcher.matches(
                        title: titleForMatch,
                        season: context.season,
                        episode: context.episode
                    ) else { continue }
                }

                allResults.append(TorrentResult.fromSearch(
                    infoHash: hash,
                    title: torrent.title ?? torrent.filename ?? "Unknown",
                    sizeBytes: torrent.sizeBytes.flatMap { Int64($0) } ?? 0,
                    seeders: torrent.seeds ?? 0,
                    leechers: torrent.peers ?? 0,
                    indexerName: name,
                    magnetURI: torrent.magnetUrl
                ))
            }

            if torrents.count < 100 { break }
        }

        return allResults
    }

    private func positiveEpisodeComponent(from rawValue: String?) -> Int? {
        guard let rawValue,
              let parsed = Int(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              parsed > 0 else {
            return nil
        }
        return parsed
    }

    private func buildURL(queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        let normalizedBasePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let appendPath = "get-torrents".trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch (normalizedBasePath.isEmpty, appendPath.isEmpty) {
        case (true, false):
            components.path = "/\(appendPath)"
        case (false, true):
            components.path = "/\(normalizedBasePath)"
        case (false, false):
            components.path = "/\(normalizedBasePath)/\(appendPath)"
        default:
            components.path = ""
        }
        components.queryItems = queryItems
        guard let url = components.url,
              IndexerURLSecurityPolicy.permits(url: url) else {
            throw URLError(.unsupportedURL)
        }
        return url
    }

}

private struct EZTVResponse: Decodable { let torrents: [EZTVTorrent]? }
private struct EZTVTorrent: Decodable {
    let hash: String?; let filename: String?; let title: String?
    let season: String?; let episode: String?
    let seeds: Int?; let peers: Int?; let sizeBytes: String?; let magnetUrl: String?
}
