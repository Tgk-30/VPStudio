import SwiftUI

// MARK: - Sidebar Layout Policy

enum SidebarLayoutPolicy {
    /// Width of the icon-only sidebar pill.
    static let collapsedWidth: CGFloat = 52
    /// Expanded width (reserved for future use / macOS with labels).
    static let expandedWidth: CGFloat = 160
    /// Corner radius for the sidebar pill shape.
    static let cornerRadius: CGFloat = 26
    /// Icon frame size for each sidebar button. Pinned to the minimum tap target (60) so each
    /// nav item meets the mandated primary-control hit area before `chromeScale` is applied.
    static let iconFrame: CGFloat = VPSpace.minTapTarget
    /// Horizontal breathing room around the 60pt target. The rendered rail must include the
    /// target plus this chrome inset so selected circles do not visually overflow the bar.
    static let railChromeInset: CGFloat = 9
    /// Gap between the main rail and the Environments mini rail. Kept tight so the standalone
    /// picker control reads as part of the same navigation cluster instead of a detached orb.
    static let environmentButtonSpacing: CGFloat = 5

    /// The tabs shown in the main sidebar group (excludes environments, which is separate).
    static var sidebarMainTabs: [SidebarTab] {
        [.discover, .search, .library, .downloads]
    }

    static func resolvedRailWidth(chromeScale: CGFloat) -> CGFloat {
        max(collapsedWidth, iconFrame + railChromeInset * 2) * chromeScale
    }
}

// MARK: - Sidebar View

struct VPSidebarView: View {
    @Binding var selectedTab: SidebarTab
    let opensEnvironmentPicker: Bool
    let onOpenEnvironmentPicker: () -> Void
    let onTabSelection: (SidebarTab) -> Void
    var activeDownloadCount: Int = 0
    var settingsWarningCount: Int = 0

    /// The tab whose name label is currently revealed (on hover / gaze). Keeps the rail compact by
    /// default — the label floats to the right of the hovered icon without reflowing the pill.
    @State private var hoveredTab: SidebarTab?

    #if os(visionOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Vision Pro compact layouts need slightly larger controls, while regular layouts keep the prior
    /// 25% growth pass from the current lane pass.
    private var chromeScale: CGFloat {
        if QARuntimeOptions.forceCompactNavScale {
            return 1.1
        }

        if horizontalSizeClass == .compact || verticalSizeClass == .compact {
            return 1.1
        }
        return 1.25
    }
    #else
    private var chromeScale: CGFloat { 1 }
    #endif

    private var railWidth: CGFloat { SidebarLayoutPolicy.resolvedRailWidth(chromeScale: chromeScale) }
    private var cornerRadius: CGFloat { SidebarLayoutPolicy.cornerRadius * chromeScale }
    private var iconFrame: CGFloat { SidebarLayoutPolicy.iconFrame * chromeScale }
    private var paddingVertical: CGFloat { 9 * chromeScale }
    private var paddingHorizontal: CGFloat { 5 * chromeScale }
    private var separatorWidth: CGFloat { 24 * chromeScale }
    private var separatorPadding: CGFloat { 3 * chromeScale }
    private var iconSize: CGFloat { 17 * chromeScale }
    private var containerInset: CGFloat { 4 * chromeScale }
    private var badgeSize: CGFloat { 7 * chromeScale }
    private var badgeOffsetX: CGFloat { -4 * chromeScale }
    private var badgeOffsetY: CGFloat { 4 * chromeScale }
    private var environmentIconSize: CGFloat { 18 * chromeScale }
    private var environmentButtonSpacing: CGFloat { SidebarLayoutPolicy.environmentButtonSpacing * chromeScale }
    /// Gap between an icon and its hover-revealed name label.
    private var hoverLabelGap: CGFloat { VPSpace.tight * chromeScale }
    /// Inset inside the floating hover-label capsule.
    private var hoverLabelPaddingH: CGFloat { VPSpace.snug * chromeScale }
    private var hoverLabelPaddingV: CGFloat { VPSpace.micro * chromeScale }

    var body: some View {
        VStack(spacing: environmentButtonSpacing) {
            mainSidebarPill

            #if os(visionOS)
            environmentSidebarPill
            #endif
        }
    }

    // MARK: - Main Sidebar Pill

    private var mainSidebarPill: some View {
        VStack(spacing: VPSpace.micro * chromeScale) {
            ForEach(SidebarLayoutPolicy.sidebarMainTabs, id: \.self) { tab in
                sidebarIconButton(tab: tab, isSelected: selectedTab == tab) {
                    switch BottomTabRoutingPolicy.action(
                        for: tab,
                        opensEnvironmentPicker: opensEnvironmentPicker
                    ) {
                    case .openEnvironmentPicker:
                        onOpenEnvironmentPicker()
                    case .select(let selected):
                        onTabSelection(selected)
                    }
                }
            }

            // Thin separator
            Capsule()
                .fill(.white.opacity(0.15))
                .frame(width: separatorWidth, height: 1 * chromeScale)
                .padding(.vertical, separatorPadding)

            sidebarIconButton(tab: .settings, isSelected: selectedTab == .settings) {
                onTabSelection(.settings)
            }
        }
        .padding(containerInset)
        .padding(.vertical, paddingVertical)
        .padding(.horizontal, paddingHorizontal)
        .frame(width: railWidth)
        .vpChromeSurface(.roundedRect(cornerRadius: cornerRadius))
    }

