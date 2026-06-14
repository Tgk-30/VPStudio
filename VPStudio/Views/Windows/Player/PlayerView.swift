import Foundation
import SwiftUI
@preconcurrency import AVKit
import MediaAccessibility
@preconcurrency import KSPlayer
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum PlayerTransportControlsPolicy {
    enum EnvironmentControlPlacement {
        case leftNavigation
        case rightTransportControls
    }

    static func showsRightTransportEnvironmentControl(
        placement: EnvironmentControlPlacement = .leftNavigation
    ) -> Bool {
        placement == .rightTransportControls
    }
}

enum PlayerLifecyclePolicy {
    static var closesDedicatedPlayerWindowOnBack: Bool {
        #if os(macOS) || os(visionOS)
        true
        #else
        false
        #endif
    }

    static var dismissesCurrentPresentationOnBack: Bool {
        true
    }
}

enum PlayerImmersiveControlEvent: Equatable {
    case toggleControls
    case togglePlayPause
    case seekBack
    case seekForward
    case seekToPercent(Double)
    case previousChapter
    case nextChapter
    case cycleRate
    case toggleSubtitles
    case toggleAudio
    case requestEnvironmentSwitch
    case dismiss
}

struct PlayerAutoplayRuntimeSnapshot: Equatable {
    var didRequestAutoplayNext: Bool
    var didCancelAutoPlayNextPrompt: Bool
    var isShowingAutoPlayNextPrompt: Bool
    var isResolvingAutoPlayNextEpisode: Bool
    var countdownRemaining: Int
}

enum PlayerAutoplayRuntimeEvent: Equatable {
    case playNowRequested
    case cancelRequested
    case progressObserved(currentTime: TimeInterval, duration: TimeInterval)
    case stateChanged(PlayerAutoplayRuntimeSnapshot)
}

enum PlayerAutoplayControlNotificationKey {
    static let currentTime = "currentTime"
    static let duration = "duration"
}

struct PlayerViewAVTimeObserverHooks {
    let addPeriodicTimeObserver: @MainActor (
        _ player: AVPlayer,
        _ interval: CMTime,
        _ callback: @escaping (CMTime) -> Void
    ) -> Any
    let removeTimeObserver: @MainActor (_ player: AVPlayer, _ token: Any) -> Void
}

struct PlayerSubtitleRuntimeSnapshot: Equatable {
    var candidateCount: Int
    var catalogMessage: String?
    var isRefreshingSubtitleCatalog: Bool
    var isDownloadingSubtitle: Bool
    var selectedSubtitleTrack: Int
    var subtitlesEnabled: Bool
}

enum PlayerSubtitleRuntimeEvent: Equatable {
    case refreshRequested
    case downloadRequested(fileID: Int?)
    case stateChanged(PlayerSubtitleRuntimeSnapshot)
}

struct PlayerSubtitleRuntimeSettings {
    let usesOpenSubtitlesAPIKeyOverride: Bool
    let openSubtitlesAPIKey: String?
    let subtitleLanguage: String?
    let subtitleAutoSearch: Bool?

    init(
        openSubtitlesAPIKey: String?,
        subtitleLanguage: String? = nil,
        subtitleAutoSearch: Bool? = nil
    ) {
        self.usesOpenSubtitlesAPIKeyOverride = true
        self.openSubtitlesAPIKey = openSubtitlesAPIKey
        self.subtitleLanguage = subtitleLanguage
        self.subtitleAutoSearch = subtitleAutoSearch
    }
}

enum PlayerViewPolicy {
    static let avPlayerPeriodicObserverIntervalSeconds: TimeInterval = 0.25

    static func playbackStateTitle(for state: PlayerPlaybackState) -> String {
        switch state {
        case .preparing:
            return "Preparing Playback"
        case .buffering:
            return "Buffering"
        case .playing:
            return "Playing"
        case .failed:
            return "Playback Failed"
        }
    }

    static func audioTrackRefreshShouldRun(requestedStreamID: String, currentStreamID: String?) -> Bool {
        currentStreamID == requestedStreamID
    }

    static func preparePlaybackShouldRun(requestedPreparationID: UUID, activePreparationID: UUID?) -> Bool {
        activePreparationID == requestedPreparationID
    }

    static func clampedSeekTarget(currentTime: TimeInterval, offset: TimeInterval, duration: TimeInterval) -> TimeInterval {
        clampedSeekTarget(time: currentTime + offset, duration: duration)
    }

    static func clampedSeekTarget(percent: Double, duration: TimeInterval) -> TimeInterval {
        guard percent.isFinite, duration.isFinite, duration >= 0 else { return 0 }
        let clamped = max(0, min(1, percent))
        return duration * clamped
    }

    static func clampedSeekTarget(time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard time.isFinite, duration.isFinite, duration >= 0 else { return 0 }
        return max(0, min(duration, time))
    }

    static func scrubberAccessibilityValue(
        currentTime: TimeInterval,
        duration: TimeInterval,
        isScrubbing: Bool,
        scrubTime: TimeInterval
    ) -> String {
        let current = isScrubbing ? scrubTime : currentTime
        let safeCurrent = current.isFinite ? current : (currentTime.isFinite ? currentTime : 0)
        guard duration.isFinite, duration > 0 else { return safeCurrent.formattedDuration }
        return "\(safeCurrent.formattedDuration) of \(duration.formattedDuration)"
    }

    static func scrobbleProgressPercent(currentTime: TimeInterval, duration: TimeInterval) -> Double {
        guard currentTime.isFinite, duration.isFinite, duration > 0 else { return 0 }
        let percent = (currentTime / duration) * 100
        return max(0, min(100, percent))
    }

    static func subtitleTextRefreshShouldRun(
        selectedSubtitleTrack: Int,
        currentSubtitleText: String?
    ) -> Bool {
        selectedSubtitleTrack >= 0 || currentSubtitleText != nil
    }

    static func bufferedPercent(
        loadedRangeStart: TimeInterval,
        loadedRangeDuration: TimeInterval,
        itemDuration: TimeInterval
    ) -> Double? {
        guard loadedRangeStart.isFinite,
              loadedRangeDuration.isFinite,
              itemDuration.isFinite,
              itemDuration > 0 else {
            return nil
        }
        let bufferedEnd = loadedRangeStart + loadedRangeDuration
        guard bufferedEnd.isFinite else { return nil }
        return max(0, min(1, bufferedEnd / itemDuration))
    }

    static func resolvedSubtitleFontSize(storedSize: Double?) -> Double {
        guard let storedSize, storedSize.isFinite else { return 24 }
        return max(16, min(48, storedSize))
    }

    static func progressBarDisplayTime(
        currentTime: TimeInterval,
        isScrubbing: Bool,
        scrubTime: TimeInterval
    ) -> TimeInterval {
        isScrubbing ? scrubTime : currentTime
    }

    static func progressBarDisplayPercent(
        displayTime: TimeInterval,
        duration: TimeInterval
    ) -> Double {
        guard displayTime.isFinite, duration.isFinite else { return 0 }
        guard duration > 0 else { return 1 }
        return max(0, min(1, displayTime / duration))
    }

    static func progressBarBufferedPercent(_ bufferedPercent: Double) -> Double {
        max(0, min(1, bufferedPercent))
    }

    static func progressBarHeight(isScrubbing: Bool) -> CGFloat {
        isScrubbing
            ? PlayerCinematicChromePolicy.progressBarScrubbingHeight
            : PlayerCinematicChromePolicy.progressBarIdleHeight
    }

    static func scrubberDragPercent(locationX: CGFloat, barWidth: CGFloat) -> Double {
        guard locationX.isFinite, barWidth.isFinite, barWidth > 0 else { return 0 }
        return max(0, min(1, locationX / barWidth))
    }

    static func scrubPreviewLabelX(
        progressX: CGFloat,
        barWidth: CGFloat,
        horizontalInset: CGFloat = 30
    ) -> CGFloat {
        guard progressX.isFinite, barWidth.isFinite else { return 0 }
        guard barWidth > 0 else { return 0 }
        let inset = max(0, min(horizontalInset, barWidth / 2))
        return max(inset, min(barWidth - inset, progressX))
    }

    static func shouldShowChapterMarker(chapterStartTime: TimeInterval) -> Bool {
        chapterStartTime > 0
    }

    static func shouldShowWarningsOverlay(
        capabilityWarnings: [String],
        playbackError: String?,
        playbackState: PlayerPlaybackState
    ) -> Bool {
        !capabilityWarnings.isEmpty || warningOverlayPlaybackError(
            playbackError: playbackError,
            playbackState: playbackState
        ) != nil
    }

    static func warningOverlayPlaybackError(
        playbackError: String?,
        playbackState: PlayerPlaybackState
    ) -> String? {
        guard playbackState == .failed else { return nil }
        return playbackError
    }

    static func emptyAudioTracksMessage(activeEngine: PlayerEngineKind?) -> String {
        activeEngine == .avPlayer
            ? "No alternate in-stream audio tracks detected. The stream may have only one audio track."
            : "No alternate audio tracks detected for this stream."
    }

    static func subtitleTrackLanguageLabel(_ language: String?) -> String? {
        guard let language, !language.isEmpty else { return nil }
        return language.uppercased()
    }

    static func isControlModalPresented(
        isShowingSubtitlePicker: Bool,
        isShowingAudioPicker: Bool,
        isShowingEnvironmentPicker: Bool,
        isShowingCinemaSettings: Bool
    ) -> Bool {
        isShowingSubtitlePicker ||
        isShowingAudioPicker ||
        isShowingEnvironmentPicker ||
        isShowingCinemaSettings
    }
}

enum PlayerTrackPresentationPolicy {
    static func availableAudioTrackCount(avMediaOptionCount: Int, engineTrackCount: Int) -> Int {
        max(avMediaOptionCount, engineTrackCount)
    }

    static func isSubtitlePresentationActive(subtitlesEnabled: Bool) -> Bool {
        subtitlesEnabled
    }

    static func isSubtitleSelectionOff(subtitlesEnabled: Bool) -> Bool {
        !subtitlesEnabled
    }

    static func canRefreshTrackList(hasAVPlayer: Bool, hasKSPlayerCoordinator: Bool) -> Bool {
        hasAVPlayer || hasKSPlayerCoordinator
    }

    static func isDirectTrackSelected(selectedID: String?, trackID: String) -> Bool {
        selectedID == trackID
    }

    static func isEngineTrackSelected(selectedTrackID: Int, trackID: Int) -> Bool {
        selectedTrackID == trackID
    }

    static func isExternalSubtitleSelected(
        selectedAVSubtitleID: String?,
        selectedEngineSubtitleTrack: Int,
        trackID: Int
    ) -> Bool {
        selectedAVSubtitleID == nil && selectedEngineSubtitleTrack == trackID
    }
}

enum PlayerSubtitleSelectionPolicy {
    static func resolvedKSSubtitleID(
        selectedSubtitleInfoID: String?,
        enabledTrackID: String?,
        optionIDs: [String]
    ) -> String? {
        if let selectedSubtitleInfoID,
           optionIDs.contains(selectedSubtitleInfoID) {
            return selectedSubtitleInfoID
        }

        if let enabledTrackID,
           optionIDs.contains(enabledTrackID) {
            return enabledTrackID
        }

        return nil
    }
}

enum PlayerSubtitleServicePolicy {
    static let missingCatalogAPIKeyMessage = "Set an OpenSubtitles API key in Settings to browse subtitle options."
    static let emptyCatalogQueryMessage = "Could not build subtitle query for this stream."
    static let noCatalogMatchesMessage = "No subtitle matches found."
    static let missingDownloadAPIKeyMessage = "OpenSubtitles API key is required."
    static let unsupportedSubtitleMessage = "That subtitle format is not supported for rendering."

    static func normalizedAPIKey(_ rawValue: String?) -> String? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func imdbSearchID(from mediaID: String?) -> String? {
        mediaID?.hasPrefix("tt") == true ? mediaID : nil
    }

    static func supportedCatalogCandidates(_ candidates: [Subtitle], limit: Int = 30) -> [Subtitle] {
        Array(
            candidates
                .filter { $0.fileId != nil && $0.isSupportedSubtitle }
                .prefix(limit)
        )
    }

    static func catalogResultMessage(candidateCount: Int) -> String? {
        candidateCount == 0 ? noCatalogMatchesMessage : nil
    }

    static func automaticDownloadFailureMessage(errorDescription: String) -> String {
        "Automatic subtitle download failed. Open subtitles to retry. \(errorDescription)"
    }
}

enum PlayerMediaOptionIDPolicy {
    static func id(
        localeIdentifier: String?,
        extendedLanguageTag: String?,
        displayName: String,
        index: Int
    ) -> String {
        let language = localeIdentifier ?? extendedLanguageTag ?? "und"
        return "\(language)-\(displayName)-\(index)"
    }
}

enum PlayerAVMediaSelectionPolicy {
    struct Candidate: Equatable {
        let id: String
        let localeIdentifier: String?
        let extendedLanguageTag: String?
    }

    struct SelectionPlan: Equatable {
        let selectedID: String?
        let autoSelectIndex: Int?

        static let none = SelectionPlan(selectedID: nil, autoSelectIndex: nil)
    }

    static func selectionPlan(
        currentSelectedIndex: Int?,
        candidates: [Candidate],
        preferredLanguages: [String],
        allowsPreferredAutoSelection: Bool
    ) -> SelectionPlan {
        if let currentSelectedIndex,
           candidates.indices.contains(currentSelectedIndex) {
            return SelectionPlan(
                selectedID: candidates[currentSelectedIndex].id,
                autoSelectIndex: nil
            )
        }

        guard allowsPreferredAutoSelection,
              let preferredIndex = candidates.firstIndex(where: {
                  PlayerSubtitlePolicy.matchesPreferredLanguage(
                      localeIdentifier: $0.localeIdentifier,
                      extendedLanguageTag: $0.extendedLanguageTag,
                      preferredLanguages: preferredLanguages
                  )
              }) else {
            return .none
        }

        return SelectionPlan(
            selectedID: candidates[preferredIndex].id,
            autoSelectIndex: preferredIndex
        )
    }
}

enum PlayerAutoplayNextPolicy {
    static let countdownDurationSeconds = 10

    struct PromptState: Equatable {
        var hasNextEpisode: Bool
        var didRequestAutoplayNext: Bool
        var didCancelAutoPlayNextPrompt: Bool
        var isShowingAutoPlayNextPrompt: Bool
        var isResolvingAutoPlayNextEpisode: Bool
        var countdownRemaining: Int

        static func idle(hasNextEpisode: Bool) -> PromptState {
            PromptState(
                hasNextEpisode: hasNextEpisode,
                didRequestAutoplayNext: false,
                didCancelAutoPlayNextPrompt: false,
                isShowingAutoPlayNextPrompt: false,
                isResolvingAutoPlayNextEpisode: false,
                countdownRemaining: PlayerAutoplayNextPolicy.countdownDurationSeconds
            )
        }
    }

    enum ResolutionOutcome {
        case succeeded
        case unavailable
        case failed
    }

    static var countdownTriggerRemainingTime: TimeInterval {
        TimeInterval(countdownDurationSeconds)
    }

    static func shouldStartCountdown(
        currentTime: TimeInterval,
        duration: TimeInterval,
        hasNextEpisode: Bool,
        hasStartedCountdown: Bool,
        wasCancelled: Bool,
        isResolving: Bool
    ) -> Bool {
        guard hasNextEpisode, !hasStartedCountdown, !wasCancelled, !isResolving else { return false }
        guard currentTime.isFinite, duration.isFinite, currentTime >= 0, duration > 0 else { return false }
        return duration - currentTime <= countdownTriggerRemainingTime
    }

    static func countdownProgress(
        remainingSeconds: Int,
        durationSeconds: Int = countdownDurationSeconds
    ) -> Double {
        guard durationSeconds > 0 else { return 0 }
        let clampedRemaining = max(0, min(durationSeconds, remainingSeconds))
        return Double(clampedRemaining) / Double(durationSeconds)
    }

    static func shouldScheduleCountdown(state: PromptState) -> Bool {
        state.hasNextEpisode &&
        !state.didRequestAutoplayNext &&
        !state.didCancelAutoPlayNextPrompt
    }

    static func stateAfterSchedulingCountdown(from state: PromptState) -> PromptState {
        guard shouldScheduleCountdown(state: state) else { return state }
        var next = state
        next.didRequestAutoplayNext = true
        return next
    }

    static func stateAfterPresentingCountdown(from state: PromptState) -> PromptState {
        var next = state
        next.isShowingAutoPlayNextPrompt = true
        next.countdownRemaining = countdownDurationSeconds
        return next
    }

    static func stateAfterCountdownUnavailable(from state: PromptState) -> PromptState {
        var next = state
        next.isShowingAutoPlayNextPrompt = false
        next.isResolvingAutoPlayNextEpisode = false
        next.countdownRemaining = countdownDurationSeconds
        if !state.hasNextEpisode {
            next.didRequestAutoplayNext = false
            next.didCancelAutoPlayNextPrompt = false
        }
        return next
    }

    static func stateAfterPlayNow(from state: PromptState) -> PromptState {
        guard state.hasNextEpisode, !state.isResolvingAutoPlayNextEpisode else { return state }
        var next = state
        next.didRequestAutoplayNext = true
        next.countdownRemaining = 0
        return next
    }

    static func stateAfterCancellingCountdown(from state: PromptState) -> PromptState {
        var next = state
        next.didCancelAutoPlayNextPrompt = true
        next.didRequestAutoplayNext = true
        next.isShowingAutoPlayNextPrompt = false
        next.countdownRemaining = countdownDurationSeconds
        return next
    }

    static func stateAfterStartingResolution(from state: PromptState) -> PromptState {
        guard state.hasNextEpisode, !state.isResolvingAutoPlayNextEpisode else { return state }
        var next = state
        next.isResolvingAutoPlayNextEpisode = true
        next.isShowingAutoPlayNextPrompt = true
        return next
    }

    static func stateAfterFinishingResolution(from state: PromptState, outcome: ResolutionOutcome) -> PromptState {
        var next = state
        next.isResolvingAutoPlayNextEpisode = false
        next.isShowingAutoPlayNextPrompt = false

        switch outcome {
        case .succeeded:
            next.hasNextEpisode = false
            next.didRequestAutoplayNext = false
            next.didCancelAutoPlayNextPrompt = false
            next.countdownRemaining = countdownDurationSeconds
        case .unavailable, .failed:
            break
        }

        return next
    }

    static func stateAfterStreamTransition(hasNextEpisode: Bool) -> PromptState {
        .idle(hasNextEpisode: hasNextEpisode)
    }
}

enum PlayerAutoplayNextResolutionPolicy {
    enum ResolutionPlan: Equatable {
        case disabled
        case unavailable
        case readyFromSeriesPage(message: String)
        case resolve(StreamRecoveryContext)
    }

    static let readyFromSeriesPageMessage = "Next episode is ready from the series page."

    static func resolutionPlan(
        autoPlayNextEnabled: Bool,
        nextEpisode: PlayerSessionRequest.NextEpisodeCandidate?,
        currentRecoveryContext: StreamRecoveryContext?
    ) -> ResolutionPlan {
        guard autoPlayNextEnabled else { return .disabled }
        guard let nextEpisode else { return .unavailable }
        guard let currentRecoveryContext else {
            return .readyFromSeriesPage(message: readyFromSeriesPageMessage)
        }

        guard let nextContext = StreamRecoveryContext(
            infoHash: currentRecoveryContext.infoHash,
            preferredService: currentRecoveryContext.preferredService,
            magnetURI: currentRecoveryContext.magnetURI,
            seasonNumber: nextEpisode.seasonNumber,
            episodeNumber: nextEpisode.episodeNumber
        ) else {
            return .readyFromSeriesPage(message: readyFromSeriesPageMessage)
        }

        return .resolve(nextContext)
    }
}

enum PlayerStreamRefreshPolicy {
    static func queueWithRefreshedPrimary(
        refreshedStream: StreamInfo,
        staleStream: StreamInfo,
        streamQueue: [StreamInfo]
    ) -> [StreamInfo] {
        let refreshedAvailable = streamQueue.map { queuedStream in
            queuedStream.id == staleStream.id ? refreshedStream : queuedStream
        }

        return PlayerSessionRouting.sessionStreams(
            primary: refreshedStream,
            available: refreshedAvailable.filter { $0.id != refreshedStream.id }
        )
    }
}

struct PlayerView: View {
    let stream: StreamInfo
    let availableStreams: [StreamInfo]
    let mediaTitle: String?
    let mediaId: String?
    let tmdbId: Int?
    let episodeId: String?
    let nextEpisode: PlayerSessionRequest.NextEpisodeCandidate?
    let sessionID: UUID?
    let sessionRequest: PlayerSessionRequest?

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    #if os(macOS) || os(visionOS)
    @Environment(\.dismissWindow) private var dismissWindow
    #endif
    #if os(visionOS)
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    /// Obsidian Glass chrome. Branches ONLY visual modifiers (background/stroke/foreground/shadow)
    /// of the player chrome — never the playback, gesture, or lifecycle code.
    @AppStorage(VPDesignFlags.useObsidianGlassKey) private var useObsidianGlass = true

    @State private var currentStream: StreamInfo
    @State private var streamQueue: [StreamInfo]
    @State private var activeMediaTitle: String?
    @State private var activeEpisodeId: String?
    @State private var queuedNextEpisode: PlayerSessionRequest.NextEpisodeCandidate?

    @State private var playbackState: PlayerPlaybackState = .preparing
    @State private var playbackMessage: String?
    @State private var playbackError: String?
    @State private var activeEngine: PlayerEngineKind?

    /// Most recent captured last-frame thumbnail path (for the Continue Watching tile) and
    /// when it was captured. Captured periodically while the engine is alive so there is never
    /// a teardown race at close time.
    @State private var lastFrameImagePath: String?
    @State private var lastFrameCaptureAt: Date?
    /// One-shot guard so the ≥90% "watched" snapshot is persisted exactly once per stream, the
    /// moment progress crosses the completion threshold (covers abrupt closes between periodic saves).
    @State private var didPersistCompletion = false

