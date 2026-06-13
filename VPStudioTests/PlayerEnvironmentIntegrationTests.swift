import Foundation
import AVFoundation
import Testing
@testable import VPStudio

// MARK: - PlayerCinemaEnvironmentPolicy Integration

@Suite("PlayerCinemaEnvironmentPolicy — Engine Combinations", .serialized)
struct PlayerCinemaEnvironmentPolicyIntegrationTests {

    @Test
    func avPlayerWithPlayerInstanceCanOpen() {
        #expect(PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: .avPlayer, hasAVPlayer: true))
    }

    @Test
    func avPlayerWithoutPlayerInstanceCannotOpen() {
        #expect(!PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: .avPlayer, hasAVPlayer: false))
    }

    @Test
    func ksPlayerWithPlayerInstanceCannotOpen() {
        #expect(!PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: .ksPlayer, hasAVPlayer: true))
    }

    @Test
    func ksPlayerWithoutPlayerInstanceCannotOpen() {
        #expect(!PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: .ksPlayer, hasAVPlayer: false))
    }

    @Test
    func nilEngineWithPlayerInstanceCannotOpen() {
        #expect(!PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: nil, hasAVPlayer: true))
    }

    @Test
    func nilEngineWithoutPlayerInstanceCannotOpen() {
        #expect(!PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: nil, hasAVPlayer: false))
    }

    @Test
    func allEngineCombinationsExhaustivelyCovered() {
        let engines: [PlayerEngineKind?] = [.avPlayer, .ksPlayer, nil]
        let hasPlayerFlags = [true, false]

        for engine in engines {
            for hasPlayer in hasPlayerFlags {
                let canOpen = PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: engine, hasAVPlayer: hasPlayer)
                let expected = engine == .avPlayer && hasPlayer
                #expect(canOpen == expected,
                    "Engine: \(String(describing: engine)), hasAVPlayer: \(hasPlayer) should yield \(expected)")
            }
        }
    }

    @Test
    func menuDismissalDelayIs180Milliseconds() {
        #expect(PlayerCinemaEnvironmentPolicy.menuDismissalDelay == .milliseconds(180))
    }

    @Test
    func unavailableMessageRequiresAVPlayer() {
        #expect(PlayerCinemaEnvironmentPolicy.unavailableMessage == "Cinema Environment requires AVPlayer playback.")
    }

    @Test
    func iconNameForHDRAssets() {
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "/env/theater.hdr") == "pano")
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "/env/sky.HDR") == "pano")
    }

    @Test
    func iconNameForEXRAssets() {
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "/env/studio.exr") == "pano")
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "/env/studio.EXR") == "pano")
    }

    @Test
    func iconNameForModelAssets() {
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "/env/room.usdz") == "cube.transparent")
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "/env/room") == "cube.transparent")
    }
}

// MARK: - CinemaSettings Aspect Ratio Sync Flow

#if os(visionOS)
@Suite("CinemaSettings — Aspect Ratio Sync Flow", .serialized)
@MainActor
struct CinemaSettingsAspectRatioSyncTests {

    private func makeSettings() -> CinemaSettings {
        CinemaSettings(loadPersisted: false)
    }

    private func syncCinemaAspectRatio(_ ratio: CGFloat?, to settings: CinemaSettings) {
        guard let ratio, ratio.isFinite, ratio > 0 else { return }
        settings.videoAspectRatio = Double(ratio)
    }

    @Test
    func validPositiveRatioUpdatesVideoAspectRatio() {
        let settings = makeSettings()
        let original = settings.videoAspectRatio
        let newRatio: CGFloat = 2.39
        settings.videoAspectRatio = Double(newRatio)
        #expect(settings.videoAspectRatio == 2.39)
        #expect(settings.videoAspectRatio != original)
    }

    @Test
    func validStandard16By9RatioUpdatesVideoAspectRatio() {
        let settings = makeSettings()
        settings.videoAspectRatio = 16.0 / 9.0
        #expect(settings.videoAspectRatio == 16.0 / 9.0)
    }

