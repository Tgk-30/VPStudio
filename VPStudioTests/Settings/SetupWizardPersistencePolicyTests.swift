import Testing
@testable import VPStudio

@Suite("SetupWizardPersistencePolicy")
struct SetupWizardPersistencePolicyTests {
    @Test
    func metadataSavePlanRequiresOneTrimmedMetadataKey() {
        let decision = SetupWizardPersistencePolicy.metadataSavePlan(
            omdbApiKey: " \n ",
            tmdbApiKey: " \t ",
            selectedAIProvider: .openAI,
            aiApiKey: " key "
        )

        #expect(decision == .invalid(message: SetupWizardValidationPolicy.requiredMetadataKeyMessage))
    }

    @Test
    func metadataSavePlanRejectsTMDbOnlyConfiguration() {
        let decision = SetupWizardPersistencePolicy.metadataSavePlan(
            omdbApiKey: " \n ",
            tmdbApiKey: " tmdb-key ",
            selectedAIProvider: .none,
            aiApiKey: ""
        )

        #expect(decision == .invalid(message: SetupWizardValidationPolicy.requiredMetadataKeyMessage))
    }

    @Test
    func metadataSavePlanPersistsSelectedProviderPlans() throws {
        let decision = SetupWizardPersistencePolicy.metadataSavePlan(
            omdbApiKey: " omdb-key ",
            tmdbApiKey: " tmdb-key ",
            omdbPlan: .paid,
            tmdbPlan: .paid,
            selectedAIProvider: .none,
            aiApiKey: ""
        )
        let plan = try #require(savePlan(from: decision))

        #expect(plan.omdbApiKey == "omdb-key")
        #expect(plan.tmdbApiKey == "tmdb-key")
        #expect(plan.omdbPlanRawValue == MetadataProviderPlan.paid.rawValue)
        #expect(plan.tmdbPlanRawValue == MetadataProviderPlan.paid.rawValue)
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
        #expect(plan.tmdbApiKey == "")
        #expect(plan.omdbPlanRawValue == MetadataProviderPlan.free.rawValue)
        #expect(plan.tmdbPlanRawValue == MetadataProviderPlan.free.rawValue)
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