    @State private var avPlayer: AVPlayer?
    @State private var ksPlayerCoordinator: KSVideoPlayer.Coordinator?
    @State private var ksOptions: KSOptions?

    @Environment(VPPlayerEngine.self) private var engine
    #if os(visionOS)
    @Environment(CinemaSettings.self) private var cinemaSettings
    #endif
    @State private var isShowingControls = true
    @State private var isControlsLocked = false
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var initialPlayerStateTask: Task<Void, Never>?
    @State private var preparePlaybackTask: Task<Void, Never>?
    @State private var activePreparePlaybackID: UUID?
    @State private var subtitleCatalogTask: Task<Void, Never>?
    @State private var subtitleDownloadTask: Task<Void, Never>?
    @State private var environmentAssetsTask: Task<Void, Never>?
    @State private var scenePhaseTask: Task<Void, Never>?
    @State private var memoryPressureTask: Task<Void, Never>?
    @State private var avMediaOptionRefreshTask: Task<Void, Never>?
    @State private var audioTrackRefreshTask: Task<Void, Never>?
    @State private var subtitleTrackRefreshTask: Task<Void, Never>?
    @State private var videoRatioDetectionTask: Task<Void, Never>?
    @State private var hdrMetadataExtractionTask: Task<Void, Never>?
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0
    @State private var hasPlayedOnce = false
    @State private var isShowingSubtitlePicker = false
    @State private var isShowingAudioPicker = false
    #if os(visionOS)
    @State private var isShowingEnvironmentPicker = false
    @State private var isShowingCinemaSettings = false
    #endif
    @State private var timeObserverToken: Any?
    @State private var timeObserverPlayer: AVPlayer?
    @State private var subtitleFontSize: Double = 24
    @State private var downloadedSubtitleFileURL: URL?
    @State private var capabilityWarnings: [String] = []
    @State private var environmentAssets: [EnvironmentAsset] = []
    @State private var progressPersistTask: Task<Void, Never>?
    @State private var scrobbleTask: Task<Void, Never>?
    @State private var subtitleService: (any OpenSubtitlesServicing)?
    @State private var subtitleServiceAPIKey: String?
    @State private var subtitleCandidates: [Subtitle] = []
    @State private var subtitleCatalogMessage: String?
    @State private var isRefreshingSubtitleCatalog = false
    @State private var isDownloadingSubtitle = false
    @State private var subtitleCatalogMutationID: UUID?
    @State private var subtitleDownloadMutationID: UUID?
    @State private var didInitiateClose = false
    @State private var avAudioOptions: [AVTrackOption] = []
    @State private var avSubtitleOptions: [AVTrackOption] = []
    @State private var ksSubtitleOptions: [KSSubtitleOption] = []
    @State private var avAudioGroup: AVMediaSelectionGroup?
    @State private var avSubtitleGroup: AVMediaSelectionGroup?
    @State private var selectedAVAudioID: String?
    @State private var selectedAVSubtitleID: String?
    @State private var selectedKSSubtitleID: String?
    @State private var subtitleSelectionMode: SubtitleSelectionMode = .automaticPreferred
    @State private var startupRefreshAttempts: [String: Int] = [:]
    @State private var didRequestAutoplayNext = false
    @State private var didCancelAutoPlayNextPrompt = false
    @State private var isShowingAutoPlayNextPrompt = false
    @State private var isResolvingAutoPlayNextEpisode = false
    @State private var autoPlayNextCountdownRemaining = PlayerAutoplayNextPolicy.countdownDurationSeconds
    @State private var autoPlayNextCountdownTask: Task<Void, Never>?
    @State private var autoPlayNextResolveTask: Task<Void, Never>?

    #if os(visionOS)
    @State private var apmpInjector = APMPInjector()
    @State private var isAPMPActive = false
    @State private var playerWindowScene: UIWindowScene?
    @State private var visionGeometryTask: Task<Void, Never>?
    @State private var environmentMenuActionTask: Task<Void, Never>?
    @State private var immersiveDismissTask: Task<Void, Never>?
    #endif

    // MARK: - Aspect Ratio
    @State private var aspectRatioSelection: AspectRatioSelection = .auto
    @State private var detectedVideoRatio: CGFloat?
    @State private var didAttemptVideoRatioDetection = false
    @State private var didAttemptHDRMetadataExtraction = false

    #if os(macOS)
    @State private var playerWindow: NSWindow?
    @State private var isFullscreen = false
    @State private var didApplyStoredFullscreen = false
    #endif

    private let avPlayerEngine = AVPlayerEngine()
    private let ksPlayerEngine = KSPlayerEngine()
    private let playerEngineSelector = PlayerEngineSelector()
    private let disablesAutomaticTasks: Bool
    private let onImmersiveControlEvent: (@MainActor (PlayerImmersiveControlEvent) -> Void)?
    private let onAutoplayRuntimeEvent: (@MainActor (PlayerAutoplayRuntimeEvent) -> Void)?
    private let onSubtitleRuntimeEvent: (@MainActor (PlayerSubtitleRuntimeEvent) -> Void)?
    private let subtitleRuntimeSettings: PlayerSubtitleRuntimeSettings?
    private let subtitleServiceFactory: (String) -> any OpenSubtitlesServicing
    private let prepareAVPlayerSessionOverride: (@MainActor (StreamInfo) async throws -> PreparedPlaybackSession)?
    private let waitUntilAVPlayerReadyOverride: (@MainActor (
        _ player: AVPlayer,
        _ onState: @escaping (PlayerPlaybackState, String?) -> Void
    ) async throws -> Void)?
    private let avTimeObserverHooks: PlayerViewAVTimeObserverHooks?

    private struct AVTrackOption: Identifiable {
        let id: String
        let name: String
        let language: String?
        let option: AVMediaSelectionOption
    }

    private struct KSSubtitleOption: Identifiable {
        let id: String
        let name: String
        let language: String?
    }

    private enum SubtitleSelectionMode: Equatable {
        case automaticPreferred
        case manual
    }

    private var availableAudioTrackCount: Int {
        PlayerTrackPresentationPolicy.availableAudioTrackCount(
            avMediaOptionCount: avAudioOptions.count,
            engineTrackCount: engine.audioTracks.count
        )
    }

    private var subtitlePresentationIsActive: Bool {
        PlayerTrackPresentationPolicy.isSubtitlePresentationActive(
            subtitlesEnabled: engine.subtitlesEnabled
        )
    }

    private var motionAnimationsEnabled: Bool {
        Self.shouldAnimateForAccessibility(reduceMotion: accessibilityReduceMotion)
    }

    init(
        stream: StreamInfo,
        availableStreams: [StreamInfo] = [],
        mediaTitle: String? = nil,
        mediaId: String? = nil,
        tmdbId: Int? = nil,
        episodeId: String? = nil,
        nextEpisode: PlayerSessionRequest.NextEpisodeCandidate? = nil,
        sessionID: UUID? = nil,
        sessionRequest: PlayerSessionRequest? = nil,
        initialPlaybackState: PlayerPlaybackState = .preparing,
        initialPlaybackMessage: String? = nil,
        initialPlaybackError: String? = nil,
        initialActiveEngine: PlayerEngineKind? = nil,
        initialIsShowingControls: Bool = true,
        initialIsShowingSubtitlePicker: Bool = false,
        initialIsShowingAudioPicker: Bool = false,
        initialIsShowingEnvironmentPicker: Bool = false,
        initialIsShowingCinemaSettings: Bool = false,
        initialSubtitleFontSize: Double = 24,
        initialCapabilityWarnings: [String] = [],
        initialEnvironmentAssets: [EnvironmentAsset] = [],
        initialSubtitleCandidates: [Subtitle] = [],
        initialSubtitleCatalogMessage: String? = nil,
        initialIsRefreshingSubtitleCatalog: Bool = false,
        initialIsDownloadingSubtitle: Bool = false,
        initialIsShowingAutoPlayNextPrompt: Bool = false,
        initialIsResolvingAutoPlayNextEpisode: Bool = false,
        initialAutoPlayNextCountdownRemaining: Int = PlayerAutoplayNextPolicy.countdownDurationSeconds,
        initialAspectRatioSelection: AspectRatioSelection = .auto,
        initialKSSubtitleOptions: [VPPlayerEngine.TrackInfo] = [],
        initialSelectedKSSubtitleID: String? = nil,
        disablesAutomaticTasks: Bool = false,
        onImmersiveControlEvent: (@MainActor (PlayerImmersiveControlEvent) -> Void)? = nil,
        onAutoplayRuntimeEvent: (@MainActor (PlayerAutoplayRuntimeEvent) -> Void)? = nil,
        onSubtitleRuntimeEvent: (@MainActor (PlayerSubtitleRuntimeEvent) -> Void)? = nil,
        subtitleRuntimeSettings: PlayerSubtitleRuntimeSettings? = nil,
        prepareAVPlayerSessionOverride: (@MainActor (StreamInfo) async throws -> PreparedPlaybackSession)? = nil,
        waitUntilAVPlayerReadyOverride: (@MainActor (
            _ player: AVPlayer,
            _ onState: @escaping (PlayerPlaybackState, String?) -> Void
        ) async throws -> Void)? = nil,
        avTimeObserverHooks: PlayerViewAVTimeObserverHooks? = nil,
        subtitleServiceFactory: @escaping (String) -> any OpenSubtitlesServicing = { OpenSubtitlesService(apiKey: $0) }
    ) {
        self.stream = stream
        self.availableStreams = availableStreams
        self.mediaTitle = mediaTitle
        self.mediaId = mediaId
        self.tmdbId = tmdbId
        self.episodeId = episodeId
        self.nextEpisode = nextEpisode
        self.sessionID = sessionID
        self.sessionRequest = sessionRequest
        self.disablesAutomaticTasks = disablesAutomaticTasks
        self.onImmersiveControlEvent = onImmersiveControlEvent
        self.onAutoplayRuntimeEvent = onAutoplayRuntimeEvent
        self.onSubtitleRuntimeEvent = onSubtitleRuntimeEvent
        self.subtitleRuntimeSettings = subtitleRuntimeSettings
        self.subtitleServiceFactory = subtitleServiceFactory
        self.prepareAVPlayerSessionOverride = prepareAVPlayerSessionOverride
        self.waitUntilAVPlayerReadyOverride = waitUntilAVPlayerReadyOverride
        self.avTimeObserverHooks = avTimeObserverHooks

        let queue = PlayerSessionRouting.sessionStreams(primary: stream, available: availableStreams)
        _currentStream = State(initialValue: stream)
        _streamQueue = State(initialValue: queue)
        _activeMediaTitle = State(initialValue: mediaTitle)
        _activeEpisodeId = State(initialValue: episodeId)
        _queuedNextEpisode = State(initialValue: nextEpisode)
        _playbackState = State(initialValue: initialPlaybackState)
        _playbackMessage = State(initialValue: initialPlaybackMessage)
        _playbackError = State(initialValue: initialPlaybackError)
        _activeEngine = State(initialValue: initialActiveEngine)
        _isShowingControls = State(initialValue: initialIsShowingControls)
        _isShowingSubtitlePicker = State(initialValue: initialIsShowingSubtitlePicker)
        _isShowingAudioPicker = State(initialValue: initialIsShowingAudioPicker)
        #if os(visionOS)
        _isShowingEnvironmentPicker = State(initialValue: initialIsShowingEnvironmentPicker)
        _isShowingCinemaSettings = State(initialValue: initialIsShowingCinemaSettings)
        #endif
        _subtitleFontSize = State(initialValue: initialSubtitleFontSize)
        _capabilityWarnings = State(initialValue: initialCapabilityWarnings)
        _environmentAssets = State(initialValue: initialEnvironmentAssets)
        _subtitleCandidates = State(initialValue: initialSubtitleCandidates)
        _subtitleCatalogMessage = State(initialValue: initialSubtitleCatalogMessage)
        _isRefreshingSubtitleCatalog = State(initialValue: initialIsRefreshingSubtitleCatalog)
        _isDownloadingSubtitle = State(initialValue: initialIsDownloadingSubtitle)
        _isShowingAutoPlayNextPrompt = State(initialValue: initialIsShowingAutoPlayNextPrompt)
        _isResolvingAutoPlayNextEpisode = State(initialValue: initialIsResolvingAutoPlayNextEpisode)
        _autoPlayNextCountdownRemaining = State(initialValue: initialAutoPlayNextCountdownRemaining)
        _aspectRatioSelection = State(initialValue: initialAspectRatioSelection)
        _ksSubtitleOptions = State(initialValue: initialKSSubtitleOptions.map {
            KSSubtitleOption(id: String($0.id), name: $0.name, language: $0.language)
        })
        _selectedKSSubtitleID = State(initialValue: initialSelectedKSSubtitleID)
    }

    var body: some View {
        playerCore
        #if os(visionOS)
        .modifier(ImmersiveControlHandlers(
            onToggleControls: {
                recordImmersiveControlEvent(.toggleControls)
                toggleControlsVisibility()
            },
            onTogglePlayPause: {
                recordImmersiveControlEvent(.togglePlayPause)
                togglePlayPause()
            },
            onSeekBack: {
                recordImmersiveControlEvent(.seekBack)
                seekRelative(-TimeInterval(PlayerCinematicChromePolicy.skipBackInterval))
            },
            onSeekForward: {
                recordImmersiveControlEvent(.seekForward)
                seekRelative(TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
            },
            onSeekToPercent: {
                recordImmersiveControlEvent(.seekToPercent($0))
                seekTo(percent: $0)
            },
            onPreviousChapter: {
                recordImmersiveControlEvent(.previousChapter)
                if let time = engine.previousChapterTime() { seek(to: time) }
            },
            onNextChapter: {
                recordImmersiveControlEvent(.nextChapter)
                if let time = engine.nextChapterTime() { seek(to: time) }
            },
            onCycleRate: {
                recordImmersiveControlEvent(.cycleRate)
                cyclePlaybackRate()
            },
            onToggleSubtitles: {
                recordImmersiveControlEvent(.toggleSubtitles)
                presentSubtitlePicker()
            },
            onToggleAudio: {
                recordImmersiveControlEvent(.toggleAudio)
                presentAudioPicker()
            },
            onRequestEnvironmentSwitch: {
                recordImmersiveControlEvent(.requestEnvironmentSwitch)
                requestEnvironmentPicker()
            },
            onDismiss: {
                recordImmersiveControlEvent(.dismiss)
                scheduleImmersiveDismiss(reason: .userInitiated)
            }
        ))
        #endif
        .modifier(AutoplayControlHandlers(
            onPlayNow: {
                recordAutoplayRuntimeEvent(.playNowRequested)
                playNextEpisodeNow()
            },
            onCancel: {
                recordAutoplayRuntimeEvent(.cancelRequested)
                cancelAutoPlayNextCountdown()
            },
            onProgress: { currentTime, duration in
                recordAutoplayRuntimeEvent(.progressObserved(currentTime: currentTime, duration: duration))
                handlePlaybackProgressForAutoplay(currentTime: currentTime, duration: duration)
                persistCompletionIfCrossedThreshold(currentTime: currentTime, duration: duration)
            }
        ))
        .modifier(SubtitleControlHandlers(
            onRefreshCatalog: {
                recordSubtitleRuntimeEvent(.refreshRequested)
                scheduleSubtitleCatalogRefresh(for: currentStream)
            },
            onDownload: { subtitle in
                recordSubtitleRuntimeEvent(.downloadRequested(fileID: subtitle.fileId))
                scheduleSubtitleDownload(subtitle, streamID: currentStream.id)
            }
        ))
        .onChange(of: stream) { _, stream in
            syncCurrentStreamIfNeeded(stream)
        }
        #if os(macOS)
        .background(PlayerWindowAccessor(window: $playerWindow).frame(width: 0, height: 0))
        .onChange(of: playerWindow) { _, newWindow in
            configurePlayerWindow(newWindow)
            isFullscreen = newWindow?.styleMask.contains(.fullScreen) ?? false
            applyStoredFullscreenPreferenceIfNeeded()
        }
        .onChange(of: aspectRatioSelection) { _, _ in
            if let playerWindow {
                applyWindowAspectRatio(to: playerWindow)
            }
        }
        .onChange(of: detectedVideoRatio) { _, _ in
            if let playerWindow, aspectRatioSelection == .auto {
                applyWindowAspectRatio(to: playerWindow)
            }
        }
        #endif
        #if os(visionOS)
        .background(PlayerWindowSceneAccessor(windowScene: $playerWindowScene).frame(width: 0, height: 0))
        .onChange(of: playerWindowScene) { _, _ in applyVisionOSWindowGeometry() }
        .onChange(of: detectedVideoRatio) { _, newRatio in
            applyVisionOSWindowGeometry()
            syncCinemaAspectRatio(newRatio)
        }
        .onChange(of: aspectRatioSelection) { _, _ in
            applyVisionOSWindowGeometry()
            applyAspectRatioPresentationMode()
        }
        .preferredSurroundingsEffect(engine.isDimEnabled ? .systemDark : nil)
        #endif
        .animation(motionAnimationsEnabled ? .easeInOut(duration: 0.25) : nil, value: isShowingControls)
        .sheet(isPresented: $isShowingSubtitlePicker) {
            subtitlePickerSheet
        }
        .onChange(of: isShowingSubtitlePicker) { _, isPresented in
            handleControlModalVisibilityChange(isPresented: isPresented)
        }
        .sheet(isPresented: $isShowingAudioPicker) {
            audioPickerSheet
        }
        .onChange(of: isShowingAudioPicker) { _, isPresented in
            handleControlModalVisibilityChange(isPresented: isPresented)
        }
        #if os(visionOS)
        .sheet(isPresented: $isShowingEnvironmentPicker) {
            EnvironmentPickerSheet(
                onSelect: { asset in
                    openEnvironmentAfterMenuDismissal(asset)
                },
                onDismiss: {
                    dismissEnvironmentAfterMenuDismissal()
                },
                onSelectCinema: {
                    openCinemaEnvironmentAfterMenuDismissal()
                }
            )
            .environment(appState)
        }
        .onChange(of: isShowingEnvironmentPicker) { _, isPresented in
            handleControlModalVisibilityChange(isPresented: isPresented)
        }
        .sheet(isPresented: $isShowingCinemaSettings) {
            CinemaSettingsPanel(settings: cinemaSettings)
        }
        .onChange(of: isShowingCinemaSettings) { _, isPresented in
            handleControlModalVisibilityChange(isPresented: isPresented)
        }
        #endif
    }

    private func recordImmersiveControlEvent(_ event: PlayerImmersiveControlEvent) {
        onImmersiveControlEvent?(event)
    }

    private func recordAutoplayRuntimeEvent(_ event: PlayerAutoplayRuntimeEvent) {
        onAutoplayRuntimeEvent?(event)
    }

    private func recordAutoplayPromptState() {
        guard onAutoplayRuntimeEvent != nil else { return }
        recordAutoplayRuntimeEvent(.stateChanged(PlayerAutoplayRuntimeSnapshot(
            didRequestAutoplayNext: didRequestAutoplayNext,
            didCancelAutoPlayNextPrompt: didCancelAutoPlayNextPrompt,
            isShowingAutoPlayNextPrompt: isShowingAutoPlayNextPrompt,
            isResolvingAutoPlayNextEpisode: isResolvingAutoPlayNextEpisode,
            countdownRemaining: autoPlayNextCountdownRemaining
        )))
    }

    private func recordSubtitleRuntimeEvent(_ event: PlayerSubtitleRuntimeEvent) {
        onSubtitleRuntimeEvent?(event)
    }

    private func recordSubtitleRuntimeState() {
        guard onSubtitleRuntimeEvent != nil else { return }
        recordSubtitleRuntimeEvent(.stateChanged(PlayerSubtitleRuntimeSnapshot(
            candidateCount: subtitleCandidates.count,
            catalogMessage: subtitleCatalogMessage,
            isRefreshingSubtitleCatalog: isRefreshingSubtitleCatalog,
            isDownloadingSubtitle: isDownloadingSubtitle,
            selectedSubtitleTrack: engine.selectedSubtitleTrack,
            subtitlesEnabled: engine.subtitlesEnabled
        )))
    }

    private func subtitleAutoSearchSetting(default defaultValue: Bool) async -> Bool {
        if let override = subtitleRuntimeSettings?.subtitleAutoSearch {
            return override
        }
        return (try? await appState.settingsManager.getBool(
            key: SettingsKeys.subtitleAutoSearch,
            default: defaultValue
        )) ?? defaultValue
    }

    private func openSubtitlesAPIKeySetting() async -> String? {
        if subtitleRuntimeSettings?.usesOpenSubtitlesAPIKeyOverride == true {
            return subtitleRuntimeSettings?.openSubtitlesAPIKey
        }
        return try? await appState.settingsManager.getString(key: SettingsKeys.openSubtitlesApiKey)
    }

    private func subtitleLanguageSetting() async -> String? {
        if let override = subtitleRuntimeSettings?.subtitleLanguage {
            return override
        }
        return try? await appState.settingsManager.getString(key: SettingsKeys.subtitleLanguage)
    }

    /// Core player view with lifecycle modifiers that don't require platform-
    /// specific notification handlers. Extracted from `body` to keep the
    /// expression small enough for the compiler's type-checker.
    private var playerCore: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            playerSurface
            subtitleOverlay
            controlsOverlay
            autoPlayNextOverlay
            startupStateOverlay
        }
        #if os(visionOS)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        #endif
        .animation(motionAnimationsEnabled ? .spring(response: 0.38, dampingFraction: 0.85) : nil, value: playbackState)
        .animation(motionAnimationsEnabled ? .easeInOut(duration: 0.18) : nil, value: engine.currentSubtitleText != nil)
        .onChange(of: playbackState) { _, newState in
            guard !disablesAutomaticTasks else { return }
            if newState == .playing, !hasPlayedOnce {
                hasPlayedOnce = true
                scrobbleStart()
            }
        }
        .task {
            guard !disablesAutomaticTasks else { return }
            initialPlayerStateTask?.cancel()
            initialPlayerStateTask = Task { await loadInitialPlayerState() }
            await initialPlayerStateTask?.value
        }
        .task(id: currentStream.id) {
            guard !disablesAutomaticTasks else { return }
            let preparationID = UUID()
            activePreparePlaybackID = preparationID
            preparePlaybackTask?.cancel()
            preparePlaybackTask = Task { await preparePlayback(for: currentStream, preparationID: preparationID) }
            await preparePlaybackTask?.value
        }
        .onAppear {
            guard !disablesAutomaticTasks else { return }
            #if os(macOS) || os(visionOS)
            scheduleMainWindowSuppressionIfNeeded()
            #endif
        }
        .onDisappear {
            guard !disablesAutomaticTasks else { return }
            stopProgressPersistence()
            // Skip the terminal scrobbleStop()/persist when the explicit close path already ran
            // them — calling scrobbleStop() again here makes onDisappear's scrobbleTask?.cancel()
            // cancel the in-flight >80% addToHistory write, intermittently losing the watch.
            if !didInitiateClose {
                scrobbleStop()
                persistCurrentWatchProgress()
            }
            initialPlayerStateTask?.cancel()
            activePreparePlaybackID = nil
            preparePlaybackTask?.cancel()
            subtitleCatalogTask?.cancel()
            subtitleDownloadTask?.cancel()
            environmentAssetsTask?.cancel()
            scenePhaseTask?.cancel()
            memoryPressureTask?.cancel()
            avMediaOptionRefreshTask?.cancel()
            avMediaOptionRefreshTask = nil
            audioTrackRefreshTask?.cancel()
            audioTrackRefreshTask = nil
            subtitleTrackRefreshTask?.cancel()
            subtitleTrackRefreshTask = nil
            autoPlayNextCountdownTask?.cancel()
            autoPlayNextResolveTask?.cancel()
            cleanupPlayback()
            controlsHideTask?.cancel()
            controlsHideTask = nil
            RuntimeMemoryDiagnostics.capture(
                event: .playerDidDisappear,
                enabled: appState.runtimeDiagnosticsEnabled,
                context: resolvedMediaTitle
            )
            if let subtitleFileURL = downloadedSubtitleFileURL {
                try? FileManager.default.removeItem(at: subtitleFileURL)
                downloadedSubtitleFileURL = nil
            }
            #if os(visionOS)
            visionGeometryTask?.cancel()
            visionGeometryTask = nil
            environmentMenuActionTask?.cancel()
            environmentMenuActionTask = nil
            immersiveDismissTask?.cancel()
            immersiveDismissTask = nil
            scheduleImmersiveDismiss(reason: .playerClosed, restoresMainWindow: true)
            #elseif os(macOS)
            resetWindowAspectRatio()
            scheduleMainWindowRestoreIfNeeded()
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            environmentAssetsTask?.cancel()
            environmentAssetsTask = Task { await loadEnvironmentAssets() }
        }
        .onChange(of: appState.activePlayerSession?.id) { _, activeSessionID in
            guard activeSessionID != sessionID else { return }
            closePlayer()
        }
        #if os(visionOS)
        .onChange(of: scenePhase) { _, phase in
            scenePhaseTask?.cancel()
            scenePhaseTask = Task { await handleScenePhaseChange(phase) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            memoryPressureTask?.cancel()
            memoryPressureTask = Task { await handleMemoryPressureWarning() }
        }
        .onChange(of: engine.stereoMode) { _, _ in
            updateAPMPInjector()
        }
        .onChange(of: appState.isImmersiveSpaceOpen) { _, _ in
            updateAPMPInjector()
        }
        #endif
    }

