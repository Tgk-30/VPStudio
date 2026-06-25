import Foundation
import AVFoundation
@preconcurrency import KSPlayer
import Testing
@testable import VPStudio

@Suite("Player View State Policy")
struct PlayerViewStatePolicyTests {
    @Test
    func autoplayPromptStateRoundTripsTransientFieldsWithoutPersistingDerivedNextEpisodeFlag() {
        let state = PlayerViewStatePolicy.autoplayPromptState(
            hasNextEpisode: true,
            didRequestAutoplayNext: true,
            didCancelAutoPlayNextPrompt: false,
            isShowingAutoPlayNextPrompt: true,
            isResolvingAutoPlayNextEpisode: true,
            countdownRemaining: 3
        )

        #expect(state.hasNextEpisode)
        #expect(state.didRequestAutoplayNext)
        #expect(!state.didCancelAutoPlayNextPrompt)
        #expect(state.isShowingAutoPlayNextPrompt)
        #expect(state.isResolvingAutoPlayNextEpisode)
        #expect(state.countdownRemaining == 3)

        let fields = PlayerViewStatePolicy.autoplayPromptFields(from: state)
        #expect(fields.didRequestAutoplayNext)
        #expect(!fields.didCancelAutoPlayNextPrompt)
        #expect(fields.isShowingAutoPlayNextPrompt)
        #expect(fields.isResolvingAutoPlayNextEpisode)
        #expect(fields.countdownRemaining == 3)
    }

    @Test
    func streamTransitionPlanRejectsCurrentStreamAndBuildsPremiumSwitchMessageForNewStream() {
        let current = Self.stream(fileName: "Movie.1080p.mkv", quality: .hd1080p)
        let next = Self.stream(fileName: "Movie.2160p.mkv", quality: .uhd4k)

        #expect(PlayerViewStatePolicy.streamTransitionPlan(from: current, to: current) == nil)

        let plan = PlayerViewStatePolicy.streamTransitionPlan(from: current, to: next)
        #expect(plan?.stream == next)
        #expect(plan?.message == "Switching stream to 4K...")
    }

    @Test
    func nextStreamDelegatesToFailoverPlannerOrdering() {
        let first = Self.stream(fileName: "Movie.720p.mkv", quality: .hd720p)
        let second = Self.stream(fileName: "Movie.1080p.mkv", quality: .hd1080p)
        let third = Self.stream(fileName: "Movie.2160p.mkv", quality: .uhd4k)

        #expect(PlayerViewStatePolicy.nextStream(after: first, in: [first, second, third]) == second)
        #expect(PlayerViewStatePolicy.nextStream(after: third, in: [first, second, third]) == nil)
    }

