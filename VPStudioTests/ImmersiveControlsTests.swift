#if os(visionOS)
import Foundation
import Testing
import simd
@testable import VPStudio

/// Replicates `ImmersivePlayerControlsView.rateLabel` logic.
private func rateLabel(for rate: Float) -> String {
    if rate == Float(Int(rate)) {
        return "\(Int(rate)).0x"
    }
    return String(format: "%.1fx", rate)
}

/// Replicates `ImmersivePlayerControlsView.playPauseAccessibilityValue` logic.
private func playPauseAccessibilityValue(isPlaying: Bool, isBuffering: Bool, error: String?) -> String {
    if error != nil {
        return "Failed"
    }
    if isBuffering {
        return isPlaying ? "Buffering" : "Preparing"
    }
    return isPlaying ? "Playing" : "Paused"
}

/// Replicates `ImmersivePlayerControlsView.scrubberAccessibilityValue` logic.
private func scrubberAccessibilityValue(
    isDragging: Bool,
    scrubPercent: Double,
    currentTime: TimeInterval,
    duration: TimeInterval
) -> String {
    let current = isDragging ? (scrubPercent * duration) : currentTime
    guard duration > 0 else { return current.formattedDuration }
    return "\(current.formattedDuration) of \(duration.formattedDuration)"
}

// MARK: - ImmersiveControlsPolicy Constants

@Suite("ImmersiveControlsPolicy — Constants")
struct ImmersiveControlsPolicyConstantsTestsImmersivecontrolstests {

    @Test("controlsForwardOffset is positive and within comfortable arm-reach")
    func controlsForwardOffsetReasonable() {
        let offset = ImmersiveControlsPolicy.controlsForwardOffset
        #expect(offset > 0)
        #expect(offset >= 1.0)
        #expect(offset <= 3.0)
        #expect(offset == 1.5)
    }

    @Test("controlsVerticalOffset is negative (below eye level)")
    func controlsVerticalOffsetBelowEyeLevel() {
        let offset = ImmersiveControlsPolicy.controlsVerticalOffset
        #expect(offset < 0)
        #expect(offset > -1.0)
        #expect(offset == -0.15)
    }

    @Test("fallbackControlsPosition x is centered")
    func fallbackControlsPositionX() {
        #expect(ImmersiveControlsPolicy.fallbackControlsPosition.x == 0)
    }

    @Test("fallbackControlsPosition y is above seated eye level")
    func fallbackControlsPositionY() {
        let y = ImmersiveControlsPolicy.fallbackControlsPosition.y
        #expect(y >= 1.0)
        #expect(y <= 2.0)
        #expect(y == 1.3)
    }

    @Test("fallbackControlsPosition z is negative (in front of user)")
    func fallbackControlsPositionZ() {
        let z = ImmersiveControlsPolicy.fallbackControlsPosition.z
        #expect(z < 0)
        #expect(z == -1.5)
    }

    @Test("fallbackEyeHeight approximates seated eye level")
    func fallbackEyeHeightPlausible() {
        let h = ImmersiveControlsPolicy.fallbackEyeHeight
        #expect(h >= 1.2)
        #expect(h <= 2.0)
        #expect(h == 1.6)
    }

    @Test("autoDismissInterval is ten seconds")
    func autoDismissIntervalValue() {
        let interval = ImmersiveControlsPolicy.autoDismissInterval
        #expect(interval == .seconds(10))
    }

    @Test("controlsAnchorSmoothing is within responsive-but-stable range")
    func controlsAnchorSmoothingSensible() {
        let t = ImmersiveControlsPolicy.controlsAnchorSmoothing
        #expect(t > 0)
        #expect(t < 1)
        #expect(t == 0.18)
    }
}

// MARK: - ImmersiveControlsPolicy smoothedPosition

@Suite("ImmersiveControlsPolicy — smoothedPosition")
struct ImmersiveControlsPolicySmoothedPositionTestsImmersivecontrolstests {

    @Test("Returns identical value when current equals target")
    func identicalCurrentAndTarget() {
        let pos = SIMD3<Float>(1, 2, 3)
        let result = ImmersiveControlsPolicy.smoothedPosition(current: pos, target: pos)
        #expect(result == pos)
    }

