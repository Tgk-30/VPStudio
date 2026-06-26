import Foundation
import Testing
@testable import VPStudio

@Suite("Player Resource Teardown Contracts")
struct PlayerResourceTeardownContractTests {
    @Test
    func avPlayerSurfaceViewClearsPlayerOnDismantle() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/AVPlayerSurfaceView.swift")
        #expect(source.contains("static func dismantleNSView"))
        #expect(source.contains("static func dismantleUIView"))
        #expect(source.contains("nsView.player = nil"))
        #expect(source.contains("uiView.player = nil"))
    }

    @Test
    func apmpRendererClearsDisplayLayerOnDismantle() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/APMPRendererView.swift")
        #expect(source.contains("static func dismantleUIView"))
        #expect(source.contains("func clearDisplayLayer()"))
        #expect(source.contains("hostedLayer?.sampleBufferRenderer.flush()"))
        #expect(source.contains("hostedLayer?.removeFromSuperlayer()"))
    }

    @Test
    func headTrackerCancelsPollTaskInDeinit() throws {
        let source = try contents(of: "VPStudio/Services/Player/Immersive/HeadTracker.swift")
        #expect(source.contains("deinit"))
        #expect(source.contains("pollTask?.cancel()"))
    }

    @Test
    func apmpInjectorRunsFullStopPathInDeinit() throws {
        let source = try contents(of: "VPStudio/Services/Player/Immersive/APMPInjector.swift")
        #expect(source.contains("deinit"))
        #expect(source.contains("stop()"))
    }

    @Test
    func playerViewChecksCancellationDuringAsyncEnginePreparation() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("let prepared = try await ksPlayerEngine.prepare(stream: stream)\n                    try Task.checkCancellation()"))
        #expect(source.contains("let prepared: PreparedPlaybackSession"))
        #expect(source.contains("if let prepareAVPlayerSessionOverride {"))
        #expect(source.contains("prepared = try await prepareAVPlayerSessionOverride(stream)"))
        #expect(source.contains("prepared = try await avPlayerEngine.prepare(stream: stream)"))
        #expect(source.contains("}\n                    try Task.checkCancellation()"))
        #expect(source.contains("catch is CancellationError"))
        #expect(source.contains("guard Self.preparePlaybackShouldRun("))
        #expect(source.contains("cleanupPlayback(clearSession: false)"))
        #expect(source.contains("@State private var preparePlaybackTask: Task<Void, Never>?"))
        #expect(source.contains("@State private var activePreparePlaybackID: UUID?"))
        #expect(source.contains("activePreparePlaybackID = preparationID"))
        #expect(source.contains("preparePlaybackTask?.cancel()"))
        #expect(source.contains("preparePlaybackTask = Task { await preparePlayback(for: currentStream, preparationID: preparationID) }"))
        #expect(source.contains("preparePlaybackTask = Task { await preparePlayback(for: stream, preparationID: preparationID) }"))
        #expect(source.contains("static func preparePlaybackShouldRun(requestedPreparationID: UUID, activePreparationID: UUID?) -> Bool"))
    }

    @Test
    func playerViewAssignsNewPreparationIDBeforeCancellingPreviousTask() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let taskBody = try section(
            from: ".task(id: currentStream.id) {",
            to: ".onAppear {",
            in: source
        )
        let assignRange = try requiredRange(of: "activePreparePlaybackID = preparationID", in: taskBody)
        let cancelRange = try requiredRange(of: "preparePlaybackTask?.cancel()", in: taskBody)
        #expect(assignRange.lowerBound < cancelRange.lowerBound)
    }

    @Test
    func playerViewCancelsSubtitleDownloadTasksAndGuardsStreamMutation() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("@State private var subtitleDownloadTask: Task<Void, Never>?"))
        #expect(source.contains("@State private var subtitleCatalogTask: Task<Void, Never>?"))
        #expect(source.contains("@State private var initialPlayerStateTask: Task<Void, Never>?"))
        #expect(source.contains("initialPlayerStateTask?.cancel()"))
        #expect(source.contains("initialPlayerStateTask = Task { await loadInitialPlayerState() }"))
        #expect(source.contains("subtitleCatalogTask?.cancel()"))
        #expect(source.contains("subtitleCatalogTask = nil"))
        // Subtitle catalog refresh may be inlined or a named helper
        let hasSubtitleRefresh = source.contains("scheduleSubtitleCatalogRefresh") ||
            source.contains("refreshSubtitleCatalog(for:")
        #expect(hasSubtitleRefresh)
        #expect(source.contains("subtitleDownloadTask?.cancel()"))
        #expect(source.contains("subtitleDownloadTask = nil"))
        #expect(source.contains("nonisolated static func subtitleMutationShouldRun(requestedStreamID: String, currentStreamID: String?) -> Bool"))
        #expect(source.contains("currentStreamID == requestedStreamID"))
        #expect(source.contains("Self.subtitleMutationShouldRun("))
        #expect(source.contains("requestedStreamID: stream.id"))
        #expect(source.contains("requestedStreamID: streamID"))
    }

    @Test
    func playerViewEnvironmentReloadNotificationRespectsDisabledAutomaticTasks() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let notificationBody = try section(
            from: ".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))",
            to: ".onChange(of: appState.activePlayerSession?.id)",
            in: source
        )

        #expect(notificationBody.contains("guard !disablesAutomaticTasks else { return }"))
        #expect(notificationBody.contains("environmentAssetsTask?.cancel()"))
        #expect(notificationBody.contains("environmentAssetsTask = Task { await loadEnvironmentAssets() }"))
    }

    @Test
    func playerViewResetsSubtitleModeAcrossStreamTransitionsAndRefreshesKeyedSubtitleServices() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("subtitleSelectionMode = .automaticPreferred"))
        #expect(source.contains("if let existing = subtitleService, subtitleServiceAPIKey == apiKey"))
        #expect(source.contains("subtitleServiceAPIKey = apiKey"))
        #expect(source.contains("preferredLanguageCodes("))
        #expect(source.contains("matchesPreferredLanguage("))
    }

    @Test
    func playerViewAppliesEngineAudioSelectionsInsteadOfOnlyMutatingState() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("refreshKSAudioTracks(from: coordinator)"))
        #expect(source.contains("private func selectEngineAudio("))
        #expect(source.contains("coordinator.playerLayer?.player.select(track: mediaTrack)"))
        #expect(source.contains("selectEngineAudio(track)"))
    }

    @Test
    func playerViewClosePlayerCancelsTrackedLoadingTasksAndDismissesWindowBeforeImmersiveTeardown() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let closePlayerBody = try functionBody(named: "closePlayer", in: source)
        let cleanupRange = try requiredRange(of: "cleanupPlayback(clearSession: true)", in: closePlayerBody)

        for taskName in [
            "initialPlayerStateTask",
            "preparePlaybackTask",
            "subtitleCatalogTask",
            "subtitleDownloadTask",
            "autoPlayNextCountdownTask",
            "autoPlayNextResolveTask"
        ] {
            let cancelRange = try requiredRange(of: "\(taskName)?.cancel()", in: closePlayerBody)
            let clearRange = try requiredRange(of: "\(taskName) = nil", in: closePlayerBody)

            #expect(cancelRange.lowerBound < clearRange.lowerBound)
            #expect(cancelRange.lowerBound < cleanupRange.lowerBound)
            #expect(clearRange.lowerBound < cleanupRange.lowerBound)
        }

        let visionOSBranch = try section(
            from: "#if os(visionOS)",
            to: "#elseif os(macOS)",
            in: closePlayerBody
        )

        #expect(containsIgnoringWhitespace(
            visionOSBranch,
            "if PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack { dismissDedicatedPlayerWindow() } if PlayerLifecyclePolicy.dismissesCurrentPresentationOnBack { dismiss() }"
        ))

        let dismissWindowRange = try requiredRange(
            of: "if PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack",
            in: visionOSBranch
        )
        let dismissPresentationRange = try requiredRange(
            of: "if PlayerLifecyclePolicy.dismissesCurrentPresentationOnBack",
            in: visionOSBranch
        )
        let immersiveDismissScheduleRange = try requiredRange(
            of: "scheduleImmersiveDismiss(reason: .playerClosed, restoresMainWindow: true)",
            in: visionOSBranch
        )

        #expect(dismissWindowRange.lowerBound < dismissPresentationRange.lowerBound)
        #expect(dismissPresentationRange.lowerBound < immersiveDismissScheduleRange.lowerBound)
    }

    @Test
    func playerViewClosesWhenActiveSessionIsClearedExternally() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let observerSection = try section(
            from: ".onChange(of: appState.activePlayerSession?.id)",
            to: "#if os(visionOS)",
            in: source
        )

        #expect(observerSection.contains("guard activeSessionID != sessionID else { return }"))
        #expect(observerSection.contains("closePlayer()"))
    }

    @Test
    func playerViewOnDisappearCancelsTrackedTasksBeforeCleanup() throws {
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
            "autoPlayNextCountdownTask",
            "autoPlayNextResolveTask"
        ] {
            let cancelRange = try requiredRange(of: "\(taskName)?.cancel()", in: onDisappearSection)
            #expect(cancelRange.lowerBound < cleanupRange.lowerBound)
        }
    }

    @Test
    func playerViewShowsCancellableCircularCountdownBeforeAutoPlayingNextEpisode() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let promptSource = try contents(of: "VPStudio/Views/Windows/Player/PlayerAutoPlayNextPromptView.swift")
        #expect(source.contains("enum PlayerAutoplayNextPolicy"))
        #expect(source.contains("private var autoPlayNextOverlay"))
        #expect(source.contains("PlayerAutoPlayNextPromptView("))
        #expect(promptSource.contains("struct PlayerAutoPlayCountdownRing"))
        #expect(promptSource.contains("Circle()\n                .trim(from: 0, to: CGFloat(progress))"))
        #expect(promptSource.contains("Button(action: onPlayNow)"))
        #expect(promptSource.contains("Button(action: onCancel)"))
        #expect(source.contains("@State private var autoPlayNextCountdownTask: Task<Void, Never>?"))
        #expect(source.contains("@State private var autoPlayNextResolveTask: Task<Void, Never>?"))
        #expect(source.contains("private func cancelAutoPlayNextCountdown()"))
        #expect(source.contains("private func playNextEpisodeNow()"))
        #expect(source.contains("scheduleAutoPlayNextCountdownIfNeeded()"))
        #expect(source.contains("resetAutoPlayNextStateForStreamTransition()"))
    }

    @Test
    func playerViewLoadInitialStateBailsOutWhenCancelledBeforeSideEffects() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let loadInitialBody = try functionBody(named: "loadInitialPlayerState", in: source)

        #expect(containsIgnoringWhitespace(
            loadInitialBody,
            "guard !Task.isCancelled else { return } streamQueue = await PlayerSessionRouting.playbackQueue("
        ))
        #expect(containsIgnoringWhitespace(
            loadInitialBody,
            "await loadEnvironmentAssets() await loadPrivacyPreferences() guard !Task.isCancelled else { return } if !guestModeEnabled { startProgressPersistence() }"
        ))
        #expect(containsIgnoringWhitespace(
            loadInitialBody,
            "let catalogMutationID = UUID() subtitleCatalogMutationID = catalogMutationID await refreshSubtitleCatalog( for: currentStream, requestedStreamID: currentStream.id, mutationID: catalogMutationID ) guard !Task.isCancelled else { return } await autoLoadSubtitlesIfEnabled(for: currentStream)"
        ))
        #expect(containsIgnoringWhitespace(
            loadInitialBody,
            "await autoLoadSubtitlesIfEnabled(for: currentStream) guard !Task.isCancelled else { return } scheduleControlsHide()"
        ))
    }

    @Test
    func playerViewGuestModeSuppressesPlaybackTrackingEntryPoints() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")

        for functionName in ["scrobbleStart", "scrobblePause", "scrobbleResume", "scrobbleStop"] {
            let body = try functionBody(named: functionName, in: source)
            #expect(body.contains("guard await shouldSuppressPlaybackTracking() == false else { return }"))
        }

        let persistBody = try functionBody(named: "persistCurrentWatchProgress", in: source)
        #expect(persistBody.contains("guard !guestModeEnabled else { return }"))
        #expect(persistBody.contains("guard await shouldSuppressPlaybackTracking() == false else { return }"))

        let saveBody = try functionBody(named: "saveWatchProgress", in: source)
        #expect(saveBody.contains("guard !guestModeEnabled else { return }"))
        #expect(saveBody.contains("guard await shouldSuppressPlaybackTracking() == false else { return }"))

        let captureBody = try functionBody(named: "captureLastFrameIfDue", in: source)
        #expect(captureBody.contains("guard !guestModeEnabled else { return }"))
        #expect(captureBody.contains("guard await shouldSuppressPlaybackTracking() == false else { return }"))

        let privacyBody = try functionBody(named: "shouldSuppressPlaybackTracking", in: source)
        #expect(privacyBody.contains("key: SettingsKeys.guestModeEnabled"))
        #expect(privacyBody.contains("default: false"))
    }

    @Test
    func playerViewBindsPlayPauseIconToControlPresentationMapper() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("private var playPausePresentation: PlayerControlPresentation"))
        #expect(source.contains("PlayerControlPresentationMapper.playPause("))
        #expect(source.contains("playbackState: playbackState"))
        #expect(source.contains("isCurrentlyPlaying: isCurrentlyPlaying"))
        #expect(source.contains("Image(systemName: playPausePresentation.symbolName)"))
        #expect(source.contains(".accessibilityLabel(playPausePresentation.label)"))
        #expect(source.contains(".accessibilityValue(playPausePresentation.accessibilityValue)"))
    }

    @Test
    func playerViewUsesEnginePlaybackStateForPlayPauseIcon() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try section(
            from: "private var isCurrentlyPlaying: Bool {",
            to: "private var currentSubtitleSelectionIsOff: Bool {",
            in: source
        )

        #expect(body.contains("engine.isPlaying"))
        #expect(!body.contains("ksPlayerCoordinator?.state.isPlaying"))
        #expect(!body.contains("avPlayer?.timeControlStatus"))
    }

    @Test
    func playerViewSeedsAndResetsSessionTitleState() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let policySource = try contents(of: "VPStudio/Views/Windows/Player/PlayerViewStatePolicy.swift")
        #expect(source.contains("engine.currentTitle = resolvedMediaTitle"))
        #expect(source.contains("engine.currentTitle = PlayerViewStatePolicy.currentTitle("))
        #expect(source.contains("mediaTitle: activeMediaTitle"))
        #expect(source.contains("streamFileName: stream.fileName"))
        #expect(source.contains("private var resolvedMediaTitle: String"))
        #expect(source.contains("private func resolvedMediaTitleFrom(activeMediaTitle: String?, streamFileName: String) -> String"))
        #expect(!source.contains("activeMediaTitle ?? currentStream.fileName"))
        #expect(policySource.contains("static func currentTitle(mediaTitle: String?, streamFileName: String) -> String"))
        #expect(source.contains("engine.resetSessionState()"))
        #expect(source.contains("Text(resolvedMediaTitle)"))
        #expect(containsIgnoringWhitespace(
            source,
            "engine.updateStereoMode( from: resolvedMediaTitleFrom(activeMediaTitle: activeMediaTitle, streamFileName: stream.fileName), codecHint: stream.codec.rawValue )"
        ))
    }

    @Test
    func playerViewBindsAutoHidePolicyToDynamicControlLockState() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let scheduleBody = try functionBody(named: "scheduleControlsHide", in: source)

        #expect(source.contains("@State private var isControlsLocked = false"))
        #expect(scheduleBody.contains("isControlsLocked: isControlsLocked"))
        #expect(!scheduleBody.contains("isControlsLocked: false"))
    }

    @Test
    func playerViewEnvironmentSwitchOpensThePicker() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let switchHandler = try section(
            from: "onRequestEnvironmentSwitch: {",
            to: "onDismiss:",
            in: source
        )

        #expect(switchHandler.contains("recordImmersiveControlEvent(.requestEnvironmentSwitch)"))
        #expect(switchHandler.contains("requestEnvironmentPicker()"))
        let recordRange = try requiredRange(of: "recordImmersiveControlEvent(.requestEnvironmentSwitch)", in: switchHandler)
        let requestRange = try requiredRange(of: "requestEnvironmentPicker()", in: switchHandler)
        #expect(recordRange.lowerBound < requestRange.lowerBound)
        #expect(source.contains("private func requestEnvironmentPicker()"))
        #expect(source.contains("isShowingEnvironmentPicker = true"))
    }

    @Test
    func playerViewExposesCinemaEnvironmentFromBothVisionMenus() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let menuSource = try contents(of: "VPStudio/Views/Windows/Player/PlayerEnvironmentMenu.swift")
        let topBarMenuSection = try section(
            from: "#if os(visionOS)\n                    Section(\"Environment\") {",
            to: "#endif\n                } label: {",
            in: source
        )
        let transportPillSection = try section(
            from: "#if os(visionOS)\n                // Environment toggle pill",
            to: ".animation(motionAnimationsEnabled ? .easeInOut(duration: 0.2) : nil, value: appState.isImmersiveSpaceOpen)",
            in: source
        )

        #expect(topBarMenuSection.contains("openCinemaEnvironmentAfterMenuDismissal()"))
        #expect(topBarMenuSection.contains("PlayerEnvironmentMenuLabel("))
        #expect(topBarMenuSection.contains("spec: .standardRoom("))
        #expect(topBarMenuSection.contains("spec: .cinema("))
        #expect(topBarMenuSection.contains("canOpenCinema: PlayerCinemaEnvironmentPolicy.canOpen("))
        #expect(topBarMenuSection.contains("spec: .compactAsset("))
        #expect(topBarMenuSection.contains("PlayerCinemaEnvironmentPolicy.canOpen("))
        #expect(topBarMenuSection.contains("activeEngine: activeEngine"))
        #expect(topBarMenuSection.contains("hasAVPlayer: avPlayer != nil"))
        #expect(topBarMenuSection.contains("Label(\"Cinema Settings\", systemImage: \"slider.horizontal.3\")"))
        #expect(topBarMenuSection.contains("Text(\"No imported environments\")"))
        #expect(topBarMenuSection.contains("Label(\"Browse Environments\", systemImage: \"mountain.2\")"))

        #expect(transportPillSection.contains("PlayerEnvironmentButton("))
        #expect(transportPillSection.contains("openCinemaEnvironmentAfterMenuDismissal()"))
        #expect(transportPillSection.contains("PlayerCinemaEnvironmentPolicy.canOpen("))
        #expect(transportPillSection.contains("activeEngine: activeEngine"))
        #expect(transportPillSection.contains("hasAVPlayer: avPlayer != nil"))
        #expect(transportPillSection.contains("onShowCinemaSettings:"))
        #expect(transportPillSection.contains("onShowPicker:"))
        #expect(menuSource.contains(#"title: "Cinema Environment""#))
        #expect(menuSource.contains("PlayerEnvironmentCinemaRow("))
        #expect(menuSource.contains("Label(\"Cinema Settings\", systemImage: \"slider.horizontal.3\")"))
        #expect(menuSource.contains("Text(\"No imported environments\")"))
        #expect(menuSource.contains("Label(\"Browse Environments\", systemImage: \"mountain.2\")"))
    }

    @Test
    func playerViewDefersEnvironmentMenuActionsUntilAfterMenuDismissal() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")

        for functionName in [
            "openCinemaEnvironmentAfterMenuDismissal",
            "openEnvironmentAfterMenuDismissal",
            "showEnvironmentPickerAfterMenuDismissal",
            "showCinemaSettingsAfterMenuDismissal",
            "dismissEnvironmentAfterMenuDismissal",
        ] {
            let body = try functionBody(named: functionName, in: source)
            #expect(body.contains("Task { @MainActor in"))
            #expect(body.contains("await waitForMenuDismissal()"))
        }

        let waitBody = try functionBody(named: "waitForMenuDismissal", in: source)
        #expect(waitBody.contains("await Task.yield()"))
        #expect(waitBody.contains("Task.sleep(for: PlayerCinemaEnvironmentPolicy.menuDismissalDelay)"))
    }

    @Test
    func playerEnvironmentPickerDefersActionsUntilAfterSheetDismissal() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let sheetBody = try section(
            from: ".sheet(isPresented: $isShowingEnvironmentPicker) {",
            to: ".sheet(isPresented: $isShowingCinemaSettings) {",
            in: source
        )

        #expect(sheetBody.contains("openEnvironmentAfterMenuDismissal(asset)"))
        #expect(sheetBody.contains("dismissEnvironmentAfterMenuDismissal()"))
        #expect(sheetBody.contains("openCinemaEnvironmentAfterMenuDismissal()"))
        #expect(!sheetBody.contains("Task { await openEnvironment(asset) }"))
        #expect(!sheetBody.contains("Task { await openCinemaEnvironment() }"))
        #expect(!sheetBody.contains("Task { await dismissImmersiveIfNeeded(reason: .userInitiated) }"))
    }

    @Test
    func playerEnvironmentPresentationWritesAreCoalesced() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let pickerBody = try functionBody(named: "showEnvironmentPickerAfterMenuDismissal", in: source)
        let settingsBody = try functionBody(named: "showCinemaSettingsAfterMenuDismissal", in: source)
        let requestBody = try functionBody(named: "requestEnvironmentPicker", in: source)

        #expect(pickerBody.contains("guard !isShowingEnvironmentPicker else {"))
        #expect(settingsBody.contains("guard !isShowingCinemaSettings else {"))
        #expect(pickerBody.contains("environmentMenuActionTask = nil"))
        #expect(settingsBody.contains("environmentMenuActionTask = nil"))
        #expect(requestBody.contains("guard !isShowingEnvironmentPicker else {"))
        #expect(requestBody.contains("environmentAssetsTask = Task { await loadEnvironmentAssets() }"))
    }

    @Test
    func immersiveDismissCompletesLocalStateBeforeSwitchReopen() throws {
        let playerSource = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let appStateSource = try contents(of: "VPStudio/App/AppState.swift")
        let dismissBody = try functionBody(named: "dismissImmersiveIfNeeded", in: playerSource)
        let completionBody = try functionBody(named: "completeImmersiveDismissIfStillPending", in: appStateSource)

        let dismissRange = try requiredRange(of: "await dismissImmersiveSpace()", in: dismissBody)
        let completeRange = try requiredRange(of: "appState.completeImmersiveDismissIfStillPending()", in: dismissBody)
        #expect(dismissRange.lowerBound < completeRange.lowerBound)
        #expect(completionBody.contains("guard isImmersiveSpaceOpen || isImmersiveTransitionInFlight else { return }"))
        #expect(completionBody.contains("immersiveSpaceDidDisappear()"))
    }

    @Test
    func playerViewOpensAppleCinemaEnvironmentWithCurrentAVPlayerOnly() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let body = try functionBody(named: "openCinemaEnvironment", in: source)

        #expect(body.contains("PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: activeEngine, hasAVPlayer: avPlayer != nil)"))
        #expect(body.contains("PlayerImmersiveTransitionPolicy.cinemaOpenPlan("))
        #expect(body.contains("let player = avPlayer"))
        #expect(body.contains("case .unavailable(let message):"))
        #expect(body.contains("playbackMessage = message"))
        #expect(body.contains("appState.activeAVPlayer = player"))
        #expect(body.contains("await dismissImmersiveIfNeeded(reason: .switchingEnvironment)"))
        #expect(body.contains("PlayerImmersiveTransitionPolicy.openReadiness(isTransitionInFlight: appState.isImmersiveTransitionInFlight)"))
        #expect(body.contains("appState.beginImmersiveTransition()"))
        #expect(body.contains("openImmersiveSpace(id: EnvironmentType.cinemaEnvironment.immersiveSpaceId)"))
        #expect(body.contains("PlayerImmersiveTransitionPolicy.completionAction(didOpen: didOpen)"))
        #expect(body.contains("appState.spatialAudioManager.enterImmersiveMode()"))
        #expect(body.contains("appState.cancelImmersiveTransition()"))

        let avPlayerAssignmentCount = body.components(separatedBy: "appState.activeAVPlayer = player").count - 1
        #expect(avPlayerAssignmentCount == 1)

        let firstAVPlayerAssignment = try requiredRange(of: "appState.activeAVPlayer = player", in: body)
        let openRange = try requiredRange(of: "openImmersiveSpace(id: EnvironmentType.cinemaEnvironment.immersiveSpaceId)", in: body)
        #expect(firstAVPlayerAssignment.lowerBound < openRange.lowerBound)
    }

    @Test
    func isolatedPlayerEnvironmentMenusAlwaysOfferCinemaEnvironment() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerEnvironmentMenu.swift")
        let menuSection = try section(
            from: "struct PlayerEnvironmentMenu: View {",
            to: "/// Compact environment toggle button",
            in: source
        )
        let buttonSection = try section(
            from: "struct PlayerEnvironmentButton: View {",
            to: "#endif",
            in: source
        )

        for section in [menuSection, buttonSection] {
            #expect(section.contains("let onSelectCinema: () -> Void"))
            #expect(section.contains("PlayerEnvironmentCinemaRow("))
            #expect(section.contains("spec: .cinema("))
            #expect(section.contains("action: onSelectCinema"))
        }
        #expect(source.contains(#"title: "Cinema Environment""#))
        #expect(source.contains("PlayerEnvironmentMenuPolicy.cinemaIconName("))

        #expect(menuSection.contains("ForEach(assets, id: \\.id)"))
        #expect(buttonSection.contains("Text(\"No imported environments\")"))
        #expect(buttonSection.contains("var onShowCinemaSettings: (() -> Void)? = nil"))
        #expect(buttonSection.contains("var onShowPicker: (() -> Void)? = nil"))
        #expect(buttonSection.contains("canOpenCinema"))
    }

    @Test
    func playerViewUsesIsolatedEnvironmentButtonForInfoPill() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let infoPillsRow = try section(
            from: "private var infoPillsRow: some View {",
            to: "// Dim passthrough toggle pill",
            in: source
        )

        #expect(infoPillsRow.contains("PlayerEnvironmentButton("))
        #expect(infoPillsRow.contains("assets: environmentAssets"))
        #expect(infoPillsRow.contains("onClear:"))
        #expect(infoPillsRow.contains("onShowCinemaSettings:"))
        #expect(infoPillsRow.contains("onShowPicker:"))
        #expect(infoPillsRow.contains("PlayerCinemaEnvironmentPolicy.canOpen("))
    }

    @Test
    func environmentAssetIconsUseSharedCinemaPolicy() throws {
        let playerSource = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let menuSource = try contents(of: "VPStudio/Views/Windows/Player/PlayerEnvironmentMenu.swift")

        let playerHelper = try functionBody(named: "environmentAssetIcon", in: playerSource)
        let menuHelper = try functionBody(named: "compactAssetIconName", in: menuSource)

        #expect(playerHelper.contains("PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: asset.assetPath)"))
        #expect(menuHelper.contains("PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: assetPath)"))
        #expect(!playerHelper.contains("pathExtension.lowercased()"))
        #expect(!menuHelper.contains("pathExtension.lowercased()"))
    }

    @Test
    func playerViewCoalescesNotificationDrivenRefreshTasks() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("@State private var environmentAssetsTask: Task<Void, Never>?"))
        #expect(source.contains("environmentAssetsTask?.cancel()"))
        #expect(source.contains("environmentAssetsTask = Task { await loadEnvironmentAssets() }"))
        #expect(source.contains("@State private var scenePhaseTask: Task<Void, Never>?"))
        #expect(source.contains("scenePhaseTask?.cancel()"))
        #expect(source.contains("scenePhaseTask = Task { await handleScenePhaseChange(phase) }"))
        #expect(source.contains("@State private var memoryPressureTask: Task<Void, Never>?"))
        #expect(source.contains("memoryPressureTask?.cancel()"))
        #expect(source.contains("memoryPressureTask = Task { await handleMemoryPressureWarning() }"))
    }

    @Test
    func playerViewHasControlsOverlayAndTransportLayout() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        // Verify player has the core control overlays and transport elements
        #expect(source.contains(".overlay(alignment: .bottom)") || source.contains("transportBar") || source.contains("transportControls"))
        // Cinematic policies exist as separate files; usage may be direct or indirect
        let cinematicPolicySource = try contents(of: "VPStudio/Views/Windows/Player/PlayerCinematicVisualPolicy.swift")
        #expect(cinematicPolicySource.contains("enum PlayerCinematicVisualPolicy"))
        let chromePolicySource = try contents(of: "VPStudio/Views/Windows/Player/PlayerCinematicChromePolicy.swift")
        #expect(chromePolicySource.contains("enum PlayerCinematicChromePolicy"))
    }

    @Test
    func playerInfoPillsRenderInsideTransportDock() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let controlsOverlay = try section(
            from: "private var controlsOverlay: some View {",
            to: "// MARK: - Title Bar",
            in: source
        )
        let transportBar = try section(
            from: "private var transportBar: some View {",
            to: "private var playbackProgressBar: some View {",
            in: source
        )

        #expect(!containsIgnoringWhitespace(controlsOverlay, """
        VStack(spacing: PlayerCinematicChromePolicy.controlsDockSpacing) {
            infoPillsRow
                .frame(maxWidth: PlayerCinematicChromePolicy.quickActionsMaxWidth)

            transportBar
                .compositingGroup()
        }
        """))
        #expect(transportBar.contains("infoPillsRow"))
        #expect(transportBar.contains(".frame(maxWidth: PlayerCinematicChromePolicy.quickActionsMaxWidth)"))

        let infoPillsRange = try requiredRange(of: "infoPillsRow", in: transportBar)
        let progressRange = try requiredRange(of: "playbackProgressBar", in: transportBar)
        #expect(infoPillsRange.lowerBound < progressRange.lowerBound)
    }

    @Test
    func playerViewTeardownCancelsNotificationTasksBeforeCleanup() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")

        let onDisappearSection = try section(
            from: ".onDisappear {",
            to: ".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))",
            in: source
        )
        let onDisappearCleanupRange = try requiredRange(of: "cleanupPlayback()", in: onDisappearSection)

        for taskName in [
            "environmentAssetsTask",
            "scenePhaseTask",
            "memoryPressureTask",
        ] {
            let cancelRange = try requiredRange(of: "\(taskName)?.cancel()", in: onDisappearSection)
            #expect(cancelRange.lowerBound < onDisappearCleanupRange.lowerBound)
        }

        let restoreRange = try requiredRange(of: "scheduleMainWindowRestoreIfNeeded()", in: onDisappearSection)
        #expect(onDisappearCleanupRange.lowerBound < restoreRange.lowerBound)

        let closePlayerBody = try functionBody(named: "closePlayer", in: source)
        let closePlayerCleanupRange = try requiredRange(of: "cleanupPlayback(clearSession: true)", in: closePlayerBody)
        #expect(!closePlayerBody.contains("scheduleMainWindowRestoreIfNeeded()"))

        for taskName in [
            "environmentAssetsTask",
        ] {
            let cancelRange = try requiredRange(of: "\(taskName)?.cancel()", in: closePlayerBody)
            let clearRange = try requiredRange(of: "\(taskName) = nil", in: closePlayerBody)
            #expect(cancelRange.lowerBound < clearRange.lowerBound)
            #expect(clearRange.lowerBound < closePlayerCleanupRange.lowerBound)
        }

        #expect(closePlayerBody.contains("cancelVisionLifecycleTasksOnClose()"))

        let visionTaskCancelBody = try functionBody(
            named: "cancelVisionLifecycleTasksOnClose",
            in: source
        )
        for taskName in [
            "scenePhaseTask",
            "memoryPressureTask",
            "immersiveDismissTask",
        ] {
            let cancelRange = try requiredRange(of: "\(taskName)?.cancel()", in: visionTaskCancelBody)
            let clearRange = try requiredRange(of: "\(taskName) = nil", in: visionTaskCancelBody)
            #expect(cancelRange.lowerBound < clearRange.lowerBound)
        }
    }

    @Test
    func playerViewOnDisappearRestoresMainWindowOnlyAfterImmersiveDismissOnVisionOS() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let onDisappearSection = try section(
            from: ".onDisappear {",
            to: ".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))",
            in: source
        )
        let visionOSSection = try section(
            from: "#if os(visionOS)",
            to: "#elseif os(macOS)",
            in: onDisappearSection
        )

        let scheduleRange = try requiredRange(
            of: "scheduleImmersiveDismiss(reason: .playerClosed, restoresMainWindow: true)",
            in: visionOSSection
        )

        let scheduleBody = try functionBody(named: "scheduleImmersiveDismiss", in: source)
        let dismissRange = try requiredRange(
            of: "await dismissImmersiveIfNeeded(reason: reason)",
            in: scheduleBody
        )
        let restoreRange = try requiredRange(
            of: "scheduleMainWindowRestoreIfNeeded()",
            in: scheduleBody
        )

        #expect(!scheduleBody.contains("didDismiss"))
        #expect(!scheduleBody.contains("restoresMainWindow &&"))
        #expect(scheduleRange.lowerBound < visionOSSection.endIndex)
        #expect(dismissRange.lowerBound < restoreRange.lowerBound)
    }

    @Test
    func playerViewOnDisappearResetsWindowAspectBeforeRestoringMainWindowOnMacOS() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let onDisappearSection = try section(
            from: ".onDisappear {",
            to: ".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))",
            in: source
        )
        let macOSSection = try section(
            from: "#elseif os(macOS)",
            to: "#endif",
            in: onDisappearSection
        )

        let resetRange = try requiredRange(of: "resetWindowAspectRatio()", in: macOSSection)
        let restoreRange = try requiredRange(of: "scheduleMainWindowRestoreIfNeeded()", in: macOSSection)
        #expect(resetRange.lowerBound < restoreRange.lowerBound)
    }

    @Test
    func playerWindowLayoutContractsApplyMinimumSizeAndFreeformAspectUnlocking() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let configureBody = try functionBody(named: "configurePlayerWindow", in: source)
        let aspectBody = try functionBody(named: "applyWindowAspectRatio", in: source)

        #expect(configureBody.contains("window.minSize = NSSize(width: 960, height: 540)"))
        #expect(configureBody.contains("applyWindowAspectRatio(to: window)"))

        #expect(aspectBody.contains("PlayerAspectRatioPolicy.resolvedRatio("))
        #expect(aspectBody.contains("PlayerAspectRatioPolicy.windowAspectSize(for: ratio)"))
        #expect(aspectBody.contains("window.contentAspectRatio = NSSize(width: size.width, height: size.height)"))
        #expect(aspectBody.contains("window.contentAspectRatio = NSSize.zero"))
    }

    @Test
    func playerViewUsesHigherCadenceAVPlayerObserverForSubtitleUpdates() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("static let avPlayerPeriodicObserverIntervalSeconds: TimeInterval = 0.25"))
        #expect(source.contains("engine.updateSubtitleText(at: newTime)"))
    }

    @Test
    func playerTrackPickerLabelsEmbeddedTracksAsDirectLinkTracks() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("Section(\"Direct Link Subtitles\")"))
        #expect(source.contains("Section(\"Direct Link Audio\")"))
    }

    @Test
    func playerViewSurfacesKSPlayerEmbeddedSubtitlesFromDirectStreams() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("@State private var ksSubtitleOptions: [KSSubtitleOption] = []"))
        #expect(source.contains("@State private var selectedKSSubtitleID: String?"))
        #expect(source.contains("@State private var subtitleTrackRefreshTask: Task<Void, Never>?"))
        #expect(source.contains("refreshKSSubtitleTracks(from: coordinator)"))
        #expect(source.contains("coordinator.subtitleModel.subtitleInfos"))
        #expect(source.contains("player.tracks(mediaType: .subtitle)"))
        #expect(source.contains("private func selectKSSubtitle(_ track: KSSubtitleOption)"))
        #expect(source.contains("coordinator.subtitleModel.selectedSubtitleInfo = subtitleInfo"))
        #expect(source.contains("player.select(track: mediaTrack)"))
        #expect(source.contains("clearKSSubtitleSelection()"))
    }

    @Test
    func playerViewChecksPreparationCancellationBeforeTearingDownPlaybackWithoutClearingActiveSession() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let prepareBody = try section(
            from: "private func preparePlayback(for stream: StreamInfo, preparationID: UUID) async {",
            to: "static func audioTrackRefreshShouldRun",
            in: source
        )

        // Invariant (robust to interleaved state resets): prepare re-checks cancellation
        // (the !Task.isCancelled guard) BEFORE it tears down playback without clearing the
        // session (cleanupPlayback(clearSession: false)). Asserted by relative ordering so
        // unrelated state-reset lines added between them don't break this contract.
        let hasPlayedReset = try requiredRange(of: "hasPlayedOnce = false", in: prepareBody)
        let cancellationGuard = try requiredRange(of: "!Task.isCancelled else {", in: prepareBody)
        let cleanupWithoutClearingSession = try requiredRange(
            of: "cleanupPlayback(clearSession: false)",
            in: prepareBody
        )
        #expect(hasPlayedReset.lowerBound < cancellationGuard.lowerBound)
        #expect(cancellationGuard.lowerBound < cleanupWithoutClearingSession.lowerBound)
    }

    @Test
    func playerViewGuardsAsyncPlaybackCallbacksAgainstStaleSessions() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("private func isCurrentAVPlayer(_ player: AVPlayer) -> Bool"))
        #expect(source.contains("private func isCurrentKSPlayerCoordinator(_ coordinator: KSVideoPlayer.Coordinator) -> Bool"))
        #expect(source.contains("guard self.isCurrentKSPlayerCoordinator(coordinator) else { return }"))
        #expect(source.contains("guard self.isCurrentAVPlayer(player) else { return }"))
        #expect(source.contains("scheduleAVVideoRatioDetection(from: asset, player: player)"))
        #expect(source.contains("scheduleAVHDRMetadataExtraction(from: asset, player: player)"))
        #expect(source.contains("guard isCurrentAVPlayer(player) else { return }"))
        #expect(source.contains("guard isCurrentKSPlayerCoordinator(coordinator) else { return }"))
    }

    @Test
    func playerViewRebuildsSubtitleServiceWhenApiKeyChangesAndClearsSessionCacheOnCleanup() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("@State private var subtitleServiceAPIKey: String?"))
        #expect(source.contains("if let existing = subtitleService, subtitleServiceAPIKey == apiKey"))
        #expect(source.contains("subtitleServiceAPIKey = apiKey"))
        #expect(source.contains("subtitleService = nil"))
        #expect(source.contains("subtitleServiceAPIKey = nil"))
    }

    @Test
    func playerViewManualSubtitleDownloadDoesNotRequireAutomaticSelectionMode() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let downloadBody = try section(
            from: "private func downloadAndSelectSubtitle(",
            to: "private func writeExternalSubtitle(content: String, source: Subtitle) throws -> URL {",
            in: source
        )

        #expect(!downloadBody.contains("subtitleSelectionMode == .automaticPreferred"))
        #expect(downloadBody.contains("Self.subtitleMutationShouldRun("))
    }

    @Test
    func playerViewRoutesEngineAudioSelectionThroughActiveKSPlayerTracks() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("selectEngineAudio(track)"))

        let selectEngineAudioBody = try section(
            from: "private func selectEngineAudio(_ track: VPPlayerEngine.TrackInfo) {",
            to: "private func scheduleSubtitleCatalogRefresh(for stream: StreamInfo) {",
            in: source
        )

        #expect(selectEngineAudioBody.contains("engine.selectAudioTrack(track.id)"))
        #expect(selectEngineAudioBody.contains("tracks(mediaType: .audio)"))
        #expect(selectEngineAudioBody.contains("player.select(track: mediaTrack)"))
        #expect(selectEngineAudioBody.contains("refreshKSAudioTracks(from: coordinator)"))
    }

    @Test
    func customEnvironmentViewUsesSharedImmersiveFallbacksAndErrorSurface() throws {
        let source = try contents(of: "VPStudio/Views/Immersive/CustomEnvironmentView.swift")
        #expect(source.contains("ImmersiveControlsPolicy.smoothedPosition("))
        #expect(source.contains("ImmersiveControlsPolicy.fallbackControlsPosition"))
        #expect(source.contains("Attachment(id: \"loadingIndicator\")"))
        #expect(source.contains("makeFallbackScreen()"))
        #expect(source.contains("setLoadingState(.failed"))
        #expect(source.contains("private func setLoadingState(_ state: LoadingState)"))
        #expect(!source.contains("loadingState = .failed"))
    }

    @Test
    func playerAccessibilityHelpersHonorReduceMotionAndSystemCaptionFallbacks() {
        #expect(!PlayerView.shouldAnimateForAccessibility(reduceMotion: true))
        #expect(PlayerView.shouldAnimateForAccessibility(reduceMotion: false))

        #expect(
            PlayerView.automaticSubtitleLanguageCodes(
                configuredLanguageSetting: "es, fr",
                systemPreferredLanguages: ["de-DE"],
                closedCaptioningEnabled: true
            ) == ["de", "es", "fr"]
        )

        #expect(
            PlayerView.automaticSubtitleLanguageCodes(
                configuredLanguageSetting: nil,
                systemPreferredLanguages: ["fr-CA", "en-US"],
                closedCaptioningEnabled: true
            ) == ["fr", "en"]
        )

        #expect(
            PlayerView.automaticSubtitleLanguageCodes(
                configuredLanguageSetting: nil,
                systemPreferredLanguages: ["fr-CA"],
                closedCaptioningEnabled: false
            ) == ["fr"]
        )
    }

    @Test
    func playerAndImmersiveSourcesGateAnimationsBehindReduceMotion() throws {
        let playerSource = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let immersiveControlsSource = try contents(of: "VPStudio/Views/Immersive/ImmersivePlayerControlsView.swift")
        let customEnvironmentSource = try contents(of: "VPStudio/Views/Immersive/CustomEnvironmentView.swift")
        let hdriSource = try contents(of: "VPStudio/Views/Immersive/HDRISkyboxEnvironment.swift")

        #expect(playerSource.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(playerSource.contains("motionAnimationsEnabled"))
        #expect(playerSource.contains("performOptionalAnimation(.easeInOut(duration: PlayerControlVisibilityPolicy.fadeInDuration))"))
        #expect(playerSource.contains("performOptionalAnimation(.easeInOut(duration: PlayerControlVisibilityPolicy.fadeOutDuration))"))
        #expect(playerSource.contains("UIAccessibility.isClosedCaptioningEnabled"))

        #expect(immersiveControlsSource.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(immersiveControlsSource.contains(".animation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.15), value: isDraggingScrubber)"))

        #expect(customEnvironmentSource.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(customEnvironmentSource.contains("performOptionalAnimation(.easeInOut(duration: 0.25))"))
        #expect(customEnvironmentSource.contains(".animation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.15), value: subtitleText)"))

        #expect(hdriSource.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(hdriSource.contains("screen.move(to: temp.transform, relativeTo: nil, duration: accessibilityReduceMotion ? 0 : 0.4)"))
        #expect(hdriSource.contains("performOptionalAnimation(.easeInOut(duration: 0.25))"))
    }

    @Test
    func playerSubtitleCatalogAndWarningsStayAccessibilityAligned() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let policySource = try contents(of: "VPStudio/Views/Windows/Player/PlayerViewStatePolicy.swift")

        #expect(source.contains("let preferredSubtitleLanguages = Self.automaticSubtitleLanguageCodes("))
        #expect(policySource.contains("let languages = PlayerSubtitlePolicy.automaticSubtitleLanguageCodes("))
        #expect(!source.contains("MACaptionAppearanceAddSelectedLanguage"))
        #expect(containsIgnoringWhitespace(
            source,
            """
            warningsOverlay
                                .padding(.top, 6)
                                .compositingGroup()
            """
        ))
    }

    @Test
    func playerWarningsOverlayComposesPurePolicyStateAndOnlyShowsFailureTextWhenAvailable() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let warningsBody = try section(
            from: "private var warningsOverlay: some View {",
            to: "private var subtitlePickerSheet: some View {",
            in: source
        )

        #expect(warningsBody.contains("let warningError = PlayerViewPolicy.warningOverlayPlaybackError("))
        #expect(warningsBody.contains("if PlayerViewPolicy.shouldShowWarningsOverlay("))
        #expect(warningsBody.contains("ForEach(capabilityWarnings, id: \\.self)"))
        #expect(warningsBody.contains("if let warningError"))
        #expect(warningsBody.contains("Text(warningError)"))
        #expect(warningsBody.contains(".background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))"))
        #expect(warningsBody.contains(".strokeBorder(.white.opacity(0.14), lineWidth: 0.5)"))
        #expect(!warningsBody.contains("playbackState == .failed"))
    }

    @Test
    func subtitleAndAudioPickersKeepSelectionHandlersAndDismissalPaths() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        let subtitlePickerBody = try section(
            from: "private var subtitlePickerSheet: some View {",
            to: "private var audioPickerSheet: some View {",
            in: source
        )
        let audioPickerBody = try section(
            from: "private var audioPickerSheet: some View {",
            to: "private var playPausePresentation: PlayerControlPresentation {",
            in: source
        )

        #expect(subtitlePickerBody.contains("selectSubtitlesOff()"))
        #expect(subtitlePickerBody.contains("selectAVSubtitle(track)"))
        #expect(subtitlePickerBody.contains("selectKSSubtitle(track)"))
        #expect(subtitlePickerBody.contains("selectExternalSubtitle(index: track.id)"))
        #expect(subtitlePickerBody.contains("scheduleSubtitleDownload(subtitle, streamID: currentStream.id)"))
        #expect(subtitlePickerBody.contains("isShowingSubtitlePicker = false"))

        #expect(audioPickerBody.contains("selectAVAudio(track)"))
        #expect(audioPickerBody.contains("selectEngineAudio(track)"))
        #expect(audioPickerBody.contains("isShowingAudioPicker = false"))
        #expect(audioPickerBody.contains("Text(PlayerViewPolicy.emptyAudioTracksMessage(activeEngine: activeEngine))"))
    }

    private func functionBody(named functionName: String, in source: String) throws -> String {
        guard let signatureRange = source.range(of: "func \(functionName)(") else {
            throw NSError(
                domain: "PlayerResourceTeardownContractTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing function: \(functionName)"]
            )
        }

        guard let openingBrace = source.range(
            of: "{",
            range: signatureRange.upperBound..<source.endIndex
        )?.lowerBound else {
            throw NSError(
                domain: "PlayerResourceTeardownContractTests",
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
            domain: "PlayerResourceTeardownContractTests",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Missing closing brace for function: \(functionName)"]
        )
    }

    private func section(from startToken: String, to endToken: String, in source: String) throws -> String {
        let startRange = try requiredRange(of: startToken, in: source)
        guard let endRange = source.range(
            of: endToken,
            range: startRange.upperBound..<source.endIndex
        ) else {
            throw NSError(
                domain: "PlayerResourceTeardownContractTests",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Missing section terminator: \(endToken)"]
            )
        }
        return String(source[startRange.upperBound..<endRange.lowerBound])
    }

    private func requiredRange(of token: String, in source: String) throws -> Range<String.Index> {
        guard let range = source.range(of: token) else {
            throw NSError(
                domain: "PlayerResourceTeardownContractTests",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Missing token: \(token)"]
            )
        }
        return range
    }

    private func containsIgnoringWhitespace(_ source: String, _ snippet: String) -> Bool {
        normalizedWhitespace(source).contains(normalizedWhitespace(snippet))
    }

    private func normalizedWhitespace(_ source: String) -> String {
        source
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
    }

    private func repoRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }
}
