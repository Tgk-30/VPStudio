import Testing
import Foundation
@testable import VPStudio

@Suite("AIMovieRecommendation Codable Round-Trip")
struct AIMovieRecommendationCodableTests {
    @Test("AIMovieRecommendation with tmdbId encodes and decodes correctly")
    func aimovieRecommendationWithTmdbIdCodableRoundTrip() throws {
        let original = AIMovieRecommendation(
            title: "Inception",
            year: 2010,
            type: .movie,
            reason: "Great sci-fi action film",
            tmdbId: 27205,
            score: 0.95
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIMovieRecommendation.self, from: encoded)

        #expect(decoded.title == original.title)
        #expect(decoded.year == original.year)
        #expect(decoded.type == original.type)
        #expect(decoded.reason == original.reason)
        #expect(decoded.tmdbId == original.tmdbId)
        #expect(decoded.score == original.score)
    }

    @Test("AIMovieRecommendation without tmdbId encodes and decodes correctly")
    func aimovieRecommendationWithoutTmdbIdCodableRoundTrip() throws {
        let original = AIMovieRecommendation(
            title: "Unknown Film",
            year: 2024,
            type: .series,
            reason: "Interesting premise",
            tmdbId: nil,
            score: 0.75
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIMovieRecommendation.self, from: encoded)

        #expect(decoded.tmdbId == nil)
        #expect(decoded.title == original.title)
    }

    @Test("AIMovieRecommendation id uses tmdbId when available")
    func aimovieRecommendationIdWithTmdbId() throws {
        let original = AIMovieRecommendation(
            title: "Inception",
            year: 2010,
            type: .movie,
            reason: "Great",
            tmdbId: 27205
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIMovieRecommendation.self, from: encoded)

        #expect(decoded.id == "movie-tmdb-27205")
    }

    @Test("AIMovieRecommendation id prefers OMDb-scoped imdbId when both ids are available")
    func aimovieRecommendationIdPrefersOMDbScopedImdbId() throws {
        let original = AIMovieRecommendation(
            title: "Dune",
            year: 2021,
            type: .movie,
            reason: "Great",
            imdbId: "tt1160419",
            tmdbId: 438631
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIMovieRecommendation.self, from: encoded)
        let preview = decoded.toMediaPreview()

        #expect(decoded.id == "movie-omdb-tt1160419")
        #expect(preview.id == "tt1160419")
        #expect(preview.tmdbId == nil)
    }

    @Test("AIMovieRecommendation accepts app-scoped OMDb imdbId values")
    func aimovieRecommendationIdAcceptsOMDbScopedImdbId() throws {
        let original = AIMovieRecommendation(
            title: "Dune",
            year: 2021,
            type: .movie,
            reason: "Great",
            imdbId: "movie-omdb-TT1160419",
            tmdbId: 438631
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIMovieRecommendation.self, from: encoded)
        let preview = decoded.toMediaPreview()

        #expect(decoded.canonicalIMDbID == "tt1160419")
        #expect(decoded.canonicalOMDbMediaID == "movie-omdb-tt1160419")
        #expect(decoded.id == "movie-omdb-tt1160419")
        #expect(preview.id == "tt1160419")
        #expect(preview.tmdbId == nil)
    }

    @Test("AIMovieRecommendation id falls back to title-year when no tmdbId")
    func aimovieRecommendationIdFallback() throws {
        let original = AIMovieRecommendation(
            title: "Some Great Film",
            year: 2024,
            type: .series,
            reason: "Nice"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIMovieRecommendation.self, from: encoded)

        #expect(decoded.id == "some great film-2024-series")
    }

    @Test("AIMovieRecommendation toMediaPreview works after codable round-trip")
    func aimovieRecommendationToMediaPreviewAfterCodable() throws {
        let original = AIMovieRecommendation(
            title: "Inception",
            year: 2010,
            type: .movie,
            reason: "Great sci-fi",
            tmdbId: 27205,
            score: 0.95
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIMovieRecommendation.self, from: encoded)

        let preview = decoded.toMediaPreview()
        #expect(preview.id == "movie-tmdb-27205")
        #expect(preview.title == "Inception")
        #expect(preview.year == 2010)
        #expect(preview.type == .movie)
        #expect(preview.tmdbId == 27205)
    }
}

@Suite("AIPersonalizedAnalysis Codable Round-Trip")
struct AIPersonalizedAnalysisCodableTests {
    @Test("AIPersonalizedAnalysis encodes and decodes correctly")
    func aipersonalizedAnalysisCodableRoundTrip() throws {
        let original = AIPersonalizedAnalysis(
            personalizedDescription: "This film matches your taste perfectly",
            predictedRating: 8.5,
            verdict: .yes,
            reasons: ["Great acting", "Beautiful cinematography", "Engaging story"]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIPersonalizedAnalysis.self, from: encoded)

        #expect(decoded.personalizedDescription == original.personalizedDescription)
        #expect(decoded.predictedRating == original.predictedRating)
        #expect(decoded.verdict == original.verdict)
        #expect(decoded.reasons == original.reasons)
    }

    @Test("AIPersonalizedAnalysis all verdict cases encode and decode correctly")
    func aipersonalizedAnalysisAllVerdictCases() throws {
        let verdicts: [AIPersonalizedAnalysis.Verdict] = [.strongYes, .yes, .maybe, .no, .strongNo]

        for verdict in verdicts {
            let analysis = AIPersonalizedAnalysis(
                personalizedDescription: "Test",
                predictedRating: 5.0,
                verdict: verdict,
                reasons: ["test"]
            )

            let encoded = try JSONEncoder().encode(analysis)
            let decoded = try JSONDecoder().decode(AIPersonalizedAnalysis.self, from: encoded)

            #expect(decoded.verdict == verdict)
        }
    }

    @Test("AIPersonalizedAnalysis verdict properties are preserved after codable")
    func aipersonalizedAnalysisVerdictPropertiesAfterCodable() throws {
        let original = AIPersonalizedAnalysis(
            personalizedDescription: "Test analysis",
            predictedRating: 7.5,
            verdict: .yes,
            reasons: ["Good pacing"]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIPersonalizedAnalysis.self, from: encoded)

        #expect(decoded.verdict.label == "You'd Enjoy This")
        #expect(decoded.verdict.systemImage == "hand.thumbsup.fill")
        #expect(decoded.verdict.tint == "green")
    }

    @Test("AIPersonalizedAnalysis with empty reasons encodes and decodes correctly")
    func aipersonalizedAnalysisEmptyReasonsCodableRoundTrip() throws {
        let original = AIPersonalizedAnalysis(
            personalizedDescription: "No specific reasons",
            predictedRating: 5.0,
            verdict: .maybe,
            reasons: []
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIPersonalizedAnalysis.self, from: encoded)

        #expect(decoded.reasons == [])
    }
}
