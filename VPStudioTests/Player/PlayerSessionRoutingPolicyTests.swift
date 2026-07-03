import Foundation
import Testing
@testable import VPStudio

// MARK: - PlayerSessionRouting Static Methods Tests

@Suite("PlayerSessionRouting — Static Methods")
struct PlayerSessionRoutingStaticTests {

    // MARK: - sessionStreams

    @Test func sessionStreamsPutsPrimaryFirst() {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv")
        let available = [
            Fixtures.stream(url: "https://cdn.example.com/first.mkv", fileName: "first.mkv"),
            Fixtures.stream(url: "https://cdn.example.com/second.mkv", fileName: "second.mkv"),
        ]

        let result = PlayerSessionRouting.sessionStreams(primary: primary, available: available)

        #expect(result.first?.id == primary.id)
        #expect(result.count == 3)
    }

    @Test func sessionStreamsDeduplicatesByID() {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv")
        let available = [
            Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv"),
            Fixtures.stream(url: "https://cdn.example.com/other.mkv", fileName: "other.mkv"),
        ]

        let result = PlayerSessionRouting.sessionStreams(primary: primary, available: available)

        // Primary should appear once even when it is also present in available streams.
        #expect(result.filter { $0.id == primary.id }.count == 1)
        #expect(result.count == 2)
    }

    @Test func sessionStreamsWithEmptyAvailable() {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv")

        let result = PlayerSessionRouting.sessionStreams(primary: primary, available: [])

        #expect(result.count == 1)
        #expect(result.first?.id == primary.id)
    }

    @Test func sessionStreamsPreservesOrderOfDistinctStreams() {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv")
        let s1 = Fixtures.stream(url: "https://cdn.example.com/stream-1.mkv", fileName: "stream-1.mkv")
        let s2 = Fixtures.stream(url: "https://cdn.example.com/stream-2.mkv", fileName: "stream-2.mkv")
        let s3 = Fixtures.stream(url: "https://cdn.example.com/stream-3.mkv", fileName: "stream-3.mkv")

        let result = PlayerSessionRouting.sessionStreams(primary: primary, available: [s3, s1, s2])

        #expect(result[0].id == primary.id)
        #expect(result[1].id == s3.id)
        #expect(result[2].id == s1.id)
        #expect(result[3].id == s2.id)
    }

    @Test func sessionStreamsDeduplicatesBothPrimaryAndAvailable() {
        let primary = Fixtures.stream(url: "https://cdn.example.com/shared.mkv", fileName: "shared.mkv")
        let available = [
            Fixtures.stream(url: "https://cdn.example.com/shared.mkv", fileName: "shared.mkv"),
            Fixtures.stream(url: "https://cdn.example.com/other.mkv", fileName: "other.mkv"),
        ]

        let result = PlayerSessionRouting.sessionStreams(primary: primary, available: available)

        #expect(result.count == 2)
        #expect(result.first?.id == primary.id)
    }

    @Test func sessionStreamsWithMultipleDuplicates() {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv")
        let available = [
            Fixtures.stream(url: "https://cdn.example.com/dup1.mkv", fileName: "dup1.mkv"),
            Fixtures.stream(url: "https://cdn.example.com/dup1.mkv", fileName: "dup1.mkv"),
            Fixtures.stream(url: "https://cdn.example.com/dup2.mkv", fileName: "dup2.mkv"),
            Fixtures.stream(url: "https://cdn.example.com/dup2.mkv", fileName: "dup2.mkv"),
        ]

        let result = PlayerSessionRouting.sessionStreams(primary: primary, available: available)

        #expect(result.count == 3) // primary + dup1 + dup2
    }

    @Test func sessionStreamsDropsMissingLocalFallbacks() {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv")
        let missingLocal = Fixtures.stream(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("missing-fallback-\(UUID().uuidString).mkv")
                .absoluteString,
            fileName: "missing-fallback.mkv"
        )
        let remoteFallback = Fixtures.stream(url: "https://cdn.example.com/fallback.mkv", fileName: "fallback.mkv")

        let result = PlayerSessionRouting.sessionStreams(primary: primary, available: [missingLocal, remoteFallback])

        #expect(result.map(\.id) == [primary.id, remoteFallback.id])
        #expect(result.contains(where: { $0.id == missingLocal.id }) == false)
    }

