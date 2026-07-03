import SwiftUI
import Testing
@testable import VPStudio

// MARK: - VPSidebarView Tests

@Suite("VPSidebarView Tests")
@MainActor
struct VPSidebarViewTestsViewsVpsidebarviewtests {

    // MARK: - SidebarLayoutPolicy Tests

    @Suite("SidebarLayoutPolicy Tests")
    struct SidebarLayoutPolicyTests {
        @Test("collapsedWidth is 52")
        func collapsedWidthIs52() {
            #expect(SidebarLayoutPolicy.collapsedWidth == 52)
        }

        @Test("expandedWidth is 160")
        func expandedWidthIs160() {
            #expect(SidebarLayoutPolicy.expandedWidth == 160)
        }

        @Test("cornerRadius is 26")
        func cornerRadiusIs26() {
            #expect(SidebarLayoutPolicy.cornerRadius == 26)
        }

        @Test("iconFrame matches the minimum tap target")
        func iconFrameMatchesMinTapTarget() {
            #expect(SidebarLayoutPolicy.iconFrame == VPSpace.minTapTarget)
        }

        @Test("resolved rail width respects the actual icon tap target")
        func resolvedRailWidthRespectsTapTarget() {
            let unscaledWidth = VPSpace.minTapTarget + SidebarLayoutPolicy.railChromeInset * 2
            #expect(SidebarLayoutPolicy.railChromeInset == 9)
            #expect(SidebarLayoutPolicy.resolvedRailWidth(chromeScale: 1) == unscaledWidth)
            #expect(SidebarLayoutPolicy.resolvedRailWidth(chromeScale: 1.25) == unscaledWidth * 1.25)
            #expect(SidebarLayoutPolicy.resolvedRailWidth(chromeScale: 1) > VPSpace.minTapTarget)
        }

        @Test("environment spacing keeps the standalone picker visually clustered")
        func environmentSpacingKeepsPickerClustered() {
            #expect(SidebarLayoutPolicy.environmentButtonSpacing == 5)
            #expect(SidebarLayoutPolicy.environmentButtonSpacing < 10)
        }

        @Test("sidebarMainTabs contains expected tabs")
        func sidebarMainTabsContainsExpected() {
            let tabs = SidebarLayoutPolicy.sidebarMainTabs
            #expect(tabs.count == 4)
            #expect(tabs.contains(.discover))
            #expect(tabs.contains(.search))
            #expect(tabs.contains(.library))
            #expect(tabs.contains(.downloads))
            #expect(!tabs.contains(.settings))
            #expect(!tabs.contains(.environments))
        }
    }

    // MARK: - VPSidebarView Construction Tests

    @Suite("VPSidebarView Construction Tests")
    @MainActor
    struct VPSidebarViewConstructionTests {
        @Test("VPSidebarView can be constructed with required parameters")
        func constructionWithRequiredParams() {
            let view = VPSidebarView(
                selectedTab: .constant(.discover),
                opensEnvironmentPicker: true,
                onOpenEnvironmentPicker: {},
                onTabSelection: { _ in }
            )
            SwiftUIViewDiagnosticHost.render(view.frame(width: 220, height: 520))
        }

        @Test("VPSidebarView can be constructed with all parameters")
        func constructionWithAllParams() {
            let view = VPSidebarView(
                selectedTab: .constant(.library),
                opensEnvironmentPicker: true,
                onOpenEnvironmentPicker: {},
                onTabSelection: { _ in },
                activeDownloadCount: 5,
                settingsWarningCount: 2
            )
            SwiftUIViewDiagnosticHost.render(view.frame(width: 220, height: 520))
        }
    }

    // MARK: - TabBadgePolicy Tests (used by sidebar)

    @Suite("TabBadgePolicy Tests")
    struct VPSidebarTabBadgePolicyTests {
        @Test("shouldShowBadge for downloads with active count")
        func shouldShowBadgeForDownloadsWithActiveCount() {
            #expect(TabBadgePolicy.shouldShowBadge(for: .downloads, activeDownloadCount: 3, settingsWarningCount: 0) == true)
        }

        @Test("shouldShowBadge for downloads with zero count")
        func shouldShowBadgeForDownloadsWithZeroCount() {
            #expect(TabBadgePolicy.shouldShowBadge(for: .downloads, activeDownloadCount: 0, settingsWarningCount: 0) == false)
        }

