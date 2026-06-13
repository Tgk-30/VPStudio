import Foundation
import Testing
import simd
@testable import VPStudio

#if os(visionOS)
// MARK: - Constants

@Suite("CinemaImmersivePlacementPolicy — Constants")
struct CinemaImmersivePlacementPolicyConstantsTestsCinemaimmersiveplacementpolicytests {

    @Test("fallbackEyeHeight is plausible for seated VR")
    func fallbackEyeHeightPlausible() {
        let h = CinemaImmersivePlacementPolicy.fallbackEyeHeight
        #expect(h >= 1.0)
        #expect(h <= 2.0)
        #expect(h == 1.55)
    }

    @Test("backdropRadius is positive")
    func backdropRadiusPositive() {
        #expect(CinemaImmersivePlacementPolicy.backdropRadius > 0)
        #expect(CinemaImmersivePlacementPolicy.backdropRadius == 26)
    }

    @Test("floorWidth is positive")
    func floorWidthPositive() {
        #expect(CinemaImmersivePlacementPolicy.floorWidth > 0)
        #expect(CinemaImmersivePlacementPolicy.floorWidth == 18)
    }

    @Test("floorDepth is positive")
    func floorDepthPositive() {
        #expect(CinemaImmersivePlacementPolicy.floorDepth > 0)
        #expect(CinemaImmersivePlacementPolicy.floorDepth == 18)
    }

    @Test("wallWidth is positive")
    func wallWidthPositive() {
        #expect(CinemaImmersivePlacementPolicy.wallWidth > 0)
        #expect(CinemaImmersivePlacementPolicy.wallWidth == 18)
    }

    @Test("wallHeight is positive")
    func wallHeightPositive() {
        #expect(CinemaImmersivePlacementPolicy.wallHeight > 0)
        #expect(CinemaImmersivePlacementPolicy.wallHeight == 7)
    }

    @Test("ceilingHeight is positive")
    func ceilingHeightPositive() {
        #expect(CinemaImmersivePlacementPolicy.ceilingHeight > 0)
        #expect(CinemaImmersivePlacementPolicy.ceilingHeight == 4.4)
    }

    @Test("sideWallDepth is positive")
    func sideWallDepthPositive() {
        #expect(CinemaImmersivePlacementPolicy.sideWallDepth > 0)
        #expect(CinemaImmersivePlacementPolicy.sideWallDepth == 18)
    }

    @Test("sideWallThickness is positive and thin")
    func sideWallThicknessPositive() {
        let t = CinemaImmersivePlacementPolicy.sideWallThickness
        #expect(t > 0)
        #expect(t < 1.0)
        #expect(t == 0.04)
    }

    @Test("floorYOffset is negative (below origin)")
    func floorYOffsetBelowOrigin() {
        #expect(CinemaImmersivePlacementPolicy.floorYOffset < 0)
        #expect(CinemaImmersivePlacementPolicy.floorYOffset == -1.45)
    }

    @Test("rearWallZOffset is negative (behind origin)")
    func rearWallZOffsetBehindOrigin() {
        #expect(CinemaImmersivePlacementPolicy.rearWallZOffset < 0)
        #expect(CinemaImmersivePlacementPolicy.rearWallZOffset == -8.5)
    }

    @Test("sideWallXOffset is positive")
    func sideWallXOffsetPositive() {
        #expect(CinemaImmersivePlacementPolicy.sideWallXOffset > 0)
        #expect(CinemaImmersivePlacementPolicy.sideWallXOffset == 9)
    }

    @Test("frameThickness is positive and small")
    func frameThicknessPositive() {
        let t = CinemaImmersivePlacementPolicy.frameThickness
        #expect(t > 0)
        #expect(t < 1.0)
        #expect(t == 0.08)
    }

    @Test("frameDepth is positive and small")
    func frameDepthPositive() {
        let d = CinemaImmersivePlacementPolicy.frameDepth
        #expect(d > 0)
        #expect(d < 1.0)
        #expect(d == 0.06)
    }

