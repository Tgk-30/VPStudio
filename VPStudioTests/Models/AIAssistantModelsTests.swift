import Foundation
import Testing
@testable import VPStudio

// MARK: - AIProviderKind

@Suite("AIProviderKind")
struct AIAssistantModelsProviderKindTests {

    @Test func displayNames() {
        #expect(AIProviderKind.openAI.displayName == "OpenAI")
        #expect(AIProviderKind.anthropic.displayName == "Anthropic")
        #expect(AIProviderKind.ollama.displayName == "Ollama")
        #expect(AIProviderKind.gemini.displayName == "Google Gemini")
        #expect(AIProviderKind.openRouter.displayName == "OpenRouter")
        #expect(AIProviderKind.mistral.displayName == "Mistral")
        #expect(AIProviderKind.minimax.displayName == "MiniMax")
        #expect(AIProviderKind.local.displayName == "On-Device (Local)")
    }

    @Test func idEqualsRawValue() {
        for provider in AIProviderKind.allCases {
            #expect(provider.id == provider.rawValue)
        }
    }

    @Test func allCasesCount() {
        #expect(AIProviderKind.allCases.count == 8)
    }
}

// MARK: - AIMovieRecommendation

@Suite("AIMovieRecommendation")
struct AIAssistantModelsRecommendationTests {

    @Test func idUsesTmdbIdWhenAvailable() {
        let rec = AIMovieRecommendation(
            title: "Inception",
            year: 2010,
            type: .movie,
            reason: "Great",
            tmdbId: 27205
        )
        #expect(rec.id == "movie-tmdb-27205")
    }

    @Test func idFallsBackToTitleAndYear() {
        let rec = AIMovieRecommendation(
            title: "Unknown Film",
            year: 2024,
            type: .series,
            reason: "Nice"
        )
        #expect(rec.id == "unknown film-2024-series")
    }

    @Test func idFallsBackWithZeroYearWhenNil() {
        let rec = AIMovieRecommendation(
            title: "Mystery",
            year: nil,
            type: .movie,
            reason: "OK"
        )
        #expect(rec.id == "mystery-0-movie")
    }

    @Test func toMediaPreviewUsesTmdbId() {
        let rec = AIMovieRecommendation(
            title: "Inception",
            year: 2010,
            type: .movie,
            reason: "Great",
            tmdbId: 27205
        )
        let preview = rec.toMediaPreview()
        #expect(preview.id == "movie-tmdb-27205")
        #expect(preview.title == "Inception")
        #expect(preview.year == 2010)
        #expect(preview.type == .movie)
        #expect(preview.tmdbId == 27205)
    }

    @Test func toMediaPreviewSlugifiesTitleWithoutTmdbId() {
        let rec = AIMovieRecommendation(
            title: "Some Great Film",
            year: 2024,
            type: .series,
            reason: "Nice"
        )
        let preview = rec.toMediaPreview()
        #expect(preview.id == "some-great-film-2024-series")
        #expect(preview.tmdbId == nil)
    }
}

// MARK: - AIPersonalizedAnalysis Verdict

@Suite("AIPersonalizedAnalysisVerdict")
struct AIAssistantModelsVerdictTests {

    @Test func rawValues() {
        #expect(AIPersonalizedAnalysis.Verdict.strongYes.rawValue == "strong_yes")
        #expect(AIPersonalizedAnalysis.Verdict.yes.rawValue == "yes")
        #expect(AIPersonalizedAnalysis.Verdict.maybe.rawValue == "maybe")
        #expect(AIPersonalizedAnalysis.Verdict.no.rawValue == "no")
        #expect(AIPersonalizedAnalysis.Verdict.strongNo.rawValue == "strong_no")
    }

    @Test func labels() {
        #expect(AIPersonalizedAnalysis.Verdict.strongYes.label == "You'd Love This")
        #expect(AIPersonalizedAnalysis.Verdict.yes.label == "You'd Enjoy This")
        #expect(AIPersonalizedAnalysis.Verdict.maybe.label == "It's a Coin Flip")
        #expect(AIPersonalizedAnalysis.Verdict.no.label == "Probably Not For You")
        #expect(AIPersonalizedAnalysis.Verdict.strongNo.label == "Skip This One")
    }

    @Test func systemImages() {
        #expect(AIPersonalizedAnalysis.Verdict.strongYes.systemImage == "heart.fill")
        #expect(AIPersonalizedAnalysis.Verdict.yes.systemImage == "hand.thumbsup.fill")
        #expect(AIPersonalizedAnalysis.Verdict.maybe.systemImage == "hand.raised.fill")
        #expect(AIPersonalizedAnalysis.Verdict.no.systemImage == "hand.thumbsdown")
        #expect(AIPersonalizedAnalysis.Verdict.strongNo.systemImage == "xmark.circle")
    }

    @Test func tints() {
        #expect(AIPersonalizedAnalysis.Verdict.strongYes.tint == "green")
        #expect(AIPersonalizedAnalysis.Verdict.yes.tint == "green")
        #expect(AIPersonalizedAnalysis.Verdict.maybe.tint == "yellow")
        #expect(AIPersonalizedAnalysis.Verdict.no.tint == "orange")
        #expect(AIPersonalizedAnalysis.Verdict.strongNo.tint == "red")
    }

    @Test func codableRoundTrip() throws {
        let analysis = AIPersonalizedAnalysis(
            personalizedDescription: "A great film",
            predictedRating: 8.5,
            verdict: .yes,
            reasons: ["Excellent acting", "Great visuals"]
        )
        let data = try JSONEncoder().encode(analysis)
        let decoded = try JSONDecoder().decode(AIPersonalizedAnalysis.self, from: data)
        #expect(decoded.verdict == .yes)
        #expect(decoded.predictedRating == 8.5)
        #expect(decoded.reasons.count == 2)
    }
}

// MARK: - AIProviderResponse & AICompareResult

@Suite("AIProviderResponseAndCompare")
struct AIAssistantModelsResponseTests {

    @Test func aiProviderResponseStruct() {
        let response = AIProviderResponse(
            provider: .openAI,
            content: "Hello",
            model: "gpt-4",
            inputTokens: 10,
            outputTokens: 5
        )
        #expect(response.provider == .openAI)
        #expect(response.inputTokens == 10)
    }

    @Test func aiCompareResultEmpty() {
        let result = AICompareResult(prompt: "test", responses: [:], errors: [:])
        #expect(result.prompt == "test")
        #expect(result.responses.isEmpty)
        #expect(result.errors.isEmpty)
    }
}
