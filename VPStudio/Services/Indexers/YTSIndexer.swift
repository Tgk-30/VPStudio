import Foundation

struct YTSIndexer: TorrentIndexer {
    let name = "YTS"
    static let apiBaseURLs = [
        "https://yts.torrentbay.st/api/v2",
        "https://yts.mx/api/v2",
        "https://yts.bz/api/v2",
    ]
    private static let requestLimiter = IndexerRequestLimiter()
    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    private let apiBaseURLs: [String]
    private let session: URLSession

    init(baseURLs: [String]? = nil, session: URLSession? = nil) {
        self.apiBaseURLs = baseURLs ?? Self.apiBaseURLs
        self.session = session ?? Self.defaultSession
    }

    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult] {
        guard type == .movie else { return [] }
        let ytsResponse = try await fetchResponse(queryTerm: imdbId)
        return mapResults(from: ytsResponse)
    }

    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult] {
        guard type == .movie else { return [] }
        let ytsResponse = try await fetchResponse(queryTerm: normalizedQueryTerm(from: query))
        return mapResults(from: ytsResponse)
    }

    private func fetchResponse(queryTerm: String) async throws -> YTSResponse {
        var lastError: Error = URLError(.badServerResponse)
        var lastEmptyResponse: YTSResponse?

        for baseURL in apiBaseURLs {
            let url: URL
            do {
                url = try buildSearchURL(baseURL: baseURL, queryTerm: queryTerm)
            } catch {
                lastError = error
                continue
            }

            do {
                let (data, response) = try await Self.requestLimiter.data(from: url, session: session)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let ytsResponse: YTSResponse
                do {
                    ytsResponse = try decoder.decode(YTSResponse.self, from: data)
                } catch {
                    throw IndexerParseError.invalidPayload(
                        indexer: name,
                        reason: "malformed JSON from \(url.host ?? "unknown-host")"
                    )
                }
                if let movies = ytsResponse.data?.movies, movies.isEmpty == false {
                    return ytsResponse
                }
                lastEmptyResponse = ytsResponse
            } catch let cancellationError as CancellationError {
                throw cancellationError
            } catch {
                lastError = error
            }
        }

        if let lastEmptyResponse { return lastEmptyResponse }
        throw lastError
    }

    private func mapResults(from response: YTSResponse) -> [TorrentResult] {
        var results: [TorrentResult] = []

        for movie in response.data?.movies ?? [] {
            for torrent in movie.torrents ?? [] {
                guard let hash = torrent.hash, !hash.isEmpty else { continue }

                let displayTitle = movie.titleLong ?? movie.title ?? "Unknown"
                let qualityBadge = torrent.quality.map { $0.isEmpty ? "" : " [\($0)]" } ?? ""
                let typeBadge = torrent.type.map { $0.isEmpty ? "" : " [\($0)]" } ?? ""

                results.append(
                    TorrentResult.fromSearch(
                        infoHash: hash,
                        title: "\(displayTitle)\(qualityBadge)\(typeBadge)",
                        sizeBytes: torrent.sizeBytes ?? 0,
                        seeders: torrent.seeds ?? 0,
                        leechers: torrent.peers ?? 0,
                        indexerName: name
                    )
                )
            }
        }

        return results
    }

    private func buildSearchURL(baseURL: String, queryTerm: String) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }

        let baseSegments = Self.pathSegments(components.path)
        let endpointSegments: [String]
        if baseSegments.suffix(3) == ["api", "v2", "list_movies.json"] {
            endpointSegments = []
        } else if baseSegments.suffix(2) == ["api", "v2"] {
            endpointSegments = ["list_movies.json"]
        } else {
            endpointSegments = ["api", "v2", "list_movies.json"]
        }
        components.path = Self.path(from: baseSegments + endpointSegments)

        components.queryItems = [
            URLQueryItem(name: "query_term", value: queryTerm),
            URLQueryItem(name: "limit", value: "20"),
        ]
        guard let url = components.url,
              IndexerURLSecurityPolicy.permits(url: url) else {
            throw URLError(.unsupportedURL)
        }
        return url
    }

    private static func pathSegments(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    private static func path(from segments: [String]) -> String {
        segments.isEmpty ? "" : "/" + segments.joined(separator: "/")
    }

    private func normalizedQueryTerm(from query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        var seen = Set<String>()
        var deduped: [String] = []
        deduped.reserveCapacity(trimmed.split(whereSeparator: \.isWhitespace).count)

        for term in trimmed.split(whereSeparator: \.isWhitespace).map(String.init) {
            let normalized = term.lowercased()
            if seen.insert(normalized).inserted {
                deduped.append(term)
            }
        }

        return deduped.isEmpty ? trimmed : deduped.joined(separator: " ")
    }
}

private struct YTSResponse: Decodable {
    let status: String?
    let data: YTSData?
}

private struct YTSData: Decodable {
    let movieCount: Int?
    let movies: [YTSMovie]?
}

private struct YTSMovie: Decodable {
    let title: String?
    let titleLong: String?
    let year: Int?
    let imdbCode: String?
    let torrents: [YTSTorrent]?
}

private struct YTSTorrent: Decodable {
    let hash: String?
    let quality: String?
    let type: String?
    let seeds: Int?
    let peers: Int?
    let size: String?
    let sizeBytes: Int64?
}
