import Testing
@testable import VPStudio

@Suite("SubtitleSettingsPolicy")
struct SubtitleSettingsPolicyTests {
    @Test
    func resolvedLanguageFallsBackToEnglishForMissingOrBlankValues() {
        #expect(SubtitleSettingsPolicy.resolvedLanguage(nil) == "en")
        #expect(SubtitleSettingsPolicy.resolvedLanguage("") == "en")
        #expect(SubtitleSettingsPolicy.resolvedLanguage(" \n\t ") == "en")
    }

    @Test
    func resolvedLanguageTrimsWhitespaceForStoredValues() {
        #expect(SubtitleSettingsPolicy.resolvedLanguage("  es  ") == "es")
        #expect(SubtitleSettingsPolicy.resolvedLanguage("fr") == "fr")
    }

    @Test
    func resolvedAutoSearchUsesStoredValueOrDefault() {
        #expect(SubtitleSettingsPolicy.resolvedAutoSearch(true))
        #expect(SubtitleSettingsPolicy.resolvedAutoSearch(false) == false)
        #expect(SubtitleSettingsPolicy.resolvedAutoSearch(nil))
    }

    @Test
    func resolvedFontSizeUsesDefaultForMissingOrInvalidValues() {
        #expect(SubtitleSettingsPolicy.resolvedFontSize(nil) == 24)
        #expect(SubtitleSettingsPolicy.resolvedFontSize("") == 24)
        #expect(SubtitleSettingsPolicy.resolvedFontSize("not-a-number") == 24)
    }

    @Test
    func resolvedFontSizeClampsToAllowedRange() {
        #expect(SubtitleSettingsPolicy.resolvedFontSize("12") == 16)
        #expect(SubtitleSettingsPolicy.resolvedFontSize("16") == 16)
        #expect(SubtitleSettingsPolicy.resolvedFontSize("24") == 24)
        #expect(SubtitleSettingsPolicy.resolvedFontSize("48") == 48)
        #expect(SubtitleSettingsPolicy.resolvedFontSize("60") == 48)
        #expect(SubtitleSettingsPolicy.resolvedFontSize("20.5") == 20.5)
        #expect(SubtitleSettingsPolicy.resolvedFontSize(" 30 ") == 30)
    }
}
