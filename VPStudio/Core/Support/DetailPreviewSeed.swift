import Foundation

/// Seeds the **real** Detail surface (`DetailView` → `SeriesDetailLayout`) with realistic content
/// for visual QA, mirroring [`DiscoverPreviewSeed`].
///
/// Uses public image paths and pre-populates a `DetailViewModel`, so the production detail layout
/// — hero, metadata, genre chips, season picker, and stream section — renders without credentials
/// or network metadata calls while preserving OMDb-style IMDb identities. Wired into Test
/// Mode's `detailMovie` / `detailSeries` screens via `DetailView(initialViewModel:disablesAutomaticLoading:)`.
enum DetailPreviewSeed {
    /// Dune: Part Two — a landscape-friendly backdrop that shows the cinematic hero well.
    static let movieEntry = DiscoverPreviewSeed.movies[0]
    /// First seeded show (Severance) — drives the series layout with a season picker + episodes.
    static let seriesEntry = DiscoverPreviewSeed.shows[0]

    static func entry(for type: MediaType) -> DiscoverPreviewSeed.Entry {
        type == .series ? seriesEntry : movieEntry
    }

    static func preview(for type: MediaType) -> MediaPreview {
        DiscoverPreviewSeed.preview(entry(for: type))
    }

    static func mediaItem(for type: MediaType) -> MediaItem {
        let e = entry(for: type)
        return MediaItem(
            id: e.imdbId,
            type: e.type,
            title: e.title,
            year: e.year,
            posterPath: e.poster,
            backdropPath: e.backdrop,
            overview: type == .series
                ? "Mark Scout leads a team whose memories have been surgically divided between work and personal life, exposing the cost of a corporate experiment built on secrecy and control."
                : "Paul Atreides unites with the Fremen on a warpath of revenge against the conspirators who destroyed his family, racing to stop a terrible future only he can foresee.",
            genres: type == .series ? ["Comedy", "Drama"] : ["Science Fiction", "Adventure", "Drama"],
            imdbRating: e.rating,
            runtime: type == .series ? 36 : 166,
            tmdbId: nil
        )
    }

    static func seasons(for type: MediaType) -> [Season] {
        guard type == .series else { return [] }
        return [
            Season(id: 1, seasonNumber: 1, name: "Season 1", overview: nil, posterPath: nil, episodeCount: 10, airDate: "2023-01-26"),
            Season(id: 2, seasonNumber: 2, name: "Season 2", overview: nil, posterPath: nil, episodeCount: 10, airDate: "2024-10-16"),
            Season(id: 3, seasonNumber: 3, name: "Season 3", overview: nil, posterPath: nil, episodeCount: 9, airDate: "2025-09-10"),
        ]
    }

    static func episodes(for type: MediaType) -> [Episode] {
        guard type == .series else { return [] }
        let mediaId = seriesEntry.imdbId
        let titles = ["Good News About Hell", "Half Loop", "Outliers", "Coward", "Punch", "Yips", "Trust", "Changing Patterns"]
        return titles.enumerated().map { index, title in
            Episode(
                id: "\(mediaId)-s1e\(index + 1)",
                mediaId: mediaId,
                seasonNumber: 1,
                episodeNumber: index + 1,
                title: title,
                overview: nil,
                airDate: nil,
                stillPath: nil,
                runtime: 32 + index
            )
        }
    }

    @MainActor
    static func seededViewModel(appState: AppState, type: MediaType) -> DetailViewModel {
        let viewModel = DetailViewModel(appState: appState)
        viewModel.mediaItem = mediaItem(for: type)
        viewModel.seasons = seasons(for: type)
        viewModel.episodes = episodes(for: type)
        viewModel.selectedSeason = 1
        return viewModel
    }
}