    // MARK: - Icon Button

    private func sidebarIconButton(tab: SidebarTab, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tab.icon)
                    .font(.system(size: iconSize, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(VPNavForeground.tint(isSelected: isSelected))
                    .frame(width: iconFrame, height: iconFrame)
                    .vpNavItemSelection(isSelected: isSelected, shape: Circle())

                // Badge dot
                if TabBadgePolicy.shouldShowBadge(
                    for: tab,
                    activeDownloadCount: activeDownloadCount,
                    settingsWarningCount: settingsWarningCount
                ) {
                    Circle()
                        .fill(TabBadgePolicy.badgeColor(for: tab))
                        .frame(width: badgeSize, height: badgeSize)
                        .offset(x: badgeOffsetX, y: badgeOffsetY)
                }
            }
            .contentShape(Circle())
            .overlay(alignment: .leading) { hoverLabel(for: tab) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TabBarAccessibilityPolicy.accessibilityLabel(for: tab, isSelected: isSelected))
        .accessibilityHint(TabBarAccessibilityPolicy.accessibilityHint(for: tab))
        .onHover { isHovered in
            withAnimation(VPMotion.snappy) {
                hoveredTab = isHovered ? tab : (hoveredTab == tab ? nil : hoveredTab)
            }
        }
        #if os(visionOS)
        .hoverEffect(.highlight)
        #endif
    }

    // MARK: - Hover-Reveal Label

    /// A compact name label that fades in to the right of an icon on hover / gaze. Anchored to the
    /// icon's leading edge and pushed fully outside the rail so the resting pill stays icon-only.
    @ViewBuilder
    private func hoverLabel(for tab: SidebarTab) -> some View {
        if hoveredTab == tab {
            let hoverLabelLeadingOffset = -(iconFrame + hoverLabelGap)
            Text(tab.rawValue)
                .font(VPFont.label)
                .foregroundStyle(VPColor.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, hoverLabelPaddingH)
                .padding(.vertical, hoverLabelPaddingV)
                .vpChromeSurface(.capsule)
                .fixedSize()
                // Place the capsule just past the icon's trailing edge without widening the rail.
                .alignmentGuide(.leading) { _ in hoverLabelLeadingOffset }
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .accessibilityHidden(true)
                .zIndex(1)
        }
    }

    // MARK: - Environments Button (separate circle, visionOS only)

    #if os(visionOS)
    private var environmentSidebarPill: some View {
        environmentButton
            .padding(containerInset)
            .frame(width: railWidth)
            .vpChromeSurface(.roundedRect(cornerRadius: cornerRadius))
    }

    private var environmentButton: some View {
        Button {
            switch BottomTabRoutingPolicy.action(
                for: .environments,
                opensEnvironmentPicker: opensEnvironmentPicker
            ) {
            case .openEnvironmentPicker:
                onOpenEnvironmentPicker()
            case .select(let tab):
                onTabSelection(tab)
            }
        } label: {
            let isSelected = selectedTab == .environments
            Image(systemName: SidebarTab.environments.icon)
                .font(.system(size: environmentIconSize, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(VPNavForeground.tint(isSelected: isSelected))
                .frame(width: iconFrame, height: iconFrame)
                // The outer mini rail supplies the chrome. The button only resolves selected
                // state so the accent never overflows as a detached orb in sidebar layout.
                .modifier(EnvironmentSelectionBackground(isSelected: isSelected))
                .overlay(alignment: .leading) { hoverLabel(for: .environments) }
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(VPMotion.snappy) {
                hoveredTab = isHovered ? .environments : (hoveredTab == .environments ? nil : hoveredTab)
            }
        }
        .hoverEffect(.lift)
        .accessibilityLabel("Environments")
    }
    #endif
}

#if os(visionOS)
/// Resolves the standalone Environments button's background without stacking the chrome surface
/// and the selection background — stacking lets the chrome's clipShape crop the selection's accent
/// glow. The surrounding mini rail owns the resting chrome; selected uses the shared glass + accent
/// ring + glow, while unselected stays clear inside that rail.
private struct EnvironmentSelectionBackground: ViewModifier {
    let isSelected: Bool
    func body(content: Content) -> some View {
        if isSelected {
            content.vpNavItemSelection(isSelected: true, shape: Circle())
        } else {
            content
        }
    }
}
#endif