    @Test("screenBackplatePadding is positive and small")
    func screenBackplatePaddingPositive() {
        let p = CinemaImmersivePlacementPolicy.screenBackplatePadding
        #expect(p > 0)
        #expect(p < 1.0)
        #expect(p == 0.18)
    }

    @Test("screenForwardOffset is positive and small")
    func screenForwardOffsetPositive() {
        let o = CinemaImmersivePlacementPolicy.screenForwardOffset
        #expect(o > 0)
        #expect(o < 1.0)
        #expect(o == 0.012)
    }

    @Test("seatingRows is positive")
    func seatingRowsPositive() {
        #expect(CinemaImmersivePlacementPolicy.seatingRows > 0)
        #expect(CinemaImmersivePlacementPolicy.seatingRows == 4)
    }

    @Test("seatsPerRow is positive")
    func seatsPerRowPositive() {
        #expect(CinemaImmersivePlacementPolicy.seatsPerRow > 0)
        #expect(CinemaImmersivePlacementPolicy.seatsPerRow == 7)
    }
}

// MARK: - safeHorizontalForward

@Suite("CinemaImmersivePlacementPolicy — safeHorizontalForward")
struct CinemaImmersivePlacementPolicySafeHorizontalForwardTestsCinemaimmersiveplacementpolicytests {

