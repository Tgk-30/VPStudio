import Foundation
import AVFoundation
import Testing
@testable import VPStudio

// MARK: - AppState.releasePlayerResources

@Suite("AppState - Player Resource Release", .serialized)
@MainActor
struct AppStatePlayerResourceReleaseTests {

    @Test
    func releasePlayerResourcesClearsActiveAVPlayer() {
        let appState = AppState()
        let player = AVPlayer()
        appState.activeAVPlayer = player
        #expect(appState.activeAVPlayer != nil)

        appState.releasePlayerResources(clearSession: false)
        #expect(appState.activeAVPlayer == nil)
    }

    @Test
    func releasePlayerResourcesClearsActiveVideoRenderer() {
        let appState = AppState()
        let renderer = AVSampleBufferVideoRenderer()
        appState.activeVideoRenderer = renderer
        #expect(appState.activeVideoRenderer != nil)

        appState.releasePlayerResources(clearSession: false)
        #expect(appState.activeVideoRenderer == nil)
    }

    @Test
    func releasePlayerResourcesClearsSessionWhenClearSessionTrue() {
        let appState = AppState()
        let request = PlayerSessionRequest(
            stream: Fixtures.stream(),
            mediaTitle: "Test",
            mediaId: "tt123"
        )
        appState.activePlayerSession = request
        appState.fullscreenBySessionID[request.id] = true

        appState.releasePlayerResources(clearSession: true, sessionID: request.id)

        #expect(appState.activePlayerSession == nil)
        #expect(appState.fullscreenBySessionID[request.id] == nil)
    }

    @Test
    func releasePlayerResourcesPreservesSessionWhenClearSessionFalse() {
        let appState = AppState()
        let request = PlayerSessionRequest(
            stream: Fixtures.stream(),
            mediaTitle: "Test",
            mediaId: "tt123"
        )
        appState.activePlayerSession = request
        appState.fullscreenBySessionID[request.id] = true

        appState.releasePlayerResources(clearSession: false, sessionID: request.id)

        #expect(appState.activePlayerSession?.id == request.id)
        #expect(appState.fullscreenBySessionID[request.id] == true)
    }

    @Test
    func releasePlayerResourcesPreservesImmersiveModeWhenSessionNotCleared() {
        let appState = AppState()
        let request = PlayerSessionRequest(
            stream: Fixtures.stream(),
            mediaTitle: "Test",
            mediaId: "tt123"
        )
        appState.activePlayerSession = request
        appState.spatialAudioManager.enterImmersiveMode()

        appState.releasePlayerResources(clearSession: false, sessionID: request.id)

        #expect(appState.spatialAudioManager.isImmersiveMode)
    }

    @Test
    func releasePlayerResourcesClearsFullscreenForTargetSessionID() {
        let appState = AppState()
        let id1 = UUID()
        let id2 = UUID()
        appState.fullscreenBySessionID[id1] = true
        appState.fullscreenBySessionID[id2] = false

        appState.releasePlayerResources(clearSession: true, sessionID: id1)

        #expect(appState.fullscreenBySessionID[id1] == nil)
        #expect(appState.fullscreenBySessionID[id2] == false)
    }

    @Test
    func releasePlayerResourcesClearsFullscreenForActiveSessionWhenNoSessionIDProvided() {
        let appState = AppState()
        let request = PlayerSessionRequest(
            stream: Fixtures.stream(),
            mediaTitle: "Test",
            mediaId: "tt123"
        )
        appState.activePlayerSession = request
        appState.fullscreenBySessionID[request.id] = true

        appState.releasePlayerResources(clearSession: true)

        #expect(appState.fullscreenBySessionID[request.id] == nil)
    }

    @Test
    func releasePlayerResourcesPreservesActiveSessionWhenSessionIDMismatches() {
        let appState = AppState()
        let activeSession = PlayerSessionRequest(
            stream: Fixtures.stream(),
            mediaTitle: "Active Session",
            mediaId: "active"
        )
        let staleSessionID = UUID()
        appState.fullscreenBySessionID[activeSession.id] = true
        appState.fullscreenBySessionID[staleSessionID] = true
        appState.activePlayerSession = activeSession
        appState.isMainWindowSuppressedForPlayer = true
        appState.shouldRestoreImmersiveAfterSuspension = true
        appState.isImmersiveTransitionInFlight = true

        appState.releasePlayerResources(clearSession: true, sessionID: staleSessionID)

        #expect(appState.activePlayerSession?.id == activeSession.id)
        #expect(appState.fullscreenBySessionID[staleSessionID] == nil)
        #expect(appState.fullscreenBySessionID[activeSession.id] == true)
        #expect(appState.isMainWindowSuppressedForPlayer)
        #expect(appState.shouldRestoreImmersiveAfterSuspension)
        #expect(appState.isImmersiveTransitionInFlight)
    }