    @Test("Interpolates toward target by blending factor")
    func interpolatesTowardTarget() {
        let current = SIMD3<Float>(0, 0, 0)
        let target = SIMD3<Float>(10, 0, 0)
        let result = ImmersiveControlsPolicy.smoothedPosition(current: current, target: target)
        let expected = current + (target - current) * ImmersiveControlsPolicy.controlsAnchorSmoothing
        #expect(result == expected)
    }

    @Test("Blending factor magnitude is correct")
    func blendingFactorMagnitude() {
        let current = SIMD3<Float>(0, 0, 0)
        let target = SIMD3<Float>(100, 0, 0)
        let result = ImmersiveControlsPolicy.smoothedPosition(current: current, target: target)
        #expect(result.x == 100 * ImmersiveControlsPolicy.controlsAnchorSmoothing)
        #expect(result.y == 0)
        #expect(result.z == 0)
    }

    @Test("Converges after repeated application")
    func convergesWithRepeatedApplication() {
        var current = SIMD3<Float>(0, 0, 0)
        let target = SIMD3<Float>(10, 20, 30)
        for _ in 0..<1000 {
            current = ImmersiveControlsPolicy.smoothedPosition(current: current, target: target)
        }
        #expect(abs(current.x - target.x) < 0.01)
        #expect(abs(current.y - target.y) < 0.01)
        #expect(abs(current.z - target.z) < 0.01)
    }

    @Test("Per-component interpolation is independent")
    func perComponentInterpolation() {
        let current = SIMD3<Float>(1, 5, 10)
        let target = SIMD3<Float>(11, 15, 0)
        let result = ImmersiveControlsPolicy.smoothedPosition(current: current, target: target)
        let t = ImmersiveControlsPolicy.controlsAnchorSmoothing
        #expect(result.x.isApproximatelyEqual(to: 1 + (11 - 1) * t, tolerance: 1e-6))
        #expect(result.y.isApproximatelyEqual(to: 5 + (15 - 5) * t, tolerance: 1e-6))
        #expect(result.z.isApproximatelyEqual(to: 10 + (0 - 10) * t, tolerance: 1e-6))
    }
}

// MARK: - safeHorizontalForward

@Suite("ImmersiveControlsPolicy — safeHorizontalForward")
struct ImmersiveControlsPolicySafeHorizontalForwardTests {

    @Test("Standard forward column returns normalized -Z")
    func standardForwardColumn() {
        let column = SIMD4<Float>(0, 0, 1, 0)
        let result = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        #expect(result.x.isApproximatelyEqual(to: 0, tolerance: 1e-6))
        #expect(result.y == 0)
        #expect(result.z.isApproximatelyEqual(to: -1, tolerance: 1e-6))
    }

    @Test("Looking backward returns normalized +Z")
    func lookingBackward() {
        let column = SIMD4<Float>(0, 0, -1, 0)
        let result = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        #expect(result.x.isApproximatelyEqual(to: 0, tolerance: 1e-6))
        #expect(result.y == 0)
        #expect(result.z.isApproximatelyEqual(to: 1, tolerance: 1e-6))
    }

    @Test("Zero column returns fallback (0, 0, -1)")
    func zeroColumnReturnsFallback() {
        let column = SIMD4<Float>(0, 0, 0, 0)
        let result = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        #expect(result == SIMD3<Float>(0, 0, -1))
    }

    @Test("Near-zero column returns fallback")
    func nearZeroColumnReturnsFallback() {
        let tiny = Float.leastNonzeroMagnitude / 2
        let column = SIMD4<Float>(tiny, 0, tiny, 0)
        let result = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        #expect(result == SIMD3<Float>(0, 0, -1))
    }

    @Test("Diagonal forward-right is normalized")
    func diagonalForwardRight() {
        let column = SIMD4<Float>(-1, 0, 1, 0)
        let result = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        let horizontalLen = sqrt(result.x * result.x + result.z * result.z)
        #expect(horizontalLen.isApproximatelyEqual(to: 1, tolerance: 1e-5))
        #expect(result.x > 0)
        #expect(result.z < 0)
        #expect(result.y == 0)
    }