    // MARK: - playbackQueue

    @Test func playbackQueueSmallQueueReturnsUnchanged() async {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv")
        let available = [
            Fixtures.stream(url: "https://cdn.example.com/first.mkv", fileName: "first.mkv"),
        ]

        let result = await PlayerSessionRouting.playbackQueue(primary: primary, available: available)

        #expect(result.first?.id == primary.id)
        #expect(result.count == 2)
    }

    @Test func playbackQueueDropsMissingLocalFallbacksBeforeSorting() async {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv")
        let missingLocal = Fixtures.stream(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("missing-queue-fallback-\(UUID().uuidString).mkv")
                .absoluteString,
            fileName: "missing-queue-fallback.mkv"
        )
        let remoteFallback = Fixtures.stream(url: "https://cdn.example.com/fallback.mkv", fileName: "fallback.mkv")

        let result = await PlayerSessionRouting.playbackQueue(primary: primary, available: [missingLocal, remoteFallback])

        #expect(result.map(\.id) == [primary.id, remoteFallback.id])
        #expect(result.contains(where: { $0.id == missingLocal.id }) == false)
    }

    @Test func playbackQueueLargeQueueSortsFallbackByScore() async {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv")
        let available = [
            Fixtures.stream(url: "https://cdn.example.com/low.mkv", quality: .sd, fileName: "low.mkv"),
            Fixtures.stream(url: "https://cdn.example.com/high.mkv", quality: .uhd4k, fileName: "high.mkv"),
            Fixtures.stream(url: "https://cdn.example.com/mid.mkv", quality: .hd1080p, fileName: "mid.mkv"),
        ]

        let result = await PlayerSessionRouting.playbackQueue(primary: primary, available: available)

        #expect(result.first?.id == primary.id) // Primary always first
        #expect(result[1].quality == .uhd4k) // Highest quality first
        #expect(result[2].quality == .hd1080p)
        #expect(result[3].quality == .sd)
    }

    @Test func playbackQueueLargeQueueSortsByFallbackScoreForSameQuality() async {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", quality: .hd1080p, fileName: "primary.mkv")
        let available = [
            Fixtures.stream(url: "https://cdn.example.com/same1.mkv", quality: .hd1080p, hdr: .sdr, fileName: "same1.mkv"),
            Fixtures.stream(url: "https://cdn.example.com/same2.mkv", quality: .hd1080p, hdr: .dolbyVision, fileName: "same2.mkv"),
        ]

        let result = await PlayerSessionRouting.playbackQueue(primary: primary, available: available)

        #expect(result.first?.id == primary.id)
        // DV should come before SDR within same quality tier
        let fallback = Array(result.dropFirst())
        let dvIndex = fallback.firstIndex { $0.hdr == .dolbyVision }
        let sdrIndex = fallback.firstIndex { $0.hdr == .sdr }
        #expect(dvIndex! < sdrIndex!)
    }

    @Test func playbackQueueLargeQueueConsidersSizeAsSecondarySort() async {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", quality: .hd1080p, fileName: "primary.mkv")
        let available = [
            Fixtures.stream(url: "https://cdn.example.com/small.mkv", quality: .hd1080p, fileName: "small.mkv", sizeBytes: 1_000_000_000),
            Fixtures.stream(url: "https://cdn.example.com/large.mkv", quality: .hd1080p, fileName: "large.mkv", sizeBytes: 8_000_000_000),
        ]

        let result = await PlayerSessionRouting.playbackQueue(primary: primary, available: available)

        #expect(result.first?.id == primary.id)
        // Larger file should come first within same quality (fallbackScore considers size)
        let largeIndex = result.firstIndex { $0.streamURL.path.contains("large") }
        let smallIndex = result.firstIndex { $0.streamURL.path.contains("small") }
        #expect(largeIndex! < smallIndex!)
    }

    @Test func playbackQueueWithEmptyAvailable() async {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", fileName: "primary.mkv")

        let result = await PlayerSessionRouting.playbackQueue(primary: primary, available: [])

        #expect(result.count == 1)
        #expect(result.first?.id == primary.id)
    }

