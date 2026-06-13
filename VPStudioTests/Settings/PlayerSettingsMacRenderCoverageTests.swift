import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit

@MainActor
@Suite("Player Settings macOS Render Coverage", .serialized)
struct PlayerSettingsMacRenderCoverageTests {
    @Test
    func playerSettingsHostsSeededPlaybackExternalPlayerAndDiagnosticsStatesOnMacOS() {
        let appState = AppState(testHooks: .init())
        let variants: [(String, PlayerSettingsView)] = [
            ("Defaults", PlayerSettingsView(disablesAutomaticTasks: true)),
            ("Adaptive high fidelity", PlayerSettingsView(
                initialPreferredQuality: .uhd4k,
                initialAutoPlay: false,
                initialHardwareDecoding: false,
                initialPlayerEngineStrategy: .adaptive,
                initialPreferCached: false,
                initialPreferAtmos: true,
                initialHDRPreference: .dolbyVision,
                initialRuntimeDiagnosticsEnabled: true,
                initialNavigationLayout: .leftSidebar,
                disablesAutomaticTasks: true
            )),
            ("Custom external URL invalid", PlayerSettingsView(
                initialExternalPlayerApp: .custom,
                initialExternalPlayerTemplate: "vlc-x-callback://x-callback-url/stream",
                initialSurfaceError: .unknown("Playback settings could not be saved in construction test."),
                disablesAutomaticTasks: true
            )),
            ("External VLC valid", PlayerSettingsView(
                initialPlayerEngineStrategy: .performance,
                initialExternalPlayerApp: .vlc,
                initialExternalPlayerTemplate: "vlc-x-callback://x-callback-url/stream?url={url}",
                initialHDRPreference: .hdr10,
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
