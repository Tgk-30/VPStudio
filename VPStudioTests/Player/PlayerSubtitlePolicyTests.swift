import Testing
@testable import VPStudio

@Suite("Player Subtitle Policy")
struct PlayerSubtitlePolicyTests {
    @Test func preferredLanguageCodesTrimLowercaseAndDropBlanks() {
        #expect(
            PlayerSubtitlePolicy.preferredLanguageCodes(from: " en-US, es , ,fr-CA ")
                == ["en-us", "es", "fr-ca"]
        )
    }

    @Test func automaticSubtitleLanguageCodesPreferSystemWhenClosedCaptionsEnabled() {
        let codes = PlayerSubtitlePolicy.automaticSubtitleLanguageCodes(
            configuredLanguageSetting: "es, fr",
            systemPreferredLanguages: ["de-DE", "en_US", "de-DE"],
            closedCaptioningEnabled: true
        )

        #expect(codes == ["de", "en", "es", "fr"])
    }

    @Test func automaticSubtitleLanguageCodesNormalizeHyphenAndUnderscoreLocaleInputs() {
        let codes = PlayerSubtitlePolicy.automaticSubtitleLanguageCodes(
            configuredLanguageSetting: "en, ja",
            systemPreferredLanguages: [" pt-BR ", "en_US", "pt_BR", ""],
            closedCaptioningEnabled: true
        )

        #expect(codes == ["pt", "en", "ja"])
    }

    @Test func automaticSubtitleLanguageCodesFallsBackToConfiguredThenSystemThenEnglish() {
        #expect(
            PlayerSubtitlePolicy.automaticSubtitleLanguageCodes(
                configuredLanguageSetting: " it ",
                systemPreferredLanguages: ["fr-CA"],
                closedCaptioningEnabled: false
            ) == ["it"]
        )
        #expect(
            PlayerSubtitlePolicy.automaticSubtitleLanguageCodes(
                configuredLanguageSetting: nil,
                systemPreferredLanguages: ["fr-CA"],
                closedCaptioningEnabled: false
            ) == ["fr"]
        )
        #expect(
            PlayerSubtitlePolicy.automaticSubtitleLanguageCodes(
                configuredLanguageSetting: nil,
                systemPreferredLanguages: [],
                closedCaptioningEnabled: false
            ) == ["en"]
        )
    }

    @Test func automaticSubtitleLanguageCodesWithClosedCaptionsFallsBackWhenSystemCodesAreEmpty() {
        #expect(
            PlayerSubtitlePolicy.automaticSubtitleLanguageCodes(
                configuredLanguageSetting: " es, de ",
                systemPreferredLanguages: [" ", "\n"],
                closedCaptioningEnabled: true
            ) == ["es", "de"]
        )
        #expect(
            PlayerSubtitlePolicy.automaticSubtitleLanguageCodes(
                configuredLanguageSetting: " , ",
                systemPreferredLanguages: [" "],
                closedCaptioningEnabled: true
            ) == ["en"]
        )
    }

    @Test func matchesPreferredLanguageByLocaleOrExtendedTagPrefix() {
        #expect(
            PlayerSubtitlePolicy.matchesPreferredLanguage(
                localeIdentifier: "en-US",
                extendedLanguageTag: nil,
                preferredLanguages: ["en"]
            )
        )
        #expect(
            PlayerSubtitlePolicy.matchesPreferredLanguage(
                localeIdentifier: nil,
                extendedLanguageTag: "pt-BR",
                preferredLanguages: ["pt"]
            )
        )
        #expect(
            !PlayerSubtitlePolicy.matchesPreferredLanguage(
                localeIdentifier: "fr-FR",
                extendedLanguageTag: "fr",
                preferredLanguages: ["en", "es"]
            )
        )
    }

    @Test func matchesPreferredLanguageNormalizesRegionalSeparators() {
        #expect(
            PlayerSubtitlePolicy.matchesPreferredLanguage(
                localeIdentifier: "en_US",
                extendedLanguageTag: nil,
                preferredLanguages: ["en-us"]
            )
        )
        #expect(
            PlayerSubtitlePolicy.matchesPreferredLanguage(
                localeIdentifier: nil,
                extendedLanguageTag: "fr_CA",
                preferredLanguages: ["fr-ca"]
            )
        )
        #expect(
            !PlayerSubtitlePolicy.matchesPreferredLanguage(
                localeIdentifier: "english",
                extendedLanguageTag: nil,
                preferredLanguages: ["en"]
            )
        )
    }

    @Test func matchesPreferredLanguageSkipsBlankPreferredLanguages() {
        #expect(
            PlayerSubtitlePolicy.matchesPreferredLanguage(
                localeIdentifier: "ja-JP",
                extendedLanguageTag: nil,
                preferredLanguages: [" ", "ja"]
            )
        )
        #expect(
            !PlayerSubtitlePolicy.matchesPreferredLanguage(
                localeIdentifier: nil,
                extendedLanguageTag: nil,
                preferredLanguages: [" ", "\n"]
            )
        )
    }

    @Test func subtitleSearchQueryCollapsesFilenameSeparatorsAndTrimsExtension() {
        #expect(
            PlayerSubtitlePolicy.subtitleSearchQuery(from: "  S01E01.Final_cut.mkv  ")
                == "S01E01 Final cut"
        )
        #expect(
            PlayerSubtitlePolicy.subtitleSearchQuery(from: "Movie...Director_Cut.en.srt")
                == "Movie Director Cut en"
        )
    }

    @Test func subtitleSearchQueryHandlesBlankAndExtensionOnlyFileNames() {
        #expect(PlayerSubtitlePolicy.subtitleSearchQuery(from: "   ") == "")
        #expect(PlayerSubtitlePolicy.subtitleSearchQuery(from: ".srt") == "srt")
    }

    @Test func mediaTrackDisplayNameFallsBackThroughCandidatesAndIndex() {
        #expect(
            PlayerSubtitlePolicy.mediaTrackDisplayName(
                fallback: "  English  ",
                name: "Track",
                description: "Description",
                index: 0,
                kind: "Audio"
            ) == "English"
        )
        #expect(
            PlayerSubtitlePolicy.mediaTrackDisplayName(
                fallback: " ",
                name: "  Stereo  ",
                description: "Description",
                index: 1,
                kind: "Audio"
            ) == "Stereo"
        )
        #expect(
            PlayerSubtitlePolicy.mediaTrackDisplayName(
                fallback: nil,
                name: "",
                description: "  Commentary  ",
                index: 2,
                kind: "Subtitle"
            ) == "Commentary"
        )
        #expect(
            PlayerSubtitlePolicy.mediaTrackDisplayName(
                fallback: nil,
                name: nil,
                description: " ",
                index: 3,
                kind: "Subtitle"
            ) == "Subtitle 4"
        )
    }
}