    @Test
    func releasePlayerResourcesPreservesImmersiveModeWhenMismatchedSessionIDIsCleared() {
        let appState = AppState()
        let activeSession = PlayerSessionRequest(
            stream: Fixtures.stream(),
            mediaTitle: "Active Session",
            mediaId: "active"
        )
        let staleSessionID = UUID()
        appState.activePlayerSession = activeSession
        appState.spatialAudioManager.enterImmersiveMode()

        appState.releasePlayerResources(clearSession: true, sessionID: staleSessionID)

        #expect(appState.activePlayerSession?.id == activeSession.id)
        #expect(appState.spatialAudioManager.isImmersiveMode)
    }

    @Test
    func releasePlayerResourcesDoesNotClearFullscreenForOtherSessions() {
        let appState = AppState()
        let activeSessionID = UUID()
        let otherSessionID = UUID()
        appState.activePlayerSession = PlayerSessionRequest(
            id: activeSessionID,
            stream: Fixtures.stream(),
            mediaTitle: "Test",
            mediaId: "tt123"
        )
        appState.fullscreenBySessionID[activeSessionID] = true
        appState.fullscreenBySessionID[otherSessionID] = true

        appState.releasePlayerResources(clearSession: true, sessionID: activeSessionID)

        #expect(appState.fullscreenBySessionID[otherSessionID] == true)
    }

    @Test
    func releasePlayerResourcesClearsAllPlaybackBridgeRefsEvenWhenClearSessionFalse() {
        let appState = AppState()
        let player = AVPlayer()
        let renderer = AVSampleBufferVideoRenderer()
        appState.activeAVPlayer = player
        appState.activeVideoRenderer = renderer
        appState.activePlayerSession = PlayerSessionRequest(
            stream: Fixtures.stream(),
            mediaTitle: "Test",
            mediaId: "tt123"
        )

        appState.releasePlayerResources(clearSession: false)

        #expect(appState.activeAVPlayer == nil)
        #expect(appState.activeVideoRenderer == nil)
        #expect(appState.activePlayerSession != nil)
    }
}

// MARK: - AppState.terminateActivePlayerSession

@Suite("AppState - Terminate Active Player Session", .serialized)
@MainActor
struct AppStateTerminatePlayerSessionTests {

    @Test
    func terminateActivePlayerSessionClearsAVPlayer() {
        let appState = AppState()
        let player = AVPlayer()
        appState.activeAVPlayer = player
        appState.terminateActivePlayerSession()
        #expect(appState.activeAVPlayer == nil)
    }

    @Test
    func terminateActivePlayerSessionClearsVideoRenderer() {
        let appState = AppState()
        let renderer = AVSampleBufferVideoRenderer()
        appState.activeVideoRenderer = renderer
        appState.terminateActivePlayerSession()
        #expect(appState.activeVideoRenderer == nil)
    }

    @Test
    func terminateActivePlayerSessionClearsActiveSession() {
        let appState = AppState()
        let request = PlayerSessionRequest(
            stream: Fixtures.stream(),
            mediaTitle: "Test",
            mediaId: "tt123"
        )
        appState.activePlayerSession = request
        appState.fullscreenBySessionID[request.id] = true

        appState.terminateActivePlayerSession()

        #expect(appState.activePlayerSession == nil)
        #expect(appState.fullscreenBySessionID[request.id] == nil)
    }

