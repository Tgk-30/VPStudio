import Foundation
import Testing
@testable import VPStudio

@Suite("Player View Contract Coverage - Runtime Wrappers")
struct PlayerViewRuntimeWrapperCoverageTests {
    @Test
    func playerStageFallbackKeepsStableGradientBehindAsyncArtwork() throws {
        let source = try playerViewSource()
        // The async backdrop artwork was extracted into `playerStageBackdropImage`;
        // the fallback composes the gradient behind it in a ZStack.
        let fallbackBody = try section(
            from: "private var playerStageFallback: some View {",
            to: "private func playerStageBackdropImage(",
            in: source
        )
        let gradientRange = try requiredRange(of: "playerStageGradient", in: fallbackBody)
        let artworkRange = try requiredRange(of: "playerStageBackdropImage(", in: fallbackBody)
        // Gradient sits behind the artwork so loading never flashes the stage.
        #expect(gradientRange.lowerBound < artworkRange.lowerBound)
        #expect(fallbackBody.contains("case .none:"))
        #expect(fallbackBody.contains("playerStageBundledArtwork(name: fallbackArtworkAssetName)"))
        #expect(fallbackBody.contains("playerStageNoArtworkBackdrop"))
        #expect(fallbackBody.contains("LinearGradient"))
        #expect(!fallbackBody.contains("RadialGradient"))
        #expect(!fallbackBody.contains("film.stack"))
        #expect(fallbackBody.contains(".foregroundStyle(.white.opacity(0.76))"))
        #expect(fallbackBody.contains("PlayerCinematicChromePolicy.resolvedStageStatusBadgeBackgroundOpacity"))
        #expect(fallbackBody.contains("PlayerCinematicChromePolicy.stageStatusBadgeCornerRadius"))
        #expect(fallbackBody.contains("PlayerCinematicChromePolicy.resolvedStageStatusBadgeBorderOpacity"))
        #expect(fallbackBody.contains("PlayerArtworkPresentationPolicy.resolvedBackdropFallbackOverlayOpacity"))
        #expect(fallbackBody.contains("PlayerArtworkPresentationPolicy.resolvedPosterFallbackOverlayOpacity"))
        #expect(fallbackBody.contains("usesAppleEnvironmentMode: usesAppleEnvironmentChromeLayout"))
        #expect(!fallbackBody.contains("case .none:\n                EmptyView()"))

        // The backdrop AsyncImage fades in on success and clears (Color.clear) on
        // empty/failure/unknown so the stable gradient shows through instead of
        // re-flashing — and it never re-renders the gradient itself.
        let backdropBody = try section(
            from: "private func playerStageBackdropImage(",
            to: "private func playerStagePosterCard(",
            in: source
        )
        let transitionRange = try requiredRange(of: ".transition(.opacity)", in: backdropBody)
        let emptyClearRange = try requiredRange(of: "case .empty, .failure:", in: backdropBody)
        let unknownClearRange = try requiredRange(of: "@unknown default:", in: backdropBody)

        #expect(transitionRange.lowerBound < emptyClearRange.lowerBound)
        #expect(unknownClearRange.lowerBound > emptyClearRange.lowerBound)
        #expect(backdropBody.contains("Color.clear"))
        #expect(!backdropBody.contains("playerStageGradient"))

        let bundledBody = try section(
            from: "private func playerStageBundledArtwork(name: String) -> some View {",
            to: "private var playerStageNoArtworkBackdrop",
            in: source
        )
        #expect(bundledBody.contains("PlayerArtworkPresentationPolicy.resolvedBundledFallbackSaturation"))
        #expect(bundledBody.contains("PlayerArtworkPresentationPolicy.resolvedBundledFallbackBlurRadius"))
        #expect(bundledBody.contains("PlayerArtworkPresentationPolicy.resolvedBundledFallbackOverlayOpacity"))
        #expect(bundledBody.contains("playerStageAppleEnvironmentFallbackVignette"))
        #expect(bundledBody.contains("usesAppleEnvironmentMode: usesAppleEnvironmentChromeLayout"))

        let appleVignetteBody = try section(
            from: "private var playerStageAppleEnvironmentFallbackVignette: some View {",
            to: "private var playerStageNoArtworkBackdrop",
            in: source
        )
        #expect(appleVignetteBody.contains("PlayerArtworkPresentationPolicy.resolvedBundledFallbackVignetteOpacity"))
        #expect(appleVignetteBody.contains("LinearGradient"))
        #expect(!appleVignetteBody.contains("RadialGradient"))
    }

    @Test
    func playerStagePosterCardReservesLayoutWhileArtworkLoadsOrFails() throws {
        let source = try playerViewSource()
        let posterBody = try section(
            from: "private func playerStagePosterCard(",
            to: "private var playerStageGradient",
            in: source
        )

        #expect(posterBody.contains("PlayerArtworkPresentationPolicy.posterCardWidth"))
        #expect(posterBody.contains("PlayerArtworkPresentationPolicy.posterCardHeight"))
        #expect(posterBody.contains("playerStagePosterPlaceholder"))
        #expect(posterBody.contains("playerStagePosterPlaceholder(showsIcon: false)"))
        #expect(posterBody.contains("playerStagePosterPlaceholder(showsIcon: true)"))
        #expect(!posterBody.contains("EmptyView()"))
    }

    @Test
    func seededPlayerPreviewFeedsBundledArtworkIntoRealPlayerSurface() throws {
        let seedSource = try contents(of: "VPStudio/Core/Support/PlayerPreviewSeed.swift")
        let testModeSource = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/TestModeView.swift")

        #expect(seedSource.contains("static var sessionRequest: PlayerSessionRequest"))
        #expect(seedSource.contains("static let fallbackArtworkAssetName = \"genre-art-scifi\""))
        #expect(seedSource.contains("imdbId: imdbID"))
        #expect(testModeSource.contains("let sessionRequest = PlayerPreviewSeed.sessionRequest"))
        #expect(testModeSource.contains("sessionRequest: sessionRequest"))
        #expect(testModeSource.contains("imdbId: sessionRequest.imdbId"))
        #expect(testModeSource.contains("fallbackArtworkAssetName: PlayerPreviewSeed.fallbackArtworkAssetName"))
        #expect(testModeSource.contains("initialEnvironmentAssets: QARuntimeOptions.playerAppleEnvironmentMode"))
        #expect(testModeSource.contains("? EnvironmentVisualQASeed.inactiveAssets"))
        #expect(testModeSource.contains(": EnvironmentVisualQASeed.assets"))
        #expect(testModeSource.contains("static var inactiveAssets: [EnvironmentAsset]"))
        #expect(testModeSource.contains("await appState.clearEnvironmentSelection()"))
        #expect(testModeSource.contains("appState.isImmersiveSpaceOpen = false"))
        #expect(testModeSource.contains("appState.selectedEnvironmentAsset = activeAsset"))
        #expect(testModeSource.contains("case .environmentPicker, .player:"))
    }

    @Test
    func playerSurfaceKeepsRebufferingFeedbackAttachedToTheVideoLayer() throws {
        let source = try playerViewSource()
        let surfaceBody = try section(
            from: "private var playerSurface: some View {",
            to: "private var playerSurfaceContent: some View {",
            in: source
        )
        let feedbackBody = try section(
            from: "private var playerSurfaceFeedbackOverlay: some View {",
            to: "private var sessionBackdropURL",
            in: source
        )

        #expect(surfaceBody.contains("playerSurfaceContent"))
        #expect(surfaceBody.contains("playerSurfaceFeedbackOverlay"))
        #expect(feedbackBody.contains("PlayerBufferingPolicy.surfaceFeedbackText"))
        #expect(feedbackBody.contains("InlineLoadingStatusView(title: text)"))
        #expect(feedbackBody.contains(".allowsHitTesting(false)"))
    }

