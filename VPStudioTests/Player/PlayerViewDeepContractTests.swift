import Foundation
import Testing
@testable import VPStudio

@Suite("Player View Deep Contracts - Policies")
struct PlayerViewDeepPolicyTests {
    @Test
    func playbackStateTitlesAreStable() {
        #expect(PlayerViewPolicy.playbackStateTitle(for: .preparing) == "Preparing Playback")
        #expect(PlayerViewPolicy.playbackStateTitle(for: .buffering) == "Buffering")
        #expect(PlayerViewPolicy.playbackStateTitle(for: .playing) == "Playing")
        #expect(PlayerViewPolicy.playbackStateTitle(for: .failed) == "Playback Failed")
    }

    @Test
    func lifecyclePolicyMatchesPlatformExpectations() {
        #if os(macOS) || os(visionOS)
        #expect(PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack)
        #else
        #expect(!PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack)
        #endif
        #expect(PlayerLifecyclePolicy.dismissesCurrentPresentationOnBack)
    }

    @Test
    func transportControlsEnvironmentPlacementDefaultsToLeftNav() {
        #expect(!PlayerTransportControlsPolicy.showsRightTransportEnvironmentControl(placement: .leftNavigation))
        #expect(PlayerTransportControlsPolicy.showsRightTransportEnvironmentControl(placement: .rightTransportControls))
    }

    @Test
    func clampedSeekTargetNeverEscapesDuration() {
        #expect(PlayerViewPolicy.clampedSeekTarget(time: -10, duration: 100) == 0)
        #expect(PlayerViewPolicy.clampedSeekTarget(time: 999, duration: 100) == 100)
        #expect(PlayerViewPolicy.clampedSeekTarget(time: 50, duration: 100) == 50)

        #expect(PlayerViewPolicy.clampedSeekTarget(percent: -1, duration: 100) == 0)
        #expect(PlayerViewPolicy.clampedSeekTarget(percent: 2, duration: 100) == 100)
        #expect(PlayerViewPolicy.clampedSeekTarget(percent: 0.25, duration: 80) == 20)

        #expect(PlayerViewPolicy.clampedSeekTarget(currentTime: 50, offset: -999, duration: 100) == 0)
        #expect(PlayerViewPolicy.clampedSeekTarget(currentTime: 50, offset: 999, duration: 100) == 100)
    }

    @Test
    func scrobbleProgressPercentClampsAndRejectsInvalidInputs() {
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: 0, duration: 0) == 0)
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: .nan, duration: 100) == 0)
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: 25, duration: 100) == 25)
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: -5, duration: 100) == 0)
        #expect(PlayerViewPolicy.scrobbleProgressPercent(currentTime: 200, duration: 100) == 100)
    }

    @Test
    func scrobbleIMDbIDPrefersExplicitOMDbIdentity() {
        #expect(PlayerViewPolicy.scrobbleIMDbID(
            mediaId: "movie-tmdb-438631",
            imdbId: "https://www.imdb.com/title/TT1160419/"
        ) == "tt1160419")
        #expect(PlayerViewPolicy.scrobbleIMDbID(mediaId: "movie-imdb-tt2543164", imdbId: nil) == "tt2543164")
        #expect(PlayerViewPolicy.scrobbleIMDbID(mediaId: "movie-tmdb-438631", imdbId: nil) == nil)
    }

    @Test
    func bufferedPercentRejectsInvalidRanges() {
        #expect(PlayerViewPolicy.bufferedPercent(
            loadedRangeStart: 0,
            loadedRangeDuration: 1,
            itemDuration: 0
        ) == nil)

        #expect(PlayerViewPolicy.bufferedPercent(
            loadedRangeStart: .infinity,
            loadedRangeDuration: 1,
            itemDuration: 10
        ) == nil)

        #expect(PlayerViewPolicy.bufferedPercent(
            loadedRangeStart: 0,
            loadedRangeDuration: 5,
            itemDuration: 10
        ) == 0.5)
    }

    @Test
    func subtitleFontSizeIsClampedToAReadableRange() {
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: nil) == 24)
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: .nan) == 24)
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: 1) == 16)
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: 999) == 48)
        #expect(PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: 22) == 22)
    }

    @Test
    func controlModalPresentedIsTrueIfAnyControlSheetIsUp() {
        #expect(PlayerViewPolicy.isControlModalPresented(
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isShowingEnvironmentPicker: false,
            isShowingCinemaSettings: false
        ) == false)

        #expect(PlayerViewPolicy.isControlModalPresented(
            isShowingSubtitlePicker: true,
            isShowingAudioPicker: false,
            isShowingEnvironmentPicker: false,
            isShowingCinemaSettings: false
        ))

        #expect(PlayerViewPolicy.isControlModalPresented(
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: true,
            isShowingEnvironmentPicker: false,
            isShowingCinemaSettings: false
        ))
    }
}