    @Test
    func terminateActivePlayerSessionIsEquivalentToReleaseWithClearSessionTrue() {
        let appState1 = AppState()
        let appState2 = AppState()
        let player = AVPlayer()
        let renderer = AVSampleBufferVideoRenderer()
        let request = PlayerSessionRequest(
            stream: Fixtures.stream(),
            mediaTitle: "Test",
            mediaId: "tt123"
        )

        appState1.activeAVPlayer = player
        appState1.activeVideoRenderer = renderer
        appState1.activePlayerSession = request
        appState1.fullscreenBySessionID[request.id] = true

        appState2.activeAVPlayer = player
        appState2.activeVideoRenderer = renderer
        appState2.activePlayerSession = request
        appState2.fullscreenBySessionID[request.id] = true

        appState1.terminateActivePlayerSession()
        appState2.releasePlayerResources(clearSession: true)

        #expect(appState1.activeAVPlayer == appState2.activeAVPlayer)
        #expect(appState1.activeVideoRenderer == appState2.activeVideoRenderer)
        #expect(appState1.activePlayerSession == appState2.activePlayerSession)
        #expect(appState1.fullscreenBySessionID == appState2.fullscreenBySessionID)
    }
}

// MARK: - Weak Reference Behavior

@Suite("AppState - Weak Reference Memory Safety", .serialized)
@MainActor
struct AppStateWeakReferenceTests {

    @Test
    func activeAVPlayerReturnsNilAfterPlayerIsReleased() {
        let appState = AppState()
        weak var weakPlayer: AVPlayer?

        autoreleasepool {
            let player = AVPlayer()
            weakPlayer = player
            appState.activeAVPlayer = player
            #expect(appState.activeAVPlayer != nil)
        }

        // AVPlayer can be retained by internal frameworks on visionOS;
        // briefly spin the run loop to allow deallocation under load.
        for _ in 0..<20 {
            if weakPlayer == nil { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        #expect(weakPlayer == nil)
        #expect(appState.activeAVPlayer == nil)
    }

    @Test
    func activeVideoRendererReturnsNilAfterRendererIsReleased() {
        let appState = AppState()
        weak var weakRenderer: AVSampleBufferVideoRenderer?

        autoreleasepool {
            let renderer = AVSampleBufferVideoRenderer()
            weakRenderer = renderer
            appState.activeVideoRenderer = renderer
            #expect(appState.activeVideoRenderer != nil)
        }

        #expect(weakRenderer == nil)
        #expect(appState.activeVideoRenderer == nil)
    }

    @Test
    func activeAVPlayerCanBeReassigned() {
        let appState = AppState()
        let player1 = AVPlayer()
        let player2 = AVPlayer()

        appState.activeAVPlayer = player1
        #expect(appState.activeAVPlayer === player1)

        appState.activeAVPlayer = player2
        #expect(appState.activeAVPlayer === player2)
    }

    @Test
    func activeVideoRendererCanBeReassigned() {
        let appState = AppState()
        let renderer1 = AVSampleBufferVideoRenderer()
        let renderer2 = AVSampleBufferVideoRenderer()

        appState.activeVideoRenderer = renderer1
        #expect(appState.activeVideoRenderer === renderer1)

        appState.activeVideoRenderer = renderer2
        #expect(appState.activeVideoRenderer === renderer2)
    }
}

// MARK: - PlayerView cleanupPlayback Contract

@Suite("PlayerView - cleanupPlayback Contract")
struct PlayerViewCleanupPlaybackContractTests {

    @Test
    func cleanupPlaybackRemovesPeriodicTimeObserver() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)
        let observerHelperBody = try functionBody(named: "removeAVTimeObserverIfNeeded", in: source)

        #expect(body.contains("removeAVTimeObserverIfNeeded()"))
        #expect(observerHelperBody.contains("timeObserverToken"))
        #expect(observerHelperBody.contains("avTimeObserverHooks.removeTimeObserver(player, token)"))
        #expect(observerHelperBody.contains("player.removeTimeObserver(token)"))
        #expect(observerHelperBody.contains("timeObserverToken = nil"))
        #expect(observerHelperBody.contains("timeObserverPlayer = nil"))
    }

