import Foundation

/// A suggested immersive environment for a given genre/mood.
///
/// Pure value type — carries a stable `matchKey` (the tag used to resolve an
/// installed `EnvironmentAsset` via `environmentTag` / `EnvironmentCatalogManager.asset(matchingTag:)`)
/// and an optional `fallbackPresetID` pointing at a curated preset that could be
/// offered/installed when no tagged asset is present.
struct EnvironmentSuggestion: Sendable, Equatable, Hashable {
    /// Stable tag identifying the mood/environment family (e.g. "horror", "scifi", "chill").
    /// Persisted on `EnvironmentAsset.environmentTag` and matched case-insensitively.
    let matchKey: String

    /// Human-friendly display name for the suggested mood.
    let displayName: String

    /// Optional curated preset id that best fits this mood, used as a hint when no
    /// installed asset carries `matchKey`.
    let fallbackPresetID: String?

    init(matchKey: String, displayName: String, fallbackPresetID: String? = nil) {
        self.matchKey = matchKey
        self.displayName = displayName
        self.fallbackPresetID = fallbackPresetID
    }
}

/// Maps a genre/mood to an `EnvironmentSuggestion`.
///
/// Pure policy — no database, no RealityKit, no I/O. Mirrors `ExploreGenreTilePolicy`'s
/// "static helpers on an enum" shape. Resolution to a concrete installed asset is the
/// caller's job (`EnvironmentCatalogManager.asset(matchingTag:)`).
enum GenreEnvironmentSuggestionPolicy {

    // MARK: - Mood definitions (single source of truth for match keys)

    static let scifi = EnvironmentSuggestion(matchKey: "scifi", displayName: "Sci-Fi", fallbackPresetID: nil)
    static let horror = EnvironmentSuggestion(matchKey: "horror", displayName: "Horror", fallbackPresetID: nil)
    static let animation = EnvironmentSuggestion(matchKey: "animation", displayName: "Animation", fallbackPresetID: nil)
    static let docs = EnvironmentSuggestion(matchKey: "docs", displayName: "Documentary", fallbackPresetID: nil)
    static let chill = EnvironmentSuggestion(matchKey: "chill", displayName: "Chill", fallbackPresetID: nil)
    static let action = EnvironmentSuggestion(matchKey: "action", displayName: "Action", fallbackPresetID: nil)
    static let drama = EnvironmentSuggestion(matchKey: "drama", displayName: "Drama", fallbackPresetID: nil)
    static let comedy = EnvironmentSuggestion(matchKey: "comedy", displayName: "Comedy", fallbackPresetID: nil)
    static let mystery = EnvironmentSuggestion(matchKey: "mystery", displayName: "Mystery", fallbackPresetID: nil)
    static let fantasy = EnvironmentSuggestion(matchKey: "fantasy", displayName: "Fantasy", fallbackPresetID: nil)
    static let classics = EnvironmentSuggestion(matchKey: "classics", displayName: "Classics", fallbackPresetID: nil)

    /// Deterministic neutral default for genres we don't map to a distinctive mood,
    /// or for unknown human strings. Resolves to a "cinema" tag when an installed
    /// asset carries it, falling back to the curated cinema presets.
    static let neutralDefault = EnvironmentSuggestion(
        matchKey: "cinema",
        displayName: "Cinema",
        fallbackPresetID: "polyhaven-pretville-cinema"
    )

    // MARK: - TMDB genre id lookup

    /// Maps a TMDB movie genre id to a suggestion. Special/neutral genres return `nil`.
    static func suggestion(forMovieGenreId genreId: Int) -> EnvironmentSuggestion? {
        movieGenreSuggestions[genreId]
    }

    /// Maps a TMDB TV genre id to a suggestion. Special/neutral genres return `nil`.
    static func suggestion(forTVGenreId genreId: Int) -> EnvironmentSuggestion? {
        tvGenreSuggestions[genreId]
    }

    /// First non-nil movie-genre suggestion for an ordered id list, or `nil`.
    static func suggestion(forMovieGenreIds genreIds: [Int]) -> EnvironmentSuggestion? {
        for id in genreIds {
            if let match = suggestion(forMovieGenreId: id) { return match }
        }
        return nil
    }

