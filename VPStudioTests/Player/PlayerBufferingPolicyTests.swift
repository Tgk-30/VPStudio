import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerBufferingPolicy - Buffering Text")
struct PlayerBufferingPolicyBufferingTextTests {

    @Test
    func rebufferTextWithZeroPercentReturnsEllipsis() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 0) == "Rebuffering\u{2026}")
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 0.004) == "Rebuffering\u{2026}")
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 0.01) == "Buffering... 1%")
    }

    @Test
    func rebufferTextWithFullPercentReturnsReadyMessage() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 1) == "Buffer ready")
    }

    @Test
    func rebufferTextWithNegativeOrNonFinitePercentReturnsEllipsis() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: -0.1) == "Rebuffering\u{2026}")
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: .nan) == "Rebuffering\u{2026}")
    }

    @Test
    func rebufferTextWithOverflowReadyPercentReturnsReadyMessage() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 1.1) == "Buffer ready")
    }

    @Test
    func rebufferTextWithPartialPercentReturnsFormattedString() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 0.6) == "Buffering... 60%")
    }

    @Test
    func rebufferTextWithThirtyPercentReturnsFormattedString() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 0.3) == "Buffering... 30%")
    }

    @Test
    func rebufferTextWithNinetyNinePercentReturnsReadyMessage() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 0.99) == "Buffer ready")
    }

    @Test
    func rebufferTextTruncatesFractionalPercentTowardZero() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 0.979) == "Buffering... 97%")
    }

    @Test
    func surfaceFeedbackAppearsOnlyForMidPlaybackRebuffering() {
        #expect(
            PlayerBufferingPolicy.surfaceFeedbackText(
                playbackState: .buffering,
                hasPlayedOnce: true,
                bufferedPercent: 0.42
            ) == "Buffering... 42%"
        )
        #expect(
            PlayerBufferingPolicy.surfaceFeedbackText(
                playbackState: .buffering,
                hasPlayedOnce: false,
                bufferedPercent: 0.42
            ) == nil
        )
        #expect(
            PlayerBufferingPolicy.surfaceFeedbackText(
                playbackState: .playing,
                hasPlayedOnce: true,
                bufferedPercent: 0.42
            ) == nil
        )
        #expect(
            PlayerBufferingPolicy.surfaceFeedbackText(
                playbackState: .failed,
                hasPlayedOnce: true,
                bufferedPercent: 0.42
            ) == nil
        )
        #expect(
            PlayerBufferingPolicy.surfaceFeedbackText(
                playbackState: .buffering,
                hasPlayedOnce: true,
                bufferedPercent: 0.99
            ) == nil
        )
        #expect(
            PlayerBufferingPolicy.surfaceFeedbackText(
                playbackState: .buffering,
                hasPlayedOnce: true,
                bufferedPercent: 0.02,
                bufferedSecondsAhead: 2.1
            ) == nil
        )
    }

    @Test
    func bufferReadyAcceptsPlayableSecondsAheadForLongStreams() {
        #expect(PlayerBufferingPolicy.isBufferReady(bufferedPercent: 0.99))
        #expect(!PlayerBufferingPolicy.isBufferReady(bufferedPercent: 0.02, bufferedSecondsAhead: 1.9))
        #expect(PlayerBufferingPolicy.isBufferReady(bufferedPercent: 0.02, bufferedSecondsAhead: 2.0))
        #expect(!PlayerBufferingPolicy.isBufferReady(bufferedPercent: 0.02, bufferedSecondsAhead: .nan))
    }
}

@Suite("PlayerBufferingPolicy - Quality Change Toast")
struct PlayerBufferingPolicyQualityChangeToastTests {

    @Test
    func qualityChangeMessageWithDifferentQualitiesReturnsFormattedString() {
        let message = PlayerBufferingPolicy.qualityChangeMessage(from: "1080p", to: "4K")
        #expect(message == "Quality: 1080p \u{2192} 4K")
    }

    @Test
    func qualityChangeMessageWithSameQualitiesReturnsNil() {
        let message = PlayerBufferingPolicy.qualityChangeMessage(from: "1080p", to: "1080p")
        #expect(message == nil)
    }

    @Test
    func qualityChangeMessageFromHDRToSDR() {
        let message = PlayerBufferingPolicy.qualityChangeMessage(from: "HDR", to: "SDR")
        #expect(message == "Quality: HDR \u{2192} SDR")
    }

    @Test
    func qualityChangeMessageDurationIsThreeSeconds() {
        #expect(PlayerBufferingPolicy.qualityToastDuration == 3.0)
    }
}

@Suite("PlayerBufferingPolicy - Controls Lock")
struct PlayerBufferingPolicyControlsLockTests {

    @Test
    func showsControlsLockAlwaysTrue() {
        #expect(PlayerBufferingPolicy.showsControlsLock == true)
    }
}
