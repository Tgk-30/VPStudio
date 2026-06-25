import SwiftUI
import Testing
@testable import VPStudio

@Suite("Player Startup State Overlay View")
@MainActor
struct PlayerStartupStateOverlayViewTests {
    @Test
    func failureOverlayPolicyKeepsCardCompactAndLegible() {
        #expect(PlayerStartupFailureOverlayPolicy.maxWidth == 420)
        #expect(PlayerStartupFailureOverlayPolicy.cornerRadius == 12)
        #expect(PlayerStartupFailureOverlayPolicy.horizontalPadding == 24)
        #expect(PlayerStartupFailureOverlayPolicy.verticalPadding == 20)
        #expect(PlayerStartupFailureOverlayPolicy.messageLineLimit == 4)
    }

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
    func failureOverlayRendersLongCopyInNarrowPlayerSurface() {
        let view = ZStack {
            Color.black
            PlayerStartupStateOverlayView(
                playbackState: .failed,
                title: "Playback Failed While Opening Stream",
                message: String(
                    repeating: "The selected stream stopped responding before the player could recover. ",
                    count: 12
                ) + "Try the next available source.",
                hasPlayedOnce: false,
                hasNextStream: true,
                onRetry: {},
                onTryNextStream: {}
            )
            .padding()
        }

        SwiftUIViewDiagnosticHost.render(view, width: 360, height: 280)
    }

    @Test
    func failureOverlayCapsDiagnosticMessageCopy() throws {
        let source = try sourceContents(of: "VPStudio/Views/Windows/Player/PlayerStartupStateOverlayView.swift")

        #expect(source.contains(".lineLimit(PlayerStartupFailureOverlayPolicy.messageLineLimit)"))
        #expect(source.contains(".truncationMode(.tail)"))
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

    private func sourceContents(of relativePath: String) throws -> String {
        let root = repoRootURL()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repoRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }
}
