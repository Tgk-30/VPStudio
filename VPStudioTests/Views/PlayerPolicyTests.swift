import SwiftUI
import Testing
@testable import VPStudio

// MARK: - PlayerBufferingPolicy Tests

@Suite("PlayerBufferingPolicy Tests")
struct PlayerBufferingPolicyTestsViewsPlayerpolicytests {

    @Test("rebufferText returns percentage when buffering")
    func rebufferTextReturnsPercentage() {
        let result = PlayerBufferingPolicy.rebufferText(bufferedPercent: 0.6)
        #expect(result.contains("60%"))
    }

    @Test("rebufferText returns rebuffering message when at zero")
    func rebufferTextReturnsRebufferingAtZero() {
        let result = PlayerBufferingPolicy.rebufferText(bufferedPercent: 0)
        #expect(result == "Rebuffering\u{2026}")
    }

    @Test("rebufferText returns rebuffering message when complete")
    func rebufferTextReturnsRebufferingWhenComplete() {
        let result = PlayerBufferingPolicy.rebufferText(bufferedPercent: 1.0)
        #expect(result == "Rebuffering\u{2026}")
    }

    @Test("qualityToastDuration is 3.0 seconds")
    func qualityToastDurationIsCorrect() {
        #expect(PlayerBufferingPolicy.qualityToastDuration == 3.0)
    }

    @Test("qualityChangeMessage returns formatted string when different")
    func qualityChangeMessageReturnsFormatted() {
        let result = PlayerBufferingPolicy.qualityChangeMessage(from: "1080p", to: "4K")
        #expect(result != nil)
        #expect(result!.contains("1080p"))
        #expect(result!.contains("4K"))
    }

    @Test("qualityChangeMessage returns nil when same")
    func qualityChangeMessageReturnsNilWhenSame() {
        let result = PlayerBufferingPolicy.qualityChangeMessage(from: "1080p", to: "1080p")
        #expect(result == nil)
    }

    @Test("showsControlsLock is true on all platforms")
    func showsControlsLockIsTrue() {
        #expect(PlayerBufferingPolicy.showsControlsLock == true)
    }
}

// MARK: - PlayerCapabilityWarningPolicy Tests

@Suite("PlayerCapabilityWarningPolicy Tests")
struct PlayerCapabilityWarningPolicyTestsViewsPlayerpolicytests {
    @Test("maxInlineWarnings is 1")
    func maxInlineWarningsIs1() {
        #expect(PlayerCapabilityWarningPolicy.maxInlineWarnings == 1)
    }

    @Test("maxInlineCharacters is 72")
    func maxInlineCharactersIs72() {
        #expect(PlayerCapabilityWarningPolicy.maxInlineCharacters == 72)
    }

    @Test("inlineMessage returns first warning")
    func inlineMessageReturnsFirstWarning() {
        let warnings = ["AV1 not supported", "HDR limited"]
        let result = PlayerCapabilityWarningPolicy.inlineMessage(for: warnings)
        #expect(result == "AV1 not supported")
    }

    @Test("inlineMessage returns nil for empty array")
    func inlineMessageReturnsNilForEmpty() {
        let result = PlayerCapabilityWarningPolicy.inlineMessage(for: [])
        #expect(result == nil)
    }

    @Test("overflowCount returns zero when at or under max")
    func overflowCountReturnsZeroWhenUnderMax() {
        let warnings = ["Warning 1"]
        #expect(PlayerCapabilityWarningPolicy.overflowCount(for: warnings) == 0)
    }

    @Test("overflowCount returns excess count")
    func overflowCountReturnsExcessCount() {
        let warnings = ["W1", "W2", "W3"]
        #expect(PlayerCapabilityWarningPolicy.overflowCount(for: warnings) == 2)
    }

    @Test("inlineMessage truncates long warnings")
    func inlineMessageTruncatesLongWarnings() {
        let longWarning = String(repeating: "x", count: 100)
        let result = PlayerCapabilityWarningPolicy.inlineMessage(for: [longWarning])
        #expect(result != nil)
        #expect(result!.count <= PlayerCapabilityWarningPolicy.maxInlineCharacters)
    }
}

// MARK: - PlayerCinemaEnvironmentPolicy Tests

@Suite("PlayerCinemaEnvironmentPolicy Tests")
struct PlayerCinemaEnvironmentPolicyTestsViewsPlayerpolicytests {
    @Test("menuDismissalDelay is 180ms")
    func menuDismissalDelayIsCorrect() {
        #expect(PlayerCinemaEnvironmentPolicy.menuDismissalDelay == .milliseconds(180))
    }

