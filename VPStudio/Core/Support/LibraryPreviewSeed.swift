import Foundation

/// Realistic mock content for visual QA of the **real** Library surface (`LibraryView`).
///
/// Builds a populated watchlist — entries plus their cached `MediaItem`s, keyed for the grid —
/// from the shared TMDB-seeded previews, so the production library grid renders real artwork
/// without credentials or database access. Wired into Test Mode via
/// `LibraryView(initialEntries:initialMediaItems:initialFolders:initialIsLoadingSelection: false,
/// disablesAutomaticTasks: true)`, mirroring [`DiscoverPreviewSeed`] / [`DetailPreviewSeed`].
enum LibraryPreviewSeed {
    /// The list rendered by the preview.
    static let listType: UserLibraryEntry.ListType = .watchlist

    /// A mix of movies and shows drawn from the shared Discover seed.
    private static let entriesSeed: [DiscoverPreviewSeed.Entry] = [
        DiscoverPreviewSeed.movies[0],
        DiscoverPreviewSeed.shows[0],
        DiscoverPreviewSeed.movies[1],
        DiscoverPreviewSeed.shows[3],
        DiscoverPreviewSeed.movies[5],
        DiscoverPreviewSeed.shows[1],
    ]

    /// System root folder so the header's folder chip matches production state.
    static var folders: [LibraryFolder] {
        [
            LibraryFolder(
                id: LibraryFolder.systemFolderID(for: listType),
                name: LibraryFolder.systemFolderName(for: listType),
                listType: listType,
                folderKind: .systemRoot,
                isSystem: true,
                sortOrder: 0
            )
        ]
    }

    static var entries: [UserLibraryEntry] {
        let folderID = LibraryFolder.systemFolderID(for: listType)
        return entriesSeed.enumerated().map { index, entry in
            UserLibraryEntry(
                id: "seed-entry-\(entry.tmdbId)",
                mediaId: "seed-\(entry.tmdbId)",
                folderId: folderID,
                listType: listType,
                addedAt: Date(timeIntervalSince1970: 1_700_000_000 - Double(index) * 86_400)
            )
        }
    }

    static var mediaItems: [String: MediaItem] {
        var items: [String: MediaItem] = [:]
        for entry in entriesSeed {
            let id = "seed-\(entry.tmdbId)"
            items[id] = MediaItem(
                id: id,
                type: entry.type,
                title: entry.title,
                year: entry.year,
                posterPath: entry.poster,
                backdropPath: entry.backdrop,
                imdbRating: entry.rating,
                tmdbId: entry.tmdbId
            )
        }
        return items
    }
}