    @Test("Standard forward column returns normalized forward")
    func standardForwardColumn() {
        // Identity matrix column 2: looking down +Z in local space,
        // which means world forward is -Z
        let column = SIMD4<Float>(0, 0, 1, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(result.x.isApproximatelyEqual(to: 0, tolerance: 1e-6))
        #expect(result.y == 0)
        #expect(result.z.isApproximatelyEqual(to: -1, tolerance: 1e-6))
    }

    @Test("Looking backward column returns +Z")
    func lookingBackwardColumn() {
        let column = SIMD4<Float>(0, 0, -1, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(result.x.isApproximatelyEqual(to: 0, tolerance: 1e-6))
        #expect(result.y == 0)
        #expect(result.z.isApproximatelyEqual(to: 1, tolerance: 1e-6))
    }

    @Test("Looking right column returns +X")
    func lookingRightColumn() {
        let column = SIMD4<Float>(-1, 0, 0, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(result.x.isApproximatelyEqual(to: 1, tolerance: 1e-6))
        #expect(result.y == 0)
        #expect(result.z.isApproximatelyEqual(to: 0, tolerance: 1e-6))
    }

    @Test("Looking left column returns -X")
    func lookingLeftColumn() {
        let column = SIMD4<Float>(1, 0, 0, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(result.x.isApproximatelyEqual(to: -1, tolerance: 1e-6))
        #expect(result.y == 0)
        #expect(result.z.isApproximatelyEqual(to: 0, tolerance: 1e-6))
    }

    @Test("Diagonal forward-right is normalized")
    func diagonalForwardRight() {
        let column = SIMD4<Float>(-1, 0, 1, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        let expectedLength = sqrt(result.x * result.x + result.z * result.z)
        #expect(expectedLength.isApproximatelyEqual(to: 1, tolerance: 1e-5))
        #expect(result.x > 0)
        #expect(result.z < 0)
        #expect(result.y == 0)
    }

    @Test("Zero column returns fallback (0, 0, -1)")
    func zeroColumnReturnsFallback() {
        let column = SIMD4<Float>(0, 0, 0, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(result == SIMD3<Float>(0, 0, -1))
    }

    @Test("Near-zero column returns fallback")
    func nearZeroColumnReturnsFallback() {
        let tiny = Float.leastNonzeroMagnitude / 2
        let column = SIMD4<Float>(tiny, 0, tiny, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(result == SIMD3<Float>(0, 0, -1))
    }

    @Test("Y component is ignored")
    func yComponentIgnored() {
        let column = SIMD4<Float>(0, 100, 1, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(result.y == 0)
        #expect(result.z < 0)
    }

    @Test("W component is ignored")
    func wComponentIgnored() {
        let column = SIMD4<Float>(0, 0, 1, 999)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(result.z.isApproximatelyEqual(to: -1, tolerance: 1e-6))
    }

    @Test("Negative column values are handled correctly")
    func negativeColumnValues() {
        let column = SIMD4<Float>(-3, 0, -4, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        // candidate = (3, 0, 4), length = 5
        #expect(result.x.isApproximatelyEqual(to: 3.0 / 5.0, tolerance: 1e-5))
        #expect(result.y == 0)
        #expect(result.z.isApproximatelyEqual(to: 4.0 / 5.0, tolerance: 1e-5))
    }
}

// MARK: - screenPosition

@Suite("CinemaImmersivePlacementPolicy — screenPosition")
struct CinemaImmersivePlacementPolicyScreenPositionTests {

    @MainActor
    @Test("Without head transform uses fallback eye height")
    func withoutHeadTransformFallbackEye() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 4.0,
            screenHeight: 0.0,
            seatOffset: .zero,
            loadPersisted: false
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: nil)
        #expect(result.position.x.isApproximatelyEqual(to: 0, tolerance: 1e-6))
        #expect(result.position.y.isApproximatelyEqual(to: 1.55, tolerance: 1e-6))
        #expect(result.position.z.isApproximatelyEqual(to: -4.0, tolerance: 1e-6))
        #expect(result.lookAt == SIMD3<Float>(0, 1.55, 0))
    }

    @MainActor
    @Test("Without head transform respects positive seat offset")
    func withoutHeadTransformPositiveSeatOffset() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 4.0,
            screenHeight: 0.5,
            seatOffset: SIMD3<Double>(1.0, 0.2, 0.5),
            loadPersisted: false
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: nil)
        #expect(result.position.x.isApproximatelyEqual(to: 1.0, tolerance: 1e-6))
        #expect(result.position.y.isApproximatelyEqual(to: 1.55 + 0.5 + 0.2, tolerance: 1e-6))
        // distance = max(4.0 - 0.5, 0.75) = 3.5
        #expect(result.position.z.isApproximatelyEqual(to: -3.5, tolerance: 1e-6))
    }

    @MainActor
    @Test("Without head transform clamps distance to minimum 0.75")
    func withoutHeadTransformClampsDistance() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 1.0,
            screenHeight: 0.0,
            seatOffset: SIMD3<Double>(0, 0, 1.0),
            loadPersisted: false
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: nil)
        // distance = max(1.0 - 1.0, 0.75) = 0.75
        #expect(result.position.z.isApproximatelyEqual(to: -0.75, tolerance: 1e-6))
    }

    @MainActor
    @Test("Without head transform with negative seat offset Z increases distance")
    func withoutHeadTransformNegativeSeatOffsetZ() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 4.0,
            screenHeight: 0.0,
            seatOffset: SIMD3<Double>(0, 0, -1.0),
            loadPersisted: false
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: nil)
        // distance = max(4.0 - (-1.0), 0.75) = 5.0
        #expect(result.position.z.isApproximatelyEqual(to: -5.0, tolerance: 1e-6))
    }

    @MainActor
    @Test("With head transform at origin looking forward")
    func withHeadTransformAtOrigin() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 4.0,
            screenHeight: 0.0,
            seatOffset: .zero,
            loadPersisted: false
        )
        // Identity transform: at origin looking down -Z
        let transform = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: transform)
        #expect(result.position.x.isApproximatelyEqual(to: 0, tolerance: 1e-5))
        #expect(result.position.y.isApproximatelyEqual(to: 0, tolerance: 1e-5))
        #expect(result.position.z.isApproximatelyEqual(to: -4.0, tolerance: 1e-5))
        #expect(result.lookAt == SIMD3<Float>(0, 0, 0))
    }

    @MainActor
    @Test("With head transform translated and looking forward")
    func withHeadTransformTranslated() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 4.0,
            screenHeight: 0.5,
            seatOffset: .zero,
            loadPersisted: false
        )
        // Head at (1, 1.6, 1) looking down -Z
        let transform = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(1, 1.6, 1, 1)
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: transform)
        #expect(result.position.x.isApproximatelyEqual(to: 1.0, tolerance: 1e-5))
        #expect(result.position.y.isApproximatelyEqual(to: 1.6 + 0.5, tolerance: 1e-5))
        #expect(result.position.z.isApproximatelyEqual(to: 1.0 - 4.0, tolerance: 1e-5))
        #expect(result.lookAt == SIMD3<Float>(1, 1.6, 1))
    }

    @MainActor
    @Test("With head transform looking right")
    func withHeadTransformLookingRight() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 3.0,
            screenHeight: 0.0,
            seatOffset: .zero,
            loadPersisted: false
        )
        // Head at origin looking down +X (column 2 = (1, 0, 0))
        let transform = simd_float4x4(
            SIMD4<Float>(0, 0, -1, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: transform)
        // forward = safeHorizontalForward((1,0,0)) = (-1, 0, 0) ??? Wait.
        // column = (1, 0, 0)
        // candidate = (-1, 0, 0)
        // forward = (-1, 0, 0)
        // right = cross(forward, up) = cross((-1,0,0), (0,1,0)) = (0,0,-1)
        // position = head + forward * 3 + right * 0 + up * 0
        // = (0,0,0) + (-3, 0, 0) = (-3, 0, 0)
        #expect(result.position.x.isApproximatelyEqual(to: -3.0, tolerance: 1e-5))
        #expect(result.position.y.isApproximatelyEqual(to: 0, tolerance: 1e-5))
        #expect(result.position.z.isApproximatelyEqual(to: 0, tolerance: 1e-5))
    }

    @MainActor
    @Test("With head transform respects seat offset X and Y")
    func withHeadTransformSeatOffsetXY() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 4.0,
            screenHeight: 0.0,
            seatOffset: SIMD3<Double>(0.5, -0.1, 0),
            loadPersisted: false
        )
        let transform = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 1.5, 0, 1)
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: transform)
        #expect(result.position.x.isApproximatelyEqual(to: 0.5, tolerance: 1e-5))
        #expect(result.position.y.isApproximatelyEqual(to: 1.5 + 0.0 - 0.1, tolerance: 1e-5))
        #expect(result.position.z.isApproximatelyEqual(to: -4.0, tolerance: 1e-5))
    }

    @MainActor
    @Test("With head transform clamps distance to 0.75")
    func withHeadTransformClampsDistance() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 1.0,
            screenHeight: 0.0,
            seatOffset: SIMD3<Double>(0, 0, 1.0),
            loadPersisted: false
        )
        let transform = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 1.5, 0, 1)
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: transform)
        // distance = max(1.0 - 1.0, 0.75) = 0.75
        #expect(result.position.z.isApproximatelyEqual(to: -0.75, tolerance: 1e-5))
    }

    @MainActor
    @Test("With head transform and very large seat offset Z")
    func withHeadTransformLargeSeatOffsetZ() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 10.0,
            screenHeight: 0.0,
            seatOffset: SIMD3<Double>(0, 0, -5.0),
            loadPersisted: false
        )
        let transform = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 1.5, 0, 1)
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: transform)
        // distance = max(10.0 - (-5.0), 0.75) = 15.0
        #expect(result.position.z.isApproximatelyEqual(to: -15.0, tolerance: 1e-5))
    }

    @MainActor
    @Test("LookAt point equals head position when head transform provided")
    func lookAtEqualsHeadPosition() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 4.0,
            screenHeight: 0.0,
            loadPersisted: false
        )
        let headPos = SIMD4<Float>(2, 1.7, -3, 1)
        let transform = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            headPos
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: transform)
        #expect(result.lookAt.x.isApproximatelyEqual(to: 2, tolerance: 1e-5))
        #expect(result.lookAt.y.isApproximatelyEqual(to: 1.7, tolerance: 1e-5))
        #expect(result.lookAt.z.isApproximatelyEqual(to: -3, tolerance: 1e-5))
    }

    @MainActor
    @Test("Without head transform lookAt is fallback eye position")
    func withoutHeadTransformLookAtFallback() {
        let settings = CinemaSettings(
            screenWidth: 6.0,
            screenDistance: 4.0,
            screenHeight: 0.0,
            seatOffset: SIMD3<Double>(2.0, 0.5, 0),
            loadPersisted: false
        )
        let result = CinemaImmersivePlacementPolicy.screenPosition(settings: settings, headTransform: nil)
        // lookAt should be (0, fallbackEyeHeight, 0) — seat offset does NOT affect lookAt without head transform
        #expect(result.lookAt.x.isApproximatelyEqual(to: 0, tolerance: 1e-6))
        #expect(result.lookAt.y.isApproximatelyEqual(to: 1.55, tolerance: 1e-6))
        #expect(result.lookAt.z.isApproximatelyEqual(to: 0, tolerance: 1e-6))
    }
}

