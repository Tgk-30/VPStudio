import Testing
import Foundation
@testable import VPStudio

@Suite("StreamInfo Codable Round-Trip")
struct StreamInfoCodableTests {
    @Test("StreamInfo encodes and decodes correctly")
    func streamInfoCodableRoundTrip() throws {
        let original = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "movie.mp4",
            sizeBytes: 1_073_741_824,
            debridService: "realDebrid",
            recoveryContext: nil
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StreamInfo.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.streamURL == original.streamURL)
        #expect(decoded.quality == original.quality)
        #expect(decoded.codec == original.codec)
        #expect(decoded.audio == original.audio)
        #expect(decoded.source == original.source)
        #expect(decoded.hdr == original.hdr)
        #expect(decoded.fileName == original.fileName)
        #expect(decoded.sizeBytes == original.sizeBytes)
        #expect(decoded.debridService == original.debridService)
    }

    @Test("StreamInfo with StreamRecoveryContext encodes and decodes correctly")
    func streamInfoWithRecoveryContextCodableRoundTrip() throws {
        let recoveryContext = StreamRecoveryContext(
            infoHash: "abc123",
            preferredService: .realDebrid,
            seasonNumber: 1,
            episodeNumber: 5,
            torrentId: "torrent-123",
            resolvedDebridService: "realDebrid",
            resolvedFileName: "episode.mkv",
            resolvedFileSizeBytes: 500_000_000
        )!

        let original = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mkv")!,
            quality: .uhd4k,
            codec: .h265,
            audio: .atmos,
            source: .bluRay,
            hdr: .dolbyVision,
            fileName: "episode.mkv",
            sizeBytes: 5_000_000_000,
            debridService: "realDebrid",
            recoveryContext: recoveryContext
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StreamInfo.self, from: encoded)

        #expect(decoded.recoveryContext != nil)
        #expect(decoded.recoveryContext?.infoHash == "abc123")
        #expect(decoded.recoveryContext?.preferredService == .realDebrid)
        #expect(decoded.recoveryContext?.seasonNumber == 1)
        #expect(decoded.recoveryContext?.episodeNumber == 5)
        #expect(decoded.recoveryContext?.torrentId == "torrent-123")
        #expect(decoded.recoveryContext?.resolvedDebridService == "realDebrid")
        #expect(decoded.recoveryContext?.resolvedFileName == "episode.mkv")
        #expect(decoded.recoveryContext?.resolvedFileSizeBytes == 500_000_000)
    }

    @Test("StreamInfo with nil sizeBytes encodes and decodes correctly")
    func streamInfoNilSizeBytesCodableRoundTrip() throws {
        let original = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "movie.mp4",
            sizeBytes: nil,
            debridService: "realDebrid"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StreamInfo.self, from: encoded)

        #expect(decoded.sizeBytes == nil)
        #expect(decoded.sizeString == "")
    }

    @Test("StreamInfo id is stable across codable round-trip")
    func streamInfoIdStabilityAcrossCodable() throws {
        let original = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4?token=abc")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "movie.mp4",
            sizeBytes: 1_000_000,
            debridService: "realDebrid"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StreamInfo.self, from: encoded)

        #expect(decoded.id == original.id)
    }

    @Test("StreamInfo request headers are runtime-only")
    func streamInfoRequestHeadersAreRuntimeOnly() throws {
        let original = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "movie.mp4",
            sizeBytes: 1_000_000,
            debridService: "realDebrid",
            requestHeaders: [
                "User-Agent": "Stremio",
                "Bad\nName": "ignored",
                "X-Blank": " "
            ]
        )

        #expect(original.requestHeaders == ["User-Agent": "Stremio"])

        let encoded = try JSONEncoder().encode(original)
        let encodedString = String(data: encoded, encoding: .utf8) ?? ""
        let decoded = try JSONDecoder().decode(StreamInfo.self, from: encoded)

        #expect(!encodedString.contains("User-Agent"))
        #expect(decoded.requestHeaders == nil)
    }

    // MARK: - BUG 1: equality/hashing consistent with Codable (excludes requestHeaders)

    @Test("Equality ignores runtime-only requestHeaders")
    func equalityExcludesRequestHeaders() {
        let base = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "movie.mp4",
            sizeBytes: 1_000_000,
            debridService: "realDebrid"
        )
        let withHeaders = base.withRequestHeaders(["User-Agent": "Stremio"])
        let withoutHeaders = base.withRequestHeaders(nil)

        #expect(withHeaders == withoutHeaders)
        #expect(withHeaders.hashValue == withoutHeaders.hashValue)
    }

    @Test("A header-carrying stream equals its own Codable round-trip")
    func equalsRoundTripDespiteHeaders() throws {
        let original = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "movie.mp4",
            sizeBytes: 1_000_000,
            debridService: "realDebrid",
            requestHeaders: ["User-Agent": "Stremio"]
        )

        let decoded = try JSONDecoder().decode(StreamInfo.self, from: JSONEncoder().encode(original))
        #expect(original.requestHeaders != nil)
        #expect(decoded.requestHeaders == nil)
        #expect(original == decoded)
        #expect(original.hashValue == decoded.hashValue)
    }

    @Test("Differing encoded fields still compare unequal")
    func unequalWhenEncodedFieldDiffers() {
        let a = StreamInfo(
            streamURL: URL(string: "https://example.com/a.mp4")!,
            quality: .hd1080p, codec: .h264, audio: .aac, source: .webDL, hdr: .sdr,
            fileName: "a.mp4", sizeBytes: 1, debridService: "realDebrid"
        )
        let b = StreamInfo(
            streamURL: URL(string: "https://example.com/b.mp4")!,
            quality: .hd1080p, codec: .h264, audio: .aac, source: .webDL, hdr: .sdr,
            fileName: "a.mp4", sizeBytes: 1, debridService: "realDebrid"
        )
        #expect(a != b)
    }
}

