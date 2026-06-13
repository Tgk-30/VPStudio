import Testing
@testable import VPStudio

@Suite("AI Model Catalog Static Entry Coverage")
struct AIModelCatalogStaticEntryCoverageTests {
    @Test
    func namedCatalogEntriesMatchAllModelsAndRemainUnique() {
        let namedEntries = [
            AIModelCatalog.claudeOpus46,
            AIModelCatalog.claudeSonnet46,
            AIModelCatalog.claudeOpus4,
            AIModelCatalog.claudeSonnet4,
            AIModelCatalog.claudeHaiku35,
            AIModelCatalog.gpt54,
            AIModelCatalog.gpt54Mini,
            AIModelCatalog.gpt54Nano,
            AIModelCatalog.gpt5,
            AIModelCatalog.gpt4o,
            AIModelCatalog.gpt4oMini,
            AIModelCatalog.o1,
            AIModelCatalog.llama31,
            AIModelCatalog.llama32,
            AIModelCatalog.mistral,
            AIModelCatalog.gemini25Flash,
            AIModelCatalog.gemini25Pro,
            AIModelCatalog.openRouterGeminiFlashLite,
            AIModelCatalog.openRouterClaudeHaiku,
            AIModelCatalog.openRouterGPT4oMini,
            AIModelCatalog.openRouterLlama3,
            AIModelCatalog.openRouterMistralNemo,
            AIModelCatalog.openRouterQwen,
            AIModelCatalog.mistralSmallLatest,
            AIModelCatalog.mistralMediumLatest,
            AIModelCatalog.codestralLatest,
            AIModelCatalog.minimaxM27,
            AIModelCatalog.minimaxM27Highspeed,
            AIModelCatalog.minimaxM25,
            AIModelCatalog.minimaxM25Highspeed,
            AIModelCatalog.minimaxM21,
            AIModelCatalog.minimaxM21Highspeed,
            AIModelCatalog.minimaxM2,
            AIModelCatalog.localSmolLM2,
            AIModelCatalog.localPhi3Mini,
            AIModelCatalog.localOpenELM3B,
        ]

        #expect(namedEntries == AIModelCatalog.allModels)
        #expect(Set(namedEntries.map(\.id)).count == namedEntries.count)
        #expect(namedEntries.allSatisfy { !$0.id.isEmpty && !$0.displayName.isEmpty })
        #expect(namedEntries.allSatisfy { $0.maxContextTokens > 0 })
    }

    @Test
    func defaultEntriesAreOnePerProviderFamily() {
        let defaults = Dictionary(grouping: AIModelCatalog.allModels.filter(\.isDefault), by: \.provider)

        #expect(defaults[.anthropic]?.map(\.id) == [AIModelCatalog.claudeSonnet46.id])
        #expect(defaults[.openAI]?.map(\.id) == [AIModelCatalog.gpt54.id])
        #expect(defaults[.ollama]?.map(\.id) == [AIModelCatalog.llama31.id])
        #expect(defaults[.gemini]?.map(\.id) == [AIModelCatalog.gemini25Flash.id])
        #expect(defaults[.openRouter]?.map(\.id) == [AIModelCatalog.openRouterGeminiFlashLite.id])
        #expect(defaults[.mistral]?.map(\.id) == [AIModelCatalog.mistralSmallLatest.id])
        #expect(defaults[.minimax]?.map(\.id) == [AIModelCatalog.minimaxM27.id])
        #expect(defaults[.local]?.map(\.id) == [AIModelCatalog.localSmolLM2.id])
    }

    @Test
    func paidAndLocalProviderCostsUseExpectedZeroOrPositiveShape() {
        let freeProviders: Set<AIProviderKind> = [.ollama, .local]

        for model in AIModelCatalog.allModels {
            if freeProviders.contains(model.provider) {
                #expect(model.inputCostPer1MTokens == 0)
                #expect(model.outputCostPer1MTokens == 0)
            } else {
                #expect(model.inputCostPer1MTokens > 0, "\(model.id) should have a positive input price")
                #expect(model.outputCostPer1MTokens > 0, "\(model.id) should have a positive output price")
            }
        }
    }

    @Test
    func openRouterKnownModelsMirrorCatalogSubset() {
        #expect(OpenRouterProvider.knownModels.map(\.id) == [
            AIModelCatalog.openRouterGeminiFlashLite.id,
            AIModelCatalog.openRouterClaudeHaiku.id,
            AIModelCatalog.openRouterGPT4oMini.id,
            AIModelCatalog.openRouterLlama3.id,
            AIModelCatalog.openRouterMistralNemo.id,
            AIModelCatalog.openRouterQwen.id,
        ])
        #expect(OpenRouterProvider.knownModels.allSatisfy { $0.provider == .openRouter })
        #expect(OpenRouterProvider.knownModels.filter(\.isDefault).map(\.id) == [
            AIModelCatalog.openRouterGeminiFlashLite.id,
        ])
    }
}
