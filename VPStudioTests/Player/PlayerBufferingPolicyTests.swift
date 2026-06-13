import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerBufferingPolicy - Buffering Text")
struct PlayerBufferingPolicyBufferingTextTests {

    @Test
    func rebufferTextWithZeroPercentReturnsEllipsis() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 0) == "Rebuffering\u{2026}")
    }

    @Test
    func rebufferTextWithFullPercentReturnsEllipsis() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 1) == "Rebuffering\u{2026}")
    }

    @Test
    func rebufferTextWithOutOfRangeOrNonFinitePercentReturnsEllipsis() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: -0.1) == "Rebuffering\u{2026}")
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 1.1) == "Rebuffering\u{2026}")
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: .nan) == "Rebuffering\u{2026}")
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
    func rebufferTextWithNinetyNinePercentReturnsFormattedString() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 0.99) == "Buffering... 99%")
    }

    @Test
    func rebufferTextTruncatesFractionalPercentTowardZero() {
        #expect(PlayerBufferingPolicy.rebufferText(bufferedPercent: 0.999) == "Buffering... 99%")
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
