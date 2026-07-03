import Foundation
import Testing
@testable import VPStudio

@Suite("TimeFormatting")
struct TimeFormattingTests {
    @Test func formattedDurationHandlesZero() {
        #expect(TimeInterval(0).formattedDuration == "0:00")
        #expect(TimeInterval(-0).formattedDuration == "0:00")
    }

    @Test func formattedDurationHandlesSecondsOnly() {
        #expect(TimeInterval(1).formattedDuration == "0:01")
        #expect(TimeInterval(5).formattedDuration == "0:05")
        #expect(TimeInterval(30).formattedDuration == "0:30")
        #expect(TimeInterval(59).formattedDuration == "0:59")
    }

    @Test func formattedDurationHandlesMinutesAndSeconds() {
        #expect(TimeInterval(60).formattedDuration == "1:00")
        #expect(TimeInterval(65).formattedDuration == "1:05")
        #expect(TimeInterval(90).formattedDuration == "1:30")
        #expect(TimeInterval(119).formattedDuration == "1:59")
        #expect(TimeInterval(600).formattedDuration == "10:00")
        #expect(TimeInterval(3599).formattedDuration == "59:59")
    }

    @Test func formattedDurationHandlesHours() {
        #expect(TimeInterval(3600).formattedDuration == "1:00:00")
        #expect(TimeInterval(3661).formattedDuration == "1:01:01")
        #expect(TimeInterval(7200).formattedDuration == "2:00:00")
        #expect(TimeInterval(86399).formattedDuration == "23:59:59")
        #expect(TimeInterval(36000).formattedDuration == "10:00:00")
    }

    @Test func formattedDurationHandlesLargeValues() {
        #expect(TimeInterval(90061).formattedDuration == "25:01:01")
        #expect(TimeInterval(86400).formattedDuration == "24:00:00")
    }

    @Test func formattedDurationPadsMinutesAndSeconds() {
        #expect(TimeInterval(61).formattedDuration == "1:01")
        #expect(TimeInterval(3601).formattedDuration == "1:00:01")
    }

    @Test func formattedDurationHandlesNegativeValues() {
        #expect(TimeInterval(-1).formattedDuration == "0:00")
        #expect(TimeInterval(-3600).formattedDuration == "0:00")
    }

    @Test func formattedDurationHandlesNonFiniteValues() {
        #expect((TimeInterval)(Double.infinity).formattedDuration == "0:00")
        #expect((TimeInterval)(-Double.infinity).formattedDuration == "0:00")
        #expect((TimeInterval)(Double.nan).formattedDuration == "0:00")
    }

    @Test func formattedDurationPreservesDecimalPrecision() {
        #expect(TimeInterval(1.5).formattedDuration == "0:01")
        #expect(TimeInterval(59.9).formattedDuration == "0:59")
        #expect(TimeInterval(3600.7).formattedDuration == "1:00:00")
    }
}