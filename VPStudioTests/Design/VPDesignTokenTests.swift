import Testing
import Foundation
@testable import VPStudio

@Suite("VPDesign tokens")
struct VPDesignTokenTests {

    // MARK: Contrast (the H2 adversarial concern — verified over the dark content-plane baseline)

    @Test func onGlassTextMeetsContrastOverContentPlane() {
        let bg = VPContrast.contentPlaneRGB
        let o = VPColor.onGlassTextOpacities
        let primary = VPContrast.whiteTextRatio(opacity: o.primary, overR: bg.r, overG: bg.g, overB: bg.b)
        let secondary = VPContrast.whiteTextRatio(opacity: o.secondary, overR: bg.r, overG: bg.g, overB: bg.b)
        let tertiary = VPContrast.whiteTextRatio(opacity: o.tertiary, overR: bg.r, overG: bg.g, overB: bg.b)

        #expect(primary >= 4.5)   // titles/body clear AA comfortably
        #expect(secondary >= 4.5) // secondary body still clears AA (was the failing 0.4–0.5 case)
        #expect(tertiary >= 3.0)  // hints clear AA-large
        #expect(primary > secondary)
        #expect(secondary > tertiary)
    }

    @Test func contrastRatioMathIsSane() {
        let whiteOnBlack = VPContrast.ratio(
            VPContrast.relativeLuminance(r: 1, g: 1, b: 1),
            VPContrast.relativeLuminance(r: 0, g: 0, b: 0)
        )
        #expect(whiteOnBlack > 20.9 && whiteOnBlack < 21.1) // canonical 21:1
    }

    // MARK: Tap targets (visionOS HIG)

    @Test func minTapTargetMeetsVisionOSMinimum() {
        #expect(VPSpace.minTapTarget >= 60)
    }

    // MARK: Scales

    @Test func spacingScaleIsStrictlyIncreasing() {
        let s = [VPSpace.micro, VPSpace.tight, VPSpace.snug, VPSpace.normal, VPSpace.roomy, VPSpace.section, VPSpace.hero]
        #expect(s == s.sorted())
        #expect(Set(s).count == s.count)
    }

    @Test func radiusScaleIsStrictlyIncreasing() {
        let r = [VPRadius.chip, VPRadius.control, VPRadius.card, VPRadius.surface, VPRadius.modal]
        #expect(r == r.sorted())
        #expect(Set(r).count == r.count)
    }

    // MARK: Elevation (3 tiers grade depth consistently)

    @Test func elevationTiersGradeDepthUpward() {
        #expect(VPElevation.rest.shadow.radius < VPElevation.raised.shadow.radius)
        #expect(VPElevation.raised.shadow.radius < VPElevation.hero.shadow.radius)
        #expect(VPElevation.rest.shadow.opacity < VPElevation.raised.shadow.opacity)
        #expect(VPElevation.raised.shadow.opacity < VPElevation.hero.shadow.opacity)
        #expect(VPElevation.rest.strokeWidth < VPElevation.hero.strokeWidth)
    }

    // MARK: Feature flag

    @Test func featureFlagKeyIsStable() {
        #expect(VPDesignFlags.useObsidianGlassKey == "useObsidianGlass")
    }
}
