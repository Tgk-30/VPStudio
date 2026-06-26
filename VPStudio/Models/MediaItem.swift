import Foundation
import GRDB

enum MediaArtworkURLPolicy {
    private static let allowedAbsoluteArtworkHosts: Set<String> = [
        "image.tmdb.org",
        "img.omdbapi.com",
        "ia.media-imdb.com",
        "images-eu.ssl-images-amazon.com",
        "images-fe.ssl-images-amazon.com",
        "images-na.ssl-images-amazon.com",
        "m.media-amazon.com",
    ]

    static func url(for path: String?, legacyTMDBSizePath: String) -> URL? {
        guard let path else { return nil }
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }
        guard trimmedPath.lowercased() != "n/a" else { return nil }

        if let absolute = URL(string: trimmedPath), let scheme = absolute.scheme?.lowercased() {
            let host = absolute.host?.lowercased()
            guard scheme == "https",
                  absolute.port == nil || absolute.port == 443,
                  let host,
                  !host.isEmpty,
                  allowedAbsoluteArtworkHosts.contains(host),
                  absolute.user == nil,
                  absolute.password == nil,
                  !SensitiveURLQueryPolicy.containsSensitiveQueryItem(in: absolute) else { return nil }
            return absolute
        }
        guard !trimmedPath.hasPrefix("//"),
              !trimmedPath.contains("?"),
              !trimmedPath.contains("#") else { return nil }

        let normalizedPath = trimmedPath.hasPrefix("/") ? trimmedPath : "/\(trimmedPath)"
        return URL(string: "https://image.tmdb.org/t/p/\(legacyTMDBSizePath)\(normalizedPath)")
    }
}

enum MediaRatingPolicy {
    private static let omdbRatingPattern = #"^(?:10(?:\.0+)?|[1-9](?:\.\d+)?|0?\.\d+)$"#

    static func normalizedIMDbRating(_ rating: Double?) -> Double? {
        guard let rating,
              rating.isFinite,
              rating > 0,
              rating <= 10 else {
            return nil
        }
        return rating
    }

    static func normalizedOMDbIMDbRating(_ value: String?) -> Double? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "n/a" else { return nil }
        guard trimmed.range(
            of: omdbRatingPattern,
            options: .regularExpression,
            range: trimmed.startIndex..<trimmed.endIndex
        ) == trimmed.startIndex..<trimmed.endIndex else {
            return nil
        }
        return normalizedIMDbRating(Double(trimmed))
    }

    static func displayText(_ rating: Double?) -> String {
        guard let rating = normalizedIMDbRating(rating) else { return "" }
        return String(format: "%.1f", rating)
    }
}