    @Test func playbackQueueWithManyStreamsSortsCorrectly() async {
        let primary = Fixtures.stream(url: "https://cdn.example.com/primary.mkv", quality: .hd1080p, fileName: "primary.mkv")
        var available: [StreamInfo] = []
        for i in 0..<20 {
            available.append(Fixtures.stream(
                url: "https://cdn.example.com/stream-\(i).mkv",
                quality: i % 3 == 0 ? .uhd4k : (i % 2 == 0 ? .hd1080p : .hd720p),
                hdr: i % 2 == 0 ? .dolbyVision : .sdr,
                fileName: "stream-\(i).mkv",
                sizeBytes: Int64(i * 100_000_000)
            ))
        }

        let result = await PlayerSessionRouting.playbackQueue(primary: primary, available: available)

        #expect(result.first?.id == primary.id) // Primary first
        #expect(result.count == 21) // primary + 20 available

        // Quality tier dominance check: all 4K should come before all 1080p
        let fallback = Array(result.dropFirst())
        let fourKIndices = fallback.enumerated().filter { $0.element.quality == .uhd4k }.map { $0.offset }
        let HD1080pIndices = fallback.enumerated().filter { $0.element.quality == .hd1080p }.map { $0.offset }
        let HD720pIndices = fallback.enumerated().filter { $0.element.quality == .hd720p }.map { $0.offset }

        if let first4K = fourKIndices.first, let first1080p = HD1080pIndices.first {
            #expect(first4K < first1080p)
        }
        if let first1080p = HD1080pIndices.first, let first720p = HD720pIndices.first {
            #expect(first1080p < first720p)
        }
    }
}

// MARK: - FallbackScore Tests

@Suite("PlayerSessionRouting — FallbackScore")
struct FallbackScoreTests {

