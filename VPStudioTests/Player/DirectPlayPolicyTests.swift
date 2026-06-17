import Foundation
import Testing
@testable import VPStudio

@Suite("Direct Play Policy")
struct DirectPlayPolicyTests {
    struct CaseData: Sendable {
        let label: String
        let stream: StreamInfo
    }

    private static let cases: [CaseData] = [
        CaseData(
            label: "HTTPS mp4 (H.264/SDR/1080p)",
            stream: Fixtures.stream(
                url: "https://cdn.example.com/movie.mp4",
                quality: .hd1080p,
                codec: .h264,
                hdr: .sdr,
                fileName: "Movie.2025.1080p.WEB-DL.mp4"
            )
        ),
        CaseData(
            label: "HTTPS mkv (H.265)",
            stream: Fixtures.stream(
                url: "https://cdn.example.com/movie.mkv",
                quality: .hd1080p,
                codec: .h265,
                hdr: .sdr,
                fileName: "Movie.2025.1080p.BluRay.mkv"
            )
        ),
        CaseData(
            label: "HLS playlist (.m3u8)",
            stream: Fixtures.stream(
                url: "https://cdn.example.com/stream/index.m3u8",
                quality: .hd1080p,
                codec: .h264,
                hdr: .sdr,
                fileName: "Movie.2025.1080p.m3u8"
            )
        ),
        CaseData(
            label: "4K HDR10 mkv",
            stream: Fixtures.stream(
                url: "https://cdn.example.com/movie.4k.mkv",
                quality: .uhd4k,
                codec: .h265,
                hdr: .hdr10,
                fileName: "Movie.2025.2160p.HDR10.mkv"
            )
        ),
        CaseData(
            label: "4K Dolby Vision mkv",
            stream: Fixtures.stream(
                url: "https://cdn.example.com/movie.dv.mkv",
                quality: .uhd4k,
                codec: .h265,
                hdr: .dolbyVision,
                fileName: "Movie.2025.2160p.DV.mkv"
            )
        ),
        CaseData(
            label: "MV-HEVC spatial mov",
            stream: Fixtures.stream(
                url: "https://cdn.example.com/movie.spatial.mov",
                quality: .uhd4k,
                codec: .h265,
                hdr: .sdr,
                fileName: "Movie.2025.MV-HEVC.Spatial.mov"
            )
        ),
        CaseData(
            label: "AV1 webm",
            stream: Fixtures.stream(
                url: "https://cdn.example.com/movie.webm",
                quality: .hd1080p,
                codec: .av1,
                hdr: .sdr,
                fileName: "Movie.2025.1080p.AV1.webm"
            )
        ),
    ]

    @Test(arguments: cases)
    func everyStreamResolvesToDirectPlay(data: CaseData) {
        #expect(
            DirectPlayPolicy.playbackMode(for: data.stream) == .directPlay,
            "\(data.label) must resolve to .directPlay"
        )
        #expect(DirectPlayPolicy.isDirectPlay(data.stream), "\(data.label) must be direct play")
        // Computed StreamInfo accessors mirror the policy.
        #expect(data.stream.playbackMode == .directPlay)
        #expect(data.stream.isDirectPlay)
    }

    @Test func mvHevcFixtureIsRecognizedAsSpatial() {
        // Guards that the MV-HEVC fixture actually exercises the spatial path
        // (so the direct-play assertion above is meaningful for MV-HEVC).
        let mvHevc = Self.cases.first { $0.label.contains("MV-HEVC") }!.stream
        #expect(
            SpatialVideoTitleDetector.stereoMode(fromTitle: mvHevc.fileName) == .mvHevc
        )
        #expect(DirectPlayPolicy.isDirectPlay(mvHevc))
    }

    /// Locks the invariant: every engine the selector can choose is a known
    /// native direct-play engine (AVPlayer or KSPlayer). There is no transcode
    /// engine, and adding one without updating this guard would fail the test.
    @Test(arguments: cases)
    func selectorOnlyEmitsDirectPlayEngines(data: CaseData) {
        let directPlayEngines: Set<PlayerEngineKind> = [.avPlayer, .ksPlayer]
        let selector = PlayerEngineSelector()

        for strategy in PlayerEngineStrategy.allCases {
            let order = selector.engineOrder(for: data.stream, strategy: strategy)
            #expect(!order.isEmpty, "engineOrder must not be empty for \(data.label) / \(strategy.rawValue)")
            for engine in order {
                #expect(
                    directPlayEngines.contains(engine),
                    "\(engine.rawValue) in \(strategy.rawValue) order for \(data.label) is not a direct-play engine"
                )
            }
        }
    }

    /// Belt-and-suspenders: the universe of player engine kinds is exactly the
    /// direct-play set, so no transcode/remux engine can exist undetected.
    @Test func allPlayerEngineKindsAreDirectPlay() {
        #expect(Set(PlayerEngineKind.allCases) == [.avPlayer, .ksPlayer])
    }
}