    @Test
    func cleanupPlaybackCallsAPMPInjectorStop() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)

        #expect(body.contains("apmpInjector.stop()"))
        #expect(body.contains("isAPMPActive = false"))
    }

    @Test
    func cleanupPlaybackCancelsAndNilsAudioTrackRefreshTask() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)

        let cancelRange = try requiredRange(of: "audioTrackRefreshTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "audioTrackRefreshTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func cleanupPlaybackCancelsAndNilsAVMediaOptionRefreshTask() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)

        let cancelRange = try requiredRange(of: "avMediaOptionRefreshTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "avMediaOptionRefreshTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func cleanupPlaybackCancelsAndNilsSubtitleCatalogTask() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)

        let cancelRange = try requiredRange(of: "subtitleCatalogTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "subtitleCatalogTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func cleanupPlaybackCancelsAndNilsSubtitleDownloadTask() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)

        let cancelRange = try requiredRange(of: "subtitleDownloadTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "subtitleDownloadTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func cleanupPlaybackPausesAndNilsAVPlayer() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)

        #expect(body.contains("avPlayer?.pause()"))
        #expect(body.contains("avPlayer = nil"))
    }

    @Test
    func cleanupPlaybackClearsKSPlayerCallbacks() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)

        #expect(body.contains("ksPlayerCoordinator?.onStateChanged = nil"))
        #expect(body.contains("ksPlayerCoordinator?.onPlay = nil"))
        #expect(body.contains("ksPlayerCoordinator?.onFinish = nil"))
    }

    @Test
    func cleanupPlaybackCallsReleasePlayerResources() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)

        #expect(body.contains("appState.releasePlayerResources("))
    }

    @Test
    func cleanupPlaybackResetsEngineState() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)

        #expect(body.contains("engine.resetSessionState()"))
        #expect(body.contains("engine.isPlaying = false"))
        #expect(body.contains("engine.isBuffering = false"))
    }

    @Test
    func cleanupPlaybackClearsSubtitleServiceState() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cleanupPlayback", in: source)

        #expect(body.contains("subtitleService = nil"))
        #expect(body.contains("subtitleServiceAPIKey = nil"))
    }
}

// MARK: - PlayerView Task Teardown Contracts

@Suite("PlayerView - Task Teardown Contracts")
struct PlayerViewTaskTeardownContractTests {

    @Test
    func closePlayerCancelsInitialPlayerStateTaskBeforeNil() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "closePlayer", in: source)

        let cancelRange = try requiredRange(of: "initialPlayerStateTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "initialPlayerStateTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func closePlayerCancelsPreparePlaybackTaskBeforeNil() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "closePlayer", in: source)

        let cancelRange = try requiredRange(of: "preparePlaybackTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "preparePlaybackTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func closePlayerCancelsSubtitleCatalogTaskBeforeNil() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "closePlayer", in: source)

        let cancelRange = try requiredRange(of: "subtitleCatalogTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "subtitleCatalogTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func closePlayerCancelsSubtitleDownloadTaskBeforeNil() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "closePlayer", in: source)

        let cancelRange = try requiredRange(of: "subtitleDownloadTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "subtitleDownloadTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func closePlayerCancelsEnvironmentAssetsTaskBeforeNil() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "closePlayer", in: source)

        let cancelRange = try requiredRange(of: "environmentAssetsTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "environmentAssetsTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func closePlayerCancelsAudioTrackRefreshTaskBeforeNil() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "closePlayer", in: source)

        let cancelRange = try requiredRange(of: "audioTrackRefreshTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "audioTrackRefreshTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func closePlayerCallsCancelVisionLifecycleTasksOnClose() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "closePlayer", in: source)

        #expect(body.contains("cancelVisionLifecycleTasksOnClose()"))
    }

    @Test
    func cancelVisionLifecycleTasksOnCloseCancelsScenePhaseTask() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cancelVisionLifecycleTasksOnClose", in: source)

        let cancelRange = try requiredRange(of: "scenePhaseTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "scenePhaseTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func cancelVisionLifecycleTasksOnCloseCancelsMemoryPressureTask() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "cancelVisionLifecycleTasksOnClose", in: source)

        let cancelRange = try requiredRange(of: "memoryPressureTask?.cancel()", in: body)
        let nilRange = try requiredRange(of: "memoryPressureTask = nil", in: body)
        #expect(cancelRange.lowerBound < nilRange.lowerBound)
    }

    @Test
    func onDisappearCancelsTasksBeforeCleanupPlayback() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let onDisappearSection = try section(
            from: ".onDisappear {",
            to: "RuntimeMemoryDiagnostics.capture(",
            in: source
        )
        let cleanupRange = try requiredRange(of: "cleanupPlayback()", in: onDisappearSection)

        for taskName in [
            "initialPlayerStateTask",
            "preparePlaybackTask",
            "subtitleCatalogTask",
            "subtitleDownloadTask",
            "environmentAssetsTask",
            "scenePhaseTask",
            "memoryPressureTask"
        ] {
            let cancelRange = try requiredRange(of: "\(taskName)?.cancel()", in: onDisappearSection)
            #expect(cancelRange.lowerBound < cleanupRange.lowerBound)
        }
    }

    @Test
    func onDisappearCancelsVisionGeometryTaskOnVisionOS() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let onDisappearSection = try section(
            from: ".onDisappear {",
            to: ".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))",
            in: source
        )

        #expect(onDisappearSection.contains("visionGeometryTask?.cancel()"))
        #expect(onDisappearSection.contains("visionGeometryTask = nil"))
    }

    @Test
    func startObservingAVPlayerRemovesPreviousObserverBeforeAddingNew() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "startObservingAVPlayer", in: source)

        #expect(body.contains("removeAVTimeObserverIfNeeded()"))
        #expect(body.contains("avTimeObserverHooks.addPeriodicTimeObserver(player, interval, observer)"))
        #expect(body.contains("player.addPeriodicTimeObserver"))

        let removeRange = try requiredRange(of: "removeAVTimeObserverIfNeeded()", in: body)
        let addRange = try requiredRange(of: "player.addPeriodicTimeObserver", in: body)
        #expect(removeRange.lowerBound < addRange.lowerBound)
    }
}

