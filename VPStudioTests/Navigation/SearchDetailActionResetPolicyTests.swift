import Foundation
import SwiftUI
import Testing
@testable import VPStudio

// MARK: - BUG 7 regression coverage
//
// On the Search tab, using "Play" on an AI Pick sets
// `appState.searchDetailInitialAction = .playBestCached` then pushes detail. Pressing
// Back must reset the companion action — otherwise a SUBSEQUENT plain row tap inherits
// the stale `.playBestCached` and auto-plays instead of opening Detail normally
// (regression from the one-tap-play work, f62f2e8).
//
// The fix lives in `SearchView`'s `searchSelection` binding setter, which delegates the
// reset decision to `SearchDetailActionResetPolicy`. These tests cover both the pure
// policy and the runtime contract through a faithful reconstruction of that binding.

@Suite("Search Detail Action Reset Policy")
struct SearchDetailActionResetPolicyTests {

    @Test
    func clearingSelectionResetsActionToNone() {
        let resolved = SearchDetailActionResetPolicy.resolvedAction(
            forNewSelection: nil,
            intendedAction: .playBestCached
        )
        #expect(resolved == .none)
    }

    @Test
    func clearingSelectionResetsEvenWhenAlreadyNone() {
        let resolved = SearchDetailActionResetPolicy.resolvedAction(
            forNewSelection: nil,
            intendedAction: .none
        )
        #expect(resolved == .none)
    }

    @Test
    func nonNilSelectionPreservesPlayBestCached() {
        let preview = MediaPreview(id: "tt-ai-pick", type: .movie, title: "AI Pick")
        let resolved = SearchDetailActionResetPolicy.resolvedAction(
            forNewSelection: preview,
            intendedAction: .playBestCached
        )
        #expect(resolved == .playBestCached)
    }

    @Test
    func nonNilSelectionPreservesNoneForPlainTap() {
        let preview = MediaPreview(id: "tt-plain", type: .movie, title: "Plain Result")
        let resolved = SearchDetailActionResetPolicy.resolvedAction(
            forNewSelection: preview,
            intendedAction: .none
        )
        #expect(resolved == .none)
    }
}

// MARK: - Runtime contract through the navigation binding

@Suite("Search Detail Action Reset - Runtime Contract", .serialized)
struct SearchDetailActionResetRuntimeTests {

    /// Reconstructs `SearchView.searchSelection`'s setter behavior verbatim against a
    /// real `AppState`. If the production binding diverges from this, the runtime bug
    /// returns — so this is intentionally a behavioral mirror, not a re-implementation.
    @MainActor
    private func makeSearchSelectionBinding(_ appState: AppState) -> Binding<MediaPreview?> {
        Binding(
            get: { appState.searchDetailSelection },
            set: { newValue in
                appState.searchDetailInitialAction = SearchDetailActionResetPolicy.resolvedAction(
                    forNewSelection: newValue,
                    intendedAction: appState.searchDetailInitialAction
                )
                appState.searchDetailSelection = newValue
            }
        )
    }

    @Test @MainActor
    func backNavigationViaBindingResetsStaleAction() {
        let appState = AppState()
        let binding = makeSearchSelectionBinding(appState)

        // AI Pick "Play": action set, then detail pushed.
        appState.searchDetailInitialAction = .playBestCached
        binding.wrappedValue = MediaPreview(id: "tt-ai", type: .movie, title: "AI Pick")
        #expect(appState.searchDetailInitialAction == .playBestCached)
        #expect(appState.searchDetailSelection != nil)

        // Back-nav: navigationDestination clears the binding.
        binding.wrappedValue = nil

        #expect(appState.searchDetailSelection == nil)
        #expect(appState.searchDetailInitialAction == .none)
    }

    @Test @MainActor
    func plainTapAfterBackNavigationDoesNotInheritStaleAction() {
        let appState = AppState()
        let binding = makeSearchSelectionBinding(appState)

        // 1. AI Pick "Play".
        appState.searchDetailInitialAction = .playBestCached
        binding.wrappedValue = MediaPreview(id: "tt-ai", type: .movie, title: "AI Pick")

        // 2. Back.
        binding.wrappedValue = nil
        #expect(appState.searchDetailInitialAction == .none)

        // 3. Subsequent plain row tap inherits no stale action and opens Detail normally.
        binding.wrappedValue = MediaPreview(id: "tt-plain", type: .series, title: "Plain Result")
        #expect(appState.searchDetailSelection?.id == "tt-plain")
        #expect(appState.searchDetailInitialAction == .none)
    }
}
