import Testing
@testable import VPStudio

@Suite("MetadataSettingsPolicy")
struct MetadataSettingsPolicyTests {
    @Test
    func normalizedAPIKeyTrimsWhitespaceAndRejectsBlankValues() {
        #expect(MetadataSettingsPolicy.normalizedAPIKey("  omdb-key  ") == "omdb-key")
        #expect(MetadataSettingsPolicy.normalizedAPIKey("\n\t  ") == nil)
    }

    @Test
    func unsavedAPIKeyChangeUsesNormalizedValues() {
        #expect(
            MetadataSettingsPolicy.hasUnsavedAPIKeyChange(
                current: "  omdb-key ",
                baseline: "omdb-key"
            ) == false
        )
        #expect(
            MetadataSettingsPolicy.hasUnsavedAPIKeyChange(
                current: "",
                baseline: "omdb-key"
            )
        )
    }

    @Test
    func savedStateInvalidationOnlyTriggersForNormalizedEdits() {
        #expect(
            MetadataSettingsPolicy.shouldInvalidateSavedState(
                newValue: "  omdb-key  ",
                baseline: "omdb-key"
            ) == false
        )
        #expect(
            MetadataSettingsPolicy.shouldInvalidateSavedState(
                newValue: "omdb-key-updated",
                baseline: "omdb-key"
            )
        )
    }

    @Test
    func loadedStateNormalizesPersistedKeyAndMarksOnlyNonEmptyKeysSaved() {
        let saved = MetadataSettingsPolicy.loadedState(for: "  omdb-key  ")
        #expect(saved.visibleValue == "omdb-key")
        #expect(saved.baselineValue == "omdb-key")
        #expect(saved.isSaved)

        let missing = MetadataSettingsPolicy.loadedState(for: "   ")
        #expect(missing.visibleValue.isEmpty)
        #expect(missing.baselineValue.isEmpty)
        #expect(missing.isSaved == false)

        let absent = MetadataSettingsPolicy.loadedState(for: nil)
        #expect(absent.visibleValue.isEmpty)
        #expect(absent.baselineValue.isEmpty)
        #expect(absent.isSaved == false)
    }

    @Test
    func savePresentationMarksDeletedKeyAsRemovedNotSaved() {
        let removed = MetadataSettingsPolicy.savePresentation(for: nil)
        #expect(removed.visibleValue.isEmpty)
        #expect(removed.baselineValue.isEmpty)
        #expect(removed.isSaved == false)
        #expect(removed.noticeMessage == MetadataSettingsPolicy.removedMessage)
        #expect(removed.noticeTone == .success)
        #expect(removed.notice.message == MetadataSettingsPolicy.removedMessage)
    }

    @Test
    func savePresentationMarksNonEmptyKeyAsSaved() {
        let saved = MetadataSettingsPolicy.savePresentation(for: "omdb-key")
        #expect(saved.visibleValue == "omdb-key")
        #expect(saved.baselineValue == "omdb-key")
        #expect(saved.isSaved)
        #expect(saved.noticeMessage == MetadataSettingsPolicy.savedMessage)
        #expect(saved.noticeTone == .success)
    }

    @Test
    func savePresentationNoticeMapsInfoAndWarningTones() {
        let info = MetadataSettingsPolicy.SavePresentation(
            visibleValue: "",
            baselineValue: "",
            isSaved: false,
            noticeMessage: "Informational update",
            noticeTone: .info
        ).notice

        let warning = MetadataSettingsPolicy.SavePresentation(
            visibleValue: "",
            baselineValue: "",
            isSaved: false,
            noticeMessage: "Needs attention",
            noticeTone: .warning
        ).notice

        #expect(info.message == "Informational update")
        #expect(info.tone == .info)
        #expect(warning.message == "Needs attention")
        #expect(warning.tone == .warning)
    }

    @Test
    func missingAPIKeyNoticeUsesWarningTone() {
        let notice = MetadataSettingsPolicy.missingAPIKeyNotice
        #expect(notice.message == MetadataSettingsPolicy.missingKeyMessage)
        #expect(notice.tone == .warning)
        #expect(notice.symbolName == "exclamationmark.triangle.fill")
    }

    @Test
    func validationFailureFallbackMessageStaysUserFacing() {
        #expect(MetadataSettingsPolicy.validationFailureFallbackMessage == "OMDb validation failed.")
        #expect(MetadataSettingsPolicy.validationProbeIMDbID == "tt0111161")
    }
}