    @Test("unavailableMessage is set correctly")
    func unavailableMessageIsSet() {
        #expect(!PlayerCinemaEnvironmentPolicy.unavailableMessage.isEmpty)
    }

    @Test("canOpen returns true for AVPlayer with engine")
    func canOpenReturnsTrueForAVPlayer() {
        #expect(PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: .avPlayer, hasAVPlayer: true) == true)
    }

    @Test("canOpen returns false for KSPlayer")
    func canOpenReturnsFalseForKSPlayer() {
        #expect(PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: .ksPlayer, hasAVPlayer: true) == false)
    }

    @Test("canOpen returns false when no AVPlayer")
    func canOpenReturnsFalseWhenNoPlayer() {
        #expect(PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: .avPlayer, hasAVPlayer: false) == false)
    }

    @Test("canOpen returns false for nil engine")
    func canOpenReturnsFalseForNilEngine() {
        #expect(PlayerCinemaEnvironmentPolicy.canOpen(activeEngine: nil, hasAVPlayer: true) == false)
    }

    @Test("iconName returns pano for HDR extension")
    func iconNameReturnsPanoForHDR() {
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "/path/to/sky.hdr") == "pano")
    }

    @Test("iconName returns pano for EXR extension")
    func iconNameReturnsPanoForEXR() {
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "/path/to/sky.exr") == "pano")
    }

    @Test("iconName returns cube for other extensions")
    func iconNameReturnsCubeForOther() {
        #expect(PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: "/path/to/sky.jpg") == "cube.transparent")
    }
}

// MARK: - PlayerCinematicChromePolicy Tests

@Suite("PlayerCinematicChromePolicy Tests")
struct PlayerCinematicChromePolicyTestsViewsPlayerpolicytests {
    @Test("transportCardCornerRadius is 26")
    func transportCardCornerRadiusIsCorrect() {
        #expect(PlayerCinematicChromePolicy.transportCardCornerRadius == 26)
    }

    @Test("topScrimHeight is 96")
    func topScrimHeightIsCorrect() {
        #expect(PlayerCinematicChromePolicy.topScrimHeight == 96)
    }

    @Test("bottomScrimHeight is 132")
    func bottomScrimHeightIsCorrect() {
        #expect(PlayerCinematicChromePolicy.bottomScrimHeight == 132)
    }

    @Test("quickActionsCornerRadius is 20")
    func quickActionsCornerRadiusIsCorrect() {
        #expect(PlayerCinematicChromePolicy.quickActionsCornerRadius == 20)
    }

    @Test("topBarButtonSize is 42")
    func topBarButtonSizeIsCorrect() {
        #expect(PlayerCinematicChromePolicy.topBarButtonSize == 42)
    }

    @Test("primaryTransportButtonSize is 56")
    func primaryTransportButtonSizeIsCorrect() {
        #expect(PlayerCinematicChromePolicy.primaryTransportButtonSize == 56)
    }

    @Test("secondaryTransportButtonSize is 48")
    func secondaryTransportButtonSizeIsCorrect() {
        #expect(PlayerCinematicChromePolicy.secondaryTransportButtonSize == 48)
    }

    @Test("controlsDockMaxWidth is 860")
    func controlsDockMaxWidthIsCorrect() {
        #expect(PlayerCinematicChromePolicy.controlsDockMaxWidth == 860)
    }

    @Test("quickActionsMaxWidth is 640")
    func quickActionsMaxWidthIsCorrect() {
        #expect(PlayerCinematicChromePolicy.quickActionsMaxWidth == 640)
    }

    @Test("transportCardMaxWidth is 780")
    func transportCardMaxWidthIsCorrect() {
        #expect(PlayerCinematicChromePolicy.transportCardMaxWidth == 780)
    }

    @Test("skipBackInterval is 10")
    func skipBackIntervalIsCorrect() {
        #expect(PlayerCinematicChromePolicy.skipBackInterval == 10)
    }

    @Test("skipForwardInterval is 10")
    func skipForwardIntervalIsCorrect() {
        #expect(PlayerCinematicChromePolicy.skipForwardInterval == 10)
    }

    @Test("progressBarIdleHeight is 4")
    func progressBarIdleHeightIsCorrect() {
        #expect(PlayerCinematicChromePolicy.progressBarIdleHeight == 4)
    }

    @Test("progressBarScrubbingHeight is 8")
    func progressBarScrubbingHeightIsCorrect() {
        #expect(PlayerCinematicChromePolicy.progressBarScrubbingHeight == 8)
    }

