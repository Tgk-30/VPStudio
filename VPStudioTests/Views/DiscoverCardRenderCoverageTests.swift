import Foundation
import SwiftUI
import Testing
@testable import VPStudio

@MainActor
@Suite("Discover Card Render Coverage")
struct DiscoverCardRenderCoverageTests {
    @Test
    func featuredHeroArtworkPolicyUsesPosterCardForPosterOnlyArtwork() {
        #expect(DiscoverHeroArtworkPresentationPolicy.posterCardWidth == 184)
        #expect(DiscoverHeroArtworkPresentationPolicy.posterCardHeight == 276)
        #expect(DiscoverHeroArtworkPresentationPolicy.posterCardCornerRadius == 18)
        #expect(DiscoverHeroArtworkPresentationPolicy.aiPosterCardWidth == 92)
        #expect(DiscoverHeroArtworkPresentationPolicy.aiPosterCardHeight == 138)
        #expect(DiscoverHeroArtworkPresentationPolicy.aiPosterCardCornerRadius == 12)

        let backdropKind = DiscoverHeroArtworkPresentationPolicy.heroArtworkKind(
            backdropPath: "/arrival-backdrop.jpg",
            posterPath: "https://m.media-amazon.com/images/M/poster.jpg"
        )
        #expect(backdropKind == .backdrop)
        #expect(!DiscoverHeroArtworkPresentationPolicy.showsPosterCard(for: backdropKind))

        let posterOnlyKind = DiscoverHeroArtworkPresentationPolicy.heroArtworkKind(
            backdropPath: nil,
            posterPath: "https://m.media-amazon.com/images/M/poster.jpg"
        )
        #expect(posterOnlyKind == .posterOnly)
        #expect(DiscoverHeroArtworkPresentationPolicy.showsPosterCard(for: posterOnlyKind))

        let emptyKind = DiscoverHeroArtworkPresentationPolicy.heroArtworkKind(
            backdropPath: " ",
            posterPath: "javascript:alert(1)"
        )
        #expect(emptyKind == .none)
        #expect(!DiscoverHeroArtworkPresentationPolicy.showsPosterCard(for: emptyKind))
    }

    @Test
    func featuredHeroSourceDoesNotFallbackPosterIntoBackdropLayer() throws {
        let source = try Self.discoverViewSource()

        #expect(!source.contains("item.backdropPath ?? item.posterPath"))
        #expect(source.contains("MediaArtworkURLPolicy.url(for: item.backdropPath, legacyTMDBSizePath: \"w1280\")"))
        #expect(source.contains("MediaArtworkURLPolicy.url(for: item.posterPath, legacyTMDBSizePath: \"w500\")"))
        #expect(source.contains("DiscoverHeroArtworkPresentationPolicy.showsPosterCard(for: heroArtworkKind)"))
        #expect(source.contains("heroBody(availableWidth: proxy.size.width)"))
        #expect(source.contains("showsPosterCard(availableWidth: CGFloat)"))
        #expect(source.contains("availableWidth >= 760"))
        #expect(source.contains("contentTrailingPadding(availableWidth: availableWidth)"))

        let heroRange = try #require(source.range(of: "struct FeaturedHeroView"))
        let contentRange = try #require(
            source.range(of: "// Content overlay", range: heroRange.upperBound..<source.endIndex)
        )
        let heroArtworkLayers = String(source[heroRange.lowerBound..<contentRange.lowerBound])
        let gradientRange = try #require(heroArtworkLayers.range(of: "// Cinematic gradient fade to dark at bottom"))
        let posterRange = try #require(heroArtworkLayers.range(of: "heroPosterCard(url: posterURL)"))

        #expect(gradientRange.lowerBound < posterRange.lowerBound)
        #expect(source.contains("heroPosterPlaceholder(showsIcon: false)"))
        #expect(source.contains("heroPosterPlaceholder(showsIcon: true)"))
    }

    @Test
    func aiCuratedHeroSourceDoesNotFallbackPosterIntoBackdropLayer() throws {
        let source = try Self.discoverViewSource()

        #expect(!source.contains("preview.backdropURL ?? preview.posterURL"))

        let heroRange = try #require(source.range(of: "struct AICuratedHeroCard"))
        let endRange = try #require(
            source.range(of: "struct AICuratedSupportingRow", range: heroRange.upperBound..<source.endIndex)
        )
        let aiHeroSource = String(source[heroRange.lowerBound..<endRange.lowerBound])

        #expect(aiHeroSource.contains("MediaArtworkURLPolicy.url(for: preview.backdropPath, legacyTMDBSizePath: \"w1280\")"))
        #expect(aiHeroSource.contains("MediaArtworkURLPolicy.url(for: preview.posterPath, legacyTMDBSizePath: \"w500\")"))
        #expect(aiHeroSource.contains("aiBody(availableWidth: proxy.size.width)"))
        #expect(aiHeroSource.contains("showsAIPosterCard(availableWidth: CGFloat)"))
        #expect(aiHeroSource.contains("availableWidth >= 520"))
        #expect(aiHeroSource.contains("aiContentTrailingPadding(availableWidth: availableWidth)"))
        #expect(aiHeroSource.contains("aiPosterCard(url: posterURL)"))
        #expect(aiHeroSource.contains("aiPosterPlaceholder(showsIcon: false)"))
        #expect(aiHeroSource.contains("aiPosterPlaceholder(showsIcon: true)"))
    }

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
        let posterOnlyPreview = makePreview(
            id: "ai-poster-only",
            title: "Dune",
            year: 2021,
            posterPath: "https://m.media-amazon.com/images/M/dune.jpg",
            backdropPath: nil,
            imdbRating: 8.0,
            tmdbId: nil
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
                preview: posterOnlyPreview,
                recommendation: makeRecommendation(
                    title: "Dune",
                    year: 2021,
                    type: .movie,
                    reason: "Desert-scale science fiction with a strong visual identity.",
                    tmdbId: nil,
                    score: 0.91
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
        .frame(width: 760, height: 780)

        SwiftUIViewDiagnosticHost.render(view, width: 800, height: 820)
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
    func mediaRowTrailingFadeStaysNarrowEnoughForVisibleTiles() {
        #expect(MediaRowScrollCuePolicy.trailingFadeStart >= 0.98)
        #expect(MediaRowScrollCuePolicy.trailingFadeStart < MediaRowScrollCuePolicy.trailingFadeEnd)
        #expect(MediaRowScrollCuePolicy.trailingFadeEnd == 1.0)
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

    private static func discoverViewSource() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot.appendingPathComponent(
            "VPStudio/Views/Windows/Discover/DiscoverView.swift"
        )
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
