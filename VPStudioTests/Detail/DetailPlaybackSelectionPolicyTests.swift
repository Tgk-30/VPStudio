import Testing
@testable import VPStudio

@Suite("Detail Playback Selection Policy")
struct DetailPlaybackSelectionPolicyTests {
    @Test
    func bestCachedReturnsNilWhenNoResults() {
        #expect(DetailPlaybackSelectionPolicy.bestCachedResult(from: []) == nil)
    }

    @Test
    func bestCachedReturnsNilWhenNothingConfirmedCached() {
        // Highest-ranked source is present but its cache status is unknown, and
        // another is confirmed NOT cached — neither is eligible for one-tap play.
        var uncached = Fixtures.torrent(hash: "a", title: "Unknown 4K", quality: .uhd4k)
        uncached.cacheAvailability = .unknown
        var notCached = Fixtures.torrent(hash: "b", title: "Confirmed Uncached", quality: .uhd4k)
        notCached.cacheAvailability = .notCached

        #expect(DetailPlaybackSelectionPolicy.bestCachedResult(from: [uncached, notCached]) == nil)
    }

    @Test
    func bestCachedPrefersCachedEvenWhenLowerRankedThanUncached() {
        // A 4K uncached source outranks a 1080p cached one, but only the cached
        // source is eligible — never force-play the uncached higher-res result.
        var uncached4K = Fixtures.torrent(hash: "a", title: "4K Uncached", quality: .uhd4k)
        uncached4K.cacheAvailability = .unknown
        let cached1080 = Fixtures.torrent(hash: "b", title: "1080p Cached", quality: .hd1080p, cached: true)

        let best = DetailPlaybackSelectionPolicy.bestCachedResult(from: [uncached4K, cached1080])
        #expect(best?.infoHash == "b")
    }

    @Test
    func bestCachedPicksHighestRankedAmongCached() {
        // Among cached sources, the highest TorrentRanking score wins (4K > 1080p).
        let cached1080 = Fixtures.torrent(hash: "a", title: "1080p Cached", quality: .hd1080p, cached: true)
        let cached4K = Fixtures.torrent(hash: "b", title: "4K Cached", quality: .uhd4k, cached: true)
        let cached720 = Fixtures.torrent(hash: "c", title: "720p Cached", quality: .hd720p, cached: true)

        let best = DetailPlaybackSelectionPolicy.bestCachedResult(from: [cached1080, cached4K, cached720])
        #expect(best?.infoHash == "b")
    }

    @Test
    func bestCachedBreaksTiesBySeeders() {
        // Same quality/cached; the higher-seeded source wins the tiebreak.
        let lowSeed = Fixtures.torrent(hash: "a", title: "Low Seed", quality: .hd1080p, seeders: 5, cached: true)
        let highSeed = Fixtures.torrent(hash: "b", title: "High Seed", quality: .hd1080p, seeders: 400, cached: true)

        let best = DetailPlaybackSelectionPolicy.bestCachedResult(from: [lowSeed, highSeed])
        #expect(best?.infoHash == "b")
    }

    @Test
    func bestCachedIgnoresInputOrder() {
        // Selection is by rank, not list position, even if cached is presented last.
        var uncached = Fixtures.torrent(hash: "a", title: "Uncached", quality: .uhd4k)
        uncached.cacheAvailability = .unknown
        let cached = Fixtures.torrent(hash: "b", title: "Cached", quality: .hd720p, cached: true)

        #expect(DetailPlaybackSelectionPolicy.bestCachedResult(from: [uncached, cached])?.infoHash == "b")
        #expect(DetailPlaybackSelectionPolicy.bestCachedResult(from: [cached, uncached])?.infoHash == "b")
    }
}