    @Test("windowCornerRadius is 28")
    func windowCornerRadiusIsCorrect() {
        #expect(PlayerCinematicChromePolicy.windowCornerRadius == 28)
    }
}

// MARK: - PlayerCinematicVisualPolicy Tests

@Suite("PlayerCinematicVisualPolicy Tests")
struct PlayerCinematicVisualPolicyTestsViewsPlayerpolicytests {
    @Test("backSymbolName is chevron.left")
    func backSymbolNameIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.backSymbolName == "chevron.left")
    }

    @Test("menuSymbolName is ellipsis")
    func menuSymbolNameIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.menuSymbolName == "ellipsis")
    }

    @Test("subtitlesSymbolName is captions.bubble.fill")
    func subtitlesSymbolNameIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.subtitlesSymbolName == "captions.bubble.fill")
    }

    @Test("audioSymbolName is speaker.wave.2.fill")
    func audioSymbolNameIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.audioSymbolName == "speaker.wave.2.fill")
    }

    @Test("qualitySymbolName is line.3.horizontal.decrease.circle.fill")
    func qualitySymbolNameIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.qualitySymbolName == "line.3.horizontal.decrease.circle.fill")
    }

    @Test("skipBackSymbolName is gobackward.10")
    func skipBackSymbolNameIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.skipBackSymbolName == "gobackward.10")
    }

    @Test("skipForwardSymbolName is goforward.10")
    func skipForwardSymbolNameIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.skipForwardSymbolName == "goforward.10")
    }

    @Test("iconSurfaceBorderOpacity is 0.30")
    func iconSurfaceBorderOpacityIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.iconSurfaceBorderOpacity == 0.30)
    }

    @Test("iconSurfaceHighlightOpacity is 0.22")
    func iconSurfaceHighlightOpacityIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.iconSurfaceHighlightOpacity == 0.22)
    }

    @Test("progressTrackOpacity is 0.18")
    func progressTrackOpacityIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.progressTrackOpacity == 0.18)
    }

    @Test("progressBufferedOpacity is 0.32")
    func progressBufferedOpacityIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.progressBufferedOpacity == 0.32)
    }

    @Test("topScrimOpacity is 0.34")
    func topScrimOpacityIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.topScrimOpacity == 0.34)
    }

    @Test("bottomScrimOpacity is 0.30")
    func bottomScrimOpacityIsCorrect() {
        #expect(PlayerCinematicVisualPolicy.bottomScrimOpacity == 0.30)
    }
}

// MARK: - PlayerControlVisibilityPolicy Tests

@Suite("PlayerControlVisibilityPolicy Tests")
struct PlayerControlVisibilityPolicyTestsViewsPlayerpolicytests {
    @Test("autoHideDelay is 10.0 seconds")
    func autoHideDelayIsCorrect() {
        #expect(PlayerControlVisibilityPolicy.autoHideDelay == 10.0)
    }

    @Test("fadeOutDuration is 0.35")
    func fadeOutDurationIsCorrect() {
        #expect(PlayerControlVisibilityPolicy.fadeOutDuration == 0.35)
    }

    @Test("fadeInDuration is 0.22")
    func fadeInDurationIsCorrect() {
        #expect(PlayerControlVisibilityPolicy.fadeInDuration == 0.22)
    }

    @Test("shouldAutoHide returns true for playing state with all guards passing")
    func shouldAutoHideReturnsTrue() {
        #expect(PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ) == true)
    }

    @Test("shouldAutoHide returns false when not playing")
    func shouldAutoHideReturnsFalseWhenNotPlaying() {
        #expect(PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .buffering,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ) == false)
    }

    @Test("shouldAutoHide returns false when paused")
    func shouldAutoHideReturnsFalseWhenPaused() {
        #expect(PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: false,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ) == false)
    }

    @Test("shouldAutoHide returns false when scrubbing")
    func shouldAutoHideReturnsFalseWhenScrubbing() {
        #expect(PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: true,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ) == false)
    }

