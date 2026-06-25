import Foundation
import Testing
@testable import VPStudio

// MARK: - TorrentResult fromSearch Parsing

@Suite("TorrentResultFromSearch")
struct TorrentResultFromSearchTests {

    @Test func fromSearchLowercasesInfoHash() {
        let result = TorrentResult.fromSearch(
            infoHash: "ABC123DEF456",
            title: "Test Movie 1080p WEB-DL",
            sizeBytes: 1_000_000,
            seeders: 10,
            leechers: 2,
            indexerName: "IndexerA"
        )
        #expect(result.infoHash == "abc123def456")
    }

    @Test func fromSearchParses4KQuality() {
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "Movie.2024.2160p.BluRay",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "i"
        )
        #expect(result.quality == .uhd4k)
    }

    @Test func fromSearchParses1080pQuality() {
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "Movie.2024.1080p.WEB-DL",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "i"
        )
        #expect(result.quality == .hd1080p)
    }

    @Test func fromSearchParsesH265Codec() {
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "Movie.x265.HEVC",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "i"
        )
        #expect(result.codec == .h265)
    }

    @Test func fromSearchParsesAtmosAudio() {
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "Movie.Atmos.DDP5.1",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "i"
        )
        #expect(result.audio == .atmos)
    }

    @Test func fromSearchParsesBluRaySource() {
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "Movie.BluRay.1080p",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "i"
        )
        #expect(result.source == .bluRay)
    }

    @Test func fromSearchParsesDolbyVisionHDR() {
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "Movie.Dolby.Vision.4K",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "i"
        )
        #expect(result.hdr == .dolbyVision)
    }

    @Test func fromSearchDefaultsToUnknownForUnmatchedTitle() {
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "Movie.2024",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "i"
        )
        #expect(result.quality == .unknown)
        #expect(result.codec == .unknown)
        #expect(result.audio == .unknown)
        #expect(result.source == .unknown)
        #expect(result.hdr == .sdr)
    }

    @Test func fromSearchStoresMagnetURI() {
        let magnet = "magnet:?xt=urn:btih:abc"
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "Test",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "i",
            magnetURI: magnet
        )
        #expect(result.magnetURI == magnet)
    }
}

// MARK: - TorrentResult Computed Properties

@Suite("TorrentResultComputedProperties")
struct TorrentResultComputedPropertiesTests {

    @Test func idCombinesHashAndIndexer() {
        let result = TorrentResult(
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
        #expect(result.id == "abc123-MyIndexer")
    }

    @Test func sizeStringFormatsGB() {
        let result = TorrentResult(
            infoHash: "abc",
            title: "Test",
            sizeBytes: 2_147_483_648,
            seeders: 1,
            leechers: 0,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            indexerName: "i"
        )
        #expect(result.sizeString == "2.0 GB")
    }

    @Test func sizeStringFormatsMB() {
        let result = TorrentResult(
            infoHash: "abc",
            title: "Test",
            sizeBytes: 524_288_000,
            seeders: 1,
            leechers: 0,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            indexerName: "i"
        )
        #expect(result.sizeString == "500 MB")
    }

    @Test func qualityBadgeIncludesAllNonDefaults() {
        let result = TorrentResult(
            infoHash: "abc",
            title: "Test",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            quality: .uhd4k,
            codec: .h265,
            audio: .atmos,
            source: .bluRay,
            hdr: .dolbyVision,
            indexerName: "i"
        )
        let badge = result.qualityBadge
        #expect(badge.contains("4K"))
        #expect(badge.contains("DV"))
        #expect(badge.contains("H.265"))
        #expect(badge.contains("Atmos"))
        #expect(badge.contains("BluRay"))
    }

    @Test func qualityBadgeOmitsUnknownSource() {
        let result = TorrentResult(
            infoHash: "abc",
            title: "Test",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            quality: .hd1080p,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            indexerName: "i"
        )
        #expect(!result.qualityBadge.contains("unknown"))
        #expect(result.qualityBadge == "1080p")
    }

    @Test func isCachedDefaultsToFalse() {
        let result = TorrentResult(
            infoHash: "abc",
            title: "Test",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            indexerName: "i"
        )
        #expect(result.isCached == false)
    }

    @Test func directStreamInfoFallsBackToFirstTitleLineWhenURLHasNoFileName() throws {
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "  Feature Presentation\n1080p mirror  ",
            sizeBytes: 0,
            seeders: 1,
            leechers: 0,
            indexerName: "Direct",
            directStreamURL: "https://cdn.example.com/",
            directStreamRequestHeaders: [
                " User-Agent ": " VPStudio ",
                "Invalid:Header": "ignored",
                "X-Blank": "   "
            ]
        )

        let stream = try #require(result.directStreamInfo)
        #expect(stream.fileName == "Feature Presentation")
        #expect(stream.sizeBytes == nil)
        #expect(stream.requestHeaders == ["User-Agent": "VPStudio"])
    }