@Suite("Player View Deep Contracts - Autoplay Policy")
struct PlayerViewDeepAutoplayPolicyTests {
    @Test
    func countdownStartsOnlyNearEndAndOnlyOnce() {
        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 0,
            duration: 100,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: false,
            isResolving: false
        ))

        #expect(PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 95,
            duration: 100,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: false,
            isResolving: false
        ))

        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 95,
            duration: 100,
            hasNextEpisode: true,
            hasStartedCountdown: true,
            wasCancelled: false,
            isResolving: false
        ))

        #expect(!PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: 95,
            duration: 100,
            hasNextEpisode: true,
            hasStartedCountdown: false,
            wasCancelled: true,
            isResolving: false
        ))
    }

    @Test
    func countdownProgressIsClampedToBounds() {
        #expect(PlayerAutoplayNextPolicy.countdownProgress(remainingSeconds: -10) == 0)
        #expect(PlayerAutoplayNextPolicy.countdownProgress(remainingSeconds: PlayerAutoplayNextPolicy.countdownDurationSeconds) == 1)
        #expect(PlayerAutoplayNextPolicy.countdownProgress(remainingSeconds: 0) == 0)
    }

    @Test
    func promptStateTransitionsArePredictable() {
        var state = PlayerAutoplayNextPolicy.PromptState.idle(hasNextEpisode: true)
        #expect(PlayerAutoplayNextPolicy.shouldScheduleCountdown(state: state))

        state = PlayerAutoplayNextPolicy.stateAfterSchedulingCountdown(from: state)
        #expect(state.didRequestAutoplayNext)

        state = PlayerAutoplayNextPolicy.stateAfterPresentingCountdown(from: state)
        #expect(state.isShowingAutoPlayNextPrompt)
        #expect(state.countdownRemaining == PlayerAutoplayNextPolicy.countdownDurationSeconds)

        state = PlayerAutoplayNextPolicy.stateAfterStartingResolution(from: state)
        #expect(state.isResolvingAutoPlayNextEpisode)
        #expect(state.isShowingAutoPlayNextPrompt)

        state = PlayerAutoplayNextPolicy.stateAfterFinishingResolution(from: state, outcome: .succeeded)
        #expect(!state.hasNextEpisode)
        #expect(!state.isShowingAutoPlayNextPrompt)
        #expect(!state.isResolvingAutoPlayNextEpisode)
        #expect(state.countdownRemaining == PlayerAutoplayNextPolicy.countdownDurationSeconds)
    }
}

@Suite("Player View Deep Contracts - Menus and Sheets (Source)")
struct PlayerViewDeepMenuAndSheetContractTests {
    @Test
    func titleBarMenuContainsStreamAndAspectRatioContracts() throws {
        let source = try playerViewSource()
        let body = try section(
            from: "// Stream quality picker",
            to: "topBarUtilityButton(systemName: \"ellipsis\", accessibilityLabel: \"More Playback Options\")",
            in: source
        )

        #expect(body.contains("Section(\"Stream\")"))
        #expect(body.contains("ForEach(streamQueue, id: \\.id) { stream in"))
        #expect(body.contains("keepControlsVisibleForMenuAction()"))
        #expect(body.contains("switchToStream(stream)"))

        let streamForEachRange = try requiredRange(of: "ForEach(streamQueue, id: \\.id) { stream in", in: body)
        let keepRange = try requiredRange(
            of: "keepControlsVisibleForMenuAction()",
            in: String(body[streamForEachRange.upperBound..<body.endIndex])
        )
        let switchRange = try requiredRange(
            of: "switchToStream(stream)",
            in: String(body[streamForEachRange.upperBound..<body.endIndex])
        )
        #expect(keepRange.lowerBound < switchRange.lowerBound)

        #expect(body.contains("Section(\"Aspect Ratio\")"))
        #expect(body.contains("Label(\"Freeflow Resize\", systemImage: \"arrow.up.left.and.arrow.down.right\")"))
        #expect(body.contains("ForEach(AspectRatioSelection.allCases.filter { $0 != .freeform }, id: \\.id) { selection in"))
    }

