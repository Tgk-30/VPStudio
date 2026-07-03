import CoreGraphics
import simd

/// Pure-logic policy constants and helpers for immersive cinema controls positioning.
///
/// Extracted from `HDRISkyboxEnvironment` so that smoothing, offsets, and timing
/// values are testable without RealityKit or ARKit dependencies.
enum ImmersiveControlsPolicy {

    /// EMA blending factor for controls anchor tracking. Higher values make the
    /// controls panel respond faster to head movement but may appear jittery;
    /// lower values feel smoother but introduce latency.
    ///
    /// Previous hardcoded value was 0.08, which felt laggy. 0.18 gives a good
    /// balance between responsiveness and smoothness.
    static let controlsAnchorSmoothing: Float = 0.18

    /// How far in front of the user the controls panel is positioned (meters).
    static let controlsForwardOffset: Float = 1.5
    static let controlsForwardOffsetScreenDistanceRatio: Float = 0.10
    static let maximumScaledControlsForwardOffset: Float = 3.2

    static let tapCatcherScreenMargin: Float = 1.2
    static let tapCatcherDepth: Float = 0.08
    static let tapCatcherBehindScreenOffset: Float = 0.12

    /// Vertical offset from the user's eye line for the controls panel (meters).
    /// Negative = below eye level.
    static let controlsVerticalOffset: Float = -0.15

    /// Duration before immersive controls automatically hide after the last
    /// user interaction.
    static let autoDismissInterval: Duration = .seconds(10)

    /// Controls position used when head tracking is unavailable (e.g. Simulator).
    /// Centered at roughly eye-height and forward of origin.
    static let fallbackControlsPosition = SIMD3<Float>(0, 1.3, -1.5)

    /// Default screen height when no head tracking data is available (meters).
    /// Approximates seated eye level for Apple Vision Pro.
    static let fallbackEyeHeight: Float = 1.6

    static let scrubberIdleThumbSize: CGFloat = 12
    static let scrubberDraggingThumbSize: CGFloat = 20
    /// Tappable height of the scrub bar. The visible track is only a few points
    /// tall, but gaze+pinch on visionOS needs the same forgiving target as the
    /// circular controls around it.
    static let scrubberHitTargetHeight: CGFloat = 60

    /// Standard diameter for the circular transport / secondary control buttons.
    /// visionOS gaze targeting is least precise of any Apple input model, so the
    /// tappable surface is kept well above the 44pt minimum.
    static let controlButtonDiameter: CGFloat = 60

    /// Fine-grained seek delta (seconds) applied when a VoiceOver user performs an
    /// increment/decrement adjustable action on the scrubber. Smaller than the
    /// skip-button interval so position nudges feel precise.
    static let accessibilityScrubSeconds: Double = 5

    /// Short crossfade for play/pause glyph changes such as entering buffering.
    /// Kept below the chrome hide/show timing so it reads as feedback, not a new
    /// panel motion.
    static let bufferingIndicatorTransitionDuration: Double = 0.16

    /// Applies exponential moving average smoothing between the current position
    /// and a target position using ``controlsAnchorSmoothing`` as the blend factor.
    ///
    /// When `current == target` the result equals both (no drift).
    static func smoothedPosition(current: SIMD3<Float>, target: SIMD3<Float>) -> SIMD3<Float> {
        let t = controlsAnchorSmoothing
        return current + (target - current) * t
    }

    static func controlsForwardOffset(forScreenDistance distance: Float) -> Float {
        guard distance.isFinite, distance > 0 else { return controlsForwardOffset }
        let scaled = distance * controlsForwardOffsetScreenDistanceRatio
        return max(controlsForwardOffset, min(maximumScaledControlsForwardOffset, scaled))
    }

    static func tapCatcherSize(screenWidth: Float, screenHeight: Float) -> SIMD3<Float> {
        let width = max(1, screenWidth + tapCatcherScreenMargin * 2)
        let height = max(1, screenHeight + tapCatcherScreenMargin * 2)
        return SIMD3<Float>(width, height, tapCatcherDepth)
    }

    static func tapCatcherPosition(forScreenPosition screenPosition: SIMD3<Float>) -> SIMD3<Float> {
        screenPosition + SIMD3<Float>(0, 0, -tapCatcherBehindScreenOffset)
    }

    /// Converts a head-transform forward column into a stable horizontal
    /// direction for positioning immersive screens and floating controls.
    static func safeHorizontalForward(from column: SIMD4<Float>) -> SIMD3<Float> {
        let candidate = SIMD3<Float>(-column.x, 0, -column.z)
        let lengthSquared = candidate.x * candidate.x + candidate.y * candidate.y + candidate.z * candidate.z
        guard lengthSquared > .leastNonzeroMagnitude else {
            return SIMD3<Float>(0, 0, -1)
        }
        return candidate / sqrt(lengthSquared)
    }

    static func scrubberMarkerX(percent: Double, barWidth: CGFloat, markerWidth: CGFloat) -> CGFloat {
        guard percent.isFinite, barWidth.isFinite, markerWidth.isFinite, barWidth > 0 else { return 0 }
        let clampedPercent = max(0, min(1, percent))
        let rawX = barWidth * clampedPercent
        let inset = max(0, markerWidth / 2)
        guard barWidth > markerWidth else { return barWidth / 2 }
        return max(inset, min(barWidth - inset, rawX))
    }

    static func scrubberDragPercent(locationX: CGFloat, barWidth: CGFloat) -> Double {
        guard locationX.isFinite, barWidth.isFinite, barWidth > 0 else { return 0 }
        return max(0, min(1, locationX / barWidth))
    }
}
