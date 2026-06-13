import SwiftUI
import Testing
@testable import VPStudio

@Suite("SettingsDestinationRow Render Coverage")
struct SettingsDestinationRowRenderCoverageTests {
    @Test
    @MainActor
    func rendersEveryStatusKindAndRecentBadgePath() {
        let rows: [(SettingsDestination, SettingsDestinationStatus?, Bool)] = [
            (.metadata, SettingsDestinationStatus(message: "Ready", kind: .positive), true),
            (.debrid, SettingsDestinationStatus(message: "Needs key", kind: .warning), false),
            (.player, SettingsDestinationStatus(message: "Playback preferences", kind: .neutral), false),
            (.testMode, nil, true)
        ]

        for (destination, status, isRecent) in rows {
            SwiftUIViewDiagnosticHost.render(
                SettingsDestinationRow(
                    destination: destination,
                    status: status,
                    isRecent: isRecent
                ),
                width: 520,
                height: 96
            )
        }
    }

    @Test
    @MainActor
    func longStatusMessagesAndSummariesWrapWithoutChangingRowConstruction() {
        SwiftUIViewDiagnosticHost.render(
            SettingsDestinationRow(
                destination: .simkl,
                status: SettingsDestinationStatus(
                    message: "Unavailable in this build",
                    kind: .neutral
                ),
                isRecent: true
            ),
            width: 360,
            height: 128
        )
    }
}
