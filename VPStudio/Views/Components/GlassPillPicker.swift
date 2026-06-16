import SwiftUI

enum PillPickerAnimationPolicy {
    static let springResponse: Double = 0.35
    static let springDamping: Double = 0.82
    /// Dense in-content control — raised to the 44pt tap-target floor (was 36).
    static let pillHeight: CGFloat = 44
    static let horizontalPadding: CGFloat = 16
    /// Accent ring weight, matching the nav selection idiom (`VPNavSelectionBackground`).
    static let selectionRingWidth: CGFloat = 1.5
}

/// A glass-morphism segmented picker with a sliding indicator.
///
/// Generic over any `Hashable & CustomStringConvertible` selection type.
/// Uses `matchedGeometryEffect` for a smooth animated pill indicator.
struct GlassPillPicker<SelectionType: Hashable & CustomStringConvertible>: View {
    let options: [SelectionType]
    @Binding var selection: SelectionType

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                pillButton(for: option)
            }
        }
        .padding(4)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.07), radius: 24, y: 0)
        .shadow(color: .black.opacity(0.13), radius: 8, y: 4)
    }

    private func pillButton(for option: SelectionType) -> some View {
        let isSelected = selection == option
        return Button {
            withAnimation(
                .spring(
                    response: PillPickerAnimationPolicy.springResponse,
                    dampingFraction: PillPickerAnimationPolicy.springDamping
                )
            ) {
                selection = option
            }
        } label: {
            Text(option.description)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: PillPickerAnimationPolicy.pillHeight)
                .padding(.horizontal, PillPickerAnimationPolicy.horizontalPadding)
                .background {
                    if isSelected {
                        selectionIndicator
                            .matchedGeometryEffect(id: "pillIndicator", in: pillNamespace)
                    }
                }
                .foregroundStyle(
                    isSelected ? VPNavForeground.selected : VPNavForeground.unselected
                )
        }
        .buttonStyle(.plain)
        #if os(visionOS)
        .hoverEffect(.highlight)
        #endif
    }

    /// The selected-segment affordance. Mirrors the canonical nav selection idiom
    /// (`VPNavSelectionBackground`): a refined glass pill + a faint inner accent tint + a thin
    /// `VPColor.accent` ring + a soft accent glow — NOT a solid red slab. Rendered inline (rather
    /// than via `vpNavItemSelection`) so the `matchedGeometryEffect` slide is preserved.
    private var selectionIndicator: some View {
        ZStack {
            // Subtle glass fill (not opaque) — keeps the substrate reading through.
            if reduceTransparency {
                Capsule().fill(VPColor.contentPlane)
            } else {
                Capsule().fill(.regularMaterial)
                Capsule().fill(VPColor.glassTintRaised)
            }
            // Faint inner accent tint for brand identity without going solid red.
            Capsule().fill(VPColor.accent.opacity(0.16))
            // Thin accent ring.
            Capsule().strokeBorder(
                VPColor.accent,
                lineWidth: PillPickerAnimationPolicy.selectionRingWidth
            )
        }
        // Soft accent glow.
        .shadow(color: VPColor.accent.opacity(0.35), radius: 8)
    }
}
