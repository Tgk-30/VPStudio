import Foundation

/// Pure policy for first-class natural-language search.
///
/// Mirrors `SearchShellCopyPolicy`: no networking, no actor isolation, no side
/// effects — just deterministic string/regex transforms so the behavior can be
/// unit-tested without an AI provider. The manager (`AIAssistantManager`) feeds
/// `recommendationPrompt(from:excluding:)` into the existing `ask(...)` flow so
/// the user's DB + Trakt history still inject via `contextualizedContext`.
enum NaturalLanguageSearchPolicy {
    /// Hints extracted from a free-form phrase that can sharpen a recommendation
    /// request without changing the literal phrase handed to the model.
    struct Hints: Equatable {
        /// e.g. `"1990s"` parsed from "90s" / "1990s". `nil` when no decade phrase.
        var decade: String?
        /// ISO 639-1 code (e.g. `"ko"`) parsed from a language word like "korean".
        var languageHint: String?
        /// The phrase with surrounding whitespace collapsed/trimmed.
        var normalizedQuery: String
    }

    /// Heuristic: does this draft read like a natural-language *request* (so the
    /// UI should offer an "Ask AI" affordance) rather than a short keyword title
    /// lookup? True when the trimmed phrase has 3+ words or exceeds ~18 chars.
    /// Plain title/keyword searches (e.g. "dune", "the matrix") stay false.
    static func looksLikePhrase(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace })
        if words.count >= 3 { return true }
        return trimmed.count > 18
    }

    /// Builds the user prompt for a natural-language recommendation request.
    ///
    /// The literal phrase is embedded verbatim so the model answers the user's
    /// actual ask, and the response shape matches `parseRecommendations`
    /// (JSON array of `{title, year, type, reason, tmdbId}`). Empty/whitespace
    /// input falls back to a safe generic taste-based prompt.
    static func recommendationPrompt(from query: String, excluding excludedTitles: [String] = []) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String]
        if trimmed.isEmpty {
            parts = [
                "Based on my viewing history and preferences, recommend 10 movies or TV shows I'd enjoy.",
                "Focus on titles I haven't seen yet.",
            ]
        } else {
            let hints = extractedHints(from: trimmed)
            parts = [
                "I'm searching for something using this request: \"\(hints.normalizedQuery)\".",
                "Recommend 10 movies or TV shows that best satisfy that request, weighing it against my taste profile and viewing history.",
            ]
            if let decade = hints.decade {
                parts.append("Favor titles from the \(decade) when they fit the request.")
            }
            if let languageHint = hints.languageHint {
                parts.append("Favor titles whose original language is \"\(languageHint)\" (ISO 639-1) when they fit the request.")
            }
        }

        parts.append("For each, provide: title, year, type (movie/series), and a brief reason tied to my request and taste.")
        parts.append("Format as JSON array with keys: title, year, type, reason, tmdbId.")
        parts.append("Only include tmdbId when you are highly confident it is correct. Otherwise use null.")

        let exclusions = excludedTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(12)
            .joined(separator: ", ")
        if !exclusions.isEmpty {
            parts.append("Do not recommend any of these titles again: \(exclusions).")
            parts.append("Return a meaningfully different list from those excluded titles.")
        }

        return parts.joined(separator: " ")
    }

    /// Extracts a decade and/or language hint from a free-form phrase. Never
    /// mutates intent — these are advisory hints layered on top of the literal
    /// phrase, which is preserved (whitespace-normalized) in `normalizedQuery`.
    static func extractedHints(from query: String) -> Hints {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let lowercased = normalizedQuery.lowercased()

        return Hints(
            decade: decade(in: lowercased),
            languageHint: languageHint(in: lowercased),
            normalizedQuery: normalizedQuery
        )
    }

    // MARK: - Decade parsing

    /// Matches "90s" / "'90s" / "1990s" / "1990's" and normalizes to a 4-digit
    /// decade label like "1990s". Two-digit decades 20–99 map to the 1900s and
    /// 00–10 map to the 2000s so "90s" -> "1990s" and "00s" -> "2000s".
    private static func decade(in lowercased: String) -> String? {
        // Four-digit form first (e.g. 1990s, 2010s, 1990's).
        if let match = firstMatch(in: lowercased, pattern: "\\b(19|20)(\\d0)'?s\\b"),
           match.count == 3 {
            return "\(match[1])\(match[2])s"
        }

        // Two-digit form (e.g. 90s, '80s, 00s).
        if let match = firstMatch(in: lowercased, pattern: "'?(\\d0)'?s\\b"),
           match.count == 2,
           let value = Int(match[1]) {
            // Derive the 1900s/2000s boundary from the current decade so "20s" means 2020s in
            // the 2020s (not 1920s). Decades at or before the current one are 2000s; later ones
            // are 1900s. (Hardcoding "<= 10 -> 2000s" drifted as the decade advanced.)
            let currentDecade = Calendar.current.component(.year, from: Date()) % 100 / 10 * 10
            let century = value <= currentDecade ? "20" : "19"
            return "\(century)\(match[1])s"
        }

        return nil
    }

    // MARK: - Language parsing

    /// Maps a language word (e.g. "korean") to an ISO 639-1 code (e.g. "ko").
    /// Prefers the canonical `SearchLanguageOption.common` table so the UI and
    /// the prompt stay in sync; falls back to a small built-in map for words the
    /// table phrases differently (e.g. "mandarin").
    private static func languageHint(in lowercased: String) -> String? {
        for (word, code) in languageWordToISO639 where containsWord(lowercased, word: word) {
            return code
        }
        return nil
    }

    /// Built from `SearchLanguageOption.common` (locale display names lowercased,
    /// stripped of parenthetical qualifiers) plus a handful of common aliases.
    /// Values are ISO 639-1 codes (the prefix of the locale code).
    private static let languageWordToISO639: [(word: String, code: String)] = {
        var pairs: [(String, String)] = []
        var seenWords = Set<String>()

        for option in SearchLanguageOption.common {
            let iso = String(option.code.prefix(2)).lowercased()
            let word = option.name
                .lowercased()
                .replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty, seenWords.insert(word).inserted else { continue }
            pairs.append((word, iso))
        }

        // Common aliases not phrased the same way as the locale display names.
        let aliases: [(String, String)] = [
            ("mandarin", "zh"),
            ("cantonese", "zh"),
            ("brazilian", "pt"),
            ("castilian", "es"),
        ]
        for (word, iso) in aliases where seenWords.insert(word).inserted {
            pairs.append((word, iso))
        }

        // Longer words first so e.g. a future multi-word language matches before
        // a shorter substring could.
        return pairs.sorted { $0.0.count > $1.0.count }
    }()

    // MARK: - Regex helpers

    private static func firstMatch(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        var groups: [String] = []
        for index in 0..<match.numberOfRanges {
            guard let groupRange = Range(match.range(at: index), in: text) else {
                groups.append("")
                continue
            }
            groups.append(String(text[groupRange]))
        }
        return groups
    }

    /// Whole-word containment so "korean" matches but "korea" inside a longer
    /// word does not produce false positives.
    private static func containsWord(_ text: String, word: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        return firstMatch(in: text, pattern: "\\b\(escaped)\\b") != nil
    }
}
