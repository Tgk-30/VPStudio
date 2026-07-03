import Foundation
import Testing
@testable import VPStudio

// MARK: - StreamInfo Computed Properties

@Suite("StreamInfoComputedProperties")
struct StreamInfoComputedPropertiesTests {

    private func makeStream(
        url: URL = URL(string: "https://example.com/video.mp4")!,
        quality: VideoQuality = .hd1080p,
        codec: VideoCodec = .h264,
        audio: AudioFormat = .aac,
        source: SourceType = .webDL,
        hdr: HDRFormat = .sdr,
        fileName: String = "video.mp4",
        sizeBytes: Int64? = 1_073_741_824,
        debridService: String = "realDebrid"
    ) -> StreamInfo {
        StreamInfo(
            streamURL: url,
            quality: quality,
            codec: codec,
            audio: audio,
            source: source,
            hdr: hdr,
            fileName: fileName,
            sizeBytes: sizeBytes,
            debridService: debridService
        )
    }

    @Test func idIncludesDebridServiceAndFileName() {
        let stream = makeStream()
        #expect(stream.id.contains("realDebrid"))
        #expect(stream.id.contains("video.mp4"))
    }

    @Test func idStripsQueryParametersFromURL() {
        let url = URL(string: "https://example.com/video.mp4?token=abc&expires=123")!
        let stream = makeStream(url: url)
        let idWithoutQuery = "realDebrid-video.mp4-1080p-H.264-https://example.com/video.mp4"
        #expect(stream.id == idWithoutQuery)
    }

    @Test func idStripsFragmentFromURL() {
        let url = URL(string: "https://example.com/video.mp4#section")!
        let stream = makeStream(url: url)
        #expect(!stream.id.contains("#"))
    }

    @Test func sizeStringFormatsGB() {
        let stream = makeStream(sizeBytes: 2_147_483_648)
        #expect(stream.sizeString == "2.0 GB")
    }

    @Test func sizeStringFormatsMB() {
        let stream = makeStream(sizeBytes: 524_288_000)
        #expect(stream.sizeString == "500 MB")
    }

    @Test func sizeStringUsesGBAtOneGiBThreshold() {
        let stream = makeStream(sizeBytes: 1_073_741_824)
        #expect(stream.sizeString == "1.0 GB")
    }

    @Test func sizeStringRoundsTinyByteCountsToZeroMB() {
        let stream = makeStream(sizeBytes: 512)
        #expect(stream.sizeString == "0 MB")
    }

    @Test func sizeStringReturnsEmptyWhenNil() {
        let stream = makeStream(sizeBytes: nil)
        #expect(stream.sizeString == "")
    }

    @Test func qualityBadgeIncludesNonDefaults() {
        let stream = makeStream(quality: .uhd4k, codec: .h265, audio: .atmos, hdr: .dolbyVision)
        let badge = stream.qualityBadge
        #expect(badge.contains("4K"))
        #expect(badge.contains("DV"))
        #expect(badge.contains("H.265"))
        #expect(badge.contains("Atmos"))
    }

    @Test func qualityBadgeOmitsUnknownQuality() {
        let stream = makeStream(quality: .unknown)
        #expect(!stream.qualityBadge.contains("unknown"))
    }

    @Test func qualityBadgeOmitsSDR() {
        let stream = makeStream(hdr: .sdr)
        #expect(!stream.qualityBadge.contains("SDR"))
    }

    @Test func qualityBadgeOmitsUnknownCodec() {
        let stream = makeStream(codec: .unknown)
        #expect(!stream.qualityBadge.contains("unknown"))
    }

    @Test func qualityBadgeOmitsUnknownAudio() {
        let stream = makeStream(audio: .unknown)
        #expect(!stream.qualityBadge.contains("unknown"))
    }

    @Test func qualityBadgeEmptyWhenAllDefaults() {
        let stream = makeStream(quality: .unknown, codec: .unknown, audio: .unknown)
        #expect(stream.qualityBadge == "")
    }

    @Test func remoteTransferIDFromRecoveryContext() {
        let context = StreamRecoveryContext(infoHash: "abc123", torrentId: "torrent-1")
        let stream = makeStream().withRecoveryContext(context)
        #expect(stream.remoteTransferID == "torrent-1")
    }

    @Test func remoteTransferIDNilWithoutContext() {
        let stream = makeStream()
        #expect(stream.remoteTransferID == nil)
    }

