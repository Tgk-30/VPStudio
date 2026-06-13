import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit

@MainActor
@Suite("Sync Settings macOS Render Coverage", .serialized)
struct SyncSettingsMacRenderCoverageTests {
    @Test
    func simklSettingsHostsSavedAuthorizationMessagesAndDisconnectDialog() {
        let appState = AppState(testHooks: .init())
        let variants: [(String, SimklSettingsView)] = [
            ("Saved authorization", SimklSettingsView(
                initialHasSavedAuthorization: true,
                initialStatusMessage: "Saved authorization exists, but Simkl remains cleanup-only in this build.",
                disablesAutomaticTasks: true
            )),
            ("Error with disconnect confirmation", SimklSettingsView(
                initialHasSavedAuthorization: true,
                initialIsShowingDisconnectConfirmation: true,
                initialErrorMessage: "Simkl authorization could not be removed in render coverage.",
                disablesAutomaticTasks: true
            )),
            ("No saved authorization with status", SimklSettingsView(
                initialHasSavedAuthorization: false,
                initialStatusMessage: "No Simkl authorization is saved.",
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in variants {
            let size = host(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 700, height: 560)
            )
            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }
    }

    @Test
    func traktSettingsHostsDisconnectedAuthenticatingConnectedAndSyncingStates() {
        let appState = AppState(testHooks: .init())
        let lastSync = ISO8601DateFormatter().string(
            from: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(-600)
        )
        let variants: [(String, TraktSettingsView)] = [
            ("Disconnected missing credentials", TraktSettingsView(
                initialIsConnected: false,
                initialStatusMessage: TraktSettingsPolicy.missingCredentialsHelpMessage,
                initialShowAdvanced: false,
                initialClientId: "",
                initialClientSecret: "",
                disablesAutomaticReload: true
            )),
            ("Device code authentication", TraktSettingsView(
                initialIsConnected: false,
                initialIsAuthenticating: true,
                initialDeviceUserCode: "ABCD-1234",
                initialDeviceVerificationURL: "https://trakt.tv/activate",
                initialShowAdvanced: false,
                initialClientId: "client-id",
                initialClientSecret: "client-secret",
                disablesAutomaticReload: true
            )),
            ("Connected sync summary", TraktSettingsView(
                initialIsConnected: true,
                initialStatusMessage: TraktSettingsPolicy.connectedStatusMessage,
                initialIsSyncing: false,
                initialLastSyncDate: lastSync,
                initialSyncResultMessage: "Last sync succeeded.",
                initialShowAdvanced: true,
                initialClientId: "client-id",
                initialClientSecret: "client-secret",
                disablesAutomaticReload: true
            )),
            ("Connected syncing", TraktSettingsView(
                initialIsConnected: true,
                initialStatusMessage: TraktSettingsPolicy.connectedStatusMessage,
                initialIsSyncing: true,
                initialShowAdvanced: true,
                initialClientId: "client-id",
                initialClientSecret: "client-secret",
                disablesAutomaticReload: true
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