    /// Video gravity — `.resizeAspectFill` for edge-to-edge display.
    /// The window itself is forced to the video's aspect ratio via geometry
    /// preferences, so fill never crops.
    private var currentVideoGravity: AVLayerVideoGravity {
        PlayerAspectRatioPolicy.videoGravity(for: aspectRatioSelection)
    }

    @ViewBuilder
    private var playerSurface: some View {
        if activeEngine == .ksPlayer,
           let coordinator = ksPlayerCoordinator,
           let options = ksOptions {
            KSVideoPlayer(coordinator: coordinator, url: currentStream.streamURL, options: options)
                .ignoresSafeArea()
                .onAppear {
                    coordinator.isScaleAspectFill = currentVideoGravity == .resizeAspectFill
                }
                .onTapGesture {
                    toggleControlsVisibility()
                }
        } else if let avPlayer {
            #if os(visionOS)
            if isAPMPActive, let displayLayer = apmpInjector.displayLayer {
                APMPRendererView(displayLayer: displayLayer)
                    .ignoresSafeArea()
                    .onTapGesture {
                        toggleControlsVisibility()
                    }
            } else {
                AVPlayerSurfaceView(player: avPlayer, videoGravity: currentVideoGravity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        toggleControlsVisibility()
                    }
            }
            #else
            AVPlayerSurfaceView(player: avPlayer, videoGravity: currentVideoGravity)
                .ignoresSafeArea()
                .onTapGesture {
                    toggleControlsVisibility()
                }
            #endif
        }
    }

    @ViewBuilder
    private var startupStateOverlay: some View {
        PlayerStartupStateOverlayView(
            playbackState: playbackState,
            title: playbackStateTitle,
            message: playbackMessage,
            hasPlayedOnce: hasPlayedOnce,
            hasNextStream: hasNextStream,
            onRetry: { retryPlayback() },
            onTryNextStream: { tryNextStream() }
        )
    }