    @Test("shouldAutoHide returns false when subtitle picker showing")
    func shouldAutoHideReturnsFalseWhenSubtitlePickerShowing() {
        #expect(PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: true,
            isShowingAudioPicker: false,
            isControlsLocked: false
        ) == false)
    }

    @Test("shouldAutoHide returns false when audio picker showing")
    func shouldAutoHideReturnsFalseWhenAudioPickerShowing() {
        #expect(PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: true,
            isControlsLocked: false
        ) == false)
    }

    @Test("shouldAutoHide returns false when controls locked")
    func shouldAutoHideReturnsFalseWhenControlsLocked() {
        #expect(PlayerControlVisibilityPolicy.shouldAutoHide(
            playbackState: .playing,
            isPlaying: true,
            isScrubbing: false,
            isShowingSubtitlePicker: false,
            isShowingAudioPicker: false,
            isControlsLocked: true
        ) == false)
    }

    @Test("ReappearTrigger cases exist")
    func reappearTriggerCasesExist() {
        #expect(PlayerControlVisibilityPolicy.ReappearTrigger.allCases.count == 4)
        #expect(PlayerControlVisibilityPolicy.ReappearTrigger.allCases.contains(.tap))
        #expect(PlayerControlVisibilityPolicy.ReappearTrigger.allCases.contains(.pointerMovement))
        #expect(PlayerControlVisibilityPolicy.ReappearTrigger.allCases.contains(.keyboardShortcut))
        #expect(PlayerControlVisibilityPolicy.ReappearTrigger.allCases.contains(.seekAction))
    }

    @Test("shouldReappear returns true for all triggers")
    func shouldReappearReturnsTrueForAll() {
        for trigger in PlayerControlVisibilityPolicy.ReappearTrigger.allCases {
            #expect(PlayerControlVisibilityPolicy.shouldReappear(for: trigger) == true)
        }
    }
}

// MARK: - PlayerGesturePolicy Tests

@Suite("PlayerGesturePolicy Tests")
struct PlayerGesturePolicyTestsViewsPlayerpolicytests {
    @Test("doubleTapMaxInterval is 0.35 seconds")
    func doubleTapMaxIntervalIsCorrect() {
        #expect(PlayerGesturePolicy.doubleTapMaxInterval == 0.35)
    }

    @Test("doubleTapSeekBackSeconds is -10")
    func doubleTapSeekBackSecondsIsCorrect() {
        #expect(PlayerGesturePolicy.doubleTapSeekBackSeconds == -10)
    }

    @Test("doubleTapSeekForwardSeconds is 30")
    func doubleTapSeekForwardSecondsIsCorrect() {
        #expect(PlayerGesturePolicy.doubleTapSeekForwardSeconds == 30)
    }

    @Test("doubleTapZoneFraction is 0.35")
    func doubleTapZoneFractionIsCorrect() {
        #expect(PlayerGesturePolicy.doubleTapZoneFraction == 0.35)
    }

    @Test("doubleTapSeekOffset returns back offset for left zone")
    func doubleTapSeekOffsetReturnsBackForLeftZone() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 100, surfaceWidth: 1000)
        #expect(result == -10)
    }

    @Test("doubleTapSeekOffset returns forward offset for right zone")
    func doubleTapSeekOffsetReturnsForwardForRightZone() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 900, surfaceWidth: 1000)
        #expect(result == 30)
    }

    @Test("doubleTapSeekOffset returns nil for center zone")
    func doubleTapSeekOffsetReturnsNilForCenter() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 500, surfaceWidth: 1000)
        #expect(result == nil)
    }

    @Test("doubleTapSeekOffset returns nil for zero width")
    func doubleTapSeekOffsetReturnsNilForZeroWidth() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 100, surfaceWidth: 0)
        #expect(result == nil)
    }

    @Test("seekDirection returns backward for negative offset")
    func seekDirectionReturnsBackwardForNegative() {
        #expect(PlayerGesturePolicy.seekDirection(for: -10) == .backward)
    }

    @Test("seekDirection returns forward for positive offset")
    func seekDirectionReturnsForwardForPositive() {
        #expect(PlayerGesturePolicy.seekDirection(for: 30) == .forward)
    }

    @Test("swipeMinimumDistance is 30.0")
    func swipeMinimumDistanceIsCorrect() {
        #expect(PlayerGesturePolicy.swipeMinimumDistance == 30.0)
    }

    @Test("swipeMaxHorizontalDeviation is 40.0")
    func swipeMaxHorizontalDeviationIsCorrect() {
        #expect(PlayerGesturePolicy.swipeMaxHorizontalDeviation == 40.0)
    }
}

// MARK: - PlayerScrubPolicy Tests

@Suite("PlayerScrubPolicy Tests")
struct PlayerScrubPolicyTestsViewsPlayerpolicytests {
    @Test("chapterSnapThresholdFraction is 0.008")
    func chapterSnapThresholdFractionIsCorrect() {
        #expect(PlayerScrubPolicy.chapterSnapThresholdFraction == 0.008)
    }

