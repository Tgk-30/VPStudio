import Testing
import Foundation
@testable import VPStudio

@Suite("AIMovieRecommendation Extension")
struct AIMovieRecommendationExtensionTests {

    @Test("toMediaPreview with tmdbId")
    func toMediaPreviewWithTmdbId() {
        let recommendation = AIMovieRecommendation(
            title: "Dune",
            year: 2024,
            type: .movie,
            reason: "Great visual effects",
            tmdbId: 693134,
            score: 0.95
        )

        let mediaPreview = recommendation.toMediaPreview()

        #expect(mediaPreview.id == "movie-tmdb-693134")
        #expect(mediaPreview.type == .movie)
        #expect(mediaPreview.title == "Dune")
        #expect(mediaPreview.year == 2024)
        #expect(mediaPreview.posterPath == nil)
        #expect(mediaPreview.imdbRating == nil)
        #expect(mediaPreview.tmdbId == 693134)
    }

    @Test("toMediaPreview without tmdbId")
    func toMediaPreviewWithoutTmdbId() {
        let recommendation = AIMovieRecommendation(
            title: "Dune Part Two",
            year: 2024,
            type: .movie,
            reason: "Great visual effects",
            tmdbId: nil,
            score: 0.95
        )

        let mediaPreview = recommendation.toMediaPreview()

        #expect(mediaPreview.id == "dune-part-two-2024-movie")
        #expect(mediaPreview.type == .movie)
        #expect(mediaPreview.title == "Dune Part Two")
        #expect(mediaPreview.year == 2024)
    }

    @Test("toMediaPreview for series with tmdbId")
    func toMediaPreviewForSeries() {
        let recommendation = AIMovieRecommendation(
            title: "Severance",
            year: 2025,
            type: .series,
            reason: "Intriguing plot",
            tmdbId: 95513,
            score: 0.88
        )

        let mediaPreview = recommendation.toMediaPreview()

        #expect(mediaPreview.id == "series-tmdb-95513")
        #expect(mediaPreview.type == .series)
        #expect(mediaPreview.title == "Severance")
        #expect(mediaPreview.year == 2025)
    }

    @Test("toMediaPreview uses lowercase hyphenated title for id when no tmdbId")
    func toMediaPreviewIdFormat() {
        let recommendation = AIMovieRecommendation(
            title: "The Batman",
            year: 2022,
            type: .movie,
            reason: "Dark knight",
            tmdbId: nil,
            score: 0.90
        )

        let mediaPreview = recommendation.toMediaPreview()

        #expect(mediaPreview.id == "the-batman-2022-movie")
    }
}

@Suite("AIPersonalizedAnalysis.Verdict Extension")
struct AIPersonalizedAnalysisVerdictExtensionTests {

    @Test("strongYes verdict label")
    func strongYesLabel() {
        #expect(AIPersonalizedAnalysis.Verdict.strongYes.label == "You'd Love This")
    }

    @Test("yes verdict label")
    func yesLabel() {
        #expect(AIPersonalizedAnalysis.Verdict.yes.label == "You'd Enjoy This")
    }

    @Test("maybe verdict label")
    func maybeLabel() {
        #expect(AIPersonalizedAnalysis.Verdict.maybe.label == "It's a Coin Flip")
    }

    @Test("no verdict label")
    func noLabel() {
        #expect(AIPersonalizedAnalysis.Verdict.no.label == "Probably Not For You")
    }

    @Test("strongNo verdict label")
    func strongNoLabel() {
        #expect(AIPersonalizedAnalysis.Verdict.strongNo.label == "Skip This One")
    }

    @Test("strongYes system image")
    func strongYesSystemImage() {
        #expect(AIPersonalizedAnalysis.Verdict.strongYes.systemImage == "heart.fill")
    }

    @Test("yes system image")
    func yesSystemImage() {
        #expect(AIPersonalizedAnalysis.Verdict.yes.systemImage == "hand.thumbsup.fill")
    }

    @Test("maybe system image")
    func maybeSystemImage() {
        #expect(AIPersonalizedAnalysis.Verdict.maybe.systemImage == "hand.raised.fill")
    }

    @Test("no system image")
    func noSystemImage() {
        #expect(AIPersonalizedAnalysis.Verdict.no.systemImage == "hand.thumbsdown")
    }

    @Test("strongNo system image")
    func strongNoSystemImage() {
        #expect(AIPersonalizedAnalysis.Verdict.strongNo.systemImage == "xmark.circle")
    }

    @Test("strongYes tint")
    func strongYesTint() {
        #expect(AIPersonalizedAnalysis.Verdict.strongYes.tint == "green")
    }

    @Test("yes tint")
    func yesTint() {
        #expect(AIPersonalizedAnalysis.Verdict.yes.tint == "green")
    }

    @Test("maybe tint")
    func maybeTint() {
        #expect(AIPersonalizedAnalysis.Verdict.maybe.tint == "yellow")
    }

    @Test("no tint")
    func noTint() {
        #expect(AIPersonalizedAnalysis.Verdict.no.tint == "orange")
    }

    @Test("strongNo tint")
    func strongNoTint() {
        #expect(AIPersonalizedAnalysis.Verdict.strongNo.tint == "red")
    }
}
