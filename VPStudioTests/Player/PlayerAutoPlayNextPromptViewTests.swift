import SwiftUI
import Testing
@testable import VPStudio

@Suite("Player Auto-Play Next Prompt View")
@MainActor
struct PlayerAutoPlayNextPromptViewTests {
    @Test
    func resolvingStateDimsPromptActions() {
        #expect(PlayerAutoPlayNextPromptStylePolicy.primaryButtonOpacity(isResolving: false) == 1.0)
        #expect(PlayerAutoPlayNextPromptStylePolicy.primaryButtonOpacity(isResolving: true) < 1.0)
        #expect(PlayerAutoPlayNextPromptStylePolicy.primaryButtonBackgroundOpacity(isResolving: true) < 1.0)
        #expect(PlayerAutoPlayNextPromptStylePolicy.secondaryButtonOpacity(isResolving: true) < 1.0)
    }

    @Test
    func promptRendersCountdownAndResolvingStatesWithoutTriggeringActions() {
        let nextEpisode = PlayerSessionRequest.NextEpisodeCandidate(
            episodeId: "next-episode",
            seasonNumber: 2,
            episodeNumber: 4,
            title: "The Next Signal"
        )
        var playNowCount = 0
        var cancelCount = 0

        let view = VStack(spacing: 12) {
            PlayerAutoPlayNextPromptView(
                nextEpisode: nextEpisode,
                remainingSeconds: 8,
                isResolving: false,
                onPlayNow: { playNowCount += 1 },
                onCancel: { cancelCount += 1 }
            )

            PlayerAutoPlayNextPromptView(
                nextEpisode: nextEpisode,
                remainingSeconds: 0,
                isResolving: true,
                onPlayNow: { playNowCount += 1 },
                onCancel: { cancelCount += 1 }
            )
        }
        .padding()
        .background(Color.black)

        SwiftUIViewDiagnosticHost.render(view, width: 520, height: 300)

        #expect(playNowCount == 0)
        #expect(cancelCount == 0)
    }

    @Test
    func countdownRingRendersNumericAndResolvingBranches() {
        let view = HStack(spacing: 16) {
            PlayerAutoPlayCountdownRing(
                progress: PlayerAutoplayNextPolicy.countdownProgress(remainingSeconds: 10),
                remainingSeconds: 10,
                isResolving: false
            )

            PlayerAutoPlayCountdownRing(
                progress: PlayerAutoplayNextPolicy.countdownProgress(remainingSeconds: 0),
                remainingSeconds: 0,
                isResolving: true
            )
        }
        .padding()
        .background(Color.black)

        SwiftUIViewDiagnosticHost.render(view, width: 180, height: 110)
    }
}
