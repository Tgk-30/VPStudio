import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerControlPresentation - Structure")
struct PlayerControlPresentationStructureTests {

    @Test
    func structureEquatable() {
        let presentation1 = PlayerControlPresentation(
            symbolName: "play.fill",
            label: "Play",
            accessibilityValue: "Playing"
        )
        let presentation2 = PlayerControlPresentation(
            symbolName: "play.fill",
            label: "Play",
            accessibilityValue: "Playing"
        )
        #expect(presentation1 == presentation2)
    }

    @Test
    func structureNotEqualWithDifferentValues() {
        let presentation1 = PlayerControlPresentation(
            symbolName: "play.fill",
            label: "Play",
            accessibilityValue: "Playing"
        )
        let presentation2 = PlayerControlPresentation(
            symbolName: "pause.fill",
            label: "Pause",
            accessibilityValue: "Paused"
        )
        #expect(presentation1 != presentation2)
    }
}

@Suite("PlayerPlayPauseControlState - From Playback State")
struct PlayerPlayPauseControlStateFromPlaybackStateTests {

    @Test
    func preparingState() {
        let state = PlayerPlayPauseControlState.from(playbackState: .preparing, isCurrentlyPlaying: false)
        #expect(state == .preparing)
    }

    @Test
    func bufferingState() {
        let state = PlayerPlayPauseControlState.from(playbackState: .buffering, isCurrentlyPlaying: false)
        #expect(state == .buffering)
    }

    @Test
    func playingWhenActuallyPlaying() {
        let state = PlayerPlayPauseControlState.from(playbackState: .playing, isCurrentlyPlaying: true)
        #expect(state == .playing)
    }

    @Test
    func pausedWhenNotPlaying() {
        let state = PlayerPlayPauseControlState.from(playbackState: .playing, isCurrentlyPlaying: false)
        #expect(state == .paused)
    }

    @Test
    func failedState() {
        let state = PlayerPlayPauseControlState.from(playbackState: .failed, isCurrentlyPlaying: false)
        #expect(state == .failed)
    }
}

@Suite("PlayerPlayPauseControlState - Equatable")
struct PlayerPlayPauseControlStateEquatableTests {

    @Test
    func allCasesAreDistinct() {
        #expect(PlayerPlayPauseControlState.playing != PlayerPlayPauseControlState.paused)
        #expect(PlayerPlayPauseControlState.playing != PlayerPlayPauseControlState.buffering)
        #expect(PlayerPlayPauseControlState.playing != PlayerPlayPauseControlState.preparing)
        #expect(PlayerPlayPauseControlState.playing != PlayerPlayPauseControlState.failed)
        #expect(PlayerPlayPauseControlState.paused != PlayerPlayPauseControlState.buffering)
        #expect(PlayerPlayPauseControlState.paused != PlayerPlayPauseControlState.preparing)
        #expect(PlayerPlayPauseControlState.paused != PlayerPlayPauseControlState.failed)
    }
}

@Suite("PlayerControlPresentationMapper - Play Pause For State")
struct PlayerControlPresentationMapperPlayPauseForStateTests {

    @Test
    func playingStatePresentation() {
        let presentation = PlayerControlPresentationMapper.playPause(for: .playing)
        #expect(presentation.symbolName == "pause.fill")
        #expect(presentation.label == "Pause")
        #expect(presentation.accessibilityValue == "Playing")
    }

    @Test
    func pausedStatePresentation() {
        let presentation = PlayerControlPresentationMapper.playPause(for: .paused)
        #expect(presentation.symbolName == "play.fill")
        #expect(presentation.label == "Play")
        #expect(presentation.accessibilityValue == "Paused")
    }

    @Test
    func bufferingStatePresentation() {
        let presentation = PlayerControlPresentationMapper.playPause(for: .buffering)
        #expect(presentation.symbolName == "play.fill")
        #expect(presentation.label == "Play")
        #expect(presentation.accessibilityValue == "Buffering")
    }

    @Test
    func preparingStatePresentation() {
        let presentation = PlayerControlPresentationMapper.playPause(for: .preparing)
        #expect(presentation.symbolName == "play.fill")
        #expect(presentation.label == "Play")
        #expect(presentation.accessibilityValue == "Preparing")
    }

    @Test
    func failedStatePresentation() {
        let presentation = PlayerControlPresentationMapper.playPause(for: .failed)
        #expect(presentation.symbolName == "play.fill")
        #expect(presentation.label == "Play")
        #expect(presentation.accessibilityValue == "Failed")
    }
}

@Suite("PlayerControlPresentationMapper - Play Pause From Playback State")
struct PlayerControlPresentationMapperPlayPauseFromPlaybackStateTests {

    @Test
    func playingWhileActuallyPlaying() {
        let presentation = PlayerControlPresentationMapper.playPause(
            playbackState: .playing,
            isCurrentlyPlaying: true
        )
        #expect(presentation.symbolName == "pause.fill")
        #expect(presentation.accessibilityValue == "Playing")
    }

    @Test
    func playingButNotActuallyPlaying() {
        let presentation = PlayerControlPresentationMapper.playPause(
            playbackState: .playing,
            isCurrentlyPlaying: false
        )
        #expect(presentation.symbolName == "play.fill")
        #expect(presentation.accessibilityValue == "Paused")
    }

    @Test
    func bufferingWhileBuffering() {
        let presentation = PlayerControlPresentationMapper.playPause(
            playbackState: .buffering,
            isCurrentlyPlaying: false
        )
        #expect(presentation.accessibilityValue == "Buffering")
    }

    @Test
    func preparingWhilePreparing() {
        let presentation = PlayerControlPresentationMapper.playPause(
            playbackState: .preparing,
            isCurrentlyPlaying: false
        )
        #expect(presentation.accessibilityValue == "Preparing")
    }

    @Test
    func failedPlayback() {
        let presentation = PlayerControlPresentationMapper.playPause(
            playbackState: .failed,
            isCurrentlyPlaying: false
        )
        #expect(presentation.accessibilityValue == "Failed")
    }
}