struct MediaItem: Codable, Sendable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "media_cache"

    var id: String
    var type: MediaType
    var title: String
    var year: Int?
    var posterPath: String?
    var backdropPath: String?
    var overview: String?
    var genres: [String]
    var imdbRating: Double?
    var runtime: Int?
    var status: String?
    var tmdbId: Int?
    var lastFetched: Date?

    var posterURL: URL? {
        MediaArtworkURLPolicy.url(for: posterPath, legacyTMDBSizePath: "w500")
    }

    var backdropURL: URL? {
        // w1280 (not original): hero backdrops render at <=280pt; cuts payload ~5x with no
        // visible quality loss, and matches MediaPreview.backdropURL.
        return MediaArtworkURLPolicy.url(for: backdropPath, legacyTMDBSizePath: "w1280")
    }

    var hasArtwork: Bool {
        posterURL != nil || backdropURL != nil
    }

    func withID(_ newID: String) -> MediaItem {
        var copy = self
        copy.id = newID
        return copy
    }

    var yearString: String {
        year.map(String.init) ?? ""
    }

    var ratingString: String {
        MediaRatingPolicy.displayText(imdbRating)
    }

    var runtimeString: String {
        guard let runtime = runtime else { return "" }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    enum Columns: String, ColumnExpression {
        case id, type, title, year, posterPath, backdropPath
        case overview, genres, imdbRating, runtime, status, tmdbId, lastFetched
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.type] = type.rawValue
        container[Columns.title] = title
        container[Columns.year] = year
        container[Columns.posterPath] = posterPath
        container[Columns.backdropPath] = backdropPath
        container[Columns.overview] = overview
        container[Columns.genres] = try? JSONEncoder().encode(genres)
        container[Columns.imdbRating] = MediaRatingPolicy.normalizedIMDbRating(imdbRating)
        container[Columns.runtime] = runtime
        container[Columns.status] = status
        container[Columns.tmdbId] = tmdbId
        container[Columns.lastFetched] = lastFetched
    }

    init(row: Row) throws {
        id = row[Columns.id]
        let typeRaw: String = row[Columns.type]
        type = MediaType(rawValue: typeRaw) ?? .movie
        title = row[Columns.title]
        year = row[Columns.year]
        posterPath = row[Columns.posterPath]
        backdropPath = row[Columns.backdropPath]
        overview = row[Columns.overview]
        if let genresData = row[Columns.genres] as Data? {
            genres = (try? JSONDecoder().decode([String].self, from: genresData)) ?? []
        } else {
            genres = []
        }
        imdbRating = MediaRatingPolicy.normalizedIMDbRating(row[Columns.imdbRating] as Double?)
        runtime = row[Columns.runtime]
        status = row[Columns.status]
        tmdbId = row[Columns.tmdbId]
        lastFetched = row[Columns.lastFetched]
    }

    init(
        id: String,
        type: MediaType,
        title: String,
        year: Int? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        overview: String? = nil,
        genres: [String] = [],
        imdbRating: Double? = nil,
        runtime: Int? = nil,
        status: String? = nil,
        tmdbId: Int? = nil,
        lastFetched: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.year = year
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.overview = overview
        self.genres = genres
        self.imdbRating = MediaRatingPolicy.normalizedIMDbRating(imdbRating)
        self.runtime = runtime
        self.status = status
        self.tmdbId = tmdbId
        self.lastFetched = lastFetched
    }

    enum CodingKeys: String, CodingKey {
        case id, type, title, year, posterPath, backdropPath
        case overview, genres, imdbRating, runtime, status, tmdbId, lastFetched
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let typeRaw = try container.decodeIfPresent(String.self, forKey: .type)
        type = typeRaw.flatMap(MediaType.init(rawValue:)) ?? .movie
        title = try container.decode(String.self, forKey: .title)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        genres = try container.decodeIfPresent([String].self, forKey: .genres) ?? []
        imdbRating = MediaRatingPolicy.normalizedIMDbRating(try container.decodeIfPresent(Double.self, forKey: .imdbRating))
        runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        tmdbId = try container.decodeIfPresent(Int.self, forKey: .tmdbId)
        lastFetched = try container.decodeIfPresent(Date.self, forKey: .lastFetched)
    }
}

struct MediaPreview: Sendable, Identifiable, Equatable, Hashable {
    var id: String
    var type: MediaType
    var title: String
    var year: Int?
    var posterPath: String?
    var backdropPath: String?
    var imdbRating: Double?
    var tmdbId: Int?
    var episodeId: String? = nil
    var seasonNumber: Int? = nil
    var episodeNumber: Int? = nil

    var posterURL: URL? {
        MediaArtworkURLPolicy.url(for: posterPath, legacyTMDBSizePath: "w342")
    }

    var backdropURL: URL? {
        MediaArtworkURLPolicy.url(for: backdropPath, legacyTMDBSizePath: "w1280")
    }

    var ratingString: String {
        MediaRatingPolicy.displayText(imdbRating)
    }

    /// Stable per-tile identity that distinguishes individual in-progress episodes of the same
    /// series (which share `id`). Equals `id` for movies / browse items. Used for Continue
    /// Watching `ForEach` identity and progress/last-frame map keys.
    var continueWatchingRowID: String {
        episodeId.map { "\(id)#\($0)" } ?? id
    }
}
