import SwiftUI
import Testing
@testable import VPStudio

@Suite("Player Startup State Overlay View")
@MainActor
struct PlayerStartupStateOverlayViewTests {
    @Test
    func rendersFailureLoadingAndRebufferingBranchesWithoutInvokingActions() {
        var retryCount = 0
        var tryNextCount = 0

        let view = ZStack {
            Color.black
            VStack(spacing: 18) {
                PlayerStartupStateOverlayView(
                    playbackState: .failed,
                    title: "Playback Failed",
                    message: "The selected stream stopped responding.",
                    hasPlayedOnce: false,
                    hasNextStream: true,
                    onRetry: { retryCount += 1 },
                    onTryNextStream: { tryNextCount += 1 }
                )

                PlayerStartupStateOverlayView(
                    playbackState: .preparing,
                    title: "Preparing Playback",
                    message: "Opening stream...",
                    hasPlayedOnce: false,
                    hasNextStream: false,
                    onRetry: { retryCount += 1 },
                    onTryNextStream: { tryNextCount += 1 }
                )

                PlayerStartupStateOverlayView(
                    playbackState: .buffering,
                    title: "Buffering",
                    message: nil,
                    hasPlayedOnce: true,
                    hasNextStream: false,
                    onRetry: { retryCount += 1 },
                    onTryNextStream: { tryNextCount += 1 }
                )
            }
            .padding()
        }

        SwiftUIViewDiagnosticHost.render(view, width: 680, height: 560)

        #expect(retryCount == 0)
        #expect(tryNextCount == 0)
    }

    @Test
    func playingStateAfterFirstPlaybackRendersEmptyBranch() {
        let view = PlayerStartupStateOverlayView(
            playbackState: .playing,
            title: "Playing",
            message: "Ready",
            hasPlayedOnce: true,
            hasNextStream: true,
            onRetry: {},
            onTryNextStream: {}
        )

        SwiftUIViewDiagnosticHost.render(view, width: 320, height: 180)
    }
}
