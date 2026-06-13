import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct AIAssistantManagerPersonalizedAnalysisParsingTests {
    @Test
    func parsesDirectJSONObject() async throws {
        let manager = try await makeManager()
        let payload = """
        {"personalizedDescription":"You like cerebral sci-fi with character focus.","predictedRating":8.6,"verdict":"yes","reasons":["Strong thematic depth","Matches your recent ratings"]}
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Arrival",
            year: 2016,
            type: .movie,
            genres: ["Sci-Fi"],
            overview: "A linguist works to communicate with aliens."
        )

        #expect(result.verdict == .yes)
        #expect(result.reasons.count == 2)
        #expect(result.predictedRating == 8.6)
    }

    @Test
    func parsesFencedJSONResponse() async throws {
        let manager = try await makeManager()
        let payload = """
        Sure, here's the result:
        ```json
        {"personalizedDescription":"Likely a strong fit for your pacing preferences.","predictedRating":9.1,"verdict":"strong_yes","reasons":["High concept","Consistent tone"]}
        ```
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Dune",
            year: 2021,
            type: .movie,
            genres: ["Sci-Fi"],
            overview: "A noble family becomes entangled in a galactic conflict."
        )

        #expect(result.verdict == .strongYes)
        #expect(result.predictedRating == 9.1)
    }

    @Test
    func parsesNarrativeWrappedJSONObject() async throws {
        let manager = try await makeManager()
        let payload = """
        My analysis follows.
        The short answer is below:
        {"personalizedDescription":"This likely aligns with your preference for grounded suspense.","predictedRating":7.2,"verdict":"maybe","reasons":["Good character work","Mood may be slower than your usual picks"]}
        Hope this helps.
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Prisoners",
            year: 2013,
            type: .movie,
            genres: ["Thriller"],
            overview: "A desperate father takes matters into his own hands."
        )

        #expect(result.verdict == .maybe)
        #expect(result.predictedRating == 7.2)
    }

    @Test
    func parsesWrappedResultObject() async throws {
        let manager = try await makeManager()
        let payload = #"""
        {"result":{"personalizedDescription":"You’ll probably like this based on your recent preferences.","predictedRating":8.7,"verdict":"strong_yes","reasons":["Inventive","Great cast"]}}
        """#
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Blade Runner",
            year: 1982,
            type: .movie,
            genres: ["Sci-Fi", "Noir"],
            overview: "A detective of the future pursues a replicant."
        )

        #expect(result.verdict == .strongYes)
        #expect(result.predictedRating == 8.7)
        #expect(result.reasons.count == 2)
    }

    @Test
    func parsesUnknownWrapperPersonalizedObject() async throws {
        let manager = try await makeManager()
        let payload = #"""
        {"payload":{"personalizedDescription":"Character-driven stories play to this profile.","predictedRating":8.4,"verdict":"yes","reasons":["Emotion","Strong performances"]}}
        """#
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "The Arrival",
            year: 2016,
            type: .movie,
            genres: ["Drama", "Sci-Fi"],
            overview: "A linguist helps humanity communicate with aliens."
        )

        #expect(result.verdict == .yes)
        #expect(result.predictedRating == 8.4)
        #expect(result.reasons == ["Emotion", "Strong performances"])
    }

    @Test
    func parsesTextWrappedJSONArray() async throws {
        let manager = try await makeManager()
        let payload = """
        Here is my output:
        [
          {
            "personalizedDescription":"This is a match if you like tense visuals.",
            "predictedRating":7.9,
            "verdict":"maybe",
            "reasons":["Stylish direction","Measured pacing"]
          }
        ]
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Inception",
            year: 2010,
            type: .movie,
            genres: ["Sci-Fi"],
            overview: "A dream thief gets pulled into layered realities."
        )

        #expect(result.verdict == .maybe)
        #expect(result.predictedRating == 7.9)
        #expect(result.reasons.count == 2)
    }

    @Test
    func parsesWhitespaceAndCasedVerdictValues() async throws {
        let manager = try await makeManager()
        let payload = """
        ```json
        {"personalizedDescription":"Might be a little dense for now.","predictedRating":6.5,"verdict":" YES ","reasons":["Strong visuals","Complex plot"]}
        ```
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "The Thing",
            year: 1982,
            type: .movie,
            genres: ["Horror"],
            overview: "A research team encounters an alien threat in Antarctica."
        )

        #expect(result.verdict == .yes)
        #expect(result.predictedRating == 6.5)
    }

    @Test
    func parsesVerdictWithSpaceSeparatedStrongValues() async throws {
        let manager = try await makeManager()
        let payload = """
        {
            "personalizedDescription":"Bold tone and pacing.",
            "predictedRating":8.8,
            "verdict":"strong yes",
            "reasons":["Confident fit"]
        }
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Nope",
            year: 2020,
            type: .movie,
            genres: ["Thriller"],
            overview: "A tense thriller."
        )

        #expect(result.verdict == .strongYes)
    }

    @Test
    func parsesSingleStringReasons() async throws {
        let manager = try await makeManager()
        let payload = """
        {"personalizedDescription":"Strong fit for your taste in grounded sci-fi.","predictedRating":8.0,"verdict":"yes","reasons":"High production values with deliberate pacing"}
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Interstellar",
            year: 2014,
            type: .movie,
            genres: ["Sci-Fi"],
            overview: "A team of explorers travels through a wormhole."
        )

        #expect(result.reasons.count == 1)
        #expect(result.reasons[0] == "High production values with deliberate pacing")
    }

    @Test
    func parsesStringPredictedRating() async throws {
        let manager = try await makeManager()
        let payload = """
        {"personalizedDescription":"A classic that matches emotional pacing.","predictedRating":"8.4","verdict":"strong_yes","reasons":["Strong character focus","Beautiful score"]}
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Blade Runner 2049",
            year: 2017,
            type: .movie,
            genres: ["Sci-Fi"],
            overview: "A blade runner uncovers secrets."
        )

        #expect(result.predictedRating == 8.4)
    }

    @Test
    func parsesVerdictWithPunctuationAndExtraChars() async throws {
        let manager = try await makeManager()
        let payload = """
        {
            "personalizedDescription":"The tone lines up with strong mood choices.",
            "predictedRating": 8.9,
            "verdict": "Strong-Yes!!!",
            "reasons": ["confident on character work", "good pacing"]
        }
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Inception",
            year: 2010,
            type: .movie,
            genres: ["Sci-Fi"],
            overview: nil
        )

        #expect(result.verdict == .strongYes)
        #expect(result.predictedRating == 8.9)
    }

    @Test
    func parsesWhitespacePredictedRatingString() async throws {
        let manager = try await makeManager()
        let payload = """
        {"personalizedDescription":"Fits your style for slower emotional arcs.","predictedRating":" 8.1 ","verdict":"maybe","reasons":["Atmospheric","Great worldbuilding"]}
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Arrival",
            year: 2016,
            type: .movie,
            genres: ["Sci-Fi", "Drama"],
            overview: "Aliens, language, and human unity."
        )

        #expect(result.predictedRating == 8.1)
    }

    @Test
    func parsesMixedReasonValuesAsStrings() async throws {
        let manager = try await makeManager()
        let payload = """
        {
            "personalizedDescription":"A strong but unconventional fit.",
            "predictedRating":8.2,
            "verdict":"yes",
            "reasons":["Grounded","7",2.5,true]
        }
        """
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: payload, model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        let result = try await manager.getPersonalizedAnalysis(
            title: "Arrival",
            year: 2016,
            type: .movie,
            genres: ["Sci-Fi"],
            overview: "A linguist works to communicate with aliens."
        )

        #expect(result.reasons == ["Grounded", "7", "2.5", "true"])
    }

    @Test
    func throwsInvalidResponseForNonJSONContent() async throws {
        let manager = try await makeManager()
        await manager.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(
                providerKind: .openAI,
                result: .success(AIProviderResponse(provider: .openAI, content: "I cannot provide that in JSON right now.", model: "stub", inputTokens: 1, outputTokens: 1))
            )
        )

        do {
            _ = try await manager.getPersonalizedAnalysis(
                title: "Unknown",
                year: nil,
                type: .movie,
                genres: [],
                overview: nil
            )
            Issue.record("Expected AIError.invalidResponse")
        } catch let error as AIError {
            if case .invalidResponse = error {
                // expected
            } else {
                Issue.record("Expected AIError.invalidResponse, got \(error)")
            }
        }
    }

    private func makeManager() async throws -> AIAssistantManager {
        let db = try DatabaseManager(inMemoryNamed: "ai-personalized-analysis-\(UUID().uuidString)")
        try await db.migrate()
        return AIAssistantManager(database: db)
    }
}
