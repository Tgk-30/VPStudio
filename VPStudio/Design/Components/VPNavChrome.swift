import SwiftUI

// MARK: - Nav Chrome Foundations
//
// The single source of truth for the Obsidian-Glass navigation chrome: the bar *container*
// (bottom tab bar capsule, sidebar rounded-rect pill) and the *selection* affordance for nav
// items (tab pill, sidebar icon circle).
//
// These replace the hand-rolled chrome that was duplicated across `VPBottomTabBar`
// (ContentView.swift) and `VPSidebarView`:
//   • a bare `.regularMaterial` + a literal `white 0.30 → 0.08` specular stroke + a literal
//     double black shadow, and
//   • a solid `LinearGradient.vpAccent` selection fill (an opaque red slab).
//
// Per the app direction: BRAND RED is an ACCENT ONLY (selection / identity / live). Nav selection
// is a refined glass pill with a thin `VPColor.accent` ring + soft accent glow — consistent with
// the Library folder chips (LibraryView.swift) — never an opaque red fill.

// MARK: - Chrome Surface (the bar container)

/// Shape used to clip a chrome bar. The bottom tab bar is a `.capsule`; the sidebar pill is a
/// `.roundedRect` (continuous corners). One recipe, two silhouettes.
enum VPChromeShape {
    /// Fully rounded — the floating bottom tab bar.
    case capsule
    /// Continuous rounded-rectangle with the given corner radius — the vertical sidebar pill.
    case roundedRect(cornerRadius: CGFloat)
}

/// Renders the canonical Obsidian-Glass *bar* container: the `.raised` system material + the
/// `VPColor.glassTintRaised` fill + the single specular stroke (`specularBright → specularDim`,
/// top-leading → bottom-trailing) + the `.raised` elevation shadow, clipped to the requested shape.
///
/// Mirrors `GlassSurfaceModifier` but pins the tier to `.raised` (nav is always the raised plane)
/// and supports a `Capsule` silhouette, which `glassSurface(_:cornerRadius:)` cannot express.
/// Honors Reduce Transparency by swapping the translucent material for a solid dark fill.
struct VPChromeSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let shape: VPChromeShape
    private let elevation: VPElevation = .raised

    func body(content: Content) -> some View {
        switch shape {
        case .capsule:
            decorate(content, shape: Capsule())
        case .roundedRect(let cornerRadius):
            decorate(content, shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    private func decorate<S: InsettableShape>(_ content: Content, shape: S) -> some View {
        content
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
    /// Applies the canonical Obsidian-Glass chrome-bar container (`.raised` tier).
    ///
    /// Use `.capsule` for the floating bottom tab bar and `.roundedRect(cornerRadius:)` for the
    /// vertical sidebar pill. Replaces the hand-rolled `.regularMaterial` + literal white
    /// `0.30 → 0.08` stroke + literal double black shadows in both bars.
    func vpChromeSurface(_ shape: VPChromeShape = .roundedRect(cornerRadius: VPRadius.surface)) -> some View {
        modifier(VPChromeSurfaceModifier(shape: shape))
    }
}

// MARK: - Nav Selection Foreground Tokens

/// The foreground (glyph + label) tints for nav items, exposed so the bottom bar and sidebar tint
/// identically. Selected reads at full white; unselected lifts to `textTertiary` (0.60) — the
/// contrast floor the direction mandates (replacing ad-hoc 0.50 / 0.55).
enum VPNavForeground {
    /// Glyph + label tint for the selected nav item.
    static let selected: Color = .white
    /// Glyph + label tint for an unselected nav item (0.60 — the minimum contrast floor).
    static let unselected: Color = VPColor.textTertiary

    /// Convenience selector.
    static func tint(isSelected: Bool) -> Color { isSelected ? selected : unselected }
}

// MARK: - Nav Selection Background

/// The canonical nav *selection* affordance: a refined glass pill + a thin `VPColor.accent` ring
/// (~1.5pt) + a faint inner accent tint + a soft accent glow. Unselected renders clear.
///
/// This is the one selection look for both the bottom tab bar (a `Capsule`) and the sidebar icon
/// (a `Circle`). It REPLACES the solid `LinearGradient.vpAccent` pills/circles (the opaque red
/// slab). Drop it into a `.background { }` on the item content; size is inherited from that frame.
///
/// Honors Reduce Transparency (solid dark glass instead of a translucent fill).
struct VPNavSelectionBackground<S: InsettableShape>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let isSelected: Bool
    let shape: S

    /// Ring weight per the direction (~1.5pt), matching the Library folder chip.
    private let ringWidth: CGFloat = 1.5

    var body: some View {
        if isSelected {
            ZStack {
                // Subtle glass fill (not an opaque slab) — keeps the substrate reading through.
                if reduceTransparency {
                    shape.fill(VPColor.contentPlane)
                } else {
                    shape.fill(.regularMaterial)
                    shape.fill(VPColor.glassTintRaised)
                }
                // Faint inner accent tint for brand identity without going solid red.
                shape.fill(VPColor.accent.opacity(0.16))
                // Thin accent ring.
                shape.strokeBorder(VPColor.accent, lineWidth: ringWidth)
            }
            // Soft accent glow.
            .shadow(color: VPColor.accent.opacity(0.35), radius: 8)
        } else {
            shape.fill(.clear)
        }
    }
}

extension View {
    /// Applies the canonical nav-selection background for a `Capsule`-shaped item (bottom tab pill).
    func vpNavItemSelection(isSelected: Bool) -> some View {
        background { VPNavSelectionBackground(isSelected: isSelected, shape: Capsule()) }
    }

    /// Applies the canonical nav-selection background for an arbitrary item shape (e.g. a
    /// `Circle` for the sidebar icon, or a `RoundedRectangle`).
    func vpNavItemSelection<S: InsettableShape>(isSelected: Bool, shape: S) -> some View {
        background { VPNavSelectionBackground(isSelected: isSelected, shape: shape) }
    }
}
