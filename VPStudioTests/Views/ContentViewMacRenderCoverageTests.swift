import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit

@MainActor
@Suite("Content View macOS Render Coverage", .serialized)
struct ContentViewMacRenderCoverageTests {
    @Test
    func hostsQuickStartSidebarAndBadgeStatesOnMacOS() {
        let quickStartState = AppState(testHooks: .init())
        quickStartState.isBootstrapping = false
        quickStartState.setupRecommendationNeeded = true
        quickStartState.selectedTab = .discover
        quickStartState.navigationLayout = .bottomTabBar
        quickStartState.activePlayerSession = PlayerSessionRequest(
            stream: streamFixture(),
            mediaTitle: "Mac Content Player",
            mediaId: "mac-content-player",
            episodeId: nil
        )
        quickStartState.isMainWindowSuppressedForPlayer = true

        let sidebarState = AppState(testHooks: .init())
        sidebarState.isBootstrapping = false
        sidebarState.selectedTab = .settings
        sidebarState.navigationLayout = .leftSidebar

        let downloadsState = AppState(testHooks: .init())
        downloadsState.isBootstrapping = false
        downloadsState.selectedTab = .downloads
        downloadsState.navigationLayout = .bottomTabBar

        let environmentsState = AppState(testHooks: .init())
        environmentsState.isBootstrapping = false
        environmentsState.selectedTab = .environments
        environmentsState.navigationLayout = .bottomTabBar

        let variants: [(String, AppState, ContentView)] = [
            ("Quick start prompt terminates active player", quickStartState, ContentView(
                initialIsShowingQuickStartPrompt: true,
                initialActiveDownloadCount: 2,
                initialSettingsWarningCount: 3,
                disablesAutomaticTasks: true
            )),
            ("Sidebar settings warnings", sidebarState, ContentView(
                initialActiveDownloadCount: 0,
                initialSettingsWarningCount: 4,
                disablesAutomaticTasks: true
            )),
            ("Downloads badge bottom tabs", downloadsState, ContentView(
                initialActiveDownloadCount: 5,
                initialSettingsWarningCount: 0,
                disablesAutomaticTasks: true
            )),
            ("Mac environments availability tab", environmentsState, ContentView(
                initialActiveDownloadCount: 0,
                initialSettingsWarningCount: 0,
                disablesAutomaticTasks: true
            )),
        ]

        for (name, appState, view) in variants {
            let size = host(
                view
                    .environment(appState)
                    .frame(width: 980, height: 820)
            )
            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }

        #expect(quickStartState.activePlayerSession == nil)
        #expect(quickStartState.isMainWindowSuppressedForPlayer == false)
    }

    private func streamFixture() -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://example.com/mac-content-player.mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Mac.Content.Player.1080p.mkv",
            sizeBytes: 1_024,
            debridService: "fixture"
        )
    }

    private func host<Content: View>(_ view: Content) -> CGSize {
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = CGRect(x: 0, y: 0, width: 980, height: 820)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 820),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        window.orderOut(nil)
        Self.retainedWindows.append(window)
        if Self.retainedWindows.count > 8 {
            Self.retainedWindows.removeFirst(Self.retainedWindows.count - 8)
        }
        return size
    }

    private static var retainedWindows: [NSWindow] = []
}
#endif
