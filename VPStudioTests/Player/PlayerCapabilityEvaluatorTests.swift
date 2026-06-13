import Testing
import Foundation
@testable import VPStudio

@Suite("PlayerCapabilityEvaluator")
struct PlayerCapabilityEvaluatorTests {

    private func stream(
        quality: VideoQuality = .hd1080p,
        hdr: HDRFormat = .sdr,
        audio: AudioFormat = .aac
    ) -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://example.com/video.mp4")!,
            quality: quality,
            codec: .h264,
            audio: audio,
            source: .unknown,
            hdr: hdr,
            fileName: "video.mp4",
            sizeBytes: nil,
            debridService: "test"
        )
    }

    @Test func noWarningsForPlainStream() {
        let warnings = PlayerCapabilityEvaluator.warnings(for: stream())
        #expect(warnings.isEmpty)
    }

    @Test func warnsFor4KStream() {
        let warnings = PlayerCapabilityEvaluator.warnings(for: stream(quality: .uhd4k))
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("4K") == true)
    }

    @Test func warnsForHDRStream() {
        let warnings = PlayerCapabilityEvaluator.warnings(for: stream(hdr: .hdr10))
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("HDR") == true)
    }

    @Test func warnsForDolbyVision() {
        let warnings = PlayerCapabilityEvaluator.warnings(for: stream(hdr: .dolbyVision))
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("HDR source (DV)") == true)
    }

    @Test func warnsForSpatialAudio() {
        let warnings = PlayerCapabilityEvaluator.warnings(for: stream(audio: .atmos))
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("Spatial") == true)
    }

    @Test func warnsForDtsHDMA() {
        let warnings = PlayerCapabilityEvaluator.warnings(for: stream(audio: .dtsHDMA))
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("Spatial") == true)
    }

    @Test func warnsForTrueHD() {
        let warnings = PlayerCapabilityEvaluator.warnings(for: stream(audio: .trueHD))
        #expect(warnings.count == 1)
        #expect(warnings.first?.contains("Spatial") == true)
    }

    @Test func noWarningForNonSpatialAudio() {
        let warnings = PlayerCapabilityEvaluator.warnings(for: stream(audio: .aac))
        #expect(warnings.isEmpty)
    }

    @Test func cumulativeWarningsFor4KHDRAtmos() {
        let warnings = PlayerCapabilityEvaluator.warnings(for: stream(
            quality: .uhd4k,
            hdr: .dolbyVision,
            audio: .atmos
        ))
        #expect(warnings.count == 3)
    }
}