// MARK: - shouldShowBackdrop

@Suite("CinemaImmersivePlacementPolicy — shouldShowBackdrop")
struct CinemaImmersivePlacementPolicyShouldShowBackdropTestsCinemaimmersiveplacementpolicytests {

    @Test("Returns true for mixed style with darkness above threshold")
    func mixedStyleAboveThreshold() {
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "mixed", environmentDarkness: 0.06) == true)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "mixed", environmentDarkness: 0.5) == true)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "mixed", environmentDarkness: 1.0) == true)
    }

    @Test("Returns true for full style with darkness above threshold")
    func fullStyleAboveThreshold() {
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "full", environmentDarkness: 0.06) == true)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "full", environmentDarkness: 0.5) == true)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "full", environmentDarkness: 1.0) == true)
    }

    @Test("Returns true for progressive style with darkness above threshold")
    func progressiveStyleAboveThreshold() {
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "progressive", environmentDarkness: 0.06) == true)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "progressive", environmentDarkness: 0.5) == true)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "progressive", environmentDarkness: 1.0) == true)
    }

    @Test("Returns false when darkness is at or below 0.05")
    func darknessAtOrBelowThreshold() {
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "mixed", environmentDarkness: 0.05) == false)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "full", environmentDarkness: 0.05) == false)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "progressive", environmentDarkness: 0.05) == false)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "mixed", environmentDarkness: 0.0) == false)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "full", environmentDarkness: -0.1) == false)
    }

    @Test("Returns false for invalid immersion style regardless of darkness")
    func invalidStyle() {
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "invalid", environmentDarkness: 0.5) == false)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "", environmentDarkness: 1.0) == false)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "half", environmentDarkness: 0.5) == false)
    }

    @Test("Returns false for invalid style even with darkness below threshold")
    func invalidStyleBelowThreshold() {
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "invalid", environmentDarkness: 0.01) == false)
    }
}

