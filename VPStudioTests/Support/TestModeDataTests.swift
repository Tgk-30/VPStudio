import Testing
@testable import VPStudio

@Suite("TestModeData")
struct TestModeDataTests {
    @Test func previewSeedsUseOMDbFirstIMDbIdentities() {
        let moviePreview = DiscoverPreviewSeed.moviePreviews[0]
        let seriesPreview = DiscoverPreviewSeed.showPreviews[0]

        #expect(moviePreview.id == "tt15239678")
        #expect(seriesPreview.id == "tt11280740")
        #expect(moviePreview.tmdbId == nil)
        #expect(seriesPreview.tmdbId == nil)

        let detailMovie = DetailPreviewSeed.mediaItem(for: .movie)
        let detailSeries = DetailPreviewSeed.mediaItem(for: .series)
        #expect(detailMovie.id == "tt15239678")
        #expect(detailSeries.id == "tt11280740")
        #expect(detailMovie.tmdbId == nil)
        #expect(detailSeries.tmdbId == nil)
        #expect(detailSeries.title == "Severance")
        #expect(detailSeries.overview?.localizedCaseInsensitiveContains("corporate") == true)
        #expect(detailSeries.overview?.localizedCaseInsensitiveContains("therapist") == false)
        #expect(DetailPreviewSeed.episodes(for: .series).first?.mediaId == "tt11280740")

        #expect(LibraryPreviewSeed.entries.allSatisfy { IMDbIdentifierPolicy.normalizedID(from: $0.mediaId) != nil })
        #expect(LibraryPreviewSeed.mediaItems.values.allSatisfy { IMDbIdentifierPolicy.normalizedID(from: $0.id) != nil })
        #expect(LibraryPreviewSeed.mediaItems.values.allSatisfy { $0.tmdbId == nil })

        #expect(DownloadsPreviewSeed.tasks.allSatisfy { IMDbIdentifierPolicy.normalizedID(from: $0.mediaId) != nil })
        #expect(DownloadsPreviewSeed.tasks.compactMap(\.episodeId).contains("tt11280740-s2e1"))
    }

    @Test func mediaPreviewsUseStableVisualQAIdentities() {
        let movie = TestModeData.moviePreview
        let series = TestModeData.seriesPreview

        #expect(movie.id == "tt15239678")
        #expect(movie.type == .movie)
        #expect(movie.title == "Dune: Part Two")
        #expect(movie.year == 2024)
        #expect(movie.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w342/8b8R8l88QJejddJmXAdzF9xFGAD.jpg")
        #expect(movie.backdropURL?.absoluteString == "https://image.tmdb.org/t/p/w1280/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg")
        #expect(movie.imdbRating == 8.8)
        #expect(movie.tmdbId == nil)

        #expect(series.id == "tt15677150")
        #expect(series.type == .series)
        #expect(series.title == "Shrinking")
        #expect(series.year == 2023)
        #expect(series.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w342/vEF6xlpIIyJPKJLRG0llLxM5sQS.jpg")
        #expect(series.backdropURL?.absoluteString == "https://image.tmdb.org/t/p/w1280/sIhNMJZzW1V3R9O8VwR2F8XJE1W.jpg")
        #expect(series.imdbRating == 8.1)
        #expect(series.tmdbId == nil)
    }

    @Test func movieTorrentFixturesPreserveSearchMetadataAndParserHints() {
        let torrents = TestModeData.torrentResults

        #expect(torrents.count == 3)
        #expect(Set(torrents.map(\.infoHash)).count == torrents.count)
        #expect(torrents.map(\.seeders) == [342, 1_204, 567])
        #expect(torrents.map(\.leechers) == [28, 89, 34])
        #expect(torrents.map(\.sizeBytes) == [8_500_000_000, 3_200_000_000, 1_800_000_000])
        #expect(torrents.map(\.indexerName) == ["AwesomeTracker", "PublicHD", "RARBG"])
        #expect(torrents.map(\.quality) == [.uhd4k, .hd1080p, .hd720p])
        #expect(torrents.map(\.codec) == [.h265, .h264, .h264])
        #expect(torrents.map(\.source) == [.webDL, .webDL, .unknown])
        #expect(torrents.map(\.hdr) == [.hdr10, .sdr, .sdr])
        #expect(torrents.map(\.audio) == [.atmos, .eac3, .unknown])
        #expect(torrents[0].audio.spatialAudioHint)
        #expect(torrents[1].audio.surroundHint)
        #expect(torrents[0].qualityBadge == "4K / HDR10 / H.265 / Atmos / WEB-DL")
        #expect(torrents[2].qualityBadge == "720p / H.264")
        #expect(torrents.allSatisfy { $0.title.localizedCaseInsensitiveContains("Dune") })
    }