    @Test
    func titleBarMenuEnvironmentSectionIncludesCinemaAndExitContracts() throws {
        let source = try playerViewSource()
        let body = try section(
            from: "Section(\"Environment\") {",
            to: "#endif",
            in: source
        )

        #expect(body.contains("PlayerEnvironmentMenuLabel("))
        #expect(body.contains("spec: .standardRoom("))
        #expect(body.contains("spec: .cinema("))
        #expect(body.contains("spec: .compactAsset("))
        #expect(body.contains("PlayerCinemaEnvironmentPolicy.canOpen("))
        #expect(body.contains("Label(\"Cinema Settings\", systemImage: \"slider.horizontal.3\")"))
        #expect(body.contains("Text(\"No imported environments\")"))
        #expect(body.contains("Label(\"Browse Environments\", systemImage: \"mountain.2\")"))
        #expect(body.contains("Label(\"Exit Environment\", systemImage: \"xmark.circle\")"))
    }

    @Test
    func subtitlePickerRefreshOrdersTrackRefreshBeforeCatalogRefresh() throws {
        let source = try playerViewSource()
        let body = try subtitlePickerBody(in: source)

        let refreshRange = try requiredRange(of: "refreshCurrentMediaTrackOptions()", in: body)
        let catalogRange = try requiredRange(of: "scheduleSubtitleCatalogRefresh(for: currentStream)", in: body)
        #expect(refreshRange.lowerBound < catalogRange.lowerBound)
        #expect(body.contains(".accessibilityLabel(\"Refresh subtitle list\")"))
    }

    @Test
    func audioPickerEmptyStateAndRefreshContractsExist() throws {
        let source = try playerViewSource()
        let body = try audioPickerBody(in: source)

        #expect(body.contains(".navigationTitle(\"Audio\")"))
        #expect(body.contains("Section(\"Direct Link Audio\")"))
        #expect(body.contains("Section(\"Audio\")"))
        #expect(body.contains("Text(PlayerViewPolicy.emptyAudioTracksMessage(activeEngine: activeEngine))"))
        #expect(body.contains("Label(\"Refresh Track List\", systemImage: \"arrow.clockwise\")"))
        #expect(body.contains(".accessibilityLabel(\"Refresh audio tracks\")"))
        #expect(body.contains(".disabled(!canRefreshTrackList)"))
    }
}

@Suite("Player View Deep Contracts - Teardown and Throttling (Source)")
struct PlayerViewDeepTeardownAndThrottlingContractTests {
    @Test
    func onDisappearCancelsWorkAndPerformsCleanupInOrder() throws {
        let source = try playerViewSource()
        let body = try section(
            from: ".onDisappear {",
            to: ".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))",
            in: source
        )

        #expect(body.contains("stopProgressPersistence()"))
        #expect(body.contains("scrobbleStop()"))
        #expect(body.contains("persistCurrentWatchProgress()"))
        #expect(body.contains("cleanupPlayback()"))
        #expect(body.contains("controlsHideTask?.cancel()"))
        #expect(body.contains("FileManager.default.removeItem(at: subtitleFileURL)"))
        #expect(body.contains("downloadedSubtitleFileURL = nil"))

        let stopRange = try requiredRange(of: "stopProgressPersistence()", in: body)
        let scrobbleRange = try requiredRange(of: "scrobbleStop()", in: body)
        let cleanupRange = try requiredRange(of: "cleanupPlayback()", in: body)
        let controlsRange = try requiredRange(of: "controlsHideTask?.cancel()", in: body)
        #expect(stopRange.lowerBound < scrobbleRange.lowerBound)
        #expect(scrobbleRange.lowerBound < cleanupRange.lowerBound)
        #expect(cleanupRange.lowerBound < controlsRange.lowerBound)
    }

