import Foundation

/// Pure decision logic for which episode should auto-play after the current one finishes.
///
/// Extracted from `DetailViewModel` so the cross-season boundary behaviour can be unit-tested
/// without metadata fetches. The view model only loads one season's episodes at a time, so a
/// naive "next item in the loaded list" lookup stops dead at a season finale. This policy adds
/// a fallback to the first episode of the following season (prefetched by the view model), which
/// lets autoplay continue across the season boundary for full-series torrents.
enum DetailNextEpisodePolicy {
    /// Determines the successor to `selectedEpisode`.
    ///
    /// - Prefers the next episode within `currentEpisodes` (the loaded season).
    /// - When `selectedEpisode` is the last loaded episode (the season finale) and
    ///   `nextSeasonFirstEpisode` is the first episode of the immediately following season,
    ///   returns that as the successor.
    /// - Returns `nil` when no successor is known (true series finale, or the next season
    ///   has not been prefetched).
    static func nextCandidate(
        selectedEpisode: Episode,
        currentEpisodes: [Episode],
        nextSeasonFirstEpisode: Episode?
    ) -> PlayerSessionRequest.NextEpisodeCandidate? {
        let sorted = currentEpisodes.sorted {
            if $0.seasonNumber != $1.seasonNumber {
                return $0.seasonNumber < $1.seasonNumber
            }
            return $0.episodeNumber < $1.episodeNumber
        }

        if let currentIndex = sorted.firstIndex(where: { $0.id == selectedEpisode.id }),
           sorted.indices.contains(currentIndex + 1) {
            return candidate(from: sorted[currentIndex + 1])
        }

        // Season finale: continue into the prefetched next season when it directly follows.
        if let nextSeasonFirstEpisode,
           nextSeasonFirstEpisode.seasonNumber == selectedEpisode.seasonNumber + 1 {
            return candidate(from: nextSeasonFirstEpisode)
        }

        return nil
    }

    /// The season number to prefetch a "first episode" for, given the currently loaded season.
    /// Returns the immediately following season's number when one exists in `seasons`, else nil.
    static func prefetchSeasonNumber(after loadedSeason: Int, seasons: [Season]) -> Int? {
        let next = loadedSeason + 1
        return seasons.contains(where: { $0.seasonNumber == next }) ? next : nil
    }

    /// The first episode (lowest episode number) of a freshly loaded season's episode list.
    static func firstEpisode(of episodes: [Episode]) -> Episode? {
        episodes.min { $0.episodeNumber < $1.episodeNumber }
    }

    private static func candidate(from episode: Episode) -> PlayerSessionRequest.NextEpisodeCandidate {
        PlayerSessionRequest.NextEpisodeCandidate(
            episodeId: episode.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            title: episode.displayTitle
        )
    }
}