    @Test func directStreamInfoUsesPercentDecodedLastPathComponentAndPositiveSize() throws {
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "Fallback Title",
            sizeBytes: 2_048,
            seeders: 1,
            leechers: 0,
            indexerName: "Direct",
            directStreamURL: "https://cdn.example.com/Movie%20Night.mkv"
        )

        let stream = try #require(result.directStreamInfo)
        #expect(stream.fileName == "Movie Night.mkv")
        #expect(stream.sizeBytes == 2_048)
        #expect(!result.requiresDebridResolution)
    }

    @Test func directStreamInfoUsesRawLastPathComponentWhenPercentDecodingFails() throws {
        let result = TorrentResult.fromSearch(
            infoHash: "abc",
            title: "Fallback Title",
            sizeBytes: 2_048,
            seeders: 1,
            leechers: 0,
            indexerName: "Direct",
            directStreamURL: "https://cdn.example.com/Movie%ZZ.mkv"
        )

        let stream = try #require(result.directStreamInfo)
        #expect(stream.fileName == "Movie%ZZ.mkv")
    }

    @Test func requiresDebridResolutionWhenNoDirectStreamInfoIsAvailable() {
        let result = TorrentResult.fromSearch(
            infoHash: "abcdef1234567890abcdef1234567890abcdef12",
            title: "Hash Only",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "Indexer",
            directStreamURL: "magnet:?xt=urn:btih:abcdef1234567890abcdef1234567890abcdef12"
        )

        #expect(result.directStreamInfo == nil)
        #expect(result.hasResolvableDebridHash)
        #expect(result.requiresDebridResolution)
    }

    @Test func resolvableDebridHashCanComeFromMagnetWhenInfoHashIsNotUsable() {
        let hash = "abcdef1234567890abcdef1234567890abcdef12"
        let result = TorrentResult.fromSearch(
            infoHash: "not-a-hash",
            title: "Magnet Hash",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "Indexer",
            magnetURI: "magnet:?xt=urn:btih:\(hash)"
        )

        #expect(result.hasResolvableDebridHash)
        #expect(result.requiresDebridResolution)
    }

    @Test func hasResolvableDebridHashIsFalseWhenInfoHashAndMagnetAreInvalid() {
        let result = TorrentResult.fromSearch(
            infoHash: "not-a-hash",
            title: "No Hash",
            sizeBytes: 1,
            seeders: 1,
            leechers: 0,
            indexerName: "Indexer",
            magnetURI: "magnet:?xt=urn:sha1:\(String(repeating: "a", count: 40))"
        )

        #expect(!result.hasResolvableDebridHash)
    }

    @Test func normalizedDirectStreamURLAcceptsHTTPAndHTTPSOnlyAfterTrimming() {
        #expect(TorrentResult.normalizedDirectStreamURLString(" https://cdn.example.com/file.mkv ") == "https://cdn.example.com/file.mkv")
        #expect(TorrentResult.normalizedDirectStreamURLString("http://cdn.example.com/file.mkv") == "http://cdn.example.com/file.mkv")
        #expect(TorrentResult.normalizedDirectStreamURLString("ftp://cdn.example.com/file.mkv") == nil)
        #expect(TorrentResult.normalizedDirectStreamURLString("https:///missing-host.mkv") == nil)
        #expect(TorrentResult.normalizedDirectStreamURLString("   ") == nil)
        #expect(TorrentResult.normalizedDirectStreamURLString(nil) == nil)
    }

    @Test func normalizedDirectStreamURLRejectsPrivateAndLoopbackHosts() {
        // Loopback / LAN / link-local / cloud-metadata must never be reachable via
        // an untrusted addon-provided stream URL (SSRF guard).
        for blocked in [
            "http://127.0.0.1/file.mkv",
            "https://localhost/file.mkv",
            "http://192.168.1.10:8096/file.mkv",
            "http://10.0.0.5/file.mkv",
            "http://172.16.4.4/file.mkv",
            "http://169.254.169.254/latest/meta-data",
            "http://[::1]:8080/file.mkv",
            "https://nas.local/file.mkv",
            "http://router/file.mkv",
            "http://0.0.0.0/file.mkv",
        ] {
            #expect(TorrentResult.normalizedDirectStreamURLString(blocked) == nil, "expected \(blocked) to be rejected")
        }

        // Genuine public CDN hosts (including public IP literals) still pass.
        #expect(TorrentResult.normalizedDirectStreamURLString("https://cdn.example.com/file.mkv") == "https://cdn.example.com/file.mkv")
        #expect(TorrentResult.normalizedDirectStreamURLString("https://8.8.8.8/file.mkv") == "https://8.8.8.8/file.mkv")
    }

    @Test func privateNetworkHostPolicyClassifiesHosts() {
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "127.0.0.1"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "10.255.255.255"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "172.31.0.1"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "192.168.0.1"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "169.254.10.10"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "::1"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "fd12:3456::1"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "fe80::1"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "::ffff:127.0.0.1"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "localhost"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "intranet"))

        #expect(!PrivateNetworkHostPolicy.isPrivateOrReserved(host: "cdn.example.com"))
        #expect(!PrivateNetworkHostPolicy.isPrivateOrReserved(host: "8.8.8.8"))
        #expect(!PrivateNetworkHostPolicy.isPrivateOrReserved(host: "172.32.0.1"))
        #expect(!PrivateNetworkHostPolicy.isPrivateOrReserved(host: "100.128.0.1"))
    }

    @Test func privateNetworkHostPolicyBlocksNonCanonicalLiteralBypasses() {
        // Non-canonical numeric IPv4 spellings of loopback/private addresses must
        // fail closed — either the resolver maps them to the private address, or
        // the numeric-literal guard rejects the disguised form (these previously
        // failed open via inet_aton's octal interpretation).
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "010.0.0.1"))    // decimal 10.0.0.1
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "0x7f.0.0.1"))   // hex 127
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "127.1"))        // short form
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "2130706433"))   // 32-bit integer
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "0x7f000001"))   // hex integer

        // Expanded / alternate IPv6 spellings of loopback & IPv4-mapped private.
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "0:0:0:0:0:0:0:1"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "::ffff:7f00:1"))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "::ffff:192.168.1.1"))

        // Trailing root dot must not bypass the local-suffix checks.
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "localhost."))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "nas.local."))
        #expect(PrivateNetworkHostPolicy.isPrivateOrReserved(host: "router.home.arpa."))

        // A public FQDN with a trailing root dot is still public.
        #expect(!PrivateNetworkHostPolicy.isPrivateOrReserved(host: "cdn.example.com."))
    }

    @Test func stremioResolverHostVariantsRespectResolvePaths() throws {
        let torrentioMirror = try #require(URL(string: "https://rd.strem.fun/resolve/rd/hash/file.mkv"))
        let torrentioCatalog = try #require(URL(string: "https://rd.strem.fun/catalog/movie/top.json"))
        let mediaFusionResolve = try #require(URL(string: "https://mediafusion.example.com/resolve/rd/hash/file.mkv"))
        let mediaFusionOfficial = try #require(URL(string: "https://mediafusion.elfhosted.com/streaming_provider/rd/hash/file.mkv"))
        let customStremioResolve = try #require(URL(string: "https://custom.strem.example/resolve/rd/hash/file.mkv"))

        #expect(TorrentResult.isStremioDebridResolverURL(torrentioMirror, indexerName: "Indexer"))
        #expect(!TorrentResult.isStremioDebridResolverURL(torrentioCatalog, indexerName: "Indexer"))
        #expect(TorrentResult.isStremioDebridResolverURL(mediaFusionResolve, indexerName: "Stremio MediaFusion"))
        #expect(TorrentResult.isStremioDebridResolverURL(mediaFusionOfficial, indexerName: "Indexer"))
        #expect(TorrentResult.isStremioDebridResolverURL(customStremioResolve, indexerName: "Stremio Custom"))
    }

    @Test func stremioResolverHostVariantsRejectNonResolverPaths() throws {
        let torrentioCatalog = try #require(URL(string: "https://torrentio.strem.fun/manifest.json"))
        let mediaFusionCatalog = try #require(URL(string: "https://mediafusion.elfhosted.com/catalog/movie/top.json"))
        let mediaFusionNamedCatalog = try #require(URL(string: "https://mediafusion.example.com/catalog/movie/top.json"))
        let customStremHostCatalog = try #require(URL(string: "https://custom.strem.example/catalog/movie/top.json"))

        #expect(!TorrentResult.isStremioDebridResolverURL(torrentioCatalog, indexerName: "Indexer"))
        #expect(!TorrentResult.isStremioDebridResolverURL(mediaFusionCatalog, indexerName: "Indexer"))
        #expect(!TorrentResult.isStremioDebridResolverURL(mediaFusionNamedCatalog, indexerName: "Stremio MediaFusion"))
        #expect(!TorrentResult.isStremioDebridResolverURL(customStremHostCatalog, indexerName: "Stremio Custom"))
    }
}
