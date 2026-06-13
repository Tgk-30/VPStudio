import Testing
@testable import VPStudio

struct SettingsAppearancePolicySettingsTests {
    // MARK: - normalizedMenuBackgroundIntensity

    @Test
    func test_normalizedMenuBackgroundIntensity_withinRange() {
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(0.5) == 0.5)
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(1.0) == 1.0)
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(0.0) == 0.0)
    }

    @Test
    func test_normalizedMenuBackgroundIntensity_clampsUnderflow() {
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(-0.5) == 0.0)
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(-100) == 0.0)
    }

    @Test
    func test_normalizedMenuBackgroundIntensity_clampsOverflow() {
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(1.5) == 1.0)
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(100) == 1.0)
    }

    @Test
    func test_normalizedMenuBackgroundIntensity_boundaryValues() {
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(0.0) == 0.0)
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(1.0) == 1.0)
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(0.999) == 0.999)
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(1.001) == 1.0)
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(-0.001) == 0.0)
    }

    @Test
    func test_normalizedMenuBackgroundIntensity_extremeNegative() {
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(-Double.greatestFiniteMagnitude) == 0.0)
    }

    @Test
    func test_normalizedMenuBackgroundIntensity_extremePositive() {
        #expect(SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(Double.greatestFiniteMagnitude) == 1.0)
    }

    // MARK: - menuBackgroundIntensityLabel

    @Test
    func test_menuBackgroundIntensityLabel_basic() {
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 0.0) == "0%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 1.0) == "100%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 0.5) == "50%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 0.333) == "33%")
    }

    @Test
    func test_menuBackgroundIntensityLabel_roundingBehavior() {
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 0.249) == "25%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 0.251) == "25%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 0.25) == "25%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 0.75) == "75%")
    }

    @Test
    func test_menuBackgroundIntensityLabel_clampsOutOfRange() {
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: -0.5) == "0%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 1.5) == "100%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: -100) == "0%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 100) == "100%")
    }

    @Test
    func test_menuBackgroundIntensityLabel_usesNormalizedValue() {
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: -0.5) == "0%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 1.5) == "100%")
        #expect(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: 100) == "100%")
    }

    @Test
    func test_menuBackgroundIntensityLabel_composition_isIdempotent() {
        let rawValue = 0.7
        let normalized = SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(rawValue)
        let label = SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: normalized)
        #expect(label == "70%")

        let labelDirect = SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: rawValue)
        #expect(label == labelDirect)
    }
}
