import Testing
import Foundation
@testable import VPStudio

@Suite("SourceRowPolicy")
struct SourceRowPolicyTests {

    private func makeTorrent(
        title: String = "Movie.2024.1080p.WEB-DL.x265-RARBG",
        sizeBytes: Int64 = 2_147_483_648,
        seeders: Int = 42,
        indexerName: String = "Jackett",
        cacheAvailability: CacheAvailability = .unknown,
        cachedOnService: String? = nil,
        releaseGroup: String? = "RARBG"
    ) -> TorrentResult {
        var torrent = TorrentResult(
            infoHash: "abcdef1234567890abcdef1234567890abcdef12",
            title: title,
            sizeBytes: sizeBytes,
            seeders: seeders,
            leechers: 0,
            quality: .hd1080p,
            codec: .h265,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            indexerName: indexerName,
            cachedOnService: cachedOnService,
            releaseGroup: releaseGroup
        )
        torrent.cacheAvailability = cacheAvailability
        return torrent
    }

    // MARK: - Cache badge tri-state

    @Test func cachedSourceShowsInstantBadge() {
        let torrent = makeTorrent(
            cacheAvailability: .cached,
            cachedOnService: DebridServiceType.realDebrid.rawValue
        )
        let descriptor = SourceRowPolicy.descriptor(for: torrent)

        #expect(descriptor.cacheBadge == .instant)
        #expect(descriptor.cacheBadge.label == "Instant")
        #expect(descriptor.cacheBadge.symbol == "bolt.fill")
        #expect(descriptor.cacheBadge.tint == .green)
    }

    @Test func notCachedSourceShowsMustDownloadBadge() {
        let torrent = makeTorrent(cacheAvailability: .notCached)
        let descriptor = SourceRowPolicy.descriptor(for: torrent)

        #expect(descriptor.cacheBadge == .mustDownload)
        #expect(descriptor.cacheBadge.label == "Must Download")
        #expect(descriptor.cacheBadge.symbol == "arrow.down.circle.fill")
        #expect(descriptor.cacheBadge.tint == .orange)
    }

    @Test func unknownSourceShowsNoBadge() {
        let torrent = makeTorrent(cacheAvailability: .unknown)
        let descriptor = SourceRowPolicy.descriptor(for: torrent)

        #expect(descriptor.cacheBadge == .none)
        #expect(descriptor.cacheBadge.label == nil)
        #expect(descriptor.cacheBadge.symbol == nil)
        #expect(descriptor.cacheBadge.tint == nil)
    }

    // MARK: - Provider label selection

    @Test func providerLabelUsesDebridDisplayNameWhenCached() {
        let torrent = makeTorrent(
            indexerName: "Jackett",
            cacheAvailability: .cached,
            cachedOnService: DebridServiceType.realDebrid.rawValue
        )
        #expect(SourceRowPolicy.providerLabel(for: torrent) == DebridServiceType.realDebrid.displayName)
        #expect(SourceRowPolicy.providerLabel(for: torrent) == "Real-Debrid")
    }

    @Test func providerLabelFallsBackToIndexerWhenNotCached() {
        let torrent = makeTorrent(indexerName: "Prowlarr", cacheAvailability: .notCached)
        #expect(SourceRowPolicy.providerLabel(for: torrent) == "Prowlarr")
    }

    @Test func providerLabelFallsBackToIndexerWhenUnknown() {
        let torrent = makeTorrent(indexerName: "Torznab", cacheAvailability: .unknown, cachedOnService: nil)
        #expect(SourceRowPolicy.providerLabel(for: torrent) == "Torznab")
    }

    @Test func providerLabelUsesRawServiceWhenCachedOnUnrecognizedService() {
        let torrent = makeTorrent(
            indexerName: "Jackett",
            cacheAvailability: .cached,
            cachedOnService: "Premiumize"
        )
        // "Premiumize" is not a DebridServiceType rawValue (raw is "premiumize"),
        // so the raw label is surfaced verbatim rather than the indexer name.
        #expect(SourceRowPolicy.providerLabel(for: torrent) == "Premiumize")
    }

    @Test func providerLabelIgnoresCachedServiceWhenNotCached() {
        // A stale cachedOnService on a non-cached row must not leak into the label.
        let torrent = makeTorrent(
            indexerName: "Jackett",
            cacheAvailability: .notCached,
            cachedOnService: DebridServiceType.realDebrid.rawValue
        )
        #expect(SourceRowPolicy.providerLabel(for: torrent) == "Jackett")
    }

    // MARK: - Size / seeders / group formatting

    @Test func sizeStringMatchesTorrentFormatting() {
        let torrent = makeTorrent(sizeBytes: 2_147_483_648)
        let descriptor = SourceRowPolicy.descriptor(for: torrent)
        #expect(descriptor.sizeString == "2.0 GB")
        #expect(descriptor.sizeString == torrent.sizeString)
    }

    @Test func seedersStringFormatsPositiveSeeders() {
        let descriptor = SourceRowPolicy.descriptor(for: makeTorrent(seeders: 128))
        #expect(descriptor.seedersString == "128")
    }

    @Test func seedersStringIsNilWhenNoSeeders() {
        let descriptor = SourceRowPolicy.descriptor(for: makeTorrent(seeders: 0))
        #expect(descriptor.seedersString == nil)
    }

    @Test func releaseGroupIsSurfacedWhenPresent() {
        let descriptor = SourceRowPolicy.descriptor(for: makeTorrent(releaseGroup: "RARBG"))
        #expect(descriptor.releaseGroup == "RARBG")
    }

    @Test func releaseGroupIsNilWhenAbsentOrBlank() {
        #expect(SourceRowPolicy.descriptor(for: makeTorrent(releaseGroup: nil)).releaseGroup == nil)
        #expect(SourceRowPolicy.descriptor(for: makeTorrent(releaseGroup: "   ")).releaseGroup == nil)
    }

    @Test func descriptorComposesAllFieldsForCachedSource() {
        let torrent = makeTorrent(
            sizeBytes: 5_368_709_120,
            seeders: 9,
            indexerName: "Jackett",
            cacheAvailability: .cached,
            cachedOnService: DebridServiceType.allDebrid.rawValue,
            releaseGroup: "FLUX"
        )
        let descriptor = SourceRowPolicy.descriptor(for: torrent)

        #expect(descriptor == SourceRowPolicy.Descriptor(
            cacheBadge: .instant,
            sizeString: "5.0 GB",
            seedersString: "9",
            providerLabel: "AllDebrid",
            releaseGroup: "FLUX"
        ))
    }
}
