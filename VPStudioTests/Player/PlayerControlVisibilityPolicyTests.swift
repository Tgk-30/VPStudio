import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerControlVisibilityPolicy - Timing Constants")
struct PlayerControlVisibilityPolicyTimingTests {

    @Test
    func autoHideDelayIsTenSeconds() {
        #expect(PlayerControlVisibilityPolicy.autoHideDelay == 10.0)
    }

    @Test
    func fadeOutDuration() {
        #expect(PlayerControlVisibilityPolicy.fadeOutDuration == 0.35)
    }

    @Test
    func fadeInDuration() {
        #expect(PlayerControlVisibilityPolicy.fadeInDuration == 0.22)
    }
}

@Suite("PlayerControlVisibilityPolicy - Should Auto Hide")
struct PlayerControlVisibilityPolicyShouldAutoHideTests {

    @Test
    func autoHidesWhenPlayingAndAllConditionsMet() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false
            ) == true
        )
    }

    @Test
    func doesNotAutoHideWhenPlaybackStateIsNotPlaying() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .buffering,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false
            ) == false
        )
    }

    @Test
    func doesNotAutoHideWhenNotPlaying() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .playing,
                isPlaying: false,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false
            ) == false
        )
    }

    @Test
    func doesNotAutoHideWhenScrubbing() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: true,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false
            ) == false
        )
    }

    @Test
    func doesNotAutoHideWhenSubtitlePickerVisible() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: true,
                isShowingAudioPicker: false,
                isControlsLocked: false
            ) == false
        )
    }

    @Test
    func doesNotAutoHideWhenAudioPickerVisible() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: true,
                isControlsLocked: false
            ) == false
        )
    }

    @Test
    func doesNotAutoHideWhenEnvironmentPickerVisible() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingEnvironmentPicker: true
            ) == false
        )
    }

    @Test
    func doesNotAutoHideWhenCinemaSettingsVisible() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false,
                isShowingCinemaSettings: true
            ) == false
        )
    }

    @Test
    func doesNotAutoHideWhenControlsLocked() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .playing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: true
            ) == false
        )
    }

    @Test
    func doesNotAutoHideWhenPreparing() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .preparing,
                isPlaying: true,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false
            ) == false
        )
    }

    @Test
    func doesNotAutoHideWhenFailed() {
        #expect(
            PlayerControlVisibilityPolicy.shouldAutoHide(
                playbackState: .failed,
                isPlaying: false,
                isScrubbing: false,
                isShowingSubtitlePicker: false,
                isShowingAudioPicker: false,
                isControlsLocked: false
            ) == false
        )
    }
}

@Suite("PlayerControlVisibilityPolicy - Reappear Trigger")
struct PlayerControlVisibilityPolicyReappearTriggerTests {

    @Test
    func allReappearTriggersExist() {
        let allCases = PlayerControlVisibilityPolicy.ReappearTrigger.allCases
        #expect(allCases.contains(.tap))
        #expect(allCases.contains(.pointerMovement))
        #expect(allCases.contains(.keyboardShortcut))
        #expect(allCases.contains(.seekAction))
    }

    @Test
    func shouldReappearForTap() {
        #expect(PlayerControlVisibilityPolicy.shouldReappear(for: .tap) == true)
    }

    @Test
    func shouldReappearForPointerMovement() {
        #expect(PlayerControlVisibilityPolicy.shouldReappear(for: .pointerMovement) == true)
    }

    @Test
    func shouldReappearForKeyboardShortcut() {
        #expect(PlayerControlVisibilityPolicy.shouldReappear(for: .keyboardShortcut) == true)
    }

    @Test
    func shouldReappearForSeekAction() {
        #expect(PlayerControlVisibilityPolicy.shouldReappear(for: .seekAction) == true)
    }
}
