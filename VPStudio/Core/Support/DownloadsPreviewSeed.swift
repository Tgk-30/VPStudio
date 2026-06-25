import Foundation

/// Realistic mock content for visual QA of the **real** Downloads surface (`DownloadsView`).
///
/// Builds two in-flight downloads (one downloading, one resolving) plus one completed item,
/// grouped the way `DownloadsViewModel` groups them, using the shared IMDb-keyed artwork seed.
/// Wired into Test Mode via a seeded
/// `DownloadsViewModel` rendered behind `DownloadsView(viewModel:disablesAutomaticTasks: true)`,
/// mirroring [`DiscoverPreviewSeed`] / [`DetailPreviewSeed`].
enum DownloadsPreviewSeed {
    static var tasks: [DownloadTask] { groups.flatMap(\.tasks) }

    static var groups: [DownloadMediaGroup] {
        let dune = DiscoverPreviewSeed.movies[0]
        let severance = DiscoverPreviewSeed.shows[0]
        let oppenheimer = DiscoverPreviewSeed.movies[1]

        let downloading = DownloadTask(
            id: "seed-dl-dune",
            mediaId: dune.imdbId,
            fileName: "Dune.Part.Two.2024.2160p.HDR.mkv",
            status: .downloading,
            progress: 0.62,
            bytesWritten: 5_300_000_000,
            totalBytes: 8_500_000_000,
            mediaTitle: dune.title,
            mediaType: "movie",
            posterPath: dune.poster,
            // Recent start so the average-speed ETA renders realistically in QA
            // (5.3 GB in ~200s ≈ 26 MB/s → ~2 min left on the remaining 3.2 GB).
            createdAt: Date(timeIntervalSinceNow: -200)
        )
        let resolving = DownloadTask(
            id: "seed-dl-severance",
            mediaId: severance.imdbId,
            episodeId: "\(severance.imdbId)-s2e1",
            fileName: "Severance.S02E01.1080p.mkv",
            status: .resolving,
            progress: 0,
            bytesWritten: 0,
            totalBytes: 2_100_000_000,
            mediaTitle: severance.title,
            mediaType: "series",
            posterPath: severance.poster,
            seasonNumber: 2,
            episodeNumber: 1,
            episodeTitle: "Hello, Ms. Cobel",
            createdAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
        let completed = DownloadTask(
            id: "seed-dl-oppenheimer",
            mediaId: oppenheimer.imdbId,
            fileName: "Oppenheimer.2023.2160p.mkv",
            status: .completed,
            progress: 1,
            bytesWritten: 7_900_000_000,
            totalBytes: 7_900_000_000,
            mediaTitle: oppenheimer.title,
            mediaType: "movie",
            posterPath: oppenheimer.poster,
            createdAt: Date(timeIntervalSince1970: 1_699_000_000)
        )

        return [
            DownloadMediaGroup(
                mediaId: downloading.mediaId,
                mediaTitle: dune.title,
                mediaType: "movie",
                posterPath: dune.poster,
                tasks: [downloading]
            ),
            DownloadMediaGroup(
                mediaId: resolving.mediaId,
                mediaTitle: severance.title,
                mediaType: "series",
                posterPath: severance.poster,
                tasks: [resolving]
            ),
            DownloadMediaGroup(
                mediaId: completed.mediaId,
                mediaTitle: oppenheimer.title,
                mediaType: "movie",
                posterPath: oppenheimer.poster,
                tasks: [completed]
            ),
        ]
    }
}
