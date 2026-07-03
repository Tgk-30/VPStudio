import Foundation
import CoreGraphics
@preconcurrency import KSPlayer

enum PlayerViewStatePolicy {
    enum MainWindowAction: Equatable {
        case none
        case dismissMainAndMarkSuppressed
        case openMainAndMarkRestored
    }

    enum ActiveSessionChangeAction: Equatable {
        case keepOpen
        case closeCurrentSession
        case closeStaleScene
    }

    struct AutoplayPromptFields: Equatable {
        var didRequestAutoplayNext: Bool
        var didCancelAutoPlayNextPrompt: Bool
        var isShowingAutoPlayNextPrompt: Bool
        var isResolvingAutoPlayNextEpisode: Bool
        var countdownRemaining: Int
    }

    struct StreamTransitionPlan: Equatable {
        var stream: StreamInfo
        var message: String
    }

    enum TrackRefreshRoute: Equatable {
        case avPlayer
        case ksPlayer
        case none
    }

    enum AVPlayerStartupAction: Equatable {
        case playImmediately
        case playAfterMinimizingStalls
    }

    enum ControlsToggleAction: Equatable {
        case keepVisibleForPresentedModal
        case keepVisibleAndCancelScheduledHide
        case showAndScheduleHide
        case hideAndCancelScheduledHide
    }

    enum ControlModalVisibilityAction: Equatable {
        case prepareForPresentation
        case scheduleHide
    }

    struct ControlModalImmersiveFlags: Equatable {
        var isShowingEnvironmentPicker: Bool
        var isShowingCinemaSettings: Bool
    }

    struct MediaTrackSnapshot: Equatable {
        var trackID: Int
        var name: String
        var description: String
        var languageCode: String?
        var isEnabled: Bool
    }

    struct KSSubtitleOptionFields: Equatable {
        var id: String
        var name: String
        var language: String?
    }

    struct SubtitleLookupRequest: Equatable {
        var apiKey: String
        var languages: [String]
        var query: String
    }

    enum AutoPlayNextPreflight: Equatable {
        case finishUnavailable
        case proceed(PlayerSessionRequest.NextEpisodeCandidate)
    }

    enum AutoSubtitlePreflight: Equatable {
        case skip
        case download(SubtitleLookupRequest)
    }

    enum SubtitleCatalogPreflight: Equatable {
        case missingAPIKey(message: String)
        case emptyQuery(message: String)
        case search(SubtitleLookupRequest)
    }

    enum SubtitleDownloadPreflight: Equatable {
        case skip
        case unsupported(message: String)
        case missingAPIKey(message: String)
        case download(apiKey: String, fileID: Int)
    }

    static func mainWindowSuppressionAction(isSuppressed: Bool) -> MainWindowAction {
        isSuppressed ? .none : .dismissMainAndMarkSuppressed
    }

    static func mainWindowRestoreAction(isSuppressed: Bool) -> MainWindowAction {
        isSuppressed ? .openMainAndMarkRestored : .none
    }

    static func activeSessionChangeAction(
        activeSessionID: UUID?,
        playerSessionID: UUID?
    ) -> ActiveSessionChangeAction {
        if activeSessionID == playerSessionID {
            return .keepOpen
        }

        if activeSessionID == nil {
            return .closeCurrentSession
        }

        return .closeStaleScene
    }

    static func autoplayPromptState(
        hasNextEpisode: Bool,
        didRequestAutoplayNext: Bool,
        didCancelAutoPlayNextPrompt: Bool,
        isShowingAutoPlayNextPrompt: Bool,
        isResolvingAutoPlayNextEpisode: Bool,
        countdownRemaining: Int
    ) -> PlayerAutoplayNextPolicy.PromptState {
        PlayerAutoplayNextPolicy.PromptState(
            hasNextEpisode: hasNextEpisode,
            didRequestAutoplayNext: didRequestAutoplayNext,
            didCancelAutoPlayNextPrompt: didCancelAutoPlayNextPrompt,
            isShowingAutoPlayNextPrompt: isShowingAutoPlayNextPrompt,
            isResolvingAutoPlayNextEpisode: isResolvingAutoPlayNextEpisode,
            countdownRemaining: countdownRemaining
        )
    }

