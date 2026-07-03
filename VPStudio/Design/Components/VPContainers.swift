import SwiftUI

// MARK: - Page Shell

/// Screen scaffold: a large title cluster + scrolling content over `VPBackground`. Standardizes
/// top-of-screen rhythm and the visionOS-generous spacing.
struct VPPageShell<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var bottomContentPadding: CGFloat = VPSpace.section
    var bottomViewportInset: CGFloat = 0
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VPSpace.section) {
                VStack(alignment: .leading, spacing: VPSpace.micro) {
                    Text(title)
                        .font(VPFont.title1)
                        .foregroundStyle(VPColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(VPFont.body)
                            .foregroundStyle(VPColor.textSecondary)
                    }
                }
                content()
            }
            .padding(.horizontal, VPSpace.roomy)
            .padding(.top, VPSpace.hero)
            .padding(.bottom, bottomContentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            if bottomViewportInset > 0 {
                VPBottomViewportScrim(height: bottomViewportInset)
            }
        }
        .background { VPBackground() }
    }
}

struct VPBottomViewportScrim: View {
    let height: CGFloat
    var maxOpacity: Double = 0.42

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: VPColor.void.opacity(0), location: 0.0),
                .init(color: VPColor.void.opacity(maxOpacity * 0.19), location: 0.40),
                .init(color: VPColor.void.opacity(maxOpacity * 0.52), location: 0.76),
                .init(color: VPColor.void.opacity(maxOpacity), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Card

/// A glass container at a chosen depth tier.
struct VPCard<Content: View>: View {
    var elevation: VPElevation = .raised
    var cornerRadius: CGFloat = VPRadius.card
    var padding: CGFloat = VPSpace.roomy
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .glassSurface(elevation, cornerRadius: cornerRadius)
    }
}

// MARK: - Section Header

/// Uppercase, tracked section label with an optional accent icon chip. Reads as a label ABOVE
/// content (fixes the "header collapses into rows" hierarchy problem).
struct VPSectionHeader: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: VPSpace.snug) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VPColor.accent)
                    .frame(width: 36, height: 36)
                    .glassSurface(.rest, cornerRadius: VPRadius.chip)
                    .accessibilityHidden(true)
            }
            Text(title.uppercased())
                .font(VPFont.sectionHeader)
                .tracking(VPFont.sectionHeaderTracking)
                .foregroundStyle(VPColor.textSecondary)
            Spacer(minLength: 0)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// A haloed circular gradient badge with an icon — the premium section marker shared by
/// Downloads and Settings (blue→purple glow). Pairs with `VPSectionHeader` for the title.
struct VPSectionBadge: View {
    let systemImage: String

    var body: some View {
        let gradient = LinearGradient(
            colors: [Color(red: 0.40, green: 0.48, blue: 0.97), Color(red: 0.64, green: 0.38, blue: 0.98)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return ZStack {
            Circle().fill(gradient).opacity(0.16)
            Circle().strokeBorder(gradient, lineWidth: 1).opacity(0.55)
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(gradient)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }
}

// MARK: - Row

/// A 60pt list/destination row with optional leading icon chip and trailing accessory.
struct VPRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var iconTint: Color
    var trailing: AnyView?

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        iconTint: Color = VPColor.accent,
        @ViewBuilder trailing: () -> some View
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.iconTint = iconTint
        self.trailing = AnyView(trailing())
    }

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        iconTint: Color = VPColor.accent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.iconTint = iconTint
        self.trailing = nil
    }

    var body: some View {
        HStack(spacing: VPSpace.normal) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: 40, height: 40)
                    .glassSurface(.rest, cornerRadius: VPRadius.chip)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VPFont.rowTitle)
                    .foregroundStyle(VPColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(VPFont.caption)
                        .foregroundStyle(VPColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: VPSpace.snug)
            if let trailing { trailing }
        }
        .padding(.horizontal, VPSpace.normal)
        .frame(minHeight: VPSpace.minTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - State Card

/// Unified empty / error / loading surface so off-states share the premium aesthetic instead of
/// looking like a different screen.
struct VPStateCard: View {
    let systemImage: String
    let title: String
    var message: String?
    var tint: Color = VPColor.textSecondary
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: VPSpace.normal) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(tint)
            Text(title)
                .font(VPFont.title2)
                .foregroundStyle(VPColor.textPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(VPFont.body)
                    .foregroundStyle(VPColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(VPButtonStyle(kind: .primary))
                    .padding(.top, VPSpace.tight)
            }
        }
        .padding(VPSpace.section)
        .frame(maxWidth: 520)
        .glassSurface(.raised, cornerRadius: VPRadius.surface)
        .accessibilityElement(children: .combine)
    }
}