    @Test
    func validStandard4By3RatioUpdatesVideoAspectRatio() {
        let settings = makeSettings()
        settings.videoAspectRatio = 4.0 / 3.0
        #expect(settings.videoAspectRatio == 4.0 / 3.0)
    }

    @Test
    func validUltrawideRatioUpdatesVideoAspectRatio() {
        let settings = makeSettings()
        settings.videoAspectRatio = 21.0 / 9.0
        #expect(settings.videoAspectRatio == 21.0 / 9.0)
    }

    @Test
    func verySmallPositiveRatioIsAccepted() {
        let settings = makeSettings()
        settings.videoAspectRatio = 0.01
        #expect(settings.videoAspectRatio == 0.01)
    }

    @Test
    func nilRatioIsRejectedBySyncLogic() {
        // Simulates syncCinemaAspectRatio(nil) early-return behavior
        let settings = makeSettings()
        let original = settings.videoAspectRatio
        syncCinemaAspectRatio(nil, to: settings)
        #expect(settings.videoAspectRatio == original)
    }

    @Test
    func nanRatioIsRejectedBySyncLogic() {
        let settings = makeSettings()
        let original = settings.videoAspectRatio
        syncCinemaAspectRatio(.nan, to: settings)
        #expect(settings.videoAspectRatio == original)
    }

    @Test
    func zeroRatioIsRejectedBySyncLogic() {
        let settings = makeSettings()
        let original = settings.videoAspectRatio
        syncCinemaAspectRatio(0, to: settings)
        #expect(settings.videoAspectRatio == original)
    }

    @Test
    func negativeRatioIsRejectedBySyncLogic() {
        let settings = makeSettings()
        let original = settings.videoAspectRatio
        syncCinemaAspectRatio(-1.78, to: settings)
        #expect(settings.videoAspectRatio == original)
    }

    @Test
    func infiniteRatioIsRejectedBySyncLogic() {
        let settings = makeSettings()
        let original = settings.videoAspectRatio
        syncCinemaAspectRatio(.infinity, to: settings)
        #expect(settings.videoAspectRatio == original)
    }

    @Test
    func negativeInfinityRatioIsRejectedBySyncLogic() {
        let settings = makeSettings()
        let original = settings.videoAspectRatio
        syncCinemaAspectRatio(-.infinity, to: settings)
        #expect(settings.videoAspectRatio == original)
    }

    @Test
    func screenSizeDerivedFromSyncedAspectRatio() {
        let settings = makeSettings()
        settings.screenWidth = 10.0
        settings.videoAspectRatio = 2.0
        #expect(settings.screenSize.width == 10.0)
        #expect(settings.screenSize.height == 5.0)
    }
}
#endif

// MARK: - AppState Immersive Lifecycle

@Suite("AppState — Immersive Lifecycle Integration", .serialized)
struct AppStateImmersiveLifecycleIntegrationTests {

    @Test
    @MainActor
    func beginImmersiveTransitionReturnsTrueWhenIdle() {
        let appState = AppState()
        #expect(appState.beginImmersiveTransition())
    }

    @Test
    @MainActor
    func beginImmersiveTransitionReturnsFalseWhenAlreadyInFlight() {
        let appState = AppState()
        #expect(appState.beginImmersiveTransition())
        #expect(!appState.beginImmersiveTransition())
    }

    @Test
    @MainActor
    func cancelImmersiveTransitionResetsInFlightFlag() {
        let appState = AppState()
        #expect(appState.beginImmersiveTransition())
        appState.cancelImmersiveTransition()
        #expect(!appState.isImmersiveTransitionInFlight)
        #expect(appState.beginImmersiveTransition())
    }

