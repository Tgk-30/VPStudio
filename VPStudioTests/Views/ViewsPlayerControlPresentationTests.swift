import SwiftUI
import Testing
@testable import VPStudio

// MARK: - PlayerControlPresentation Tests

@Suite("PlayerControlPresentation Tests")
struct PlayerControlPresentationTests {
    @Test("PlayerControlPresentation equatable")
    func equatable() {
        let p1 = PlayerControlPresentation(symbolName: "pause.fill", label: "Pause", accessibilityValue: "Playing")
        let p2 = PlayerControlPresentation(symbolName: "pause.fill", label: "Pause", accessibilityValue: "Playing")
        let p3 = PlayerControlPresentation(symbolName: "play.fill", label: "Play", accessibilityValue: "Paused")

        #expect(p1 == p2)
        #expect(p1 != p3)
    }
}

// MARK: - PlayerPlayPauseControlState Tests

@Suite("PlayerPlayPauseControlState Tests")
struct PlayerPlayPauseControlStateTests {
    @Test("from returns preparing for preparing state")
    func returnsPreparingForPreparingState() {
        let result = PlayerPlayPauseControlState.from(playbackState: .preparing, isCurrentlyPlaying: false)
        #expect(result == .preparing)
    }

    @Test("from returns buffering for buffering state")
    func returnsBufferingForBufferingState() {
        let result = PlayerPlayPauseControlState.from(playbackState: .buffering, isCurrentlyPlaying: true)
        #expect(result == .buffering)
    }

    @Test("from returns playing when playing and currently playing")
    func returnsPlayingWhenPlayingAndCurrentlyPlaying() {
        let result = PlayerPlayPauseControlState.from(playbackState: .playing, isCurrentlyPlaying: true)
        #expect(result == .playing)
    }

    @Test("from returns paused when playing but not currently playing")
    func returnsPausedWhenPlayingButNotCurrentlyPlaying() {
        let result = PlayerPlayPauseControlState.from(playbackState: .playing, isCurrentlyPlaying: false)
        #expect(result == .paused)
    }

    @Test("from returns failed for failed state")
    func returnsFailedForFailedState() {
        let result = PlayerPlayPauseControlState.from(playbackState: .failed, isCurrentlyPlaying: false)
        #expect(result == .failed)
    }

    @Test("all cases are equatable")
    func allCasesEquatable() {
        #expect(PlayerPlayPauseControlState.playing == .playing)
        #expect(PlayerPlayPauseControlState.paused == .paused)
        #expect(PlayerPlayPauseControlState.buffering == .buffering)
        #expect(PlayerPlayPauseControlState.preparing == .preparing)
        #expect(PlayerPlayPauseControlState.failed == .failed)
    }

    @Test("cases are not equal to each other")
    func casesNotEqual() {
        #expect(PlayerPlayPauseControlState.playing != .paused)
        #expect(PlayerPlayPauseControlState.buffering != .preparing)
        #expect(PlayerPlayPauseControlState.failed != .playing)
    }
}

// MARK: - PlayerControlPresentationMapper Tests

@Suite("PlayerControlPresentationMapper Tests")
struct PlayerControlPresentationMapperTests {
    @Test("playPause returns pause symbol for playing state")
    func playPauseReturnsPauseForPlaying() {
        let result = PlayerControlPresentationMapper.playPause(
            playbackState: .playing,
            isCurrentlyPlaying: true
        )
        #expect(result.symbolName == "pause.fill")
        #expect(result.label == "Pause")
        #expect(result.accessibilityValue == "Playing")
    }

    @Test("playPause returns play symbol for paused state")
    func playPauseReturnsPlayForPaused() {
        let result = PlayerControlPresentationMapper.playPause(
            playbackState: .playing,
            isCurrentlyPlaying: false
        )
        #expect(result.symbolName == "play.fill")
        #expect(result.label == "Play")
        #expect(result.accessibilityValue == "Paused")
    }

