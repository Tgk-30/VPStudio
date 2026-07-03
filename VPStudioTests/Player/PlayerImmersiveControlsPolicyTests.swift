import Foundation
import Testing
@testable import VPStudio

@Suite("ImmersiveControlsPolicy - Positioning Constants")
struct ImmersiveControlsPolicyPositioningTests {

    @Test
    func controlsAnchorSmoothingValue() {
        #expect(ImmersiveControlsPolicy.controlsAnchorSmoothing == 0.18)
    }

    @Test
    func controlsForwardOffset() {
        #expect(ImmersiveControlsPolicy.controlsForwardOffset == 1.5)
    }

    @Test
    func controlsForwardOffsetScalesForLargeScreensWithoutMovingTooFarAway() {
        #expect(ImmersiveControlsPolicy.controlsForwardOffset(forScreenDistance: 10) == 1.5)
        #expect(ImmersiveControlsPolicy.controlsForwardOffset(forScreenDistance: 20) == 2.0)
        #expect(ImmersiveControlsPolicy.controlsForwardOffset(forScreenDistance: 35) == 3.2)
        #expect(ImmersiveControlsPolicy.controlsForwardOffset(forScreenDistance: -1) == 1.5)
    }

    @Test
    func tapCatcherGeometryStaysBehindAndNearTheScreenPlane() {
        let size = ImmersiveControlsPolicy.tapCatcherSize(screenWidth: 10, screenHeight: 5.625)
        #expect(size.x == 12.4)
        #expect(size.y == 8.025)
        #expect(size.z == ImmersiveControlsPolicy.tapCatcherDepth)

        let position = ImmersiveControlsPolicy.tapCatcherPosition(
            forScreenPosition: SIMD3<Float>(0, 1.6, -20)
        )
        #expect(position.x == 0)
        #expect(position.y == 1.6)
        #expect(position.z == -20.12)
    }

    @Test
    func controlsVerticalOffset() {
        #expect(ImmersiveControlsPolicy.controlsVerticalOffset == -0.15)
    }

    @Test
    func autoDismissIntervalIsTenSeconds() {
        #expect(ImmersiveControlsPolicy.autoDismissInterval == .seconds(10))
    }

    @Test
    func fallbackControlsPosition() {
        #expect(ImmersiveControlsPolicy.fallbackControlsPosition == SIMD3<Float>(0, 1.3, -1.5))
    }

    @Test
    func fallbackEyeHeight() {
        #expect(ImmersiveControlsPolicy.fallbackEyeHeight == 1.6)
    }
}

@Suite("ImmersiveControlsPolicy - Smoothed Position")
struct ImmersiveControlsPolicySmoothedPositionTests {

    @Test
    func smoothedPositionWhenCurrentEqualsTargetReturnsTarget() {
        let position = SIMD3<Float>(1.0, 1.5, -1.0)
        let result = ImmersiveControlsPolicy.smoothedPosition(current: position, target: position)
        #expect(result == position)
    }

    @Test
    func smoothedPositionMovesTowardTarget() {
        let current = SIMD3<Float>(0, 0, 0)
        let target = SIMD3<Float>(1, 1, 1)
        let result = ImmersiveControlsPolicy.smoothedPosition(current: current, target: target)
        #expect(result.x > current.x)
        #expect(result.y > current.y)
        #expect(result.z > current.z)
    }

    @Test
    func smoothedPositionUsesSmoothingFactor() {
        let current = SIMD3<Float>(0, 0, 0)
        let target = SIMD3<Float>(1, 1, 1)
        let result = ImmersiveControlsPolicy.smoothedPosition(current: current, target: target)
        let smoothing = ImmersiveControlsPolicy.controlsAnchorSmoothing
        let expected = current + (target - current) * smoothing
        #expect(result.x == expected.x)
        #expect(result.y == expected.y)
        #expect(result.z == expected.z)
    }

    @Test
    func smoothedPositionAtHalfwayPoint() {
        let smoothing = ImmersiveControlsPolicy.controlsAnchorSmoothing
        let current = SIMD3<Float>(0, 0, 0)
        let target = SIMD3<Float>(1, 1, 1)
        let result = ImmersiveControlsPolicy.smoothedPosition(current: current, target: target)
        #expect(abs(result.x - (1.0 * smoothing)) < 0.001)
    }
}

@Suite("ImmersiveControlsPolicy - Scrubber Geometry")
struct ImmersiveControlsPolicyScrubberGeometryTests {
    @Test
    func scrubberThumbSizesAndHitTargetMeetVisionInteractionMinimums() {
        #expect(ImmersiveControlsPolicy.scrubberIdleThumbSize == 12)
        #expect(ImmersiveControlsPolicy.scrubberDraggingThumbSize == 20)
        // The thumb must visibly grow while dragging for gaze confirmation.
        #expect(ImmersiveControlsPolicy.scrubberDraggingThumbSize > ImmersiveControlsPolicy.scrubberIdleThumbSize)
        // visionOS gaze+pinch needs the same forgiving target as the circular
        // controls; 44pt is too easy to miss at immersive viewing distance.
        #expect(ImmersiveControlsPolicy.controlButtonDiameter >= 60)
        #expect(ImmersiveControlsPolicy.scrubberHitTargetHeight >= 60)
        #expect(ImmersiveControlsPolicy.scrubberHitTargetHeight >= ImmersiveControlsPolicy.controlButtonDiameter)
        #expect(ImmersiveControlsPolicy.bufferingIndicatorTransitionDuration > 0)
        #expect(ImmersiveControlsPolicy.bufferingIndicatorTransitionDuration <= 0.18)
    }

    @Test
    func scrubberMarkerXStaysInsideTrackEdges() {
        #expect(ImmersiveControlsPolicy.scrubberMarkerX(percent: 0, barWidth: 100, markerWidth: 10) == 5)
        #expect(ImmersiveControlsPolicy.scrubberMarkerX(percent: 0.5, barWidth: 100, markerWidth: 10) == 50)
        #expect(ImmersiveControlsPolicy.scrubberMarkerX(percent: 1, barWidth: 100, markerWidth: 10) == 95)
        #expect(ImmersiveControlsPolicy.scrubberMarkerX(percent: 1.5, barWidth: 100, markerWidth: 10) == 95)
        #expect(ImmersiveControlsPolicy.scrubberMarkerX(percent: -0.5, barWidth: 100, markerWidth: 10) == 5)
    }

    @Test
    func scrubberMarkerXHandlesInvalidAndNarrowTracks() {
        #expect(ImmersiveControlsPolicy.scrubberMarkerX(percent: .nan, barWidth: 100, markerWidth: 10) == 0)
        #expect(ImmersiveControlsPolicy.scrubberMarkerX(percent: 0.5, barWidth: .nan, markerWidth: 10) == 0)
        #expect(ImmersiveControlsPolicy.scrubberMarkerX(percent: 0.5, barWidth: 8, markerWidth: 10) == 4)
    }

    @Test
    func scrubberDragPercentClampsToValidPlaybackRange() {
        #expect(ImmersiveControlsPolicy.scrubberDragPercent(locationX: -10, barWidth: 100) == 0)
        #expect(ImmersiveControlsPolicy.scrubberDragPercent(locationX: 40, barWidth: 100) == 0.4)
        #expect(ImmersiveControlsPolicy.scrubberDragPercent(locationX: 120, barWidth: 100) == 1)
        #expect(ImmersiveControlsPolicy.scrubberDragPercent(locationX: 20, barWidth: .nan) == 0)
        #expect(ImmersiveControlsPolicy.scrubberDragPercent(locationX: 0.5, barWidth: 0) == 0)
    }
}