    @Test
    func closePlayerCancelsTasksBeforeDismissalAndWindowRestoration() throws {
        let source = try playerViewSource()
        let body = try functionBody(named: "closePlayer", in: source)

        #expect(body.contains("didInitiateClose = true"))
        #expect(body.contains("persistCurrentWatchProgress()"))
        #expect(body.contains("cleanupPlayback(clearSession: true)"))
        #expect(body.contains("dismissDedicatedPlayerWindow()"))
        #expect(!body.contains("scheduleMainWindowRestoreIfNeeded()"))

        let persistRange = try requiredRange(of: "persistCurrentWatchProgress()", in: body)
        let cleanupRange = try requiredRange(of: "cleanupPlayback(clearSession: true)", in: body)
        let bodyAfterCleanup = String(body[cleanupRange.upperBound..<body.endIndex])
        #expect(persistRange.lowerBound < cleanupRange.lowerBound)
        #expect(bodyAfterCleanup.contains("dismissDedicatedPlayerWindow()"))
    }

    @Test
    func dedicatedPlayerWindowDismissalTargetsValueBackedWindowBeforeFallback() throws {
        let source = try playerViewSource()
        let body = try functionBody(named: "dismissDedicatedPlayerWindow", in: source)

        #expect(body.contains("if let sessionRequest"))
        #expect(body.contains("dismissWindow(id: \"player\", value: sessionRequest)"))
        #expect(body.contains("dismissWindow(id: \"player\")"))

        let valueDismissalRange = try requiredRange(
            of: "dismissWindow(id: \"player\", value: sessionRequest)",
            in: body
        )
        let fallbackDismissalRange = try requiredRange(
            of: "dismissWindow(id: \"player\")",
            in: body
        )
        #expect(valueDismissalRange.lowerBound < fallbackDismissalRange.lowerBound)
    }

    @Test
    func cleanupPlaybackReleasesObserversAndResetsSessionState() throws {
        let source = try playerViewSource()
        let body = try functionBody(named: "cleanupPlayback", in: source)
        let observerHelperBody = try functionBody(named: "removeAVTimeObserverIfNeeded", in: source)

        #expect(body.contains("resetAutoPlayNextStateForStreamTransition()"))
        #expect(body.contains("removeAVTimeObserverIfNeeded()"))
        #expect(observerHelperBody.contains("guard let token = timeObserverToken else { return }"))
        #expect(observerHelperBody.contains("avTimeObserverHooks.removeTimeObserver(player, token)"))
        #expect(observerHelperBody.contains("player.removeTimeObserver(token)"))
        #expect(observerHelperBody.contains("timeObserverToken = nil"))
        #expect(observerHelperBody.contains("timeObserverPlayer = nil"))
        #expect(body.contains("appState.releasePlayerResources(clearSession: clearSession, sessionID: sessionID)"))
        #expect(body.contains("engine.resetSessionState()"))

        let resetAutoplayRange = try requiredRange(of: "resetAutoPlayNextStateForStreamTransition()", in: body)
        let removeObserverRange = try requiredRange(of: "removeAVTimeObserverIfNeeded()", in: body)
        let releaseRange = try requiredRange(of: "appState.releasePlayerResources(clearSession: clearSession, sessionID: sessionID)", in: body)
        #expect(resetAutoplayRange.lowerBound < removeObserverRange.lowerBound)
        #expect(removeObserverRange.lowerBound < releaseRange.lowerBound)
    }

    @Test
    func avPlayerPeriodicObserverThrottlesObservableWritesToPreventStutter() throws {
        let source = try playerViewSource()
        let body = try functionBody(named: "startObservingAVPlayer", in: source)

        #expect(body.contains("player.addPeriodicTimeObserver"))
        #expect(body.contains("if abs(engine.currentTime - newTime) >= Self.avPlayerPeriodicObserverIntervalSeconds {"))
        #expect(body.contains("PlayerViewPolicy.subtitleTextRefreshShouldRun("))
        #expect(body.contains("if abs(engine.bufferedPercent - newBuffered) > 0.01 {"))
        #expect(body.contains("handlePlaybackProgressForAutoplay(currentTime: newTime, duration: engine.duration)"))
        #expect(body.contains("scheduleAVVideoRatioDetection(from: asset, player: player)"))
        #expect(body.contains("scheduleAVHDRMetadataExtraction(from: asset, player: player)"))
        #expect(!body.contains("Task { await detectVideoRatio(from: asset, player: player) }"))

        let timeThrottleRange = try requiredRange(
            of: "if abs(engine.currentTime - newTime) >= Self.avPlayerPeriodicObserverIntervalSeconds {",
            in: body
        )
        let subtitleGateRange = try requiredRange(of: "PlayerViewPolicy.subtitleTextRefreshShouldRun(", in: body)
        let bufferedGateRange = try requiredRange(of: "if abs(engine.bufferedPercent - newBuffered) > 0.01 {", in: body)
        #expect(timeThrottleRange.lowerBound < subtitleGateRange.lowerBound)
        #expect(subtitleGateRange.lowerBound < bufferedGateRange.lowerBound)
    }