    @Test
    func transportChromeUsesRaisedObsidianGlassOverBrightPassthrough() throws {
        let source = try playerViewSource()
        let transportBody = try section(
            from: "private var transportBar: some View {",
            to: "private var playbackProgressBar: some View {",
            in: source
        )
        let chromeBody = try section(
            from: "private var transportChromeBackground: some View {",
            to: "private var playbackProgressBar: some View {",
            in: source
        )

        #expect(transportBody.contains(".background {\n            transportChromeBackground\n        }"))
        #expect(chromeBody.contains("if useObsidianGlass"))
        #expect(chromeBody.contains("VPElevation.raised.material"))
        #expect(chromeBody.contains("transportObsidianScrimOpacity"))
        #expect(chromeBody.contains("PlayerCinematicChromePolicy.resolvedTransportObsidianScrimOpacity"))
        #expect(chromeBody.contains("VPColor.glassTintRaised"))
        #expect(chromeBody.contains("shape.fill(.ultraThinMaterial)"))
    }

    @Test
    func topBarButtonsUseRaisedObsidianGlassOverBrightPassthrough() throws {
        let source = try playerViewSource()
        let buttonBody = try section(
            from: "private func topBarUtilityButton(",
            to: "// MARK: - Info Pills Row",
            in: source
        )

        #expect(buttonBody.contains(".background {\n                topBarUtilityButtonBackground(isActive: isActive)\n            }"))
        #expect(buttonBody.contains("private func topBarUtilityButtonBackground(isActive: Bool) -> some View"))
        #expect(buttonBody.contains("if isActive"))
        #expect(buttonBody.contains("VPColor.info.opacity(PlayerCinematicVisualPolicy.activeControlBorderOpacity)"))
        #expect(!buttonBody.contains("VPColor.accent.opacity(0.90)"))
        #expect(!buttonBody.contains("isShowingAudioPicker || availableAudioTrackCount > 1"))
        #expect(buttonBody.contains("Circle().fill(VPElevation.raised.material)"))
        #expect(buttonBody.contains("Circle().fill(Color.black.opacity(PlayerCinematicChromePolicy.topBarButtonObsidianScrimOpacity))"))
        #expect(buttonBody.contains("Circle().fill(VPColor.glassTintRaised)"))
        #expect(buttonBody.contains("Circle().fill(.ultraThinMaterial)"))
        #expect(!buttonBody.contains("Circle().fill(isActive ? VPColor.accent.opacity(0.30) : VPColor.glassTintRaised)"))
        #expect(!buttonBody.contains("Circle().fill(isActive ? AnyShapeStyle(.tint.opacity(0.34)) : AnyShapeStyle(.ultraThinMaterial))"))
    }

    @Test
    func playerChromeTextUsesReadableVisionScale() throws {
        let source = try playerViewSource()
        let titleBody = try section(
            from: "private var titleMetadataBlock: some View {",
            to: "private var titleMetadataItems: [String]",
            in: source
        )
        let infoPillsBody = try section(
            from: "private var infoPillsRow: some View {",
            to: "// MARK: - Transport Bar",
            in: source
        )

        #expect(titleBody.contains(".font(.title2.weight(.semibold))"))
        #expect(titleBody.contains(".font(.callout.weight(.medium))"))
        #expect(!titleBody.contains(".font(.caption2.weight(.medium))"))
        #expect(infoPillsBody.contains(".font(.callout.weight(.semibold))"))
        #expect(infoPillsBody.contains("PlayerCinematicChromePolicy.quickActionPillMinHeight"))
        #expect(!infoPillsBody.contains(".font(.footnote.weight(.semibold))"))
        #expect(!infoPillsBody.contains(".font(.caption2.weight(.semibold))"))
    }

    @Test
    func playerFallbackWaitsForDetectedVideoFrameAndDoesNotDuplicateFailureMessaging() throws {
        let source = try playerViewSource()
        let fallbackBody = try section(
            from: "private var playerStageFallback: some View {",
            to: "private func playerStageBackdropImage(",
            in: source
        )
        let ksRatioBody = try functionBody(
            named: "captureKSVideoRatioAndApplyGeometry",
            in: source
        )
        let fallbackPolicyBody = try functionBody(named: "shouldElevatePlayerStageFallback", in: try contents(of: "VPStudio/Views/Windows/Player/PlayerViewStatePolicy.swift"))

        #expect(source.contains("hasDetectedVideoFrame: detectedVideoRatio != nil"))
        #expect(source.contains("hasExhaustedVideoFrameDetection: didExhaustAVVideoRatioDetection || didExhaustKSVideoRatioRetry"))
        #expect(source.contains("hasRenderablePlayerSurface: hasRenderablePlayerSurface"))
        #expect(source.contains("private var hasRenderablePlayerSurface: Bool"))
        #expect(source.contains("didExhaustAVVideoRatioDetection = true"))
        #expect(source.contains("didExhaustKSVideoRatioRetry = true"))
        #expect(source.contains(".padding(.horizontal, PlayerCinematicChromePolicy.topBarHorizontalPadding)"))
        #expect(source.contains(".frame(maxWidth: resolvedTopBarMaxWidth)"))
        #expect(source.contains("PlayerCinematicChromePolicy.resolvedTopBarMaxWidth("))
        #expect(ksRatioBody.contains("#else"))
        #expect(ksRatioBody.contains("didExhaustKSVideoRatioRetry = true"))
        #expect(fallbackPolicyBody.contains("hasExhaustedVideoFrameDetection && playbackState == .playing"))
        #expect(fallbackBody.contains("isElevatedFallback: shouldElevatePlayerStageFallback"))
        #expect(fallbackBody.contains("isElevatedStageFallback: shouldElevatePlayerStageFallback"))
        #expect(fallbackBody.contains("PlayerArtworkPresentationPolicy.stageStatusBadgeIconName"))
        #expect(!fallbackBody.contains("exclamationmark.triangle.fill"))
    }

    @Test
    func subtitleOverlayUsesDockAwareBottomPadding() throws {
        let source = try playerViewSource()
        let subtitleBody = try section(
            from: "private var subtitleOverlay: some View {",
            to: "private var autoPlayNextOverlay: some View {",
            in: source
        )

        #expect(subtitleBody.contains(".padding(.bottom, subtitleBottomPadding)"))
        #expect(source.contains("private var isTransportDockVisible: Bool"))
        #expect(source.contains("PlayerViewStatePolicy.subtitleBottomPadding("))
        #expect(source.contains("subtitleFontSize: subtitleFontSize"))
    }

    @Test
    func autoplayPromptUsesDockAwareBottomPadding() throws {
        let source = try playerViewSource()
        let promptBody = try section(
            from: "private var autoPlayNextOverlay: some View {",
            to: "private func autoPlayNextPrompt(",
            in: source
        )

        #expect(promptBody.contains(".padding(.bottom, autoPlayNextBottomPadding)"))
        #expect(promptBody.contains(".zIndex(PlayerCinematicChromePolicy.autoPlayPromptZIndex)"))
        #expect(!promptBody.contains(".padding(.bottom, 150)"))
        #expect(source.contains("private var autoPlayNextBottomPadding: CGFloat"))
        #expect(source.contains("PlayerViewStatePolicy.autoPlayNextBottomPadding("))
        #expect(source.contains("hasVisibleSubtitles: engine.currentSubtitleText != nil"))
        #expect(source.contains("subtitleFontSize: subtitleFontSize"))
    }

