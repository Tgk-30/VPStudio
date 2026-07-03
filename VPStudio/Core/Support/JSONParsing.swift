import Foundation

/// Shared JSON value-extraction helpers used by indexer parsers that process
/// untyped `JSONSerialization` payloads (Stremio, Torznab/Prowlarr, etc.).
enum JSONValueParsing {
    private static let infoHashRegex = SensitiveURLQueryPolicy.regularExpression(pattern: "(?i)[0-9a-f]{40,64}")

    /// Coerce a loosely-typed JSON value to `Int`.
    /// Handles `Int`, `Int64`, `Double`, and numeric `String` representations.
    static func parseInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let int64Value = value as? Int64 { return Int(int64Value) }
        if let doubleValue = value as? Double {
            // Guard before converting: JSONSerialization can yield a finite Double that
            // exceeds Int's range (e.g. 1e30 from a hostile/garbage indexer field), and
            // Int(Double) TRAPS on out-of-range/non-finite values. Callers use `?? 0`.
            guard doubleValue.isFinite, doubleValue >= Double(Int.min), doubleValue < Double(Int.max) else { return nil }
            return Int(doubleValue)
        }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }

    /// Coerce a loosely-typed JSON value to `Int64`.
    /// Handles `Int64`, `Int`, `Double`, and numeric `String` representations.
    static func parseInt64(_ value: Any?) -> Int64? {
        if let intValue = value as? Int64 { return intValue }
        if let intValue = value as? Int { return Int64(intValue) }
        if let doubleValue = value as? Double {
            // Guard before converting: a finite Double > Int64.max (e.g. 1e30) traps in
            // Int64(Double). Bounds use Double-representable limits (2^63). Callers use `?? 0`.
            guard doubleValue.isFinite,
                  doubleValue >= -9_223_372_036_854_775_808.0,
                  doubleValue < 9_223_372_036_854_775_808.0 else { return nil }
            return Int64(doubleValue)
        }
        if let stringValue = value as? String { return Int64(stringValue) }
        return nil
    }

    /// Extract a BitTorrent info-hash from a magnet URI or resolve URL.
    /// Returns `nil` when no 40-or-64 hex hash can be resolved.
    static func extractInfoHash(from magnetURI: String?) -> String? {
        guard let magnetURI else { return nil }

        if let components = URLComponents(string: magnetURI) {
            if let xt = components.queryItems?.compactMap({ (item: URLQueryItem) -> String? in
                guard item.name.lowercased() == "xt",
                      let value = item.value,
                      value.lowercased().hasPrefix("urn:btih:") else {
                    return nil
                }

                return normalizedHexHash(from: String(value.dropFirst("urn:btih:".count)))
            }).first {
                return xt
            }
        }

        return extractInfoHashFromTorrentURL(magnetURI)
    }

    private static func normalizedHexHash(from value: String) -> String? {
        // Delegate to the shared validator so magnet parsing accepts the same
        // hash forms as the rest of the app — including 32-character RFC 4648
        // base32 `btih` hashes, which some Torznab/indexer feeds emit and which
        // would otherwise be silently dropped here (no hash → result discarded).
        DebridHashValidator.normalizedInfoHash(value)
    }

    private static func extractInfoHashFromTorrentURL(_ value: String) -> String? {
        guard let infoHashRegex else { return nil }
        if let components = URLComponents(string: value),
           let queryItems = components.queryItems {
            let candidates = queryItems.compactMap { item -> String? in
                guard ["hash", "infohash", "info_hash", "xt"].contains(item.name.lowercased()),
                      let value = item.value else {
                    return nil
                }
                return normalizedHexHash(from: value)
            }
            if let directCandidate = candidates.first(where: { $0.count == 40 || $0.count == 64 }) {
                return directCandidate
            }
        }

        let regex = infoHashRegex
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        let matches = regex.matches(in: value, range: range)
        for match in matches {
            if let matchRange = Range(match.range, in: value) {
                let candidate = String(value[matchRange]).lowercased()
                guard candidate.count == 40 || candidate.count == 64,
                      let lowerBound = Range(match.range, in: value)?.lowerBound,
                      let upperBound = Range(match.range, in: value)?.upperBound else {
                    continue
                }

                let validLowerBoundary = lowerBound == value.startIndex || "/?#&=.".contains(value[value.index(before: lowerBound)])
                let validUpperBoundary = upperBound == value.endIndex || "/?#&=.".contains(value[upperBound])

                if validLowerBoundary && validUpperBoundary {
                    return candidate
                }
            }
        }
        return nil
    }
}
