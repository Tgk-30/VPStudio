import Testing
@testable import VPStudio

struct VPMenuBackgroundIntensityPolicyTestsVpmenubackgroundintensitypolicytests {
    @Test func constantsExposeExpectedStorageAndRange() {
        #expect(VPMenuBackgroundIntensityPolicy.appStorageKey == "settings.menu_background_intensity")
        #expect(VPMenuBackgroundIntensityPolicy.defaultValue == 1.0)
        #expect(VPMenuBackgroundIntensityPolicy.minValue == 0.0)
        #expect(VPMenuBackgroundIntensityPolicy.maxValue == 1.0)
        #expect(VPMenuBackgroundIntensityPolicy.range == 0.0...1.0)
    }

    @Test func clampReturnsMinForLowerValues() {
        let clamped = VPMenuBackgroundIntensityPolicy.clamped(-0.5)
        #expect(clamped == VPMenuBackgroundIntensityPolicy.minValue)
    }

    @Test func clampReturnsMaxForHigherValues() {
        let clamped = VPMenuBackgroundIntensityPolicy.clamped(2.0)
        #expect(clamped == VPMenuBackgroundIntensityPolicy.maxValue)
    }

    @Test func clampPassesThroughInRangeValues() {
        let value = 0.42
        let clamped = VPMenuBackgroundIntensityPolicy.clamped(value)
        #expect(clamped == value)
    }

    @Test func percentageLabelUsesClampedValue() {
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: -1.0) == "0%")
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 1.0) == "100%")
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 2.0) == "100%")
    }

    @Test func percentageLabelRoundsToNearestPercent() {
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 0.424) == "42%")
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 0.425) == "43%")
    }
}