// MARK: - APMPInjector Immersive Teardown

#if os(visionOS)
@Suite("APMPInjector - Immersive Space Teardown", .serialized)
@MainActor
struct APMPInjectorImmersiveTeardownTests {

    @Test
    func stopDeactivatesAfterStart() {
        let injector = APMPInjector()
        let url = URL(string: "https://example.com/video.mp4")!
        let player = AVPlayer(playerItem: AVPlayerItem(url: url))

        injector.start(player: player, mode: .sideBySide)
        #expect(injector.isActive == true)

        injector.stop()
        #expect(injector.isActive == false)
        #expect(injector.videoRenderer == nil)
        #expect(injector.displayLayer == nil)
    }

    @Test
    func stopClearsDisplayLink() {
        let injector = APMPInjector()
        let url = URL(string: "https://example.com/video.mp4")!
        let player = AVPlayer(playerItem: AVPlayerItem(url: url))

        injector.start(player: player, mode: .sideBySide)
        injector.stop()

        #expect(injector.isActive == false)
    }

    @Test
    func stopFlushesVideoRenderer() {
        let injector = APMPInjector()
        let url = URL(string: "https://example.com/video.mp4")!
        let player = AVPlayer(playerItem: AVPlayerItem(url: url))

        injector.start(player: player, mode: .sideBySide)
        let renderer = injector.videoRenderer
        #expect(renderer != nil)

        injector.stop()
        #expect(injector.videoRenderer == nil)
    }

    @Test
    func stopFlushesDisplayLayerRenderer() {
        let injector = APMPInjector()
        let url = URL(string: "https://example.com/video.mp4")!
        let player = AVPlayer(playerItem: AVPlayerItem(url: url))

        injector.start(player: player, mode: .sideBySide)
        let layer = injector.displayLayer
        #expect(layer != nil)

        injector.stop()
        #expect(injector.displayLayer == nil)
    }

    @Test
    func deinitCallsStopAutomatically() {
        func scoped() {
            let injector = APMPInjector()
            let url = URL(string: "https://example.com/video.mp4")!
            let player = AVPlayer(playerItem: AVPlayerItem(url: url))
            injector.start(player: player, mode: .overUnder)
            #expect(injector.isActive == true)
        }
        scoped()
    }
}
#endif

// MARK: - APMPInjector Stop Contract

@Suite("APMPInjector - Stop Contract")
struct APMPInjectorStopContractTests {

    @Test
    func updateAPMPInjectorCallsStopWhenImmersiveSpaceNotOpen() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "updateAPMPInjector", in: source)

        #expect(body.contains("apmpInjector.stop()"))
        #expect(body.contains("isAPMPActive = false"))
        #expect(body.contains("appState.activeVideoRenderer = nil"))
    }

    @Test
    func apmpInjectorDeinitCallsStop() throws {
        let source = try contents(of: "VPStudio/Services/Player/Immersive/APMPInjector.swift")
        #expect(source.contains("deinit"))
        #expect(source.contains("stop()"))
    }

    @Test
    func apmpInjectorStopIsIdempotent() throws {
        let source = try contents(of: "VPStudio/Services/Player/Immersive/APMPInjector.swift")
        let body = try functionBody(named: "stop", in: source)

        #expect(body.contains("displayLink?.invalidate()"))
        #expect(body.contains("displayLink = nil"))
        #expect(body.contains("videoOutput = nil"))
        #expect(body.contains("trackedItem = nil"))
        #expect(body.contains("weakPlayer = nil"))
        #expect(body.contains("videoRenderer = nil"))
        #expect(body.contains("displayLayer = nil"))
        #expect(body.contains("isActive = false"))
    }
}

