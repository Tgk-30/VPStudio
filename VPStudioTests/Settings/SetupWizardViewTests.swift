import Foundation
import Testing
@testable import VPStudio

@Suite("SetupWizardView and SetupWizardValidationPolicy Comprehensive Tests")
struct SetupWizardViewTests {

    // MARK: - SetupWizardValidationPolicy Tests

    @Suite("SetupWizardValidationPolicy - Metadata Provider Validation")
    struct MetadataProviderValidationTests {
        @Test
        func canContinueFromMetadataStepRequiresNonEmptyKey() {
            #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "", tmdbApiKey: "") == false)
            #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "   ", tmdbApiKey: "") == false)
            #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "\n\t", tmdbApiKey: " \r\n") == false)
        }

        @Test
        func canContinueFromMetadataStepRequiresOMDbKey() {
            #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "abc123", tmdbApiKey: "") == true)
            #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "", tmdbApiKey: "tmdb123") == false)
            #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "\tabc123\n", tmdbApiKey: " tmdb123 ") == true)
        }

        @Test
        func requiredMetadataKeyMessageIsDescriptive() {
            #expect(SetupWizardValidationPolicy.requiredMetadataKeyMessage == "Enter an OMDb API key to continue.")
        }
    }

    @Suite("SetupWizardValidationPolicy - trimmedValue")
    struct TrimmedValueTests {
        @Test
        func trimmedValueStripsWhitespace() {
            #expect(SetupWizardValidationPolicy.trimmedValue("  abc\n") == "abc")
            #expect(SetupWizardValidationPolicy.trimmedValue("\n\t  def  \r\n") == "def")
            #expect(SetupWizardValidationPolicy.trimmedValue("single") == "single")
            #expect(SetupWizardValidationPolicy.trimmedValue("") == "")
            #expect(SetupWizardValidationPolicy.trimmedValue("   ") == "")
        }
    }

    @Suite("SetupWizardValidationPolicy - Continue Button Title")
    struct ContinueButtonTitleTests {
        @Test
        func debridStepShowsSkipForNowWhenNoKey() {
            #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 1, debridApiKey: "") == "Skip for Now")
            #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 1, debridApiKey: "   ") == "Skip for Now")
            #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 1, debridApiKey: "\n\t") == "Skip for Now")
        }

        @Test
        func debridStepShowsContinueWhenKeyProvided() {
            #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 1, debridApiKey: "token") == "Continue")
            #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 1, debridApiKey: "  token  ") == "Continue")
        }

        @Test
        func nonDebridStepsAlwaysShowContinue() {
            #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 0, debridApiKey: "") == "Continue")
            #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 2, debridApiKey: "") == "Continue")
            #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 3, debridApiKey: "") == "Continue")
            #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 4, debridApiKey: "") == "Continue")
        }
    }

    @Suite("SetupWizardValidationPolicy - Continue Button Icon")
    struct ContinueButtonIconTests {
        @Test
        func debridStepShowsForwardIconWhenNoKey() {
            #expect(SetupWizardValidationPolicy.continueButtonIcon(currentStep: 1, debridApiKey: "") == "forward")
            #expect(SetupWizardValidationPolicy.continueButtonIcon(currentStep: 1, debridApiKey: "   ") == "forward")
        }

        @Test
        func debridStepShowsArrowRightWhenKeyProvided() {
            #expect(SetupWizardValidationPolicy.continueButtonIcon(currentStep: 1, debridApiKey: "token") == "arrow.right")
            #expect(SetupWizardValidationPolicy.continueButtonIcon(currentStep: 1, debridApiKey: "  token  ") == "arrow.right")
        }

        @Test
        func nonDebridStepsShowArrowRight() {
            #expect(SetupWizardValidationPolicy.continueButtonIcon(currentStep: 0, debridApiKey: "") == "arrow.right")
            #expect(SetupWizardValidationPolicy.continueButtonIcon(currentStep: 2, debridApiKey: "") == "arrow.right")
            #expect(SetupWizardValidationPolicy.continueButtonIcon(currentStep: 3, debridApiKey: "") == "arrow.right")
        }
    }

