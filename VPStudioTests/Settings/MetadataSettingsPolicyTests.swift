import Foundation
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
    func planChangesCountAsUnsavedMetadataConfigurationChanges() {
        #expect(
            MetadataSettingsPolicy.hasUnsavedConfigurationChange(
                currentOMDb: "omdb",
                baselineOMDb: " omdb ",
                currentOMDbPlan: .free,
                baselineOMDbPlan: .free,
                currentTMDb: "",
                baselineTMDb: "",
                currentTMDbPlan: .paid,
                baselineTMDbPlan: .free
            )
        )
        #expect(
            MetadataSettingsPolicy.hasUnsavedConfigurationChange(
                currentOMDb: "omdb",
                baselineOMDb: " omdb ",
                currentOMDbPlan: .free,
                baselineOMDbPlan: .free,
                currentTMDb: "",
                baselineTMDb: "",
                currentTMDbPlan: .free,
                baselineTMDbPlan: .free
            ) == false
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
    func saveNoticeKeepsTMDbOnlyAsLegacyFallbackWarning() {
        let tmdbOnly = MetadataSettingsPolicy.saveNotice(
            for: MetadataProviderConfiguration(tmdbApiKey: "tmdb")
        )
        let omdbReady = MetadataSettingsPolicy.saveNotice(
            for: MetadataProviderConfiguration(omdbApiKey: "omdb", tmdbApiKey: "tmdb")
        )

        #expect(tmdbOnly.tone == .warning)
        #expect(tmdbOnly.message == MetadataSettingsPolicy.legacyFallbackSavedMessage)
        #expect(omdbReady.tone == .success)
        #expect(omdbReady.message == MetadataSettingsPolicy.savedMessage)
    }

    @Test
    func validationFailureFallbackMessageStaysUserFacing() {
        #expect(MetadataSettingsPolicy.validationFailureFallbackMessage == "Metadata validation failed.")
        #expect(MetadataSettingsPolicy.validationProbeIMDbID == "tt0111161")
    }

    @Test
    func validationMessagesReportProviderSpecificResults() {
        #expect(
            MetadataSettingsPolicy.validationSuccessMessage(providerNames: ["OMDb", "Legacy TMDb fallback"])
                == "OMDb + Legacy TMDb fallback metadata is valid."
        )
        #expect(
            MetadataSettingsPolicy.partialValidationWarningMessage(
                validProviderNames: ["OMDb"],
                failedProviderNames: ["TMDb"]
            ) == "OMDb valid. TMDb failed validation. The valid provider will still be used."
        )
        #expect(
            MetadataSettingsPolicy.partialValidationWarningMessage(
                validProviderNames: ["TMDb"],
                failedProviderNames: ["OMDb"],
                failureDescription: "Invalid metadata API key"
            ) == "TMDb valid. OMDb failed validation. Invalid metadata API key. The valid provider will still be used."
        )
        #expect(MetadataSettingsPolicy.omdbAPIKeyURL.absoluteString == "https://www.omdbapi.com/apikey.aspx")
        #expect(MetadataSettingsPolicy.tmdbAPIKeyURL.absoluteString == "https://www.themoviedb.org/settings/api")
        #expect(MetadataSettingsPolicy.omdbPlanDescription(for: .free).contains("Poster API is patron-only"))
        #expect(MetadataSettingsPolicy.omdbPlanDescription(for: .paid).contains("patron-only OMDb image resources"))
        #expect(MetadataSettingsPolicy.omdbPlanDescription(for: .paid).contains("do not embed API keys"))
        #expect(MetadataSettingsPolicy.tmdbPlanDescription(for: .paid).contains("expanded TMDb image"))
        #expect(MetadataSettingsPolicy.legacyFallbackValidationMessage.contains("Legacy TMDb fallback is valid"))
    }

    @Test
    func validationFailureDescriptionRedactsSensitiveProviderErrors() {
        let redacted = MetadataSettingsPolicy.validationFailureDescription(
            for: SecretBearingMetadataValidationError()
        )

        #expect(redacted.contains("REDACTED"))
        #expect(!redacted.contains("omdb-validation-secret"))
        #expect(!redacted.contains("tmdb-validation-secret"))
        #expect(!redacted.contains("metadata-client-secret-1234567890"))
    }

    @Test
    func providerPrecedenceMessageMatchesRuntimeProviderMode() {
        #expect(
            MetadataSettingsPolicy.providerPrecedenceMessage(for: MetadataProviderConfiguration())
                == "Add an OMDb key to enable metadata, ratings, search, and sync identity. TMDb is only a legacy fallback."
        )
        #expect(
            MetadataSettingsPolicy.providerPrecedenceMessage(for: MetadataProviderConfiguration(omdbApiKey: "omdb"))
                .contains("OMDb powers IMDb lookup")
        )
        #expect(
            MetadataSettingsPolicy.providerPrecedenceMessage(for: MetadataProviderConfiguration(omdbApiKey: "omdb"))
                .contains("keyless artwork URLs")
        )
        #expect(
            MetadataSettingsPolicy.providerPrecedenceMessage(for: MetadataProviderConfiguration(tmdbApiKey: "tmdb"))
                .contains("Only a legacy TMDb key is configured")
        )
        #expect(
            MetadataSettingsPolicy.providerPrecedenceMessage(
                for: MetadataProviderConfiguration(
                    omdbApiKey: "omdb",
                    tmdbApiKey: "tmdb",
                    omdbPlan: .paid,
                    tmdbPlan: .free
                )
            ).contains("OMDb leads metadata")
        )
        #expect(
            MetadataSettingsPolicy.providerPrecedenceMessage(
                for: MetadataProviderConfiguration(
                    omdbApiKey: "omdb",
                    tmdbApiKey: "tmdb",
                    omdbPlan: .paid,
                    tmdbPlan: .paid
                )
            ).contains("compatibility fallback")
        )
    }

    @Test
    func validationErrorsOnlyBlockWhenEveryConfiguredProviderFails() {
        #expect(
            MetadataSettingsPolicy.shouldSurfaceBlockingValidationError(
                validProviderCount: 0,
                failedProviderCount: 1
            )
        )
        #expect(
            MetadataSettingsPolicy.shouldSurfaceBlockingValidationError(
                validProviderCount: 0,
                failedProviderCount: 2
            )
        )
        #expect(
            !MetadataSettingsPolicy.shouldSurfaceBlockingValidationError(
                validProviderCount: 1,
                failedProviderCount: 1
            )
        )
        #expect(
            !MetadataSettingsPolicy.shouldSurfaceBlockingValidationError(
                validProviderCount: 1,
                failedProviderCount: 0
            )
        )
    }

    @Test
    func providerCardLayoutTokensStayReadableForVisionOS() {
        #expect(MetadataSettingsPolicy.apiKeyFieldMinHeight >= 46)
        #expect(MetadataSettingsPolicy.planOptionMinHeight >= 36)
        #expect(MetadataSettingsPolicy.footerActionMinHeight >= 40)
        #expect(MetadataSettingsPolicy.providerCardContentSpacing >= 14)
    }
}

private struct SecretBearingMetadataValidationError: LocalizedError {
    var errorDescription: String? {
        "Metadata validation failed for https://api.example.com/title?apikey=omdb-validation-secret&token=tmdb-validation-secret clientSecret=metadata-client-secret-1234567890"
    }
}