    @Test func initializerNormalizesRequestHeaders() {
        let stream = makeStream().withRequestHeaders(nil)
        let initialized = StreamInfo(
            streamURL: stream.streamURL,
            quality: stream.quality,
            codec: stream.codec,
            audio: stream.audio,
            source: stream.source,
            hdr: stream.hdr,
            fileName: stream.fileName,
            sizeBytes: stream.sizeBytes,
            debridService: stream.debridService,
            requestHeaders: [
                " Authorization ": " Bearer token ",
                "Invalid:Name": "value",
                "X-Line": "bad\rvalue",
                "X-Empty": "   ",
                " Referer ": " https://app.strem.io/ ",
                " origin ": " https://app.strem.io "
            ]
        )

        #expect(initialized.requestHeaders == [
            "Origin": "https://app.strem.io",
            "Referer": "https://app.strem.io/"
        ])
    }
}

// MARK: - StreamInfo Copy Methods

@Suite("StreamInfoCopyMethods")
struct StreamInfoCopyMethodsTests {

    private func baseStream() -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://example.com/video.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "video.mp4",
            sizeBytes: 1000,
            debridService: "realDebrid"
        )
    }

    @Test func withRecoveryContextReturnsNewInstance() {
        let original = baseStream()
        let context = StreamRecoveryContext(infoHash: "abc")
        let copy = original.withRecoveryContext(context)
        #expect(original.recoveryContext == nil)
        #expect(copy.recoveryContext?.infoHash == "abc")
        #expect(copy.streamURL == original.streamURL)
    }

    @Test func withStreamURLReturnsNewInstance() {
        let original = baseStream()
        let newURL = URL(string: "https://cdn.example.com/video.mp4")!
        let copy = original.withStreamURL(newURL)
        #expect(copy.streamURL == newURL)
        #expect(original.streamURL != newURL)
    }

    @Test func withRequestHeadersNormalizesAndFiltersInvalidHeaders() {
        let original = baseStream()
        let copy = original.withRequestHeaders([
            "  User-Agent  ": "  VPStudio  ",
            "Bad:Name": "ignored",
            "Bad\nName": "ignored",
            "Authorization": "Bearer ignored",
            "Cookie": "session=ignored",
            "X-Token": "ignored",
            "X-Bad-Value": "line\nbreak",
            "X-Blank": "   ",
            "   ": "value",
        ])

        #expect(original.requestHeaders == nil)
        #expect(copy.requestHeaders == ["User-Agent": "VPStudio"])
    }

    @Test func withRequestHeadersClearsHeadersWhenInputIsNilOrAllInvalid() {
        let original = baseStream().withRequestHeaders(["User-Agent": "VPStudio"])
        let nilCopy = original.withRequestHeaders(nil)
        let invalidCopy = original.withRequestHeaders(["Bad\rName": "value"])

        #expect(original.requestHeaders == ["User-Agent": "VPStudio"])
        #expect(nilCopy.requestHeaders == nil)
        #expect(invalidCopy.requestHeaders == nil)
    }

    @Test func withRequestHeadersKeepsOnlyPublicRefererAndOriginValues() {
        let copy = baseStream().withRequestHeaders([
            "Referer": "https://app.strem.io/shell-v4.4/#/detail",
            "Origin": "https://app.strem.io",
            "Referrer": "http://127.0.0.1/private",
            "referer": "file:///private/movie",
            "origin": "https://nas.local",
            "User-Agent": "Stremio",
            "Accept": "video/*",
        ])

        #expect(copy.requestHeaders == [
            "Accept": "video/*",
            "Origin": "https://app.strem.io",
            "Referer": "https://app.strem.io/shell-v4.4/#/detail",
            "User-Agent": "Stremio",
        ])
    }

    @Test func withRequestHeadersDropsRefererAndOriginCredentialMaterial() {
        let copy = baseStream().withRequestHeaders([
            "Referer": "https://user:pass@app.strem.io/shell-v4.4/#/detail",
            "Referrer": "https://app.strem.io/shell-v4.4/?access_token=secret",
            "referer": "https://app.strem.io/shell-v4.4/#access_token=secret",
            "Origin": "https://app.strem.io?apikey=secret",
            "ORIGIN": "https://app.strem.io#token%3Dsecret",
            "Accept": "video/*",
            "User-Agent": "Stremio",
        ])

        #expect(copy.requestHeaders == [
            "Accept": "video/*",
            "User-Agent": "Stremio",
        ])
    }

    @Test func withRequestHeadersDropsControlCharactersAndOversizedValues() {
        let hugeValue = String(repeating: "a", count: 2_049)
        let copy = baseStream().withRequestHeaders([
            "User-Agent": hugeValue,
            "Accept-Language": "en-US\tfr",
            "Accept": "video/*",
        ])

        #expect(copy.requestHeaders == ["Accept": "video/*"])
    }

    @Test func codableRoundTripPreservesRecoveryContextAndDropsTransientHeaders() throws {
        let context = try #require(StreamRecoveryContext(
            infoHash: "ABC123",
            preferredService: .realDebrid,
            magnetURI: " magnet:?xt=urn:btih:ABC123 ",
            seasonNumber: 1,
            episodeNumber: 2,
            torrentId: " torrent-1 ",
            resolvedDebridService: " real_debrid ",
            resolvedFileName: " episode.mkv ",
            resolvedFileSizeBytes: 1234
        ))
        let original = baseStream()
            .withRecoveryContext(context)
            .withRequestHeaders(["Authorization": "Bearer token"])

        let data = try JSONEncoder().encode(original)
        let encoded = try #require(String(data: data, encoding: .utf8))
        let decoded = try JSONDecoder().decode(StreamInfo.self, from: data)

        #expect(encoded.contains("requestHeaders") == false)
        #expect(encoded.contains("Bearer token") == false)
        #expect(decoded.recoveryContext == context)
        #expect(decoded.requestHeaders == nil)
        #expect(decoded.remoteTransferID == "torrent-1")
    }
}