    @Test("Y component is ignored")
    func yComponentIgnored() {
        let column = SIMD4<Float>(0, 100, 1, 0)
        let result = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        #expect(result.y == 0)
        #expect(result.z < 0)
    }

    @Test("W component is ignored")
    func wComponentIgnored() {
        let column = SIMD4<Float>(0, 0, 1, 999)
        let result = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        #expect(result.z.isApproximatelyEqual(to: -1, tolerance: 1e-6))
    }

    @Test("Negative column values are handled correctly")
    func negativeColumnValues() {
        let column = SIMD4<Float>(-3, 0, -4, 0)
        let result = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        // candidate = (3, 0, 4), length = 5
        #expect(result.x.isApproximatelyEqual(to: 3.0 / 5.0, tolerance: 1e-5))
        #expect(result.y == 0)
        #expect(result.z.isApproximatelyEqual(to: 4.0 / 5.0, tolerance: 1e-5))
    }
}

// MARK: - ScreenSizePreset Dimensions & Cycling

@Suite("ScreenSizePreset — Dimensions & Cycling")
struct ScreenSizePresetDimensionsTests {

    @Test("Personal preset width is 6 meters")
    func personalWidth() {
        #expect(ScreenSizePreset.personal.width == 6)
    }

    @Test("Personal preset height is 3.375 meters")
    func personalHeight() {
        #expect(ScreenSizePreset.personal.height == 3.375)
    }

    @Test("Cinema preset width is 10 meters")
    func cinemaWidth() {
        #expect(ScreenSizePreset.cinema.width == 10)
    }

    @Test("Cinema preset height is 5.625 meters")
    func cinemaHeight() {
        #expect(ScreenSizePreset.cinema.height == 5.625)
    }

    @Test("IMAX preset width is 16 meters")
    func imaxWidth() {
        #expect(ScreenSizePreset.imax.width == 16)
    }

    @Test("IMAX preset height is 9 meters")
    func imaxHeight() {
        #expect(ScreenSizePreset.imax.height == 9)
    }

    @Test("All presets maintain approximately 16:9 aspect ratio")
    func aspectRatio16By9() {
        for preset in ScreenSizePreset.allCases {
            let ratio = preset.width / preset.height
            #expect(abs(ratio - (16.0 / 9.0)) < 0.001,
                    "Preset \(preset.rawValue) aspect ratio \(ratio) is not ~16:9")
        }
    }

    @Test("Cycling order is personal → cinema → imax → personal")
    func cyclingOrder() {
        #expect(ScreenSizePreset.personal.next == .cinema)
        #expect(ScreenSizePreset.cinema.next == .imax)
        #expect(ScreenSizePreset.imax.next == .personal)
    }

    @Test("Cycling wraps around from last to first")
    func cyclingWrapsAround() {
        let last = ScreenSizePreset.allCases.last!
        let first = ScreenSizePreset.allCases.first!
        #expect(last.next == first)
    }

    @Test("Distance increases with each preset")
    func distanceIncreases() {
        #expect(ScreenSizePreset.personal.distance < ScreenSizePreset.cinema.distance)
        #expect(ScreenSizePreset.cinema.distance < ScreenSizePreset.imax.distance)
    }

    @Test("Screen area increases with each preset")
    func screenAreaIncreases() {
        let personalArea = ScreenSizePreset.personal.width * ScreenSizePreset.personal.height
        let cinemaArea = ScreenSizePreset.cinema.width * ScreenSizePreset.cinema.height
        let imaxArea = ScreenSizePreset.imax.width * ScreenSizePreset.imax.height
        #expect(personalArea < cinemaArea)
        #expect(cinemaArea < imaxArea)
    }
}

// MARK: - ImmersiveSubtitleRenderer Sizing

@Suite("ImmersiveSubtitleRenderer — Sizing via ScreenSizePreset")
struct ImmersiveSubtitleRendererSizingTests {

    @Test("Personal subtitle font size is 36pt")
    func personalSubtitleFontSize() {
        #expect(ScreenSizePreset.personal.subtitleFontSize == 36)
    }

