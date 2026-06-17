import Testing
@testable import VPStudio

@Suite("SpatialControlPolicy -- Clamp, Nudge & Auto-Dim")
struct SpatialControlPolicyTests {

    // MARK: - Canonical Ranges match existing CinemaSettingsPanel controls

    @Test("screen geometry ranges match the existing panel controls")
    func canonicalRanges() {
        #expect(SpatialControlPolicy.screenWidthRange == 1.0...10.0)
        #expect(SpatialControlPolicy.screenDistanceRange == 1.5...15.0)
        #expect(SpatialControlPolicy.screenHeightRange == -2.0...4.0)
        #expect(SpatialControlPolicy.screenTiltRange == -15.0...15.0)
        #expect(SpatialControlPolicy.seatOffsetRange == -2.0...2.0)
    }

    // MARK: - clampedX

    @Test("clampedX below range returns lower bound")
    func clampBelowRange() {
        let result = SpatialControlPolicy.clampedX(0.0, within: SpatialControlPolicy.screenWidthRange)
        #expect(result == 1.0)
    }

    @Test("clampedX above range returns upper bound")
    func clampAboveRange() {
        let result = SpatialControlPolicy.clampedX(99.0, within: SpatialControlPolicy.screenWidthRange)
        #expect(result == 10.0)
    }

    @Test("clampedX within range returns value unchanged")
    func clampWithinRange() {
        let result = SpatialControlPolicy.clampedX(5.5, within: SpatialControlPolicy.screenWidthRange)
        #expect(result == 5.5)
    }

    @Test("clampedX at exact bounds returns the bounds")
    func clampAtBounds() {
        #expect(SpatialControlPolicy.clampedX(1.0, within: SpatialControlPolicy.screenWidthRange) == 1.0)
        #expect(SpatialControlPolicy.clampedX(10.0, within: SpatialControlPolicy.screenWidthRange) == 10.0)
    }

    @Test("clampedX with NaN collapses to lower bound")
    func clampNaN() {
        let result = SpatialControlPolicy.clampedX(.nan, within: SpatialControlPolicy.screenTiltRange)
        #expect(result == SpatialControlPolicy.screenTiltRange.lowerBound)
    }

    @Test("clampedX handles negative ranges")
    func clampNegativeRange() {
        #expect(SpatialControlPolicy.clampedX(-99.0, within: SpatialControlPolicy.screenTiltRange) == -15.0)
        #expect(SpatialControlPolicy.clampedX(99.0, within: SpatialControlPolicy.screenTiltRange) == 15.0)
        #expect(SpatialControlPolicy.clampedX(-3.0, within: SpatialControlPolicy.screenTiltRange) == -3.0)
    }

    // MARK: - nudge

    @Test("nudge by normal step produces exact stepped value within range")
    func nudgeNormalStepExact() {
        let result = SpatialControlPolicy.nudge(
            5.0,
            by: SpatialControlPolicy.screenWidthStep,
            within: SpatialControlPolicy.screenWidthRange
        )
        #expect(result == 5.0 + SpatialControlPolicy.screenWidthStep)
    }

    @Test("negative nudge subtracts the step exactly within range")
    func nudgeNegativeStepExact() {
        let result = SpatialControlPolicy.nudge(
            5.0,
            by: -SpatialControlPolicy.screenWidthStep,
            within: SpatialControlPolicy.screenWidthRange
        )
        #expect(result == 5.0 - SpatialControlPolicy.screenWidthStep)
    }

    @Test("nudge up at maximum stays at maximum")
    func nudgeAtMaxStays() {
        let max = SpatialControlPolicy.screenWidthRange.upperBound
        let result = SpatialControlPolicy.nudge(
            max,
            by: SpatialControlPolicy.screenWidthStep,
            within: SpatialControlPolicy.screenWidthRange
        )
        #expect(result == max)
    }

    @Test("nudge down at minimum stays at minimum")
    func nudgeAtMinStays() {
        let min = SpatialControlPolicy.screenWidthRange.lowerBound
        let result = SpatialControlPolicy.nudge(
            min,
            by: -SpatialControlPolicy.screenWidthStep,
            within: SpatialControlPolicy.screenWidthRange
        )
        #expect(result == min)
    }

    @Test("nudge near maximum pins to maximum rather than overshooting")
    func nudgeNearMaxPins() {
        let result = SpatialControlPolicy.nudge(
            9.9,
            by: SpatialControlPolicy.screenWidthStep,
            within: SpatialControlPolicy.screenWidthRange
        )
        #expect(result == SpatialControlPolicy.screenWidthRange.upperBound)
    }

    // MARK: - Property-specific clamp convenience

    @Test("clampedScreenDistance enforces 1.5 lower bound")
    func clampScreenDistanceLower() {
        #expect(SpatialControlPolicy.clampedScreenDistance(0.0) == 1.5)
    }

    @Test("clampedSeatOffset enforces both bounds")
    func clampSeatOffset() {
        #expect(SpatialControlPolicy.clampedSeatOffset(-5.0) == -2.0)
        #expect(SpatialControlPolicy.clampedSeatOffset(5.0) == 2.0)
        #expect(SpatialControlPolicy.clampedSeatOffset(0.5) == 0.5)
    }

    @Test("clampedScreenHeight passes through in-range value")
    func clampScreenHeightInRange() {
        #expect(SpatialControlPolicy.clampedScreenHeight(1.0) == 1.0)
    }

    // MARK: - targetDarkness (auto-dim)

    @Test("auto-dim enabled and playing returns darkness greater than base")
    func autoDimEnabledPlayingDimmer() {
        let base = 0.5
        let result = SpatialControlPolicy.targetDarkness(isPlaying: true, base: base, enabled: true)
        #expect(result > base)
    }

    @Test("auto-dim disabled returns base unchanged even while playing")
    func autoDimDisabledReturnsBase() {
        let base = 0.5
        let result = SpatialControlPolicy.targetDarkness(isPlaying: true, base: base, enabled: false)
        #expect(result == base)
    }

    @Test("auto-dim enabled but not playing returns base unchanged")
    func autoDimNotPlayingReturnsBase() {
        let base = 0.5
        let result = SpatialControlPolicy.targetDarkness(isPlaying: false, base: base, enabled: true)
        #expect(result == base)
    }

    @Test("auto-dim disabled and not playing returns base unchanged")
    func autoDimDisabledNotPlayingReturnsBase() {
        let base = 0.5
        let result = SpatialControlPolicy.targetDarkness(isPlaying: false, base: base, enabled: false)
        #expect(result == base)
    }

    @Test("auto-dim clamps boosted darkness to 1.0 ceiling")
    func autoDimClampsToCeiling() {
        let result = SpatialControlPolicy.targetDarkness(isPlaying: true, base: 0.95, enabled: true)
        #expect(result == 1.0)
    }

    @Test("auto-dim boost equals base plus configured boost when headroom allows")
    func autoDimBoostExact() {
        let base = 0.3
        let result = SpatialControlPolicy.targetDarkness(isPlaying: true, base: base, enabled: true)
        #expect(result == base + SpatialControlPolicy.autoDimBoost)
    }

    @Test("auto-dim clamps an out-of-range base before returning")
    func autoDimClampsBaseWhenDisabled() {
        #expect(SpatialControlPolicy.targetDarkness(isPlaying: false, base: 1.5, enabled: true) == 1.0)
        #expect(SpatialControlPolicy.targetDarkness(isPlaying: false, base: -0.5, enabled: false) == 0.0)
    }
}