    static func autoplayPromptFields(from state: PlayerAutoplayNextPolicy.PromptState) -> AutoplayPromptFields {
        AutoplayPromptFields(
            didRequestAutoplayNext: state.didRequestAutoplayNext,
            didCancelAutoPlayNextPrompt: state.didCancelAutoPlayNextPrompt,
            isShowingAutoPlayNextPrompt: state.isShowingAutoPlayNextPrompt,
            isResolvingAutoPlayNextEpisode: state.isResolvingAutoPlayNextEpisode,
            countdownRemaining: state.countdownRemaining
        )
    }

    static func nextStream(after current: StreamInfo, in queue: [StreamInfo]) -> StreamInfo? {
        PlayerStreamFailoverPlanner.nextStream(after: current, in: queue)
    }

    static func streamTransitionPlan(from current: StreamInfo, to candidate: StreamInfo) -> StreamTransitionPlan? {
        guard candidate.id != current.id else { return nil }
        return StreamTransitionPlan(
            stream: candidate,
            message: "Switching stream to \(candidate.quality.rawValue)..."
        )
    }

    static func trackRefreshRoute(
        activeEngine: PlayerEngineKind?,
        hasAVPlayer: Bool,
        hasKSPlayerCoordinator: Bool
    ) -> TrackRefreshRoute {
        switch activeEngine {
        case .avPlayer where hasAVPlayer:
            return .avPlayer
        case .ksPlayer where hasKSPlayerCoordinator:
            return .ksPlayer
        default:
            return .none
        }
    }

    static func resolvedEngineStrategy(from rawValue: String?) -> PlayerEngineStrategy {
        PlayerEngineStrategy(rawValue: rawValue ?? "") ?? .compatibility
    }

    static func controlsToggleAction(
        isControlModalPresented: Bool,
        isShowingControls: Bool,
        playbackState: PlayerPlaybackState,
        isPlaying: Bool,
        isScrubbing: Bool,
        isShowingSubtitlePicker: Bool,
        isShowingAudioPicker: Bool,
        isControlsLocked: Bool,
        isShowingEnvironmentPicker: Bool,
        isShowingCinemaSettings: Bool
    ) -> ControlsToggleAction {
        if isControlModalPresented {
            return .keepVisibleForPresentedModal
        }

        guard isShowingControls else { return .showAndScheduleHide }

        let canHideControls = shouldAutoHideControls(
            playbackState: playbackState,
            isPlaying: isPlaying,
            isScrubbing: isScrubbing,
            isShowingSubtitlePicker: isShowingSubtitlePicker,
            isShowingAudioPicker: isShowingAudioPicker,
            isControlsLocked: isControlsLocked,
            isShowingEnvironmentPicker: isShowingEnvironmentPicker,
            isShowingCinemaSettings: isShowingCinemaSettings
        )

        return canHideControls ? .hideAndCancelScheduledHide : .keepVisibleAndCancelScheduledHide
    }

    static func controlModalVisibilityAction(
        isPresented: Bool,
        hasPresentedControlModal: Bool = false
    ) -> ControlModalVisibilityAction {
        isPresented || hasPresentedControlModal ? .prepareForPresentation : .scheduleHide
    }

    static func shouldShowControlsForModalPresentation(isShowingControls: Bool) -> Bool {
        !isShowingControls
    }

    static func shouldElevatePlayerStageFallback(
        playbackState: PlayerPlaybackState,
        hasPlayedOnce: Bool,
        hasDetectedVideoFrame: Bool = true,
        hasExhaustedVideoFrameDetection: Bool = false,
        hasRenderablePlayerSurface: Bool = true
    ) -> Bool {
        if !hasRenderablePlayerSurface {
            return true
        }

        if playbackState == .failed || !hasPlayedOnce {
            return true
        }

        if hasDetectedVideoFrame {
            return false
        }

        if hasExhaustedVideoFrameDetection && playbackState == .playing {
            return true
        }

        if playbackState == .playing {
            return false
        }

        return true
    }

