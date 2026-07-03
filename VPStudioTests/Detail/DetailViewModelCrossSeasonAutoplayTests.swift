import Testing
import Foundation
@testable import VPStudio

/// Integration coverage for cross-season autoplay wiring (not just the pure policy): opening a
/// series via `loadDetail` — the primary navigation path — must prefetch the next season so the
/// season finale yields a next-episode candidate. Regression guard for the gap where the prefetch
/// only ran on the `loadSeason` tab-switch path.
@Suite("DetailViewModel cross-season autoplay", .serialized)
@MainActor
struct DetailViewModelCrossSeasonAutoplayTests {
    private struct StubProvider: DetailMetadataProviding {
        let seasons: [Season]
        let episodesBySeason: [Int: [Episode]]
        let tmdbId: Int

        func getDetail(id: String, type: MediaType) async throws -> MediaItem {
            MediaItem(id: id, type: type, title: "Stub Series", tmdbId: tmdbId)
        }
        func getSeasons(id: String, type: MediaType) async throws -> [Season] { seasons }
        func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode] { episodesBySeason[season] ?? [] }
        func getSeasons(tmdbId: Int) async throws -> [Season] { seasons }
        func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode] { episodesBySeason[season] ?? [] }
    }

    private func season(_ n: Int) -> Season {
        Season(id: n, seasonNumber: n, name: "Season \(n)", overview: nil, posterPath: nil, episodeCount: 2, airDate: nil)
    }
    private func episode(_ s: Int, _ e: Int) -> Episode {
        Episode(id: "tmdb-77-s\(s)e\(e)", mediaId: "show-77", seasonNumber: s, episodeNumber: e, title: "Episode \(e)")
    }
    private func stream() -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://example.com/a.mkv")!,
            quality: .hd1080p, codec: .h264, audio: .aac,
            source: .webDL, hdr: .sdr, fileName: "a.mkv",
            sizeBytes: 1_000_000, debridService: "rd"
        )
    }

    private func makeViewModel(_ stub: StubProvider) -> DetailViewModel {
        DetailViewModel(
            appState: AppState(),
            metadataProviderFactory: { _ in stub },
            indexerManager: StubIndexerManager(),
            debridManager: StubDebridManager(),
            downloadManager: StubDownloadManager()
        )
    }

    @Test("Opening a show via loadDetail enables cross-season autoplay at the S1 finale")
    func loadDetailPrefetchesNextSeasonForFinale() async throws {
        let stub = StubProvider(
            seasons: [season(1), season(2)],
            episodesBySeason: [
                1: [episode(1, 1), episode(1, 2)],
                2: [episode(2, 1), episode(2, 2)],
            ],
            tmdbId: 77
        )
        let vm = makeViewModel(stub)

        await vm.loadDetail(
            preview: MediaPreview(id: "show-77", type: .series, title: "Stub Series", tmdbId: 77),
            apiKey: "key"
        )

        // Select the season-1 finale (last loaded episode of the initial season).
        let finale = try #require(vm.episodes.first { $0.seasonNumber == 1 && $0.episodeNumber == 2 })
        vm.selectEpisode(finale)

        let request = vm.makePlayerSessionRequest(stream: stream(), preview: MediaPreview(id: "show-77", type: .series, title: "Stub Series", tmdbId: 77))

        // Without the loadDetail-path prefetch this is nil and autoplay dies at the boundary.
        #expect(request.nextEpisode?.seasonNumber == 2)
        #expect(request.nextEpisode?.episodeNumber == 1)
    }

    @Test("A true series finale (no following season) yields no next-episode candidate")
    func loadDetailSeriesFinaleHasNoNextEpisode() async throws {
        let stub = StubProvider(
            seasons: [season(1)],
            episodesBySeason: [1: [episode(1, 1), episode(1, 2)]],
            tmdbId: 77
        )
        let vm = makeViewModel(stub)

        await vm.loadDetail(
            preview: MediaPreview(id: "show-77", type: .series, title: "Stub Series", tmdbId: 77),
            apiKey: "key"
        )
        let finale = try #require(vm.episodes.first { $0.seasonNumber == 1 && $0.episodeNumber == 2 })
        vm.selectEpisode(finale)

        let request = vm.makePlayerSessionRequest(stream: stream(), preview: MediaPreview(id: "show-77", type: .series, title: "Stub Series", tmdbId: 77))
        #expect(request.nextEpisode == nil)
    }
}
