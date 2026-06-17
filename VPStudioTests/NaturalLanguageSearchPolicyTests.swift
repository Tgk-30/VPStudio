import Testing
@testable import VPStudio

@Suite("Natural Language Search Policy")
struct NaturalLanguageSearchPolicyTests {
    @Test
    func promptEmbedsLiteralPhraseAndRequestsJSONShape() {
        let phrase = "gritty 90s korean revenge thrillers"
        let prompt = NaturalLanguageSearchPolicy.recommendationPrompt(from: phrase)

        // The literal phrase is embedded verbatim.
        #expect(prompt.contains(phrase))
        // JSON array shape requested with the keys parseRecommendations expects.
        #expect(prompt.contains("Format as JSON array with keys: title, year, type, reason, tmdbId."))
        #expect(prompt.lowercased().contains("recommend"))
    }

    @Test
    func emptyOrWhitespaceQueryFallsBackToGenericTastePrompt() {
        for query in ["", "   ", "\n\t "] {
            let prompt = NaturalLanguageSearchPolicy.recommendationPrompt(from: query)
            #expect(prompt.contains("Based on my viewing history and preferences"))
            #expect(prompt.contains("Format as JSON array with keys: title, year, type, reason, tmdbId."))
            // No empty quoted phrase leaks into the generic prompt.
            #expect(!prompt.contains("\u{201C}\u{201D}"))
            #expect(!prompt.contains("\"\""))
        }
    }

    @Test
    func excludedTitlesAreAppendedAndCapped() {
        let prompt = NaturalLanguageSearchPolicy.recommendationPrompt(
            from: "cozy mysteries",
            excluding: ["Knives Out", "  ", "Glass Onion"]
        )
        #expect(prompt.contains("Do not recommend any of these titles again: Knives Out, Glass Onion."))
        // Whitespace-only exclusions are dropped.
        #expect(!prompt.contains(",  ,"))
    }

    @Test
    func extractedHintsParseTwoDigitDecade() {
        let hints = NaturalLanguageSearchPolicy.extractedHints(from: "fun 90s action movies")
        #expect(hints.decade == "1990s")
    }

    @Test
    func extractedHintsParseFourDigitDecade() {
        #expect(NaturalLanguageSearchPolicy.extractedHints(from: "1980s sci-fi").decade == "1980s")
        #expect(NaturalLanguageSearchPolicy.extractedHints(from: "2010s dramas").decade == "2010s")
        #expect(NaturalLanguageSearchPolicy.extractedHints(from: "the 1990's").decade == "1990s")
    }

    @Test
    func extractedHintsMapDecadeCenturyByValue() {
        #expect(NaturalLanguageSearchPolicy.extractedHints(from: "00s pop hits").decade == "2000s")
        #expect(NaturalLanguageSearchPolicy.extractedHints(from: "80s synth").decade == "1980s")
    }

    @Test
    func extractedHintsMapLanguageWordToISO639() {
        #expect(NaturalLanguageSearchPolicy.extractedHints(from: "korean revenge thrillers").languageHint == "ko")
        #expect(NaturalLanguageSearchPolicy.extractedHints(from: "classic japanese horror").languageHint == "ja")
        #expect(NaturalLanguageSearchPolicy.extractedHints(from: "french new wave").languageHint == "fr")
        // Alias not phrased the same as the locale display name.
        #expect(NaturalLanguageSearchPolicy.extractedHints(from: "mandarin epics").languageHint == "zh")
    }

    @Test
    func extractedHintsReturnNilWhenNoDecadeOrLanguage() {
        let hints = NaturalLanguageSearchPolicy.extractedHints(from: "something heartwarming to watch")
        #expect(hints.decade == nil)
        #expect(hints.languageHint == nil)
    }

    @Test
    func extractedHintsNormalizeWhitespaceButPreservePhrase() {
        let hints = NaturalLanguageSearchPolicy.extractedHints(from: "   space   opera \n adventures  ")
        #expect(hints.normalizedQuery == "space opera adventures")
    }

    @Test
    func decadeHintAppearsInPromptWhenPresent() {
        let prompt = NaturalLanguageSearchPolicy.recommendationPrompt(from: "90s thrillers")
        #expect(prompt.contains("1990s"))
    }

    @Test
    func looksLikePhraseDistinguishesRequestsFromKeywords() {
        #expect(NaturalLanguageSearchPolicy.looksLikePhrase("something cozy for a rainy night"))
        #expect(NaturalLanguageSearchPolicy.looksLikePhrase("gritty 90s revenge"))
        #expect(NaturalLanguageSearchPolicy.looksLikePhrase("a really long single keyword title here"))

        #expect(!NaturalLanguageSearchPolicy.looksLikePhrase("dune"))
        #expect(!NaturalLanguageSearchPolicy.looksLikePhrase("the matrix"))
        #expect(!NaturalLanguageSearchPolicy.looksLikePhrase("   "))
        #expect(!NaturalLanguageSearchPolicy.looksLikePhrase(""))
    }
}
