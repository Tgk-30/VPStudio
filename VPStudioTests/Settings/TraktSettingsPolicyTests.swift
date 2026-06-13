import Foundation
import SwiftUI
import Testing
@testable import VPStudio
#if canImport(UIKit)
import UIKit
#endif

@Suite("TraktSettingsPolicy")
struct TraktSettingsPolicyTests {
    @Test
    func formattedSyncDateReturnsOriginalStringForInvalidISODate() {
        #expect(TraktSettingsPolicy.formattedSyncDate("not-a-date") == "not-a-date")
    }

    @Test
    func formattedSyncDateFormatsRecentTimestampRelatively() {
        let now = Date(timeIntervalSince1970: 1_700_000_600)
        let syncedAt = ISO8601DateFormatter().string(
            from: Date(timeIntervalSince1970: 1_700_000_300)
        )

        let formatted = TraktSettingsPolicy.formattedSyncDate(syncedAt, now: now)

        #expect(formatted != syncedAt)
        #expect(formatted.isEmpty == false)
    }

    @Test
    func formattedSyncDateCanFormatFutureTimestampRelatively() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let syncedAt = ISO8601DateFormatter().string(
            from: Date(timeIntervalSince1970: 1_700_003_600)
        )

        let formatted = TraktSettingsPolicy.formattedSyncDate(syncedAt, now: now)

        #expect(formatted != syncedAt)
        #expect(formatted.isEmpty == false)
    }

    @Test
    func formattedSyncDateAcceptsFractionalSecondsISO8601() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let iso = "2023-11-14T22:13:20.123Z"
        let formatted = TraktSettingsPolicy.formattedSyncDate(iso, now: now)
        #expect(formatted != iso)
        #expect(formatted.isEmpty == false)
    }

    @Test
    func shouldShowMissingCredentialsHelpRequiresNoEffectiveCredentialsAndNoBundledCredentials() {
        #expect(
            TraktSettingsPolicy.shouldShowMissingCredentialsHelp(
                hasCredentials: false,
                hasBundledCredentials: false
            )
        )
        #expect(
            TraktSettingsPolicy.shouldShowMissingCredentialsHelp(
                hasCredentials: true,
                hasBundledCredentials: false
            ) == false
        )
        #expect(
            TraktSettingsPolicy.shouldShowMissingCredentialsHelp(
                hasCredentials: false,
                hasBundledCredentials: true
            ) == false
        )
    }

    @Test
    func advancedCredentialsDescriptionMatchesBundledCredentialState() {
        let withBundled = TraktSettingsPolicy.advancedCredentialsDescription(hasBundledCredentials: true)
        #expect(withBundled.contains("override"))

        let withoutBundled = TraktSettingsPolicy.advancedCredentialsDescription(hasBundledCredentials: false)
        #expect(withoutBundled.contains("trakt.tv/oauth/applications"))
        #expect(withoutBundled.contains("urn:ietf:wg:oauth:2.0:oob"))
    }

    @Test
    func initialPollIntervalClampsToAtLeastOneSecond() {
        #expect(TraktSettingsPolicy.initialPollInterval(0) == 1)
        #expect(TraktSettingsPolicy.initialPollInterval(-10) == 1)
        #expect(TraktSettingsPolicy.initialPollInterval(1) == 1)
        #expect(TraktSettingsPolicy.initialPollInterval(5) == 5)
    }

    @Test
    func devicePollDecisionContinuesPollingForPendingAndSlowDown() {
        #expect(
            TraktSettingsPolicy.devicePollDecision(
                for: .pending,
                currentInterval: 3
            ) == .continuePolling(nextInterval: 3)
        )
        #expect(
            TraktSettingsPolicy.devicePollDecision(
                for: .slowDown,
                currentInterval: 3
            ) == .continuePolling(nextInterval: 4)
        )
    }

    @Test
    func devicePollDecisionCarriesTokensOnSuccess() {
        #expect(
            TraktSettingsPolicy.devicePollDecision(
                for: .success(access: "access", refresh: "refresh"),
                currentInterval: 3
            ) == .authorized(access: "access", refresh: "refresh")
        )
        #expect(
            TraktSettingsPolicy.devicePollDecision(
                for: .success(access: "access", refresh: nil),
                currentInterval: 3
            ) == .authorized(access: "access", refresh: nil)
        )
    }

    #if canImport(UIKit)
    @Test
    @MainActor
    func viewBodyBuildsWhenDisconnected() throws {
        let view = TraktSettingsView(
            initialIsConnected: false,
            initialIsAuthenticating: false,
            initialShowAdvanced: false,
            initialClientId: "",
            initialClientSecret: "",
            disablesAutomaticReload: true
        )
        _ = hostTraktSettingsView(view)
    }
    #endif

    #if canImport(UIKit)
    @Test
    @MainActor
    func viewBodyBuildsDuringDeviceCodeAuthentication() throws {
        let view = TraktSettingsView(
            initialIsConnected: false,
            initialIsAuthenticating: true,
            initialDeviceUserCode: "ABCD-1234",
            initialDeviceVerificationURL: "https://trakt.tv/activate",
            initialShowAdvanced: false,
            initialClientId: "client-id",
            initialClientSecret: "client-secret",
            disablesAutomaticReload: true
        )
        _ = hostTraktSettingsView(view)
    }
    #endif

    #if canImport(UIKit)
    @Test
    @MainActor
    func viewBodyBuildsWhenConnectedIncludingSyncSection() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let lastSync = ISO8601DateFormatter().string(from: now.addingTimeInterval(-600))
        let view = TraktSettingsView(
            initialIsConnected: true,
            initialStatusMessage: TraktSettingsPolicy.connectedStatusMessage,
            initialIsSyncing: false,
            initialLastSyncDate: lastSync,
            initialSyncResultMessage: "Last sync succeeded.",
            initialShowAdvanced: true,
            initialClientId: "client-id",
            initialClientSecret: "client-secret",
            disablesAutomaticReload: true
        )
        _ = hostTraktSettingsView(view)
    }
    #endif

    #if canImport(UIKit)
    @Test
    @MainActor
    func viewBodyBuildsWhenConnectedAndSyncing() throws {
        let view = TraktSettingsView(
            initialIsConnected: true,
            initialIsSyncing: true,
            initialShowAdvanced: true,
            initialClientId: "client-id",
            initialClientSecret: "client-secret",
            disablesAutomaticReload: true
        )
        _ = hostTraktSettingsView(view)
    }
    #endif

    #if canImport(UIKit)
    @MainActor
    private func hostTraktSettingsView(_ view: TraktSettingsView) -> UIViewController {
        let appState = AppState()
        let host = UIHostingController(rootView: view.environment(appState))
        host.view.frame = CGRect(x: 0, y: 0, width: 640, height: 720)
        host.loadViewIfNeeded()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        return host
    }
    #endif
}