// MARK: - PlayerView Policy Tests

@Suite("PlayerView - Policy Behavior")
struct PlayerViewPolicyTestsPlayerresourcelifecycletests {

    @Test
    func preparePlaybackShouldRunWhenIDsMatch() {
        let id = UUID()
        #expect(PlayerView.preparePlaybackShouldRun(requestedPreparationID: id, activePreparationID: id))
    }

    @Test
    func preparePlaybackShouldNotRunWhenIDsDiffer() {
        let id1 = UUID()
        let id2 = UUID()
        #expect(!PlayerView.preparePlaybackShouldRun(requestedPreparationID: id1, activePreparationID: id2))
    }

    @Test
    func preparePlaybackShouldNotRunWhenActiveIDIsNil() {
        let id = UUID()
        #expect(!PlayerView.preparePlaybackShouldRun(requestedPreparationID: id, activePreparationID: nil))
    }

    @Test
    func audioTrackRefreshShouldRunWhenStreamIDsMatch() {
        #expect(PlayerView.audioTrackRefreshShouldRun(requestedStreamID: "abc", currentStreamID: "abc"))
    }

    @Test
    func audioTrackRefreshShouldNotRunWhenStreamIDsDiffer() {
        #expect(!PlayerView.audioTrackRefreshShouldRun(requestedStreamID: "abc", currentStreamID: "xyz"))
    }

    @Test
    func audioTrackRefreshShouldNotRunWhenCurrentStreamIDIsNil() {
        #expect(!PlayerView.audioTrackRefreshShouldRun(requestedStreamID: "abc", currentStreamID: nil))
    }

    @Test
    func avPlayerPeriodicObserverIntervalIsQuarterSecond() {
        #expect(PlayerView.avPlayerPeriodicObserverIntervalSeconds == 0.25)
    }
}

// MARK: - Source Parsing Helpers

private func functionBody(named functionName: String, in source: String) throws -> String {
    guard let signatureRange = source.range(of: "func \(functionName)(") else {
        throw NSError(
            domain: "PlayerResourceLifecycleTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing function: \(functionName)"]
        )
    }

    guard let openingBrace = source.range(
        of: "{",
        range: signatureRange.upperBound..<source.endIndex
    )?.lowerBound else {
        throw NSError(
            domain: "PlayerResourceLifecycleTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Missing opening brace for function: \(functionName)"]
        )
    }

    var depth = 0
    var cursor = openingBrace
    while cursor < source.endIndex {
        let character = source[cursor]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                let bodyStart = source.index(after: openingBrace)
                return String(source[bodyStart..<cursor])
            }
        }
        cursor = source.index(after: cursor)
    }

    throw NSError(
        domain: "PlayerResourceLifecycleTests",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Missing closing brace for function: \(functionName)"]
    )
}

private func section(from startToken: String, to endToken: String, in source: String) throws -> String {
    guard let startRange = source.range(of: startToken) else {
        throw NSError(
            domain: "PlayerResourceLifecycleTests",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Missing section start: \(startToken)"]
        )
    }
    guard let endRange = source.range(
        of: endToken,
        range: startRange.upperBound..<source.endIndex
    ) else {
        throw NSError(
            domain: "PlayerResourceLifecycleTests",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Missing section end: \(endToken)"]
        )
    }
    return String(source[startRange.upperBound..<endRange.lowerBound])
}

private func requiredRange(of token: String, in source: String) throws -> Range<String.Index> {
    guard let range = source.range(of: token) else {
        throw NSError(
            domain: "PlayerResourceLifecycleTests",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Missing token: \(token)"]
        )
    }
    return range
}

private func contents(of relativePath: String) throws -> String {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let fileURL = repoRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: fileURL, encoding: .utf8)
}