    @ViewBuilder
    private var subtitleOverlay: some View {
        if let subtitleText = engine.currentSubtitleText {
            VStack {
                Spacer()
                Text(subtitleText)
                    .font(.system(size: subtitleFontSize, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 90)
                    .transition(.blurReplace.combined(with: .opacity))
                    .contextMenu {
                        ForEach([18.0, 22.0, 26.0, 30.0, 36.0, 42.0], id: \.self) { size in
                            Button("Size \(Int(size))pt") {
                                subtitleFontSize = size
                            }
                        }
                    }
            }
            .compositingGroup()
        }
    }

    @ViewBuilder
    private var autoPlayNextOverlay: some View {
        if isShowingAutoPlayNextPrompt, let nextEpisode = queuedNextEpisode {
            autoPlayNextPrompt(nextEpisode)
                .padding(.horizontal, 24)
                .padding(.bottom, 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(
                    motionAnimationsEnabled ? .easeInOut(duration: 0.2) : nil,
                    value: isShowingAutoPlayNextPrompt
                )
                .animation(
                    motionAnimationsEnabled ? .linear(duration: 0.2) : nil,
                    value: autoPlayNextCountdownRemaining
                )
        }
    }

    private func autoPlayNextPrompt(_ nextEpisode: PlayerSessionRequest.NextEpisodeCandidate) -> some View {
        PlayerAutoPlayNextPromptView(
            nextEpisode: nextEpisode,
            remainingSeconds: autoPlayNextCountdownRemaining,
            isResolving: isResolvingAutoPlayNextEpisode,
            onPlayNow: { playNextEpisodeNow() },
            onCancel: { cancelAutoPlayNextCountdown() }
        )
    }

    // MARK: - Controls Overlay (full-height, overlaying video)

    @ViewBuilder
    private var controlsOverlay: some View {
        if isShowingControls {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    titleBar
                        .compositingGroup()

                    warningsOverlay
                        .padding(.top, 6)
                        .compositingGroup()

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack(spacing: PlayerCinematicChromePolicy.controlsDockSpacing) {
                    infoPillsRow
                        .frame(maxWidth: PlayerCinematicChromePolicy.quickActionsMaxWidth)

                    transportBar
                        .compositingGroup()
                }
                .padding(.horizontal, PlayerCinematicChromePolicy.controlsDockHorizontalPadding)
                .padding(.bottom, PlayerCinematicChromePolicy.controlsDockBottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .transition(.opacity)
        }
    }

    // MARK: - Title Bar (top edge, overlaying video)

    private var titleBar: some View {
        HStack(spacing: 12) {
            Button {
                closePlayer()
            } label: {
                topBarUtilityButton(
                    systemName: PlayerCinematicVisualPolicy.backSymbolName,
                    accessibilityLabel: "Close player"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close player")
            .accessibilityHint("Dismisses playback and returns to the previous screen.")
            #if os(visionOS)
            .hoverEffect(.lift)
            #endif

            titleMetadataBlock

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button {
                    presentSubtitlePicker()
                } label: {
                    topBarUtilityButton(
                        systemName: subtitlePresentationIsActive ? "captions.bubble.fill" : "captions.bubble",
                        isActive: isShowingSubtitlePicker || subtitlePresentationIsActive,
                        accessibilityLabel: "Subtitles"
                    )
                }
                .buttonStyle(.plain)
                #if os(visionOS)
                .hoverEffect(.lift)
                #endif

                Button {
                    presentAudioPicker()
                } label: {
                    topBarUtilityButton(
                        systemName: availableAudioTrackCount > 1 ? "speaker.wave.2.fill" : "speaker.wave.2",
                        isActive: isShowingAudioPicker || availableAudioTrackCount > 1,
                        accessibilityLabel: "Audio Tracks"
                    )
                }
                .buttonStyle(.plain)
                #if os(visionOS)
                .hoverEffect(.lift)
                #endif

                Button {
                    toggleControlsLock()
                } label: {
                    topBarUtilityButton(
                        systemName: isControlsLocked ? "lock.fill" : "lock.open",
                        isActive: isControlsLocked,
                        accessibilityLabel: isControlsLocked ? "Unlock controls" : "Lock controls"
                    )
                }
                .buttonStyle(.plain)
                #if os(visionOS)
                .hoverEffect(.lift)
                #endif

                Menu {
                    // Stream quality picker
                    Section("Stream") {
                        ForEach(streamQueue, id: \.id) { stream in
                            Button {
                                keepControlsVisibleForMenuAction()
                                switchToStream(stream)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stream.quality.rawValue)
                                        Text(stream.qualityBadge)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if stream.id == currentStream.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Section("Aspect Ratio") {
                        Button {
                            keepControlsVisibleForMenuAction()
                            aspectRatioSelection = aspectRatioSelection == .freeform ? .auto : .freeform
                        } label: {
                            HStack {
                                Label("Freeflow Resize", systemImage: "arrow.up.left.and.arrow.down.right")
                                if aspectRatioSelection == .freeform {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        ForEach(AspectRatioSelection.allCases.filter { $0 != .freeform }, id: \.id) { selection in
                            Button {
                                keepControlsVisibleForMenuAction()
                                aspectRatioSelection = selection
                            } label: {
                                HStack {
                                    Label(selection.label, systemImage: selection.icon)
                                    if aspectRatioSelection == selection {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    #if os(macOS)
                    Section {
                        Button {
                            keepControlsVisibleForMenuAction()
                            guard let playerWindow else { return }
                            playerWindow.toggleFullScreen(nil)
                            isFullscreen = playerWindow.styleMask.contains(.fullScreen)
                            if let sessionID {
                                appState.fullscreenBySessionID[sessionID] = isFullscreen
                            }
                        } label: {
                            Label(
                                isFullscreen ? "Exit Fullscreen" : "Enter Fullscreen",
                                systemImage: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                            )
                        }
                    }
                    #endif

                    #if os(visionOS)
                    Section("Environment") {
                        Button {
                            keepControlsVisibleForMenuAction()
                            openCinemaEnvironmentAfterMenuDismissal()
                        } label: {
                            Label("Cinema Environment", systemImage: "theatermasks")
                        }
                        .disabled(!PlayerCinemaEnvironmentPolicy.canOpen(
                            activeEngine: activeEngine,
                            hasAVPlayer: avPlayer != nil
                        ))

                        Button {
                            keepControlsVisibleForMenuAction()
                            showCinemaSettingsAfterMenuDismissal()
                        } label: {
                            Label("Cinema Settings", systemImage: "slider.horizontal.3")
                        }

                        if environmentAssets.isEmpty {
                            Button {
                                keepControlsVisibleForMenuAction()
                                showEnvironmentPickerAfterMenuDismissal()
                            } label: {
                                Label("Browse Environments", systemImage: "mountain.2")
                            }
                        } else {
                            ForEach(environmentAssets, id: \.id) { asset in
                                Button {
                                    keepControlsVisibleForMenuAction()
                                    openEnvironmentAfterMenuDismissal(asset)
                                } label: {
                                    HStack {
                                        Text(asset.name)
                                        if asset.id == appState.selectedEnvironmentAsset?.id,
                                           appState.isImmersiveSpaceOpen {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        if appState.isImmersiveSpaceOpen {
                            Button(role: .destructive) {
                                keepControlsVisibleForMenuAction()
                                dismissEnvironmentAfterMenuDismissal()
                            } label: {
                                Label("Exit Environment", systemImage: "xmark.circle")
                            }
                        }
                    }
                    #endif
                } label: {
                    topBarUtilityButton(systemName: "ellipsis", accessibilityLabel: "More Playback Options")
                }
                .buttonStyle(.plain)
                #if os(visionOS)
                .hoverEffect(.lift)
                #endif
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: useObsidianGlass
                    ? [
                        VPColor.void.opacity(PlayerCinematicVisualPolicy.topScrimOpacity + 0.24),
                        VPColor.void.opacity(0.18),
                        .clear
                    ]
                    : [
                        .black.opacity(PlayerCinematicVisualPolicy.topScrimOpacity + 0.24),
                        .black.opacity(0.18),
                        .clear
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: PlayerCinematicChromePolicy.topScrimHeight),
            alignment: .top
        )
    }

    private var titleMetadataBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(resolvedMediaTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack(spacing: 8) {
                if let chapter = engine.currentChapter(at: engine.currentTime) {
                    Text(chapter.title)
                        .lineLimit(1)
                } else {
                    Text(currentStream.quality.rawValue)
                    if let activeEngine {
                        Text(activeEngine.displayName)
                    }
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(PlayerCinematicVisualPolicy.timeLabelOpacity))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func topBarUtilityButton(
        systemName: String,
        isActive: Bool = false,
        accessibilityLabel: String
    ) -> some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(
                width: PlayerCinematicChromePolicy.topBarButtonSize,
                height: PlayerCinematicChromePolicy.topBarButtonSize
            )
            .background(
                useObsidianGlass
                    ? (isActive ? AnyShapeStyle(VPColor.accentGlow) : AnyShapeStyle(VPElevation.raised.material))
                    : (isActive ? AnyShapeStyle(.tint.opacity(0.34)) : AnyShapeStyle(.ultraThinMaterial)),
                in: Circle()
            )
            .overlay {
                if useObsidianGlass {
                    Circle().strokeBorder(
                        LinearGradient(colors: [VPColor.specularBright, VPColor.specularDim],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: VPElevation.raised.strokeWidth
                    )
                } else {
                    Circle()
                        .strokeBorder(.white.opacity(PlayerCinematicVisualPolicy.iconSurfaceBorderOpacity), lineWidth: 0.8)
                }
            }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
            .contentShape(Circle())
            .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Info Pills Row (floating above transport bar)

    private var infoPillsRow: some View {
        HStack(spacing: 8) {
            Button {
                keepControlsVisibleForMenuAction()
                cyclePlaybackRate()
            } label: {
                Text("\(engine.playbackRate, specifier: "%.1f")x")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            #if os(visionOS)
            .hoverEffect(.lift)
            #endif

            #if os(visionOS)
            // Environment toggle pill — always visible so users can open built-in cinema or imported environments.
            Menu {
                Button {
                    keepControlsVisibleForMenuAction()
                    openCinemaEnvironmentAfterMenuDismissal()
                } label: {
                    if appState.activeEnvironment == .cinemaEnvironment,
                       appState.isImmersiveSpaceOpen {
                        Label("Cinema Environment", systemImage: "checkmark")
                    } else {
                        Label("Cinema Environment", systemImage: "theatermasks")
                    }
                }
                .disabled(!PlayerCinemaEnvironmentPolicy.canOpen(
                    activeEngine: activeEngine,
                    hasAVPlayer: avPlayer != nil
                ))

                Button {
                    keepControlsVisibleForMenuAction()
                    showCinemaSettingsAfterMenuDismissal()
                } label: {
                    Label("Cinema Settings", systemImage: "slider.horizontal.3")
                }

                Divider()

                if environmentAssets.isEmpty {
                    Text("No imported environments")
                } else {
                    ForEach(environmentAssets, id: \.id) { asset in
                        Button {
                            keepControlsVisibleForMenuAction()
                            openEnvironmentAfterMenuDismissal(asset)
                        } label: {
                            if asset.id == appState.selectedEnvironmentAsset?.id,
                               appState.isImmersiveSpaceOpen,
                               appState.activeEnvironment != .cinemaEnvironment {
                                Label(asset.name, systemImage: "checkmark")
                            } else {
                                Label(asset.name, systemImage: environmentAssetIcon(asset))
                            }
                        }
                    }
                }

                Button {
                    keepControlsVisibleForMenuAction()
                    showEnvironmentPickerAfterMenuDismissal()
                } label: {
                    Label("Browse Environments", systemImage: "mountain.2")
                }

                if appState.isImmersiveSpaceOpen {
                    Divider()
                    Button(role: .destructive) {
                        keepControlsVisibleForMenuAction()
                        dismissEnvironmentAfterMenuDismissal()
                    } label: {
                        Label("Exit Environment", systemImage: "xmark.circle")
                    }
                }
            } label: {
                Image(systemName: appState.isImmersiveSpaceOpen ? "mountain.2.fill" : "mountain.2")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        appState.isImmersiveSpaceOpen
                            ? AnyShapeStyle(.tint.opacity(0.35))
                            : AnyShapeStyle(.ultraThinMaterial),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open immersive environments")
            .hoverEffect(.lift)
            .animation(motionAnimationsEnabled ? .easeInOut(duration: 0.2) : nil, value: appState.isImmersiveSpaceOpen)

            // Dim passthrough toggle pill
            Button {
                keepControlsVisibleForMenuAction()
                engine.isDimEnabled.toggle()
                Task {
                    try? await appState.settingsManager.setBool(
                        key: SettingsKeys.playerDimPassthrough,
                        value: engine.isDimEnabled
                    )
                }
            } label: {
                Image(systemName: engine.isDimEnabled ? "sun.min.fill" : "sun.max")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        engine.isDimEnabled
                            ? AnyShapeStyle(.tint.opacity(0.35))
                            : AnyShapeStyle(.ultraThinMaterial),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.isDimEnabled ? "Disable dim passthrough" : "Enable dim passthrough")
            .hoverEffect(.lift)
            .animation(motionAnimationsEnabled ? .easeInOut(duration: 0.2) : nil, value: engine.isDimEnabled)
            #endif

            // Quality badge pill
            featureChip(title: currentStream.quality.rawValue, symbol: nil)

            // 3D badge if applicable
            if engine.is3DContent {
                featureChip(title: "3D", symbol: "cube")
            }

            // Engine label pill
            if let activeEngine {
                featureChip(title: activeEngine.displayName, symbol: nil)
            }
        }
    }

    // MARK: - Transport Bar (bottom edge, overlaying video)

    private var transportBar: some View {
        VStack(spacing: 10) {
            playbackProgressBar
            timeLabelsRow
            transportControlsRow

            Capsule()
                .fill(.white.opacity(0.24))
                .frame(width: 34, height: 3)
                .padding(.top, 2)
        }
        .padding(.horizontal, PlayerCinematicChromePolicy.transportCardHorizontalPadding)
        .padding(.vertical, PlayerCinematicChromePolicy.transportCardVerticalPadding)
        .frame(maxWidth: PlayerCinematicChromePolicy.transportCardMaxWidth)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
                cornerRadius: PlayerCinematicChromePolicy.transportCardCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PlayerCinematicChromePolicy.transportCardCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: useObsidianGlass
                        ? [VPColor.specularBright, VPColor.specularDim]
                        : [.white.opacity(0.26), .white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(0.24), radius: 24, y: 10)
    }

    private var playbackProgressBar: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width
            let displayTime = PlayerViewPolicy.progressBarDisplayTime(
                currentTime: engine.currentTime,
                isScrubbing: isScrubbing,
                scrubTime: scrubTime
            )
            let displayPercent = PlayerViewPolicy.progressBarDisplayPercent(
                displayTime: displayTime,
                duration: engine.duration
            )
            let progressX = barWidth * displayPercent
            let bufferedX = barWidth * PlayerViewPolicy.progressBarBufferedPercent(engine.bufferedPercent)
            let barHeight = PlayerViewPolicy.progressBarHeight(isScrubbing: isScrubbing)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(PlayerCinematicVisualPolicy.progressTrackOpacity))
                    .frame(height: barHeight)

                Capsule()
                    .fill(.white.opacity(PlayerCinematicVisualPolicy.progressBufferedOpacity))
                    .frame(width: bufferedX, height: barHeight)

                Capsule()
                    .fill(.white)
                    .frame(width: progressX, height: barHeight)

                if !engine.chapters.isEmpty && engine.duration > 0 {
                    ForEach(engine.chapters) { chapter in
                        let tickX = barWidth * (chapter.startTime / engine.duration)
                        if PlayerViewPolicy.shouldShowChapterMarker(chapterStartTime: chapter.startTime) {
                            RoundedRectangle(cornerRadius: 0.75)
                                .fill(.white.opacity(0.58))
                                .frame(width: 2, height: barHeight + 5)
                                .position(x: tickX, y: geo.size.height / 2)
                        }
                    }
                }

                Circle()
                    .fill(.white)
                    .frame(width: isScrubbing ? 16 : 10, height: isScrubbing ? 16 : 10)
                    .shadow(color: .black.opacity(0.34), radius: 4, y: 2)
                    .position(x: progressX, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let percent = PlayerViewPolicy.scrubberDragPercent(
                            locationX: value.location.x,
                            barWidth: barWidth
                        )
                        scrubTime = engine.duration * percent
                        if !isScrubbing {
                            controlsHideTask?.cancel()
                            isScrubbing = true
                        }
                    }
                    .onEnded { value in
                        let percent = PlayerViewPolicy.scrubberDragPercent(
                            locationX: value.location.x,
                            barWidth: barWidth
                        )
                        seekTo(percent: percent)
                        isScrubbing = false
                        scheduleControlsHide()
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback position")
            .accessibilityValue(scrubberAccessibilityValue)
            .accessibilityHint("Adjust to seek through the current video.")
            .accessibilityAdjustableAction { direction in
                adjustScrubberAccessibility(direction)
            }
            .animation(motionAnimationsEnabled ? .easeInOut(duration: 0.15) : nil, value: isScrubbing)

            if isScrubbing {
                Text(scrubTime.formattedDuration)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
                    .position(
                        x: PlayerViewPolicy.scrubPreviewLabelX(progressX: progressX, barWidth: barWidth),
                        y: -10
                    )
            }
        }
        .frame(height: 22)
    }

    private var timeLabelsRow: some View {
        HStack {
            Text(isScrubbing ? scrubTime.formattedDuration : engine.currentTimeFormatted)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(PlayerCinematicVisualPolicy.timeLabelOpacity))

            Spacer()

            Text("-\(engine.remainingFormatted)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(PlayerCinematicVisualPolicy.timeLabelOpacity))
        }
    }

    private var transportControlsRow: some View {
        HStack(spacing: 24) {
            if !engine.chapters.isEmpty {
                transportIconButton(
                    systemName: PlayerCinematicVisualPolicy.previousChapterSymbolName,
                    accessibilityLabel: "Previous chapter"
                ) {
                    if let time = engine.previousChapterTime() { seek(to: time) }
                }
            }

            transportIconButton(
                systemName: PlayerCinematicVisualPolicy.skipBackSymbolName,
                accessibilityLabel: "Back \(PlayerCinematicChromePolicy.skipBackInterval) seconds"
            ) {
                seekRelative(-TimeInterval(PlayerCinematicChromePolicy.skipBackInterval))
            }

            Button {
                togglePlayPause()
            } label: {
                Image(systemName: playPausePresentation.symbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(
                        width: PlayerCinematicChromePolicy.primaryTransportButtonSize,
                        height: PlayerCinematicChromePolicy.primaryTransportButtonSize
                    )
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.24), radius: 10, y: 3)
            }
            .accessibilityLabel(playPausePresentation.label)
            .accessibilityValue(playPausePresentation.accessibilityValue)
            .buttonStyle(.plain)
            #if os(visionOS)
            .hoverEffect(.lift)
            #endif

            transportIconButton(
                systemName: PlayerCinematicVisualPolicy.skipForwardSymbolName,
                accessibilityLabel: "Forward \(PlayerCinematicChromePolicy.skipForwardInterval) seconds"
            ) {
                seekRelative(TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
            }

            if !engine.chapters.isEmpty {
                transportIconButton(
                    systemName: PlayerCinematicVisualPolicy.nextChapterSymbolName,
                    accessibilityLabel: "Next chapter"
                ) {
                    if let time = engine.nextChapterTime() { seek(to: time) }
                }
            }
        }
        .frame(minHeight: PlayerCinematicChromePolicy.primaryTransportButtonSize)
    }

    private func transportIconButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(
                    width: PlayerCinematicChromePolicy.secondaryTransportButtonSize,
                    height: PlayerCinematicChromePolicy.secondaryTransportButtonSize
                )
                .background(.white.opacity(0.10), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
                }
        }
        .accessibilityLabel(accessibilityLabel)
        .buttonStyle(.plain)
        #if os(visionOS)
        .hoverEffect(.highlight)
        #endif
    }

    // MARK: - Capability Warnings & Errors (shown in title bar area when present)

    @ViewBuilder
    private var warningsOverlay: some View {
        let warningError = PlayerViewPolicy.warningOverlayPlaybackError(
            playbackError: playbackError,
            playbackState: playbackState
        )
        if PlayerViewPolicy.shouldShowWarningsOverlay(
            capabilityWarnings: capabilityWarnings,
            playbackError: playbackError,
            playbackState: playbackState
        ) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(capabilityWarnings, id: \.self) { warning in
                    Text(warning)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if let warningError {
                    Text(warningError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var subtitlePickerSheet: some View {
        NavigationStack {
            List {
                Section("Current Selection") {
                    Button("Off") {
                        selectSubtitlesOff()
                    }
                    .foregroundStyle(currentSubtitleSelectionIsOff ? .blue : .primary)
                }

                if !avSubtitleOptions.isEmpty || !ksSubtitleOptions.isEmpty {
                    Section("Direct Link Subtitles") {
                        ForEach(avSubtitleOptions) { track in
                            Button {
                                selectAVSubtitle(track)
                                isShowingSubtitlePicker = false
                            } label: {
                                subtitleTrackRow(name: track.name, language: track.language)
                            }
                            .foregroundStyle(
                                PlayerTrackPresentationPolicy.isDirectTrackSelected(
                                    selectedID: selectedAVSubtitleID,
                                    trackID: track.id
                                ) ? .blue : .primary
                            )
                        }

                        ForEach(ksSubtitleOptions) { track in
                            Button {
                                selectKSSubtitle(track)
                                isShowingSubtitlePicker = false
                            } label: {
                                subtitleTrackRow(name: track.name, language: track.language)
                            }
                            .foregroundStyle(
                                PlayerTrackPresentationPolicy.isDirectTrackSelected(
                                    selectedID: selectedKSSubtitleID,
                                    trackID: track.id
                                ) ? .blue : .primary
                            )
                        }
                    }
                }

                Section("OpenSubtitles") {
                    if isDownloadingSubtitle {
                        HStack {
                            ProgressView()
                            Text("Downloading subtitle...")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !engine.subtitleTracks.isEmpty {
                        ForEach(engine.subtitleTracks) { track in
                            Button {
                                selectExternalSubtitle(index: track.id)
                                isShowingSubtitlePicker = false
                            } label: {
                                subtitleTrackRow(name: track.name, language: track.language)
                            }
                            .foregroundStyle(
                                PlayerTrackPresentationPolicy.isExternalSubtitleSelected(
                                    selectedAVSubtitleID: selectedAVSubtitleID,
                                    selectedEngineSubtitleTrack: engine.selectedSubtitleTrack,
                                    trackID: track.id
                                ) ? .blue : .primary
                            )
                        }
                    }

                    if isRefreshingSubtitleCatalog {
                        HStack {
                            ProgressView()
                            Text("Searching subtitles...")
                                .foregroundStyle(.secondary)
                        }
                    } else if subtitleCandidates.isEmpty {
                        Text(subtitleCatalogMessage ?? "No subtitle results found for this stream.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(subtitleCandidates, id: \.id) { subtitle in
                            Button {
                                scheduleSubtitleDownload(subtitle, streamID: currentStream.id)
                            } label: {
                                subtitleCandidateRow(subtitle)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .navigationTitle("Subtitles")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        refreshCurrentMediaTrackOptions()
                        scheduleSubtitleCatalogRefresh(for: currentStream)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh subtitle list")
                    .disabled(isRefreshingSubtitleCatalog || isDownloadingSubtitle)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private var audioPickerSheet: some View {
        NavigationStack {
            List {
                if !avAudioOptions.isEmpty || !engine.audioTracks.isEmpty {
                    Section("Direct Link Audio") {
                        ForEach(avAudioOptions) { track in
                            Button {
                                selectAVAudio(track)
                                isShowingAudioPicker = false
                            } label: {
                                subtitleTrackRow(name: track.name, language: track.language)
                            }
                            .foregroundStyle(
                                PlayerTrackPresentationPolicy.isDirectTrackSelected(
                                    selectedID: selectedAVAudioID,
                                    trackID: track.id
                                ) ? .blue : .primary
                            )
                        }

                        ForEach(engine.audioTracks) { track in
                            Button {
                                selectEngineAudio(track)
                                isShowingAudioPicker = false
                            } label: {
                                subtitleTrackRow(name: track.name, language: track.language)
                            }
                            .foregroundStyle(
                                PlayerTrackPresentationPolicy.isEngineTrackSelected(
                                    selectedTrackID: engine.selectedAudioTrack,
                                    trackID: track.id
                                ) ? .blue : .primary
                            )
                        }
                    }
                } else {
                    Section("Audio") {
                        Text(PlayerViewPolicy.emptyAudioTracksMessage(activeEngine: activeEngine))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        refreshCurrentMediaTrackOptions()
                    } label: {
                        Label("Refresh Track List", systemImage: "arrow.clockwise")
                    }
                    .disabled(!canRefreshTrackList)
                }
            }
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .navigationTitle("Audio")
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        refreshCurrentMediaTrackOptions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh audio tracks")
                    .disabled(!canRefreshTrackList)
                }
                #else
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refreshCurrentMediaTrackOptions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh audio tracks")
                    .disabled(!canRefreshTrackList)
                }
                #endif
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }


    private var playPausePresentation: PlayerControlPresentation {
        PlayerControlPresentationMapper.playPause(
            playbackState: playbackState,
            isCurrentlyPlaying: isCurrentlyPlaying
        )
    }

    private var isCurrentlyPlaying: Bool {
        switch activeEngine {
        case .ksPlayer:
            return ksPlayerCoordinator?.state.isPlaying ?? engine.isPlaying
        case .avPlayer:
            return avPlayer?.timeControlStatus == .playing || avPlayer?.rate ?? 0 > 0
        default:
            return false
        }
    }

    private var currentSubtitleSelectionIsOff: Bool {
        PlayerTrackPresentationPolicy.isSubtitleSelectionOff(
            subtitlesEnabled: engine.subtitlesEnabled
        )
    }

    private var canRefreshTrackList: Bool {
        PlayerTrackPresentationPolicy.canRefreshTrackList(
            hasAVPlayer: avPlayer != nil,
            hasKSPlayerCoordinator: ksPlayerCoordinator != nil
        )
    }

    private var autoPlayNextPromptState: PlayerAutoplayNextPolicy.PromptState {
        PlayerViewStatePolicy.autoplayPromptState(
            hasNextEpisode: queuedNextEpisode != nil,
            didRequestAutoplayNext: didRequestAutoplayNext,
            didCancelAutoPlayNextPrompt: didCancelAutoPlayNextPrompt,
            isShowingAutoPlayNextPrompt: isShowingAutoPlayNextPrompt,
            isResolvingAutoPlayNextEpisode: isResolvingAutoPlayNextEpisode,
            countdownRemaining: autoPlayNextCountdownRemaining
        )
    }

    private func applyAutoPlayNextPromptState(_ state: PlayerAutoplayNextPolicy.PromptState) {
        let fields = PlayerViewStatePolicy.autoplayPromptFields(from: state)
        didRequestAutoplayNext = fields.didRequestAutoplayNext
        didCancelAutoPlayNextPrompt = fields.didCancelAutoPlayNextPrompt
        isShowingAutoPlayNextPrompt = fields.isShowingAutoPlayNextPrompt
        isResolvingAutoPlayNextEpisode = fields.isResolvingAutoPlayNextEpisode
        autoPlayNextCountdownRemaining = fields.countdownRemaining
        recordAutoplayPromptState()
    }

    private var playbackStateTitle: String {
        PlayerViewPolicy.playbackStateTitle(for: playbackState)
    }

    private var hasNextStream: Bool {
        PlayerViewStatePolicy.nextStream(after: currentStream, in: streamQueue) != nil
    }

    private func tryNextStream() {
        guard let next = PlayerViewStatePolicy.nextStream(after: currentStream, in: streamQueue) else { return }
        switchToStream(next)
    }

    private func switchToStream(_ stream: StreamInfo) {
        guard let plan = PlayerViewStatePolicy.streamTransitionPlan(from: currentStream, to: stream) else { return }
        persistCurrentWatchProgress()
        resetSubtitleStateForStreamTransition()
        resetAutoPlayNextStateForStreamTransition()
        currentStream = plan.stream
        playbackMessage = plan.message
        scheduleSubtitleCatalogRefresh(for: plan.stream)
    }

    private func handlePlaybackProgressForAutoplay(currentTime: TimeInterval, duration: TimeInterval) {
        guard PlayerAutoplayNextPolicy.shouldStartCountdown(
            currentTime: currentTime,
            duration: duration,
            hasNextEpisode: queuedNextEpisode != nil,
            hasStartedCountdown: didRequestAutoplayNext,
            wasCancelled: didCancelAutoPlayNextPrompt,
            isResolving: isResolvingAutoPlayNextEpisode
        ) else {
            return
        }

        scheduleAutoPlayNextCountdownIfNeeded()
    }

    private func scheduleAutoPlayNextCountdownIfNeeded() {
        let state = autoPlayNextPromptState
        guard PlayerAutoplayNextPolicy.shouldScheduleCountdown(state: state) else { return }

        applyAutoPlayNextPromptState(PlayerAutoplayNextPolicy.stateAfterSchedulingCountdown(from: state))
        autoPlayNextCountdownTask?.cancel()
        autoPlayNextCountdownTask = Task { @MainActor in
            let autoPlayNext = (try? await appState.settingsManager.getBool(
                key: SettingsKeys.autoPlayNext,
                default: true
            )) ?? true

            guard !Task.isCancelled else { return }
            guard autoPlayNext, queuedNextEpisode != nil else {
                applyAutoPlayNextPromptState(
                    PlayerAutoplayNextPolicy.stateAfterCountdownUnavailable(from: autoPlayNextPromptState)
                )
                autoPlayNextCountdownTask = nil
                return
            }

            applyAutoPlayNextPromptState(
                PlayerAutoplayNextPolicy.stateAfterPresentingCountdown(from: autoPlayNextPromptState)
            )

            for seconds in stride(
                from: PlayerAutoplayNextPolicy.countdownDurationSeconds,
                through: 1,
                by: -1
            ) {
                autoPlayNextCountdownRemaining = seconds
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
            }

            autoPlayNextCountdownRemaining = 0
            autoPlayNextCountdownTask = nil
            startAutoPlayNextResolution()
        }
    }

    private func playNextEpisodeNow() {
        let state = autoPlayNextPromptState
        let nextState = PlayerAutoplayNextPolicy.stateAfterPlayNow(from: state)
        guard nextState != state else { return }
        applyAutoPlayNextPromptState(nextState)
        autoPlayNextCountdownTask?.cancel()
        autoPlayNextCountdownTask = nil
        startAutoPlayNextResolution()
    }

    private func cancelAutoPlayNextCountdown() {
        applyAutoPlayNextPromptState(
            PlayerAutoplayNextPolicy.stateAfterCancellingCountdown(from: autoPlayNextPromptState)
        )
        autoPlayNextCountdownTask?.cancel()
        autoPlayNextCountdownTask = nil
    }

    private func startAutoPlayNextResolution() {
        let state = autoPlayNextPromptState
        let nextState = PlayerAutoplayNextPolicy.stateAfterStartingResolution(from: state)
        guard nextState != state else { return }
        applyAutoPlayNextPromptState(nextState)
        autoPlayNextResolveTask?.cancel()
        autoPlayNextResolveTask = Task { @MainActor in
            await autoPlayNextEpisodeIfPossible()
        }
    }

    private func resetAutoPlayNextStateForStreamTransition() {
        autoPlayNextCountdownTask?.cancel()
        autoPlayNextCountdownTask = nil
        autoPlayNextResolveTask?.cancel()
        autoPlayNextResolveTask = nil
        applyAutoPlayNextPromptState(
            PlayerAutoplayNextPolicy.stateAfterStreamTransition(hasNextEpisode: queuedNextEpisode != nil)
        )
    }

    @MainActor
    private func autoPlayNextEpisodeIfPossible() async {
        let nextEpisode: PlayerSessionRequest.NextEpisodeCandidate
        switch PlayerViewStatePolicy.autoplayNextPreflight(
            isCancelled: Task.isCancelled,
            nextEpisode: queuedNextEpisode
        ) {
        case .finishUnavailable:
            applyAutoPlayNextPromptState(
                PlayerAutoplayNextPolicy.stateAfterFinishingResolution(
                    from: autoPlayNextPromptState,
                    outcome: .unavailable
                )
            )
            autoPlayNextResolveTask = nil
            return
        case .proceed(let queuedEpisode):
            nextEpisode = queuedEpisode
            isShowingAutoPlayNextPrompt = true
            playbackMessage = PlayerViewStatePolicy.autoplayNextLoadingMessage(for: nextEpisode)
        }

        defer {
            applyAutoPlayNextPromptState(
                PlayerAutoplayNextPolicy.stateAfterFinishingResolution(
                    from: autoPlayNextPromptState,
                    outcome: PlayerViewStatePolicy.autoplayResolutionFinishOutcome(
                        hasQueuedNextEpisode: queuedNextEpisode != nil
                    )
                )
            )
            autoPlayNextResolveTask = nil
        }

        let autoPlayNext = (try? await appState.settingsManager.getBool(
            key: SettingsKeys.autoPlayNext,
            default: true
        )) ?? true
        guard !Task.isCancelled else { return }

        let resolutionPlan = PlayerAutoplayNextResolutionPolicy.resolutionPlan(
            autoPlayNextEnabled: autoPlayNext,
            nextEpisode: nextEpisode,
            currentRecoveryContext: currentStream.recoveryContext
        )

        switch resolutionPlan {
        case .disabled, .unavailable:
            return
        case .readyFromSeriesPage(let message):
            playbackMessage = message
            return
        case .resolve(let nextContext):
            do {
                let nextStream = try await appState.debridManager.resolveStream(from: nextContext)
                try Task.checkCancellation()
                persistCurrentWatchProgress()
                resetSubtitleStateForStreamTransition()
                activeEpisodeId = nextEpisode.episodeId
                activeMediaTitle = nextEpisode.title
                queuedNextEpisode = nil
                streamQueue = [nextStream]
                currentStream = nextStream
            } catch is CancellationError {
                applyAutoPlayNextPromptState(
                    PlayerAutoplayNextPolicy.stateAfterFinishingResolution(
                        from: autoPlayNextPromptState,
                        outcome: .unavailable
                    )
                )
            } catch {
                playbackMessage = PlayerViewStatePolicy.autoplayNextFailureMessage(
                    for: nextEpisode,
                    errorDescription: error.localizedDescription
                )
                applyAutoPlayNextPromptState(
                    PlayerAutoplayNextPolicy.stateAfterFinishingResolution(
                        from: autoPlayNextPromptState,
                        outcome: .failed
                    )
                )
            }
        }
    }

    private func closePlayer() {
        guard !didInitiateClose else {
            #if os(macOS) || os(visionOS)
            if PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack {
                dismissDedicatedPlayerWindow()
            } else {
                dismiss()
            }
            #else
            dismiss()
            #endif
            return
        }

        didInitiateClose = true
        RuntimeMemoryDiagnostics.capture(
            event: .playerCloseRequested,
            enabled: appState.runtimeDiagnosticsEnabled,
            context: resolvedMediaTitle
        )

        // Snapshot + persist watch progress and stop scrobbling first. Both capture the
        // engine state synchronously (cheap) and hand the DB/network work to detached
        // tasks, so they must run before the engine is torn down — but they never block.
        stopProgressPersistence()
        scrobbleStop()
        persistCurrentWatchProgress()

        // Cancel every in-flight load/prepare task so Back never waits on "loading".
        initialPlayerStateTask?.cancel()
        initialPlayerStateTask = nil
        activePreparePlaybackID = nil
        preparePlaybackTask?.cancel()
        preparePlaybackTask = nil
        subtitleCatalogTask?.cancel()
        subtitleCatalogTask = nil
        subtitleDownloadTask?.cancel()
        subtitleDownloadTask = nil
        environmentAssetsTask?.cancel()
        environmentAssetsTask = nil
        audioTrackRefreshTask?.cancel()
        audioTrackRefreshTask = nil
        subtitleTrackRefreshTask?.cancel()
        subtitleTrackRefreshTask = nil
        autoPlayNextCountdownTask?.cancel()
        autoPlayNextCountdownTask = nil
        autoPlayNextResolveTask?.cancel()
        autoPlayNextResolveTask = nil
        cancelVisionLifecycleTasksOnClose()
        controlsHideTask?.cancel()
        controlsHideTask = nil

        // Silence playback immediately so Back stops sound the instant it is tapped,
        // without waiting for the heavier coordinator/session teardown below.
        avPlayer?.pause()
        #if os(visionOS)
        apmpInjector.stop()
        isAPMPActive = false
        #endif

        #if os(visionOS)
        // Surface the app page and close the player window *before* tearing down the
        // player. The heavy cleanupPlayback() (KSPlayer/AVPlayer release) is deferred to
        // the next main-actor tick so it can never block the Back transition; onDisappear
        // also runs cleanupPlayback() as a safety net and it is idempotent + sessionID-guarded.
        if PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack {
            scheduleMainWindowRestoreIfNeeded()
            dismissDedicatedPlayerWindow()
        }
        if PlayerLifecyclePolicy.dismissesCurrentPresentationOnBack {
            dismiss()
        }
        scheduleImmersiveDismiss(reason: .playerClosed, restoresMainWindow: true)
        Task { @MainActor in
            cleanupPlayback(clearSession: true)
        }
        #elseif os(macOS)
        cleanupPlayback(clearSession: true)
        if PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack {
            dismissDedicatedPlayerWindow()
        } else {
            dismiss()
        }
        #else
        cleanupPlayback(clearSession: true)
        dismiss()
        #endif
    }

    #if os(macOS) || os(visionOS)
    private func dismissDedicatedPlayerWindow() {
        if let sessionRequest {
            dismissWindow(id: "player", value: sessionRequest)
        }
        dismissWindow(id: "player")
    }
    #endif

    @MainActor
    private func retryPlayback() {
        startPlaybackPreparation(for: currentStream)
    }

    private func toggleControlsVisibility() {
        switch PlayerViewStatePolicy.controlsToggleAction(
            isControlModalPresented: isControlModalPresented,
            isShowingControls: isShowingControls
        ) {
        case .keepVisibleForPresentedModal:
            keepControlsVisibleForMenuAction()
            return
        case .showAndScheduleHide:
            performOptionalAnimation(.easeInOut(duration: PlayerControlVisibilityPolicy.fadeInDuration)) {
                isShowingControls = true
            }
            scheduleControlsHide()
        case .hideAndCancelScheduledHide:
            performOptionalAnimation(.easeInOut(duration: PlayerControlVisibilityPolicy.fadeOutDuration)) {
                isShowingControls = false
            }
            controlsHideTask?.cancel()
            controlsHideTask = nil
        }
    }

    private func toggleControlsLock() {
        isControlsLocked.toggle()
        if isControlsLocked {
            controlsHideTask?.cancel()
            controlsHideTask = nil
            if !isShowingControls {
                isShowingControls = true
            }
        } else if isShowingControls, isControlModalPresented == false {
            scheduleControlsHide()
        }
    }

    private func presentSubtitlePicker() {
        prepareForControlModalPresentation()
        isShowingSubtitlePicker = true
    }

    private func presentAudioPicker() {
        prepareForControlModalPresentation()
        isShowingAudioPicker = true
    }

    private func refreshCurrentMediaTrackOptions() {
        switch PlayerViewStatePolicy.trackRefreshRoute(
            activeEngine: activeEngine,
            hasAVPlayer: avPlayer != nil,
            hasKSPlayerCoordinator: ksPlayerCoordinator != nil
        ) {
        case .avPlayer:
            guard let avPlayer else { return }
            let streamID = currentStream.id
            avMediaOptionRefreshTask?.cancel()
            avMediaOptionRefreshTask = Task { @MainActor in
                guard !Task.isCancelled,
                      Self.audioTrackRefreshShouldRun(
                          requestedStreamID: streamID,
                          currentStreamID: currentStream.id
                      ) else {
                    return
                }
                await refreshAVMediaOptions(for: avPlayer)
            }
        case .ksPlayer:
            guard let coordinator = ksPlayerCoordinator else { return }
            refreshKSAudioTracks(from: coordinator)
            refreshKSSubtitleTracks(from: coordinator)
        case .none:
            break
        }
    }

    private func prepareForControlModalPresentation() {
        controlsHideTask?.cancel()
        controlsHideTask = nil
        guard PlayerViewStatePolicy.shouldShowControlsForModalPresentation(
            isShowingControls: isShowingControls
        ) else { return }
        performOptionalAnimation(.easeInOut(duration: PlayerControlVisibilityPolicy.fadeInDuration)) {
            isShowingControls = true
        }
    }

    private func handleControlModalVisibilityChange(isPresented: Bool) {
        switch PlayerViewStatePolicy.controlModalVisibilityAction(isPresented: isPresented) {
        case .prepareForPresentation:
            prepareForControlModalPresentation()
        case .scheduleHide:
            scheduleControlsHide()
        }
    }

    private func keepControlsVisibleForMenuAction() {
        prepareForControlModalPresentation()
        scheduleControlsHide()
    }

    private var isControlModalPresented: Bool {
        #if os(visionOS)
        let immersiveFlags = PlayerViewStatePolicy.immersiveControlModalFlags(
            includesImmersiveControls: true,
            isShowingEnvironmentPicker: isShowingEnvironmentPicker,
            isShowingCinemaSettings: isShowingCinemaSettings
        )
        #else
        let immersiveFlags = PlayerViewStatePolicy.immersiveControlModalFlags(
            includesImmersiveControls: false,
            isShowingEnvironmentPicker: false,
            isShowingCinemaSettings: false
        )
        #endif
        return PlayerViewPolicy.isControlModalPresented(
            isShowingSubtitlePicker: isShowingSubtitlePicker,
            isShowingAudioPicker: isShowingAudioPicker,
            isShowingEnvironmentPicker: immersiveFlags.isShowingEnvironmentPicker,
            isShowingCinemaSettings: immersiveFlags.isShowingCinemaSettings
        )
    }

    private func loadInitialPlayerState() async {
        guard !Task.isCancelled else { return }
        streamQueue = await PlayerSessionRouting.playbackQueue(
            primary: currentStream,
            available: availableStreams
        )
        engine.currentTitle = resolvedMediaTitle
        evaluateCapabilities(for: currentStream)
        await loadEnvironmentAssets()
        guard !Task.isCancelled else { return }
        startProgressPersistence()
        await loadSubtitleAppearance()
        let catalogMutationID = UUID()
        subtitleCatalogMutationID = catalogMutationID
        await refreshSubtitleCatalog(
            for: currentStream,
            requestedStreamID: currentStream.id,
            mutationID: catalogMutationID
        )
        guard !Task.isCancelled else { return }
        await autoLoadSubtitlesIfEnabled(for: currentStream)
        guard !Task.isCancelled else { return }
        scheduleControlsHide()
        #if os(visionOS)
        await loadDimPassthroughPreference()
        await autoOpenEnvironmentIfNeeded()
        #endif
    }

    @MainActor
    private func startPlaybackPreparation(for stream: StreamInfo) {
        let preparationID = UUID()
        activePreparePlaybackID = preparationID
        preparePlaybackTask?.cancel()
        preparePlaybackTask = Task { await preparePlayback(for: stream, preparationID: preparationID) }
    }

    @MainActor
    private func refreshedStartupStreamIfNeeded(
        after error: Error,
        for stream: StreamInfo
    ) async -> StreamInfo? {
        let attemptKey = PlayerStreamLinkRecovery.attemptTrackingKey(for: stream)
        let priorRefreshAttempts = startupRefreshAttempts[attemptKey] ?? 0
        guard PlayerStartupFailurePolicy.shouldSkipRemainingEnginesAndRefreshCurrentStream(
            after: error,
            stream: stream,
            priorRefreshAttempts: priorRefreshAttempts
        ) else {
            return nil
        }

        guard let refreshPlan = PlayerStreamLinkRecovery.refreshPlan(
            for: stream,
            priorAttempts: priorRefreshAttempts
        ) else {
            return nil
        }

        startupRefreshAttempts[attemptKey] = priorRefreshAttempts + 1

        do {
            switch refreshPlan {
            case .replace(let replacement):
                return replacement
            case .reResolve(let context):
                return try await appState.debridManager.resolveStream(from: context)
            }
        } catch {
            playbackMessage = "Refreshing stream link failed."
            return nil
        }
    }

    @MainActor
    private func queueWithRefreshedPrimary(_ refreshedStream: StreamInfo, replacing staleStream: StreamInfo) -> [StreamInfo] {
        PlayerStreamRefreshPolicy.queueWithRefreshedPrimary(
            refreshedStream: refreshedStream,
            staleStream: staleStream,
            streamQueue: streamQueue
        )
    }

    #if os(visionOS)
    private func loadDimPassthroughPreference() async {
        engine.isDimEnabled = (try? await appState.settingsManager.getBool(
            key: SettingsKeys.playerDimPassthrough,
            default: true
        )) ?? true
    }
    #endif

    #if os(visionOS)
    private func autoOpenEnvironmentIfNeeded() async {
        let autoOpen = (try? await appState.settingsManager.getBool(
            key: SettingsKeys.autoOpenEnvironment, default: true
        )) ?? true
        guard autoOpen else { return }
        guard let asset = appState.selectedEnvironmentAsset else { return }
        guard !appState.isImmersiveSpaceOpen else { return }
        guard !appState.isImmersiveTransitionInFlight else { return }
        await openImmersiveSpaceIfPossible(for: asset)
    }
    #endif

    @MainActor
    private func preparePlayback(for stream: StreamInfo, preparationID: UUID) async {
        defer {
            if Self.preparePlaybackShouldRun(
                requestedPreparationID: preparationID,
                activePreparationID: activePreparePlaybackID
            ) {
                activePreparePlaybackID = nil
            }
        }

        guard Self.preparePlaybackShouldRun(
            requestedPreparationID: preparationID,
            activePreparationID: activePreparePlaybackID
        ) else {
            return
        }

        RuntimeMemoryDiagnostics.capture(
            event: .playerPrepareStarted,
            enabled: appState.runtimeDiagnosticsEnabled,
            context: stream.fileName
        )

        playbackState = .preparing
        playbackError = nil
        playbackMessage = PlayerViewStatePolicy.preparationStartMessage()
        isShowingControls = true
        hasPlayedOnce = false
        // New stream/episode: re-arm the one-shot completion save and drop the previous
        // episode's captured frame so it isn't reused for this one.
        didPersistCompletion = false
        lastFrameImagePath = nil
        lastFrameCaptureAt = nil
        guard Self.preparePlaybackShouldRun(
            requestedPreparationID: preparationID,
            activePreparationID: activePreparePlaybackID
        ), !Task.isCancelled else {
            return
        }
        cleanupPlayback(clearSession: false)
        engine.currentTitle = PlayerViewStatePolicy.currentTitle(
            mediaTitle: activeMediaTitle,
            streamFileName: stream.fileName
        )
        engine.currentTime = 0
        engine.duration = 0
        engine.bufferedPercent = 0
        detectedVideoRatio = nil
        didAttemptVideoRatioDetection = false
        didAttemptHDRMetadataExtraction = false
        engine.updateStereoMode(
            from: resolvedMediaTitleFrom(activeMediaTitle: activeMediaTitle, streamFileName: stream.fileName),
            codecHint: stream.codec.rawValue
        )
        evaluateCapabilities(for: stream)

        // Re-activate the audio session before playback — the session from
        // app init may not survive window transitions on visionOS.
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let resumeTarget = await loadResumeTarget()
        guard Self.preparePlaybackShouldRun(
            requestedPreparationID: preparationID,
            activePreparationID: activePreparePlaybackID
        ), !Task.isCancelled else {
            return
        }
        let engineStrategy = await loadPlayerEngineStrategy()
        guard Self.preparePlaybackShouldRun(
            requestedPreparationID: preparationID,
            activePreparationID: activePreparePlaybackID
        ), !Task.isCancelled else {
            return
        }

        let orderedEngines = playerEngineSelector.engineOrder(for: stream, strategy: engineStrategy)
        var failures: [String] = []

        for kind in orderedEngines {
            guard Self.preparePlaybackShouldRun(
                requestedPreparationID: preparationID,
                activePreparationID: activePreparePlaybackID
            ), !Task.isCancelled else {
                return
            }

            do {
                switch kind {
                case .ksPlayer:
                    let prepared = try await ksPlayerEngine.prepare(stream: stream)
                    try Task.checkCancellation()
                    guard Self.preparePlaybackShouldRun(
                        requestedPreparationID: preparationID,
                        activePreparationID: activePreparePlaybackID
                    ) else {
                        return
                    }
                    guard let coordinator = prepared.ksPlayerCoordinator,
                          let options = prepared.ksOptions else {
                        throw PlayerEngineError.initializationFailed(.ksPlayer, "Missing player coordinator.")
                    }

                    // Honor the user's hardware decoding preference from Settings.
                    let hwDecode = (try? await appState.settingsManager.getBool(
                        key: SettingsKeys.hardwareDecoding, default: true
                    )) ?? true
                    try Task.checkCancellation()
                    options.hardwareDecode = hwDecode

                    configureKSCallbacks(coordinator)
                    activeEngine = .ksPlayer
                    ksPlayerCoordinator = coordinator
                    applyAspectRatioPresentationMode()
                    ksOptions = options
                    avPlayer = nil
                    avAudioOptions = []
                    avSubtitleOptions = []
                    avAudioGroup = nil
                    avSubtitleGroup = nil
                    selectedAVAudioID = nil
                    selectedAVSubtitleID = nil
                    ksSubtitleOptions = []
                    selectedKSSubtitleID = nil
                    hydrateFallbackAudioTrack(for: stream)
                    playbackState = .preparing
                    playbackMessage = PlayerViewStatePolicy.preparationAttemptMessage(for: .ksPlayer)

                    try await Task.sleep(for: .milliseconds(140))
                    try Task.checkCancellation()
                    try await KSPlayerEngine.waitUntilReady(
                        coordinator: coordinator,
                        timeout: KSPlayerEngine.timeout(for: stream),
                        onState: { state, diagnostics in
                            guard Self.preparePlaybackShouldRun(
                                requestedPreparationID: preparationID,
                                activePreparationID: activePreparePlaybackID
                            ) else {
                                return
                            }
                            playbackState = state
                            playbackMessage = diagnostics
                        },
                        failureMessage: { playbackError }
                    )
                    try Task.checkCancellation()
                    guard Self.preparePlaybackShouldRun(
                        requestedPreparationID: preparationID,
                        activePreparationID: activePreparePlaybackID
                    ) else {
                        return
                    }
                    refreshKSAudioTracks(for: stream)
                    refreshKSSubtitleTracks(for: stream)

                    if let resumeTarget {
                        coordinator.seek(time: resumeTarget)
                        engine.currentTime = resumeTarget
                        playbackMessage = PlayerViewStatePolicy.preparationResumeMessage(for: resumeTarget)
                    }

                    coordinator.playerLayer?.player.playbackRate = engine.playbackRate
                    coordinator.playerLayer?.play()
                    playbackState = .playing
                    playbackMessage = PlayerViewStatePolicy.preparationSuccessMessage(
                        for: .ksPlayer,
                        didResume: resumeTarget != nil
                    )
                    refreshKSAudioTracks(from: coordinator)
                    refreshKSSubtitleTracks(from: coordinator)
                    scheduleKSTrackRefresh(for: stream)
                    await autoLoadSubtitlesIfEnabled(for: stream)
                    try Task.checkCancellation()
                    scheduleControlsHide()
                    RuntimeMemoryDiagnostics.capture(
                        event: .playerPrepareSucceeded,
                        enabled: appState.runtimeDiagnosticsEnabled,
                        context: "ksplayer:\(stream.fileName)"
                    )
                    return

                case .avPlayer:
                    let prepared: PreparedPlaybackSession
                    if let prepareAVPlayerSessionOverride {
                        prepared = try await prepareAVPlayerSessionOverride(stream)
                    } else {
                        prepared = try await avPlayerEngine.prepare(stream: stream)
                    }
                    try Task.checkCancellation()
                    guard Self.preparePlaybackShouldRun(
                        requestedPreparationID: preparationID,
                        activePreparationID: activePreparePlaybackID
                    ) else {
                        return
                    }
                    guard let player = prepared.avPlayer else {
                        throw PlayerEngineError.initializationFailed(.avPlayer, "Missing AVPlayer session.")
                    }

                    activeEngine = .avPlayer
                    ksPlayerCoordinator = nil
                    ksOptions = nil
                    ksSubtitleOptions = []
                    selectedKSSubtitleID = nil
                    avPlayer = player
                    appState.activeAVPlayer = player
                    playbackState = .preparing
                    playbackMessage = PlayerViewStatePolicy.preparationAttemptMessage(for: .avPlayer)

                    startObservingAVPlayer(player)
                    #if os(visionOS)
                    updateAPMPInjector()
                    #endif
                    player.playImmediately(atRate: PlayerViewStatePolicy.playbackStartRate(engine.playbackRate))

                    let onState: (PlayerPlaybackState, String?) -> Void = { state, diagnostics in
                        guard Self.preparePlaybackShouldRun(
                            requestedPreparationID: preparationID,
                            activePreparationID: activePreparePlaybackID
                        ) else {
                            return
                        }
                        playbackState = state
                        playbackMessage = diagnostics
                    }
                    if let waitUntilAVPlayerReadyOverride {
                        try await waitUntilAVPlayerReadyOverride(player, onState)
                    } else {
                        try await AVPlayerEngine.waitUntilReady(
                            player: player,
                            onState: onState
                        )
                    }
                    try Task.checkCancellation()
                    guard Self.preparePlaybackShouldRun(
                        requestedPreparationID: preparationID,
                        activePreparationID: activePreparePlaybackID
                    ) else {
                        return
                    }

                    await refreshAVMediaOptions(for: player)
                    try Task.checkCancellation()
                    // Torrent/direct streams may not expose audio tracks immediately.
                    // Refresh again after the stream has had time to load track metadata.
                    let streamID = stream.id
                    audioTrackRefreshTask?.cancel()
                    audioTrackRefreshTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(2000))
                        guard !Task.isCancelled,
                              Self.audioTrackRefreshShouldRun(
                                  requestedStreamID: streamID,
                                  currentStreamID: currentStream.id
                              ) else {
                            return
                        }
                        await refreshAVMediaOptions(for: player)
                    }
                    try Task.checkCancellation()
                    await loadChapters(from: player)
                    try Task.checkCancellation()
                    if let resumeTarget {
                        await seekAVPlayer(player, to: resumeTarget)
                        try Task.checkCancellation()
                        engine.currentTime = resumeTarget
                        playbackMessage = PlayerViewStatePolicy.preparationResumeMessage(for: resumeTarget)
                    }
                    player.playImmediately(atRate: PlayerViewStatePolicy.playbackStartRate(engine.playbackRate))

                    playbackState = .playing
                    playbackMessage = PlayerViewStatePolicy.preparationSuccessMessage(
                        for: .avPlayer,
                        didResume: resumeTarget != nil
                    )
                    await autoLoadSubtitlesIfEnabled(for: stream)
                    try Task.checkCancellation()
                    scheduleControlsHide()
                    RuntimeMemoryDiagnostics.capture(
                        event: .playerPrepareSucceeded,
                        enabled: appState.runtimeDiagnosticsEnabled,
                        context: "avplayer:\(stream.fileName)"
                    )
                    return
                }
            } catch is CancellationError {
                guard Self.preparePlaybackShouldRun(
                    requestedPreparationID: preparationID,
                    activePreparationID: activePreparePlaybackID
                ) else {
                    return
                }
                cleanupPlayback(clearSession: false)
                return
            } catch {
                guard Self.preparePlaybackShouldRun(
                    requestedPreparationID: preparationID,
                    activePreparationID: activePreparePlaybackID
                ) else {
                    return
                }
                if let refreshedStream = await refreshedStartupStreamIfNeeded(after: error, for: stream) {
                    guard Self.preparePlaybackShouldRun(
                        requestedPreparationID: preparationID,
                        activePreparationID: activePreparePlaybackID
                    ) else {
                        return
                    }
                    currentStream = refreshedStream
                    streamQueue = queueWithRefreshedPrimary(refreshedStream, replacing: stream)
                    playbackMessage = "Refreshing stream link..."
                    startPlaybackPreparation(for: refreshedStream)
                    return
                }
                failures.append(
                    PlayerViewStatePolicy.preparationFailureLine(
                        kind: kind,
                        errorDescription: error.localizedDescription
                    )
                )
                cleanupPlayback(clearSession: false)
            }
        }

        guard Self.preparePlaybackShouldRun(
            requestedPreparationID: preparationID,
            activePreparationID: activePreparePlaybackID
        ) else {
            return
        }
        playbackState = .failed
        activeEngine = nil
        let reason = PlayerViewStatePolicy.preparationFailureReason(failures: failures)
        playbackError = reason
        playbackMessage = "Use retry or try the next stream."
        RuntimeMemoryDiagnostics.capture(
            event: .playerPrepareFailed,
            enabled: appState.runtimeDiagnosticsEnabled,
            context: "failures=\(failures.count)"
        )
    }

    nonisolated static func audioTrackRefreshShouldRun(requestedStreamID: String, currentStreamID: String?) -> Bool {
        PlayerViewPolicy.audioTrackRefreshShouldRun(
            requestedStreamID: requestedStreamID,
            currentStreamID: currentStreamID
        )
    }

    nonisolated static func preparePlaybackShouldRun(requestedPreparationID: UUID, activePreparationID: UUID?) -> Bool {
        PlayerViewPolicy.preparePlaybackShouldRun(
            requestedPreparationID: requestedPreparationID,
            activePreparationID: activePreparationID
        )
    }

    private func isCurrentAVPlayer(_ player: AVPlayer) -> Bool {
        activeEngine == .avPlayer && avPlayer === player
    }

    private func isCurrentKSPlayerCoordinator(_ coordinator: KSVideoPlayer.Coordinator) -> Bool {
        activeEngine == .ksPlayer && ksPlayerCoordinator === coordinator
    }

    private func removeAVTimeObserverIfNeeded() {
        guard let token = timeObserverToken else { return }
        if let player = timeObserverPlayer {
            if let avTimeObserverHooks {
                avTimeObserverHooks.removeTimeObserver(player, token)
            } else {
                player.removeTimeObserver(token)
            }
        }
        timeObserverToken = nil
        timeObserverPlayer = nil
    }

    private func configureKSCallbacks(_ coordinator: KSVideoPlayer.Coordinator) {
        coordinator.onStateChanged = { playerLayer, state in
            Task { @MainActor in
                guard self.isCurrentKSPlayerCoordinator(coordinator) else { return }
                switch state {
                case .initialized, .preparing:
                    playbackState = .preparing
                    engine.isBuffering = true
                    engine.isPlaying = false
                case .readyToPlay, .buffering:
                    playbackState = .buffering
                    engine.isBuffering = true
                    engine.isPlaying = false
                    refreshKSAudioTracks(from: coordinator)
                    refreshKSSubtitleTracks(from: coordinator)
                    // Detect video ratio from KSPlayer once ready
                    if detectedVideoRatio == nil {
                        let size = playerLayer.player.naturalSize
                        if let ratio = PlayerAspectRatioPolicy.ratio(from: size) {
                            detectedVideoRatio = ratio
                            engine.videoSize = size
                        }
                    }
                case .bufferFinished:
                    playbackState = .playing
                    engine.isBuffering = false
                    engine.isPlaying = true
                    refreshKSAudioTracks(from: coordinator)
                    refreshKSSubtitleTracks(from: coordinator)
                    // Fallback: detect if not yet captured at readyToPlay
                    if detectedVideoRatio == nil {
                        let size = playerLayer.player.naturalSize
                        if let ratio = PlayerAspectRatioPolicy.ratio(from: size) {
                            detectedVideoRatio = ratio
                            engine.videoSize = size
                        }
                    }
                case .paused:
                    engine.isPlaying = false
                    engine.isBuffering = false
                case .playedToTheEnd:
                    engine.isPlaying = false
                    engine.isBuffering = false
                case .error:
                    playbackState = .failed
                    engine.isPlaying = false
                    engine.isBuffering = false
                }
            }
        }

        coordinator.onPlay = { currentTime, totalTime in
            Task { @MainActor in
                guard self.isCurrentKSPlayerCoordinator(coordinator) else { return }
                let newTime = max(0, currentTime)
                // Only write to @Observable properties when the value has actually
                // changed by a perceptible amount. This prevents KSPlayer's high-
                // frequency onPlay callbacks from flooding the observation system
                // and causing PlayerView.body to re-evaluate (and the transport
                // controls tree to re-diff) on every callback -- which caused
                // audio/video lag when the environment Menu was open.
                if abs(engine.currentTime - newTime) >= 0.25 {
                    engine.currentTime = newTime
                    engine.updateSubtitleText(at: newTime)
                }
                let newDuration = max(0, totalTime)
                if abs(engine.duration - newDuration) > 1.0 {
                    engine.duration = newDuration
                }
                handlePlaybackProgressForAutoplay(currentTime: newTime, duration: newDuration)
                persistCompletionIfCrossedThreshold(currentTime: newTime, duration: newDuration)
            }
        }

        coordinator.onFinish = { _, error in
            Task { @MainActor in
                guard self.isCurrentKSPlayerCoordinator(coordinator) else { return }
                if let error {
                    playbackState = .failed
                    playbackError = error.localizedDescription
                    playbackMessage = "This stream failed during playback."
                }
            }
        }
    }

    private func startObservingAVPlayer(_ player: AVPlayer) {
        removeAVTimeObserverIfNeeded()
        videoRatioDetectionTask?.cancel()
        videoRatioDetectionTask = nil
        hdrMetadataExtractionTask?.cancel()
        hdrMetadataExtractionTask = nil

        let interval = CMTime(
            seconds: Self.avPlayerPeriodicObserverIntervalSeconds,
            preferredTimescale: 600
        )
        let observer: @Sendable (CMTime) -> Void = { time in
            Task { @MainActor in
                guard self.isCurrentAVPlayer(player) else { return }
                let seconds = time.seconds
                let newTime = seconds.isFinite ? max(0, seconds) : 0
                if abs(engine.currentTime - newTime) >= Self.avPlayerPeriodicObserverIntervalSeconds {
                    engine.currentTime = newTime
                }
                if PlayerViewPolicy.subtitleTextRefreshShouldRun(
                    selectedSubtitleTrack: engine.selectedSubtitleTrack,
                    currentSubtitleText: engine.currentSubtitleText
                ) {
                    engine.updateSubtitleText(at: newTime)
                }

                if let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0,
                   engine.duration != duration {
                    engine.duration = duration
                }
                handlePlaybackProgressForAutoplay(currentTime: newTime, duration: engine.duration)
                persistCompletionIfCrossedThreshold(currentTime: newTime, duration: engine.duration)

                // Trigger async video size detection once
                if detectedVideoRatio == nil, let asset = player.currentItem?.asset {
                    scheduleAVVideoRatioDetection(from: asset, player: player)
                }

                // Extract HDR mastering-display metadata once
                if engine.hdrMetadata == nil, let asset = player.currentItem?.asset {
                    scheduleAVHDRMetadataExtraction(from: asset, player: player)
                }

                // Buffered range
                if let loadedRange = player.currentItem?.loadedTimeRanges.first?.timeRangeValue,
                   let itemDuration = player.currentItem?.duration.seconds,
                   let newBuffered = PlayerViewPolicy.bufferedPercent(
                    loadedRangeStart: loadedRange.start.seconds,
                    loadedRangeDuration: loadedRange.duration.seconds,
                    itemDuration: itemDuration
                   ) {
                    if abs(engine.bufferedPercent - newBuffered) > 0.01 {
                        engine.bufferedPercent = newBuffered
                    }
                }

                let nowPlaying = player.timeControlStatus == .playing
                let nowBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                if engine.isPlaying != nowPlaying { engine.isPlaying = nowPlaying }
                if engine.isBuffering != nowBuffering { engine.isBuffering = nowBuffering }
                if nowPlaying && playbackState != .playing {
                    playbackState = .playing
                } else if nowBuffering && playbackState != .buffering {
                    playbackState = .buffering
                }
            }
        }
        if let avTimeObserverHooks {
            timeObserverToken = avTimeObserverHooks.addPeriodicTimeObserver(player, interval, observer)
        } else {
            timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main, using: observer)
        }
        timeObserverPlayer = player
    }

    static let avPlayerPeriodicObserverIntervalSeconds: TimeInterval = PlayerViewPolicy.avPlayerPeriodicObserverIntervalSeconds

    @MainActor
    private func detectVideoRatio(from asset: AVAsset, player: AVPlayer) async {
        guard !Task.isCancelled, isCurrentAVPlayer(player), detectedVideoRatio == nil else { return }
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard !Task.isCancelled else { return }
            guard let videoTrack = tracks.first else { return }
            let naturalSize = try await videoTrack.load(.naturalSize)
            guard !Task.isCancelled else { return }
            let transform = try await videoTrack.load(.preferredTransform)
            let size = naturalSize.applying(transform)
            let absSize = CGSize(width: abs(size.width), height: abs(size.height))
            guard !Task.isCancelled, isCurrentAVPlayer(player), detectedVideoRatio == nil else { return }
            if let ratio = PlayerAspectRatioPolicy.ratio(from: absSize) {
                detectedVideoRatio = ratio
                engine.videoSize = absSize
            }
        } catch {
            // Video track unavailable; ratio stays nil and 16:9 fallback is used
        }
    }

    @MainActor
    private func scheduleAVVideoRatioDetection(from asset: AVAsset, player: AVPlayer) {
        guard detectedVideoRatio == nil,
              !didAttemptVideoRatioDetection,
              videoRatioDetectionTask == nil else {
            return
        }
        didAttemptVideoRatioDetection = true
        videoRatioDetectionTask = Task { @MainActor in
            defer {
                if self.isCurrentAVPlayer(player) {
                    videoRatioDetectionTask = nil
                }
            }
            guard !Task.isCancelled, self.isCurrentAVPlayer(player) else { return }
            await detectVideoRatio(from: asset, player: player)
        }
    }

    @MainActor
    private func scheduleAVHDRMetadataExtraction(from asset: AVAsset, player: AVPlayer) {
        guard engine.hdrMetadata == nil,
              !didAttemptHDRMetadataExtraction,
              hdrMetadataExtractionTask == nil else {
            return
        }
        didAttemptHDRMetadataExtraction = true
        hdrMetadataExtractionTask = Task { @MainActor in
            defer {
                if self.isCurrentAVPlayer(player) {
                    hdrMetadataExtractionTask = nil
                }
            }
            guard !Task.isCancelled,
                  self.isCurrentAVPlayer(player),
                  engine.hdrMetadata == nil else {
                return
            }
            let metadata = await HDRMetadataExtractor.extract(from: asset)
            guard !Task.isCancelled,
                  self.isCurrentAVPlayer(player),
                  engine.hdrMetadata == nil else {
                return
            }
            engine.hdrMetadata = metadata
        }
    }

    private func seekTo(percent: Double) {
        let target = PlayerViewPolicy.clampedSeekTarget(percent: percent, duration: engine.duration)
        seek(to: target)
    }

    private func seekRelative(_ offset: TimeInterval) {
        let target = PlayerViewPolicy.clampedSeekTarget(
            currentTime: engine.currentTime,
            offset: offset,
            duration: engine.duration
        )
        seek(to: target)
    }

    private var scrubberAccessibilityValue: String {
        PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: engine.currentTime,
            duration: engine.duration,
            isScrubbing: isScrubbing,
            scrubTime: scrubTime
        )
    }

    private func adjustScrubberAccessibility(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment:
            seekRelative(TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
        case .decrement:
            seekRelative(-TimeInterval(PlayerCinematicChromePolicy.skipBackInterval))
        default:
            break
        }
    }

    private func seek(to time: TimeInterval) {
        let target = PlayerViewPolicy.clampedSeekTarget(time: time, duration: engine.duration)
        engine.currentTime = target
        engine.updateSubtitleText(at: target)

        switch activeEngine {
        case .ksPlayer:
            ksPlayerCoordinator?.seek(time: target)
        case .avPlayer:
            avPlayer?.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        default:
            break
        }
    }

    private func togglePlayPause() {
        switch activeEngine {
        case .ksPlayer:
            guard let layer = ksPlayerCoordinator?.playerLayer else { return }
            if layer.state.isPlaying {
                layer.pause()
                engine.isPlaying = false
            } else {
                layer.player.playbackRate = engine.playbackRate
                layer.play()
                engine.isPlaying = true
            }

        case .avPlayer:
            guard let avPlayer else { return }
            if avPlayer.timeControlStatus == .playing || avPlayer.rate > 0 {
                avPlayer.pause()
                engine.isPlaying = false
            } else {
                avPlayer.playImmediately(atRate: engine.playbackRate)
                engine.isPlaying = true
            }

        default:
            break
        }

        if engine.isPlaying {
            scrobbleResume()
        } else {
            scrobblePause()
        }
        scheduleControlsHide()
    }

    private func cyclePlaybackRate() {
        engine.cycleRate()
        switch activeEngine {
        case .ksPlayer:
            ksPlayerCoordinator?.playerLayer?.player.playbackRate = engine.playbackRate
        case .avPlayer:
            if isCurrentlyPlaying {
                avPlayer?.playImmediately(atRate: engine.playbackRate)
            }
        default:
            break
        }
    }

    private func cleanupPlayback(clearSession: Bool = true) {
        resetAutoPlayNextStateForStreamTransition()

        removeAVTimeObserverIfNeeded()

        #if os(visionOS)
        apmpInjector.stop()
        isAPMPActive = false
        #endif

        avPlayer?.pause()
        avPlayer = nil
        appState.releasePlayerResources(clearSession: clearSession, sessionID: sessionID)

        ksPlayerCoordinator?.onStateChanged = nil
        ksPlayerCoordinator?.onPlay = nil
        ksPlayerCoordinator?.onFinish = nil
        avMediaOptionRefreshTask?.cancel()
        avMediaOptionRefreshTask = nil
        audioTrackRefreshTask?.cancel()
        audioTrackRefreshTask = nil
        subtitleTrackRefreshTask?.cancel()
        subtitleTrackRefreshTask = nil
        videoRatioDetectionTask?.cancel()
        videoRatioDetectionTask = nil
        hdrMetadataExtractionTask?.cancel()
        hdrMetadataExtractionTask = nil
        didAttemptVideoRatioDetection = false
        didAttemptHDRMetadataExtraction = false

        clearKSSubtitleSelection()
        ksPlayerCoordinator?.resetPlayer()
        ksPlayerCoordinator = nil
        ksOptions = nil
        avAudioOptions = []
        avSubtitleOptions = []
        ksSubtitleOptions = []
        avAudioGroup = nil
        avSubtitleGroup = nil
        selectedAVAudioID = nil
        selectedAVSubtitleID = nil
        selectedKSSubtitleID = nil
        subtitleCatalogTask?.cancel()
        subtitleCatalogTask = nil
        subtitleDownloadTask?.cancel()
        subtitleDownloadTask = nil
        subtitleService = nil
        subtitleServiceAPIKey = nil
        engine.resetSessionState()

        if clearSession {
            activeEngine = nil
        }

        engine.isPlaying = false
        engine.isBuffering = false
        clearTransientSubtitleState(removeDownloadedFile: clearSession)
    }

    // MARK: - Scrobbling

    private var scrobbleProgress: Double {
        PlayerViewPolicy.scrobbleProgressPercent(
            currentTime: engine.currentTime,
            duration: engine.duration
        )
    }

    private func scrobbleStart() {
        guard let mediaId, mediaId.hasPrefix("tt") else { return }
        let progress = scrobbleProgress
        let type: MediaType = activeEpisodeId != nil ? .series : .movie
        scrobbleTask?.cancel()
        let currentEpisodeID = activeEpisodeId
        scrobbleTask = Task {
            await appState.scrobbleCoordinator.startPlayback(
                mediaId: mediaId,
                mediaType: type,
                progress: progress,
                episodeId: currentEpisodeID
            )
        }
    }

    private func scrobblePause() {
        guard let mediaId, mediaId.hasPrefix("tt") else { return }
        let progress = scrobbleProgress
        scrobbleTask?.cancel()
        scrobbleTask = Task { await appState.scrobbleCoordinator.pausePlayback(progress: progress) }
    }

    private func scrobbleResume() {
        guard let mediaId, mediaId.hasPrefix("tt") else { return }
        let progress = scrobbleProgress
        scrobbleTask?.cancel()
        scrobbleTask = Task { await appState.scrobbleCoordinator.resumePlayback(progress: progress) }
    }

    private func scrobbleStop() {
        guard let mediaId, mediaId.hasPrefix("tt") else { return }
        let progress = scrobbleProgress
        scrobbleTask?.cancel()
        scrobbleTask = Task { await appState.scrobbleCoordinator.stopPlayback(progress: progress) }
    }

    private func applyAspectRatioPresentationMode() {
        guard let coordinator = ksPlayerCoordinator else { return }
        coordinator.isScaleAspectFill = currentVideoGravity == .resizeAspectFill
    }

    #if os(macOS)
    private func configurePlayerWindow(_ window: NSWindow?) {
        guard let window else { return }
        window.minSize = NSSize(width: 960, height: 540)
        applyWindowAspectRatio(to: window)
    }

    private func applyWindowAspectRatio(to window: NSWindow) {
        let ratio = PlayerAspectRatioPolicy.resolvedRatio(
            for: aspectRatioSelection,
            detectedRatio: detectedVideoRatio
        )
        if let size = PlayerAspectRatioPolicy.windowAspectSize(for: ratio) {
            window.contentAspectRatio = NSSize(width: size.width, height: size.height)
        } else {
            // Freeform: unlock window aspect ratio
            window.contentAspectRatio = NSSize.zero
        }
    }

    private func resetWindowAspectRatio() {
        guard let playerWindow else { return }
        playerWindow.contentAspectRatio = NSSize.zero
    }

    private func applyStoredFullscreenPreferenceIfNeeded() {
        guard let playerWindow else { return }
        guard let sessionID else { return }
        guard !didApplyStoredFullscreen else { return }

        didApplyStoredFullscreen = true
        let preferredFullscreen = appState.fullscreenBySessionID[sessionID] ?? false
        guard preferredFullscreen else { return }

        if !playerWindow.styleMask.contains(.fullScreen) {
            playerWindow.toggleFullScreen(nil)
            isFullscreen = true
        }
    }
    #endif

    #if os(visionOS)
    private func applyVisionOSWindowGeometry() {
        // Seeded QA previews (Test Mode) render this chrome with `disablesAutomaticTasks` and share
        // the presenting window's scene — they must never request a geometry update, which would
        // resize the host window. The other automatic paths are already gated; this one is reached
        // via the window-scene accessor's onChange, so guard it here too.
        guard !disablesAutomaticTasks else { return }
        visionGeometryTask?.cancel()

        guard let windowScene = playerWindowScene else {
            visionGeometryTask = nil
            return
        }

        if !aspectRatioSelection.locksWindowRatio {
            let freeform = UIWindowScene.GeometryPreferences.Vision(
                minimumSize: CGSize(width: 640, height: 360),
                maximumSize: CGSize(width: 3840, height: 3840),
                resizingRestrictions: UIWindowScene.ResizingRestrictions.none
            )
            windowScene.requestGeometryUpdate(freeform)
            visionGeometryTask = nil
            return
        }

        let ratio = PlayerAspectRatioPolicy.resolvedRatio(
            for: aspectRatioSelection,
            detectedRatio: detectedVideoRatio
        ) ?? PlayerAspectRatioPolicy.defaultRatio
        let trackedSceneID = ObjectIdentifier(windowScene)

        visionGeometryTask = Task { @MainActor in
            guard let liveScene = playerWindowScene,
                  ObjectIdentifier(liveScene) == trackedSceneID else { return }

            let currentWidth: CGFloat
            if let window = liveScene.windows.first {
                currentWidth = max(window.frame.width, 1400)
            } else {
                currentWidth = 1400
            }
            let targetHeight = currentWidth / ratio
            let targetSize = CGSize(width: currentWidth, height: targetHeight)

            // Force the window into the selected ratio by briefly locking
            // min = max, then relax to proportional user resizing.
            let forceGeometry = UIWindowScene.GeometryPreferences.Vision(
                minimumSize: targetSize,
                maximumSize: targetSize,
                resizingRestrictions: .uniform
            )
            liveScene.requestGeometryUpdate(forceGeometry)

            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            guard let liveScene = playerWindowScene,
                  ObjectIdentifier(liveScene) == trackedSceneID else { return }

            let safeMinDim: CGFloat = 400
            let safeMaxDim: CGFloat = 3840
            let minWidth = max(640, safeMinDim * ratio)
            let minHeight = max(640 / ratio, safeMinDim)
            let maxWidth = min(safeMaxDim, safeMaxDim * ratio)
            let maxHeight = min(safeMaxDim / ratio, safeMaxDim)
            let relaxed = UIWindowScene.GeometryPreferences.Vision(
                minimumSize: CGSize(width: minWidth, height: minHeight),
                maximumSize: CGSize(width: maxWidth, height: maxHeight),
                resizingRestrictions: .uniform
            )
            liveScene.requestGeometryUpdate(relaxed)
            visionGeometryTask = nil
        }
    }
    #endif

    #if os(macOS) || os(visionOS)
    private func scheduleMainWindowSuppressionIfNeeded() {
        guard PlayerViewStatePolicy.mainWindowSuppressionAction(
            isSuppressed: appState.isMainWindowSuppressedForPlayer
        ) == .dismissMainAndMarkSuppressed else {
            return
        }
        appState.isMainWindowSuppressedForPlayer = true
        dismissWindow(id: "main")
    }

    private func scheduleMainWindowRestoreIfNeeded() {
        guard PlayerViewStatePolicy.mainWindowRestoreAction(
            isSuppressed: appState.isMainWindowSuppressedForPlayer
        ) == .openMainAndMarkRestored else {
            return
        }
        openWindow(id: "main")
        appState.isMainWindowSuppressedForPlayer = false
    }
    #endif

    #if os(visionOS)
    private func syncCinemaAspectRatio(_ ratio: CGFloat?) {
        guard let ratio, ratio.isFinite, ratio > 0 else { return }
        cinemaSettings.videoAspectRatio = Double(ratio)
    }

    private func openEnvironment(_ asset: EnvironmentAsset) async {
        let plan = PlayerImmersiveTransitionPolicy.environmentOpenPlan(
            requestedAssetID: asset.id,
            selectedAssetID: appState.selectedEnvironmentAsset?.id,
            isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
        )
        if plan == .alreadyOpen {
            return
        }
        await dismissImmersiveIfNeeded(reason: .switchingEnvironment)
        await appState.activateEnvironmentAsset(asset)
        await openImmersiveSpaceIfPossible(for: asset)
    }

    private func environmentAssetIcon(_ asset: EnvironmentAsset) -> String {
        PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: asset.assetPath)
    }

    private func openCinemaEnvironmentAfterMenuDismissal() {
        environmentMenuActionTask?.cancel()
        environmentMenuActionTask = Task { @MainActor in
            await waitForMenuDismissal()
            guard !Task.isCancelled else { return }
            await openCinemaEnvironment()
            guard !Task.isCancelled else { return }
            environmentMenuActionTask = nil
        }
    }

    private func openEnvironmentAfterMenuDismissal(_ asset: EnvironmentAsset) {
        environmentMenuActionTask?.cancel()
        environmentMenuActionTask = Task { @MainActor in
            await waitForMenuDismissal()
            guard !Task.isCancelled else { return }
            await openEnvironment(asset)
            guard !Task.isCancelled else { return }
            environmentMenuActionTask = nil
        }
    }

    private func showEnvironmentPickerAfterMenuDismissal() {
        environmentMenuActionTask?.cancel()
        environmentMenuActionTask = Task { @MainActor in
            await waitForMenuDismissal()
            guard !Task.isCancelled else { return }
            guard !isShowingEnvironmentPicker else {
                environmentMenuActionTask = nil
                return
            }
            isShowingEnvironmentPicker = true
            environmentMenuActionTask = nil
        }
    }

    private func showCinemaSettingsAfterMenuDismissal() {
        environmentMenuActionTask?.cancel()
        environmentMenuActionTask = Task { @MainActor in
            await waitForMenuDismissal()
            guard !Task.isCancelled else { return }
            guard !isShowingCinemaSettings else {
                environmentMenuActionTask = nil
                return
            }
            isShowingCinemaSettings = true
            environmentMenuActionTask = nil
        }
    }

    private func dismissEnvironmentAfterMenuDismissal() {
        environmentMenuActionTask?.cancel()
        environmentMenuActionTask = Task { @MainActor in
            await waitForMenuDismissal()
            guard !Task.isCancelled else { return }
            await dismissImmersiveIfNeeded(reason: .userInitiated)
            guard !Task.isCancelled else { return }
            environmentMenuActionTask = nil
        }
    }

    private func waitForMenuDismissal() async {
        await Task.yield()
        try? await Task.sleep(for: PlayerCinemaEnvironmentPolicy.menuDismissalDelay)
    }

    private func openCinemaEnvironment() async {
        let canOpen = PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: activeEngine, hasAVPlayer: avPlayer != nil)
        switch PlayerImmersiveTransitionPolicy.cinemaOpenPlan(
            canOpen: canOpen,
            hasAVPlayer: avPlayer != nil,
            activeEnvironment: appState.activeEnvironment,
            isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
        ) {
        case .unavailable(let message):
            playbackMessage = message
            return
        case .alreadyOpen:
            return
        case .open:
            break
        }
        guard let player = avPlayer else { return }
        appState.activeAVPlayer = player
        await dismissImmersiveIfNeeded(reason: .switchingEnvironment)
        appState.activeAVPlayer = player
        guard PlayerImmersiveTransitionPolicy.openReadiness(isTransitionInFlight: appState.isImmersiveTransitionInFlight) == .begin,
              appState.beginImmersiveTransition() else { return }
        let result = await openImmersiveSpace(id: EnvironmentType.cinemaEnvironment.immersiveSpaceId)
        let didOpen: Bool
        switch result {
        case .opened:
            didOpen = true
        case .error, .userCancelled:
            didOpen = false
        @unknown default:
            didOpen = false
        }
        if PlayerImmersiveTransitionPolicy.completionAction(didOpen: didOpen) == .enterImmersiveMode {
            appState.spatialAudioManager.enterImmersiveMode()
        } else {
            appState.cancelImmersiveTransition()
        }
    }

    private func openImmersiveSpaceIfPossible(for asset: EnvironmentAsset) async {
        guard PlayerImmersiveTransitionPolicy.openReadiness(isTransitionInFlight: appState.isImmersiveTransitionInFlight) == .begin,
              appState.beginImmersiveTransition() else { return }
        let immersiveSpaceID = await appState.environmentCatalogManager.immersiveSpaceID(for: asset)
        let result = await openImmersiveSpace(id: immersiveSpaceID)
        let didOpen: Bool
        switch result {
        case .opened:
            didOpen = true
        case .error, .userCancelled:
            didOpen = false
        @unknown default:
            didOpen = false
        }
        if PlayerImmersiveTransitionPolicy.completionAction(didOpen: didOpen) == .enterImmersiveMode {
            appState.spatialAudioManager.enterImmersiveMode()
        } else {
            appState.cancelImmersiveTransition()
        }
    }

    private func dismissImmersiveIfNeeded(reason: ImmersiveDismissReason) async {
        guard !Task.isCancelled,
              PlayerImmersiveTransitionPolicy.dismissReadiness(
            isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen,
            isTransitionInFlight: appState.isImmersiveTransitionInFlight
        ) == .begin,
              appState.beginImmersiveTransition() else { return }
        appState.stageImmersiveDismiss(reason: reason)
        appState.spatialAudioManager.exitImmersiveMode()
        await dismissImmersiveSpace()
        appState.completeImmersiveDismissIfStillPending()
    }

    private func scheduleImmersiveDismiss(reason: ImmersiveDismissReason, restoresMainWindow: Bool = false) {
        immersiveDismissTask?.cancel()
        immersiveDismissTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            await dismissImmersiveIfNeeded(reason: reason)
            guard !Task.isCancelled else { return }
            if restoresMainWindow {
                scheduleMainWindowRestoreIfNeeded()
            }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) async {
        switch phase {
        case .background:
            await dismissImmersiveIfNeeded(reason: .suspension)
        case .active:
            let selectedAsset = appState.selectedEnvironmentAsset
            let plan = PlayerImmersiveTransitionPolicy.activeRestorePlan(
                hasRestoreRequest: appState.consumeSuspendedImmersiveRestoreRequest(),
                hasSelectedAsset: selectedAsset != nil
            )
            guard plan == .openSelectedAsset, let selectedAsset else { return }
            await openImmersiveSpaceIfPossible(for: selectedAsset)
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func handleMemoryPressureWarning() async {
        switch PlayerImmersiveTransitionPolicy.memoryPressurePlan(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen) {
        case .ignore:
            return
        case .dismiss(let message, let reason):
            playbackMessage = message
            await dismissImmersiveIfNeeded(reason: reason)
        }
    }

    private func updateAPMPInjector() {
        let mode = engine.stereoMode
        guard activeEngine == .avPlayer, let player = avPlayer,
              appState.isImmersiveSpaceOpen else {
            apmpInjector.stop()
            isAPMPActive = false
            appState.activeVideoRenderer = nil
            return
        }
        switch mode {
        case .sideBySide:
            apmpInjector.start(player: player, mode: .sideBySide)
            isAPMPActive = true
            appState.activeVideoRenderer = apmpInjector.videoRenderer
        case .overUnder:
            apmpInjector.start(player: player, mode: .overUnder)
            isAPMPActive = true
            appState.activeVideoRenderer = apmpInjector.videoRenderer
        default:
            apmpInjector.stop()
            isAPMPActive = false
            appState.activeVideoRenderer = nil
        }
    }
    #endif

    private func evaluateCapabilities(for stream: StreamInfo) {
        capabilityWarnings = PlayerCapabilityEvaluator.warnings(for: stream)
    }

    private func loadEnvironmentAssets() async {
        environmentAssets = (try? await appState.environmentCatalogManager.fetchAssets()) ?? []
    }

    @MainActor
    private func requestEnvironmentPicker() {
        environmentAssetsTask?.cancel()
        #if os(visionOS)
        guard !isShowingEnvironmentPicker else {
            environmentAssetsTask = Task { await loadEnvironmentAssets() }
            return
        }
        isShowingEnvironmentPicker = true
        #endif
        environmentAssetsTask = Task { await loadEnvironmentAssets() }
    }

    private func startProgressPersistence() {
        progressPersistTask?.cancel()
        progressPersistTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                await captureLastFrameIfDue()
                await saveWatchProgress()
            }
        }
    }

    /// Captures the current video frame for the Continue Watching tile while the engine is alive.
    /// Throttled, skips stereo/3D content (a raw SBS/OU frame would look squished — the tile
    /// falls back to the backdrop in that case), and never blocks the player.
    @MainActor
    private func captureLastFrameIfDue() async {
        guard engine.stereoMode == .mono else { return }
        guard let mediaId else { return }
        if let last = lastFrameCaptureAt, Date().timeIntervalSince(last) < 28 { return }

        // Frame generation suspends the main actor; an autoplay-next transition can advance the
        // episode while we await. Pin the episode at capture start and discard the frame if it
        // changed, so we never store one episode's frame under another's key.
        let episodeIdAtCaptureStart = activeEpisodeId

        var jpeg: Data?
        switch activeEngine {
        case .avPlayer:
            if let item = avPlayer?.currentItem {
                jpeg = await FrameCaptureService.captureAVPlayerFrameJPEG(asset: item.asset, at: item.currentTime())
            }
        case .ksPlayer:
            if let image = await ksPlayerCoordinator?.playerLayer?.player.thumbnailImageAtCurrentTime() {
                jpeg = FrameCaptureService.encodeJPEG(image)
            }
        case .none:
            return
        }

        guard let data = jpeg else { return }
        guard activeEpisodeId == episodeIdAtCaptureStart else { return }
        if let path = FrameCaptureService.store(jpegData: data, mediaId: mediaId, episodeId: episodeIdAtCaptureStart) {
            lastFrameCaptureAt = Date()
            lastFrameImagePath = path
        }
    }

    private func stopProgressPersistence() {
        progressPersistTask?.cancel()
        progressPersistTask = nil
    }

    @MainActor
    private func persistCurrentWatchProgress() {
        guard let history = makeWatchProgressSnapshot() else { return }
        Task {
            do {
                try await appState.database.saveWatchHistory(history)
                await MainActor.run {
                    NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
                }
            } catch {
                return
            }
        }
    }

    /// Persists a completion snapshot once, the instant playback crosses the watched threshold,
    /// so an abrupt close before the next periodic save still records the title as watched.
    @MainActor
    private func persistCompletionIfCrossedThreshold(currentTime: TimeInterval, duration: TimeInterval) {
        guard !didPersistCompletion else { return }
        guard duration.isFinite, duration > 0, currentTime.isFinite else { return }
        guard currentTime / duration >= PlayerWatchProgressPolicy.completionThreshold else { return }
        didPersistCompletion = true
        persistCurrentWatchProgress()
    }

    @MainActor
    private func makeWatchProgressSnapshot() -> WatchHistory? {
        PlayerWatchProgressPolicy.makeSnapshot(
            mediaId: mediaId,
            episodeId: activeEpisodeId,
            mediaTitle: activeMediaTitle,
            stream: currentStream,
            currentTime: engine.currentTime,
            duration: engine.duration,
            lastFrameImagePath: lastFrameImagePath
        )
    }

    @MainActor
    private func saveWatchProgress() async {
        guard let history = makeWatchProgressSnapshot() else { return }
        do {
            try await appState.database.saveWatchHistory(history)
            NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
        } catch {
            return
        }
    }

    private func loadResumeTarget() async -> TimeInterval? {
        guard let mediaId else { return nil }
        let history = try? await appState.database.fetchWatchHistory(mediaId: mediaId, episodeId: activeEpisodeId)
        return WatchProgressResumePolicy.resumeTime(for: history)
    }

    private func loadPlayerEngineStrategy() async -> PlayerEngineStrategy {
        let raw = (try? await appState.settingsManager.getString(key: SettingsKeys.playerEngineStrategy)) ?? ""
        return PlayerViewStatePolicy.resolvedEngineStrategy(from: raw)
    }

    @MainActor
    private func seekAVPlayer(_ player: AVPlayer, to seconds: TimeInterval) async {
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                continuation.resume()
            }
        }
    }

    private func scheduleControlsHide() {
        controlsHideTask?.cancel()
        controlsHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: PlayerViewStatePolicy.autoHideDelayNanoseconds())
            guard !Task.isCancelled else { return }
            guard PlayerViewStatePolicy.shouldAutoHideControls(
                playbackState: playbackState,
                isPlaying: isCurrentlyPlaying,
                isScrubbing: isScrubbing,
                isShowingSubtitlePicker: isShowingSubtitlePicker,
                isShowingAudioPicker: isShowingAudioPicker,
                isControlsLocked: isControlsLocked,
                isShowingEnvironmentPicker: isShowingEnvironmentPickerForAutoHide,
                isShowingCinemaSettings: isShowingCinemaSettingsForAutoHide
            ) else { return }
            performOptionalAnimation(.easeInOut(duration: PlayerControlVisibilityPolicy.fadeOutDuration)) {
                isShowingControls = false
            }
            controlsHideTask = nil
        }
    }

    private var isShowingEnvironmentPickerForAutoHide: Bool {
        #if os(visionOS)
        return isShowingEnvironmentPicker
        #else
        return false
        #endif
    }

    private var isShowingCinemaSettingsForAutoHide: Bool {
        #if os(visionOS)
        return isShowingCinemaSettings
        #else
        return false
        #endif
    }

    private var resolvedMediaTitle: String {
        resolvedMediaTitleFrom(activeMediaTitle: activeMediaTitle, streamFileName: currentStream.fileName)
    }

    private func resolvedMediaTitleFrom(activeMediaTitle: String?, streamFileName: String) -> String {
        PlayerViewStatePolicy.currentTitle(
            mediaTitle: activeMediaTitle,
            streamFileName: streamFileName
        )
    }

    private func loadSubtitleAppearance() async {
        let storedSize = (try? await appState.settingsManager.getString(key: SettingsKeys.subtitleFontSize))
            .flatMap(Double.init)
        subtitleFontSize = PlayerViewPolicy.resolvedSubtitleFontSize(storedSize: storedSize)
    }

    private func performOptionalAnimation(_ animation: Animation, updates: () -> Void) {
        if motionAnimationsEnabled {
            withAnimation(animation, updates)
        } else {
            updates()
        }
    }

    private var systemClosedCaptioningEnabled: Bool {
        let mediaAccessibilityEnabled = MACaptionAppearanceGetDisplayType(.user) == .alwaysOn
        #if canImport(UIKit)
        return mediaAccessibilityEnabled || UIAccessibility.isClosedCaptioningEnabled
        #else
        return mediaAccessibilityEnabled
        #endif
    }

    private var systemPreferredCaptionLanguages: [String] {
        let captionLanguages = (MACaptionAppearanceCopySelectedLanguages(.user).takeRetainedValue() as NSArray)
            .compactMap { $0 as? String }
        if !captionLanguages.isEmpty {
            return captionLanguages
        }
        return Locale.preferredLanguages
    }

    nonisolated static func subtitleMutationShouldRun(requestedStreamID: String, currentStreamID: String?) -> Bool {
        currentStreamID == requestedStreamID
    }

    nonisolated static func subtitleMutationShouldRun(
        requestedStreamID: String,
        currentStreamID: String?,
        requestedMutationID: UUID?,
        activeMutationID: UUID?
    ) -> Bool {
        requestedMutationID != nil && currentStreamID == requestedStreamID && requestedMutationID == activeMutationID
    }

    nonisolated static func shouldAnimateForAccessibility(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    nonisolated static func automaticSubtitleLanguageCodes(
        configuredLanguageSetting: String?,
        systemPreferredLanguages: [String],
        closedCaptioningEnabled: Bool
    ) -> [String] {
        PlayerSubtitlePolicy.automaticSubtitleLanguageCodes(
            configuredLanguageSetting: configuredLanguageSetting,
            systemPreferredLanguages: systemPreferredLanguages,
            closedCaptioningEnabled: closedCaptioningEnabled
        )
    }

    private func resetSubtitleStateForStreamTransition() {
        subtitleCatalogTask?.cancel()
        subtitleCatalogTask = nil
        subtitleDownloadTask?.cancel()
        subtitleDownloadTask = nil
        subtitleTrackRefreshTask?.cancel()
        subtitleTrackRefreshTask = nil
        subtitleSelectionMode = .automaticPreferred
        clearTransientSubtitleState(removeDownloadedFile: true, clearCurrentItemSelection: true)
    }

    private func syncCurrentStreamIfNeeded(_ stream: StreamInfo) {
        guard stream != currentStream else { return }
        if stream.id != currentStream.id {
            persistCurrentWatchProgress()
            resetSubtitleStateForStreamTransition()
            resetAutoPlayNextStateForStreamTransition()
        }

        activeMediaTitle = mediaTitle
        activeEpisodeId = episodeId
        queuedNextEpisode = nextEpisode
        currentStream = stream
        streamQueue = PlayerSessionRouting.sessionStreams(primary: stream, available: availableStreams)
        playbackMessage = nil
        guard !disablesAutomaticTasks else { return }
        startPlaybackPreparation(for: stream)
    }

    private func clearTransientSubtitleState(
        removeDownloadedFile: Bool,
        clearCurrentItemSelection: Bool = false
    ) {
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

        guard removeDownloadedFile, let subtitleFileURL = downloadedSubtitleFileURL else { return }
        try? FileManager.default.removeItem(at: subtitleFileURL)
        downloadedSubtitleFileURL = nil
    }

    private func autoLoadSubtitlesIfEnabled(for stream: StreamInfo) async {
        let autoSearch = await subtitleAutoSearchSetting(default: true)
        let rawAPIKey = await openSubtitlesAPIKeySetting()
        let languageSetting = await subtitleLanguageSetting()
        let preflight = PlayerViewStatePolicy.autoSubtitlePreflight(
            requestedStreamID: stream.id,
            currentStreamID: currentStream.id,
            autoSearchEnabled: autoSearch,
            rawAPIKey: rawAPIKey,
            configuredLanguageSetting: languageSetting,
            systemPreferredLanguages: systemPreferredCaptionLanguages,
            closedCaptioningEnabled: systemClosedCaptioningEnabled,
            streamFileName: stream.fileName
        )
        guard case .download(let request) = preflight else { return }

        let service = resolvedSubtitleService(apiKey: request.apiKey)

        do {
            let subtitle = try await service.downloadFirstMatch(
                query: request.query,
                languages: request.languages,
                season: stream.recoveryContext?.seasonNumber,
                episode: stream.recoveryContext?.episodeNumber
            )
            guard !Task.isCancelled,
                  Self.subtitleMutationShouldRun(
                      requestedStreamID: stream.id,
                      currentStreamID: currentStream.id
                  ) else {
                if let staleURL = subtitle.downloadURL {
                    try? FileManager.default.removeItem(at: staleURL)
                }
                return
            }
            if let previousURL = downloadedSubtitleFileURL {
                try? FileManager.default.removeItem(at: previousURL)
            }
            downloadedSubtitleFileURL = subtitle.downloadURL
            if let avSubtitleGroup {
                avPlayer?.currentItem?.select(nil, in: avSubtitleGroup)
            }
            selectedAVSubtitleID = nil
            clearKSSubtitleSelection()
            engine.loadExternalSubtitles([subtitle])
            engine.selectSubtitleTrack(0)
            recordSubtitleRuntimeState()
        } catch {
            guard !Task.isCancelled,
                  Self.subtitleMutationShouldRun(
                      requestedStreamID: stream.id,
                      currentStreamID: currentStream.id
                  ) else {
                return
            }
            subtitleCatalogMessage = PlayerSubtitleServicePolicy.automaticDownloadFailureMessage(
                errorDescription: error.localizedDescription
            )
            recordSubtitleRuntimeState()
        }
    }

    private func resolvedSubtitleService(apiKey: String) -> any OpenSubtitlesServicing {
        if let existing = subtitleService, subtitleServiceAPIKey == apiKey {
            return existing
        }
        let service = subtitleServiceFactory(apiKey)
        subtitleService = service
        subtitleServiceAPIKey = apiKey
        return service
    }

    @ViewBuilder
    private func featureChip(title: String, symbol: String?) -> some View {
        Group {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
        }
    }

    private func subtitleTrackRow(name: String, language: String?) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .lineLimit(1)
                if let languageLabel = PlayerViewPolicy.subtitleTrackLanguageLabel(language) {
                    Text(languageLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func subtitleCandidateRow(_ subtitle: Subtitle) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(subtitle.fileName)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    GlassTag(text: subtitle.language.uppercased(), weight: .semibold)
                    if let rating = subtitle.rating {
                        Label("\(rating, specifier: "%.1f")", systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let downloads = subtitle.downloadCount {
                        Label("\(downloads)", systemImage: "arrow.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
        }
    }

    private func hydrateFallbackAudioTrack(for stream: StreamInfo) {
        guard PlayerViewStatePolicy.shouldHydrateFallbackAudioTrack(
            existingAudioTrackCount: engine.audioTracks.count
        ) else { return }
        let fallback = PlayerViewStatePolicy.fallbackKSAudioTrackInfo(for: stream)
        engine.loadAudioTracks([fallback], selectedTrackID: fallback.id)
    }

    @MainActor
    private func refreshKSAudioTracks(for stream: StreamInfo) {
        guard let coordinator = ksPlayerCoordinator,
              isCurrentKSPlayerCoordinator(coordinator),
              let player = coordinator.playerLayer?.player else {
            return
        }

        let audioTracks = player.tracks(mediaType: .audio)
        guard !audioTracks.isEmpty else {
            hydrateFallbackAudioTrack(for: stream)
            return
        }

        let snapshots = audioTracks.map { PlayerViewStatePolicy.mediaTrackSnapshot(from: $0) }
        let trackInfos = PlayerViewStatePolicy.ksAudioTrackInfos(from: snapshots)
        let selectedTrackID = PlayerViewStatePolicy.selectedKSTrackID(from: snapshots)
        engine.loadAudioTracks(trackInfos, selectedTrackID: selectedTrackID)
    }

    private func refreshKSAudioTracks(from coordinator: KSVideoPlayer.Coordinator) {
        guard isCurrentKSPlayerCoordinator(coordinator) else { return }
        let tracks = coordinator.playerLayer?.player.tracks(mediaType: .audio) ?? []
        guard !tracks.isEmpty else { return }

        let snapshots = tracks.map { PlayerViewStatePolicy.mediaTrackSnapshot(from: $0) }
        let trackInfos = PlayerViewStatePolicy.ksAudioTrackInfos(from: snapshots)
        let selectedTrackID = PlayerViewStatePolicy.selectedKSTrackID(from: snapshots)
        engine.loadAudioTracks(trackInfos, selectedTrackID: selectedTrackID)
    }

    @MainActor
    private func scheduleKSTrackRefresh(for stream: StreamInfo) {
        subtitleTrackRefreshTask?.cancel()
        subtitleTrackRefreshTask = Task { @MainActor in
            for delay in PlayerViewStatePolicy.scheduledKSTrackRefreshDelaysMilliseconds() {
                try? await Task.sleep(for: .milliseconds(delay))
                guard !Task.isCancelled,
                      PlayerViewStatePolicy.shouldRunScheduledKSTrackRefresh(
                          requestedStreamID: stream.id,
                          currentStreamID: currentStream.id,
                          hasCurrentCoordinator: ksPlayerCoordinator.map(isCurrentKSPlayerCoordinator) ?? false
                      ),
                      let coordinator = ksPlayerCoordinator else {
                    return
                }
                refreshKSAudioTracks(from: coordinator)
                refreshKSSubtitleTracks(from: coordinator)
            }
            subtitleTrackRefreshTask = nil
        }
    }

    @MainActor
    private func refreshKSSubtitleTracks(for stream: StreamInfo) {
        guard let coordinator = ksPlayerCoordinator,
              isCurrentKSPlayerCoordinator(coordinator) else {
            return
        }

        refreshKSSubtitleTracks(from: coordinator)
        if ksSubtitleOptions.isEmpty {
            subtitleTrackRefreshTask?.cancel()
            scheduleKSTrackRefresh(for: stream)
        }
    }

    private func refreshKSSubtitleTracks(from coordinator: KSVideoPlayer.Coordinator) {
        guard isCurrentKSPlayerCoordinator(coordinator) else { return }
        let tracks = coordinator.playerLayer?.player.tracks(mediaType: .subtitle) ?? []
        guard !tracks.isEmpty else {
            ksSubtitleOptions = []
            selectedKSSubtitleID = nil
            return
        }

        let subtitleInfos = coordinator.subtitleModel.subtitleInfos
        let options = tracks.enumerated().map { index, track in
            let snapshot = PlayerViewStatePolicy.mediaTrackSnapshot(from: track)
            let id = String(snapshot.trackID)
            let modelName = subtitleInfos.first { $0.subtitleID == id }?.name
            let fields = PlayerViewStatePolicy.ksSubtitleOptionFields(
                from: snapshot,
                modelName: modelName,
                index: index
            )
            return KSSubtitleOption(
                id: fields.id,
                name: fields.name,
                language: fields.language
            )
        }

        let selectedID = resolvedSelectedKSSubtitleID(from: coordinator, tracks: tracks, options: options)
        ksSubtitleOptions = options
        selectedKSSubtitleID = selectedID
        if PlayerViewStatePolicy.shouldMarkSubtitlesEnabled(selectedKSSubtitleID: selectedID) {
            engine.subtitlesEnabled = true
        }
    }

    private func resolvedSelectedKSSubtitleID(
        from coordinator: KSVideoPlayer.Coordinator,
        tracks: [any MediaPlayerTrack],
        options: [KSSubtitleOption]
    ) -> String? {
        PlayerSubtitleSelectionPolicy.resolvedKSSubtitleID(
            selectedSubtitleInfoID: coordinator.subtitleModel.selectedSubtitleInfo?.subtitleID,
            enabledTrackID: tracks.first(where: { $0.isEnabled }).map { String($0.trackID) },
            optionIDs: options.map(\.id)
        )
    }

    @MainActor
    private func refreshAVMediaOptions(for player: AVPlayer) async {
        guard !Task.isCancelled, isCurrentAVPlayer(player) else { return }
        guard let item = player.currentItem else {
            avAudioOptions = []
            avSubtitleOptions = []
            avAudioGroup = nil
            avSubtitleGroup = nil
            selectedAVAudioID = nil
            selectedAVSubtitleID = nil
            return
        }

        // Audio defaults stay app-driven; subtitle defaults can honor the
        // system closed-caption preference when the user has not set one.
        let preferredAudioLanguages = PlayerSubtitlePolicy.preferredLanguageCodes(
            from: (try? await appState.settingsManager.getString(key: SettingsKeys.audioLanguage)) ?? "en"
        )
        let preferredSubtitleLanguages = Self.automaticSubtitleLanguageCodes(
            configuredLanguageSetting: await subtitleLanguageSetting(),
            systemPreferredLanguages: systemPreferredCaptionLanguages,
            closedCaptioningEnabled: systemClosedCaptioningEnabled
        )
        guard !Task.isCancelled, isCurrentAVPlayer(player) else { return }

        var newAudioGroup: AVMediaSelectionGroup?
        var newAudioOptions: [AVTrackOption] = []
        var newSelectedAVAudioID: String?

        if let audioGroup = try? await item.asset.loadMediaSelectionGroup(for: .audible) {
            guard !Task.isCancelled, isCurrentAVPlayer(player) else { return }
            newAudioGroup = audioGroup
            newAudioOptions = audioGroup.options.enumerated().map { index, option in
                AVTrackOption(
                    id: avOptionID(option, index: index),
                    name: option.displayName,
                    language: option.locale?.identifier ?? option.extendedLanguageTag,
                    option: option
                )
            }
            let candidates = newAudioOptions.map { option in
                PlayerAVMediaSelectionPolicy.Candidate(
                    id: option.id,
                    localeIdentifier: option.option.locale?.identifier,
                    extendedLanguageTag: option.option.extendedLanguageTag
                )
            }
            let selectedIndex = item.currentMediaSelection.selectedMediaOption(in: audioGroup)
                .flatMap { audioGroup.options.firstIndex(of: $0) }
            let selectionPlan = PlayerAVMediaSelectionPolicy.selectionPlan(
                currentSelectedIndex: selectedIndex,
                candidates: candidates,
                preferredLanguages: preferredAudioLanguages,
                allowsPreferredAutoSelection: true
            )
            newSelectedAVAudioID = selectionPlan.selectedID
            if let autoSelectIndex = selectionPlan.autoSelectIndex {
                item.select(audioGroup.options[autoSelectIndex], in: audioGroup)
            }
        }

        guard !Task.isCancelled, isCurrentAVPlayer(player) else { return }
        avAudioGroup = newAudioGroup
        avAudioOptions = newAudioOptions
        selectedAVAudioID = newSelectedAVAudioID

        var newSubtitleGroup: AVMediaSelectionGroup?
        var newSubtitleOptions: [AVTrackOption] = []
        var newSelectedAVSubtitleID: String?
        var newSubtitlesEnabled = engine.subtitlesEnabled

        if let subtitleGroup = try? await item.asset.loadMediaSelectionGroup(for: .legible) {
            guard !Task.isCancelled, isCurrentAVPlayer(player) else { return }
            newSubtitleGroup = subtitleGroup
            newSubtitleOptions = subtitleGroup.options.enumerated().map { index, option in
                AVTrackOption(
                    id: avOptionID(option, index: index),
                    name: option.displayName,
                    language: option.locale?.identifier ?? option.extendedLanguageTag,
                    option: option
                )
            }
            let candidates = newSubtitleOptions.map { option in
                PlayerAVMediaSelectionPolicy.Candidate(
                    id: option.id,
                    localeIdentifier: option.option.locale?.identifier,
                    extendedLanguageTag: option.option.extendedLanguageTag
                )
            }
            let selectedIndex = item.currentMediaSelection.selectedMediaOption(in: subtitleGroup)
                .flatMap { subtitleGroup.options.firstIndex(of: $0) }
            let selectionPlan = PlayerAVMediaSelectionPolicy.selectionPlan(
                currentSelectedIndex: selectedIndex,
                candidates: candidates,
                preferredLanguages: preferredSubtitleLanguages,
                allowsPreferredAutoSelection: subtitleSelectionMode == .automaticPreferred
            )
            newSelectedAVSubtitleID = selectionPlan.selectedID
            if let autoSelectIndex = selectionPlan.autoSelectIndex {
                item.select(subtitleGroup.options[autoSelectIndex], in: subtitleGroup)
            }
            if selectionPlan.selectedID != nil {
                newSubtitlesEnabled = true
            }
        }

        guard !Task.isCancelled, isCurrentAVPlayer(player) else { return }
        avSubtitleGroup = newSubtitleGroup
        avSubtitleOptions = newSubtitleOptions
        selectedAVSubtitleID = newSelectedAVSubtitleID
        engine.subtitlesEnabled = newSubtitlesEnabled
    }

    @MainActor
    private func loadChapters(from player: AVPlayer) async {
        guard isCurrentAVPlayer(player) else { return }
        guard let item = player.currentItem else {
            engine.loadChapters([])
            return
        }

        do {
            let groups = try await item.asset.load(.availableChapterLocales)
            guard let locale = groups.first else {
                guard isCurrentAVPlayer(player) else { return }
                engine.loadChapters([])
                return
            }
            let chapterMetadata = try await item.asset.loadChapterMetadataGroups(
                bestMatchingPreferredLanguages: [locale.identifier]
            )
            var chapters: [VPPlayerEngine.ChapterInfo] = []
            for (index, group) in chapterMetadata.enumerated() {
                let start = group.timeRange.start.seconds
                let end = (group.timeRange.start + group.timeRange.duration).seconds
                guard start.isFinite, end.isFinite else { continue }
                var title = "Chapter \(index + 1)"
                if let firstItem = group.items.first,
                   let value = try? await firstItem.load(.stringValue) {
                    title = value
                }
                chapters.append(VPPlayerEngine.ChapterInfo(
                    id: index,
                    title: title,
                    startTime: start,
                    endTime: end
                ))
            }
            guard isCurrentAVPlayer(player) else { return }
            engine.loadChapters(chapters)
        } catch {
            guard isCurrentAVPlayer(player) else { return }
            engine.loadChapters([])
        }
    }

    private func avOptionID(_ option: AVMediaSelectionOption, index: Int) -> String {
        PlayerMediaOptionIDPolicy.id(
            localeIdentifier: option.locale?.identifier,
            extendedLanguageTag: option.extendedLanguageTag,
            displayName: option.displayName,
            index: index
        )
    }

    private func selectAVSubtitle(_ track: AVTrackOption) {
        guard let avSubtitleGroup else { return }
        cancelSubtitleDownloadTask()
        subtitleSelectionMode = .manual
        clearTransientSubtitleState(removeDownloadedFile: true)
        avPlayer?.currentItem?.select(track.option, in: avSubtitleGroup)
        selectedAVSubtitleID = track.id
        engine.clearSubtitleSelection()
        engine.subtitlesEnabled = true
    }

    private func selectKSSubtitle(_ track: KSSubtitleOption) {
        cancelSubtitleDownloadTask()
        subtitleSelectionMode = .manual
        if let avSubtitleGroup {
            avPlayer?.currentItem?.select(nil, in: avSubtitleGroup)
        }
        selectedAVSubtitleID = nil
        engine.loadExternalSubtitles([])
        engine.clearSubtitleSelection()

        guard let coordinator = ksPlayerCoordinator,
              isCurrentKSPlayerCoordinator(coordinator),
              let player = coordinator.playerLayer?.player,
              let mediaTrack = player.tracks(mediaType: .subtitle).first(where: {
                  String($0.trackID) == track.id
              }) else {
            return
        }

        if coordinator.subtitleModel.selectedSubtitleInfo?.subtitleID != track.id {
            coordinator.subtitleModel.selectedSubtitleInfo = nil
        }
        if let subtitleInfo = coordinator.subtitleModel.subtitleInfos.first(where: {
            $0.subtitleID == track.id
        }) {
            coordinator.subtitleModel.selectedSubtitleInfo = subtitleInfo
        } else {
            mediaTrack.isEnabled = true
        }

        player.select(track: mediaTrack)
        selectedKSSubtitleID = track.id
        engine.subtitlesEnabled = true
        refreshKSSubtitleTracks(from: coordinator)
    }

    private func selectExternalSubtitle(index: Int) {
        cancelSubtitleDownloadTask()
        subtitleSelectionMode = .manual
        if let avSubtitleGroup {
            avPlayer?.currentItem?.select(nil, in: avSubtitleGroup)
        }
        selectedAVSubtitleID = nil
        clearKSSubtitleSelection()
        engine.selectSubtitleTrack(index)
    }

    private func selectSubtitlesOff() {
        cancelSubtitleDownloadTask()
        subtitleSelectionMode = .manual
        clearTransientSubtitleState(removeDownloadedFile: true)
        if let avSubtitleGroup {
            avPlayer?.currentItem?.select(nil, in: avSubtitleGroup)
        }
        selectedAVSubtitleID = nil
        engine.selectSubtitleTrack(-1)
        isShowingSubtitlePicker = false
    }

    private func clearKSSubtitleSelection() {
        selectedKSSubtitleID = nil
        guard let coordinator = ksPlayerCoordinator,
              isCurrentKSPlayerCoordinator(coordinator) else {
            return
        }

        coordinator.subtitleModel.selectedSubtitleInfo = nil
        for track in coordinator.playerLayer?.player.tracks(mediaType: .subtitle) ?? [] where track.isEnabled {
            track.isEnabled = false
        }
    }

    private func selectAVAudio(_ track: AVTrackOption) {
        guard let avAudioGroup else { return }
        avPlayer?.currentItem?.select(track.option, in: avAudioGroup)
        selectedAVAudioID = track.id
    }

    private func selectEngineAudio(_ track: VPPlayerEngine.TrackInfo) {
        engine.selectAudioTrack(track.id)

        guard let coordinator = ksPlayerCoordinator else { return }
        guard let mediaTrack = coordinator.playerLayer?.player.tracks(mediaType: .audio).first(where: {
            Int($0.trackID) == track.id
        }) else {
            return
        }

        coordinator.playerLayer?.player.select(track: mediaTrack)
        refreshKSAudioTracks(from: coordinator)
    }

    private func scheduleSubtitleCatalogRefresh(for stream: StreamInfo) {
        let mutationID = UUID()
        subtitleCatalogMutationID = mutationID
        subtitleCatalogTask?.cancel()
        subtitleCatalogTask = nil
        subtitleCatalogTask = Task {
            await refreshSubtitleCatalog(
                for: stream,
                requestedStreamID: stream.id,
                mutationID: mutationID
            )
        }
    }

    private func cancelSubtitleDownloadTask() {
        subtitleDownloadTask?.cancel()
        subtitleDownloadTask = nil
    }

    private func cancelVisionLifecycleTasksOnClose() {
        scenePhaseTask?.cancel()
        scenePhaseTask = nil
        memoryPressureTask?.cancel()
        memoryPressureTask = nil
        #if os(visionOS)
        environmentMenuActionTask?.cancel()
        environmentMenuActionTask = nil
        immersiveDismissTask?.cancel()
        immersiveDismissTask = nil
        #endif
    }

    private func refreshSubtitleCatalog(
        for stream: StreamInfo,
        requestedStreamID: String,
        mutationID: UUID
    ) async {
        guard !Task.isCancelled,
              Self.subtitleMutationShouldRun(
                  requestedStreamID: requestedStreamID,
                  currentStreamID: currentStream.id,
                  requestedMutationID: mutationID,
                  activeMutationID: subtitleCatalogMutationID
              ) else {
            return
        }

        isRefreshingSubtitleCatalog = true
        recordSubtitleRuntimeState()
        defer {
            if Self.subtitleMutationShouldRun(
                requestedStreamID: requestedStreamID,
                currentStreamID: currentStream.id,
                requestedMutationID: mutationID,
                activeMutationID: subtitleCatalogMutationID
            ) {
                isRefreshingSubtitleCatalog = false
                recordSubtitleRuntimeState()
            }
        }

        let rawAPIKey = await openSubtitlesAPIKeySetting()
        let languageSetting = await subtitleLanguageSetting()
        guard !Task.isCancelled,
              Self.subtitleMutationShouldRun(
                  requestedStreamID: requestedStreamID,
                  currentStreamID: currentStream.id,
                  requestedMutationID: mutationID,
                  activeMutationID: subtitleCatalogMutationID
              ) else {
            return
        }

        let preflight = PlayerViewStatePolicy.subtitleCatalogPreflight(
            rawAPIKey: rawAPIKey,
            configuredLanguageSetting: languageSetting,
            systemPreferredLanguages: systemPreferredCaptionLanguages,
            closedCaptioningEnabled: systemClosedCaptioningEnabled,
            streamFileName: stream.fileName
        )

        let request: PlayerViewStatePolicy.SubtitleLookupRequest
        guard !Task.isCancelled,
              Self.subtitleMutationShouldRun(
                  requestedStreamID: requestedStreamID,
                  currentStreamID: currentStream.id,
                  requestedMutationID: mutationID,
                  activeMutationID: subtitleCatalogMutationID
              ) else {
            return
        }

        switch preflight {
        case .missingAPIKey(let message):
            subtitleCandidates = []
            subtitleCatalogMessage = message
            recordSubtitleRuntimeState()
            return
        case .emptyQuery(let message):
            subtitleCandidates = []
            subtitleCatalogMessage = message
            recordSubtitleRuntimeState()
            return
        case .search(let lookupRequest):
            request = lookupRequest
        }

        let service = resolvedSubtitleService(apiKey: request.apiKey)

        do {
            var candidates = try await service.search(
                imdbId: PlayerSubtitleServicePolicy.imdbSearchID(from: mediaId),
                tmdbId: tmdbId,
                query: request.query,
                season: stream.recoveryContext?.seasonNumber,
                episode: stream.recoveryContext?.episodeNumber,
                languages: request.languages
            )
            candidates = PlayerSubtitleServicePolicy.supportedCatalogCandidates(candidates)
            guard !Task.isCancelled,
                  Self.subtitleMutationShouldRun(
                      requestedStreamID: requestedStreamID,
                      currentStreamID: currentStream.id,
                      requestedMutationID: mutationID,
                      activeMutationID: subtitleCatalogMutationID
                  ) else {
                return
            }
            subtitleCandidates = candidates
            subtitleCatalogMessage = PlayerSubtitleServicePolicy.catalogResultMessage(
                candidateCount: subtitleCandidates.count
            )
            recordSubtitleRuntimeState()
        } catch {
            guard !Task.isCancelled,
                  Self.subtitleMutationShouldRun(
                  requestedStreamID: requestedStreamID,
                  currentStreamID: currentStream.id,
                  requestedMutationID: mutationID,
                  activeMutationID: subtitleCatalogMutationID
              ) else {
                return
            }
            subtitleCandidates = []
            subtitleCatalogMessage = error.localizedDescription
            recordSubtitleRuntimeState()
        }
    }


    private func scheduleSubtitleDownload(_ subtitle: Subtitle, streamID: String) {
        let mutationID = UUID()
        subtitleDownloadMutationID = mutationID
        subtitleDownloadTask?.cancel()
        subtitleDownloadTask = nil
        subtitleDownloadTask = Task {
            await downloadAndSelectSubtitle(
                subtitle,
                streamID: streamID,
                mutationID: mutationID
            )
        }
    }

    private func downloadAndSelectSubtitle(
        _ subtitle: Subtitle,
        streamID: String,
        mutationID: UUID
    ) async {
        let rawAPIKey = await openSubtitlesAPIKeySetting()
        let preflight = PlayerViewStatePolicy.subtitleDownloadPreflight(
            requestedStreamID: streamID,
            currentStreamID: currentStream.id,
            subtitle: subtitle,
            rawAPIKey: rawAPIKey
        )
        guard Self.subtitleMutationShouldRun(
            requestedStreamID: streamID,
            currentStreamID: currentStream.id,
            requestedMutationID: mutationID,
            activeMutationID: subtitleDownloadMutationID
        ) else {
            return
        }

        let apiKey: String
        let fileID: Int
        switch preflight {
        case .skip:
            return
        case .unsupported(let message):
            subtitleCatalogMessage = message
            recordSubtitleRuntimeState()
            return
        case .missingAPIKey(let message):
            subtitleCatalogMessage = message
            recordSubtitleRuntimeState()
            return
        case .download(let resolvedAPIKey, let resolvedFileID):
            apiKey = resolvedAPIKey
            fileID = resolvedFileID
        }

        isDownloadingSubtitle = true
        recordSubtitleRuntimeState()
        defer {
            if Self.subtitleMutationShouldRun(
                requestedStreamID: streamID,
                currentStreamID: currentStream.id,
                requestedMutationID: mutationID,
                activeMutationID: subtitleDownloadMutationID
            ) {
                isDownloadingSubtitle = false
                recordSubtitleRuntimeState()
            }
        }

        let service = resolvedSubtitleService(apiKey: apiKey)

        do {
            let content = try await service.downloadSubtitle(fileId: fileID)
            let localURL = try writeExternalSubtitle(content: content, source: subtitle)
            guard !Task.isCancelled,
                  Self.subtitleMutationShouldRun(
                      requestedStreamID: streamID,
                      currentStreamID: currentStream.id,
                      requestedMutationID: mutationID,
                      activeMutationID: subtitleDownloadMutationID
                  ) else {
                try? FileManager.default.removeItem(at: localURL)
                return
            }

            if let previousURL = downloadedSubtitleFileURL {
                try? FileManager.default.removeItem(at: previousURL)
            }
            downloadedSubtitleFileURL = localURL
            subtitleSelectionMode = .manual

            var hydrated = subtitle
            hydrated.url = localURL.absoluteString

            if let avSubtitleGroup {
                avPlayer?.currentItem?.select(nil, in: avSubtitleGroup)
            }
            selectedAVSubtitleID = nil
            clearKSSubtitleSelection()
            engine.loadExternalSubtitles([hydrated])
            engine.selectSubtitleTrack(0)
            isShowingSubtitlePicker = false
            subtitleCatalogMessage = nil
            recordSubtitleRuntimeState()
        } catch {
            guard Self.subtitleMutationShouldRun(
                requestedStreamID: streamID,
                currentStreamID: currentStream.id,
                requestedMutationID: mutationID,
                activeMutationID: subtitleDownloadMutationID
            ) else {
                return
            }
            subtitleCatalogMessage = error.localizedDescription
            recordSubtitleRuntimeState()
        }
    }

    private func writeExternalSubtitle(content: String, source: Subtitle) throws -> URL {
        try PlayerExternalSubtitleWriter.write(content: content, source: source)
    }

}

// MARK: - Autoplay Control Notification Handlers

private struct AutoplayControlHandlers: ViewModifier {
    let onPlayNow: () -> Void
    let onCancel: () -> Void
    let onProgress: (TimeInterval, TimeInterval) -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .playerAutoplayControlPlayNow)) { _ in
                onPlayNow()
            }
            .onReceive(NotificationCenter.default.publisher(for: .playerAutoplayControlCancel)) { _ in
                onCancel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .playerAutoplayControlProgress)) { notification in
                guard let userInfo = notification.userInfo,
                      let currentTime = userInfo[PlayerAutoplayControlNotificationKey.currentTime] as? TimeInterval,
                      let duration = userInfo[PlayerAutoplayControlNotificationKey.duration] as? TimeInterval else {
                    return
                }
                onProgress(currentTime, duration)
            }
    }
}

private struct SubtitleControlHandlers: ViewModifier {
    let onRefreshCatalog: () -> Void
    let onDownload: (Subtitle) -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .playerSubtitleControlRefreshCatalog)) { _ in
                onRefreshCatalog()
            }
            .onReceive(NotificationCenter.default.publisher(for: .playerSubtitleControlDownload)) { notification in
                guard let subtitle = notification.object as? Subtitle else { return }
                onDownload(subtitle)
            }
    }
}

// MARK: - Immersive Control Notification Handlers (visionOS)

#if os(visionOS)
/// Extracted ViewModifier to keep the PlayerView body expression small enough
/// for the Swift compiler's type-checker. Listens for all immersive control
/// notifications posted by `ImmersivePlayerControlsView` and dispatches them
/// to the provided closures.
private struct ImmersiveControlHandlers: ViewModifier {
    let onToggleControls: () -> Void
    let onTogglePlayPause: () -> Void
    let onSeekBack: () -> Void
    let onSeekForward: () -> Void
    let onSeekToPercent: (Double) -> Void
    let onPreviousChapter: () -> Void
    let onNextChapter: () -> Void
    let onCycleRate: () -> Void
    let onToggleSubtitles: () -> Void
    let onToggleAudio: () -> Void
    let onRequestEnvironmentSwitch: () -> Void
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .immersiveTapCatcherDidFire)) { _ in
                onToggleControls()
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlTogglePlayPause)) { _ in
                onTogglePlayPause()
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlSeekBack)) { _ in
                onSeekBack()
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlSeekForward)) { _ in
                onSeekForward()
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlSeekToPercent)) { notification in
                if let percent = (notification.object as? NSNumber)?.doubleValue {
                    onSeekToPercent(percent)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlPreviousChapter)) { _ in
                onPreviousChapter()
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlNextChapter)) { _ in
                onNextChapter()
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlCycleRate)) { _ in
                onCycleRate()
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlToggleSubtitles)) { _ in
                onToggleSubtitles()
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlToggleAudio)) { _ in
                onToggleAudio()
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlRequestEnvironmentSwitch)) { _ in
                onRequestEnvironmentSwitch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .immersiveControlDismiss)) { _ in
                onDismiss()
            }
    }
}
#endif
