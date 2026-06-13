import Testing
@testable import VPStudio

@Suite("Player Immersive Transition Policy")
struct PlayerImmersiveTransitionPolicyTests {
    @Test
    func environmentOpenPlanSkipsOnlyWhenSelectedAssetIsAlreadyOpen() {
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: "theater",
                isImmersiveSpaceOpen: true
            ) == .alreadyOpen
        )

        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: "theater",
                isImmersiveSpaceOpen: false
            ) == .switchAndOpen
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: "lounge",
                isImmersiveSpaceOpen: true
            ) == .switchAndOpen
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: nil,
                isImmersiveSpaceOpen: true
            ) == .switchAndOpen
        )
    }

    @Test
    func cinemaOpenPlanRequiresCompatibleAVPlayerPlayback() {
        #expect(
            PlayerImmersiveTransitionPolicy.cinemaOpenPlan(
                canOpen: false,
                hasAVPlayer: true,
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ) == .unavailable(message: PlayerCinemaEnvironmentPolicy.unavailableMessage)
        )
        #expect(
            PlayerImmersiveTransitionPolicy.cinemaOpenPlan(
                canOpen: true,
                hasAVPlayer: false,
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ) == .unavailable(message: PlayerCinemaEnvironmentPolicy.unavailableMessage)
        )
        #expect(
            PlayerImmersiveTransitionPolicy.cinemaOpenPlan(
                canOpen: false,
                hasAVPlayer: false,
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: true
            ) == .unavailable(message: PlayerCinemaEnvironmentPolicy.unavailableMessage)
        )
    }

    @Test
    func cinemaOpenPlanSkipsAlreadyOpenCinemaAndOtherwiseOpens() {
        #expect(
            PlayerImmersiveTransitionPolicy.cinemaOpenPlan(
                canOpen: true,
                hasAVPlayer: true,
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: true
            ) == .alreadyOpen
        )
        #expect(
            PlayerImmersiveTransitionPolicy.cinemaOpenPlan(
                canOpen: true,
                hasAVPlayer: true,
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: false
            ) == .open
        )
        #expect(
            PlayerImmersiveTransitionPolicy.cinemaOpenPlan(
                canOpen: true,
                hasAVPlayer: true,
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: true
            ) == .open
        )
        #expect(
            PlayerImmersiveTransitionPolicy.cinemaOpenPlan(
                canOpen: true,
                hasAVPlayer: true,
                activeEnvironment: nil,
                isImmersiveSpaceOpen: true
            ) == .open
        )
    }

    @Test
    func openReadinessSkipsWhenTransitionIsAlreadyInFlight() {
        #expect(PlayerImmersiveTransitionPolicy.openReadiness(isTransitionInFlight: false) == .begin)
        #expect(PlayerImmersiveTransitionPolicy.openReadiness(isTransitionInFlight: true) == .skip)
    }

    @Test
    func dismissReadinessRequiresOpenSpaceAndNoInFlightTransition() {
        #expect(
            PlayerImmersiveTransitionPolicy.dismissReadiness(
                isImmersiveSpaceOpen: true,
                isTransitionInFlight: false
            ) == .begin
        )
        #expect(
            PlayerImmersiveTransitionPolicy.dismissReadiness(
                isImmersiveSpaceOpen: false,
                isTransitionInFlight: false
            ) == .skip
        )
        #expect(
            PlayerImmersiveTransitionPolicy.dismissReadiness(
                isImmersiveSpaceOpen: true,
                isTransitionInFlight: true
            ) == .skip
        )
        #expect(
            PlayerImmersiveTransitionPolicy.dismissReadiness(
                isImmersiveSpaceOpen: false,
                isTransitionInFlight: true
            ) == .skip
        )
    }

    @Test
    func completionActionEntersOnlyAfterOpenResult() {
        #expect(PlayerImmersiveTransitionPolicy.completionAction(didOpen: true) == .enterImmersiveMode)
        #expect(PlayerImmersiveTransitionPolicy.completionAction(didOpen: false) == .cancelTransition)
    }

    @Test
    func activeRestorePlanRequiresRestoreRequestAndSelectedAsset() {
        #expect(
            PlayerImmersiveTransitionPolicy.activeRestorePlan(
                hasRestoreRequest: true,
                hasSelectedAsset: true
            ) == .openSelectedAsset
        )
        #expect(
            PlayerImmersiveTransitionPolicy.activeRestorePlan(
                hasRestoreRequest: false,
                hasSelectedAsset: true
            ) == .skip
        )
        #expect(
            PlayerImmersiveTransitionPolicy.activeRestorePlan(
                hasRestoreRequest: true,
                hasSelectedAsset: false
            ) == .skip
        )
        #expect(
            PlayerImmersiveTransitionPolicy.activeRestorePlan(
                hasRestoreRequest: false,
                hasSelectedAsset: false
            ) == .skip
        )
    }

    @Test
    func memoryPressurePlanDismissesOnlyWhenImmersiveSpaceIsOpen() {
        #expect(PlayerImmersiveTransitionPolicy.memoryPressurePlan(isImmersiveSpaceOpen: false) == .ignore)
        #expect(
            PlayerImmersiveTransitionPolicy.memoryPressurePlan(isImmersiveSpaceOpen: true) == .dismiss(
                message: "Memory pressure detected. Closed immersive space to stabilize playback.",
                reason: .memoryPressure
            )
        )
    }
}
