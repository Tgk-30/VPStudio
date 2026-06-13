import Foundation
import Testing
@testable import VPStudio

@Suite("Player View Contract Coverage - Runtime Wrappers")
struct PlayerViewRuntimeWrapperCoverageTests {
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
        #expect(source.contains("systemName: isControlsLocked ? \"lock.fill\" : \"lock.open\""))
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
            "showEnvironmentPickerAfterMenuDismissal",
            "showCinemaSettingsAfterMenuDismissal",
            "dismissEnvironmentAfterMenuDismissal"
        ] {
            let body = try functionBody(named: functionName, in: source)

            #expect(body.contains("environmentMenuActionTask?.cancel()"))
            #expect(body.contains("environmentMenuActionTask = Task { @MainActor in"))
            #expect(body.contains("await waitForMenuDismissal()"))
            #expect(body.contains("guard !Task.isCancelled else { return }"))

            let cancelRange = try requiredRange(of: "environmentMenuActionTask?.cancel()", in: body)
            let taskRange = try requiredRange(of: "environmentMenuActionTask = Task { @MainActor in", in: body)
            let waitRange = try requiredRange(of: "await waitForMenuDismissal()", in: body)
            let guardRange = try requiredRange(of: "guard !Task.isCancelled else { return }", in: body)

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
        #expect(scheduleBody.contains("scheduleMainWindowRestoreIfNeeded()"))

        let closePlayerBody = try functionBody(named: "closePlayer", in: source)
        #expect(closePlayerBody.contains("cancelVisionLifecycleTasksOnClose()"))
        #expect(closePlayerBody.contains("scheduleImmersiveDismiss(reason: .playerClosed)"))
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
