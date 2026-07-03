import SwiftUI

// MARK: - Glass Surface

/// The single canonical glass recipe: a system material (blur/vibrancy) + dark glass tint +
/// one specular stroke (top-leading light) + a tier-scaled shadow. Replaces the ~41 hand-rolled
/// specular strokes and 15+ duplicated shadow pairs across the app.
///
/// Respects Reduce Transparency by swapping the translucent material for a solid dark fill.
struct GlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let elevation: VPElevation
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(VPColor.contentPlane)
                    } else {
                        shape.fill(elevation.material)
                        shape.fill(elevation.tint)
                    }
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [elevation.strokeBright, elevation.strokeDim],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: elevation.strokeWidth
                )
            }
            .clipShape(shape)
            .shadow(
                color: .black.opacity(elevation.shadow.opacity),
                radius: elevation.shadow.radius,
                y: elevation.shadow.y
            )
    }
}

extension View {
    /// Applies the canonical Obsidian-Glass surface for the given depth tier.
    func glassSurface(_ elevation: VPElevation = .raised, cornerRadius: CGFloat = VPRadius.card) -> some View {
        modifier(GlassSurfaceModifier(elevation: elevation, cornerRadius: cornerRadius))
    }
}

// MARK: - Interactive (hover / focus)

/// One hover model, not three. On visionOS we defer to the system `.hoverEffect(.lift)` (gaze-
/// driven) instead of stacking a custom scale + z-translation + spring that would fight the
/// system gesture driver. A subtle custom scale is used only where the system effect is absent.
/// Honors Reduce Motion.
struct VPInteractiveModifier: ViewModifier {
    #if os(visionOS)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #endif

    func body(content: Content) -> some View {
        #if os(visionOS)
        // Reduce Motion: use the static highlight instead of the animated lift.
        content.hoverEffect(reduceMotion ? .highlight : .lift)
        #else
        content.modifier(VPMacHoverModifier())
        #endif
    }
}

#if !os(visionOS)
private struct VPMacHoverModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering && !reduceMotion ? VPMotion.hoverLift : 1.0)
            .animation(VPMotion.snappy, value: hovering)
            .onHover { hovering = $0 }
    }
}
#endif

extension View {
    /// Standard interactive affordance (hover/focus lift) for tappable glass surfaces.
    func vpInteractive() -> some View { modifier(VPInteractiveModifier()) }
}

// MARK: - Background

/// App background: system material + broad neutral depth bands + a lifted "content plane"
/// vignette that keeps on-glass text legible without turning Apple Environment windows into a
/// fully opaque black slab. Replaces the legacy `VPMenuBackground` for migrated screens.
struct VPBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if reduceTransparency {
                LinearGradient(
                    colors: [
                        Color(red: 0.056, green: 0.062, blue: 0.072),
                        Color(red: 0.040, green: 0.046, blue: 0.056),
                        Color(red: 0.030, green: 0.034, blue: 0.042),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Rectangle().fill(.regularMaterial)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.045),
                        Color(red: 0.070, green: 0.080, blue: 0.092).opacity(0.34),
                        Color(red: 0.026, green: 0.030, blue: 0.038).opacity(0.24),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(red: 0.10, green: 0.15, blue: 0.17).opacity(0.10),
                        Color(red: 0.14, green: 0.11, blue: 0.09).opacity(0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .scaleEffect(1.24)
                .blur(radius: 64)
            }
        }
        .ignoresSafeArea()
    }
}

/// Lighter room-aware backdrop for environment management surfaces. These views are usually
/// shown over a bright Apple Environment room, where the default dark app background turns into a
/// flat gray slab when stacked with a visionOS sheet or list.
struct VPEnvironmentBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var includesMaterial: Bool = true

    var body: some View {
        ZStack {
            if reduceTransparency {
                LinearGradient(
                    colors: [
                        Color(red: 0.070, green: 0.074, blue: 0.078),
                        Color(red: 0.046, green: 0.052, blue: 0.058),
                        Color(red: 0.036, green: 0.040, blue: 0.046),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                if includesMaterial {
                    Rectangle().fill(.thinMaterial)
                }

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.055),
                        Color.white.opacity(0.018),
                        Color.black.opacity(0.038),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(red: 0.12, green: 0.15, blue: 0.15).opacity(0.036),
                        Color.clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 48)
            }
        }
        .ignoresSafeArea()
    }
}

struct VPEnvironmentListRowBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if reduceTransparency {
            shape
                .fill(Color(red: 0.046, green: 0.052, blue: 0.060))
        } else {
            shape
                .fill(Color.black.opacity(0.26))
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
        }
    }
}