    @Test
    func subtitleMutationOnlyRunsForTheActiveStream() {
        #expect(PlayerView.subtitleMutationShouldRun(requestedStreamID: "stream-1", currentStreamID: "stream-1"))
        #expect(!PlayerView.subtitleMutationShouldRun(requestedStreamID: "stream-1", currentStreamID: "stream-2"))
        #expect(!PlayerView.subtitleMutationShouldRun(requestedStreamID: "stream-1", currentStreamID: nil))

        let mutationID = UUID()
        #expect(
            PlayerView.subtitleMutationShouldRun(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                requestedMutationID: mutationID,
                activeMutationID: mutationID
            )
        )
        #expect(
            !PlayerView.subtitleMutationShouldRun(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                requestedMutationID: mutationID,
                activeMutationID: nil
            )
        )
        #expect(
            !PlayerView.subtitleMutationShouldRun(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-2",
                requestedMutationID: mutationID,
                activeMutationID: mutationID
            )
        )
    }

    @Test
    func viewLevelRefreshAndPreparationGuardsMatchUnderlyingPolicies() {
        let preparationID = UUID()

        #expect(PlayerView.audioTrackRefreshShouldRun(requestedStreamID: "stream-1", currentStreamID: "stream-1"))
        #expect(!PlayerView.audioTrackRefreshShouldRun(requestedStreamID: "stream-1", currentStreamID: "stream-9"))

        #expect(PlayerView.preparePlaybackShouldRun(
            requestedPreparationID: preparationID,
            activePreparationID: preparationID
        ))
        #expect(!PlayerView.preparePlaybackShouldRun(
            requestedPreparationID: preparationID,
            activePreparationID: UUID()
        ))
    }

    @Test
    func avMediaOptionRefreshForControlMenusIsTrackedAndStreamGuarded() throws {
        let source = try playerViewSource()
        let body = try functionBody(named: "refreshCurrentMediaTrackOptions", in: source)

        #expect(source.contains("@State private var avMediaOptionRefreshTask: Task<Void, Never>?"))
        #expect(body.contains("let streamID = currentStream.id"))
        #expect(body.contains("avMediaOptionRefreshTask?.cancel()"))
        #expect(body.contains("avMediaOptionRefreshTask = Task { @MainActor in"))
        #expect(body.contains("guard !Task.isCancelled,"))
        #expect(body.contains("Self.audioTrackRefreshShouldRun("))
        #expect(body.contains("requestedStreamID: streamID"))
        #expect(body.contains("currentStreamID: currentStream.id"))
        #expect(body.contains("await refreshAVMediaOptions(for: avPlayer)"))
        #expect(!body.contains("Task { await refreshAVMediaOptions(for: avPlayer) }"))
    }

    @Test
    func avMediaOptionRefreshChecksCancellationBeforeAsyncMutations() throws {
        let body = try functionBody(named: "refreshAVMediaOptions", in: try playerViewSource())

        #expect(body.contains("guard !Task.isCancelled, isCurrentAVPlayer(player) else { return }"))
        #expect(body.contains("if let audioGroup = try? await item.asset.loadMediaSelectionGroup(for: .audible) {"))
        #expect(body.contains("if let subtitleGroup = try? await item.asset.loadMediaSelectionGroup(for: .legible) {"))
        #expect(body.contains("engine.subtitlesEnabled = newSubtitlesEnabled"))

        let settingsRange = try requiredRange(of: "let preferredSubtitleLanguages", in: body)
        let bodyAfterSettings = String(body[settingsRange.lowerBound...])
        let postSettingsGuardRange = try requiredRange(
            of: "guard !Task.isCancelled, isCurrentAVPlayer(player) else { return }",
            in: bodyAfterSettings
        )
        let subtitleMutationRange = try requiredRange(of: "engine.subtitlesEnabled = newSubtitlesEnabled", in: body)
        let subtitleMutationAfterSettingsRange = try requiredRange(
            of: "engine.subtitlesEnabled = newSubtitlesEnabled",
            in: bodyAfterSettings
        )

        #expect(settingsRange.lowerBound < subtitleMutationRange.lowerBound)
        #expect(postSettingsGuardRange.lowerBound < subtitleMutationAfterSettingsRange.lowerBound)
    }
}

@Suite("Player View Contract Coverage - Auto-Play Next")
struct PlayerViewAutoplayContractCoverageTests {
    @Test
    func autoplayCountdownTaskPresentsPromptBeforeResolvingNextEpisode() throws {
        let source = try playerViewSource()
        let body = try functionBody(named: "scheduleAutoPlayNextCountdownIfNeeded", in: source)

        #expect(containsIgnoringWhitespace(
            body,
            """
            let state = autoPlayNextPromptState
            guard PlayerAutoplayNextPolicy.shouldScheduleCountdown(state: state) else { return }
            applyAutoPlayNextPromptState(PlayerAutoplayNextPolicy.stateAfterSchedulingCountdown(from: state))
            autoPlayNextCountdownTask?.cancel()
            autoPlayNextCountdownTask = Task { @MainActor in
            """
        ))
        #expect(body.contains("key: SettingsKeys.autoPlayNext"))
        #expect(body.contains("PlayerAutoplayNextPolicy.stateAfterCountdownUnavailable(from: autoPlayNextPromptState)"))
        #expect(body.contains("PlayerAutoplayNextPolicy.stateAfterPresentingCountdown(from: autoPlayNextPromptState)"))
        #expect(body.contains("for seconds in stride("))
        #expect(body.contains("autoPlayNextCountdownRemaining = seconds"))
        #expect(body.contains("try? await Task.sleep(for: .seconds(1))"))
        #expect(body.contains("startAutoPlayNextResolution()"))
    }

    @Test
    func autoplayResolutionRoutesThroughDebridAndReseedsEpisodeState() throws {
        let source = try playerViewSource()
        let body = try functionBody(named: "autoPlayNextEpisodeIfPossible", in: source)

        #expect(body.contains("currentRecoveryContext: currentStream.recoveryContext"))
        #expect(body.contains("let nextStream = try await appState.debridManager.resolveStream(from: nextContext)"))
        #expect(body.contains("persistCurrentWatchProgress()"))
        #expect(body.contains("resetSubtitleStateForStreamTransition()"))
        #expect(body.contains("activeEpisodeId = nextEpisode.episodeId"))
        #expect(body.contains("activeMediaTitle = nextEpisode.title"))
        #expect(body.contains("queuedNextEpisode = nil"))
        #expect(body.contains("streamQueue = [nextStream]"))
        #expect(body.contains("currentStream = nextStream"))

        let resolveRange = try requiredRange(
            of: "let nextStream = try await appState.debridManager.resolveStream(from: nextContext)",
            in: body
        )
        let watchProgressRange = try requiredRange(of: "persistCurrentWatchProgress()", in: body)
        let subtitleResetRange = try requiredRange(of: "resetSubtitleStateForStreamTransition()", in: body)
        let queueClearRange = try requiredRange(of: "queuedNextEpisode = nil", in: body)
        let currentStreamRange = try requiredRange(of: "currentStream = nextStream", in: body)

        #expect(resolveRange.lowerBound < watchProgressRange.lowerBound)
        #expect(watchProgressRange.lowerBound < subtitleResetRange.lowerBound)
        #expect(subtitleResetRange.lowerBound < queueClearRange.lowerBound)
        #expect(queueClearRange.lowerBound < currentStreamRange.lowerBound)
    }
}

@Suite("Player View Contract Coverage - Track Menus")
struct PlayerViewTrackMenuContractCoverageTests {
    @Test
    func lockButtonToggleIsWiredToControlsState() throws {
        let source = try playerViewSource()
        #expect(source.contains("toggleControlsLock()"))
        #expect(source.contains("systemName: isControlsLocked ? \"lock.fill\" : \"lock\""))
        #expect(source.contains("isActive: isControlsLocked"))
        #expect(source.contains("accessibilityLabel: isControlsLocked ? \"Unlock controls\" : \"Lock controls\""))
    }

    @Test
    func hideTransitionUsesFadeOutDuration() throws {
        let body = try functionBody(named: "toggleControlsVisibility", in: try playerViewSource())

        #expect(body.contains("performOptionalAnimation(.easeInOut(duration: PlayerControlVisibilityPolicy.fadeOutDuration))"))
        #expect(body.contains("isShowingControls = false"))
        #expect(body.contains("performOptionalAnimation(.easeInOut(duration: PlayerControlVisibilityPolicy.fadeInDuration))"))
        #expect(body.contains("isShowingControls = true"))
    }

    @Test
    func controlsLockHelperActuallyCancelsOrSchedulesAutoHide() throws {
        let body = try functionBody(named: "toggleControlsLock", in: try playerViewSource())

        #expect(body.contains("isControlsLocked.toggle()"))
        #expect(body.contains("controlsHideTask?.cancel()"))
        #expect(body.contains("controlsHideTask = nil"))
        #expect(body.contains("isShowingControls = true"))
        #expect(body.contains("scheduleControlsHide()"))
        #expect(body.contains("else if isShowingControls, isControlModalPresented == false"))
    }