    @Test("playPause returns play symbol for buffering state")
    func playPauseReturnsPlayForBuffering() {
        let result = PlayerControlPresentationMapper.playPause(
            playbackState: .buffering,
            isCurrentlyPlaying: true
        )
        #expect(result.symbolName == "play.fill")
        #expect(result.label == "Play")
        #expect(result.accessibilityValue == "Buffering")
    }

    @Test("playPause returns play symbol for preparing state")
    func playPauseReturnsPlayForPreparing() {
        let result = PlayerControlPresentationMapper.playPause(
            playbackState: .preparing,
            isCurrentlyPlaying: false
        )
        #expect(result.symbolName == "play.fill")
        #expect(result.label == "Play")
        #expect(result.accessibilityValue == "Preparing")
    }

    @Test("playPause returns play symbol for failed state")
    func playPauseReturnsPlayForFailed() {
        let result = PlayerControlPresentationMapper.playPause(
            playbackState: .failed,
            isCurrentlyPlaying: false
        )
        #expect(result.symbolName == "play.fill")
        #expect(result.label == "Play")
        #expect(result.accessibilityValue == "Failed")
    }

    @Test("playPause with state parameter returns correct for playing")
    func playPauseWithStatePlaying() {
        let result = PlayerControlPresentationMapper.playPause(for: .playing)
        #expect(result.symbolName == "pause.fill")
    }

    @Test("playPause with state parameter returns correct for paused")
    func playPauseWithStatePaused() {
        let result = PlayerControlPresentationMapper.playPause(for: .paused)
        #expect(result.symbolName == "play.fill")
    }

    @Test("playPause with state parameter returns correct for buffering")
    func playPauseWithStateBuffering() {
        let result = PlayerControlPresentationMapper.playPause(for: .buffering)
        #expect(result.symbolName == "play.fill")
    }

    @Test("playPause with state parameter returns correct for preparing")
    func playPauseWithStatePreparing() {
        let result = PlayerControlPresentationMapper.playPause(for: .preparing)
        #expect(result.symbolName == "play.fill")
    }

    @Test("playPause with state parameter returns correct for failed")
    func playPauseWithStateFailed() {
        let result = PlayerControlPresentationMapper.playPause(for: .failed)
        #expect(result.symbolName == "play.fill")
    }
}

// MARK: - PlayerTransportControlsPolicy Tests

@Suite("PlayerTransportControlsPolicy Tests")
struct PlayerTransportControlsPolicyTestsViewsViewsplayercontrolpresentationtests {
    @Test("showsRightTransportEnvironmentControl returns true for rightTransportControls")
    func returnsTrueForRightTransport() {
        #expect(PlayerTransportControlsPolicy.showsRightTransportEnvironmentControl(placement: .rightTransportControls) == true)
    }

    @Test("showsRightTransportEnvironmentControl returns false for leftNavigation")
    func returnsFalseForLeftNavigation() {
        #expect(PlayerTransportControlsPolicy.showsRightTransportEnvironmentControl(placement: .leftNavigation) == false)
    }
}

// MARK: - PlayerLifecyclePolicy Tests

@Suite("PlayerLifecyclePolicy Tests")
struct PlayerLifecyclePolicyTestsViewsViewsplayercontrolpresentationtests {
    #if os(macOS) || os(visionOS)
    @Test("closesDedicatedPlayerWindowOnBack is true on macOS/visionOS")
    func closesDedicatedPlayerWindowOnBackIsTrue() {
        #expect(PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack == true)
    }
    #else
    @Test("closesDedicatedPlayerWindowOnBack is false on other platforms")
    func closesDedicatedPlayerWindowOnBackIsFalse() {
        #expect(PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack == false)
    }
    #endif

    @Test("dismissesCurrentPresentationOnBack is always true")
    func dismissesCurrentPresentationOnBackIsAlwaysTrue() {
        #expect(PlayerLifecyclePolicy.dismissesCurrentPresentationOnBack == true)
    }
}

