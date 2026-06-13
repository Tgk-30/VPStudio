import Foundation

enum PlayerImmersiveTransitionPolicy {
    enum EnvironmentOpenPlan: Equatable {
        case alreadyOpen
        case switchAndOpen
    }

    enum CinemaOpenPlan: Equatable {
        case unavailable(message: String)
        case alreadyOpen
        case open
    }

    enum TransitionReadiness: Equatable {
        case begin
        case skip
    }

    enum OpenCompletionAction: Equatable {
        case enterImmersiveMode
        case cancelTransition
    }

    enum ActiveRestorePlan: Equatable {
        case skip
        case openSelectedAsset
    }

    enum MemoryPressurePlan: Equatable {
        case ignore
        case dismiss(message: String, reason: ImmersiveDismissReason)
    }

    static func environmentOpenPlan(
        requestedAssetID: String,
        selectedAssetID: String?,
        isImmersiveSpaceOpen: Bool
    ) -> EnvironmentOpenPlan {
        requestedAssetID == selectedAssetID && isImmersiveSpaceOpen ? .alreadyOpen : .switchAndOpen
    }

    static func cinemaOpenPlan(
        canOpen: Bool,
        hasAVPlayer: Bool,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> CinemaOpenPlan {
        guard canOpen, hasAVPlayer else {
            return .unavailable(message: PlayerCinemaEnvironmentPolicy.unavailableMessage)
        }

        if activeEnvironment == .cinemaEnvironment && isImmersiveSpaceOpen {
            return .alreadyOpen
        }

        return .open
    }

    static func openReadiness(isTransitionInFlight: Bool) -> TransitionReadiness {
        isTransitionInFlight ? .skip : .begin
    }

    static func dismissReadiness(
        isImmersiveSpaceOpen: Bool,
        isTransitionInFlight: Bool
    ) -> TransitionReadiness {
        isImmersiveSpaceOpen && !isTransitionInFlight ? .begin : .skip
    }

    static func completionAction(didOpen: Bool) -> OpenCompletionAction {
        didOpen ? .enterImmersiveMode : .cancelTransition
    }

    static func activeRestorePlan(
        hasRestoreRequest: Bool,
        hasSelectedAsset: Bool
    ) -> ActiveRestorePlan {
        hasRestoreRequest && hasSelectedAsset ? .openSelectedAsset : .skip
    }

    static func memoryPressurePlan(isImmersiveSpaceOpen: Bool) -> MemoryPressurePlan {
        guard isImmersiveSpaceOpen else { return .ignore }
        return .dismiss(
            message: "Memory pressure detected. Closed immersive space to stabilize playback.",
            reason: .memoryPressure
        )
    }
}
