import Testing
@testable import VPStudio

@Suite("Player Immersive Transition Policy")
struct PlayerImmersiveTransitionPolicyTests {
    @Test
    func openFailedMessageNamesAssetOrFallsBackToGenericCopy() {
        #expect(
            PlayerImmersiveTransitionPolicy.openFailedMessage(assetName: "  Moon Room  ")
                == "Could not open \"Moon Room\". Try another environment or re-import it from Settings."
        )
        #expect(
            PlayerImmersiveTransitionPolicy.openFailedMessage(assetName: "   ")
                == "Could not open this environment. Try another environment or re-import it from Settings."
        )
    }

    @Test
    func environmentOpenPlanSkipsOnlyWhenSelectedAssetIsAlreadyOpen() {
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: "theater",
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: true
            ) == .alreadyOpen
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: " theater ",
                selectedAssetID: "\ntheater\t",
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: true
            ) == .alreadyOpen
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "   ",
                selectedAssetID: "   ",
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: true
            ) == .switchAndOpen
        )

        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: "theater",
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: false
            ) == .switchAndOpen
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: "lounge",
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: true
            ) == .switchAndOpen
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: nil,
                activeEnvironment: .customEnvironment,
                isImmersiveSpaceOpen: true
            ) == .switchAndOpen
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: "theater",
                activeEnvironment: .hdriSkybox,
                isImmersiveSpaceOpen: true
            ) == .alreadyOpen
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: "theater",
                activeEnvironment: .cinemaEnvironment,
                isImmersiveSpaceOpen: true
            ) == .switchAndOpen
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentOpenPlan(
                requestedAssetID: "theater",
                selectedAssetID: "theater",
                activeEnvironment: nil,
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
        #expect(PlayerImmersiveTransitionPolicy.transitionBusyMessage.contains("Finish the current environment transition"))
    }

    @Test
    func missingAssetMessageNamesEnvironmentWhenAvailable() {
        #expect(
            PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: "Lunar Theater")
                == "Environment file missing for \"Lunar Theater\". Re-import it from Settings."
        )
        #expect(
            PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: "  ")
                == "Environment file missing for this environment. Re-import it from Settings."
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentAlreadyOpenMessage(assetName: "Lunar Theater")
                == "\"Lunar Theater\" is already open."
        )
        #expect(
            PlayerImmersiveTransitionPolicy.environmentAlreadyOpenMessage(assetName: "  ")
                == "Environment is already open."
        )
        #expect(PlayerImmersiveTransitionPolicy.cinemaAlreadyOpenMessage == "Cinema Environment is already open.")
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
