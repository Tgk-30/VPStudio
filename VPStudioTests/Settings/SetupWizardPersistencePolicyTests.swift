import Testing
@testable import VPStudio

@Suite("SetupWizardPersistencePolicy")
struct SetupWizardPersistencePolicyTests {
    @Test
    func metadataSavePlanRequiresTrimmedTMDBKey() {
        let decision = SetupWizardPersistencePolicy.metadataSavePlan(
            tmdbApiKey: " \n ",
            selectedAIProvider: .openAI,
            aiApiKey: " key "
        )

        #expect(decision == .invalid(message: SetupWizardValidationPolicy.requiredTMDBMessage))
    }

    @Test
    func metadataSavePlanSkipsDefaultAIProviderWhenNoneSelected() throws {
        let decision = SetupWizardPersistencePolicy.metadataSavePlan(
            tmdbApiKey: " tmdb-key ",
            selectedAIProvider: .none,
            aiApiKey: " ignored "
        )
        let plan = try #require(savePlan(from: decision))

        #expect(plan.tmdbApiKey == "tmdb-key")
        #expect(plan.defaultAIProviderRawValue == nil)
        #expect(plan.aiKeyWrite == nil)
    }

    @Test
    func metadataSavePlanSavesAIKeyOnlyWhenProviderAndTrimmedKeyPresent() throws {
        let decision = SetupWizardPersistencePolicy.metadataSavePlan(
            tmdbApiKey: "\ttmdb\n",
            selectedAIProvider: .openRouter,
            aiApiKey: " router-key "
        )
        let plan = try #require(savePlan(from: decision))

        #expect(plan.tmdbApiKey == "tmdb")
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
            tmdbApiKey: "tmdb",
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
            selectedSubtitleLanguage: .none
        )

        #expect(plan.preferredQualityRawValue == VideoQuality.uhd4k.rawValue)
        #expect(plan.subtitleLanguageValue == nil)
    }

    @Test
    func preferencesSavePlanPersistsSelectedSubtitleLanguage() {
        let plan = SetupWizardPersistencePolicy.preferencesSavePlan(
            selectedQuality: .hd720p,
            selectedSubtitleLanguage: .japanese
        )

        #expect(plan.preferredQualityRawValue == VideoQuality.hd720p.rawValue)
        #expect(plan.subtitleLanguageValue == "jpn")
    }

    private func savePlan(
        from decision: SetupWizardPersistencePolicy.MetadataDecision
    ) -> SetupWizardPersistencePolicy.MetadataSavePlan? {
        guard case .save(let plan) = decision else { return nil }
        return plan
    }
}