// MARK: - StreamRecoveryContext

@Suite("StreamRecoveryContext")
struct StreamRecoveryContextTestsModelsStreaminfotests {

    @Test func initNormalizesHashToLowercase() {
        let context = StreamRecoveryContext(infoHash: "  ABC123  ")
        #expect(context?.infoHash == "abc123")
    }

    @Test func initReturnsNilForEmptyHash() {
        let context = StreamRecoveryContext(infoHash: "   ")
        #expect(context == nil)
    }

    @Test func initTrimsOptionalStrings() {
        let context = StreamRecoveryContext(
            infoHash: "abc",
            magnetURI: "  magnet:?xt=urn:btih:abc  ",
            torrentId: "  torrent-1  ",
            resolvedDebridService: "  realDebrid  ",
            resolvedFileName: "  file.mkv  "
        )
        #expect(context?.magnetURI == "magnet:?xt=urn:btih:abc")
        #expect(context?.torrentId == "torrent-1")
        #expect(context?.resolvedFileName == "file.mkv")
        #expect(context?.resolvedDebridService == "realDebrid")
    }

    @Test func initNilsEmptyOptionalStrings() {
        let context = StreamRecoveryContext(
            infoHash: "abc",
            resolvedDebridService: "",
            resolvedFileName: "   "
        )
        #expect(context?.resolvedFileName == nil)
        #expect(context?.resolvedDebridService == nil)
    }

    @Test func initNilsNonPositiveByteCount() {
        let zero = StreamRecoveryContext(
            infoHash: "abc",
            resolvedFileSizeBytes: 0
        )
        let negative = StreamRecoveryContext(
            infoHash: "abc",
            resolvedFileSizeBytes: -1
        )
        #expect(zero?.resolvedFileSizeBytes == nil)
        #expect(negative?.resolvedFileSizeBytes == nil)
    }

    @Test func initPreservesPositiveByteCount() {
        let context = StreamRecoveryContext(
            infoHash: "abc",
            resolvedFileSizeBytes: 1_000_000
        )
        #expect(context?.resolvedFileSizeBytes == 1_000_000)
    }

    @Test func enrichedForDownloadPersistenceCopiesFields() {
        let original = StreamRecoveryContext(infoHash: "abc", seasonNumber: 2, episodeNumber: 5)!
        let enriched = original.enrichedForDownloadPersistence(
            fileName: "video.mkv",
            sizeBytes: 2_000_000,
            debridService: "realDebrid"
        )
        #expect(enriched.infoHash == "abc")
        #expect(enriched.seasonNumber == 2)
        #expect(enriched.episodeNumber == 5)
        #expect(enriched.resolvedFileName == "video.mkv")
        #expect(enriched.resolvedFileSizeBytes == 2_000_000)
        #expect(enriched.resolvedDebridService == "realDebrid")
    }

    @Test func enrichedFallsBackToSelfWhenInitFails() {
        let original = StreamRecoveryContext(infoHash: "abc")!
        // enrichedForDownloadPersistence uses failable init; it should never fail
        // with valid inputs, but we verify the happy path works
        let enriched = original.enrichedForDownloadPersistence(
            fileName: "file.mkv",
            sizeBytes: 100,
            debridService: "rd"
        )
        #expect(enriched.resolvedFileName == "file.mkv")
    }

    @Test func enrichedForDownloadPersistenceNormalizesEmptyAndNonPositiveValues() {
        let original = StreamRecoveryContext(
            infoHash: "abc",
            preferredService: .realDebrid,
            magnetURI: "magnet:?xt=urn:btih:abc"
        )!

        let enriched = original.enrichedForDownloadPersistence(
            fileName: "   ",
            sizeBytes: -10,
            debridService: "   "
        )

        #expect(enriched.infoHash == original.infoHash)
        #expect(enriched.preferredService == .realDebrid)
        #expect(enriched.magnetURI == "magnet:?xt=urn:btih:abc")
        #expect(enriched.resolvedFileName == nil)
        #expect(enriched.resolvedFileSizeBytes == nil)
        #expect(enriched.resolvedDebridService == nil)
    }
}
