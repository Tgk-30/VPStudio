import Foundation

/// Pure selectors for one-tap playback decisions on the Detail surface.
///
/// Kept free of actor isolation / networking so the "play the best cached
/// source" choice can be unit-tested deterministically. Cache status is only
/// known after async debrid enrichment, so callers must treat a `nil` result as
/// "no confirmed-cached source yet — land on Detail, do not force-play".
enum DetailPlaybackSelectionPolicy {
    /// Returns the highest-priority **confirmed-cached** source, or `nil` when
    /// none of the provided results are cached.
    ///
    /// Ranking reuses `TorrentRanking.score` so the selection matches the order
    /// the UI already presents. Defaults mirror `sortTorrentsByPreferences`
    /// (`preferCached`/`preferAtmos` on, 1080p, auto HDR) so the choice is stable
    /// even when called on an unsorted list. Only `.cached` qualifies —
    /// `.unknown` (not yet checked) and `.notCached` are never auto-played.
    nonisolated static func bestCachedResult(
        from results: [TorrentResult],
        preferredQuality: VideoQuality = .hd1080p,
        preferCached: Bool = true,
        preferAtmos: Bool = true,
        hdrPreference: HDRPreference = .auto
    ) -> TorrentResult? {
        results
            .filter { $0.cacheAvailability == .cached }
            .max { lhs, rhs in
                let lhsScore = TorrentRanking.score(
                    lhs,
                    preferredQuality: preferredQuality,
                    preferCached: preferCached,
                    preferAtmos: preferAtmos,
                    hdrPreference: hdrPreference
                )
                let rhsScore = TorrentRanking.score(
                    rhs,
                    preferredQuality: preferredQuality,
                    preferCached: preferCached,
                    preferAtmos: preferAtmos,
                    hdrPreference: hdrPreference
                )
                if lhsScore != rhsScore { return lhsScore < rhsScore }
                return lhs.seeders < rhs.seeders
            }
    }
}
