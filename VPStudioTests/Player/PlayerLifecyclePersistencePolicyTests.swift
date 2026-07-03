import SwiftUI
import Testing
@testable import VPStudio

@Suite("Player Lifecycle Persistence Policy")
struct PlayerLifecyclePersistencePolicyTests {

    // MARK: - persistenceAction(for:)

    @Test
    func backgroundPersistsAndStopsTimer() {
        #expect(
            PlayerLifecyclePersistencePolicy.persistenceAction(for: .background)
                == .persistAndStopTimer
        )
    }

    @Test
    func inactivePersistsProgressKeepingTimer() {
        #expect(
            PlayerLifecyclePersistencePolicy.persistenceAction(for: .inactive)
                == .persistProgress
        )
    }

    @Test
    func activeRequiresNoPersistenceAction() {
        #expect(
            PlayerLifecyclePersistencePolicy.persistenceAction(for: .active) == .none
        )
    }

    // MARK: - reanchorAction(previous:current:)

    @Test
    func returningToActiveFromBackgroundReanchors() {
        #expect(
            PlayerLifecyclePersistencePolicy.reanchorAction(previous: .background, current: .active)
                == .reanchorResume
        )
    }

    @Test
    func returningToActiveFromInactiveReanchors() {
        #expect(
            PlayerLifecyclePersistencePolicy.reanchorAction(previous: .inactive, current: .active)
                == .reanchorResume
        )
    }

    @Test
    func stayingActiveDoesNotReanchor() {
        #expect(
            PlayerLifecyclePersistencePolicy.reanchorAction(previous: .active, current: .active)
                == .none
        )
    }

    @Test
    func transitionsAwayFromActiveDoNotReanchor() {
        // Only settling back into `.active` should trigger a reanchor.
        #expect(
            PlayerLifecyclePersistencePolicy.reanchorAction(previous: .active, current: .inactive)
                == .none
        )
        #expect(
            PlayerLifecyclePersistencePolicy.reanchorAction(previous: .active, current: .background)
                == .none
        )
        #expect(
            PlayerLifecyclePersistencePolicy.reanchorAction(previous: .inactive, current: .background)
                == .none
        )
        #expect(
            PlayerLifecyclePersistencePolicy.reanchorAction(previous: .background, current: .inactive)
                == .none
        )
    }
}
