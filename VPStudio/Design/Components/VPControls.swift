import SwiftUI

// MARK: - Button Style

enum VPButtonKind {
    case primary       // accent CTA
    case secondary     // glass
    case tertiary      // subtle glass
    case destructive   // glass with danger glow (never an opaque red slab)
    case icon          // square 60pt glass icon button
}

/// Canonical button style. Enforces the 60pt minimum interactive target, the glass aesthetic,
/// one press animation, and the single hover model. Selection/CTA use the accent as a glow.
struct VPButtonStyle: ButtonStyle {
    var kind: VPButtonKind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        VPButtonSurface(kind: kind, configuration: configuration)
    }
}

private struct VPButtonSurface: View {
    let kind: VPButtonKind
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .font(VPFont.label)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .icon ? 0 : VPSpace.roomy)
            .frame(minWidth: VPSpace.minTapTarget, minHeight: VPSpace.minTapTarget)
            .background { background(shape) }
            .overlay { shape.strokeBorder(strokeGradient, lineWidth: 1) }
            .clipShape(shape)
            .shadow(color: shadowColor,
                    radius: (pressed && !reduceMotion) ? 6 : 12,
                    y: (pressed && !reduceMotion) ? 3 : 7)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : VPMotion.snappy, value: pressed)
            .vpInteractive()
            .contentShape(shape)
    }

    private var radius: CGFloat { kind == .icon ? VPSpace.minTapTarget / 2 : VPRadius.control }

    @ViewBuilder
    private func background(_ shape: RoundedRectangle) -> some View {
        switch kind {
        case .primary:
            shape.fill(LinearGradient(colors: [VPColor.accentLight, VPColor.accent],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
        case .secondary, .icon:
            ZStack { shape.fill(.regularMaterial); shape.fill(VPColor.glassTintRaised) }
        case .tertiary:
            ZStack { shape.fill(.ultraThinMaterial); shape.fill(VPColor.glassTintRest) }
        case .destructive:
            ZStack { shape.fill(.regularMaterial); shape.fill(VPColor.danger.opacity(0.16)) }
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary:     return VPColor.textOnAccent
        case .destructive: return VPColor.danger
        default:           return VPColor.textPrimary
        }
    }

    private var strokeGradient: LinearGradient {
        let top: Color
        switch kind {
        case .primary:     top = Color.white.opacity(0.5)
        case .destructive: top = VPColor.danger.opacity(0.55)
        default:           top = VPColor.specularBright
        }
        return LinearGradient(colors: [top, VPColor.specularDim],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var shadowColor: Color {
        switch kind {
        case .primary:     return VPColor.accentGlow
        case .destructive: return VPColor.danger.opacity(0.35)
        default:           return .black.opacity(0.28)
        }
    }
}

// MARK: - Close Button (canonical 60pt "x")

/// The single clear/close control. Fixes the Explore recent-chip close (an ~8.5pt glyph / ~14pt
/// target — far under the 60pt visionOS minimum) by guaranteeing a 60pt hit area everywhere.
struct VPCloseButton: View {
    var systemName: String = "xmark"
    var accessibilityLabel: String = "Close"
    var size: CGFloat = VPSpace.minTapTarget
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: max(13, size * 0.26), weight: .semibold))
                .foregroundStyle(VPColor.textSecondary)
                .frame(width: size, height: size)
                .glassSurface(.rest, cornerRadius: size / 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .vpInteractive()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Badge

/// Small status pill (glass + tinted), used for counts, states, sort indicators.
struct VPBadge: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = VPColor.textSecondary

    var body: some View {
        HStack(spacing: VPSpace.micro) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
            Text(text).font(VPFont.captionEmph)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, VPSpace.snug)
        .padding(.vertical, VPSpace.micro + 2)
        .background { Capsule().fill(tint.opacity(0.16)) }
        .overlay { Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 0.75) }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Progress Bar

/// Headline progress element (jewel-like specular fill + optional inline label). Replaces hairline
/// progress lines in Downloads/Settings/Library.
struct VPProgressBar: View {
    let value: Double
    var height: CGFloat = 8
    var label: String? = nil
    var tint: Color = VPColor.accent

    private var clamped: Double { min(max(value, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: VPSpace.tight) {
            if let label {
                Text(label)
                    .font(VPFont.caption)
                    .foregroundStyle(VPColor.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    if clamped > 0 {
                        Capsule()
                            .fill(LinearGradient(colors: [tint.opacity(0.85), tint],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(height, geo.size.width * clamped))
                            .shadow(color: tint.opacity(0.5), radius: 6)
                    } else {
                        // Faint tinted stub so the bar still reads as "present" at 0%.
                        Capsule()
                            .fill(tint.opacity(0.25))
                            .frame(width: height)
                    }
                }
            }
            .frame(height: height)
        }
        .accessibilityElement()
        .accessibilityLabel(label ?? "Progress")
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}
