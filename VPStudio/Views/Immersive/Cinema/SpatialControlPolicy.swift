import Foundation

/// Pure-logic policy for spatial-playback adjustment of the cinema scene.
///
/// Holds the canonical adjustable ranges and the clamp / nudge math for the
/// existing `CinemaSettings` geometry properties (screen width, distance,
/// height, tilt, seat offset), plus the auto-dim-on-play darkness target.
///
/// This type intentionally has **no** RealityKit or SwiftUI dependency so the
/// math can be unit-tested in isolation. The ranges mirror the bounds already
/// enforced by `CinemaSettingsPanel`'s sliders and seat-offset steppers — they
/// are the real, currently-used limits, not invented values.
enum SpatialControlPolicy {

    // MARK: - Canonical Ranges
    //
    // These match the existing `CinemaSettingsPanel` controls exactly:
    //   screenWidth     Slider 1...10
    //   screenDistance  Slider 1.5...15
    //   screenHeight    Slider -2...4
    //   screenTilt      Slider -15...15
    //   seatOffset.{x,y,z} Stepper -2...2

    /// Screen width in meters.
    static let screenWidthRange: ClosedRange<Double> = 1.0...10.0
    /// Screen distance from the viewer in meters.
    static let screenDistanceRange: ClosedRange<Double> = 1.5...15.0
    /// Screen vertical offset from eye line in meters.
    static let screenHeightRange: ClosedRange<Double> = -2.0...4.0
    /// Screen pitch in degrees.
    static let screenTiltRange: ClosedRange<Double> = -15.0...15.0
    /// Seat offset along any single axis in meters.
    static let seatOffsetRange: ClosedRange<Double> = -2.0...2.0

    // MARK: - Canonical Step Sizes
    //
    // Step granularity for nudge interactions (e.g. buttons / fine adjust).
    // Seat-offset step matches the existing stepper's 0.1 m increment.

    static let screenWidthStep: Double = 0.25
    static let screenDistanceStep: Double = 0.25
    static let screenHeightStep: Double = 0.1
    static let screenTiltStep: Double = 1.0
    static let seatOffsetStep: Double = 0.1

    // MARK: - Auto-Dim

    /// How much darker than the configured base darkness the environment becomes
    /// while playback is active and auto-dim is enabled. Additive on the 0...1
    /// darkness scale; the result is clamped to 0...1.
    static let autoDimBoost: Double = 0.2

    // MARK: - Generic Clamp / Nudge

    /// Clamps `value` to `range`. NaN collapses to the lower bound so the scene
    /// never receives a non-finite geometry value.
    static func clampedX(_ value: Double, within range: ClosedRange<Double>) -> Double {
        guard !value.isNaN else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// Adds `step` to `value` and clamps the result to `range`. At a bound a
    /// nudge that would exceed it stays pinned to the bound.
    static func nudge(_ value: Double, by step: Double, within range: ClosedRange<Double>) -> Double {
        clampedX(value + step, within: range)
    }

    // MARK: - Property-Specific Clamps (convenience)

    static func clampedScreenWidth(_ value: Double) -> Double {
        clampedX(value, within: screenWidthRange)
    }
    static func clampedScreenDistance(_ value: Double) -> Double {
        clampedX(value, within: screenDistanceRange)
    }
    static func clampedScreenHeight(_ value: Double) -> Double {
        clampedX(value, within: screenHeightRange)
    }
    static func clampedScreenTilt(_ value: Double) -> Double {
        clampedX(value, within: screenTiltRange)
    }
    static func clampedSeatOffset(_ value: Double) -> Double {
        clampedX(value, within: seatOffsetRange)
    }

    // MARK: - Auto-Dim Policy

    /// The darkness the cinema environment should use, given the current
    /// playback state and the user's configured base darkness.
    ///
    /// - When `enabled` and `isPlaying`, returns a value **dimmer** (larger on
    ///   the 0...1 darkness scale) than `base`, clamped to 1.0.
    /// - Otherwise returns `base` unchanged (still clamped to the 0...1 range
    ///   for safety).
    ///
    /// This never mutates persisted state; callers apply the result to the live
    /// scene's darkness only.
    static func targetDarkness(isPlaying: Bool, base: Double, enabled: Bool) -> Double {
        let clampedBase = clampedX(base, within: 0.0...1.0)
        guard enabled, isPlaying else { return clampedBase }
        return clampedX(clampedBase + autoDimBoost, within: 0.0...1.0)
    }
}
