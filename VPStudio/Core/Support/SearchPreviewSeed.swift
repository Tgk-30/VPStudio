import Foundation

/// Realistic mock content for visual QA of the **real** Search surface (`SearchView`).
///
/// Mirrors [`DiscoverPreviewSeed`] / [`DetailPreviewSeed`]: results reuse the shared IMDb-keyed
/// previews, so the production Explore grid, filter bar, and `MediaCardView` tiles render with
/// real artwork without credentials or network. The `SearchViewModel.seededPreview(showsResults:)`
/// factory that wires this in lives in SearchViewModel.swift, because it sets `private(set)` query
/// state and must share that file.
enum SearchPreviewSeed {
    /// Genre chips shown in the idle Explore grid.
    static let genres: [Genre] = [
        Genre(id: 28, name: "Action"),
        Genre(id: 12, name: "Adventure"),
        Genre(id: 878, name: "Science Fiction"),
        Genre(id: 18, name: "Drama"),
        Genre(id: 35, name: "Comedy"),
        Genre(id: 27, name: "Horror"),
        Genre(id: 53, name: "Thriller"),
        Genre(id: 16, name: "Animation"),
    ]

    /// Recent-search suggestions shown in the idle state.
    static let recentSearches = ["Dune", "Oppenheimer", "Severance", "The Batman"]

    /// The committed query reflected in the results header and the search field.
    static let resultsQuery = "Dune"

    /// Populated results grid — reuses the shared Discover seed previews.
    static var results: [MediaPreview] { DiscoverPreviewSeed.moviePreviews }
}
