import Foundation
import Testing
@testable import VPStudio

@Suite("SetupWizardValidationPolicy")
struct SetupWizardValidationPolicyTests {
    @Test
    func metadataKeyIsRequiredToContinueFromMetadataStep() {
        #expect(SetupWizardValidationPolicy.trimmedValue("  abc\n") == "abc")
        #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "   ", tmdbApiKey: "") == false)
        #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "\n\t", tmdbApiKey: " \r") == false)
        #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "abcd", tmdbApiKey: "") == true)
        #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "", tmdbApiKey: "tmdb") == false)
        #expect(SetupWizardValidationPolicy.canContinueFromMetadataStep(omdbApiKey: "omdb", tmdbApiKey: "tmdb") == true)
        #expect(SetupWizardValidationPolicy.requiredMetadataKeyMessage == "Enter an OMDb API key to continue.")
    }

    @Test
    func metadataStepCopyMatchesPlanAwareProviderBehavior() throws {
        let source = try setupWizardSource()

        #expect(source.contains("Enter an OMDb key for metadata"))
        #expect(source.contains("TMDb is optional legacy fallback only"))
        #expect(source.contains("TMDb adds richer artwork, backdrops, banners, and discovery.") == false)
    }

    @Test
    func setupWizardErrorPresentationRedactsSensitiveProviderFailures() {
        let redacted = SetupWizardErrorPresentationPolicy.displayMessage(
            for: SecretBearingSetupWizardError()
        )

        #expect(redacted.contains("REDACTED"))
        #expect(!redacted.contains("omdb-secret-token"))
        #expect(!redacted.contains("tmdb-secret-token"))
        #expect(!redacted.contains("vpstudioBearerSecretToken123456"))
        #expect(!redacted.contains("provider-client-secret-1234567890"))
    }

    @Test
    func setupWizardAIOffersCurrentCloudProviders() {
        let offeredProviders = Set(AIProviderOption.allCases)
        #expect(offeredProviders.contains(.none))
        #expect(offeredProviders.contains(.openAI))
        #expect(offeredProviders.contains(.anthropic))
        #expect(offeredProviders.contains(.gemini))
        #expect(offeredProviders.contains(.openRouter))
    }

    @Test
    func debridStepSkipsWhenNoTokenWasEntered() {
        #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 1, debridApiKey: "   ") == "Skip for Now")
        #expect(SetupWizardValidationPolicy.continueButtonIcon(currentStep: 1, debridApiKey: "\n\t") == "forward")

        #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 1, debridApiKey: "token") == "Continue")
        #expect(SetupWizardValidationPolicy.continueButtonIcon(currentStep: 1, debridApiKey: "token") == "arrow.right")
        #expect(SetupWizardValidationPolicy.continueButtonTitle(currentStep: 2, debridApiKey: "") == "Continue")
    }

    @Test
    func aiProviderSettingsKeysMatchSettingsStorage() {
        #expect(SetupWizardValidationPolicy.settingsKey(for: .none) == nil)
        #expect(SetupWizardValidationPolicy.settingsKey(for: .openAI) == SettingsKeys.openAIApiKey)
        #expect(SetupWizardValidationPolicy.settingsKey(for: .anthropic) == SettingsKeys.anthropicApiKey)
        #expect(SetupWizardValidationPolicy.settingsKey(for: .gemini) == SettingsKeys.geminiApiKey)
        #expect(SetupWizardValidationPolicy.settingsKey(for: .openRouter) == SettingsKeys.openRouterApiKey)

        #expect(!SetupWizardValidationPolicy.shouldSaveAIKey(provider: .openAI, apiKey: "   "))
        #expect(!SetupWizardValidationPolicy.shouldSaveAIKey(provider: .none, apiKey: "key"))
        #expect(SetupWizardValidationPolicy.shouldSaveAIKey(provider: .gemini, apiKey: " key "))
    }