    @Test
    @MainActor
    func immersiveSpaceDidAppearSetsOpenFlag() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.cinemaEnvironment)
        #expect(appState.isImmersiveSpaceOpen)
    }

    @Test
    @MainActor
    func immersiveSpaceDidAppearSetsActiveEnvironment() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        #expect(appState.activeEnvironment == .hdriSkybox)
    }

    @Test
    @MainActor
    func immersiveSpaceDidAppearSetsCinemaEnvironment() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.cinemaEnvironment)
        #expect(appState.activeEnvironment == .cinemaEnvironment)
    }

    @Test
    @MainActor
    func immersiveSpaceDidAppearResetsTransitionInFlight() {
        let appState = AppState()
        #expect(appState.beginImmersiveTransition())
        appState.immersiveSpaceDidAppear(.customEnvironment)
        #expect(!appState.isImmersiveTransitionInFlight)
    }

    @Test
    @MainActor
    func immersiveSpaceDidAppearResetsShouldRestoreAfterSuspension() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .suspension)
        appState.immersiveSpaceDidDisappear()
        #expect(appState.shouldRestoreImmersiveAfterSuspension)
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        #expect(!appState.shouldRestoreImmersiveAfterSuspension)
    }

    @Test
    @MainActor
    func immersiveSpaceDidDisappearClearsOpenFlag() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.immersiveSpaceDidDisappear()
        #expect(!appState.isImmersiveSpaceOpen)
    }

    @Test
    @MainActor
    func immersiveSpaceDidDisappearClearsActiveEnvironment() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.cinemaEnvironment)
        appState.immersiveSpaceDidDisappear()
        #expect(appState.activeEnvironment == nil)
    }

    @Test
    @MainActor
    func immersiveSpaceDidDisappearResetsTransitionInFlight() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.customEnvironment)
        #expect(appState.beginImmersiveTransition())
        appState.stageImmersiveDismiss(reason: .userInitiated)
        appState.immersiveSpaceDidDisappear()
        #expect(!appState.isImmersiveTransitionInFlight)
    }

    @Test
    @MainActor
    func completeImmersiveDismissIfStillPendingWhenSpaceIsOpen() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.completeImmersiveDismissIfStillPending()
        #expect(!appState.isImmersiveSpaceOpen)
        #expect(appState.activeEnvironment == nil)
        #expect(!appState.isImmersiveTransitionInFlight)
    }

    @Test
    @MainActor
    func completeImmersiveDismissIfStillPendingWhenTransitionInFlight() {
        let appState = AppState()
        #expect(appState.beginImmersiveTransition())
        appState.completeImmersiveDismissIfStillPending()
        #expect(!appState.isImmersiveSpaceOpen)
        #expect(appState.activeEnvironment == nil)
        #expect(!appState.isImmersiveTransitionInFlight)
    }

    @Test
    @MainActor
    func completeImmersiveDismissIfStillPendingIsNoOpWhenIdle() {
        let appState = AppState()
        appState.completeImmersiveDismissIfStillPending()
        #expect(!appState.isImmersiveSpaceOpen)
        #expect(appState.activeEnvironment == nil)
        #expect(!appState.isImmersiveTransitionInFlight)
        #expect(!appState.shouldRestoreImmersiveAfterSuspension)
    }
}

// MARK: - AppState Player Resource Bridge

@Suite("AppState — Player Resource Bridge Integration", .serialized)
struct AppStatePlayerResourceBridgeIntegrationTests {

    @Test
    @MainActor
    func activeAVPlayerIsNilByDefault() {
        let appState = AppState()
        #expect(appState.activeAVPlayer == nil)
    }

    @Test
    @MainActor
    func activeVideoRendererIsNilByDefault() {
        let appState = AppState()
        #expect(appState.activeVideoRenderer == nil)
    }

    @Test
    @MainActor
    func activeAVPlayerWeakReferenceCanBeSet() {
        let appState = AppState()
        let player = AVPlayer()
        appState.activeAVPlayer = player
        #expect(appState.activeAVPlayer === player)
    }

    @Test
    @MainActor
    func activeVideoRendererWeakReferenceCanBeSet() {
        let appState = AppState()
        let renderer = AVSampleBufferVideoRenderer()
        appState.activeVideoRenderer = renderer
        #expect(appState.activeVideoRenderer === renderer)
    }