        @Test("shouldShowBadge for settings with warning count")
        func shouldShowBadgeForSettingsWithWarningCount() {
            #expect(TabBadgePolicy.shouldShowBadge(for: .settings, activeDownloadCount: 0, settingsWarningCount: 2) == true)
        }

        @Test("shouldShowBadge for settings with zero warning count")
        func shouldShowBadgeForSettingsWithZeroWarningCount() {
            #expect(TabBadgePolicy.shouldShowBadge(for: .settings, activeDownloadCount: 0, settingsWarningCount: 0) == false)
        }

        @Test("shouldShowBadge returns false for non-badge tabs")
        func shouldShowBadgeReturnsFalseForOtherTabs() {
            let tabs: [SidebarTab] = [.discover, .search, .library, .environments]
            for tab in tabs {
                #expect(TabBadgePolicy.shouldShowBadge(for: tab, activeDownloadCount: 99, settingsWarningCount: 99) == false)
            }
        }
    }

    // MARK: - TabBarAccessibilityPolicy Tests

    @Suite("TabBarAccessibilityPolicy Tests")
    struct VPSidebarTabBarAccessibilityPolicyTests {
        @Test("accessibilityLabel returns non-empty string for discover")
        func accessibilityLabelForDiscover() {
            let label = TabBarAccessibilityPolicy.accessibilityLabel(for: .discover, isSelected: false)
            #expect(!label.isEmpty)
        }

        @Test("accessibilityLabel returns non-empty string for search")
        func accessibilityLabelForSearch() {
            let label = TabBarAccessibilityPolicy.accessibilityLabel(for: .search, isSelected: false)
            #expect(!label.isEmpty)
        }

        @Test("accessibilityLabel returns non-empty string for library")
        func accessibilityLabelForLibrary() {
            let label = TabBarAccessibilityPolicy.accessibilityLabel(for: .library, isSelected: false)
            #expect(!label.isEmpty)
        }

        @Test("accessibilityLabel returns non-empty string for downloads")
        func accessibilityLabelForDownloads() {
            let label = TabBarAccessibilityPolicy.accessibilityLabel(for: .downloads, isSelected: false)
            #expect(!label.isEmpty)
        }

        @Test("accessibilityLabel returns non-empty string for settings")
        func accessibilityLabelForSettings() {
            let label = TabBarAccessibilityPolicy.accessibilityLabel(for: .settings, isSelected: false)
            #expect(!label.isEmpty)
        }

        @Test("accessibilityHint returns non-empty string for all tabs")
        func accessibilityHintReturnsNonEmpty() {
            let tabs: [SidebarTab] = [.discover, .search, .library, .downloads, .settings]
            for tab in tabs {
                let hint = TabBarAccessibilityPolicy.accessibilityHint(for: tab)
                #expect(!hint.isEmpty)
            }
        }
    }
}

// MARK: - BottomTabRoutingPolicy Tests (used by sidebar)

@Suite("BottomTabRoutingPolicy Tests for Sidebar")
struct BottomTabRoutingPolicySidebarTests {
    @Test("action for discover opens environment picker")
    func discoverActionWithPicker() {
        let action = BottomTabRoutingPolicy.action(for: .discover, opensEnvironmentPicker: true)
        #expect(action == .select(.discover))
    }

    @Test("action for environments with picker opens environment picker")
    func environmentsActionWithPicker() {
        let action = BottomTabRoutingPolicy.action(for: .environments, opensEnvironmentPicker: true)
        #expect(action == .openEnvironmentPicker)
    }

    @Test("action for environments without picker selects environments")
    func environmentsActionWithoutPicker() {
        let action = BottomTabRoutingPolicy.action(for: .environments, opensEnvironmentPicker: false)
        #expect(action == .select(.environments))
    }

    @Test("action for settings always selects settings")
    func settingsActionAlwaysSelects() {
        let action1 = BottomTabRoutingPolicy.action(for: .settings, opensEnvironmentPicker: true)
        let action2 = BottomTabRoutingPolicy.action(for: .settings, opensEnvironmentPicker: false)
        #expect(action1 == .select(.settings))
        #expect(action2 == .select(.settings))
    }
}