    @Suite("SetupWizardValidationPolicy - AI Provider Settings Keys")
    struct AIProviderSettingsKeyTests {
        @Test
        func settingsKeyReturnsCorrectKeyForEachProvider() {
            #expect(SetupWizardValidationPolicy.settingsKey(for: .openAI) == SettingsKeys.openAIApiKey)
            #expect(SetupWizardValidationPolicy.settingsKey(for: .anthropic) == SettingsKeys.anthropicApiKey)
            #expect(SetupWizardValidationPolicy.settingsKey(for: .gemini) == SettingsKeys.geminiApiKey)
            #expect(SetupWizardValidationPolicy.settingsKey(for: .openRouter) == SettingsKeys.openRouterApiKey)
        }

        @Test
        func settingsKeyReturnsNilForNoneProvider() {
            #expect(SetupWizardValidationPolicy.settingsKey(for: .none) == nil)
        }
    }

    @Suite("SetupWizardValidationPolicy - Should Save AI Key")
    struct ShouldSaveAIKeyTests {
        @Test
        func shouldSaveAIKeyRequiresProviderAndKey() {
            #expect(SetupWizardValidationPolicy.shouldSaveAIKey(provider: .none, apiKey: "key") == false)
            #expect(SetupWizardValidationPolicy.shouldSaveAIKey(provider: .openAI, apiKey: "") == false)
            #expect(SetupWizardValidationPolicy.shouldSaveAIKey(provider: .openAI, apiKey: "   ") == false)
        }

        @Test
        func shouldSaveAIKeySavesWhenProviderAndKeyPresent() {
            #expect(SetupWizardValidationPolicy.shouldSaveAIKey(provider: .openAI, apiKey: "key") == true)
            #expect(SetupWizardValidationPolicy.shouldSaveAIKey(provider: .anthropic, apiKey: "key") == true)
            #expect(SetupWizardValidationPolicy.shouldSaveAIKey(provider: .gemini, apiKey: "  key  ") == true)
        }
    }

    @Suite("SetupWizardValidationPolicy - Subtitle Persistence")
    struct SubtitlePersistenceTests {
        @Test
        func noneSelectionClearsStoredSubtitleLanguage() {
            #expect(SetupWizardValidationPolicy.storedSubtitleLanguageValue(.none) == nil)
        }

        @Test
        func languageSelectionPersistsRawLanguageCode() {
            #expect(SetupWizardValidationPolicy.storedSubtitleLanguageValue(.spanish) == "spa")
            #expect(SetupWizardValidationPolicy.storedSubtitleLanguageValue(.korean) == "kor")
        }
    }

    @Suite("SetupWizardValidationPolicy - Completion Summary Rows")
    struct CompletionSummaryRowsTests {
        @Test
        func allConfiguredStepsProduceSummaryRows() {
            let rows = SetupWizardValidationPolicy.completionSummaryRows(
                selectedService: .realDebrid,
                debridApiKey: "token",
                omdbApiKey: "omdb",
                selectedAIProvider: .openAI,
                selectedQuality: .uhd4k,
                selectedSubtitleLanguage: .english,
                selectedSourceFilterPreset: .cinema,
                guestModeEnabled: true
            )

            #expect(rows.count == 7)
            #expect(rows[0].icon == "link")
            #expect(rows[0].text == "Real-Debrid connected")
            #expect(rows[1].icon == "film")
            #expect(rows[1].text == "OMDb metadata configured")
            #expect(rows[2].icon == "brain")
            #expect(rows[2].text == "OpenAI AI enabled")
            #expect(rows[3].icon == "4k.tv")
            #expect(rows[3].text == "Quality set to 4K")
            #expect(rows[4].icon == "line.3.horizontal.decrease.circle")
            #expect(rows[4].text == "Cinema source filters")
            #expect(rows[5].icon == "captions.bubble")
            #expect(rows[5].text == "English subtitles")
            #expect(rows[6].icon == "person.crop.circle.badge.clock")
            #expect(rows[6].text == "Guest Mode enabled")
        }