    @Test
    func closePlayerDismissesPresentedControlModalBeforePlaybackTeardown() throws {
        let source = try playerViewSource()
        let closeBody = try functionBody(named: "closePlayer", in: source)
        let dismissBody = try functionBody(named: "dismissPresentedControlModalForCloseRequest", in: source)

        let modalDismissRange = try requiredRange(of: "dismissPresentedControlModalForCloseRequest()", in: closeBody)
        let closeGuardRange = try requiredRange(of: "guard !didInitiateClose else", in: closeBody)
        #expect(modalDismissRange.lowerBound < closeGuardRange.lowerBound)
        #expect(dismissBody.contains("PlayerViewPolicy.closeRequestAction("))
        #expect(dismissBody.contains("guard action == .dismissControlModal else { return false }"))
        #expect(dismissBody.contains("isShowingSubtitlePicker = false"))
        #expect(dismissBody.contains("isShowingAudioPicker = false"))
        #expect(dismissBody.contains("isShowingEnvironmentPicker = false"))
        #expect(dismissBody.contains("isShowingCinemaSettings = false"))
        #expect(dismissBody.contains("environmentMenuActionTask?.cancel()"))
        #expect(dismissBody.contains("return true"))
    }

    @Test
    func playerCloseControlExposesCancelShortcutThroughClosePolicy() throws {
        let source = try playerViewSource()
        let titleBarBody = try section(
            from: "private var titleBar: some View {",
            to: "private var titleMetadataBlock: some View {",
            in: source
        )

        let closeActionRange = try requiredRange(of: "closePlayer()", in: titleBarBody)
        let shortcutRange = try requiredRange(of: ".keyboardShortcut(.cancelAction)", in: titleBarBody)
        #expect(closeActionRange.lowerBound < shortcutRange.lowerBound)
    }

    @Test
    func subtitlePickerRefreshRebuildsEmbeddedTracksAndOpenSubtitlesCatalog() throws {
        let body = try subtitlePickerBody()

        #expect(body.contains("Section(\"Current Selection\")"))
        #expect(body.contains("Button(\"Off\")"))
        #expect(body.contains("Section(\"Direct Link Subtitles\")"))
        #expect(body.contains("Section(\"OpenSubtitles\")"))
        #expect(body.contains(".accessibilityLabel(\"Refresh subtitle list\")"))
        #expect(body.contains(".disabled(isRefreshingSubtitleCatalog || isDownloadingSubtitle)"))

        let refreshTracksRange = try requiredRange(of: "refreshCurrentMediaTrackOptions()", in: body)
        let refreshCatalogRange = try requiredRange(
            of: "scheduleSubtitleCatalogRefresh(for: currentStream)",
            in: body
        )
        let iconRange = try requiredRange(of: "Image(systemName: \"arrow.clockwise\")", in: body)

        #expect(refreshTracksRange.lowerBound < refreshCatalogRange.lowerBound)
        #expect(refreshCatalogRange.lowerBound < iconRange.lowerBound)
    }

    @Test
    func subtitleCatalogRefreshUsesTrackedCancelableTaskScheduler() throws {
        let source = try playerViewSource()
        let schedulerBody = try functionBody(named: "scheduleSubtitleCatalogRefresh", in: source)

        #expect(schedulerBody.contains("subtitleCatalogTask?.cancel()"))
        #expect(schedulerBody.contains("subtitleCatalogTask = nil"))
        #expect(schedulerBody.contains("subtitleCatalogTask = Task {"))
        #expect(schedulerBody.contains("await refreshSubtitleCatalog("))
        #expect(schedulerBody.contains("requestedStreamID: stream.id"))
        #expect(schedulerBody.contains("mutationID: mutationID"))
        #expect(schedulerBody.contains("let mutationID = UUID()"))
        #expect(schedulerBody.contains("subtitleCatalogMutationID = mutationID"))

        let body = try subtitlePickerBody()
        #expect(body.contains("scheduleSubtitleCatalogRefresh(for: currentStream)"))
        #expect(!body.contains("Task { await refreshSubtitleCatalog(for: currentStream) }"))
    }

    @Test
    func subtitleCatalogRefreshGuardIncludesMutationID() throws {
        let source = try playerViewSource()
        let body = try functionBody(named: "refreshSubtitleCatalog", in: source)

        #expect(body.contains("requestedStreamID: requestedStreamID"))
        #expect(body.contains("requestedMutationID: mutationID"))
        #expect(body.contains("activeMutationID: subtitleCatalogMutationID"))
        #expect(body.contains("if Self.subtitleMutationShouldRun("))
        #expect(body.contains("requestedMutationID: mutationID"))
    }

    @Test
    func subtitleDownloadFlowTracksMutationsWithRequestScopedIDs() throws {
        let source = try playerViewSource()
        let schedulerBody = try functionBody(named: "scheduleSubtitleDownload", in: source)

        #expect(schedulerBody.contains("let mutationID = UUID()"))
        #expect(schedulerBody.contains("subtitleDownloadMutationID = mutationID"))
        #expect(schedulerBody.contains("await downloadAndSelectSubtitle("))

        let body = try functionBody(named: "downloadAndSelectSubtitle", in: source)
        #expect(body.contains("requestedMutationID: mutationID"))
        #expect(body.contains("activeMutationID: subtitleDownloadMutationID"))
        #expect(body.contains("guard Self.subtitleMutationShouldRun("))
    }

    @Test
    func subtitlePickerShowsDownloadedExternalTracksBeforeCatalogFallbackStates() throws {
        let body = try subtitlePickerBody()

        #expect(body.contains("selectExternalSubtitle(index: track.id)"))
        #expect(body.contains("scheduleSubtitleDownload(subtitle, streamID: currentStream.id)"))
        #expect(body.contains("Text(\"Downloading subtitle...\")"))
        #expect(body.contains("Text(\"Searching subtitles...\")"))
        #expect(body.contains("Text(subtitleCatalogMessage ?? \"No subtitle results found for this stream.\")"))

        let downloadedTrackRange = try requiredRange(of: "if !engine.subtitleTracks.isEmpty {", in: body)
        let refreshRange = try requiredRange(of: "if isRefreshingSubtitleCatalog {", in: body)
        let emptyStateRange = try requiredRange(
            of: "} else if subtitleCandidates.isEmpty {",
            in: body
        )
        let candidateRange = try requiredRange(of: "ForEach(subtitleCandidates, id: \\.id) { subtitle in", in: body)

        #expect(downloadedTrackRange.lowerBound < refreshRange.lowerBound)
        #expect(refreshRange.lowerBound < emptyStateRange.lowerBound)
        #expect(emptyStateRange.lowerBound < candidateRange.lowerBound)
    }
}

