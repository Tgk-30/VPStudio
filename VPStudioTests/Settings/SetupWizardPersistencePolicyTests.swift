import Testing
@testable import VPStudio

@Suite("SetupWizardPersistencePolicy")
struct SetupWizardPersistencePolicyTests {
    @Test
    func metadataSavePlanRequiresTrimmedOMDbKey() {
        let decision = SetupWizardPersistencePolicy.metadataSavePlan(
            omdbApiKey: " \n ",
            selectedAIProvider: .openAI,
            aiApiKey: " key "
        )

        #expect(decision == .invalid(message: SetupWizardValidationPolicy.requiredOMDbMessage))
    }

    @Test
    func metadataSavePlanSkipsDefaultAIProviderWhenNoneSelected() throws {
        let decision = SetupWizardPersistencePolicy.metadataSavePlan(
            omdbApiKey: " omdb-key ",
            selectedAIProvider: .none,
            aiApiKey: " ignored "
        )
        let plan = try #require(savePlan(from: decision))

        #expect(plan.omdbApiKey == "omdb-key")
        #expect(plan.defaultAIProviderRawValue == nil)
        #expect(plan.aiKeyWrite == nil)
    }

    @Test
    func metadataSavePlanSavesAIKeyOnlyWhenProviderAndTrimmedKeyPresent() throws {
        let decision = SetupWizardPersistencePolicy.metadataSavePlan(
            omdbApiKey: "\tomdb\n",
            selectedAIProvider: .openRouter,
            aiApiKey: " router-key "
        )
        let plan = try #require(savePlan(from: decision))

        #expect(plan.omdbApiKey == "omdb")
        #expect(plan.defaultAIProviderRawValue == AIProviderOption.openRouter.rawValue)
        #expect(
            plan.aiKeyWrite == SetupWizardPersistencePolicy.AIKeyWrite(
                settingsKey: SettingsKeys.openRouterApiKey,
                apiKey: "router-key"
            )
        )
    }

    @Test
    func metadataSavePlanOmitsBlankAIKeyEvenWhenProviderSelected() throws {
        let decision = SetupWizardPersistencePolicy.metadataSavePlan(
            omdbApiKey: "omdb",
            selectedAIProvider: .gemini,
            aiApiKey: "  "
        )
        let plan = try #require(savePlan(from: decision))

        #expect(plan.defaultAIProviderRawValue == AIProviderOption.gemini.rawValue)
        #expect(plan.aiKeyWrite == nil)
    }

    @Test
    func preferencesSavePlanClearsSubtitleLanguageWhenNoneSelected() {
        let plan = SetupWizardPersistencePolicy.preferencesSavePlan(
            selectedQuality: .uhd4k,
            selectedSubtitleLanguage: .none,
            selectedSourceFilterPreset: .cinema,
            guestModeEnabled: true
        )

        #expect(plan.preferredQualityRawValue == VideoQuality.uhd4k.rawValue)
        #expect(plan.subtitleLanguageValue == nil)
        #expect(plan.sourceFilterPresetRawValue == SourceFilterPreset.cinema.rawValue)
        #expect(plan.guestModeEnabled)
    }

    @Test
    func preferencesSavePlanPersistsSelectedSubtitleLanguage() {
        let plan = SetupWizardPersistencePolicy.preferencesSavePlan(
            selectedQuality: .hd720p,
            selectedSubtitleLanguage: .japanese,
            selectedSourceFilterPreset: .instant,
            guestModeEnabled: false
        )

        #expect(plan.preferredQualityRawValue == VideoQuality.hd720p.rawValue)
        #expect(plan.subtitleLanguageValue == "jpn")
        #expect(plan.sourceFilterPresetRawValue == SourceFilterPreset.instant.rawValue)
        #expect(plan.guestModeEnabled == false)
    }

    @Test
    func preferencesSavePlanDefaultsToBalancedSourceFiltersAndGuestModeOff() {
        let plan = SetupWizardPersistencePolicy.preferencesSavePlan(
            selectedQuality: .hd1080p,
            selectedSubtitleLanguage: .english
        )

        #expect(plan.preferredQualityRawValue == VideoQuality.hd1080p.rawValue)
        #expect(plan.subtitleLanguageValue == "eng")
        #expect(plan.sourceFilterPresetRawValue == SourceFilterPreset.balanced.rawValue)
        #expect(plan.guestModeEnabled == false)
    }

    private func savePlan(
        from decision: SetupWizardPersistencePolicy.MetadataDecision
    ) -> SetupWizardPersistencePolicy.MetadataSavePlan? {
        guard case .save(let plan) = decision else { return nil }
        return plan
    }
}
