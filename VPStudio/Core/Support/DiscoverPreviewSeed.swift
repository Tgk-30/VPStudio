import Foundation

/// Realistic mock content for visual QA of the **real** Discover surface.
///
/// Uses public TMDB image paths (the `image.tmdb.org` CDN requires no API key), so the
/// actual `DiscoverView` — its hero carousel, rows, and `MediaCardView` tiles — renders with
/// real artwork without any credentials or network metadata calls. Wired into Test Mode's
/// Discover screen and reachable at launch via `VPSTUDIO_QA_TEST_SCREEN=discover`.
enum DiscoverPreviewSeed {
    struct Entry: Sendable {
        let tmdbId: Int
        let type: MediaType
        let title: String
        let year: Int
        let rating: Double
        let poster: String
        let backdrop: String
    }

    static let movies: [Entry] = [
        Entry(tmdbId: 693134, type: .movie, title: "Dune: Part Two", year: 2024, rating: 8.2,
              poster: "/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg", backdrop: "/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg"),
        Entry(tmdbId: 872585, type: .movie, title: "Oppenheimer", year: 2023, rating: 8.1,
              poster: "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg", backdrop: "/neeNHeXjMF5fXoCJRsOmkNGC7q.jpg"),
        Entry(tmdbId: 569094, type: .movie, title: "Spider-Man: Across the Spider-Verse", year: 2023, rating: 8.3,
              poster: "/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg", backdrop: "/9xfDWXAUbFXQK585JvByT5pEAhe.jpg"),
        Entry(tmdbId: 533535, type: .movie, title: "Deadpool & Wolverine", year: 2024, rating: 7.6,
              poster: "/8cdWjvZQUExUUTzyp4t6EDMubfO.jpg", backdrop: "/cOoVcVQ3i1m5b2xtqKBtoTSbxC1.jpg"),
        Entry(tmdbId: 414906, type: .movie, title: "The Batman", year: 2022, rating: 7.7,
              poster: "/74xTEgt7R36Fpooo50r9T25onhq.jpg", backdrop: "/rvtdN5XkWAfGX6xDuPL6yYS2seK.jpg"),
        Entry(tmdbId: 1184918, type: .movie, title: "The Wild Robot", year: 2024, rating: 8.3,
              poster: "/eG9lz41mJqsI4J6ubMtVqD26q2J.jpg", backdrop: "/mQZJoIhTEkNhCYAqcHrQqhENLdu.jpg"),
        Entry(tmdbId: 1022789, type: .movie, title: "Inside Out 2", year: 2024, rating: 7.6,
              poster: "/vpnVM9B6NMmQpWeZvzLvDESb2QY.jpg", backdrop: "/p5ozvmdgsmbWe0H8Xk7Rc8SCwAB.jpg"),
        Entry(tmdbId: 558449, type: .movie, title: "Gladiator II", year: 2024, rating: 6.8,
              poster: "/2cxhvwyEwRlysAmRH4iodkvo0z5.jpg", backdrop: "/tOqIwliWMovSIZ9DyvHcHI7p2im.jpg"),
    ]

    static let shows: [Entry] = [
        Entry(tmdbId: 95396, type: .series, title: "Severance", year: 2022, rating: 8.4,
              poster: "/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg", backdrop: "/ixgFmf1X59PUZam2qbAfskx2gQr.jpg"),
        Entry(tmdbId: 100088, type: .series, title: "The Last of Us", year: 2023, rating: 8.5,
              poster: "/dmo6TYuuJgaYinXBPjrgG9mB5od.jpg", backdrop: "/acevLdSl5I2MK5RYAm7gwAndt1w.jpg"),
        Entry(tmdbId: 126308, type: .series, title: "Shogun", year: 2024, rating: 8.4,
              poster: "/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg", backdrop: "/6Tb87q9Tog30F5AAHh1gyDT2Vve.jpg"),
        Entry(tmdbId: 94605, type: .series, title: "Arcane", year: 2021, rating: 8.7,
              poster: "/abf8tHznhSvl9BAElD2cQeRr7do.jpg", backdrop: "/q8eejQcg1bAqImEV8jh8RtBD4uH.jpg"),
        Entry(tmdbId: 66732, type: .series, title: "Stranger Things", year: 2016, rating: 8.6,
              poster: "/uOOtwVbSr4QDjAGIifLDwpb2Pdl.jpg", backdrop: "/56v2KjBlU4XaOv9rVYEQypROD7P.jpg"),
        Entry(tmdbId: 1396, type: .series, title: "Breaking Bad", year: 2008, rating: 8.9,
              poster: "/3xnWaLQjelJDDF7LT1WBo6f4BRe.jpg", backdrop: "/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg"),
        Entry(tmdbId: 119051, type: .series, title: "Wednesday", year: 2022, rating: 8.1,
              poster: "/36xXlhEpQqVVPuiZhfoQuaY4OlA.jpg", backdrop: "/iHSwvRVsRyxpX7FE7GbviaDvgGZ.jpg"),
        Entry(tmdbId: 106379, type: .series, title: "Fallout", year: 2024, rating: 8.3,
              poster: "/c15BtJxCXMrISLVmysdsnZUPQft.jpg", backdrop: "/coaPCIqQBPUZsOnJcWZxhaORcDT.jpg"),
    ]

    static func preview(_ entry: Entry) -> MediaPreview {
        MediaPreview(
            id: "seed-\(entry.tmdbId)",
            type: entry.type,
            title: entry.title,
            year: entry.year,
            posterPath: entry.poster,
            backdropPath: entry.backdrop,
            imdbRating: entry.rating,
            tmdbId: entry.tmdbId
        )
    }

    static var moviePreviews: [MediaPreview] { movies.map(preview) }
    static var showPreviews: [MediaPreview] { shows.map(preview) }
}

extension DiscoverViewModel {
    /// A `DiscoverViewModel` pre-populated with real artwork for visual QA. `hasPerformedInitialLoad`
    /// is set so `DiscoverView`'s `.task` skips the network refresh (which would otherwise surface a
    /// "TMDB setup required" panel over the seeded content).
    @MainActor
    static func seededPreview() -> DiscoverViewModel {
        let movies = DiscoverPreviewSeed.moviePreviews
        let shows = DiscoverPreviewSeed.showPreviews
        let viewModel = DiscoverViewModel()
        viewModel.trendingMovies = movies
        viewModel.trendingShows = shows
        viewModel.popularMovies = Array(movies.reversed())
        viewModel.topRatedMovies = (movies + shows).sorted { ($0.imdbRating ?? 0) > ($1.imdbRating ?? 0) }
        viewModel.nowPlayingMovies = Array(movies.prefix(6))
        // Cinematic, landscape-friendly backdrops for the hero carousel.
        viewModel.featuredBackdrops = [movies[0], shows[0], movies[2], shows[2], shows[1]]
        viewModel.isLoading = false
        viewModel.error = nil
        viewModel.hasPerformedInitialLoad = true
        return viewModel
    }
}