    @Test
    @MainActor
    func releasePlayerResourcesClearsBothWeakReferences() {
        let appState = AppState()
        let player = AVPlayer()
        let renderer = AVSampleBufferVideoRenderer()
        appState.activeAVPlayer = player
        appState.activeVideoRenderer = renderer

        appState.releasePlayerResources(clearSession: false)

        #expect(appState.activeAVPlayer == nil)
        #expect(appState.activeVideoRenderer == nil)
    }

    @Test
    @MainActor
    func releasePlayerResourcesWithClearSessionFalsePreservesSession() {
        let appState = AppState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        let preview = Fixtures.mediaPreview()
        let viewModel = DetailViewModel(appState: appState)
        let request = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)
        appState.activePlayerSession = request
        appState.fullscreenBySessionID[request.id] = true
        let player = AVPlayer()
        let renderer = AVSampleBufferVideoRenderer()
        appState.activeAVPlayer = player
        appState.activeVideoRenderer = renderer

        appState.releasePlayerResources(clearSession: false, sessionID: request.id)

        #expect(appState.activePlayerSession?.id == request.id)
        #expect(appState.fullscreenBySessionID[request.id] == true)
    }

    @Test
    @MainActor
    func releasePlayerResourcesWithClearSessionTrueClearsSession() {
        let appState = AppState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        let preview = Fixtures.mediaPreview()
        let viewModel = DetailViewModel(appState: appState)
        let request = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)
        appState.activePlayerSession = request
        appState.fullscreenBySessionID[request.id] = true
        let player = AVPlayer()
        let renderer = AVSampleBufferVideoRenderer()
        appState.activeAVPlayer = player
        appState.activeVideoRenderer = renderer

        appState.releasePlayerResources(clearSession: true, sessionID: request.id)

        #expect(appState.activePlayerSession == nil)
        #expect(appState.fullscreenBySessionID[request.id] == nil)
    }

    @Test
    @MainActor
    func releasePlayerResourcesWithoutSessionIDFallsBackToActivePlayerSession() {
        let appState = AppState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        let preview = Fixtures.mediaPreview()
        let viewModel = DetailViewModel(appState: appState)
        let request = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)
        appState.activePlayerSession = request
        appState.fullscreenBySessionID[request.id] = true

        appState.releasePlayerResources(clearSession: true)

        #expect(appState.activePlayerSession == nil)
        #expect(appState.fullscreenBySessionID[request.id] == nil)
    }

    @Test
    @MainActor
    func terminateActivePlayerSessionClearsEverything() {
        let appState = AppState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        let preview = Fixtures.mediaPreview()
        let viewModel = DetailViewModel(appState: appState)
        let request = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)
        appState.activePlayerSession = request
        appState.fullscreenBySessionID[request.id] = true
        let player = AVPlayer()
        let renderer = AVSampleBufferVideoRenderer()
        appState.activeAVPlayer = player
        appState.activeVideoRenderer = renderer

        appState.terminateActivePlayerSession()

        #expect(appState.activeAVPlayer == nil)
        #expect(appState.activeVideoRenderer == nil)
        #expect(appState.activePlayerSession == nil)
        #expect(appState.fullscreenBySessionID[request.id] == nil)
    }

    @Test
    @MainActor
    func weakReferenceDoesNotRetainPlayer() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appStateURL = repoRoot.appendingPathComponent("VPStudio/App/AppState.swift")
        let source = try String(contentsOf: appStateURL, encoding: .utf8)
        #expect(source.contains("weak var activeAVPlayer: AVPlayer?"))

        let appState = AppState()
        let player = AVPlayer()
        appState.activeAVPlayer = player
        #expect(appState.activeAVPlayer === player)
        appState.activeAVPlayer = nil
        #expect(appState.activeAVPlayer == nil)
    }

    @Test
    @MainActor
    func weakReferenceDoesNotRetainRenderer() {
        let appState = AppState()
        weak var weakRenderer: AVSampleBufferVideoRenderer?
        do {
            let renderer = AVSampleBufferVideoRenderer()
            weakRenderer = renderer
            appState.activeVideoRenderer = renderer
            #expect(appState.activeVideoRenderer === renderer)
        }
        #expect(weakRenderer == nil)
        #expect(appState.activeVideoRenderer == nil)
    }
}

