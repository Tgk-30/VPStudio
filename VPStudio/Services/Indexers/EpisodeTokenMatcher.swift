import Foundation

enum EpisodeTokenMatcher {
    struct Context: Equatable, Sendable {
        let season: Int
        let episode: Int
    }

    /// A season plus the (possibly multi-episode) range a title claims, e.g.
    /// `S01E01E02` or `S01E02-03` covers episodes 2...3 of season 1.
    private struct RangeMatch: Equatable {
        let season: Int
        let firstEpisode: Int
        let lastEpisode: Int

        func covers(episode: Int) -> Bool {
            episode >= firstEpisode && episode <= lastEpisode
        }
    }

    private struct Pattern {
        let regex: NSRegularExpression?

        init(_ pattern: String) {
            regex = SensitiveURLQueryPolicy.regularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }

    // Separators between the season and episode blocks vary across release
    // naming (`S01E02`, `S01.E02`, `S01_E02`, `S01-E02`), so accept the common
    // delimiter set rather than whitespace only.
    // The optional trailing group captures multi-episode releases
    // (`S01E01E02`, `S01E01-E02`, `S01E02-03`); the second episode must be
    // introduced by an explicit `e`/`-`/`to` connector so resolution/size
    // tokens (`...E02.1080p`) are not misread as a second episode number.
    private static let seasonEpisodePattern = Pattern(
        #"s\s*(\d{1,2})[\s._-]*e\s*(\d{1,3})(?:[\s._-]*(?:e|-|to)[\s._-]*e?\s*(\d{1,3})(?![pi]))?(?!\d)"#
    )
    private static let seasonByEpisodePattern = Pattern(#"(?<!\d)(\d{1,2})\s*x\s*(\d{1,3})(?!\d)"#)
    private static let seasonEpisodeWordsPattern = Pattern(#"season\D*(\d{1,2})(?!\d).{0,20}episode\D*(\d{1,3})(?!\d)"#)

    /// The largest consecutive-episode span a single multi-episode release file
    /// is allowed to claim, past which the "range end" is treated as a stray
    /// resolution/bitrate token rather than a real episode number.
    private static let maximumMultiEpisodeSpan = 32

    nonisolated static func context(fromQuery query: String) -> Context? {
        context(in: query.lowercased())
    }

    nonisolated static func matches(title: String, season: Int, episode: Int) -> Bool {
        guard let match = rangeMatch(in: title.lowercased()) else { return false }
        return match.season == season && match.covers(episode: episode)
    }

    nonisolated static func matchesIfPresent(title: String, season: Int, episode: Int) -> Bool {
        guard let match = rangeMatch(in: title.lowercased()) else { return true }
        return match.season == season && match.covers(episode: episode)
    }

    nonisolated private static func context(in normalizedValue: String) -> Context? {
        guard let match = rangeMatch(in: normalizedValue) else { return nil }
        return Context(season: match.season, episode: match.firstEpisode)
    }

    /// Resolves the season and episode range encoded in a normalized (lowercased)
    /// title, preferring the `SxxExx` form (which alone supports multi-episode
    /// ranges) and falling back to `NxNN` and worded `Season N Episode M` forms.
    nonisolated private static func rangeMatch(in normalizedValue: String) -> RangeMatch? {
        if let regex = seasonEpisodePattern.regex,
           let match = firstRangeMatch(using: regex, in: normalizedValue) {
            return match
        }

        for pattern in [seasonByEpisodePattern, seasonEpisodeWordsPattern] {
            if let regex = pattern.regex,
               let (season, episode) = firstMatch(using: regex, in: normalizedValue) {
                return RangeMatch(season: season, firstEpisode: episode, lastEpisode: episode)
            }
        }
        return nil
    }

    nonisolated private static func firstRangeMatch(using regex: NSRegularExpression, in value: String) -> RangeMatch? {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, options: [], range: range),
              match.numberOfRanges >= 3,
              let seasonRange = Range(match.range(at: 1), in: value),
              let episodeRange = Range(match.range(at: 2), in: value),
              let season = Int(value[seasonRange]),
              let firstEpisode = Int(value[episodeRange]) else {
            return nil
        }

        var lastEpisode = firstEpisode
        if match.numberOfRanges >= 4,
           let secondRange = Range(match.range(at: 3), in: value),
           let secondEpisode = Int(value[secondRange]),
           secondEpisode >= firstEpisode,
           // Guard against a bare resolution/bitrate token (e.g. `S01E02-720`)
           // being read as a giant episode span. A single multi-episode file
           // realistically covers only a handful of consecutive episodes.
           secondEpisode - firstEpisode <= Self.maximumMultiEpisodeSpan {
            lastEpisode = secondEpisode
        }

        return RangeMatch(season: season, firstEpisode: firstEpisode, lastEpisode: lastEpisode)
    }

    nonisolated private static func firstMatch(using regex: NSRegularExpression, in value: String) -> (Int, Int)? {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, options: [], range: range),
              match.numberOfRanges >= 3,
              let firstRange = Range(match.range(at: 1), in: value),
              let secondRange = Range(match.range(at: 2), in: value),
              let first = Int(value[firstRange]),
              let second = Int(value[secondRange]) else {
            return nil
        }
        return (first, second)
    }
}
