import Foundation
import Testing
@testable import VPStudio

@Suite("AIModelCatalog Dynamic Fallback Coverage")
struct AIModelCatalogDynamicFallbackCoverageTests {
    @Test func mistralFetcherFormatsUnknownSupportedIDsAndFiltersUnsupportedRows() async throws {
        let session = URLProtocolHarness.makeSession { request in
            #expect(request.url?.absoluteString == "https://api.mistral.ai/v1/models")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer dynamic-key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    ["id": "custom_mistral-model_v2"],
                    ["id": "ministral-edge_case"],
                    ["id": "embedding-mistral-large"],
                    ["id": "unrelated-chat-model"],
                    ["id": ""],
                    ["name": "Missing ID"],
                ],
            ])
            return (response, data)
        }

        let models = await AIModelFetcher.fetchMistralModels(apiKey: " dynamic-key ", session: session)

        #expect(models.map(\.id) == ["custom_mistral-model_v2", "ministral-edge_case"])
        #expect(models.first(where: { $0.id == "custom_mistral-model_v2" })?.displayName == "Custom Mistral Model V2")
        #expect(models.first(where: { $0.id == "custom_mistral-model_v2" })?.maxContextTokens == 128_000)
        #expect(models.first(where: { $0.id == "custom_mistral-model_v2" })?.inputCostPer1MTokens == 0)
        #expect(models.first(where: { $0.id == "ministral-edge_case" })?.displayName == "Ministral Edge Case")
    }

    @Test func miniMaxFetcherFormatsUnknownIDsAndUsesDefaultEconomics() async throws {
        let session = URLProtocolHarness.makeSession { request in
            #expect(request.url?.absoluteString == "https://api.minimax.io/v1/models")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer minimax-key")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: [
                "data": [
                    ["id": "voice_minimax-model_v3"],
                    ["id": "MiniMax-M2.7"],
                    ["id": ""],
                    ["display_name": "Missing ID"],
                ],
            ])
            return (response, data)
        }

        let models = await AIModelFetcher.fetchMiniMaxModels(apiKey: "\nminimax-key\t", session: session)

        #expect(models.map(\.id) == ["MiniMax-M2.7", "voice_minimax-model_v3"])
        #expect(models.first(where: { $0.id == "MiniMax-M2.7" })?.displayName == "MiniMax M2.7")
        #expect(models.first(where: { $0.id == "MiniMax-M2.7" })?.isDefault == true)
        #expect(models.first(where: { $0.id == "voice_minimax-model_v3" })?.displayName == "Voice Minimax Model V3")
        #expect(models.first(where: { $0.id == "voice_minimax-model_v3" })?.maxContextTokens == 204_800)
        #expect(models.first(where: { $0.id == "voice_minimax-model_v3" })?.outputCostPer1MTokens == 0)
    }
}