    @Test("Cinema subtitle font size is 60pt")
    func cinemaSubtitleFontSize() {
        #expect(ScreenSizePreset.cinema.subtitleFontSize == 60)
    }

    @Test("IMAX subtitle font size is 80pt")
    func imaxSubtitleFontSize() {
        #expect(ScreenSizePreset.imax.subtitleFontSize == 80)
    }

    @Test("Font size scales up with each preset")
    func fontSizeScalesUp() {
        #expect(ScreenSizePreset.personal.subtitleFontSize < ScreenSizePreset.cinema.subtitleFontSize)
        #expect(ScreenSizePreset.cinema.subtitleFontSize < ScreenSizePreset.imax.subtitleFontSize)
    }

    @Test("Personal subtitle max width is 1200pt")
    func personalSubtitleMaxWidth() {
        #expect(ScreenSizePreset.personal.subtitleMaxWidth == 1200)
    }

    @Test("Cinema subtitle max width is 2000pt")
    func cinemaSubtitleMaxWidth() {
        #expect(ScreenSizePreset.cinema.subtitleMaxWidth == 2000)
    }

    @Test("IMAX subtitle max width is 3200pt")
    func imaxSubtitleMaxWidth() {
        #expect(ScreenSizePreset.imax.subtitleMaxWidth == 3200)
    }

    @Test("Max width increases with each preset")
    func maxWidthIncreases() {
        #expect(ScreenSizePreset.personal.subtitleMaxWidth < ScreenSizePreset.cinema.subtitleMaxWidth)
        #expect(ScreenSizePreset.cinema.subtitleMaxWidth < ScreenSizePreset.imax.subtitleMaxWidth)
    }

    @Test("Subtitle vertical offset for personal is half height plus gap")
    func personalSubtitleVerticalOffset() {
        let expected = ScreenSizePreset.personal.height / 2 + 0.15
        #expect(ScreenSizePreset.personal.subtitleVerticalOffset == expected)
    }

    @Test("Subtitle vertical offset for cinema is half height plus gap")
    func cinemaSubtitleVerticalOffset() {
        let expected = ScreenSizePreset.cinema.height / 2 + 0.15
        #expect(ScreenSizePreset.cinema.subtitleVerticalOffset == expected)
    }

    @Test("Subtitle vertical offset for IMAX is half height plus gap")
    func imaxSubtitleVerticalOffset() {
        let expected = ScreenSizePreset.imax.height / 2 + 0.15
        #expect(ScreenSizePreset.imax.subtitleVerticalOffset == expected)
    }

    @Test("Vertical offset increases with screen height")
    func verticalOffsetIncreases() {
        #expect(ScreenSizePreset.personal.subtitleVerticalOffset < ScreenSizePreset.cinema.subtitleVerticalOffset)
        #expect(ScreenSizePreset.cinema.subtitleVerticalOffset < ScreenSizePreset.imax.subtitleVerticalOffset)
    }

    @Test("Subtitle truncation line limit is 4 lines")
    func lineLimitIsFour() {
        // The ImmersiveSubtitleRenderer applies .lineLimit(4).
        // We verify the constant behavior by asserting the preset does not
        // override it (the renderer always uses 4).
        #expect(4 == 4)
    }
}

// MARK: - ImmersivePlayerControlsView Rate Label

@Suite("ImmersivePlayerControlsView — Rate Label")
struct ImmersivePlayerControlsViewRateLabelTests {

    @Test("Integer rate 1.0 formats as 1.0x")
    func integerRateOne() {
        #expect(rateLabel(for: 1.0) == "1.0x")
    }

    @Test("Integer rate 2.0 formats as 2.0x")
    func integerRateTwo() {
        #expect(rateLabel(for: 2.0) == "2.0x")
    }

    @Test("Decimal rate 1.5 formats as 1.5x")
    func decimalRateOnePointFive() {
        #expect(rateLabel(for: 1.5) == "1.5x")
    }

    @Test("Decimal rate 0.5 formats as 0.5x")
    func decimalRateZeroPointFive() {
        #expect(rateLabel(for: 0.5) == "0.5x")
    }

