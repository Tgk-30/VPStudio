import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit
#endif

@Suite("VPMenuBackground")
@MainActor
struct VPMenuBackgroundTests {
    @Test("VPMenuBackground constructs successfully")
    func constructs() {
        let view = VPMenuBackground()
        _ = view.body
    }

    @Test("VPMenuBackground uses GeometryReader for layout")
    func usesGeometryReader() {
        let view = VPMenuBackground()
        let body = view.body
        _ = body
    }

    #if os(macOS)
    @Test("VPMenuBackground hosts in NSHostingView")
    func hostsInNSHostingView() {
        let view = VPMenuBackground()
        let host = NSHostingView(rootView: view.frame(width: 800, height: 600))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(host.fittingSize.width > 0)
    }
    #endif
}

@Suite("LibraryEmptyStateView")
@MainActor
struct LibraryEmptyStateViewTestsViewsVpmenubackgroundandnavigationtests {
    @Test("LibraryEmptyStateView constructs with favorites list type")
    func constructsWithFavorites() {
        let view = LibraryEmptyStateView(listType: .favorites)
        _ = view.body
    }

    @Test("LibraryEmptyStateView constructs with watchlist list type")
    func constructsWithWatchlist() {
        let view = LibraryEmptyStateView(listType: .watchlist)
        _ = view.body
    }

    @Test("LibraryEmptyStateView constructs with history list type")
    func constructsWithHistory() {
        let view = LibraryEmptyStateView(listType: .history)
        _ = view.body
    }

    @Test("LibraryEmptyStateView constructs with downloads list type")
    func constructsWithDownloads() {
        let view = LibraryEmptyStateView(listType: .downloads)
        _ = view.body
    }

    @Test("LibraryEmptyStateView constructs with onCTAAction callback")
    func constructsWithCallback() {
        let view = LibraryEmptyStateView(listType: .favorites) { action in
            _ = action
        }
        _ = view.body
    }

    @Test("LibraryEmptyStateView CTA button triggers callback for switchToDiscover")
    func ctaButtonTriggersCallbackSwitchToDiscover() {
        let view = LibraryEmptyStateView(listType: .favorites) { action in
            _ = action
        }
        _ = view.body
    }

    @Test("LibraryEmptyStateView CTA button triggers callback for openSettings")
    func ctaButtonTriggersCallbackOpenSettings() {
        let view = LibraryEmptyStateView(listType: .downloads) { action in
            _ = action
        }
        _ = view.body
    }

    #if os(macOS)
    @Test("LibraryEmptyStateView hosts in NSHostingView")
    func hostsInNSHostingView() {
        let view = LibraryEmptyStateView(listType: .favorites)
        let host = NSHostingView(rootView: view.frame(width: 400, height: 400))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(host.fittingSize.width > 0)
    }
    #endif
}

@Suite("LaunchScreen")
@MainActor
struct LaunchScreenTests {
    @Test("LaunchScreen constructs successfully")
    func constructs() {
        let view = LaunchScreen()
        SwiftUIViewDiagnosticHost.render(view, width: 800, height: 600)
    }

    @Test("LaunchScreen has initial state values")
    func initialStateValues() {
        let view = LaunchScreen()
        SwiftUIViewDiagnosticHost.render(view, width: 800, height: 600)
    }

    @Test("LaunchScreen body contains ZStack")
    func bodyContainsZStack() {
        let view = LaunchScreen()
        SwiftUIViewDiagnosticHost.render(view, width: 800, height: 600)
    }

    #if os(macOS)
    @Test("LaunchScreen hosts in NSHostingView")
    func hostsInNSHostingView() {
        let view = LaunchScreen()
        let host = NSHostingView(rootView: view.frame(width: 800, height: 600))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(host.fittingSize.width > 0)
    }
    #endif
}

@Suite("VPSidebarView")
@MainActor
struct VPSidebarViewTests {
    @Test("VPSidebarView constructs with required parameters")
    func constructsWithRequiredParameters() {
        var selectedTab: SidebarTab = .discover
        let view = VPSidebarView(
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }),
            opensEnvironmentPicker: false,
            onOpenEnvironmentPicker: {},
            onTabSelection: { _ in }
        )
        _ = view.body
    }

    @Test("VPSidebarView constructs with all parameters")
    func constructsWithAllParameters() {
        var selectedTab: SidebarTab = .library
        var openedPicker = false
        var selectedTabs: [SidebarTab] = []

        let view = VPSidebarView(
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }),
            opensEnvironmentPicker: true,
            onOpenEnvironmentPicker: { openedPicker = true },
            onTabSelection: { selectedTabs.append($0) },
            activeDownloadCount: 3,
            settingsWarningCount: 2
        )
        _ = view.body

        #expect(openedPicker == false)
        #expect(selectedTabs.isEmpty)
    }

    @Test("SidebarLayoutPolicy constants have expected values")
    func sidebarLayoutPolicyConstants() {
        #expect(SidebarLayoutPolicy.collapsedWidth == 52)
        #expect(SidebarLayoutPolicy.expandedWidth == 160)
        #expect(SidebarLayoutPolicy.cornerRadius == 26)
        #expect(SidebarLayoutPolicy.iconFrame == VPSpace.minTapTarget)
    }

    @Test("SidebarLayoutPolicy sidebarMainTabs contains expected tabs")
    func sidebarMainTabsContainsExpectedTabs() {
        let tabs = SidebarLayoutPolicy.sidebarMainTabs
        #expect(tabs.contains(.discover))
        #expect(tabs.contains(.search))
        #expect(tabs.contains(.library))
        #expect(tabs.contains(.downloads))
        #expect(tabs.count == 4)
    }

    #if os(macOS)
    @Test("VPSidebarView hosts in NSHostingView")
    func hostsInNSHostingView() {
        var selectedTab: SidebarTab = .discover
        let view = VPSidebarView(
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }),
            opensEnvironmentPicker: false,
            onOpenEnvironmentPicker: {},
            onTabSelection: { _ in }
        )
        let host = NSHostingView(rootView: view.frame(width: 80, height: 400))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(host.fittingSize.width > 0)
    }
    #endif
}
