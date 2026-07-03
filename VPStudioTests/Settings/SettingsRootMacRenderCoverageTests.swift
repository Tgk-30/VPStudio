import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit

@MainActor
@Suite("Settings Root macOS Render Coverage", .serialized)
struct SettingsRootMacRenderCoverageTests {
    @Test
    func settingsRootHostsSeededHealthSearchRefreshAndResetStatesOnMacOS() {
        let appState = AppState(testHooks: .init())
        let configuredStatuses: [SettingsDestination: SettingsDestinationStatus] = [
            .debrid: SettingsDestinationStatus(message: "Connected", kind: .positive),
            .metadata: SettingsDestinationStatus(message: "Ready", kind: .positive),
            .ai: SettingsDestinationStatus(message: "Configured", kind: .positive),
            .player: SettingsDestinationStatus(message: "Adaptive", kind: .positive),
        ]
        let warningStatuses: [SettingsDestination: SettingsDestinationStatus] = [
            .debrid: SettingsDestinationStatus(message: "Missing provider", kind: .warning),
            .indexers: SettingsDestinationStatus(message: "No active indexers", kind: .warning),
            .metadata: SettingsDestinationStatus(message: "OMDb key required", kind: .warning),
            .ai: SettingsDestinationStatus(message: "Provider key required", kind: .warning),
            .subtitles: SettingsDestinationStatus(message: "Optional", kind: .neutral),
        ]
        let variants: [(String, SettingsView)] = [
            ("Configured recent", SettingsView(
                initialDidLoadInitialSearch: true,
                initialDestinationStatuses: configuredStatuses,
                initialRecentDestination: .player,
                disablesAutomaticTasks: true
            )),
            ("Empty search refreshing", SettingsView(
                initialQuery: "no-such-provider",
                initialDidLoadInitialSearch: true,
                initialIsRefreshingStatuses: true,
                initialDestinationStatuses: warningStatuses,
                disablesAutomaticTasks: true
            )),
            ("Reset sheet", SettingsView(
                initialDidLoadInitialSearch: true,
                initialDestinationStatuses: warningStatuses,
                initialIsShowingResetSheet: true,
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in variants {
            let size = host(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 760, height: 900)
            )
            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }
    }

    private func host<Content: View>(_ view: Content) -> CGSize {
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = CGRect(x: 0, y: 0, width: 760, height: 900)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 900),
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