    static func shouldShowTransportDock(
        playbackState: PlayerPlaybackState,
        hasPlayedOnce: Bool
    ) -> Bool {
        playbackState == .playing || hasPlayedOnce
    }

    static func subtitleBottomPadding(
        isShowingControls: Bool,
        showsTransportDock: Bool,
        subtitleFontSize: CGFloat = 24,
        containerSize: CGSize = .zero,
        usesAppleEnvironmentMode: Bool = false,
        videoAspectRatio: CGFloat? = nil,
        videoUsesAspectFit: Bool = false
    ) -> CGFloat {
        let dynamicExtra = PlayerCinematicChromePolicy.subtitleDynamicBottomPaddingExtra(
            fontSize: subtitleFontSize
        )
        let basePadding: CGFloat
        if isShowingControls && showsTransportDock {
            basePadding = PlayerCinematicChromePolicy.resolvedOverlayBottomPaddingAboveTransportDock(
                containerSize: containerSize,
                usesAppleEnvironmentMode: usesAppleEnvironmentMode
            )
        } else {
            basePadding = PlayerCinematicChromePolicy.resolvedSubtitleHiddenControlsBottomPadding(
                containerSize: containerSize
            )
        }
        // Letterboxed aspect-fit video: subtitles stay pinned inside the
        // picture, never in the bottom bar. Zero (no-op) for aspect-fill,
        // unmeasured containers, or an unknown video ratio.
        let letterboxBar = videoUsesAspectFit
            ? PlayerCinematicChromePolicy.letterboxBarHeight(
                containerSize: containerSize,
                videoAspectRatio: videoAspectRatio
            )
            : 0
        let letterboxFloor = letterboxBar > 0
            ? letterboxBar + PlayerCinematicChromePolicy.subtitleLetterboxClearance
            : 0
        return max(basePadding, letterboxFloor) + dynamicExtra
    }

    static func autoPlayNextBottomPadding(
        isShowingControls: Bool,
        showsTransportDock: Bool,
        hasVisibleSubtitles: Bool = false,
        subtitleFontSize: CGFloat = 24,
        containerSize: CGSize = .zero,
        usesAppleEnvironmentMode: Bool = false
    ) -> CGFloat {
        let subtitleExtra = hasVisibleSubtitles
            ? PlayerCinematicChromePolicy.subtitleDynamicBottomPaddingExtra(fontSize: subtitleFontSize)
            : 0

        guard isShowingControls && showsTransportDock else {
            let hiddenBase = PlayerCinematicChromePolicy.resolvedAutoPlayHiddenControlsBottomPadding(
                containerSize: containerSize,
                hasVisibleSubtitles: hasVisibleSubtitles
            )
            return hasVisibleSubtitles ? hiddenBase + subtitleExtra : hiddenBase
        }

        let basePadding = PlayerCinematicChromePolicy.resolvedOverlayBottomPaddingAboveTransportDock(
            containerSize: containerSize,
            usesAppleEnvironmentMode: usesAppleEnvironmentMode
        )
        return hasVisibleSubtitles
            ? basePadding + PlayerCinematicChromePolicy.autoPlaySubtitleSeparation + subtitleExtra
            : basePadding
    }

    static func avPlayerObservedPlaybackState(
        currentState: PlayerPlaybackState,
        isPlaying: Bool,
        isBuffering: Bool,
        hasPlayedOnce: Bool,
        bufferedPercent: Double = 0,
        bufferedSecondsAhead: TimeInterval = 0
    ) -> PlayerPlaybackState {
        if isPlaying {
            return .playing
        }

        if isBuffering,
           PlayerBufferingPolicy.isBufferReady(
               bufferedPercent: bufferedPercent,
               bufferedSecondsAhead: bufferedSecondsAhead
           ) {
            return .playing
        }

        if isBuffering {
            return .buffering
        }

        if hasPlayedOnce, currentState == .buffering {
            return .playing
        }

        return currentState
    }

