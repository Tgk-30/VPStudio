import Testing
@testable import VPStudio

struct BottomTabRoutingPolicyTestsBottomtabroutingpolicytests {
    @Test
    func navigationChromePolicyReflectsLayout() {
        #expect(NavigationChromePolicy.usesSidebar(for: .bottomTabBar) == false)
        #expect(NavigationChromePolicy.usesBottomTabBar(for: .bottomTabBar) == true)
        #expect(NavigationChromePolicy.usesSidebar(for: .leftSidebar) == true)
        #expect(NavigationChromePolicy.usesBottomTabBar(for: .leftSidebar) == false)
    }

    @Test
    func environmentsTabOpensPickerWhenConfigured() {
        let action = BottomTabRoutingPolicy.action(for: .environments, opensEnvironmentPicker: true)
        #expect(action == .openEnvironmentPicker)
    }

    @Test
    func environmentsTabSelectsTabWhenPickerDisabled() {
        let action = BottomTabRoutingPolicy.action(for: .environments, opensEnvironmentPicker: false)
        #expect(action == .select(.environments))
    }

    @Test(arguments: SidebarTab.mainTabs.filter { $0 != .environments })
    func nonEnvironmentTabsAlwaysSelect(tab: SidebarTab) {
        let withPicker = BottomTabRoutingPolicy.action(for: tab, opensEnvironmentPicker: true)
        let withoutPicker = BottomTabRoutingPolicy.action(for: tab, opensEnvironmentPicker: false)

        #expect(withPicker == .select(tab))
        #expect(withoutPicker == .select(tab))
    }

    @Test
    func settingsAlwaysSelectsSettingsTab() {
        let withPicker = BottomTabRoutingPolicy.action(for: .settings, opensEnvironmentPicker: true)
        let withoutPicker = BottomTabRoutingPolicy.action(for: .settings, opensEnvironmentPicker: false)

        #expect(withPicker == .select(.settings))
        #expect(withoutPicker == .select(.settings))
    }

    @Test
    func rootTabSelectionClearsPathWhenSwitchingTabsAndRebuildsWhenReselectingCurrentTab() {
        #expect(
            RootTabSelectionPolicy.navigationAction(
                currentTab: .library,
                selectedTab: .search
            ) == .clearPath
        )
        #expect(
            RootTabSelectionPolicy.navigationAction(
                currentTab: .library,
                selectedTab: .library
            ) == .resetStack
        )
        #expect(
            RootTabSelectionPolicy.shouldResetNavigationStack(
                currentTab: .library,
                selectedTab: .library
            )
        )
        #expect(
            RootTabSelectionPolicy.shouldResetNavigationStack(
                currentTab: .library,
                selectedTab: .search
            ) == false
        )
        #expect(
            RootTabSelectionPolicy.shouldClearNavigationPath(
                currentTab: .library,
                selectedTab: .search
            )
        )
        #expect(
            RootTabSelectionPolicy.shouldClearNavigationPath(
                currentTab: .library,
                selectedTab: .library
            ) == false
        )
    }
}