// MARK: - Transition State Machine

@Suite("AppState — Transition State Machine Integration", .serialized)
struct AppStateTransitionStateMachineIntegrationTests {

    @Test
    @MainActor
    func concurrentTransitionRequestsAreRejected() {
        let appState = AppState()
        #expect(appState.beginImmersiveTransition())
        #expect(!appState.beginImmersiveTransition())
        #expect(!appState.beginImmersiveTransition())
    }

    @Test
    @MainActor
    func transitionLockReleasedAfterCancel() {
        let appState = AppState()
        #expect(appState.beginImmersiveTransition())
        appState.cancelImmersiveTransition()
        #expect(!appState.isImmersiveTransitionInFlight)
        #expect(appState.beginImmersiveTransition())
    }

    @Test
    @MainActor
    func transitionLockReleasedAfterAppear() {
        let appState = AppState()
        #expect(appState.beginImmersiveTransition())
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        #expect(!appState.isImmersiveTransitionInFlight)
        #expect(appState.beginImmersiveTransition())
    }

    @Test
    @MainActor
    func transitionLockReleasedAfterDisappear() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.customEnvironment)
        #expect(appState.beginImmersiveTransition())
        appState.stageImmersiveDismiss(reason: .userInitiated)
        appState.immersiveSpaceDidDisappear()
        #expect(!appState.isImmersiveTransitionInFlight)
        #expect(appState.beginImmersiveTransition())
    }

    @Test
    @MainActor
    func isImmersiveTransitionInFlightDefaultsToFalse() {
        let appState = AppState()
        #expect(!appState.isImmersiveTransitionInFlight)
    }

    @Test
    @MainActor
    func isImmersiveSpaceOpenDefaultsToFalse() {
        let appState = AppState()
        #expect(!appState.isImmersiveSpaceOpen)
    }

    @Test
    @MainActor
    func activeEnvironmentDefaultsToNil() {
        let appState = AppState()
        #expect(appState.activeEnvironment == nil)
    }
}

// MARK: - Environment Switching & Restore Behavior

@Suite("AppState — Environment Switching & Restore Integration", .serialized)
struct AppStateEnvironmentSwitchingIntegrationTests {

    @Test
    @MainActor
    func activeEnvironmentUpdatesThroughAllTypes() {
        let appState = AppState()
        for env in EnvironmentType.allCases {
            appState.immersiveSpaceDidAppear(env)
            #expect(appState.activeEnvironment == env)
        }
    }