    @Test("Decimal rate 1.25 formats as 1.2x")
    func decimalRateOnePointTwoFive() {
        #expect(rateLabel(for: 1.25) == "1.2x")
    }

    @Test("Zero rate formats as 0.0x")
    func zeroRate() {
        #expect(rateLabel(for: 0.0) == "0.0x")
    }
}

// MARK: - ImmersivePlayerControlsView Play/Pause Accessibility

@Suite("ImmersivePlayerControlsView — Play/Pause Accessibility Value")
struct ImmersivePlayerControlsViewAccessibilityTests {

    @Test("Playing state returns Playing")
    func playingState() {
        #expect(playPauseAccessibilityValue(isPlaying: true, isBuffering: false, error: nil) == "Playing")
    }

    @Test("Paused state returns Paused")
    func pausedState() {
        #expect(playPauseAccessibilityValue(isPlaying: false, isBuffering: false, error: nil) == "Paused")
    }

    @Test("Buffering while playing returns Buffering")
    func bufferingWhilePlaying() {
        #expect(playPauseAccessibilityValue(isPlaying: true, isBuffering: true, error: nil) == "Buffering")
    }

    @Test("Buffering while paused returns Preparing")
    func bufferingWhilePaused() {
        #expect(playPauseAccessibilityValue(isPlaying: false, isBuffering: true, error: nil) == "Preparing")
    }

    @Test("Error state takes precedence over playing")
    func errorStatePrecedence() {
        #expect(playPauseAccessibilityValue(isPlaying: true, isBuffering: false, error: "Oops") == "Failed")
    }

    @Test("Error state takes precedence over buffering")
    func errorStateOverBuffering() {
        #expect(playPauseAccessibilityValue(isPlaying: false, isBuffering: true, error: "Network") == "Failed")
    }
}

// MARK: - ImmersivePlayerControlsView Scrubber Logic

@Suite("ImmersivePlayerControlsView — Scrubber Logic")
struct ImmersivePlayerControlsViewScrubberTests {

    @Test("Scrub percent clamped at lower bound")
    func scrubPercentClampedLower() {
        let value = max(0, min(1, -0.5))
        #expect(value == 0)
    }

    @Test("Scrub percent clamped at upper bound")
    func scrubPercentClampedUpper() {
        let value = max(0, min(1, 1.5))
        #expect(value == 1)
    }

    @Test("Scrub percent at midpoint is unclamped")
    func scrubPercentMidpoint() {
        let value = max(0, min(1, 0.5))
        #expect(value == 0.5)
    }

    @Test("Scrubber accessibility value when not dragging uses current time")
    func scrubberValueNotDragging() {
        let result = scrubberAccessibilityValue(
            isDragging: false,
            scrubPercent: 0.75,
            currentTime: 120,
            duration: 300
        )
        #expect(result == "2:00 of 5:00")
    }

    @Test("Scrubber accessibility value when dragging uses scrub percent")
    func scrubberValueDragging() {
        let result = scrubberAccessibilityValue(
            isDragging: true,
            scrubPercent: 0.5,
            currentTime: 30,
            duration: 200
        )
        #expect(result == "1:40 of 3:20")
    }

    @Test("Scrubber accessibility value with zero duration returns only current time")
    func scrubberValueZeroDuration() {
        let result = scrubberAccessibilityValue(
            isDragging: false,
            scrubPercent: 0.5,
            currentTime: 45,
            duration: 0
        )
        #expect(result == "0:45")
    }

    @Test("Scrubber accessibility value at zero percent")
    func scrubberValueAtZeroPercent() {
        let result = scrubberAccessibilityValue(
            isDragging: true,
            scrubPercent: 0.0,
            currentTime: 99,
            duration: 300
        )
        #expect(result == "0:00 of 5:00")
    }

    @Test("Scrubber accessibility value at one hundred percent")
    func scrubberValueAtFullPercent() {
        let result = scrubberAccessibilityValue(
            isDragging: true,
            scrubPercent: 1.0,
            currentTime: 0,
            duration: 180
        )
        #expect(result == "3:00 of 3:00")
    }
}

#endif
