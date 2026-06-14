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

/// App background: glossy-black gradient + soft blurred accent orbs + a lifted "content plane"
/// vignette that keeps on-glass text legible even when the visionOS passthrough behind the
/// window is bright. Replaces the legacy `VPMenuBackground` for migrated screens.
struct VPBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [VPColor.void, VPColor.abyss, VPColor.void],
                startPoint: .top,
                endPoint: .bottom
            )

            if !reduceTransparency {
                // Blurred ambient orbs (kept subtle; behind everything).
                Circle().fill(VPColor.orbBlue.opacity(0.22))
                    .frame(width: 520, height: 520).blur(radius: 140)
                    .offset(x: -240, y: -180)
                Circle().fill(VPColor.orbPurple.opacity(0.18))
                    .frame(width: 460, height: 460).blur(radius: 150)
                    .offset(x: 260, y: 200)
                Circle().fill(VPColor.orbRed.opacity(0.12))
                    .frame(width: 380, height: 380).blur(radius: 150)
                    .offset(x: 60, y: -260)
            }

            // Content-plane lift: a soft brighter pool in the middle for text contrast.
            RadialGradient(
                colors: [VPColor.contentPlane.opacity(0.9), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 700
            )
            .blendMode(.plusLighter)
            .opacity(reduceTransparency ? 0 : 0.5)
        }
        .ignoresSafeArea()
    }
}