    @Test("chapterSnapMinimumSeconds is 2.0")
    func chapterSnapMinimumSecondsIsCorrect() {
        #expect(PlayerScrubPolicy.chapterSnapMinimumSeconds == 2.0)
    }

    @Test("chapterSnapMaximumSeconds is 12.0")
    func chapterSnapMaximumSecondsIsCorrect() {
        #expect(PlayerScrubPolicy.chapterSnapMaximumSeconds == 12.0)
    }

    @Test("nearestChapterSnap returns snap time when close enough")
    func nearestChapterSnapReturnsSnapTime() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 10, title: "Intro"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 60, title: "Chapter 1")
        ]
        let result = PlayerScrubPolicy.nearestChapterSnap(scrubTime: 61, chapters: chapters, duration: 7200)
        #expect(result == 60)
    }

    @Test("nearestChapterSnap returns nil when too far")
    func nearestChapterSnapReturnsNilWhenTooFar() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 10, title: "Intro")
        ]
        let result = PlayerScrubPolicy.nearestChapterSnap(scrubTime: 100, chapters: chapters, duration: 7200)
        #expect(result == nil)
    }

    @Test("nearestChapterSnap returns nil for zero duration")
    func nearestChapterSnapReturnsNilForZeroDuration() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 10, title: "Intro")
        ]
        let result = PlayerScrubPolicy.nearestChapterSnap(scrubTime: 10, chapters: chapters, duration: 0)
        #expect(result == nil)
    }

    @Test("chapterSnapDistance clamps to minimum for short content")
    func chapterSnapDistanceClampsToMinimum() {
        let distance = PlayerScrubPolicy.chapterSnapDistance(duration: 60)
        #expect(distance == 2.0)
    }

    @Test("chapterSnapDistance clamps to maximum for long content")
    func chapterSnapDistanceClampsToMaximum() {
        let distance = PlayerScrubPolicy.chapterSnapDistance(duration: 100000)
        #expect(distance == 12.0)
    }

    @Test("fineScrubVelocityThreshold is 80.0")
    func fineScrubVelocityThresholdIsCorrect() {
        #expect(PlayerScrubPolicy.fineScrubVelocityThreshold == 80.0)
    }

    @Test("fineScrubScale is 0.25")
    func fineScrubScaleIsCorrect() {
        #expect(PlayerScrubPolicy.fineScrubScale == 0.25)
    }

    @Test("scrubPercentDelta applies fine scale for slow drag")
    func scrubPercentDeltaAppliesFineScale() {
        let delta = PlayerScrubPolicy.scrubPercentDelta(
            translationX: 100,
            velocityX: 50,
            barWidth: 1000
        )
        #expect(delta == 0.025)
    }

    @Test("scrubPercentDelta uses raw delta for fast drag")
    func scrubPercentDeltaUsesRawDeltaForFastDrag() {
        let delta = PlayerScrubPolicy.scrubPercentDelta(
            translationX: 100,
            velocityX: 200,
            barWidth: 1000
        )
        #expect(delta == 0.1)
    }

    @Test("scrubPercentDelta returns zero for zero width")
    func scrubPercentDeltaReturnsZeroForZeroWidth() {
        let delta = PlayerScrubPolicy.scrubPercentDelta(
            translationX: 100,
            velocityX: 50,
            barWidth: 0
        )
        #expect(delta == 0)
    }

    @Test("previewLabel formats time correctly")
    func previewLabelFormatsTime() {
        let result = PlayerScrubPolicy.previewLabel(for: 125)
        #expect(!result.isEmpty)
    }

    @Test("previewChapterTitle returns last chapter before time")
    func previewChapterTitleReturnsLastChapter() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 0, title: "Start"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 60, title: "Chapter 1")
        ]
        let result = PlayerScrubPolicy.previewChapterTitle(at: 90, chapters: chapters)
        #expect(result == "Chapter 1")
    }

    @Test("previewChapterTitle returns nil for no chapters")
    func previewChapterTitleReturnsNilForNoChapters() {
        let result = PlayerScrubPolicy.previewChapterTitle(at: 10, chapters: [])
        #expect(result == nil)
    }

    @Test("ChapterBoundary is Sendable")
    func chapterBoundaryIsSendable() {
        let boundary = PlayerScrubPolicy.ChapterBoundary(startTime: 10, title: "Test")
        #expect(boundary.startTime == 10)
        #expect(boundary.title == "Test")
    }
}