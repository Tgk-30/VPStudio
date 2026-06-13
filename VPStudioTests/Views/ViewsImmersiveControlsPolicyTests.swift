import Testing
@testable import VPStudio

@Suite("ImmersiveControlsPolicy Constants")
struct ImmersiveControlsPolicyConstantsTests {
    @Test("Controls anchor smoothing")
    func controlsAnchorSmoothing() {
        #expect(ImmersiveControlsPolicy.controlsAnchorSmoothing == 0.18)
    }

    @Test("Controls forward offset")
    func controlsForwardOffset() {
        #expect(ImmersiveControlsPolicy.controlsForwardOffset == 1.5)
    }

    @Test("Controls vertical offset")
    func controlsVerticalOffset() {
        #expect(ImmersiveControlsPolicy.controlsVerticalOffset == -0.15)
    }

    @Test("Auto dismiss interval is 10 seconds")
    func autoDismissInterval() {
        #expect(ImmersiveControlsPolicy.autoDismissInterval == .seconds(10))
    }

    @Test("Fallback controls position")
    func fallbackControlsPosition() {
        let expected = SIMD3<Float>(0, 1.3, -1.5)
        #expect(ImmersiveControlsPolicy.fallbackControlsPosition == expected)
    }

    @Test("Fallback eye height")
    func fallbackEyeHeight() {
        #expect(ImmersiveControlsPolicy.fallbackEyeHeight == 1.6)
    }

    @Test("Smoothing factor is between 0 and 1")
    func smoothingFactorRange() {
        #expect(ImmersiveControlsPolicy.controlsAnchorSmoothing > 0)
        #expect(ImmersiveControlsPolicy.controlsAnchorSmoothing < 1)
    }

    @Test("Forward offset is positive")
    func forwardOffsetPositive() {
        #expect(ImmersiveControlsPolicy.controlsForwardOffset > 0)
    }

    @Test("Vertical offset is negative (below eye level)")
    func verticalOffsetNegative() {
        #expect(ImmersiveControlsPolicy.controlsVerticalOffset < 0)
    }
}

@Suite("ImmersiveControlsPolicy Smoothed Position")
struct ImmersiveControlsPolicySmoothedPositionTestsViewsViewsimmersivecontrolspolicytests {
    @Test("Same position returns same position")
    func samePosition() {
        let position = SIMD3<Float>(1, 2, 3)
        let result = ImmersiveControlsPolicy.smoothedPosition(current: position, target: position)
        #expect(result == position)
    }

    @Test("Zero smoothing blends fully to target")
    func zeroSmoothing() {
        let current = SIMD3<Float>(0, 0, 0)
        let target = SIMD3<Float>(10, 20, 30)

        let smoothing: Float = 0.18
        let expected = current + (target - current) * smoothing

        let result = ImmersiveControlsPolicy.smoothedPosition(current: current, target: target)
        #expect(result.x == expected.x)
        #expect(result.y == expected.y)
        #expect(result.z == expected.z)
    }

    @Test("Smoothed position is between current and target")
    func blendedPosition() {
        let current = SIMD3<Float>(0, 0, 0)
        let target = SIMD3<Float>(100, 100, 100)

        let result = ImmersiveControlsPolicy.smoothedPosition(current: current, target: target)

        for i in 0..<3 {
            #expect(result[i] > current[i])
            #expect(result[i] < target[i])
        }
    }

    @Test("Moving toward target from different positions")
    func differentStartingPositions() {
        let target = SIMD3<Float>(100, 200, 300)

        let result1 = ImmersiveControlsPolicy.smoothedPosition(current: SIMD3<Float>(0, 0, 0), target: target)
        let result2 = ImmersiveControlsPolicy.smoothedPosition(current: SIMD3<Float>(50, 100, 150), target: target)

        #expect(result2[0] > result1[0])
        #expect(result2[1] > result1[1])
        #expect(result2[2] > result1[2])
    }
}