    @Test
    @MainActor
    func activeEnvironmentClearsOnDisappear() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.cinemaEnvironment)
        #expect(appState.activeEnvironment == .cinemaEnvironment)
        appState.immersiveSpaceDidDisappear()
        #expect(appState.activeEnvironment == nil)
    }

    @Test
    @MainActor
    func suspensionDismissQueuesRestoreWhenSpaceIsOpen() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .suspension)
        appState.immersiveSpaceDidDisappear()
        #expect(appState.consumeSuspendedImmersiveRestoreRequest())
    }

    @Test
    @MainActor
    func suspensionDismissQueuesRestoreWhenTransitionInFlight() {
        let appState = AppState()
        #expect(appState.beginImmersiveTransition())
        appState.stageImmersiveDismiss(reason: .suspension)
        appState.immersiveSpaceDidDisappear()
        #expect(appState.consumeSuspendedImmersiveRestoreRequest())
    }

    @Test
    @MainActor
    func userInitiatedDismissDoesNotQueueRestore() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .userInitiated)
        appState.immersiveSpaceDidDisappear()
        #expect(!appState.consumeSuspendedImmersiveRestoreRequest())
    }

    @Test
    @MainActor
    func switchingEnvironmentDismissDoesNotQueueRestore() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.customEnvironment)
        appState.stageImmersiveDismiss(reason: .switchingEnvironment)
        appState.immersiveSpaceDidDisappear()
        #expect(!appState.consumeSuspendedImmersiveRestoreRequest())
    }

    @Test
    @MainActor
    func memoryPressureDismissDoesNotQueueRestore() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.customEnvironment)
        appState.stageImmersiveDismiss(reason: .memoryPressure)
        appState.immersiveSpaceDidDisappear()
        #expect(!appState.consumeSuspendedImmersiveRestoreRequest())
    }

    @Test
    @MainActor
    func playerClosedDismissDoesNotQueueRestore() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.cinemaEnvironment)
        appState.stageImmersiveDismiss(reason: .playerClosed)
        appState.immersiveSpaceDidDisappear()
        #expect(!appState.consumeSuspendedImmersiveRestoreRequest())
    }

    @Test
    @MainActor
    func suspensionWhenSpaceNotOpenDoesNotQueueRestore() {
        let appState = AppState()
        appState.stageImmersiveDismiss(reason: .suspension)
        appState.immersiveSpaceDidDisappear()
        #expect(!appState.consumeSuspendedImmersiveRestoreRequest())
    }

    @Test
    @MainActor
    func consumeSuspendedImmersiveRestoreRequestReturnsTrueOnlyOnce() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .suspension)
        appState.immersiveSpaceDidDisappear()
        #expect(appState.consumeSuspendedImmersiveRestoreRequest())
        #expect(!appState.consumeSuspendedImmersiveRestoreRequest())
    }

    @Test
    @MainActor
    func shouldRestoreImmersiveAfterSuspensionDefaultsToFalse() {
        let appState = AppState()
        #expect(!appState.shouldRestoreImmersiveAfterSuspension)
    }

    @Test
    @MainActor
    func immersiveSpaceDidDisappearWithSuspensionPendingPreservesRestoreFlag() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .suspension)
        appState.immersiveSpaceDidDisappear()
        #expect(appState.shouldRestoreImmersiveAfterSuspension)
    }

    @Test
    @MainActor
    func immersiveSpaceDidDisappearWithNonSuspensionPendingClearsRestoreFlag() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .userInitiated)
        appState.immersiveSpaceDidDisappear()
        #expect(!appState.shouldRestoreImmersiveAfterSuspension)
    }

    @Test
    @MainActor
    func immersiveSpaceDidAppearClearsRestoreFlagEvenAfterSuspension() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .suspension)
        appState.immersiveSpaceDidDisappear()
        #expect(appState.shouldRestoreImmersiveAfterSuspension)
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        #expect(!appState.shouldRestoreImmersiveAfterSuspension)
    }

    @Test
    @MainActor
    func stageImmersiveDismissPreservesEnvironmentBeforeDisappear() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.cinemaEnvironment)
        appState.stageImmersiveDismiss(reason: .suspension)
        #expect(appState.isImmersiveSpaceOpen)
        #expect(appState.activeEnvironment == .cinemaEnvironment)
    }

    @Test
    @MainActor
    func environmentSwitchesFromCustomToCinema() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.customEnvironment)
        #expect(appState.activeEnvironment == .customEnvironment)
        appState.immersiveSpaceDidDisappear()
        appState.immersiveSpaceDidAppear(.cinemaEnvironment)
        #expect(appState.activeEnvironment == .cinemaEnvironment)
    }

    @Test
    @MainActor
    func environmentSwitchesFromHDRIToCinema() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        #expect(appState.activeEnvironment == .hdriSkybox)
        appState.immersiveSpaceDidDisappear()
        appState.immersiveSpaceDidAppear(.cinemaEnvironment)
        #expect(appState.activeEnvironment == .cinemaEnvironment)
    }

    @Test
    @MainActor
    func completeImmersiveDismissAfterSuspensionPreservesRestoreFlag() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .suspension)
        appState.completeImmersiveDismissIfStillPending()
        // Suspension dismiss preserves the restore flag so the app can re-open
        // the immersive space when it returns to the foreground.
        #expect(appState.shouldRestoreImmersiveAfterSuspension)
    }
}
