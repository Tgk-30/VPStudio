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