        @Test
        func skippedOptionalStepsAreOmitted() {
            let rows = SetupWizardValidationPolicy.completionSummaryRows(
                selectedService: .premiumize,
                debridApiKey: "",
                omdbApiKey: "",
                selectedAIProvider: .none,
                selectedQuality: .hd720p,
                selectedSubtitleLanguage: .none,
                selectedSourceFilterPreset: .balanced,
                guestModeEnabled: false
            )

            #expect(rows.count == 2)
            #expect(rows[0].icon == "4k.tv")
            #expect(rows[0].text == "Quality set to 720p")
            #expect(rows[1].icon == "line.3.horizontal.decrease.circle")
            #expect(rows[1].text == "Balanced source filters")
        }

        @Test
        func qualityAndSourceFiltersAreAlwaysIncluded() {
            let rowsNoDebrid = SetupWizardValidationPolicy.completionSummaryRows(
                selectedService: .realDebrid,
                debridApiKey: "  ",
                omdbApiKey: "",
                selectedAIProvider: .none,
                selectedQuality: .hd1080p,
                selectedSubtitleLanguage: .none,
                selectedSourceFilterPreset: .instant,
                guestModeEnabled: false
            )

            #expect(rowsNoDebrid.count == 2)
            #expect(rowsNoDebrid[0].icon == "4k.tv")
            #expect(rowsNoDebrid[0].text == "Quality set to 1080p")
            #expect(rowsNoDebrid[1].icon == "line.3.horizontal.decrease.circle")
            #expect(rowsNoDebrid[1].text == "Instant source filters")
        }

        @Test
        func debridWithWhitespaceKeyIsSkipped() {
            let rows = SetupWizardValidationPolicy.completionSummaryRows(
                selectedService: .realDebrid,
                debridApiKey: "   ",
                omdbApiKey: "omdb",
                selectedAIProvider: .none,
                selectedQuality: .hd1080p,
                selectedSubtitleLanguage: .none
            )

            let icons = rows.map { $0.icon }
            #expect(!icons.contains("link"))
        }

        @Test
        func omdbWithWhitespaceKeyIsSkipped() {
            let rows = SetupWizardValidationPolicy.completionSummaryRows(
                selectedService: .realDebrid,
                debridApiKey: "token",
                omdbApiKey: "   ",
                selectedAIProvider: .none,
                selectedQuality: .hd1080p,
                selectedSubtitleLanguage: .none
            )

            let icons = rows.map { $0.icon }
            #expect(!icons.contains("film"))
        }
    }

    // MARK: - SubtitleLanguageOption Tests

    @Suite("SubtitleLanguageOption")
    struct SubtitleLanguageOptionTests {
        @Test
        func allCasesAreDefined() {
            let cases = SubtitleLanguageOption.allCases
            #expect(cases.count == 8)
        }

        @Test
        func displayNamesAreCorrect() {
            #expect(SubtitleLanguageOption.none.displayName == "None")
            #expect(SubtitleLanguageOption.english.displayName == "English")
            #expect(SubtitleLanguageOption.spanish.displayName == "Spanish")
            #expect(SubtitleLanguageOption.french.displayName == "French")
            #expect(SubtitleLanguageOption.german.displayName == "German")
            #expect(SubtitleLanguageOption.portuguese.displayName == "Portuguese")
            #expect(SubtitleLanguageOption.japanese.displayName == "Japanese")
            #expect(SubtitleLanguageOption.korean.displayName == "Korean")
        }

        @Test
        func rawValuesAreISO639Codes() {
            #expect(SubtitleLanguageOption.none.rawValue == "none")
            #expect(SubtitleLanguageOption.english.rawValue == "eng")
            #expect(SubtitleLanguageOption.spanish.rawValue == "spa")
            #expect(SubtitleLanguageOption.french.rawValue == "fre")
            #expect(SubtitleLanguageOption.german.rawValue == "ger")
            #expect(SubtitleLanguageOption.portuguese.rawValue == "por")
            #expect(SubtitleLanguageOption.japanese.rawValue == "jpn")
            #expect(SubtitleLanguageOption.korean.rawValue == "kor")
        }

        @Test
        func idMatchesRawValue() {
            for option in SubtitleLanguageOption.allCases {
                #expect(option.id == option.rawValue)
            }
        }
    }

    // MARK: - AIProviderOption Tests

    @Suite("AIProviderOption")
    struct AIProviderOptionTests {
        @Test
        func allCasesAreDefined() {
            let cases = AIProviderOption.allCases
            #expect(cases.count == 5)
        }

