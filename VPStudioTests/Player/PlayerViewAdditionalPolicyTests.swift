import Foundation
import Testing
@testable import VPStudio

#if os(visionOS)
@Suite("Player Environment Menu Policy - Additional Coverage")
struct PlayerEnvironmentMenuAdditionalPolicyTests {

    @Test
    func cinemaIconRequiresAnOpenImmersiveCinemaEnvironment() {
        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: true
            ) == "checkmark"
        )

        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: false
            ) == "theatermasks"
        )

        #expect(
            PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: true
            ) == "theatermasks"
        )
    }

    @Test
    func activeMenuAssetsAlwaysRenderAsCheckedRegardlessOfSourceType() {
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                isActive: true,
                sourceType: .bundled
            ) == "checkmark"
        )

        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                isActive: true,
                sourceType: .imported
            ) == "checkmark"
        )
    }

    @Test
    func compactAssetIconsNormalizeExtensionsAndHandleMissingExtensions() {
        #expect(PlayerEnvironmentMenuPolicy.compactAssetIconName(forAssetPath: "SCENE.HDR") == "pano")
        #expect(PlayerEnvironmentMenuPolicy.compactAssetIconName(forAssetPath: "scene.ExR") == "pano")
        #expect(PlayerEnvironmentMenuPolicy.compactAssetIconName(forAssetPath: "scene") == "cube.transparent")
    }
}
#endif

@Suite("Player Auto-Play Next Policy - Additional Coverage")
struct PlayerAutoplayNextAdditionalPolicyTests {

    @Test
    func idlePromptStateStartsWithDefaultCountdownAndNoTransientFlags() {
        let state = PlayerAutoplayNextPolicy.PromptState.idle(hasNextEpisode: true)

        #expect(state.hasNextEpisode)
        #expect(!state.didRequestAutoplayNext)
        #expect(!state.didCancelAutoPlayNextPrompt)
        #expect(!state.isShowingAutoPlayNextPrompt)
        #expect(!state.isResolvingAutoPlayNextEpisode)
        #expect(state.countdownRemaining == PlayerAutoplayNextPolicy.countdownDurationSeconds)
    }

    @Test
    func countdownDoesNotStartOnceItHasAlreadyStartedOrIsResolving() {
        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 595,
            duration: 600,
            hasNextEpisode: true,
            hasStartedCountdown: true,
            wasCancelled: false,
            isResolving: false
        ))

        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 595,
            duration: 600,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: false,
            isResolving: true
        ))
    }

    @Test
    func unavailableResolutionKeepsQueuedEpisodeAvailableButHidesPromptSurface() {
        let state = PlayerAutoplayNextPolicy.stateAfterFinishingResolution(
            from: PlayerAutoplayNextPolicy.PromptState(
                hasNextEpisode: true,
                didRequestAutoplayNext: true,
                didCancelAutoPlayNextPrompt: false,
                isShowingAutoPlayNextPrompt: true,
                isResolvingAutoPlayNextEpisode: true,
                countdownRemaining: 4
            ),
            outcome: .unavailable
        )

        #expect(state.hasNextEpisode)
        #expect(state.didRequestAutoplayNext)
        #expect(!state.didCancelAutoPlayNextPrompt)
        #expect(!state.isShowingAutoPlayNextPrompt)
        #expect(!state.isResolvingAutoPlayNextEpisode)
        #expect(state.countdownRemaining == 4)
    }

    @Test
    func resolutionPlanPreservesNilPreferredServiceWhileRebuildingTheNextEpisodeContext() throws {
        let currentRecoveryContext = try #require(StreamRecoveryContext(infoHash: "ABC123"))
        let plan = PlayerAutoplayNextResolutionPolicy.resolutionPlan(
            autoPlayNextEnabled: true,
            nextEpisode: PlayerSessionRequest.NextEpisodeCandidate(
                episodeId: "ep-9",
                seasonNumber: 2,
                episodeNumber: 9,
                title: "Episode 9"
            ),
            currentRecoveryContext: currentRecoveryContext
        )

        guard case .resolve(let nextContext) = plan else {
            Issue.record("Expected next episode recovery to be resolved from the current context")
            return
        }

        #expect(nextContext.infoHash == "abc123")
        #expect(nextContext.preferredService == nil)
        #expect(nextContext.seasonNumber == 2)
        #expect(nextContext.episodeNumber == 9)
    }
}

@Suite("Player Lifecycle Policy - Additional Coverage")
struct PlayerLifecycleAdditionalPolicyTests {

    @Test
    func backNavigationPolicyMatchesPlatformExpectations() {
        #if os(macOS) || os(visionOS)
        #expect(PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack)
        #else
        #expect(!PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack)
        #endif

        #expect(PlayerLifecyclePolicy.dismissesCurrentPresentationOnBack)
    }
}