    @Test
    func subtitleLanguagePersistenceClearsWhenNoneSelected() {
        #expect(SetupWizardValidationPolicy.storedSubtitleLanguageValue(.none) == nil)
        #expect(SetupWizardValidationPolicy.storedSubtitleLanguageValue(.english) == "eng")
        #expect(SetupWizardValidationPolicy.storedSubtitleLanguageValue(.japanese) == "jpn")
    }

    @Test
    func completionSummaryRowsReflectConfiguredOptionalSteps() {
        let rows = SetupWizardValidationPolicy.completionSummaryRows(
            selectedService: .realDebrid,
            debridApiKey: " token ",
            omdbApiKey: " omdb ",
            selectedAIProvider: .openRouter,
            selectedQuality: .uhd4k,
            selectedSubtitleLanguage: .english,
            selectedSourceFilterPreset: .cinema,
            guestModeEnabled: true
        )

        #expect(rows == [
            SetupWizardValidationPolicy.SummaryRow(icon: "link", text: "Real-Debrid connected"),
            SetupWizardValidationPolicy.SummaryRow(icon: "film", text: "OMDb metadata configured"),
            SetupWizardValidationPolicy.SummaryRow(icon: "brain", text: "OpenRouter AI enabled"),
            SetupWizardValidationPolicy.SummaryRow(icon: "4k.tv", text: "Quality set to 4K"),
            SetupWizardValidationPolicy.SummaryRow(icon: "line.3.horizontal.decrease.circle", text: "Cinema source filters"),
            SetupWizardValidationPolicy.SummaryRow(icon: "captions.bubble", text: "English subtitles"),
            SetupWizardValidationPolicy.SummaryRow(icon: "person.crop.circle.badge.clock", text: "Guest Mode enabled"),
        ])
    }

    @Test
    func completionSummaryRowsMentionPaidMetadataPlansWhenConfigured() {
        let rows = SetupWizardValidationPolicy.completionSummaryRows(
            selectedService: .realDebrid,
            debridApiKey: "",
            omdbApiKey: "omdb",
            tmdbApiKey: "tmdb",
            omdbPlan: .paid,
            tmdbPlan: .paid,
            selectedAIProvider: .none,
            selectedQuality: .hd1080p,
            selectedSubtitleLanguage: .none
        )

        #expect(rows.contains(.init(icon: "photo.on.rectangle.angled", text: "OMDb paid artwork enabled")))
        #expect(rows.contains(.init(icon: "photo.stack", text: "TMDb expanded artwork enabled")))
    }

    @Test
    func completionSummaryRowsOmitSkippedOptionalStepsButAlwaysIncludeQuality() {
        let rows = SetupWizardValidationPolicy.completionSummaryRows(
            selectedService: .premiumize,
            debridApiKey: "   ",
            omdbApiKey: "",
            selectedAIProvider: .none,
            selectedQuality: .hd1080p,
            selectedSubtitleLanguage: .none,
            selectedSourceFilterPreset: .balanced,
            guestModeEnabled: false
        )

        #expect(rows == [
            SetupWizardValidationPolicy.SummaryRow(icon: "4k.tv", text: "Quality set to 1080p"),
            SetupWizardValidationPolicy.SummaryRow(icon: "line.3.horizontal.decrease.circle", text: "Balanced source filters"),
        ])
    }

    private func setupWizardSource() throws -> String {
        let absolutePath = setupWizardRepoRoot()
            .appendingPathComponent("VPStudio/Views/Windows/Settings/Onboarding/SetupWizardView.swift")
            .path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
    }

    private func setupWizardRepoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }
}

private struct SecretBearingSetupWizardError: LocalizedError {
    var errorDescription: String? {
        "Metadata save failed for https://api.example.com/title?apikey=omdb-secret-token&token=tmdb-secret-token Authorization: Bearer vpstudioBearerSecretToken123456 clientSecret=provider-client-secret-1234567890"
    }
}