@Suite("StreamRecoveryContext Codable Round-Trip")
struct StreamRecoveryContextCodableTests {
    @Test("StreamRecoveryContext encodes and decodes correctly")
    func streamRecoveryContextCodableRoundTrip() throws {
        let original = StreamRecoveryContext(
            infoHash: "abc123",
            preferredService: .realDebrid,
            seasonNumber: 1,
            episodeNumber: 5,
            torrentId: "torrent-456",
            resolvedDebridService: "realDebrid",
            resolvedFileName: "movie.mkv",
            resolvedFileSizeBytes: 1_500_000_000
        )!

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StreamRecoveryContext.self, from: encoded)

        #expect(decoded.infoHash == original.infoHash)
        #expect(decoded.preferredService == original.preferredService)
        #expect(decoded.seasonNumber == original.seasonNumber)
        #expect(decoded.episodeNumber == original.episodeNumber)
        #expect(decoded.torrentId == original.torrentId)
        #expect(decoded.resolvedDebridService == original.resolvedDebridService)
        #expect(decoded.resolvedFileName == original.resolvedFileName)
        #expect(decoded.resolvedFileSizeBytes == original.resolvedFileSizeBytes)
    }

    @Test("StreamRecoveryContext with nil optionals encodes and decodes correctly")
    func streamRecoveryContextNilOptionalsCodableRoundTrip() throws {
        let original = StreamRecoveryContext(
            infoHash: "xyz789",
            preferredService: nil,
            seasonNumber: nil,
            episodeNumber: nil,
            torrentId: nil,
            resolvedDebridService: nil,
            resolvedFileName: nil,
            resolvedFileSizeBytes: nil
        )!

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StreamRecoveryContext.self, from: encoded)

        #expect(decoded.infoHash == original.infoHash)
        #expect(decoded.preferredService == nil)
        #expect(decoded.seasonNumber == nil)
        #expect(decoded.episodeNumber == nil)
        #expect(decoded.torrentId == nil)
        #expect(decoded.resolvedDebridService == nil)
        #expect(decoded.resolvedFileName == nil)
        #expect(decoded.resolvedFileSizeBytes == nil)
    }

    @Test("StreamRecoveryContext infoHash is normalized to lowercase on decode")
    func streamRecoveryContextInfoHashNormalization() throws {
        let original = StreamRecoveryContext(
            infoHash: "ABC123",
            preferredService: .realDebrid
        )!

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StreamRecoveryContext.self, from: encoded)

        #expect(decoded.infoHash == "abc123")
    }
}
