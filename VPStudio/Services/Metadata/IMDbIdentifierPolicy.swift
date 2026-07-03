import Foundation

enum IMDbIdentifierPolicy {
    static func normalizedID(from value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.range(of: #"^tt\d+$"#, options: [.caseInsensitive, .regularExpression]) != nil else {
            return nil
        }
        return trimmed.lowercased()
    }

    static func firstID(in value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        if let direct = normalizedID(from: trimmed) {
            return direct
        }

        guard let components = URLComponents(string: trimmed),
              let host = components.host?.lowercased(),
              host == "imdb.com" || host.hasSuffix(".imdb.com") else {
            return nil
        }

        return components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .lazy
            .compactMap { normalizedID(from: String($0)) }
            .first
    }

    static func appScopedID(in value: String?) -> String? {
        scopedID(
            in: value,
            prefixes: [
                "imdb-",
                "omdb-",
                "movie-imdb-",
                "series-imdb-",
                "movie-omdb-",
                "series-omdb-",
            ]
        )
    }

    static func episodeScopedID(in value: String?) -> String? {
        scopedID(
            in: value,
            prefixes: [
                "episode-imdb-",
                "episode-omdb-",
            ]
        )
    }

    private static func scopedID(in value: String?, prefixes: [String]) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        if let direct = firstID(in: trimmed) {
            return direct
        }

        let lower = trimmed.lowercased()
        for prefix in prefixes {
            guard lower.hasPrefix(prefix) else { continue }
            return normalizedID(from: String(lower.dropFirst(prefix.count)))
        }
        return nil
    }
}
