import Testing
@testable import VPStudio

@Suite("VPMenuBackgroundIntensityPolicy Constants")
struct VPMenuBackgroundIntensityPolicyTests {
    @Test("App storage key")
    func appStorageKey() {
        #expect(VPMenuBackgroundIntensityPolicy.appStorageKey == "settings.menu_background_intensity")
    }

    @Test("Default value")
    func defaultValue() {
        #expect(VPMenuBackgroundIntensityPolicy.defaultValue == 1.0)
    }

    @Test("Min value")
    func minValue() {
        #expect(VPMenuBackgroundIntensityPolicy.minValue == 0.0)
    }

    @Test("Max value")
    func maxValue() {
        #expect(VPMenuBackgroundIntensityPolicy.maxValue == 1.0)
    }

    @Test("Range bounds")
    func rangeBounds() {
        #expect(VPMenuBackgroundIntensityPolicy.range.lowerBound == 0.0)
        #expect(VPMenuBackgroundIntensityPolicy.range.upperBound == 1.0)
    }

    @Test("Default is at max")
    func defaultAtMax() {
        #expect(VPMenuBackgroundIntensityPolicy.defaultValue == VPMenuBackgroundIntensityPolicy.maxValue)
    }
}

@Suite("VPMenuBackgroundIntensityPolicy Clamping")
struct VPMenuBackgroundIntensityPolicyClampingTests {
    @Test("Value within range returns unchanged")
    func valueWithinRange() {
        #expect(VPMenuBackgroundIntensityPolicy.clamped(0.5) == 0.5)
        #expect(VPMenuBackgroundIntensityPolicy.clamped(0.0) == 0.0)
        #expect(VPMenuBackgroundIntensityPolicy.clamped(1.0) == 1.0)
    }

    @Test("Value below min returns min")
    func valueBelowMin() {
        #expect(VPMenuBackgroundIntensityPolicy.clamped(-0.5) == 0.0)
        #expect(VPMenuBackgroundIntensityPolicy.clamped(-1.0) == 0.0)
    }

    @Test("Value above max returns max")
    func valueAboveMax() {
        #expect(VPMenuBackgroundIntensityPolicy.clamped(1.5) == 1.0)
        #expect(VPMenuBackgroundIntensityPolicy.clamped(2.0) == 1.0)
    }

    @Test("Clamping is idempotent")
    func clampingIsIdempotent() {
        let value = 0.7
        #expect(VPMenuBackgroundIntensityPolicy.clamped(value) == value)
        #expect(VPMenuBackgroundIntensityPolicy.clamped(VPMenuBackgroundIntensityPolicy.clamped(value)) == value)
    }

    @Test("Edge cases at boundaries")
    func edgeCases() {
        #expect(VPMenuBackgroundIntensityPolicy.clamped(0.0) == 0.0)
        #expect(VPMenuBackgroundIntensityPolicy.clamped(1.0) == 1.0)
    }
}

@Suite("VPMenuBackgroundIntensityPolicy Percentage Label")
struct VPMenuBackgroundIntensityPolicyLabelTests {
    @Test("Zero percent")
    func zeroPercent() {
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 0.0) == "0%")
    }

    @Test("Fifty percent")
    func fiftyPercent() {
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 0.5) == "50%")
    }

    @Test("Hundred percent")
    func hundredPercent() {
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 1.0) == "100%")
    }

    @Test("Rounds to nearest integer")
    func rounding() {
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 0.249) == "25%")
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 0.251) == "25%")
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 0.25) == "25%")
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 0.75) == "75%")
    }

    @Test("Clamps values before converting")
    func clampsBeforeConverting() {
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: -0.5) == "0%")
        #expect(VPMenuBackgroundIntensityPolicy.percentageLabel(for: 1.5) == "100%")
    }
}
