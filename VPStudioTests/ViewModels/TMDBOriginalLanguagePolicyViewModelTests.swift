import Testing
@testable import VPStudio

@Suite("TMDBOriginalLanguagePolicy Should Send Original Language")
struct TMDBOriginalLanguagePolicyTests {
    @Test("Empty set returns false")
    func emptySet() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: []) == false)
    }

    @Test("Multiple languages returns false")
    func multipleLanguages() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["en-US", "fr-FR"]) == false)
    }

    @Test("Single en-US returns false")
    func singleEnglish() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["en-US"]) == false)
    }

    @Test("Single non-English, non-Hindi returns true")
    func singleNonEnglish() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["fr-FR"]) == true)
    }

    @Test("Single Hindi returns false")
    func singleHindi() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["hi-IN"]) == false)
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["hi"]) == false)
    }

    @Test("Single related Indian language returns false")
    func relatedIndianLanguages() {
        let codes = ["as", "bn", "gu", "hi", "kn", "ml", "mr", "or", "pa", "ta", "te", "ur"]
        for code in codes {
            #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: [code]) == false, "Code \(code) should return false")
        }
    }

    @Test("Whitespace only returns false")
    func whitespaceOnly() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["   "]) == false)
    }

    @Test("Empty string returns false")
    func emptyString() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: [""]) == false)
    }
}

@Suite("TMDBOriginalLanguagePolicy Original Language Code")
struct TMDBOriginalLanguagePolicyCodeTests {
    @Test("en-US returns nil")
    func englishReturnsNil() {
        #expect(TMDBOriginalLanguagePolicy.originalLanguageCode(for: ["en-US"]) == nil)
    }

    @Test("Hindi returns nil")
    func hindiReturnsNil() {
        #expect(TMDBOriginalLanguagePolicy.originalLanguageCode(for: ["hi-IN"]) == nil)
    }

    @Test("Valid non-Hindi returns code via DiscoverFilters")
    func validNonHindi() {
        let result = TMDBOriginalLanguagePolicy.originalLanguageCode(for: ["fr-FR"])
        #expect(result != nil)
    }

    @Test("Empty set returns nil")
    func emptySetReturnsNil() {
        #expect(TMDBOriginalLanguagePolicy.originalLanguageCode(for: []) == nil)
    }
}

@Suite("TMDBOriginalLanguagePolicy Indian Locale Detection")
struct TMDBOriginalLanguagePolicyIndianLocaleTests {
    @Test("Hindi with region code IN")
    func hindiWithIndiaRegion() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["hi_IN"]) == false)
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["hi-IN"]) == false)
    }

    @Test("Tamil with region code IN")
    func tamilWithIndiaRegion() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["ta_IN"]) == false)
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["ta-In"]) == false)
    }

    @Test("Tamil without region code")
    func tamilWithoutRegionCode() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["ta"]) == false)
    }

    @Test("Bengali without region code")
    func bengaliWithoutRegionCode() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["bn"]) == false)
    }

    @Test("Case insensitivity for region codes")
    func caseInsensitive() {
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["hi_In"]) == false)
        #expect(TMDBOriginalLanguagePolicy.shouldSendOriginalLanguage(for: ["HI-IN"]) == false)
    }
}
