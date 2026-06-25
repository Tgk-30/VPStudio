import Foundation

enum PlayerImmersiveTransitionPolicy {
    static let transitionBusyMessage = "Finish the current environment transition before changing rooms."
    static let cinemaAlreadyOpenMessage = "Cinema Environment is already open."

    static func missingAssetMessage(assetName: String) -> String {
        let trimmedName = assetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? "this environment" : "\"\(trimmedName)\""
        return "Environment file missing for \(displayName). Re-import it from Settings."
    }

    static func environmentAlreadyOpenMessage(assetName: String) -> String {
        let trimmedName = assetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? "Environment" : "\"\(trimmedName)\""
        return "\(displayName) is already open."
    }

    static func openFailedMessage(assetName: String) -> String {
        let trimmedName = assetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? "this environment" : "\"\(trimmedName)\""
        return "Could not open \(displayName). Try another environment or re-import it from Settings."
    }

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
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> EnvironmentOpenPlan {
        let normalizedRequestedAssetID = normalizedID(requestedAssetID)
        guard !normalizedRequestedAssetID.isEmpty,
              normalizedRequestedAssetID == normalizedID(selectedAssetID),
              isImmersiveSpaceOpen else {
            return .switchAndOpen
        }

        switch activeEnvironment {
        case .customEnvironment, .hdriSkybox:
            return .alreadyOpen
        case .cinemaEnvironment, nil:
            return .switchAndOpen
        }
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

    private static func normalizedID(_ id: String?) -> String {
        id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
