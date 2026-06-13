import SwiftUI
import Testing
@testable import VPStudio

@MainActor
@Suite("Discover Card Render Coverage")
struct DiscoverCardRenderCoverageTests {
    @Test
    func aiCuratedHeroCardRendersWithFullMetadataAndFallbackMetadata() {
        var tapCount = 0
        let fullPreview = makePreview(
            id: "ai-full",
            title: "Moon",
            year: 2009,
            posterPath: "/moon-poster.jpg",
            backdropPath: "/moon-backdrop.jpg",
            imdbRating: 7.9,
            tmdbId: 17431
        )
        let minimalPreview = makePreview(
            id: "ai-minimal",
            type: .series,
            title: "Unknown Signal",
            year: nil,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: 0,
            tmdbId: nil
        )

        let view = VStack(spacing: 18) {
            AICuratedHeroCard(
                preview: fullPreview,
                recommendation: makeRecommendation(
                    title: "Moon",
                    year: 2009,
                    type: .movie,
                    reason: "Compact science fiction with a lonely, cerebral atmosphere.",
                    tmdbId: 17431,
                    score: 0.94
                )
            ) {
                tapCount += 1
            }

            AICuratedHeroCard(
                preview: minimalPreview,
                recommendation: makeRecommendation(
                    title: "Unknown Signal",
                    year: nil,
                    type: .series,
                    reason: "A sparse mystery pick.",
                    tmdbId: nil,
                    score: nil
                )
            ) {
                tapCount += 1
            }
        }
        .frame(width: 760, height: 520)

        SwiftUIViewDiagnosticHost.render(view, width: 800, height: 560)
        #expect(tapCount == 0)
    }

    @Test
    func aiCuratedSupportingRowsRenderOptionalScoreAndYearBranches() {
        var tapCount = 0
        let view = VStack(spacing: 12) {
            AICuratedSupportingRow(
                recommendation: makeRecommendation(
                    title: "Devs",
                    year: 2020,
                    type: .series,
                    reason: "Quiet corporate mystery with big ideas.",
                    tmdbId: 81349,
                    score: 0.88
                )
            ) {
                tapCount += 1
            }

            AICuratedSupportingRow(
                recommendation: makeRecommendation(
                    title: "Primer",
                    year: nil,
                    type: .movie,
                    reason: "Dense time-loop engineering.",
                    tmdbId: nil,
                    score: nil
                )
            ) {
                tapCount += 1
            }
        }
        .frame(width: 620, height: 180)

        SwiftUIViewDiagnosticHost.render(view, width: 660, height: 220)
        #expect(tapCount == 0)
    }

    @Test
    func featuredHeroRendersBackdropPosterAndMissingArtworkFallbacks() {
        var selectedIDs: [String] = []
        let backdropPreview = makePreview(
            id: "hero-backdrop",
            title: "Arrival",
            year: 2016,
            posterPath: "/arrival-poster.jpg",
            backdropPath: "/arrival-backdrop.jpg",
            imdbRating: 7.9,
            tmdbId: 329865
        )
        let posterOnlyPreview = makePreview(
            id: "hero-poster",
            title: "Poster Only",
            year: 2024,
            posterPath: "/poster-only.jpg",
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 44
        )
        let minimalPreview = makePreview(
            id: "hero-minimal",
            type: .series,
            title: "No Artwork",
            year: nil,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: 0,
            tmdbId: nil
        )

        let view = ScrollView {
            VStack(spacing: 20) {
                FeaturedHeroView(item: backdropPreview) {
                    selectedIDs.append(backdropPreview.id)
                }

                FeaturedHeroView(item: posterOnlyPreview) {
                    selectedIDs.append(posterOnlyPreview.id)
                }

                FeaturedHeroView(item: minimalPreview) {
                    selectedIDs.append(minimalPreview.id)
                }
            }
            .padding(16)
        }
        .frame(width: 860, height: 1_420)

        SwiftUIViewDiagnosticHost.render(view, width: 900, height: 1_460)
        #expect(selectedIDs.isEmpty)
    }

    @Test
    func mediaRowRendersSymbolRatingAndEmptyBranches() {
        var selectedIDs: [String] = []
        let rated = makePreview(
            id: "row-rated",
            title: "Dune",
            year: 2021,
            posterPath: "/dune.jpg",
            backdropPath: "/dune-backdrop.jpg",
            imdbRating: 8.0,
            tmdbId: 438631
        )
        let unrated = makePreview(
            id: "row-unrated",
            type: .series,
            title: "Severance",
            year: 2022,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 95396
        )

        let view = VStack(spacing: 24) {
            MediaRow(
                title: "Trending Now",
                symbol: "flame",
                items: [rated, unrated],
                userRatings: [
                    rated.id: TasteEvent(
                        mediaId: rated.id,
                        eventType: .rated,
                        feedbackScale: .oneToTen,
                        feedbackValue: 9
                    )
                ],
                animationDelay: 0
            ) { item in
                selectedIDs.append(item.id)
            }

            MediaRow(
                title: "No Symbol Empty Row",
                symbol: "",
                items: [],
                userRatings: [:],
                animationDelay: 0.05
            ) { item in
                selectedIDs.append(item.id)
            }
        }
        .frame(width: 760, height: 520)

        SwiftUIViewDiagnosticHost.render(view, width: 800, height: 560)
        #expect(selectedIDs.isEmpty)
    }

    private func makePreview(
        id: String,
        type: MediaType = .movie,
        title: String,
        year: Int?,
        posterPath: String?,
        backdropPath: String?,
        imdbRating: Double?,
        tmdbId: Int?
    ) -> MediaPreview {
        MediaPreview(
            id: id,
            type: type,
            title: title,
            year: year,
            posterPath: posterPath,
            backdropPath: backdropPath,
            imdbRating: imdbRating,
            tmdbId: tmdbId
        )
    }

    private func makeRecommendation(
        title: String,
        year: Int?,
        type: MediaType,
        reason: String,
        tmdbId: Int?,
        score: Double?
    ) -> AIMovieRecommendation {
        AIMovieRecommendation(
            title: title,
            year: year,
            type: type,
            reason: reason,
            tmdbId: tmdbId,
            score: score
        )
    }
}
