import Testing
import Foundation
@testable import VPStudio

@Suite("TorrentResult Codable Round-Trip")
struct TorrentResultCodableTests {
    @Test("TorrentResult encodes and decodes correctly")
    func torrentResultCodableRoundTrip() throws {
        let original = TorrentResult(
            infoHash: "abc123def456",
            title: "Test.Movie.2024.1080p.BluRay",
            sizeBytes: 2_147_483_648,
            seeders: 100,
            leechers: 20,
            quality: .hd1080p,
            codec: .h264,
            audio: .dtsHDMA,
            source: .bluRay,
            hdr: .hdr10,
            indexerName: "MyIndexer",
            magnetURI: "magnet:?xt=urn:btih:abc123"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TorrentResult.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.infoHash == original.infoHash)
        #expect(decoded.title == original.title)
        #expect(decoded.sizeBytes == original.sizeBytes)
        #expect(decoded.seeders == original.seeders)
        #expect(decoded.leechers == original.leechers)
        #expect(decoded.quality == original.quality)
        #expect(decoded.codec == original.codec)
        #expect(decoded.audio == original.audio)
        #expect(decoded.source == original.source)
        #expect(decoded.hdr == original.hdr)
        #expect(decoded.indexerName == original.indexerName)
        #expect(decoded.magnetURI == original.magnetURI)
    }

    @Test("TorrentResult with nil magnetURI encodes and decodes correctly")
    func torrentResultNilMagnetURICodableRoundTrip() throws {
        let original = TorrentResult(
            infoHash: "abc123",
            title: "Test.Movie",
            sizeBytes: 1_000_000,
            seeders: 50,
            leechers: 10,
            quality: .uhd4k,
            codec: .h265,
            audio: .atmos,
            source: .webDL,
            hdr: .dolbyVision,
            indexerName: "Indexer1",
            magnetURI: nil
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TorrentResult.self, from: encoded)

        #expect(decoded.magnetURI == nil)
        #expect(decoded.infoHash == original.infoHash)
    }

    @Test("TorrentResult isCached and cachedOnService encode and decode correctly")
    func torrentResultCachedFieldsCodableRoundTrip() throws {
        var original = TorrentResult(
            infoHash: "abc123",
            title: "Test.Movie",
            sizeBytes: 1_000_000,
            seeders: 50,
            leechers: 10,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            indexerName: "Indexer1"
        )
        original.isCached = true
        original.cachedOnService = "realDebrid"

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TorrentResult.self, from: encoded)

        #expect(decoded.isCached == original.isCached)
        #expect(decoded.cachedOnService == original.cachedOnService)
    }

    @Test("TorrentResult all unknown qualities encode and decode correctly")
    func torrentResultAllUnknownCodableRoundTrip() throws {
        let original = TorrentResult(
            infoHash: "abc123",
            title: "Unknown Movie",
            sizeBytes: 500_000_000,
            seeders: 0,
            leechers: 0,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            indexerName: "Indexer1"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TorrentResult.self, from: encoded)

        #expect(decoded.quality == .unknown)
        #expect(decoded.codec == .unknown)
        #expect(decoded.audio == .unknown)
        #expect(decoded.source == .unknown)
        #expect(decoded.hdr == .sdr)
    }

    @Test("TorrentResult id combines infoHash and indexerName")
    func torrentResultIdFormat() throws {
        let original = TorrentResult(
            infoHash: "abc123",
            title: "Test",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            indexerName: "MyIndexer"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TorrentResult.self, from: encoded)

        #expect(decoded.id == "abc123-MyIndexer")
    }
}