    static func avPlayerObservedBuffering(
        isWaitingToPlayAtSpecifiedRate: Bool,
        isPlaybackBufferEmpty: Bool,
        isPlaybackLikelyToKeepUp: Bool,
        hasPlayedOnce: Bool,
        isPlaybackPaused: Bool = false,
        bufferedPercent: Double = 0,
        bufferedSecondsAhead: TimeInterval = 0
    ) -> Bool {
        if isPlaybackPaused { return false }
        if PlayerBufferingPolicy.isBufferReady(
            bufferedPercent: bufferedPercent,
            bufferedSecondsAhead: bufferedSecondsAhead
        ) { return false }
        if isPlaybackBufferEmpty {
            return hasPlayedOnce || !isPlaybackLikelyToKeepUp
        }
        if isPlaybackLikelyToKeepUp { return false }
        return isWaitingToPlayAtSpecifiedRate
    }

    static func ksPlayerObservedPlaybackState(
        currentState: PlayerPlaybackState,
        observedState: KSPlayerState,
        hasPlayedOnce: Bool,
        bufferedPercent: Double = 0
    ) -> PlayerPlaybackState {
        switch observedState {
        case .initialized, .preparing:
            return .preparing
        case .readyToPlay:
            return PlayerBufferingPolicy.isBufferReady(bufferedPercent: bufferedPercent) || hasPlayedOnce
                ? .playing
                : .buffering
        case .buffering:
            return hasPlayedOnce && PlayerBufferingPolicy.isBufferReady(bufferedPercent: bufferedPercent)
                ? .playing
                : .buffering
        case .bufferFinished:
            return .playing
        case .paused, .playedToTheEnd:
            return currentState == .buffering && hasPlayedOnce ? .playing : currentState
        case .error:
            return .failed
        }
    }

    static func ksPlayerPlaybackStateAfterProgressTick(
        currentState: PlayerPlaybackState,
        observedState: KSPlayerState,
        currentTime: TimeInterval,
        duration: TimeInterval
    ) -> PlayerPlaybackState {
        guard currentState == .preparing || currentState == .buffering else {
            return currentState
        }
        guard observedState == .readyToPlay || observedState == .buffering || observedState == .bufferFinished else {
            return currentState
        }
        guard shouldRecordKSPlaybackProgress(currentTime: currentTime, duration: duration) else {
            return currentState
        }
        guard currentTime.isFinite, currentTime > 0 else {
            return currentState
        }
        return .playing
    }

    /// Whether a KSPlayer time-tick reflects genuine decode progress. KSPlayer's
    /// played-to-the-end path emits one final synthetic tick with
    /// `currentTime == duration`, even when a dead/truncated stream ended after a
    /// few seconds, so ticks at (or past) the reported duration are not treated
    /// as real progress.
    static func shouldRecordKSPlaybackProgress(
        currentTime: TimeInterval,
        duration: TimeInterval
    ) -> Bool {
        guard currentTime.isFinite, currentTime >= 0 else { return false }
        guard duration.isFinite, duration > 0 else { return true }
        return currentTime < duration
    }

    /// Classifies a nil-error KSPlayer finish. FFmpeg reports a dead/truncated
    /// stream ("File ended prematurely") as a plain end-of-file, which KSPlayer
    /// surfaces as `.playedToTheEnd` with no error. Treat the finish as a
    /// failure when genuine playback never got close to the container's
    /// declared runtime.
    static func isPrematureKSPlayerFinish(
        lastObservedPlaybackTime: TimeInterval,
        duration: TimeInterval,
        tolerance: TimeInterval = 30
    ) -> Bool {
        guard duration.isFinite, duration > tolerance else { return false }
        guard lastObservedPlaybackTime.isFinite, lastObservedPlaybackTime >= 0 else { return true }
        return lastObservedPlaybackTime + tolerance < duration
    }

