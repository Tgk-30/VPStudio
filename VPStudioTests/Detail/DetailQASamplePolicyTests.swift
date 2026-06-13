import Foundation
import Testing
@testable import VPStudio

@Suite("DetailQASamplePolicy")
struct DetailQASamplePolicyTests {
    @Test
    func previewTaskIdentityIncludesPreviewEpisodeAndInitialActionFields() {
        let preview = MediaPreview(
            id: "show-42",
            type: .series,
            title: "Series",
            year: 2026,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 1234,
            episodeId: "episode-2",
            seasonNumber: 1,
            episodeNumber: 2
        )

        #expect(
            DetailQASamplePolicy.previewTaskIdentity(
                preview: preview,
                initialAction: .resumePlayback
            ) == "series-show-42-1234-episode-2-1-2-resumePlayback"
        )
    }

    @Test
    func previewTaskIdentityUsesNoneForMissingOptionalFields() {
        let preview = MediaPreview(
            id: "movie-1",
            type: .movie,
            title: "Movie",
            year: nil,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: nil
        )

        #expect(
            DetailQASamplePolicy.previewTaskIdentity(
                preview: preview,
                initialAction: .none
            ) == "movie-movie-1-none-none-none-none-none"
        )
    }

    @Test
    func makeSampleStreamsReturnsNilForEmptySampleURLList() {
        #expect(
            DetailQASamplePolicy.makeSampleStreams(
                sampleURLs: [],
                mediaTitle: "Movie",
                previewType: .movie,
                selectedEpisode: nil
            ) == nil
        )
    }

    @Test
    func movieSampleStreamsUsePlainMP4FileName() throws {
        let sampleURLs = [
            URL(string: "https://example.test/one.mp4")!,
            URL(string: "https://example.test/two.mp4")!,
        ]
        let streams = try #require(
            DetailQASamplePolicy.makeSampleStreams(
                sampleURLs: sampleURLs,
                mediaTitle: "Arrival",
                previewType: .movie,
                selectedEpisode: makeEpisode()
            )
        )

        #expect(streams.map(\.fileName) == ["Arrival.mp4", "Arrival.mp4"])
        #expect(streams.map(\.debridService) == ["qa-sample", "qa-sample"])
        #expect(streams.allSatisfy { $0.quality == .hd720p && $0.codec == .h264 && $0.audio == .aac })
    }

    @Test
    func seriesSampleStreamsIncludeSeasonAndEpisodeInFileName() throws {
        let streams = try #require(
            DetailQASamplePolicy.makeSampleStreams(
                sampleURLs: [URL(string: "https://example.test/show.mp4")!],
                mediaTitle: "Severance",
                previewType: .series,
                selectedEpisode: makeEpisode(season: 2, episode: 7)
            )
        )

        #expect(streams.first?.fileName == "Severance-S02E07.mp4")
    }

    @Test
    func seriesSampleStreamsWithoutSelectedEpisodeUsePlainMP4FileName() throws {
        let streams = try #require(
            DetailQASamplePolicy.makeSampleStreams(
                sampleURLs: [URL(string: "https://example.test/show.mp4")!],
                mediaTitle: "Severance",
                previewType: .series,
                selectedEpisode: nil
            )
        )

        #expect(streams.first?.fileName == "Severance.mp4")
    }

    @Test
    func movieSampleDownloadOmitsEpisodeMetadata() {
        let arguments = DetailQASamplePolicy.downloadArguments(
            mediaItem: makeMediaItem(type: .movie),
            previewType: .movie,
            selectedEpisode: makeEpisode()
        )

        #expect(arguments?.mediaId == "media-1")
        #expect(arguments?.mediaType == MediaType.movie.rawValue)
        #expect(arguments?.episodeId == nil)
        #expect(arguments?.seasonNumber == nil)
        #expect(arguments?.episodeNumber == nil)
        #expect(arguments?.episodeTitle == nil)
    }

    @Test
    func seriesSampleDownloadIncludesSelectedEpisodeMetadata() {
        let arguments = DetailQASamplePolicy.downloadArguments(
            mediaItem: makeMediaItem(type: .series),
            previewType: .series,
            selectedEpisode: makeEpisode(id: "episode-7", season: 3, episode: 4, title: "The Signal")
        )

        #expect(arguments?.mediaId == "media-1")
        #expect(arguments?.mediaTitle == "Fixture")
        #expect(arguments?.mediaType == MediaType.series.rawValue)
        #expect(arguments?.posterPath == "/poster.jpg")
        #expect(arguments?.episodeId == "episode-7")
        #expect(arguments?.seasonNumber == 3)
        #expect(arguments?.episodeNumber == 4)
        #expect(arguments?.episodeTitle == "The Signal")
    }

    @Test
    func sampleDownloadReturnsNilWithoutMediaItem() {
        #expect(
            DetailQASamplePolicy.downloadArguments(
                mediaItem: nil,
                previewType: .series,
                selectedEpisode: makeEpisode()
            ) == nil
        )
    }

    private func makeMediaItem(type: MediaType) -> MediaItem {
        MediaItem(
            id: "media-1",
            type: type,
            title: "Fixture",
            year: 2026,
            posterPath: "/poster.jpg"
        )
    }

    private func makeEpisode(
        id: String = "episode-1",
        season: Int = 1,
        episode: Int = 2,
        title: String? = "Pilot"
    ) -> Episode {
        Episode(
            id: id,
            mediaId: "media-1",
            seasonNumber: season,
            episodeNumber: episode,
            title: title,
            overview: nil,
            airDate: nil,
            stillPath: nil,
            runtime: nil
        )
    }
}
