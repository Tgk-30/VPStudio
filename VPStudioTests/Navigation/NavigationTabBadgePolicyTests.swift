import Testing
import SwiftUI
@testable import VPStudio

struct NavigationTabBadgePolicyTests {

    @Test
    func test_shouldShowBadge_downloadsWithActive() {
        #expect(TabBadgePolicy.shouldShowBadge(for: .downloads, activeDownloadCount: 1, settingsWarningCount: 0))
        #expect(TabBadgePolicy.shouldShowBadge(for: .downloads, activeDownloadCount: 5, settingsWarningCount: 0))
    }

    @Test
    func test_shouldShowBadge_downloadsWithNoActive() {
        #expect(!TabBadgePolicy.shouldShowBadge(for: .downloads, activeDownloadCount: 0, settingsWarningCount: 0))
        #expect(!TabBadgePolicy.shouldShowBadge(for: .downloads, activeDownloadCount: -1, settingsWarningCount: 0))
    }

    @Test
    func test_shouldShowBadge_settingsWithWarning() {
        #expect(TabBadgePolicy.shouldShowBadge(for: .settings, activeDownloadCount: 0, settingsWarningCount: 1))
        #expect(TabBadgePolicy.shouldShowBadge(for: .settings, activeDownloadCount: 0, settingsWarningCount: 3))
    }

    @Test
    func test_shouldShowBadge_settingsWithNoWarning() {
        #expect(!TabBadgePolicy.shouldShowBadge(for: .settings, activeDownloadCount: 0, settingsWarningCount: 0))
        #expect(!TabBadgePolicy.shouldShowBadge(for: .settings, activeDownloadCount: 0, settingsWarningCount: -1))
    }

    @Test
    func test_shouldShowBadge_otherTabs() {
        #expect(!TabBadgePolicy.shouldShowBadge(for: .discover, activeDownloadCount: 10, settingsWarningCount: 5))
        #expect(!TabBadgePolicy.shouldShowBadge(for: .search, activeDownloadCount: 10, settingsWarningCount: 5))
        #expect(!TabBadgePolicy.shouldShowBadge(for: .library, activeDownloadCount: 10, settingsWarningCount: 5))
        #expect(!TabBadgePolicy.shouldShowBadge(for: .environments, activeDownloadCount: 10, settingsWarningCount: 5))
    }

    @Test
    func test_badgeColor_downloads() {
        #expect(TabBadgePolicy.badgeColor(for: .downloads) == .red)
    }

    @Test
    func test_badgeColor_settings() {
        #expect(TabBadgePolicy.badgeColor(for: .settings) == .orange)
    }

    @Test
    func test_badgeColor_otherTabs() {
        #expect(TabBadgePolicy.badgeColor(for: .discover) == .clear)
        #expect(TabBadgePolicy.badgeColor(for: .search) == .clear)
        #expect(TabBadgePolicy.badgeColor(for: .library) == .clear)
        #expect(TabBadgePolicy.badgeColor(for: .environments) == .clear)
    }
}
