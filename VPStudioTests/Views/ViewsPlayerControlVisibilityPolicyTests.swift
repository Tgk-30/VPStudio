import Testing
@testable import VPStudio

@Suite("PlayerControlVisibilityPolicy Timing Constants")
struct PlayerControlVisibilityPolicyTimingTestsViewsViewsplayercontrolvisibilitypolicytests {
    @Test("Auto hide delay")
    func autoHideDelay() {
        #expect(PlayerControlVisibilityPolicy.autoHideDelay == 10.0)
    }

    @Test("Fade out duration")
    func fadeOutDuration() {
        #expect(PlayerControlVisibilityPolicy.fadeOutDuration == 0.35)
    }

    @Test("Fade in duration")
    func fadeInDuration() {
        #expect(PlayerControlVisibilityPolicy.fadeInDuration == 0.22)
    }

    @Test("Fade out is longer than fade in")
    func fadeOutLongerThanFadeIn() {
        #expect(PlayerControlVisibilityPolicy.fadeOutDuration > PlayerControlVisibilityPolicy.fadeInDuration)
    }
}

@Suite("PlayerControlVisibilityPolicy Should Auto Hide")
struct PlayerControlVisibilityPolicyAutoHideTests {
    @Test("Playing state allows auto hide")
    func playingState() {
        #expect(PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ))
    }

    @Test("Paused state prevents auto hide")
    func pausedState() {
        #expect(!PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .buffering,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ))
    }

    @Test("Stopped state prevents auto hide")
    func stoppedState() {
        #expect(!PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .failed,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ))
    }

    @Test("Not playing prevents auto hide")
    func notPlaying() {
        #expect(!PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: false,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ))
    }

    @Test("Scrubbing prevents auto hide")
    func scrubbingPreventsAutoHide() {
        #expect(!PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: true,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ))
    }

    @Test("Subtitle picker prevents auto hide")
    func subtitlePickerPreventsAutoHide() {
        #expect(!PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: true,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ))
    }

    @Test("Audio picker prevents auto hide")
    func audioPickerPreventsAutoHide() {
        #expect(!PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: true,
            isControlsLocked: false
        ))
    }

    @Test("Controls locked prevents auto hide")
    func controlsLockedPreventsAutoHide() {
        #expect(!PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: true
        ))
    }

    @Test("All guards pass allows auto hide")
    func allGuardsPass() {
        #expect(PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ))
    }
}

@Suite("PlayerControlVisibilityPolicy Reappear Trigger")
struct PlayerControlVisibilityPolicyReappearTriggerTestsViewsViewsplayercontrolvisibilitypolicytests {
    @Test("All triggers return true")
    func allTriggersEnabled() {
        for trigger in PlayerControlVisibilityPolicy.ReappearTrigger.allCases {
            #expect(PlayerControlVisibilityPolicy.shouldReappear(for: trigger) == true)
        }
    }

    @Test("All triggers are case iterable")
    func caseIterable() {
        let triggers = PlayerControlVisibilityPolicy.ReappearTrigger.allCases
        #expect(triggers.count == 4)
    }
}