    @Test func episodeTorrentFixturesTargetTheSameEpisodeWithDistinctHashes() {
        let torrents = TestModeData.episodeTorrentResults

        #expect(torrents.count == 2)
        #expect(Set(torrents.map(\.infoHash)).count == torrents.count)
        #expect(torrents.allSatisfy { $0.title.contains("S03E01") })
        #expect(torrents.map(\.quality) == [.uhd4k, .hd1080p])
        #expect(torrents.map(\.codec) == [.h265, .h264])
        #expect(torrents.map(\.source) == [.webDL, .webDL])
        #expect(torrents.map(\.hdr) == [.hdr10, .sdr])
        #expect(torrents.map(\.audio) == [.eac3, .eac3])
        #expect(torrents.map(\.seeders) == [88, 341])
        #expect(torrents.map(\.indexerName) == ["AwesomeTracker", "PublicHD"])
        #expect(torrents[0].qualityBadge == "4K / HDR10 / H.265 / EAC3 / WEB-DL")
        #expect(torrents[1].qualityBadge == "1080p / H.264 / EAC3 / WEB-DL")
    }

    @Test func seriesSeasonAndEpisodeFixturesAreContiguous() {
        let seasons = TestModeData.seasons
        let episodes = TestModeData.episodes

        #expect(seasons.map(\.seasonNumber) == [1, 2, 3])
        #expect(seasons.map(\.episodeCount) == [10, 10, 9])
        #expect(seasons.allSatisfy { $0.posterURL == nil })
        #expect(seasons.last?.seasonNumber == episodes.first?.seasonNumber)
        #expect(seasons.reduce(0) { $0 + $1.episodeCount } == 29)

        #expect(episodes.map(\.id) == [
            "tt15677150-s3e1",
            "tt15677150-s3e2",
            "tt15677150-s3e3",
            "tt15677150-s3e4",
            "tt15677150-s3e5",
            "tt15677150-s3e6",
        ])
        #expect(episodes.map(\.episodeNumber) == [1, 2, 3, 4, 5, 6])
        #expect(Set(episodes.map(\.mediaId)) == ["tt15677150"])
        #expect(episodes.map(\.shortLabel) == ["S03E01", "S03E02", "S03E03", "S03E04", "S03E05", "S03E06"])
        #expect(episodes.first?.displayTitle == "S03E01 - Fanatics")
        #expect(episodes.compactMap(\.stillURL).count == 4)
        #expect(episodes.filter { $0.stillPath == nil }.count == 2)
        #expect(episodes.compactMap(\.runtime).reduce(0, +) == 215)
    }

    @Test func libraryEntriesCoverMovieAndSeriesFixtures() {
        let entries = TestModeData.libraryEntries
        let titles = Set(entries.map(\.title))

        #expect(entries.count == 6)
        #expect(Set(entries.map(\.id)).count == entries.count)
        #expect(entries.filter { $0.type == .movie }.count == 4)
        #expect(entries.filter { $0.type == .series }.count == 2)
        #expect(titles == Set([
            "Oppenheimer",
            "Poor Things",
            "The Bear",
            "Killers of the Flower Moon",
            "Slow Horses",
            "The Holdovers",
        ]))
        #expect(entries.allSatisfy { $0.posterURL != nil })
        #expect(entries.allSatisfy { $0.backdropURL == nil })
        #expect(entries.compactMap(\.year).min() == 2022)
        #expect(entries.compactMap(\.year).max() == 2023)
        #expect(entries.map(\.id) == [
            "tt15398776",
            "tt14230458",
            "tt14452776",
            "tt5537002",
            "tt5875444",
            "tt14849194",
        ])
        #expect(entries.allSatisfy { IMDbIdentifierPolicy.normalizedID(from: $0.id) != nil })
        #expect(entries.allSatisfy { $0.tmdbId == nil })
    }
}
