import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct AIAssistantManagerRecommendationParsingTests {
    struct CaseData: Sendable {
        let payload: String
        let shouldSucceed: Bool
        let expectedCount: Int
    }

    private static let cases: [CaseData] = {
        var values: [CaseData] = []
        for index in 0..<120 {
            switch index % 6 {
            case 0:
                values.append(
                    CaseData(
                        payload: #"[{"title":"Dune","year":2021,"type":"movie","reason":"Sci-fi","tmdbId":438631}]"#,
                        shouldSucceed: true,
                        expectedCount: 1
                    )
                )
            case 1:
                values.append(
                    CaseData(
                        payload: "```json\n[{\"title\":\"Andor\",\"year\":2022,\"type\":\"series\",\"reason\":\"tone\",\"tmdbId\":83867}]\n```",
                        shouldSucceed: true,
                        expectedCount: 1
                    )
                )
            case 2:
                values.append(
                    CaseData(
                        payload: "Some intro text [ {\"title\":\"Alien\",\"type\":\"movie\"} ] trailing text",
                        shouldSucceed: true,
                        expectedCount: 1
                    )
                )
            case 3:
                values.append(
                    CaseData(
                        payload: #"[{"title":"A","type":"tv"},{"title":"B","type":"show"}]"#,
                        shouldSucceed: true,
                        expectedCount: 2
                    )
                )
            case 4:
                values.append(
                    CaseData(
                        payload: #"{"not":"an array"}"#,
                        shouldSucceed: false,
                        expectedCount: 0
                    )
                )
            default:
                values.append(
                    CaseData(
                        payload: "no json content \(index)",
                        shouldSucceed: false,
                        expectedCount: 0
                    )
                )
            }
        }
        return values
    }()

    @Test(arguments: ExhaustiveMode.choose(fast: Array(cases.prefix(30)), full: cases))
    func recommendationsParsingMatrix(data: CaseData) async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(provider: .openAI, content: data.payload, model: "stub", inputTokens: 1, outputTokens: 1)
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        do {
            let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)
            #expect(data.shouldSucceed)
            #expect(recommendations.count == data.expectedCount)
        } catch {
            #expect(data.shouldSucceed == false)
        }
    }

    @Test
    func parsesTypeWhitespaceAsSeries() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Andor","year":2022,"type":" tv ","reason":"Space-opera","tmdbId":83867}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].type == .series)
    }

    @Test(arguments: [
        ("series", MediaType.series),
        ("tv", MediaType.series),
        ("show", MediaType.series),
        ("TV Series", MediaType.series),
        ("tv show", MediaType.series),
        ("miniseries", MediaType.series),
        ("mini-series", MediaType.series),
        ("K-Drama", MediaType.series),
        ("kdrama", MediaType.series),
        ("anime", MediaType.series),
        ("movie", MediaType.movie),
        ("film", MediaType.movie),
        ("tv movie", MediaType.movie),
        ("anime film", MediaType.movie),
        ("documentary", MediaType.movie),
        ("", MediaType.movie),
    ])
    func normalizesFreeFormTypeStrings(rawType: String, expected: MediaType) {
        #expect(AIAssistantManager.recommendationMediaType(fromRawType: rawType) == expected)
    }

    @Test
    func missingTypeDefaultsToMovie() {
        #expect(AIAssistantManager.recommendationMediaType(fromRawType: nil) == .movie)
    }

    @Test
    func parsesWrappedRecommendationsObject() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        {"recommendations":[{"title":"Andor","year":2022,"type":"series","reason":"tone","tmdbId":83867}]}
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].title == "Andor")
        #expect(recommendations[0].type == .series)
    }

    @Test
    func parsesSingleWrappedRecommendationObject() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        {"recommendation":{"title":"Dune","year":2021,"type":"movie","reason":"Epic","tmdbId":438631}}
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].title == "Dune")
        #expect(recommendations[0].tmdbId == 438631)
    }

    @Test
    func parsesCommonIMDbAndTMDBKeyVariants() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        [{"title":"Dune","year":"2021","type":"movie","reason":"Epic","imdbID":"TT1160419","tmdb_id":"438631"}]
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].imdbId == "tt1160419")
        #expect(recommendations[0].tmdbId == nil)
        #expect(recommendations[0].id == "movie-omdb-tt1160419")
        #expect(recommendations[0].toMediaPreview().id == "tt1160419")
    }

    @Test
    func dropsInvalidIMDbVariantValue() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        [{"title":"Dune","year":2021,"type":"movie","reason":"Epic","imdb":"not-an-imdb-id","tmdb":438631}]
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].imdbId == nil)
        #expect(recommendations[0].tmdbId == 438631)
    }

    @Test
    func parsesUnknownWrapperObject() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        {"payload":{"title":"Andor","year":2022,"type":"series","reason":"pace","tmdbId":83867}}
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].title == "Andor")
        #expect(recommendations[0].type == .series)
    }

    @Test
    func parsesItemResultWrappedRecommendationsObject() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        {"result":{"title":"Andor","year":2022,"type":"tv","reason":"space opera","tmdbId":83867}}
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].type == .series)
    }

    @Test
    func parsesItemsWrappedRecommendationsObject() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        {"items":[{"title":"The Expanse","year":2015,"type":"television","reason":"epic","tmdbId":83122}]}
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].type == .series)
    }

    @Test
    func parsesNestedRecommendationsWrapper() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        {"payload":{"recommendations":[{"title":"The Expanse","year":2015,"type":"tv","reason":"epic","tmdbId":83122}]}}
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].title == "The Expanse")
        #expect(recommendations[0].type == .series)
    }

    @Test
    func parsesNestedResultPayloadWithSingleItem() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        {"result":{"item":{"title":"Andor","year":2022,"type":"series","reason":"pace","tmdbId":83867}}}
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].title == "Andor")
        #expect(recommendations[0].type == .series)
    }

    @Test
    func parsesRecommendationArrayOfSingleItemWrappers() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        {"recommendations":[
            {"recommendation":{"title":"Andor","year":2022,"type":"series","reason":"paced","tmdbId":83867}},
            {"recommendation":{"title":"The Expanse","year":2015,"type":"tv","reason":"epic","tmdbId":83122}}
        ]}
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 2)
        #expect(recommendations[0].title == "Andor")
        #expect(recommendations[0].type == .series)
        #expect(recommendations[1].title == "The Expanse")
        #expect(recommendations[1].type == .series)
    }

    @Test
    func parsesResultArrayWithSingleAndWrappedEntries() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        {"result":[
            {"title":"Arrival","year":2016,"type":"movie","reason":"concept","tmdbId":76203},
            {"recommendation":{"title":"Andor","year":2022,"type":"series","reason":"pace","tmdbId":83867}}
        ]}
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 2)
        #expect(recommendations[0].title == "Arrival")
        #expect(recommendations[0].type == .movie)
        #expect(recommendations[1].title == "Andor")
        #expect(recommendations[1].type == .series)
    }

    @Test
    func parsesMixedRecommendationArrayEntries() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        [
            {"title":"Blade Runner","year":1982,"type":"movie","reason":"neo-noir","tmdbId":78},
            {"recommendation":{"title":"Andor","year":2022,"type":"series","reason":"pace","tmdbId":83867}},
            {"title":"Arrival","year":2016,"type":"movie","reason":"concept","tmdbId":76203}
        ]
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 3)
        #expect(recommendations[0].title == "Blade Runner")
        #expect(recommendations[1].title == "Andor")
        #expect(recommendations[2].title == "Arrival")
    }

    @Test
    func parsesContainerRecommendationsMixedWithWrappedEntries() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let payload = """
        {"recommendations":[
            {"title":"Blade Runner","year":1982,"type":"movie","reason":"neo-noir","tmdbId":78},
            {"recommendation":{"title":"Andor","year":2022,"type":"series","reason":"pace","tmdbId":83867}},
            {"title":"Arrival","year":2016,"type":"movie","reason":"concept","tmdbId":76203}
        ]}
        """
        let response = AIProviderResponse(
            provider: .openAI,
            content: payload,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 3)
        #expect(recommendations[0].title == "Blade Runner")
        #expect(recommendations[1].title == "Andor")
        #expect(recommendations[2].title == "Arrival")
    }

    @Test
    func parsesStringTmdbId() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Arrival","year":2016,"type":"movie","reason":"Acclaimed","tmdbId":"76203"}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].tmdbId == 76203)
    }

    @Test
    func parsesWhitespaceTrimmedStringYearAndTmdbId() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Gravity","year":" 2013 ","type":"movie","reason":"space","tmdbId":" 330459 "}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].year == 2013)
        #expect(recommendations[0].tmdbId == 330459)
    }

    @Test
    func dropsEmptyOrWhitespaceOnlyRecommendationTitles() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"   ","year":2021,"type":"movie","reason":"blank","tmdbId":1},{"title":"","year":2021,"type":"movie","reason":"empty","tmdbId":2},{"title":"Interstellar","year":2014,"type":"movie","reason":"Epic","tmdbId":157336}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].title == "Interstellar")
    }

    @Test
    func deduplicatesTitlesIgnoringOuterWhitespace() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Arrival","year":2016,"type":"movie","reason":"A","tmdbId":76203},{"title":" Arrival ","year":2016,"type":"movie","reason":"B","tmdbId":76203},{"title":"arrival","year":2016,"type":"movie","reason":"C","tmdbId":76203}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].title == "Arrival")
    }

    @Test
    func deduplicatesMixedIMDbAndTMDbRowsByTitleYearAndTypePreferringIMDb() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Dune","year":2021,"type":"movie","reason":"Legacy","tmdbId":438631},{"title":" dune ","year":2021,"type":"movie","reason":"IMDb","imdbId":"TT1160419"}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].title == "Dune")
        #expect(recommendations[0].reason == "Legacy")
        #expect(recommendations[0].imdbId == "tt1160419")
        #expect(recommendations[0].tmdbId == nil)
        #expect(recommendations[0].id == "movie-omdb-tt1160419")
    }

    @Test
    func parsesReasonAsArray() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"The Martian","year":2015,"type":"movie","reason":["gritty","survival","clever"],"tmdbId":" 615655 "}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].reason == "gritty; survival; clever")
    }

    @Test
    func parsesReasonAsNumeric() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"The Martian","year":2015,"type":"movie","reason":2.1,"tmdbId":615655}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].reason == "2.1")
    }

    @Test
    func parsesReasonArrayWithMixedPrimitiveValues() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Cloud Atlas","year":2012,"type":"movie","reason":["Grounded","7",8,2.5,true],"tmdbId":64690}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].reason == "Grounded; 7; 8; 2.5; true")
    }

    @Test
    func parsesReasonArrayWithNullEntriesAndSkipsNullValues() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Cloud Atlas","year":2012,"type":"movie","reason":[null,"Grounded",8,null],"tmdbId":64690}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].reason == "Grounded; 8")
    }

    @Test
    func parsesYearStringAsInt() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Interstellar","year":"2014","type":"movie","reason":"Epic","tmdbId":157336}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].year == 2014)
    }

    @Test
    func ignoresInvalidTmdbIdString() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Blade Runner","year":1982,"type":"movie","reason":"Classic","tmdbId":"not-a-number"}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].tmdbId == nil)
    }

    @Test
    func parsesDecimalYearAndTmdbIdValues() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Interstellar","year":2014.0,"type":"movie","reason":"Epic","tmdbId":328111.0}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].year == 2014)
        #expect(recommendations[0].tmdbId == 328111)
    }

    @Test
    func parsesDecimalYearAndTmdbIdStringValues() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"Interstellar","year":"2014.0","type":"movie","reason":"Epic","tmdbId":"328111.0"}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].year == 2014)
        #expect(recommendations[0].tmdbId == 328111)
    }

    @Test
    func parsesTVSeriesTypeWithSpacing() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":"The Expanse","year":2015,"type":"TV Series","reason":"space opera","tmdbId":83122}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].type == .series)
    }

    @Test
    func skipsInvalidRecommendationEntries() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":1,"year":2021,"type":"movie"},{"title":"Valid Show","year":2022,"type":"tv","reason":"stable cast"}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        let recommendations = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)

        #expect(recommendations.count == 1)
        #expect(recommendations[0].title == "Valid Show")
    }

    @Test
    func throwsWhenNoValidRecommendationEntries() async throws {
        let manager = try await makeManager()
        defer { try? FileManager.default.removeItem(at: manager.tempDir) }

        let response = AIProviderResponse(
            provider: .openAI,
            content: #"[{"title":1},{"title":true},{"type":"tv"}]"#,
            model: "stub",
            inputTokens: 1,
            outputTokens: 1
        )
        await manager.instance.registerProvider(
            kind: .openAI,
            provider: StubAIProvider(providerKind: .openAI, result: .success(response))
        )

        do {
            _ = try await manager.instance.getRecommendations(context: AssistantContext(), provider: .openAI)
            Issue.record("Expected AIError.invalidResponse")
        } catch let error as AIError {
            if case .invalidResponse = error {
                // expected
            } else {
                Issue.record("Expected AIError.invalidResponse, got \(error)")
            }
        }
    }

    private func makeManager() async throws -> (instance: AIAssistantManager, tempDir: URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let db = try DatabaseManager(inMemoryNamed: "ai-\(UUID().uuidString)")
        try await db.migrate()
        return (AIAssistantManager(database: db), tempDir)
    }
}