    @Test
    func trackRefreshRouteRequiresTheMatchingEngineAndBackingPlayerObject() {
        #expect(
            PlayerViewStatePolicy.trackRefreshRoute(
                activeEngine: .avPlayer,
                hasAVPlayer: true,
                hasKSPlayerCoordinator: true
            ) == .avPlayer
        )
        #expect(
            PlayerViewStatePolicy.trackRefreshRoute(
                activeEngine: .ksPlayer,
                hasAVPlayer: true,
                hasKSPlayerCoordinator: true
            ) == .ksPlayer
        )
        #expect(
            PlayerViewStatePolicy.trackRefreshRoute(
                activeEngine: .avPlayer,
                hasAVPlayer: false,
                hasKSPlayerCoordinator: true
            ) == .none
        )
        #expect(
            PlayerViewStatePolicy.trackRefreshRoute(
                activeEngine: .ksPlayer,
                hasAVPlayer: true,
                hasKSPlayerCoordinator: false
            ) == .none
        )
        #expect(
            PlayerViewStatePolicy.trackRefreshRoute(
                activeEngine: nil,
                hasAVPlayer: true,
                hasKSPlayerCoordinator: true
            ) == .none
        )
    }

    @Test
    func resolvedEngineStrategyFallsBackToCompatibilityForMissingOrUnknownSettings() {
        #expect(PlayerViewStatePolicy.resolvedEngineStrategy(from: PlayerEngineStrategy.adaptive.rawValue) == .adaptive)
        #expect(PlayerViewStatePolicy.resolvedEngineStrategy(from: PlayerEngineStrategy.performance.rawValue) == .performance)
        #expect(PlayerViewStatePolicy.resolvedEngineStrategy(from: nil) == .compatibility)
        #expect(PlayerViewStatePolicy.resolvedEngineStrategy(from: "future-mode") == .compatibility)
    }

    @Test
    func controlsToggleActionKeepsMenusResponsiveWithoutStutteringAutoHideState() {
        #expect(
            PlayerViewStatePolicy.controlsToggleAction(
                isControlModalPresented: true,
                isShowingControls: false,
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            ) == .keepVisibleForPresentedModal
        )
        #expect(
            PlayerViewStatePolicy.controlsToggleAction(
                isControlModalPresented: false,
                isShowingControls: false,
                playbackState: .playing,
                isPlaying: false,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            ) == .showAndScheduleHide
        )
        #expect(
            PlayerViewStatePolicy.controlsToggleAction(
                isControlModalPresented: false,
                isShowingControls: true,
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            ) == .hideAndCancelScheduledHide
        )
    }

    @Test
    func controlsToggleKeepsVisibleWhenPlaybackCannotSafelyHideChrome() {
        #expect(
            PlayerViewStatePolicy.controlsToggleAction(
                isControlModalPresented: false,
                isShowingControls: true,
                playbackState: .playing,
                isPlaying: false,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            ) == .keepVisibleAndCancelScheduledHide
        )
        #expect(
            PlayerViewStatePolicy.controlsToggleAction(
                isControlModalPresented: false,
                isShowingControls: true,
                playbackState: .buffering,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            ) == .keepVisibleAndCancelScheduledHide
        )
        #expect(
            PlayerViewStatePolicy.controlsToggleAction(
                isControlModalPresented: false,
                isShowingControls: true,
                playbackState: .failed,
                isPlaying: false,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            ) == .keepVisibleAndCancelScheduledHide
        )
        #expect(
            PlayerViewStatePolicy.controlsToggleAction(
                isControlModalPresented: false,
                isShowingControls: true,
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: true,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            ) == .keepVisibleAndCancelScheduledHide
        )
    }

    @Test
    func controlModalVisibilityActionMapsSheetLifecycleToPresentationOrAutoHide() {
        #expect(PlayerViewStatePolicy.controlModalVisibilityAction(isPresented: true) == .prepareForPresentation)
        #expect(PlayerViewStatePolicy.controlModalVisibilityAction(isPresented: false) == .scheduleHide)
        #expect(PlayerViewStatePolicy.shouldShowControlsForModalPresentation(isShowingControls: false))
        #expect(!PlayerViewStatePolicy.shouldShowControlsForModalPresentation(isShowingControls: true))
    }

    @Test
    func elevatedPlayerStageFallbackStaysAboveOpaqueSurfacesUntilPlaybackHasRendered() {
        #expect(
            PlayerViewStatePolicy.shouldElevatePlayerStageFallback(
                playbackState: .preparing,
                hasPlayedOnce: false
            )
        )
        #expect(
            PlayerViewStatePolicy.shouldElevatePlayerStageFallback(
                playbackState: .buffering,
                hasPlayedOnce: false
            )
        )
        #expect(
            PlayerViewStatePolicy.shouldElevatePlayerStageFallback(
                playbackState: .playing,
                hasPlayedOnce: false
            )
        )
        #expect(
            PlayerViewStatePolicy.shouldElevatePlayerStageFallback(
                playbackState: .failed,
                hasPlayedOnce: true
            )
        )
        #expect(
            !PlayerViewStatePolicy.shouldElevatePlayerStageFallback(
                playbackState: .playing,
                hasPlayedOnce: true
            )
        )
        #expect(
            !PlayerViewStatePolicy.shouldElevatePlayerStageFallback(
                playbackState: .buffering,
                hasPlayedOnce: true
            )
        )
    }

    @Test
    func transportDockHidesDuringInitialLoadingStates() {
        #expect(!PlayerViewStatePolicy.shouldShowTransportDock(playbackState: .preparing, hasPlayedOnce: false))
        #expect(!PlayerViewStatePolicy.shouldShowTransportDock(playbackState: .buffering, hasPlayedOnce: false))
        #expect(PlayerViewStatePolicy.shouldShowTransportDock(playbackState: .playing, hasPlayedOnce: false))
        #expect(PlayerViewStatePolicy.shouldShowTransportDock(playbackState: .buffering, hasPlayedOnce: true))
        #expect(PlayerViewStatePolicy.shouldShowTransportDock(playbackState: .failed, hasPlayedOnce: true))
    }

    @Test
    func avPlayerObservationClearsRebufferStateWhenPausedAfterFirstFrame() {
        #expect(
            PlayerViewStatePolicy.avPlayerObservedPlaybackState(
                currentState: .buffering,
                isPlaying: true,
                isBuffering: false,
                hasPlayedOnce: true
            ) == .playing
        )
        #expect(
            PlayerViewStatePolicy.avPlayerObservedPlaybackState(
                currentState: .playing,
                isPlaying: false,
                isBuffering: true,
                hasPlayedOnce: true
            ) == .buffering
        )
        #expect(
            PlayerViewStatePolicy.avPlayerObservedPlaybackState(
                currentState: .buffering,
                isPlaying: false,
                isBuffering: false,
                hasPlayedOnce: true
            ) == .playing
        )
        #expect(
            PlayerViewStatePolicy.avPlayerObservedPlaybackState(
                currentState: .buffering,
                isPlaying: false,
                isBuffering: false,
                hasPlayedOnce: false
            ) == .buffering
        )
        #expect(
            PlayerViewStatePolicy.avPlayerObservedPlaybackState(
                currentState: .failed,
                isPlaying: false,
                isBuffering: false,
                hasPlayedOnce: true
            ) == .failed
        )
    }

    @Test
    func observedRebufferingClearsStalePreparationSuccessMessageOnlyAfterPlaybackStarted() {
        #expect(
            PlayerViewStatePolicy.playbackMessageAfterObservedState(
                currentMessage: "Playing with KSPlayer.",
                observedPlaybackState: .buffering,
                hasPlayedOnce: true
            ) == nil
        )
        #expect(
            PlayerViewStatePolicy.playbackMessageAfterObservedState(
                currentMessage: "Resumed with AVPlayer.",
                observedPlaybackState: .buffering,
                hasPlayedOnce: true
            ) == nil
        )
        #expect(
            PlayerViewStatePolicy.playbackMessageAfterObservedState(
                currentMessage: "Trying AVPlayer...",
                observedPlaybackState: .buffering,
                hasPlayedOnce: false
            ) == "Trying AVPlayer..."
        )
        #expect(
            PlayerViewStatePolicy.playbackMessageAfterObservedState(
                currentMessage: "This stream failed during playback.",
                observedPlaybackState: .failed,
                hasPlayedOnce: true
            ) == "This stream failed during playback."
        )
    }

    @Test
    func immersiveControlModalFlagsAreExcludedOutsideVisionPresentationContext() {
        #expect(
            PlayerViewStatePolicy.immersiveControlModalFlags(
                includesImmersiveControls: true,
                isShowingEnvironmentPicker: true,
                isShowingCinemaSettings: false
            ) == PlayerViewStatePolicy.ControlModalImmersiveFlags(
                isShowingEnvironmentPicker: true,
                isShowingCinemaSettings: false
            )
        )
        #expect(
            PlayerViewStatePolicy.immersiveControlModalFlags(
                includesImmersiveControls: false,
                isShowingEnvironmentPicker: true,
                isShowingCinemaSettings: true
            ) == PlayerViewStatePolicy.ControlModalImmersiveFlags(
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            )
        )
    }

    @Test
    func autoHideTimingAndGuardsUseSharedPremiumPlayerPolicy() {
        #expect(PlayerViewStatePolicy.autoHideDelayNanoseconds(delaySeconds: 0.25) == 250_000_000)
        #expect(PlayerViewStatePolicy.autoHideDelayNanoseconds(delaySeconds: 10) == 10_000_000_000)

        #expect(
            PlayerViewStatePolicy.shouldAutoHideControls(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            )
        )
        #expect(
            !PlayerViewStatePolicy.shouldAutoHideControls(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: true,
                isShowingCinemaSettings: false
            )
        )
        #expect(
            !PlayerViewStatePolicy.shouldAutoHideControls(
                playbackState: .buffering,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            )
        )
        #expect(
            !PlayerViewStatePolicy.shouldAutoHideControls(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: true,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            )
        )
        #expect(
            PlayerViewStatePolicy.shouldAutoHideControls(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: false,
                isShowingCinemaSettings: false
            )
        )
    }

    @Test
    func mainWindowSuppressionAndRestoreActionsAreIdempotent() {
        #expect(PlayerViewStatePolicy.mainWindowSuppressionAction(isSuppressed: false) == .dismissMainAndMarkSuppressed)
        #expect(PlayerViewStatePolicy.mainWindowSuppressionAction(isSuppressed: true) == .none)
        #expect(PlayerViewStatePolicy.mainWindowRestoreAction(isSuppressed: true) == .openMainAndMarkRestored)
        #expect(PlayerViewStatePolicy.mainWindowRestoreAction(isSuppressed: false) == .none)
    }

    @Test
    @MainActor
    func fallbackKSAudioTrackReflectsDirectStreamCodecAndAvoidsDuplicateHydration() {
        let stream = Self.stream(fileName: "Movie.1080p.mkv", quality: .hd1080p)
        let fallback = PlayerViewStatePolicy.fallbackKSAudioTrackInfo(for: stream)

        #expect(PlayerViewStatePolicy.shouldHydrateFallbackAudioTrack(existingAudioTrackCount: 0))
        #expect(PlayerViewStatePolicy.shouldHydrateFallbackAudioTrack(existingAudioTrackCount: -1))
        #expect(!PlayerViewStatePolicy.shouldHydrateFallbackAudioTrack(existingAudioTrackCount: 1))
        #expect(fallback.id == 0)
        #expect(fallback.name == "Auto (AAC)")
        #expect(fallback.language == nil)
        #expect(fallback.codec == "H.264")
    }

    @Test
    @MainActor
    func ksAudioTrackSnapshotsMapToEngineTracksAndCurrentSelection() {
        let snapshots = [
            PlayerViewStatePolicy.MediaTrackSnapshot(
                trackID: 10,
                name: "",
                description: "Main 5.1",
                languageCode: "en",
                isEnabled: false
            ),
            PlayerViewStatePolicy.MediaTrackSnapshot(
                trackID: 11,
                name: "Commentary",
                description: "Commentary fallback",
                languageCode: "fr",
                isEnabled: true
            ),
        ]

        let tracks = PlayerViewStatePolicy.ksAudioTrackInfos(from: snapshots)

        #expect(tracks.map(\.id) == [10, 11])
        #expect(tracks.map(\.name) == ["Main 5.1", "Commentary"])
        #expect(tracks.map(\.language) == ["en", "fr"])
        #expect(tracks.allSatisfy { $0.codec == nil })
        #expect(PlayerViewStatePolicy.selectedKSTrackID(from: snapshots) == 11)
        #expect(PlayerViewStatePolicy.selectedKSTrackID(from: snapshots.map { snapshot in
            PlayerViewStatePolicy.MediaTrackSnapshot(
                trackID: snapshot.trackID,
                name: snapshot.name,
                description: snapshot.description,
                languageCode: snapshot.languageCode,
                isEnabled: false
            )
        }) == nil)
    }

    @Test
    @MainActor
    func mediaTrackSnapshotCopiesMediaPlayerTrackFields() {
        let track = FakeMediaPlayerTrack(
            trackID: 42,
            name: "Director Commentary",
            description: "English 5.1",
            languageCode: "en",
            isEnabled: true
        )

        let snapshot = PlayerViewStatePolicy.mediaTrackSnapshot(from: track)

        #expect(snapshot.trackID == 42)
        #expect(snapshot.name == "Director Commentary")
        #expect(snapshot.description == "English 5.1")
        #expect(snapshot.languageCode == "en")
        #expect(snapshot.isEnabled)
    }

    @Test
    func ksSubtitleOptionFieldsUseModelNamesWhenAvailableAndKeepTrackIDsDistinct() {
        let unnamed = PlayerViewStatePolicy.MediaTrackSnapshot(
            trackID: 7,
            name: "",
            description: "Subtitle Track",
            languageCode: "es",
            isEnabled: true
        )
        let named = PlayerViewStatePolicy.MediaTrackSnapshot(
            trackID: 8,
            name: "Forced",
            description: "Subtitle Track",
            languageCode: nil,
            isEnabled: false
        )

        let modelBacked = PlayerViewStatePolicy.ksSubtitleOptionFields(
            from: unnamed,
            modelName: "Spanish SDH",
            index: 0
        )
        let direct = PlayerViewStatePolicy.ksSubtitleOptionFields(
            from: named,
            modelName: nil,
            index: 1
        )

        #expect(modelBacked.id == "7")
        #expect(modelBacked.name == "Spanish SDH")
        #expect(modelBacked.language == "es")
        #expect(direct.id == "8")
        #expect(direct.name == "Forced")
        #expect(direct.language == nil)
        #expect(PlayerViewStatePolicy.shouldMarkSubtitlesEnabled(selectedKSSubtitleID: "7"))
        #expect(!PlayerViewStatePolicy.shouldMarkSubtitlesEnabled(selectedKSSubtitleID: nil))
    }

    @Test
    func scheduledKSTrackRefreshPolicyMatchesStreamAndCoordinatorBeforeRefreshingMenus() {
        #expect(PlayerViewStatePolicy.scheduledKSTrackRefreshDelaysMilliseconds() == [300, 1_200, 2_500])
        #expect(
            PlayerViewStatePolicy.shouldRunScheduledKSTrackRefresh(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                hasCurrentCoordinator: true
            )
        )
        #expect(
            !PlayerViewStatePolicy.shouldRunScheduledKSTrackRefresh(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-2",
                hasCurrentCoordinator: true
            )
        )
        #expect(
            !PlayerViewStatePolicy.shouldRunScheduledKSTrackRefresh(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                hasCurrentCoordinator: false
            )
        )
    }

    @Test
    func autoplayRuntimePreflightAndMessagesKeepResolutionStatePredictable() {
        let nextEpisode = PlayerSessionRequest.NextEpisodeCandidate(
            episodeId: "show-s01e02",
            seasonNumber: 1,
            episodeNumber: 2,
            title: "The Next Signal"
        )

        #expect(
            PlayerViewStatePolicy.autoplayNextPreflight(
                isCancelled: true,
                nextEpisode: nextEpisode
            ) == .finishUnavailable
        )
        #expect(
            PlayerViewStatePolicy.autoplayNextPreflight(
                isCancelled: false,
                nextEpisode: nil
            ) == .finishUnavailable
        )
        #expect(
            PlayerViewStatePolicy.autoplayNextPreflight(
                isCancelled: false,
                nextEpisode: nextEpisode
            ) == .proceed(nextEpisode)
        )
        #expect(PlayerViewStatePolicy.autoplayNextLoadingMessage(for: nextEpisode) == "Loading The Next Signal...")
        #expect(
            PlayerViewStatePolicy.autoplayNextFailureMessage(
                for: nextEpisode,
                errorDescription: "No cached files"
            ) == "Could not auto-play The Next Signal. No cached files"
        )
        #expect(PlayerViewStatePolicy.autoplayResolutionFinishOutcome(hasQueuedNextEpisode: false) == .succeeded)
        #expect(PlayerViewStatePolicy.autoplayResolutionFinishOutcome(hasQueuedNextEpisode: true) == .unavailable)
    }

    @Test
    func userVisiblePlaybackErrorsRedactSignedURLsAndTokens() {
        let nextEpisode = PlayerSessionRequest.NextEpisodeCandidate(
            episodeId: "show-s01e02",
            seasonNumber: 1,
            episodeNumber: 2,
            title: "The Next Signal"
        )

        #expect(
            PlayerViewStatePolicy.preparationFailureLine(
                kind: .avPlayer,
                errorDescription: "Invalid stream URL: https://cdn.example.com/movie.mkv?token=secret&sig=abc"
            ) == "AVPlayer: Invalid stream URL: [redacted URL]"
        )
        #expect(
            PlayerViewStatePolicy.userVisibleErrorDescription(
                "Request failed: token=abc123 access_token=def456 Bearer sk_test_secret"
            ) == "Request failed: token=[redacted] access_token=[redacted] Bearer [redacted]"
        )
        #expect(
            PlayerViewStatePolicy.autoplayNextFailureMessage(
                for: nextEpisode,
                errorDescription: "Refresh failed for https://cdn.example.com/next.mkv?signature=abc"
            ) == "Could not auto-play The Next Signal. Refresh failed for [redacted URL]"
        )
        #expect(PlayerViewStatePolicy.userVisibleErrorDescription("   ") == "Playback failed.")
    }

    @Test
    func preparationRuntimeCopyAndRatesStayPremiumAndDefensive() {
        #expect(PlayerViewStatePolicy.currentTitle(mediaTitle: "Dune", streamFileName: "Dune.2160p.mkv") == "Dune")
        #expect(PlayerViewStatePolicy.currentTitle(mediaTitle: "  Dune  ", streamFileName: "Dune.2160p.mkv") == "Dune")
        #expect(PlayerViewStatePolicy.currentTitle(mediaTitle: "", streamFileName: "Dune.2160p.mkv") == "Dune.2160p.mkv")
        #expect(PlayerViewStatePolicy.currentTitle(mediaTitle: "   \n", streamFileName: "Dune.2160p.mkv") == "Dune.2160p.mkv")
        #expect(PlayerViewStatePolicy.currentTitle(mediaTitle: nil, streamFileName: "Dune.2160p.mkv") == "Dune.2160p.mkv")
        #expect(PlayerViewStatePolicy.preparationStartMessage() == "Starting stream...")
        #expect(PlayerViewStatePolicy.preparationAttemptMessage(for: .ksPlayer) == "Trying KSPlayer...")
        #expect(PlayerViewStatePolicy.preparationAttemptMessage(for: .avPlayer) == "Trying AVPlayer...")
        #expect(PlayerViewStatePolicy.preparationResumeMessage(for: 65) == "Resuming from 1:05...")
        #expect(PlayerViewStatePolicy.preparationSuccessMessage(for: .ksPlayer, didResume: false) == "Playing with KSPlayer.")
        #expect(PlayerViewStatePolicy.preparationSuccessMessage(for: .avPlayer, didResume: true) == "Resumed with AVPlayer.")
        #expect(PlayerViewStatePolicy.playbackStartRate(-2) == 0.1)
        #expect(PlayerViewStatePolicy.playbackStartRate(0) == 0.1)
        #expect(PlayerViewStatePolicy.playbackStartRate(1.5) == 1.5)
        #expect(PlayerViewStatePolicy.playbackStartRate(.infinity) == 0.1)
        #expect(PlayerViewStatePolicy.playbackStartRate(.nan) == 0.1)
        #expect(
            PlayerViewStatePolicy.preparationFailureLine(
                kind: .ksPlayer,
                errorDescription: "decoder failed"
            ) == "KSPlayer: decoder failed"
        )
        #expect(
            PlayerViewStatePolicy.preparationFailureReason(failures: []) ==
            "No compatible player engine was available."
        )
        #expect(
            PlayerViewStatePolicy.preparationFailureReason(failures: ["KSPlayer: failed", "AVPlayer: failed"]) ==
            "KSPlayer: failed\nAVPlayer: failed"
        )
    }

    @Test
    func automaticSubtitlePreflightRequiresCurrentStreamAutoSearchKeyAndQuery() {
        let active = PlayerViewStatePolicy.autoSubtitlePreflight(
            requestedStreamID: "stream-1",
            currentStreamID: "stream-1",
            autoSearchEnabled: true,
            rawAPIKey: "  api-key  ",
            configuredLanguageSetting: "fr, en",
            systemPreferredLanguages: ["es-MX"],
            closedCaptioningEnabled: false,
            streamFileName: "Show.S01E02.1080p.mkv"
        )

        #expect(
            active == .download(
                PlayerViewStatePolicy.SubtitleLookupRequest(
                    apiKey: "api-key",
                    languages: ["fr", "en"],
                    query: "Show S01E02 1080p"
                )
            )
        )
        #expect(
            PlayerViewStatePolicy.autoSubtitlePreflight(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-2",
                autoSearchEnabled: true,
                rawAPIKey: "api-key",
                configuredLanguageSetting: nil,
                systemPreferredLanguages: ["en-US"],
                closedCaptioningEnabled: true,
                streamFileName: "Show.mkv"
            ) == .skip
        )
        #expect(
            PlayerViewStatePolicy.autoSubtitlePreflight(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                autoSearchEnabled: false,
                rawAPIKey: "api-key",
                configuredLanguageSetting: nil,
                systemPreferredLanguages: ["en-US"],
                closedCaptioningEnabled: true,
                streamFileName: "Show.mkv"
            ) == .skip
        )
        #expect(
            PlayerViewStatePolicy.autoSubtitlePreflight(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                autoSearchEnabled: true,
                rawAPIKey: " ",
                configuredLanguageSetting: nil,
                systemPreferredLanguages: ["en-US"],
                closedCaptioningEnabled: true,
                streamFileName: "Show.mkv"
            ) == .skip
        )
        #expect(
            PlayerViewStatePolicy.autoSubtitlePreflight(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                autoSearchEnabled: true,
                rawAPIKey: "api-key",
                configuredLanguageSetting: nil,
                systemPreferredLanguages: ["en-US"],
                closedCaptioningEnabled: true,
                streamFileName: "   "
            ) == .skip
        )
    }

    @Test
    func subtitleCatalogPreflightSeparatesMissingKeyEmptyQueryAndSearchRequest() {
        #expect(
            PlayerViewStatePolicy.subtitleCatalogPreflight(
                rawAPIKey: nil,
                configuredLanguageSetting: nil,
                systemPreferredLanguages: [],
                closedCaptioningEnabled: false,
                streamFileName: "Show.mkv"
            ) == .missingAPIKey(message: PlayerSubtitleServicePolicy.missingCatalogAPIKeyMessage)
        )
        #expect(
            PlayerViewStatePolicy.subtitleCatalogPreflight(
                rawAPIKey: "api-key",
                configuredLanguageSetting: nil,
                systemPreferredLanguages: [],
                closedCaptioningEnabled: false,
                streamFileName: "   "
            ) == .emptyQuery(message: PlayerSubtitleServicePolicy.emptyCatalogQueryMessage)
        )
        #expect(
            PlayerViewStatePolicy.subtitleCatalogPreflight(
                rawAPIKey: "api-key",
                configuredLanguageSetting: nil,
                systemPreferredLanguages: ["de-DE", "en-US"],
                closedCaptioningEnabled: true,
                streamFileName: "Movie.2160p.WEB-DL.mkv"
            ) == .search(
                PlayerViewStatePolicy.SubtitleLookupRequest(
                    apiKey: "api-key",
                    languages: ["de", "en"],
                    query: "Movie 2160p WEB-DL"
                )
            )
        )
    }

    @Test
    func subtitleDownloadPreflightProtectsStreamFormatKeyAndFileID() {
        let supported = Subtitle(
            id: "sub-1",
            language: "en",
            fileName: "movie.en.srt",
            url: "https://example.com/movie.en.srt",
            format: .srt,
            fileId: 42,
            rating: nil,
            downloadCount: nil,
            isHearingImpaired: false,
            source: "OpenSubtitles"
        )
        let unsupported = Subtitle(
            id: "sub-2",
            language: "en",
            fileName: "movie.en.txt",
            url: "https://example.com/movie.en.txt",
            format: .unknown,
            fileId: 43,
            rating: nil,
            downloadCount: nil,
            isHearingImpaired: false,
            source: "OpenSubtitles"
        )
        let missingFileID = Subtitle(
            id: "sub-3",
            language: "en",
            fileName: "movie.en.srt",
            url: "https://example.com/movie.en.srt",
            format: .srt,
            fileId: nil,
            rating: nil,
            downloadCount: nil,
            isHearingImpaired: false,
            source: "OpenSubtitles"
        )

        #expect(
            PlayerViewStatePolicy.subtitleDownloadPreflight(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-2",
                subtitle: supported,
                rawAPIKey: "api-key"
            ) == .skip
        )
        #expect(
            PlayerViewStatePolicy.subtitleDownloadPreflight(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                subtitle: missingFileID,
                rawAPIKey: "api-key"
            ) == .skip
        )
        #expect(
            PlayerViewStatePolicy.subtitleDownloadPreflight(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                subtitle: unsupported,
                rawAPIKey: "api-key"
            ) == .unsupported(message: PlayerSubtitleServicePolicy.unsupportedSubtitleMessage)
        )
        #expect(
            PlayerViewStatePolicy.subtitleDownloadPreflight(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                subtitle: supported,
                rawAPIKey: nil
            ) == .missingAPIKey(message: PlayerSubtitleServicePolicy.missingDownloadAPIKeyMessage)
        )
        #expect(
            PlayerViewStatePolicy.subtitleDownloadPreflight(
                requestedStreamID: "stream-1",
                currentStreamID: "stream-1",
                subtitle: supported,
                rawAPIKey: "  api-key  "
            ) == .download(apiKey: "api-key", fileID: 42)
        )
    }

    private static func stream(fileName: String, quality: VideoQuality) -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://example.com/\(fileName)")!,
            quality: quality,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: fileName,
            sizeBytes: 100,
            debridService: "realdebrid"
        )
    }
}

private final class FakeMediaPlayerTrack: MediaPlayerTrack {
    let trackID: Int32
    let name: String
    let languageCode: String?
    let mediaType: AVMediaType = .audio
    var nominalFrameRate: Float = 0
    let bitRate: Int64 = 0
    let bitDepth: Int32 = 0
    var isEnabled: Bool
    let isImageSubtitle = false
    let rotation: Int16 = 0
    let dovi: DOVIDecoderConfigurationRecord? = nil
    let fieldOrder: FFmpegFieldOrder = .unknown
    let formatDescription: CMFormatDescription? = nil
    let description: String

    init(
        trackID: Int32,
        name: String,
        description: String,
        languageCode: String?,
        isEnabled: Bool
    ) {
        self.trackID = trackID
        self.name = name
        self.description = description
        self.languageCode = languageCode
        self.isEnabled = isEnabled
    }
}
