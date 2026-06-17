import SwiftUI

/// Pure mapping from a `ScenePhase` (or transition between phases) to the
/// watch-progress lifecycle action the player should take.
///
/// Keeping this logic free of view/engine state lets the headset
/// doff/don, sleep/wake, and backgrounding behavior be exhaustively unit
/// tested without spinning up SwiftUI or AVKit. `PlayerView` owns the side
/// effects (persisting to the database, stopping the periodic timer, and
/// re-seeking the engine); this policy only decides *what* should happen.
enum PlayerLifecyclePersistencePolicy {
    enum Action: Equatable {
        case none
        case persistProgress
        case persistAndStopTimer
        case reanchorResume
    }

    /// What to do when the scene settles into a given phase.
    ///
    /// - `.background` (full suspend, e.g. doff or app backgrounded): persist
    ///   the current progress and stop the periodic persistence timer so no
    ///   work runs while suspended.
    /// - `.inactive` (transient, e.g. sleep/wake or control-center pull-down):
    ///   persist progress but keep the timer alive.
    /// - `.active`: no persistence action is required on settle.
    static func persistenceAction(for phase: ScenePhase) -> Action {
        switch phase {
        case .background:
            return .persistAndStopTimer
        case .inactive:
            return .persistProgress
        case .active:
            return .none
        @unknown default:
            return .none
        }
    }

    /// What to do on the transition into a new phase. Returning to `.active`
    /// from a suspended/inactive phase means the engine may have been torn
    /// down or reset, so the resume point should be re-anchored.
    static func reanchorAction(previous: ScenePhase, current: ScenePhase) -> Action {
        guard current == .active else { return .none }
        switch previous {
        case .background, .inactive:
            return .reanchorResume
        case .active:
            return .none
        @unknown default:
            return .none
        }
    }
}