    @Test func higherQualityScoresHigher() {
        let uhd4k = Fixtures.stream(url: "https://cdn.example.com/4k.mkv", quality: .uhd4k, fileName: "4k.mkv")
        let hd1080p = Fixtures.stream(url: "https://cdn.example.com/1080p.mkv", quality: .hd1080p, fileName: "1080p.mkv")

        let score4k = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: uhd4k)
        let score1080p = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: hd1080p)

        #expect(score4k > score1080p)
    }

    @Test func dolbyVisionAddsScoreBonus() {
        let dv = Fixtures.stream(url: "https://cdn.example.com/dv.mkv", quality: .hd1080p, hdr: .dolbyVision, fileName: "dv.mkv")
        let sdr = Fixtures.stream(url: "https://cdn.example.com/sdr.mkv", quality: .hd1080p, hdr: .sdr, fileName: "sdr.mkv")

        let scoreDV = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: dv)
        let scoreSDR = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: sdr)

        #expect(scoreDV > scoreSDR)
    }

    @Test func hdr10PlusAddsScoreBonus() {
        let hdr10plus = Fixtures.stream(url: "https://cdn.example.com/hdr10plus.mkv", quality: .hd1080p, hdr: .hdr10Plus, fileName: "hdr10plus.mkv")
        let sdr = Fixtures.stream(url: "https://cdn.example.com/sdr.mkv", quality: .hd1080p, hdr: .sdr, fileName: "sdr.mkv")

        let scoreH10P = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: hdr10plus)
        let scoreSDR = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: sdr)

        #expect(scoreH10P > scoreSDR)
    }

    @Test func hlgAddsScoreBonus() {
        let hlg = Fixtures.stream(url: "https://cdn.example.com/hlg.mkv", quality: .hd1080p, hdr: .hlg, fileName: "hlg.mkv")
        let sdr = Fixtures.stream(url: "https://cdn.example.com/sdr.mkv", quality: .hd1080p, hdr: .sdr, fileName: "sdr.mkv")

        let scoreHLG = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: hlg)
        let scoreSDR = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: sdr)

        #expect(scoreHLG > scoreSDR)
    }

    @Test func spatialAudioHintAddsScoreBonus() {
        let atmos = Fixtures.stream(url: "https://cdn.example.com/atmos.mkv", quality: .hd1080p, audio: .atmos, fileName: "atmos.mkv")
        let aac = Fixtures.stream(url: "https://cdn.example.com/aac.mkv", quality: .hd1080p, audio: .aac, fileName: "aac.mkv")

        let scoreAtmos = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: atmos)
        let scoreAAC = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: aac)

        #expect(scoreAtmos > scoreAAC)
    }

    @Test func h265CodecAddsScoreBonusOverH264() {
        let h265 = Fixtures.stream(url: "https://cdn.example.com/h265.mkv", quality: .hd1080p, codec: .h265, fileName: "h265.mkv")
        let h264 = Fixtures.stream(url: "https://cdn.example.com/h264.mkv", quality: .hd1080p, codec: .h264, fileName: "h264.mkv")

        let score265 = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: h265)
        let score264 = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: h264)

        #expect(score265 > score264)
    }

    @Test func av1CodecAddsScoreBonus() {
        let av1 = Fixtures.stream(url: "https://cdn.example.com/av1.mkv", quality: .hd1080p, codec: .av1, fileName: "av1.mkv")
        let h264 = Fixtures.stream(url: "https://cdn.example.com/h264.mkv", quality: .hd1080p, codec: .h264, fileName: "h264.mkv")

        let scoreAV1 = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: av1)
        let scoreH264 = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: h264)

        #expect(scoreAV1 > scoreH264)
    }

    @Test func sizeBytesContributesToScore() {
        let large = Fixtures.stream(url: "https://cdn.example.com/large.mkv", quality: .hd1080p, fileName: "large.mkv", sizeBytes: 8_000_000_000)
        let small = Fixtures.stream(url: "https://cdn.example.com/small.mkv", quality: .hd1080p, fileName: "small.mkv", sizeBytes: 1_000_000_000)

        let scoreLarge = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: large)
        let scoreSmall = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: small)

        #expect(scoreLarge > scoreSmall)
    }

    @Test func sizeBytesCapsAt4GBContribution() {
        // 4GB should cap the size contribution; larger files do not score higher.
        let fourGB = Fixtures.stream(url: "https://cdn.example.com/4gb.mkv", quality: .hd1080p, fileName: "4gb.mkv", sizeBytes: 4_000_000_000)
        let fiveGB = Fixtures.stream(url: "https://cdn.example.com/5gb.mkv", quality: .hd1080p, fileName: "5gb.mkv", sizeBytes: 5_000_000_000)

        let score4GB = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: fourGB)
        let score5GB = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: fiveGB)

        #expect(score4GB == score5GB)
    }

    @Test func sizeBytesZeroContributesNothing() {
        let noSize = Fixtures.stream(url: "https://cdn.example.com/nosize.mkv", quality: .hd1080p, fileName: "nosize.mkv", sizeBytes: nil)
        let withSize = Fixtures.stream(url: "https://cdn.example.com/sized.mkv", quality: .hd1080p, fileName: "sized.mkv", sizeBytes: 2_000_000_000)

        let scoreNoSize = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: noSize)
        let scoreWithSize = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: withSize)

        #expect(scoreNoSize < scoreWithSize)
    }

    @Test func sourceQualityTierContributes() {
        let bluray = Fixtures.stream(url: "https://cdn.example.com/br.mkv", quality: .hd1080p, source: .bluRay, fileName: "br.mkv")
        let webdl = Fixtures.stream(url: "https://cdn.example.com/webdl.mkv", quality: .hd1080p, source: .webDL, fileName: "webdl.mkv")

        let scoreBR = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: bluray)
        let scoreWebDL = PlayerSessionRoutingFallbackScoreTestsHelper.fallbackScore(for: webdl)

        #expect(scoreBR > scoreWebDL)
    }
}

// MARK: - FallbackScore Test Helper

enum PlayerSessionRoutingFallbackScoreTestsHelper {
    static func fallbackScore(for stream: StreamInfo) -> Int {
        // This replicates the private fallbackScore logic from PlayerSessionRouting
        // to test its behavior in isolation
        var score = 0
        score += stream.quality.sortOrder * 140
        score += stream.source.qualityTier * 24

        switch stream.hdr {
        case .dolbyVision:
            score += 40
        case .hdr10Plus, .hdr10:
            score += 28
        case .hlg:
            score += 18
        case .sdr:
            break
        }

        if stream.audio.spatialAudioHint {
            score += 22
        }

        switch stream.codec {
        case .h265:
            score += 14
        case .av1:
            score += 12
        case .h264:
            score += 10
        case .xvid:
            score += 4
        case .unknown:
            break
        }

        if let bytes = stream.sizeBytes {
            let gigabytes = min(max(0, Int(bytes / 1_000_000_000)), 4)
            score += min(gigabytes * 3, 12)
        }

        return score
    }
}