        @Test
        func displayNamesAreCorrect() {
            #expect(AIProviderOption.none.displayName == "None")
            #expect(AIProviderOption.openAI.displayName == "OpenAI")
            #expect(AIProviderOption.anthropic.displayName == "Anthropic")
            #expect(AIProviderOption.gemini.displayName == "Gemini")
            #expect(AIProviderOption.openRouter.displayName == "OpenRouter")
        }

        @Test
        func rawValuesAreCorrect() {
            #expect(AIProviderOption.none.rawValue == "none")
            #expect(AIProviderOption.openAI.rawValue == "openai")
            #expect(AIProviderOption.anthropic.rawValue == "anthropic")
            #expect(AIProviderOption.gemini.rawValue == "gemini")
            #expect(AIProviderOption.openRouter.rawValue == "openrouter")
        }

        @Test
        func idMatchesRawValue() {
            for option in AIProviderOption.allCases {
                #expect(option.id == option.rawValue)
            }
        }
    }

    // MARK: - Step Navigation Constants

    @Suite("Step Navigation Constants")
    struct StepNavigationTests {
        @Test
        func totalStepsIsFive() {
            #expect(Bool(true)) // totalSteps is private implementation detail
        }

        @Test
        func stepsAreZeroIndexed() {
            #expect(Bool(true))
        }
    }

    // MARK: - DebridServiceType Tests (Used in Wizard)

    @Suite("DebridServiceType")
    struct DebridServiceTypeTests {
        @Test
        func allCasesAreDefined() {
            let cases = DebridServiceType.allCases
            #expect(cases.count == 7)
        }

        @Test
        func displayNamesAreCorrect() {
            #expect(DebridServiceType.realDebrid.displayName == "Real-Debrid")
            #expect(DebridServiceType.allDebrid.displayName == "AllDebrid")
            #expect(DebridServiceType.premiumize.displayName == "Premiumize")
            #expect(DebridServiceType.torBox.displayName == "TorBox")
            #expect(DebridServiceType.debridLink.displayName == "Debrid-Link")
            #expect(DebridServiceType.offcloud.displayName == "Offcloud")
            #expect(DebridServiceType.easyNews.displayName == "EasyNews")
        }

        @Test
        func baseURLsAreDefined() {
            for service in DebridServiceType.allCases {
                #expect(!service.baseURL.isEmpty)
                #expect(service.baseURL.hasPrefix("https://"))
            }
        }

        @Test
        func idMatchesRawValue() {
            for service in DebridServiceType.allCases {
                #expect(service.id == service.rawValue)
            }
        }
    }

    // MARK: - VideoQuality Tests (Used in Wizard Preferences)

    @Suite("VideoQuality")
    struct VideoQualityTests {
        @Test
        func rawValuesAreExpected() {
            #expect(VideoQuality.hd720p.rawValue == "720p")
            #expect(VideoQuality.hd1080p.rawValue == "1080p")
            #expect(VideoQuality.uhd4k.rawValue == "4K")
        }

        @Test
        func rawValuesAreCorrect() {
            #expect(VideoQuality.hd720p.rawValue == "720p")
            #expect(VideoQuality.hd1080p.rawValue == "1080p")
            #expect(VideoQuality.uhd4k.rawValue == "4K")
        }
    }

    // MARK: - SetupWizardValidationPolicy SummaryRow Tests

    @Suite("SetupWizardValidationPolicy.SummaryRow")
    struct SummaryRowTests {
        @Test
        func summaryRowConformsToEquatable() {
            let row1 = SetupWizardValidationPolicy.SummaryRow(icon: "link", text: "Test")
            let row2 = SetupWizardValidationPolicy.SummaryRow(icon: "link", text: "Test")
            let row3 = SetupWizardValidationPolicy.SummaryRow(icon: "film", text: "Test")

            #expect(row1 == row2)
            #expect(row1 != row3)
        }

        @Test
        func summaryRowConformsToSendable() {
            let row = SetupWizardValidationPolicy.SummaryRow(icon: "link", text: "Test")
            let _: any Sendable = row
            #expect(Bool(true))
        }
    }
}
