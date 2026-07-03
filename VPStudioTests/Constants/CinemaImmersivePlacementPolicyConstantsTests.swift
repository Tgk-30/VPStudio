import Foundation
import Testing
import simd
#if os(visionOS)
@testable import VPStudio

@Suite("CinemaImmersivePlacementPolicy Constants Tests")
struct CinemaImmersivePlacementPolicyConstantsTests {

    @Test("Fallback eye height is reasonable")
    func fallbackEyeHeight() {
        #expect(CinemaImmersivePlacementPolicy.fallbackEyeHeight > 0)
        #expect(CinemaImmersivePlacementPolicy.fallbackEyeHeight < 2.5)
    }

    @Test("Backdrop radius is positive")
    func backdropRadius() {
        #expect(CinemaImmersivePlacementPolicy.backdropRadius > 0)
    }

    @Test("Floor dimensions are positive")
    func floorDimensions() {
        #expect(CinemaImmersivePlacementPolicy.floorWidth > 0)
        #expect(CinemaImmersivePlacementPolicy.floorDepth > 0)
    }

    @Test("Wall dimensions are positive")
    func wallDimensions() {
        #expect(CinemaImmersivePlacementPolicy.wallWidth > 0)
        #expect(CinemaImmersivePlacementPolicy.wallHeight > 0)
    }

    @Test("Ceiling height is positive")
    func ceilingHeight() {
        #expect(CinemaImmersivePlacementPolicy.ceilingHeight > 0)
    }

    @Test("Side wall dimensions are positive")
    func sideWallDimensions() {
        #expect(CinemaImmersivePlacementPolicy.sideWallDepth > 0)
        #expect(CinemaImmersivePlacementPolicy.sideWallThickness > 0)
    }

    @Test("Floor Y offset is negative (below eye level)")
    func floorYOffset() {
        #expect(CinemaImmersivePlacementPolicy.floorYOffset < 0)
    }

    @Test("Rear wall Z offset is negative (behind origin)")
    func rearWallZOffset() {
        #expect(CinemaImmersivePlacementPolicy.rearWallZOffset < 0)
    }

    @Test("Side wall X offset is positive")
    func sideWallXOffset() {
        #expect(CinemaImmersivePlacementPolicy.sideWallXOffset > 0)
    }

    @Test("Frame dimensions are positive")
    func frameDimensions() {
        #expect(CinemaImmersivePlacementPolicy.frameThickness > 0)
        #expect(CinemaImmersivePlacementPolicy.frameDepth > 0)
    }

    @Test("Screen backplate padding is positive")
    func screenBackplatePadding() {
        #expect(CinemaImmersivePlacementPolicy.screenBackplatePadding > 0)
    }

    @Test("Screen forward offset is positive")
    func screenForwardOffset() {
        #expect(CinemaImmersivePlacementPolicy.screenForwardOffset > 0)
    }

    @Test("Seating rows count is positive")
    func seatingRows() {
        #expect(CinemaImmersivePlacementPolicy.seatingRows > 0)
    }

    @Test("Seats per row count is positive")
    func seatsPerRow() {
        #expect(CinemaImmersivePlacementPolicy.seatsPerRow > 0)
    }
}

@Suite("CinemaImmersivePlacementPolicy Safe Horizontal Forward Tests")
struct CinemaImmersivePlacementPolicySafeHorizontalForwardTests {

    @Test("safeHorizontalForward returns normalized vector")
    func safeHorizontalForwardNormalized() {
        let column = SIMD4<Float>(0, 0, -1, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        let length = sqrt(result.x * result.x + result.y * result.y + result.z * result.z)
        #expect(abs(length - 1.0) < 0.001)
    }

    @Test("safeHorizontalForward with forward vector points +Z")
    func safeHorizontalForwardForward() {
        let column = SIMD4<Float>(0, 0, -1, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(result.x == 0)
        #expect(result.y == 0)
        // Implementation negates Z: candidate = (-column.x, 0, -column.z)
        #expect(result.z > 0)
    }

    @Test("safeHorizontalForward with backward vector points -Z")
    func safeHorizontalForwardBackward() {
        let column = SIMD4<Float>(0, 0, 1, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        // Implementation negates Z: candidate = (-column.x, 0, -column.z)
        #expect(result.z < 0)
    }

    @Test("safeHorizontalForward falls back to -Z for zero vector")
    func safeHorizontalForwardFallback() {
        let column = SIMD4<Float>(0, 0, 0, 0)
        let result = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(result == SIMD3<Float>(0, 0, -1))
    }
}

@Suite("CinemaImmersivePlacementPolicy Should Show Backdrop Tests")
struct CinemaImmersivePlacementPolicyShouldShowBackdropTests {

    @Test("shouldShowBackdrop returns false for very low darkness")
    func shouldShowBackdropVeryLowDarkness() {
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "full", environmentDarkness: 0.0) == false)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "full", environmentDarkness: 0.04) == false)
    }

    @Test("shouldShowBackdrop returns true when darkness > 0.05")
    func shouldShowBackdropPositiveDarkness() {
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "full", environmentDarkness: 0.06) == true)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "full", environmentDarkness: 1.0) == true)
    }

    @Test("shouldShowBackdrop returns true for any valid immersion style")
    func shouldShowBackdropValidStyles() {
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "mixed", environmentDarkness: 0.5) == true)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "full", environmentDarkness: 0.5) == true)
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "progressive", environmentDarkness: 0.5) == true)
    }

    @Test("shouldShowBackdrop returns false for invalid immersion style raw value")
    func shouldShowBackdropInvalidStyle() {
        #expect(CinemaImmersivePlacementPolicy.shouldShowBackdrop(immersionStyleRaw: "invalid", environmentDarkness: 0.5) == false)
    }
}

@Suite("CinemaImmersivePlacementPolicy Backdrop Opacity Tests")
struct CinemaImmersivePlacementPolicyBackdropOpacityTests {

    @Test("backdropOpacity clamps minimum to 0.18")
    func backdropOpacityMinimum() {
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.0) == 0.18)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.1) == 0.18)
    }

    @Test("backdropOpacity clamps maximum to 1.0")
    func backdropOpacityMaximum() {
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 1.0) == 1.0)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 1.5) == 1.0)
    }

    @Test("backdropOpacity passes through normal values")
    func backdropOpacityNormal() {
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.5) == 0.5)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.8) == 0.8)
    }
}
#endif