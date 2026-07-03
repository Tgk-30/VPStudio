import Testing
@testable import VPStudio

@Suite("DetailNextEpisodePolicy")
struct DetailNextEpisodePolicyTests {
    private func episode(_ season: Int, _ number: Int, id: String? = nil) -> Episode {
        Episode(
            id: id ?? "s\(season)e\(number)",
            mediaId: "show-1",
            seasonNumber: season,
            episodeNumber: number,
            title: "Episode \(number)"
        )
    }

    private func season(_ number: Int) -> Season {
        Season(
            id: number,
            seasonNumber: number,
            name: "Season \(number)",
            overview: nil,
            posterPath: nil,
            episodeCount: 10,
            airDate: nil
        )
    }

    @Test("Next episode within the loaded season is preferred")
    func nextWithinSeason() {
        let episodes = [episode(1, 1), episode(1, 2), episode(1, 3)]
        let candidate = DetailNextEpisodePolicy.nextCandidate(
            selectedEpisode: episodes[1],
            currentEpisodes: episodes,
            nextSeasonFirstEpisode: nil
        )
        #expect(candidate?.seasonNumber == 1)
        #expect(candidate?.episodeNumber == 3)
        #expect(candidate?.episodeId == "s1e3")
    }

    @Test("Season finale falls back to the prefetched next season's first episode")
    func crossesSeasonBoundary() {
        let episodes = [episode(1, 1), episode(1, 2)] // E2 is the loaded finale
        let candidate = DetailNextEpisodePolicy.nextCandidate(
            selectedEpisode: episodes[1],
            currentEpisodes: episodes,
            nextSeasonFirstEpisode: episode(2, 1)
        )
        #expect(candidate?.seasonNumber == 2)
        #expect(candidate?.episodeNumber == 1)
        #expect(candidate?.episodeId == "s2e1")
    }

    @Test("Season finale with no prefetched next season returns nil")
    func finaleWithoutPrefetchStops() {
        let episodes = [episode(1, 1), episode(1, 2)]
        let candidate = DetailNextEpisodePolicy.nextCandidate(
            selectedEpisode: episodes[1],
            currentEpisodes: episodes,
            nextSeasonFirstEpisode: nil
        )
        #expect(candidate == nil)
    }

    @Test("Prefetched episode from a non-adjacent season is ignored")
    func ignoresNonAdjacentSeason() {
        let episodes = [episode(1, 1), episode(1, 2)]
        // A stale prefetch pointing two seasons ahead must not be treated as the successor.
        let candidate = DetailNextEpisodePolicy.nextCandidate(
            selectedEpisode: episodes[1],
            currentEpisodes: episodes,
            nextSeasonFirstEpisode: episode(3, 1)
        )
        #expect(candidate == nil)
    }

    @Test("Mid-season selection ignores any prefetched next season")
    func midSeasonIgnoresPrefetch() {
        let episodes = [episode(1, 1), episode(1, 2), episode(1, 3)]
        let candidate = DetailNextEpisodePolicy.nextCandidate(
            selectedEpisode: episodes[0],
            currentEpisodes: episodes,
            nextSeasonFirstEpisode: episode(2, 1)
        )
        #expect(candidate?.seasonNumber == 1)
        #expect(candidate?.episodeNumber == 2)
    }

    @Test("prefetchSeasonNumber returns the immediately following season when present")
    func prefetchSeasonResolution() {
        let seasons = [season(1), season(2), season(3)]
        #expect(DetailNextEpisodePolicy.prefetchSeasonNumber(after: 1, seasons: seasons) == 2)
        #expect(DetailNextEpisodePolicy.prefetchSeasonNumber(after: 2, seasons: seasons) == 3)
        #expect(DetailNextEpisodePolicy.prefetchSeasonNumber(after: 3, seasons: seasons) == nil)
    }

    @Test("prefetchSeasonNumber returns nil when the next season is missing (e.g. specials gap)")
    func prefetchSeasonGap() {
        let seasons = [season(1), season(3)] // no season 2
        #expect(DetailNextEpisodePolicy.prefetchSeasonNumber(after: 1, seasons: seasons) == nil)
    }

    @Test("firstEpisode returns the lowest-numbered episode regardless of order")
    func firstEpisodeOrdering() {
        let episodes = [episode(2, 3), episode(2, 1), episode(2, 2)]
        #expect(DetailNextEpisodePolicy.firstEpisode(of: episodes)?.episodeNumber == 1)
        #expect(DetailNextEpisodePolicy.firstEpisode(of: [])?.episodeNumber == nil)
    }
}