    /// First non-nil TV-genre suggestion for an ordered id list, or `nil`.
    static func suggestion(forTVGenreIds genreIds: [Int]) -> EnvironmentSuggestion? {
        for id in genreIds {
            if let match = suggestion(forTVGenreId: id) { return match }
        }
        return nil
    }

    // MARK: - Human genre-name lookup

    /// Resolves an ordered list of human genre names (e.g. ["Science Fiction", "Drama"])
    /// to a suggestion. Case- and whitespace-insensitive. Returns the first recognized
    /// mood; if names are present but none are recognized, returns `neutralDefault`;
    /// if the list is empty, returns `nil`.
    static func suggestion(forGenreNames genreNames: [String]) -> EnvironmentSuggestion? {
        let normalized = genreNames
            .map { normalize($0) }
            .filter { !$0.isEmpty }
        guard !normalized.isEmpty else { return nil }

        for name in normalized {
            if let match = nameSuggestions[name] { return match }
        }
        return neutralDefault
    }

    // MARK: - Normalization

    /// Lowercases, trims, and collapses internal whitespace so "Science Fiction",
    /// "  science   fiction " and "SCIENCE FICTION" all match.
    static func normalize(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let collapsed = lowered
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalizes a persisted environment tag without applying the neutral fallback
    /// used for unknown media genres. This keeps asset tags stable and prevents a
    /// misspelled/custom tag from silently becoming "cinema".
    static func normalizedEnvironmentTag(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = normalize(raw)
        guard !normalized.isEmpty else { return nil }
        if let suggestion = allSuggestions.first(where: { $0.matchKey == normalized }) {
            return suggestion.matchKey
        }
        if let suggestion = nameSuggestions[normalized] {
            return suggestion.matchKey
        }
        return normalized
    }

    // MARK: - Tables

    /// TMDB movie genre ids -> mood. Keyed off the ids used in `ExploreGenreCatalog`
    /// plus common TMDB movie genres.
    private static let movieGenreSuggestions: [Int: EnvironmentSuggestion] = [
        27: horror,        // Horror
        878: scifi,        // Science Fiction
        16: animation,     // Animation
        99: docs,          // Documentary
        10749: chill,      // Romance
        28: action,        // Action
        12: action,        // Adventure
        53: mystery,       // Thriller
        9648: mystery,     // Mystery
        18: drama,         // Drama
        35: comedy,        // Comedy
        14: fantasy,       // Fantasy
        36: classics,      // History
    ]

    /// TMDB TV genre ids -> mood.
    private static let tvGenreSuggestions: [Int: EnvironmentSuggestion] = [
        27: horror,        // (movie horror id, defensive)
        10765: scifi,      // Sci-Fi & Fantasy
        16: animation,     // Animation
        99: docs,          // Documentary
        10749: chill,      // Romance
        10759: action,     // Action & Adventure
        9648: mystery,     // Mystery
        18: drama,         // Drama
        35: comedy,        // Comedy
        36: classics,      // History
    ]

    /// Normalized human genre names -> mood. Covers TMDB display names AND the full
    /// OMDb genre vocabulary (Biography, Family, Film-Noir, Music, Musical, Sport,
    /// War, Western, …) so OMDb-sourced titles resolve to a tailored environment
    /// instead of always falling back to the neutral cinema default.
    private static let allSuggestions: [EnvironmentSuggestion] = [
        scifi,
        horror,
        animation,
        docs,
        chill,
        action,
        drama,
        comedy,
        mystery,
        fantasy,
        classics,
        neutralDefault,
    ]

    private static let nameSuggestions: [String: EnvironmentSuggestion] = [
        "horror": horror,
        "science fiction": scifi,
        "sci fi": scifi,
        "sci-fi": scifi,
        "scifi": scifi,
        "sci-fi & fantasy": scifi,
        "animation": animation,
        "documentary": docs,
        "documentaries": docs,
        "docs": docs,
        "news": docs,
        "romance": chill,
        "music": chill,
        "musical": chill,
        "family": chill,
        "action": action,
        "action & adventure": action,
        "adventure": action,
        "sport": action,
        "war": action,
        "war & politics": action,
        "thriller": mystery,
        "mystery": mystery,
        "crime": mystery,
        "film-noir": mystery,
        "drama": drama,
        "biography": drama,
        "comedy": comedy,
        "fantasy": fantasy,
        "history": classics,
        "western": classics,
    ]
}