    @Test
    func avMetadataExtractionTasksAreSingleFlightAndCanceledOnCleanup() throws {
        let source = try playerViewSource()

        #expect(source.contains("@State private var videoRatioDetectionTask: Task<Void, Never>?"))
        #expect(source.contains("@State private var hdrMetadataExtractionTask: Task<Void, Never>?"))
        #expect(source.contains("@State private var didAttemptVideoRatioDetection = false"))
        #expect(source.contains("@State private var didAttemptHDRMetadataExtraction = false"))

        let ratioBody = try functionBody(named: "scheduleAVVideoRatioDetection", in: source)
        #expect(ratioBody.contains("!didAttemptVideoRatioDetection"))
        #expect(ratioBody.contains("videoRatioDetectionTask == nil"))
        #expect(ratioBody.contains("didAttemptVideoRatioDetection = true"))
        #expect(ratioBody.contains("videoRatioDetectionTask = Task { @MainActor in"))
        #expect(ratioBody.contains("await detectVideoRatio(from: asset, player: player)"))

        let hdrBody = try functionBody(named: "scheduleAVHDRMetadataExtraction", in: source)
        #expect(hdrBody.contains("!didAttemptHDRMetadataExtraction"))
        #expect(hdrBody.contains("hdrMetadataExtractionTask == nil"))
        #expect(hdrBody.contains("didAttemptHDRMetadataExtraction = true"))
        #expect(hdrBody.contains("hdrMetadataExtractionTask = Task { @MainActor in"))
        #expect(hdrBody.contains("let metadata = await HDRMetadataExtractor.extract(from: asset)"))

        let cleanupBody = try functionBody(named: "cleanupPlayback", in: source)
        #expect(cleanupBody.contains("videoRatioDetectionTask?.cancel()"))
        #expect(cleanupBody.contains("videoRatioDetectionTask = nil"))
        #expect(cleanupBody.contains("hdrMetadataExtractionTask?.cancel()"))
        #expect(cleanupBody.contains("hdrMetadataExtractionTask = nil"))
        #expect(cleanupBody.contains("didAttemptVideoRatioDetection = false"))
        #expect(cleanupBody.contains("didAttemptHDRMetadataExtraction = false"))
    }
}

private func playerViewSource() throws -> String {
    try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
}

private func subtitlePickerBody(in source: String) throws -> String {
    try section(
        from: "private var subtitlePickerSheet: some View {",
        to: "private var audioPickerSheet: some View {",
        in: source
    )
}

private func audioPickerBody(in source: String) throws -> String {
    try section(
        from: "private var audioPickerSheet: some View {",
        to: "private var playPausePresentation",
        in: source
    )
}

private func functionBody(named functionName: String, in source: String) throws -> String {
    guard let signatureRange = source.range(of: "func \(functionName)(") else {
        throw NSError(
            domain: "PlayerViewDeepContractTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing function: \(functionName)"]
        )
    }

    guard let openingBrace = source.range(
        of: "{",
        range: signatureRange.upperBound..<source.endIndex
    )?.lowerBound else {
        throw NSError(
            domain: "PlayerViewDeepContractTests",
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
        domain: "PlayerViewDeepContractTests",
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
            domain: "PlayerViewDeepContractTests",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Missing section terminator: \(endToken)"]
        )
    }
    return String(source[startRange.upperBound..<endRange.lowerBound])
}

private func requiredRange(of token: String, in source: String) throws -> Range<String.Index> {
    guard let range = source.range(of: token) else {
        throw NSError(
            domain: "PlayerViewDeepContractTests",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Missing token: \(token)"]
        )
    }
    return range
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