// MARK: - PlayerViewPolicy Tests

@Suite("PlayerViewPolicy Tests")
struct PlayerViewPolicyTests {
    @Test("avPlayerPeriodicObserverIntervalSeconds is 0.25")
    func observerIntervalIsCorrect() {
        #expect(PlayerViewPolicy.avPlayerPeriodicObserverIntervalSeconds == 0.25)
    }

    @Test("playbackStateTitle returns correct strings")
    func playbackStateTitleReturnsCorrectStrings() {
        #expect(PlayerViewPolicy.playbackStateTitle(for: .preparing) == "Preparing Playback")
        #expect(PlayerViewPolicy.playbackStateTitle(for: .buffering) == "Buffering")
        #expect(PlayerViewPolicy.playbackStateTitle(for: .playing) == "Playing")
        #expect(PlayerViewPolicy.playbackStateTitle(for: .failed) == "Playback Failed")
    }

    @Test("audioTrackRefreshShouldRun returns true when stream IDs match")
    func audioTrackRefreshRunsWhenIDsMatch() {
        #expect(PlayerViewPolicy.audioTrackRefreshShouldRun(requestedStreamID: "track1", currentStreamID: "track1") == true)
    }

    @Test("audioTrackRefreshShouldRun returns false when stream IDs differ")
    func audioTrackRefreshDoesNotRunWhenIDsDiffer() {
        #expect(PlayerViewPolicy.audioTrackRefreshShouldRun(requestedStreamID: "track1", currentStreamID: "track2") == false)
    }

    @Test("audioTrackRefreshShouldRun returns false when current is nil")
    func audioTrackRefreshDoesNotRunWhenCurrentNil() {
        #expect(PlayerViewPolicy.audioTrackRefreshShouldRun(requestedStreamID: "track1", currentStreamID: nil) == false)
    }

    @Test("preparePlaybackShouldRun returns true when IDs match")
    func preparePlaybackRunsWhenIDsMatch() {
        let id = UUID()
        #expect(PlayerViewPolicy.preparePlaybackShouldRun(requestedPreparationID: id, activePreparationID: id) == true)
    }

    @Test("preparePlaybackShouldRun returns false when IDs differ")
    func preparePlaybackDoesNotRunWhenIDsDiffer() {
        let id1 = UUID()
        let id2 = UUID()
        #expect(PlayerViewPolicy.preparePlaybackShouldRun(requestedPreparationID: id1, activePreparationID: id2) == false)
    }

    @Test("clampedSeekTarget with offset clamps correctly")
    func clampedSeekTargetWithOffset() {
        let result = PlayerViewPolicy.clampedSeekTarget(currentTime: 50, offset: 20, duration: 100)
        #expect(result == 70)
    }

    @Test("clampedSeekTarget with offset clamps to max")
    func clampedSeekTargetWithOffsetClampsToMax() {
        let result = PlayerViewPolicy.clampedSeekTarget(currentTime: 90, offset: 20, duration: 100)
        #expect(result == 100)
    }

    @Test("clampedSeekTarget with offset clamps to min")
    func clampedSeekTargetWithOffsetClampsToMin() {
        let result = PlayerViewPolicy.clampedSeekTarget(currentTime: 10, offset: -20, duration: 100)
        #expect(result == 0)
    }

    @Test("clampedSeekTarget with percent clamps correctly")
    func clampedSeekTargetWithPercent() {
        let result = PlayerViewPolicy.clampedSeekTarget(percent: 0.5, duration: 100)
        #expect(result == 50)
    }

    @Test("clampedSeekTarget with percent clamps to max")
    func clampedSeekTargetWithPercentClampsToMax() {
        let result = PlayerViewPolicy.clampedSeekTarget(percent: 1.5, duration: 100)
        #expect(result == 100)
    }

    @Test("clampedSeekTarget with percent clamps to min")
    func clampedSeekTargetWithPercentClampsToMin() {
        let result = PlayerViewPolicy.clampedSeekTarget(percent: -0.5, duration: 100)
        #expect(result == 0)
    }