// MARK: - backdropOpacity

@Suite("CinemaImmersivePlacementPolicy — backdropOpacity")
struct CinemaImmersivePlacementPolicyBackdropOpacityTestsCinemaimmersiveplacementpolicytests {

    @Test("Clamps values below 0.18 to 0.18")
    func clampsBelowMinimum() {
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.0) == 0.18)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.05) == 0.18)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.17) == 0.18)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.18) == 0.18)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: -1.0) == 0.18)
    }

    @Test("Passes through values between 0.18 and 1.0")
    func passesThroughMidRange() {
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.25).isApproximatelyEqual(to: 0.25, tolerance: 1e-6))
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.5).isApproximatelyEqual(to: 0.5, tolerance: 1e-6))
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.75).isApproximatelyEqual(to: 0.75, tolerance: 1e-6))
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 1.0).isApproximatelyEqual(to: 1.0, tolerance: 1e-6))
    }

    @Test("Clamps values above 1.0 to 1.0")
    func clampsAboveMaximum() {
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 1.1) == 1.0)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 2.0) == 1.0)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 100.0) == 1.0)
    }
}

// MARK: - Helpers

extension Float {
    func isApproximatelyEqual(to other: Float, tolerance: Float) -> Bool {
        abs(self - other) <= tolerance
    }
}
#endif