@Suite("Player View Contract Coverage - Cleanup and Performance")
struct PlayerViewCleanupAndPerformanceContractCoverageTests {
    @Test
    func subtitleResetClearsSelectionsTransientStateAndDownloadedFiles() throws {
        let source = try playerViewSource()
        let body = try functionBody(named: "clearTransientSubtitleState", in: source)

        #expect(containsIgnoringWhitespace(
            body,
            """
            if clearCurrentItemSelection, let avSubtitleGroup {
                avPlayer?.currentItem?.select(nil, in: avSubtitleGroup)
            }
            subtitleCandidates = []
            subtitleCatalogMessage = nil
            isRefreshingSubtitleCatalog = false
            isDownloadingSubtitle = false
            subtitleCatalogMutationID = nil
            subtitleDownloadMutationID = nil
            selectedAVSubtitleID = nil
            clearKSSubtitleSelection()
            engine.loadExternalSubtitles([])
            engine.clearSubtitleSelection()
            """
        ))
        #expect(body.contains("guard removeDownloadedFile, let subtitleFileURL = downloadedSubtitleFileURL else { return }"))
        #expect(body.contains("try? FileManager.default.removeItem(at: subtitleFileURL)"))
        #expect(body.contains("downloadedSubtitleFileURL = nil"))
    }

    @Test
    func streamPropChangesResyncInternalCurrentStreamAndRestartPlayback() throws {
        let source = try playerViewSource()
        #expect(source.contains(".onChange(of: stream)"))
        #expect(source.contains("syncCurrentStreamIfNeeded(stream)"))

        let syncBody = try functionBody(named: "syncCurrentStreamIfNeeded", in: source)
        #expect(syncBody.contains("guard stream != currentStream else { return }"))
        #expect(syncBody.contains("if stream.id != currentStream.id {"))
        #expect(syncBody.contains("persistCurrentWatchProgress()"))
        #expect(syncBody.contains("resetSubtitleStateForStreamTransition()"))
        #expect(syncBody.contains("resetAutoPlayNextStateForStreamTransition()"))
        #expect(syncBody.contains("streamQueue = PlayerSessionRouting.sessionStreams(primary: stream, available: availableStreams)"))
        #expect(syncBody.contains("startPlaybackPreparation(for: stream)"))
        #expect(syncBody.contains("guard !disablesAutomaticTasks else { return }"))
    }

    @Test
    func subtitleStreamTransitionResetCancelsOutstandingWorkBeforeClearingState() throws {
        let source = try playerViewSource()
        let body = try functionBody(named: "resetSubtitleStateForStreamTransition", in: source)

        #expect(body.contains("subtitleSelectionMode = .automaticPreferred"))
        #expect(body.contains("clearTransientSubtitleState(removeDownloadedFile: true, clearCurrentItemSelection: true)"))

        let catalogCancelRange = try requiredRange(of: "subtitleCatalogTask?.cancel()", in: body)
        let downloadCancelRange = try requiredRange(of: "subtitleDownloadTask?.cancel()", in: body)
        let refreshCancelRange = try requiredRange(of: "subtitleTrackRefreshTask?.cancel()", in: body)
        let clearRange = try requiredRange(
            of: "clearTransientSubtitleState(removeDownloadedFile: true, clearCurrentItemSelection: true)",
            in: body
        )

        #expect(catalogCancelRange.lowerBound < clearRange.lowerBound)
        #expect(downloadCancelRange.lowerBound < clearRange.lowerBound)
        #expect(refreshCancelRange.lowerBound < clearRange.lowerBound)
    }

    @Test
    func ksplayerProgressUpdatesAreThrottledToLimitMenuDrivenLag() throws {
        let source = try playerViewSource()
        let body = try section(
            from: "coordinator.onPlay = { currentTime, totalTime in",
            to: "coordinator.onFinish = { _, error in",
            in: source
        )

        #expect(body.contains("if abs(engine.currentTime - newTime) >= 0.25 {"))
        #expect(body.contains("engine.currentTime = newTime"))
        #expect(body.contains("engine.updateSubtitleText(at: newTime)"))
        #expect(body.contains("if abs(engine.duration - newDuration) > 1.0 {"))
        #expect(body.contains("engine.duration = newDuration"))
        #expect(body.contains("handlePlaybackProgressForAutoplay(currentTime: newTime, duration: newDuration)"))

        let currentTimeThrottleRange = try requiredRange(of: "if abs(engine.currentTime - newTime) >= 0.25 {", in: body)
        let durationThrottleRange = try requiredRange(of: "if abs(engine.duration - newDuration) > 1.0 {", in: body)
        let autoplayRange = try requiredRange(
            of: "handlePlaybackProgressForAutoplay(currentTime: newTime, duration: newDuration)",
            in: body
        )

        #expect(currentTimeThrottleRange.lowerBound < durationThrottleRange.lowerBound)
        #expect(durationThrottleRange.lowerBound < autoplayRange.lowerBound)
    }

    @Test
    func delayedEnvironmentMenuActionsAreTrackedAndCanceledOnTeardown() throws {
        let source = try playerViewSource()

        #expect(source.contains("@State private var environmentMenuActionTask: Task<Void, Never>?"))

        for functionName in [
            "openCinemaEnvironmentAfterMenuDismissal",
            "openEnvironmentAfterMenuDismissal",
            "openAppleEnvironmentAfterMenuDismissal",
            "showEnvironmentPickerAfterMenuDismissal",
            "showCinemaSettingsAfterMenuDismissal",
            "dismissEnvironmentAfterMenuDismissal",
            "clearEnvironmentSelectionAfterMenuDismissal"
        ] {
            let body = try functionBody(named: functionName, in: source)

            #expect(body.contains("environmentMenuActionTask?.cancel()"))
            #expect(body.contains("environmentMenuActionTask = Task { @MainActor in"))
            #expect(body.contains("await waitForMenuDismissal()"))
            #expect(body.contains("guard !Task.isCancelled, acceptsPlayerLifecycleCallbacks else { return }"))

            let cancelRange = try requiredRange(of: "environmentMenuActionTask?.cancel()", in: body)
            let taskRange = try requiredRange(of: "environmentMenuActionTask = Task { @MainActor in", in: body)
            let waitRange = try requiredRange(of: "await waitForMenuDismissal()", in: body)
            let guardRange = try requiredRange(
                of: "guard !Task.isCancelled, acceptsPlayerLifecycleCallbacks else { return }",
                in: body
            )

            #expect(cancelRange.lowerBound < taskRange.lowerBound)
            #expect(taskRange.lowerBound < waitRange.lowerBound)
            #expect(waitRange.lowerBound < guardRange.lowerBound)
        }

        let closeCleanupBody = try functionBody(named: "cancelVisionLifecycleTasksOnClose", in: source)
        #expect(closeCleanupBody.contains("environmentMenuActionTask?.cancel()"))
        #expect(closeCleanupBody.contains("environmentMenuActionTask = nil"))

        let disappearBody = try section(
            from: ".onDisappear {",
            to: ".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))",
            in: source
        )
        #expect(disappearBody.contains("environmentMenuActionTask?.cancel()"))
        #expect(disappearBody.contains("environmentMenuActionTask = nil"))
    }

    @Test
    func alreadyOpenEnvironmentActionsShowTransientFeedbackBeforeReturning() throws {
        let source = try playerViewSource()
        let environmentBody = try section(
            from: "private func openEnvironment(_ asset: EnvironmentAsset) async {",
            to: "private func environmentAssetIcon(_ asset: EnvironmentAsset) -> String {",
            in: source
        )
        let cinemaBody = try functionBody(named: "openCinemaEnvironment", in: source)

        let environmentAlreadyOpenBlock = try section(
            from: "if plan == .alreadyOpen {",
            to: "guard await ensureEnvironmentAssetCanOpen(asset) else {",
            in: environmentBody
        )
        #expect(environmentAlreadyOpenBlock.contains(
            "showTransientPlayerMessage(PlayerImmersiveTransitionPolicy.environmentAlreadyOpenMessage(assetName: asset.name))"
        ))
        let environmentMessageRange = try requiredRange(
            of: "showTransientPlayerMessage(PlayerImmersiveTransitionPolicy.environmentAlreadyOpenMessage(assetName: asset.name))",
            in: environmentAlreadyOpenBlock
        )
        let environmentReturnRange = try requiredRange(of: "return", in: environmentAlreadyOpenBlock)
        #expect(environmentMessageRange.lowerBound < environmentReturnRange.lowerBound)

        let activationGuardRange = try requiredRange(
            of: "guard await appState.activateEnvironmentAsset(asset) else {",
            in: environmentBody
        )
        let openCustomRange = try requiredRange(of: "await openImmersiveSpaceIfPossible(for: asset)", in: environmentBody)
        #expect(activationGuardRange.lowerBound < openCustomRange.lowerBound)
        #expect(environmentBody.contains("await loadEnvironmentAssets()"))
        #expect(environmentBody.contains(
            "showTransientPlayerMessage(PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name))"
        ))

        let cinemaAlreadyOpenBlock = try section(
            from: "case .alreadyOpen:",
            to: "case .open:",
            in: cinemaBody
        )
        #expect(cinemaAlreadyOpenBlock.contains(
            "showTransientPlayerMessage(PlayerImmersiveTransitionPolicy.cinemaAlreadyOpenMessage)"
        ))
        let cinemaMessageRange = try requiredRange(
            of: "showTransientPlayerMessage(PlayerImmersiveTransitionPolicy.cinemaAlreadyOpenMessage)",
            in: cinemaAlreadyOpenBlock
        )
        let cinemaReturnRange = try requiredRange(of: "return", in: cinemaAlreadyOpenBlock)
        #expect(cinemaMessageRange.lowerBound < cinemaReturnRange.lowerBound)
    }

    @Test
    func playbackInterruptionsRestoreControlsAndClearPendingAutoHide() throws {
        let source = try playerViewSource()

        #expect(source.contains(".onChange(of: playbackState)"))
        #expect(source.contains(".onChange(of: isCurrentlyPlaying)"))

        let toggleBody = try functionBody(named: "toggleControlsVisibility", in: source)
        #expect(toggleBody.contains("playbackState: playbackState"))
        #expect(toggleBody.contains("isPlaying: isCurrentlyPlaying"))
        #expect(toggleBody.contains("case .keepVisibleAndCancelScheduledHide:"))
        #expect(toggleBody.contains("restoreControlsForNonInteractivePlaybackIfNeeded()"))

        let restoreBody = try functionBody(named: "restoreControlsForNonInteractivePlaybackIfNeeded", in: source)
        #expect(restoreBody.contains("PlayerViewStatePolicy.shouldAutoHideControls"))
        #expect(restoreBody.contains("controlsHideTask?.cancel()"))
        #expect(restoreBody.contains("controlsHideTask = nil"))
        #expect(restoreBody.contains("isShowingControls = true"))

        let scheduleBody = try functionBody(named: "scheduleControlsHide", in: source)
        #expect(scheduleBody.contains("controlsHideTask = nil"))
        #expect(scheduleBody.contains("return"))
    }

    @Test
    func autoSuggestedEnvironmentMustPersistBeforeOpeningImmersiveSpaceWithoutNeutralFallback() throws {
        let source = try playerViewSource()
        let autoOpenBody = try functionBody(named: "autoOpenEnvironmentIfNeeded", in: source)

        #expect(autoOpenBody.contains("guard await appState.selectSuggestedEnvironmentAsset(match) else { return }"))
        let suggestRange = try requiredRange(
            of: "guard await appState.selectSuggestedEnvironmentAsset(match) else { return }",
            in: autoOpenBody
        )
        let openRange = try requiredRange(of: "await openImmersiveSpaceIfPossible(for: asset)", in: autoOpenBody)
        let dimRange = try requiredRange(of: "await loadDimPassthroughPreference()", in: autoOpenBody)
        #expect(suggestRange.lowerBound < openRange.lowerBound)
        #expect(suggestRange.lowerBound < dimRange.lowerBound)
        #expect(dimRange.lowerBound < openRange.lowerBound)
        #expect(!autoOpenBody.contains("appState.selectSuggestedEnvironmentAsset(match)\n"))
        #expect(!autoOpenBody.contains("defaultEnvironmentAssetForAutoOpen"))
        #expect(!autoOpenBody.contains("GenreEnvironmentSuggestionPolicy.neutralDefault.matchKey"))

        let settingsSource = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/EnvironmentSettingsView.swift")
        #expect(settingsSource.contains("If nothing matches, playback stays in Apple Environment."))
        #expect(!settingsSource.contains("falling back to the neutral environment"))
    }

    @Test
    func appleEnvironmentModeUsesSystemWindowExpansionInsteadOfForcedRatio() throws {
        let source = try playerViewSource()
        let gravityBody = try section(
            from: "private var currentVideoGravity: AVLayerVideoGravity {",
            to: "private var shouldElevatePlayerStageFallback: Bool {",
            in: source
        )
        let geometryBody = try functionBody(named: "applyVisionOSWindowGeometry", in: source)

        #expect(source.contains("private var usesAppleEnvironmentMode: Bool"))
        #expect(source.contains("PlayerEnvironmentMenuPolicy.usesAppleEnvironmentMode("))
        #expect(source.contains("@State private var didApplyInitialDimDefault = false"))
        #expect(source.contains("@State private var didExpandAppleEnvironmentWindow = false"))
        #expect(source.contains("@State private var playerSceneActivationTask: Task<Void, Never>?"))
        #expect(source.contains("applyInitialDimDefaultIfNeeded()"))
        #expect(source.contains("private func applyInitialDimDefaultIfNeeded()"))
        #expect(source.contains("PlayerViewPolicy.defaultDimPassthrough("))
        let initialLoadBody = try functionBody(named: "loadInitialPlayerState", in: source)
        let loadAssetsRange = try requiredRange(of: "await loadEnvironmentAssets()", in: initialLoadBody)
        let initialDimRange = try requiredRange(of: "applyInitialDimDefaultIfNeeded()", in: initialLoadBody)
        let privacyRange = try requiredRange(of: "await loadPrivacyPreferences()", in: initialLoadBody)
        let autoOpenRange = try requiredRange(of: "await autoOpenEnvironmentIfNeeded()", in: initialLoadBody)
        let loadDimRange = try requiredRange(of: "await loadDimPassthroughPreference()", in: initialLoadBody)
        #expect(loadAssetsRange.lowerBound < initialDimRange.lowerBound)
        #expect(initialDimRange.lowerBound < privacyRange.lowerBound)
        #expect(loadAssetsRange.lowerBound < autoOpenRange.lowerBound)
        #expect(autoOpenRange.lowerBound < loadDimRange.lowerBound)
        let onAppearBody = try section(
            from: ".onAppear {",
            to: ".onDisappear {",
            in: source
        )
        #expect(!onAppearBody.contains("applyInitialDimDefaultIfNeeded()"))
        #expect(onAppearBody.contains("startPlayerSceneActivation()"))
        let activationBody = try functionBody(named: "startPlayerSceneActivation", in: source)
        let activationYieldRange = try requiredRange(of: "await Task.yield()", in: activationBody)
        let activationSuppressRange = try requiredRange(of: "scheduleMainWindowSuppressionIfNeeded()", in: activationBody)
        let activationGeometryRange = try requiredRange(of: "scheduleVisionOSWindowGeometryUpdate()", in: activationBody)
        #expect(activationYieldRange.lowerBound < activationSuppressRange.lowerBound)
        #expect(activationSuppressRange.lowerBound < activationGeometryRange.lowerBound)
        let scheduledGeometryBody = try functionBody(named: "scheduleVisionOSWindowGeometryUpdate", in: source)
        #expect(source.contains(".onChange(of: playerWindowScene) { _, _ in\n            expandPendingAppleEnvironmentWindowIfAvailable()\n            scheduleVisionOSWindowGeometryUpdate()\n        }"))
        #expect(scheduledGeometryBody.contains("await Task.yield()"))
        #expect(scheduledGeometryBody.contains("guard playerWindowScene.map({ ObjectIdentifier($0) }) == trackedSceneID else { return }"))
        #expect(scheduledGeometryBody.contains("applyVisionOSWindowGeometry(cancelPendingTask: false)"))
        #expect(source.contains("private func applyVisionOSWindowGeometry(cancelPendingTask: Bool = true)"))
        #expect(geometryBody.contains("if cancelPendingTask"))
        #expect(gravityBody.contains("if usesAppleEnvironmentChromeLayout"))
        #expect(gravityBody.contains("return .resizeAspect"))
        #expect(geometryBody.contains("if usesAppleEnvironmentChromeLayout"))
        #expect(geometryBody.contains("requestAppleEnvironmentExpandedWindowGeometry(on: windowScene)"))
        #expect(geometryBody.contains("if !aspectRatioSelection.locksWindowRatio"))
        #expect(source.contains("private var playerBaseBackdrop: some View"))
        #expect(source.contains("private var playerSurfaceBackdrop: some View"))
        #expect(source.contains("if usesAppleEnvironmentChromeLayout {\n            Color.clear"))
        #expect(source.contains("allowsTransparentBackground: usesAppleEnvironmentChromeLayout"))
        #expect(source.contains(".immersiveEnvironmentPicker {\n            playerSystemEnvironmentPickerEntries\n        }"))
        let systemPickerBody = try section(
            from: "private var playerSystemEnvironmentPickerEntries: some View {",
            to: "#endif\n\n    @ViewBuilder\n    private var playerSurfaceFeedbackOverlay",
            in: source
        )
        #expect(systemPickerBody.contains("Text(EnvironmentPreviewRowPolicy.appleEnvironmentTitle)"))
        #expect(systemPickerBody.contains("Image(systemName: \"visionpro\")"))
        #expect(systemPickerBody.contains("Text(PlayerEnvironmentMenuPolicy.appleEnvironmentMenuBenefit)"))
        #expect(systemPickerBody.contains("await openAppleEnvironmentFromSystemPicker()"))
        let appleEnvironmentPickerBody = try functionBody(named: "openAppleEnvironmentFromSystemPicker", in: source)
        #expect(appleEnvironmentPickerBody.contains("guard await clearEnvironmentSelection() else"))
        #expect(appleEnvironmentPickerBody.contains("pendingAppleEnvironmentWindowExpansion = false"))
        #expect(appleEnvironmentPickerBody.contains("expandAppleEnvironmentWindowIfAvailable(allowPending: true)"))
        let appleEnvironmentMenuBody = try functionBody(named: "openAppleEnvironmentAfterMenuDismissal", in: source)
        #expect(appleEnvironmentMenuBody.contains("await openAppleEnvironmentFromSystemPicker()"))
        let appleEnvironmentExpandBody = try functionBody(named: "expandAppleEnvironmentWindowIfAvailable", in: source)
        #expect(appleEnvironmentExpandBody.contains("guard canExpandAppleEnvironmentWindow else"))
        #expect(appleEnvironmentExpandBody.contains("pendingAppleEnvironmentWindowExpansion = true"))
        #expect(appleEnvironmentExpandBody.contains("PlayerEnvironmentMenuPolicy.appleEnvironmentPendingBenefit"))
        #expect(appleEnvironmentExpandBody.contains("PlayerEnvironmentMenuPolicy.appleEnvironmentFallbackBenefit"))
        #expect(appleEnvironmentExpandBody.contains("expandAppleEnvironmentWindow()"))
        let pendingExpandBody = try functionBody(named: "expandPendingAppleEnvironmentWindowIfAvailable", in: source)
        #expect(pendingExpandBody.contains("pendingAppleEnvironmentWindowExpansion"))
        #expect(pendingExpandBody.contains("usesAppleEnvironmentMode"))
        #expect(pendingExpandBody.contains("canExpandAppleEnvironmentWindow"))
        #expect(pendingExpandBody.contains("expandAppleEnvironmentWindow()"))
        #expect(source.contains("private func applyVisionOSEnvironmentPresentationMode()"))
        #expect(source.contains(".persistentSystemOverlays(persistentSystemOverlayVisibility)"))
        #expect(source.contains("private var persistentSystemOverlayVisibility: Visibility"))
        #expect(source.contains("usesAppleEnvironmentChromeLayout ? .hidden : (isShowingControls ? .automatic : .hidden)"))
        #expect(source.contains("private var usesAppleEnvironmentChromeLayout: Bool"))
        #expect(source.contains("return usesAppleEnvironmentMode\n            && didExpandAppleEnvironmentWindow\n            && canExpandAppleEnvironmentWindow"))
        #expect(source.contains("private var canExpandAppleEnvironmentWindow: Bool"))
        #expect(source.contains("PlayerCinemaEnvironmentPolicy.canOpen(\n                activeEngine: activeEngine,\n                hasAVPlayer: avPlayer != nil\n            )"))
        #expect(source.contains("accessibilityLabel: \"Expand Apple Environment\""))
        #expect(source.contains("PlayerEnvironmentMenuPolicy.showsAppleEnvironmentExpandAction("))
        #expect(source.contains("PlayerEnvironmentMenuPolicy.appleEnvironmentExpandTitle"))
        #expect(source.contains("PlayerCinematicChromePolicy.closeMenuTitle"))
        #expect(source.contains("PlayerCinematicChromePolicy.closeMenuIconName"))
        #expect(source.contains("onExpandAppleEnvironment: {"))
        #expect(source.components(separatedBy: "expandAppleEnvironmentWindowIfAvailable(allowPending: true)").count - 1 >= 6)
        #expect(!source.contains("expandAppleEnvironmentWindowIfAvailable()\n"))
        #expect(source.contains("onClear: {\n                        keepControlsVisibleForMenuAction()\n                        openAppleEnvironmentAfterMenuDismissal()\n                    }"))
        #expect(source.contains("isAppleEnvironmentExpansionPending: pendingAppleEnvironmentWindowExpansion"))
        #expect(source.contains("isExpansionPending: pendingAppleEnvironmentWindowExpansion"))
        #expect(source.contains("onCloseMenu: {\n                        closeOpenControlMenu()\n                    }"))
        #expect(!source.contains(".disabled(!canExpandAppleEnvironmentWindow)"))
        #expect(source.contains("private func applyAppleEnvironmentExpandedWindowGeometry()"))
        #expect(source.contains("private func requestAppleEnvironmentExpandedWindowGeometry(on windowScene: UIWindowScene)"))
        #expect(source.contains("visionGeometryTask = nil\n            return\n        }\n\n        requestAppleEnvironmentExpandedWindowGeometry(on: windowScene)"))
        #expect(source.contains("PlayerCinematicChromePolicy.appleEnvironmentExpandedWindowSize"))
        #expect(source.contains("PlayerCinematicChromePolicy.appleEnvironmentExpansionRelaxDelay"))
        #expect(source.contains("appleEnvironmentFreeformGeometryPreferences()"))
        let preparePlaybackBody = try functionBody(named: "preparePlayback", in: source)
        let activePlayerRange = try requiredRange(of: "appState.activeAVPlayer = player", in: preparePlaybackBody)
        let pendingExpandRange = try requiredRange(of: "expandPendingAppleEnvironmentWindowIfAvailable()", in: preparePlaybackBody)
        let presentationRange = try requiredRange(of: "applyVisionOSEnvironmentPresentationMode()", in: preparePlaybackBody)
        #expect(activePlayerRange.lowerBound < pendingExpandRange.lowerBound)
        #expect(pendingExpandRange.lowerBound < presentationRange.lowerBound)
        #expect(source.contains(".onChange(of: playerWindowScene) { _, _ in\n            expandPendingAppleEnvironmentWindowIfAvailable()"))
        let playerCoreBody = try section(
            from: "private var playerCore: some View {",
            to: "private var persistentSystemOverlayVisibility: Visibility {",
            in: source
        )
        let visualStageRange = try requiredRange(of: "playerVisualStage", in: playerCoreBody)
        let surfaceTreatmentRange = try requiredRange(of: "appleEnvironmentSurfaceTreatment", in: playerCoreBody)
        let subtitleOverlayRange = try requiredRange(of: "subtitleOverlay", in: playerCoreBody)
        let controlsOverlayRange = try requiredRange(of: "controlsOverlay", in: playerCoreBody)
        #expect(visualStageRange.lowerBound < surfaceTreatmentRange.lowerBound)
        #expect(surfaceTreatmentRange.lowerBound < subtitleOverlayRange.lowerBound)
        #expect(surfaceTreatmentRange.lowerBound < controlsOverlayRange.lowerBound)
        #expect(!playerCoreBody.contains(".overlay {\n            appleEnvironmentSurfaceTreatment\n        }"))
        let playerSurfaceContentBody = try section(
            from: "private var playerSurfaceContent: some View {",
            to: "#endif\n\n    @ViewBuilder\n    private var playerSystemEnvironmentPickerEntries",
            in: source
        )
        #expect(!playerSurfaceContentBody.contains(".immersiveEnvironmentPicker"))
        #expect(source.contains("private var appleEnvironmentSurfaceTreatment: some View"))
        #expect(source.contains("if usesAppleEnvironmentChromeLayout"))
        #expect(source.contains("PlayerCinematicChromePolicy.appleEnvironmentSurfaceRimOpacity"))
        #expect(!source.contains("appleEnvironmentSurfaceTopSheen"))
        #expect(!source.contains("appleEnvironmentSurfaceSideReflection"))
        #expect(!source.contains("appleEnvironmentSurfaceLowerReflection"))
        #expect(!source.contains("appleEnvironmentSurfaceLowerShade"))
        #expect(source.contains("PlayerCinematicChromePolicy.resolvedControlsDockBottomPadding("))
        #expect(source.contains("PlayerCinematicChromePolicy.resolvedTransportCardMaxWidth("))
        #expect(source.contains(".onChange(of: appState.isImmersiveSpaceOpen)"))
        #expect(source.contains(".onChange(of: appState.activeEnvironment)"))
        #expect(source.contains(".onChange(of: appState.selectedEnvironmentAsset?.id)"))
        #expect(source.contains("applyVisionOSEnvironmentPresentationMode()"))
        #expect(source.contains("Free Resize"))
    }

    @Test
    func appleEnvironmentExpansionStateIsExplicitAndResetsOnEnvironmentSwitches() throws {
        let source = try playerViewSource()
        let expandBody = try functionBody(named: "expandAppleEnvironmentWindow", in: source)
        let resetBody = try functionBody(named: "resetAppleEnvironmentExpansionState", in: source)
        let closeBody = try functionBody(named: "closePlayer", in: source)
        let clearBody = try functionBody(named: "clearEnvironmentSelection", in: source)
        let openEnvironmentBody = try functionBody(named: "openEnvironment", in: source)
        let openCinemaBody = try functionBody(named: "openCinemaEnvironment", in: source)

        let expandStateRange = try requiredRange(of: "didExpandAppleEnvironmentWindow = true", in: expandBody)
        let freeformRange = try requiredRange(of: "aspectRatioSelection = .freeform", in: expandBody)
        let geometryRange = try requiredRange(of: "applyAppleEnvironmentExpandedWindowGeometry()", in: expandBody)
        #expect(expandStateRange.lowerBound < freeformRange.lowerBound)
        #expect(freeformRange.lowerBound < geometryRange.lowerBound)

        #expect(resetBody.contains("pendingAppleEnvironmentWindowExpansion = false"))
        #expect(resetBody.contains("didExpandAppleEnvironmentWindow = false"))
        #expect(closeBody.contains("resetAppleEnvironmentExpansionState()"))
        #expect(clearBody.contains("resetAppleEnvironmentExpansionState()"))
        #expect(openEnvironmentBody.contains("resetAppleEnvironmentExpansionState()"))
        #expect(openCinemaBody.contains("resetAppleEnvironmentExpansionState()"))
    }

    @Test
    func customEnvironmentOpenFailureRollsBackPersistedSelection() throws {
        let body = try functionBody(named: "openImmersiveSpaceIfPossible", in: try playerViewSource())

        #expect(body.contains("await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)"))
        #expect(body.contains("PlayerImmersiveTransitionPolicy.openFailedMessage(assetName: asset.name)"))

        let cancelRange = try requiredRange(of: "appState.cancelImmersiveTransition()", in: body)
        let clearRange = try requiredRange(
            of: "await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)",
            in: body
        )
        let messageRange = try requiredRange(
            of: "showTransientPlayerMessage(PlayerImmersiveTransitionPolicy.openFailedMessage(assetName: asset.name))",
            in: body
        )
        #expect(cancelRange.lowerBound < clearRange.lowerBound)
        #expect(clearRange.lowerBound < messageRange.lowerBound)
    }

    @Test
    func missingImportedEnvironmentAssetClearsPersistedSelectionThroughAppState() throws {
        let body = try functionBody(named: "ensureEnvironmentAssetCanOpen", in: try playerViewSource())

        #expect(body.contains("resolvedAssetURL(for: asset)"))
        #expect(body.contains("asset.sourceType == .imported"))
        #expect(body.contains("deleteAsset(id: asset.id)"))
        #expect(body.contains("await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)"))
        #expect(!body.contains("selectedEnvironmentAsset = nil"))

        let deleteRange = try requiredRange(of: "deleteAsset(id: asset.id)", in: body)
        let clearRange = try requiredRange(
            of: "await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)",
            in: body
        )
        let reloadRange = try requiredRange(of: "await loadEnvironmentAssets()", in: body)
        let messageRange = try requiredRange(
            of: "showTransientPlayerMessage(PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name))",
            in: body
        )
        #expect(deleteRange.lowerBound < clearRange.lowerBound)
        #expect(clearRange.lowerBound < reloadRange.lowerBound)
        #expect(reloadRange.lowerBound < messageRange.lowerBound)
    }

    @Test
    func successfulEnvironmentCatalogLoadReconcilesStaleSelectedAsset() throws {
        let body = try functionBody(named: "loadEnvironmentAssets", in: try playerViewSource())

        #expect(body.contains("assets = try await appState.environmentCatalogManager.fetchAssets()"))
        #expect(body.contains("environmentAssets = []"))
        #expect(body.contains("appState.reconcileEnvironmentSelection(withLoadedAssets: assets)"))
        #expect(!body.contains("(try? await appState.environmentCatalogManager.fetchAssets()) ?? []"))

        let fetchRange = try requiredRange(
            of: "assets = try await appState.environmentCatalogManager.fetchAssets()",
            in: body
        )
        let loadedRange = try requiredRange(of: "environmentAssets = assets", in: body)
        let reconcileRange = try requiredRange(
            of: "appState.reconcileEnvironmentSelection(withLoadedAssets: assets)",
            in: body
        )
        let failureRange = try requiredRange(of: "environmentAssets = []", in: body)
        #expect(fetchRange.lowerBound < loadedRange.lowerBound)
        #expect(loadedRange.lowerBound < reconcileRange.lowerBound)
        #expect(failureRange.lowerBound < reconcileRange.lowerBound)
    }

    @Test
    func immersiveDismissActionsAreTrackedAndCanceledOnTeardown() throws {
        let source = try playerViewSource()

        #expect(source.contains("@State private var immersiveDismissTask: Task<Void, Never>?"))
        let dismissHandler = try section(
            from: "onDismiss: {",
            to: "))\n        #endif",
            in: source
        )
        #expect(dismissHandler.contains("recordImmersiveControlEvent(.dismiss)"))
        #expect(dismissHandler.contains("scheduleImmersiveDismiss(reason: .userInitiated)"))
        let recordRange = try requiredRange(of: "recordImmersiveControlEvent(.dismiss)", in: dismissHandler)
        let scheduleRange = try requiredRange(
            of: "scheduleImmersiveDismiss(reason: .userInitiated)",
            in: dismissHandler
        )
        #expect(recordRange.lowerBound < scheduleRange.lowerBound)
        #expect(!source.contains("onDismiss: { Task { await dismissImmersiveIfNeeded(reason: .userInitiated) } }"))

        let scheduleBody = try functionBody(named: "scheduleImmersiveDismiss", in: source)
        #expect(scheduleBody.contains("immersiveDismissTask?.cancel()"))
        #expect(scheduleBody.contains("immersiveDismissTask = Task { @MainActor in"))
        #expect(scheduleBody.contains("guard !Task.isCancelled else { return }"))
        #expect(scheduleBody.contains("await dismissImmersiveIfNeeded(reason: reason)"))
        #expect(scheduleBody.contains("if restoresMainWindow"))
        #expect(!scheduleBody.contains("didDismiss"))
        #expect(!scheduleBody.contains("restoresMainWindow &&"))
        #expect(scheduleBody.contains("scheduleMainWindowRestoreIfNeeded()"))

        let closePlayerBody = try functionBody(named: "closePlayer", in: source)
        #expect(closePlayerBody.contains("cancelVisionLifecycleTasksOnClose()"))
        #expect(closePlayerBody.contains("scheduleImmersiveDismiss(reason: .playerClosed, restoresMainWindow: true)"))
        #expect(!closePlayerBody.contains("Task {\n            await dismissImmersiveIfNeeded(reason: .playerClosed)"))

        let closeCleanupBody = try functionBody(named: "cancelVisionLifecycleTasksOnClose", in: source)
        #expect(closeCleanupBody.contains("immersiveDismissTask?.cancel()"))
        #expect(closeCleanupBody.contains("immersiveDismissTask = nil"))

        let disappearBody = try section(
            from: ".onDisappear {",
            to: ".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))",
            in: source
        )
        #expect(disappearBody.contains("immersiveDismissTask?.cancel()"))
        #expect(disappearBody.contains("immersiveDismissTask = nil"))
        #expect(disappearBody.contains("scheduleImmersiveDismiss(reason: .playerClosed, restoresMainWindow: true)"))
    }
}

private func playerViewSource() throws -> String {
    try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
}

private func subtitlePickerBody() throws -> String {
    try section(
        from: "private var subtitlePickerSheet: some View {",
        to: "private var audioPickerSheet: some View {",
        in: try playerViewSource()
    )
}

private func functionBody(named functionName: String, in source: String) throws -> String {
    guard let signatureRange = source.range(of: "func \(functionName)(") else {
        throw NSError(
            domain: "PlayerViewContractCoverageTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing function: \(functionName)"]
        )
    }

    guard let openingBrace = source.range(
        of: "{",
        range: signatureRange.upperBound..<source.endIndex
    )?.lowerBound else {
        throw NSError(
            domain: "PlayerViewContractCoverageTests",
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
        domain: "PlayerViewContractCoverageTests",
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
            domain: "PlayerViewContractCoverageTests",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Missing section terminator: \(endToken)"]
        )
    }
    return String(source[startRange.upperBound..<endRange.lowerBound])
}

private func requiredRange(of token: String, in source: String) throws -> Range<String.Index> {
    guard let range = source.range(of: token) else {
        throw NSError(
            domain: "PlayerViewContractCoverageTests",
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