    @Test("clampedSeekTarget with time clamps correctly")
    func clampedSeekTargetWithTime() {
        let result = PlayerViewPolicy.clampedSeekTarget(time: 50, duration: 100)
        #expect(result == 50)
    }

    @Test("clampedSeekTarget with time clamps to max")
    func clampedSeekTargetWithTimeClampsToMax() {
        let result = PlayerViewPolicy.clampedSeekTarget(time: 150, duration: 100)
        #expect(result == 100)
    }

    @Test("clampedSeekTarget with time clamps to min")
    func clampedSeekTargetWithTimeClampsToMin() {
        let result = PlayerViewPolicy.clampedSeekTarget(time: -50, duration: 100)
        #expect(result == 0)
    }

    @Test("clampedSeekTarget with invalid percent inputs returns zero")
    func clampedSeekTargetWithInvalidPercentInputsReturnsZero() {
        #expect(PlayerViewPolicy.clampedSeekTarget(percent: .nan, duration: 120) == 0)
        #expect(PlayerViewPolicy.clampedSeekTarget(percent: 0.5, duration: .nan) == 0)
        #expect(PlayerViewPolicy.clampedSeekTarget(percent: 0.5, duration: -120) == 0)
        #expect(PlayerViewPolicy.clampedSeekTarget(percent: .infinity, duration: 120) == 0)
    }

    @Test("clampedSeekTarget with invalid time inputs returns zero")
    func clampedSeekTargetWithInvalidTimeInputsReturnsZero() {
        #expect(PlayerViewPolicy.clampedSeekTarget(time: .nan, duration: 120) == 0)
        #expect(PlayerViewPolicy.clampedSeekTarget(time: 5, duration: .nan) == 0)
        #expect(PlayerViewPolicy.clampedSeekTarget(time: 5, duration: -120) == 0)
        #expect(PlayerViewPolicy.clampedSeekTarget(time: .infinity, duration: 120) == 0)
    }

    @Test("scrubberAccessibilityValue returns formatted string")
    func scrubberAccessibilityValueFormats() {
        let result = PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: 120,
            duration: 3600,
            isScrubbing: false,
            scrubTime: 0
        )
        #expect(result.contains("2:00"))
        #expect(result.contains("1:00:00"))
    }

    @Test("scrubberAccessibilityValue uses scrub time when scrubbing")
    func scrubberAccessibilityValueUsesScrubTime() {
        let result = PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: 120,
            duration: 3600,
            isScrubbing: true,
            scrubTime: 240
        )
        #expect(result.contains("4:00"))
        #expect(!result.contains("2:00"))
    }

    @Test("scrubberAccessibilityValue returns current time when duration is zero")
    func scrubberAccessibilityValueHandlesZeroDuration() {
        let result = PlayerViewPolicy.scrubberAccessibilityValue(
            currentTime: 120,
            duration: 0,
            isScrubbing: false,
            scrubTime: 0
        )
        #expect(result.contains("2:00"))
        #expect(!result.contains("of"))
    }

    @Test("progressBarDisplayPercent ignores invalid inputs")
    func progressBarDisplayPercentIgnoresInvalidInputs() {
        #expect(PlayerViewPolicy.progressBarDisplayPercent(displayTime: .nan, duration: 120) == 0)
        #expect(PlayerViewPolicy.progressBarDisplayPercent(displayTime: 10, duration: .nan) == 0)
        #expect(PlayerViewPolicy.progressBarDisplayPercent(displayTime: 0, duration: 0) == 1)
    }

    @Test("scrubberDragPercent treats invalid location values as zero")
    func scrubberDragPercentHandlesInvalidLocation() {
        #expect(PlayerViewPolicy.scrubberDragPercent(locationX: .nan, barWidth: 320) == 0)
        #expect(PlayerViewPolicy.scrubberDragPercent(locationX: 10, barWidth: .nan) == 0)
    }
}