    static func playbackMessageAfterObservedState(
        currentMessage: String?,
        observedPlaybackState: PlayerPlaybackState,
        hasPlayedOnce: Bool
    ) -> String? {
        if observedPlaybackState == .buffering, hasPlayedOnce {
            return nil
        }
        return currentMessage
    }

    static func immersiveControlModalFlags(
        includesImmersiveControls: Bool,
        isShowingEnvironmentPicker: Bool,
        isShowingCinemaSettings: Bool
    ) -> ControlModalImmersiveFlags {
        ControlModalImmersiveFlags(
            isShowingEnvironmentPicker: includesImmersiveControls && isShowingEnvironmentPicker,
            isShowingCinemaSettings: includesImmersiveControls && isShowingCinemaSettings
        )
    }

    static func autoHideDelayNanoseconds(delaySeconds: TimeInterval = PlayerControlVisibilityPolicy.autoHideDelay) -> UInt64 {
        UInt64(delaySeconds * 1_000_000_000)
    }

    static func shouldAutoHideControls(
        playbackState: PlayerPlaybackState,
        isPlaying: Bool,
        isScrubbing: Bool,
        isShowingSubtitlePicker: Bool,
        isShowingAudioPicker: Bool,
        isControlsLocked: Bool,
        isShowingEnvironmentPicker: Bool,
        isShowingCinemaSettings: Bool
    ) -> Bool {
        PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: playbackState,
            isPlaying: isPlaying,
            isScrubbing: isScrubbing,
            isShowingSubtitlePicker: isShowingSubtitlePicker,
            isShowingAudioPicker: isShowingAudioPicker,
            isControlsLocked: isControlsLocked,
            isShowingEnvironmentPicker: isShowingEnvironmentPicker,
            isShowingCinemaSettings: isShowingCinemaSettings
        )
    }

    static func shouldHydrateFallbackAudioTrack(existingAudioTrackCount: Int) -> Bool {
        existingAudioTrackCount <= 0
    }

    static func mediaTrackSnapshot(from track: any MediaPlayerTrack) -> MediaTrackSnapshot {
        MediaTrackSnapshot(
            trackID: Int(track.trackID),
            name: track.name,
            description: track.description,
            languageCode: track.languageCode,
            isEnabled: track.isEnabled
        )
    }

    static func fallbackKSAudioTrackInfo(for stream: StreamInfo) -> VPPlayerEngine.TrackInfo {
        VPPlayerEngine.TrackInfo(
            id: 0,
            name: "Auto (\(stream.audio.rawValue.uppercased()))",
            language: nil,
            codec: stream.codec.rawValue
        )
    }

    static func ksAudioTrackInfos(from snapshots: [MediaTrackSnapshot]) -> [VPPlayerEngine.TrackInfo] {
        snapshots.map { snapshot in
            VPPlayerEngine.TrackInfo(
                id: snapshot.trackID,
                name: ksTrackDisplayName(name: snapshot.name, description: snapshot.description),
                language: snapshot.languageCode,
                codec: nil
            )
        }
    }

    static func selectedKSTrackID(from snapshots: [MediaTrackSnapshot]) -> Int? {
        snapshots.first(where: \.isEnabled)?.trackID
    }

    static func ksSubtitleOptionFields(
        from snapshot: MediaTrackSnapshot,
        modelName: String?,
        index: Int
    ) -> KSSubtitleOptionFields {
        let id = String(snapshot.trackID)
        return KSSubtitleOptionFields(
            id: id,
            name: PlayerSubtitlePolicy.mediaTrackDisplayName(
                fallback: modelName,
                name: snapshot.name,
                description: snapshot.description,
                index: index,
                kind: "Subtitle"
            ),
            language: snapshot.languageCode
        )
    }

    static func shouldMarkSubtitlesEnabled(selectedKSSubtitleID: String?) -> Bool {
        selectedKSSubtitleID != nil
    }

    static func scheduledKSTrackRefreshDelaysMilliseconds() -> [Int] {
        [300, 1_200, 2_500]
    }

    static func shouldRunScheduledKSTrackRefresh(
        requestedStreamID: String,
        currentStreamID: String?,
        hasCurrentCoordinator: Bool
    ) -> Bool {
        hasCurrentCoordinator &&
        PlayerViewPolicy.audioTrackRefreshShouldRun(
            requestedStreamID: requestedStreamID,
            currentStreamID: currentStreamID
        )
    }

    static func autoplayNextPreflight(
        isCancelled: Bool,
        nextEpisode: PlayerSessionRequest.NextEpisodeCandidate?
    ) -> AutoPlayNextPreflight {
        guard !isCancelled, let nextEpisode else { return .finishUnavailable }
        return .proceed(nextEpisode)
    }

    static func autoplayNextLoadingMessage(for nextEpisode: PlayerSessionRequest.NextEpisodeCandidate) -> String {
        "Loading \(nextEpisode.title)..."
    }

    static func autoplayNextFailureMessage(
        for nextEpisode: PlayerSessionRequest.NextEpisodeCandidate,
        errorDescription: String
    ) -> String {
        "Could not auto-play \(nextEpisode.title). \(userVisibleErrorDescription(errorDescription))"
    }

    static func autoplayResolutionFinishOutcome(hasQueuedNextEpisode: Bool) -> PlayerAutoplayNextPolicy.ResolutionOutcome {
        hasQueuedNextEpisode ? .unavailable : .succeeded
    }

    static func currentTitle(mediaTitle: String?, streamFileName: String) -> String {
        let trimmedTitle = mediaTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let title = trimmedTitle, !title.isEmpty else {
            return streamFileName
        }
        return title
    }

    static func preparationStartMessage() -> String {
        "Starting stream..."
    }

    static func preparationAttemptMessage(for kind: PlayerEngineKind) -> String {
        "Trying \(kind.displayName)..."
    }

    static func preparationResumeMessage(for seconds: TimeInterval) -> String {
        "Resuming from \(seconds.formattedDuration)..."
    }

    static func preparationSuccessMessage(for kind: PlayerEngineKind, didResume: Bool) -> String {
        let action = didResume ? "Resumed" : "Playing"
        return "\(action) with \(kind.displayName)."
    }

    static func playbackStartRate(_ playbackRate: Float) -> Float {
        guard playbackRate.isFinite else { return 0.1 }
        return max(0.1, playbackRate)
    }

    static func avPlayerStartupAction(
        automaticallyWaitsToMinimizeStalling: Bool
    ) -> AVPlayerStartupAction {
        automaticallyWaitsToMinimizeStalling ? .playAfterMinimizingStalls : .playImmediately
    }

    static func preparationFailureLine(kind: PlayerEngineKind, errorDescription: String) -> String {
        "\(kind.displayName): \(userVisibleErrorDescription(errorDescription))"
    }

    static func preparationFailureReason(failures: [String]) -> String {
        failures.isEmpty ? "No compatible player engine was available." : failures.joined(separator: "\n")
    }

    static func userVisibleErrorDescription(_ errorDescription: String) -> String {
        var sanitized = errorDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return "Playback failed." }

        let replacements: [(pattern: String, replacement: String)] = [
            (#"(https?|ftp|file)://[^\s<>"']+"#, "[redacted URL]"),
            (#"\b(bearer)\s+[A-Za-z0-9._~+/=-]{8,}"#, "$1 [redacted]"),
            (#"\b(access_token|refresh_token|client_secret|token|apikey|api_key|signature|sig|auth)=([^&\s]+)"#, "$1=[redacted]"),
        ]
        for replacement in replacements {
            sanitized = sanitized.replacingOccurrences(
                of: replacement.pattern,
                with: replacement.replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return sanitized
    }

    static func autoSubtitlePreflight(
        requestedStreamID: String,
        currentStreamID: String?,
        autoSearchEnabled: Bool,
        rawAPIKey: String?,
        configuredLanguageSetting: String?,
        systemPreferredLanguages: [String],
        closedCaptioningEnabled: Bool,
        streamFileName: String
    ) -> AutoSubtitlePreflight {
        guard requestedStreamID == currentStreamID, autoSearchEnabled else { return .skip }
        guard let request = subtitleLookupRequest(
            rawAPIKey: rawAPIKey,
            configuredLanguageSetting: configuredLanguageSetting,
            systemPreferredLanguages: systemPreferredLanguages,
            closedCaptioningEnabled: closedCaptioningEnabled,
            streamFileName: streamFileName
        ) else {
            return .skip
        }
        return .download(request)
    }

    static func subtitleCatalogPreflight(
        rawAPIKey: String?,
        configuredLanguageSetting: String?,
        systemPreferredLanguages: [String],
        closedCaptioningEnabled: Bool,
        streamFileName: String
    ) -> SubtitleCatalogPreflight {
        guard let apiKey = PlayerSubtitleServicePolicy.normalizedAPIKey(rawAPIKey) else {
            return .missingAPIKey(message: PlayerSubtitleServicePolicy.missingCatalogAPIKeyMessage)
        }

        let languages = PlayerSubtitlePolicy.automaticSubtitleLanguageCodes(
            configuredLanguageSetting: configuredLanguageSetting,
            systemPreferredLanguages: systemPreferredLanguages,
            closedCaptioningEnabled: closedCaptioningEnabled
        )
        let query = PlayerSubtitlePolicy.subtitleSearchQuery(from: streamFileName)
        guard !query.isEmpty else {
            return .emptyQuery(message: PlayerSubtitleServicePolicy.emptyCatalogQueryMessage)
        }

        return .search(SubtitleLookupRequest(apiKey: apiKey, languages: languages, query: query))
    }

    static func subtitleDownloadPreflight(
        requestedStreamID: String,
        currentStreamID: String?,
        subtitle: Subtitle,
        rawAPIKey: String?
    ) -> SubtitleDownloadPreflight {
        guard requestedStreamID == currentStreamID else { return .skip }
        guard let fileID = subtitle.fileId else { return .skip }
        guard subtitle.isSupportedSubtitle else {
            return .unsupported(message: PlayerSubtitleServicePolicy.unsupportedSubtitleMessage)
        }
        guard let apiKey = PlayerSubtitleServicePolicy.normalizedAPIKey(rawAPIKey) else {
            return .missingAPIKey(message: PlayerSubtitleServicePolicy.missingDownloadAPIKeyMessage)
        }
        return .download(apiKey: apiKey, fileID: fileID)
    }

    private static func ksTrackDisplayName(name: String, description: String) -> String {
        name.isEmpty ? description : name
    }

    private static func subtitleLookupRequest(
        rawAPIKey: String?,
        configuredLanguageSetting: String?,
        systemPreferredLanguages: [String],
        closedCaptioningEnabled: Bool,
        streamFileName: String
    ) -> SubtitleLookupRequest? {
        guard let apiKey = PlayerSubtitleServicePolicy.normalizedAPIKey(rawAPIKey) else { return nil }
        let languages = PlayerSubtitlePolicy.automaticSubtitleLanguageCodes(
            configuredLanguageSetting: configuredLanguageSetting,
            systemPreferredLanguages: systemPreferredLanguages,
            closedCaptioningEnabled: closedCaptioningEnabled
        )
        let query = PlayerSubtitlePolicy.subtitleSearchQuery(from: streamFileName)
        guard !query.isEmpty else { return nil }
        return SubtitleLookupRequest(apiKey: apiKey, languages: languages, query: query)
    }
}
