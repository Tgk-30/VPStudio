import SwiftUI
import Testing
@testable import VPStudio

@Suite("VP Bottom Tab Bar Render Coverage")
@MainActor
struct VPBottomTabBarRenderCoverageTests {
    @Test
    func hostsSelectedBadgeAndEnvironmentPickerVariantsWithoutActions() {
        var selectedTab = SidebarTab.discover
        var openedEnvironmentPicker = 0
        var selectedTabs: [SidebarTab] = []

        let view = VStack(spacing: 22) {
            VPBottomTabBar(
                selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }),
                opensEnvironmentPicker: false,
                onOpenEnvironmentPicker: { openedEnvironmentPicker += 1 },
                onTabSelection: { selectedTabs.append($0) },
                activeDownloadCount: 0,
                settingsWarningCount: 0
            )

            VPBottomTabBar(
                selectedTab: .constant(.downloads),
                opensEnvironmentPicker: false,
                onOpenEnvironmentPicker: { openedEnvironmentPicker += 1 },
                onTabSelection: { selectedTabs.append($0) },
                activeDownloadCount: 3,
                settingsWarningCount: 2
            )

            VPBottomTabBar(
                selectedTab: .constant(.environments),
                opensEnvironmentPicker: true,
                onOpenEnvironmentPicker: { openedEnvironmentPicker += 1 },
                onTabSelection: { selectedTabs.append($0) },
                activeDownloadCount: 1,
                settingsWarningCount: 1
            )
        }
        .padding()
        .frame(width: 760, height: 260)
        .background(Color.black)

        SwiftUIViewDiagnosticHost.render(view, width: 800, height: 300)

        #expect(selectedTab == .discover)
        #expect(openedEnvironmentPicker == 0)
        #expect(selectedTabs.isEmpty)
    }
}
