import Testing
@testable import VPStudio

@Suite("Personalized Recs Gate Policy")
struct PersonalizedRecsGatePolicyTests {
    @Test
    func enabledOnlyWhenTokenPresentAndHistorySyncOn() {
        #expect(PersonalizedRecsGatePolicy.isEnabled(hasTraktToken: true, historySyncEnabled: true))
    }

    @Test
    func disabledWithoutTraktToken() {
        #expect(!PersonalizedRecsGatePolicy.isEnabled(hasTraktToken: false, historySyncEnabled: true))
    }

    @Test
    func disabledWhenHistorySyncOff() {
        #expect(!PersonalizedRecsGatePolicy.isEnabled(hasTraktToken: true, historySyncEnabled: false))
    }

    @Test
    func disabledWhenNeitherConditionMet() {
        #expect(!PersonalizedRecsGatePolicy.isEnabled(hasTraktToken: false, historySyncEnabled: false))
    }
}
