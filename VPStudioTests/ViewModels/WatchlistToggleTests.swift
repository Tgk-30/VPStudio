import Foundation
import Testing
@testable import VPStudio

@Suite("Detail Library Actions", .serialized)
struct WatchlistToggleTests {
    private func makePreview(id: String = "preview-\(UUID().uuidString)", title: String = "Fallback Movie") -> MediaPreview {
        MediaPreview(
            id: id,
            type: .movie,
            title: title,
            year: 2025,
            posterPath: nil,
            imdbRating: nil,
            tmdbId: nil
        )
    }

    @MainActor private func withIsolatedAppState<T>(
        _ body: (AppState) async throws -> T
    ) async throws -> T {
        let database = try DatabaseManager(inMemoryNamed: "watchlist-test-\(UUID().uuidString)")
        let appState = AppState(database: database)
        try await appState.database.migrate()
        return try await body(appState)
    }

    @MainActor
    @Test func toggleWatchlistWorksWithPreviewFallbackWhenMediaItemIsUnavailable() async throws {
        try await withIsolatedAppState { appState in
            let preview = makePreview()

            let viewModel = DetailViewModel(appState: appState)
            viewModel.setPreviewContext(preview)

            await viewModel.toggleWatchlist()

            let inserted = try await appState.database.isInLibrary(mediaId: preview.id, listType: .watchlist)
            #expect(inserted)
            #expect(viewModel.isInWatchlist == true)

            await viewModel.toggleWatchlist()

            let removed = try await appState.database.isInLibrary(mediaId: preview.id, listType: .watchlist)
            #expect(removed == false)
            #expect(viewModel.isInWatchlist == false)
        }
    }

    @MainActor
    @Test func toggleFavoritesWorksWithPreviewFallbackWhenMediaItemIsUnavailable() async throws {
        try await withIsolatedAppState { appState in
            let preview = makePreview(title: "Favorite Candidate")
            let viewModel = DetailViewModel(appState: appState)
            viewModel.setPreviewContext(preview)

            await viewModel.toggleFavorites()

            let inserted = try await appState.database.isInLibrary(mediaId: preview.id, listType: .favorites)
            #expect(inserted)
            #expect(viewModel.isInFavorites == true)

            await viewModel.toggleFavorites()

            let removed = try await appState.database.isInLibrary(mediaId: preview.id, listType: .favorites)
            #expect(removed == false)
            #expect(viewModel.isInFavorites == false)
        }
    }

    @MainActor
    @Test func addOrMoveToLibraryAddsToSpecificWatchlistFolder() async throws {
        try await withIsolatedAppState { appState in
            let customFolder = try await appState.database.createLibraryFolder(name: "Weekend Picks", listType: .watchlist)

            let preview = makePreview(title: "Folder Test")
            let viewModel = DetailViewModel(appState: appState)
            viewModel.setPreviewContext(preview)

            await viewModel.addOrMoveToLibrary(
                listType: .watchlist,
                folderId: customFolder.id,
                folderName: customFolder.name
            )

            let watchlistInFolder = try await appState.database.fetchLibraryEntries(listType: .watchlist, folderId: customFolder.id)
            #expect(watchlistInFolder.count == 1)
            #expect(watchlistInFolder.first?.mediaId == preview.id)
            #expect(viewModel.isInWatchlist)
            #expect(viewModel.libraryStatusMessage?.contains(customFolder.name) == true)
        }
    }

    @MainActor
    @Test func addOrMoveToLibraryMovesExistingFavoriteEntryToSelectedFolder() async throws {
        try await withIsolatedAppState { appState in
            let sourceFolder = try await appState.database.createLibraryFolder(name: "Primary", listType: .favorites)
            let destinationFolder = try await appState.database.createLibraryFolder(name: "Archive", listType: .favorites)

            let preview = makePreview(title: "Move Test")
            let viewModel = DetailViewModel(appState: appState)
            viewModel.setPreviewContext(preview)

            await viewModel.addOrMoveToLibrary(
                listType: .favorites,
                folderId: sourceFolder.id,
                folderName: sourceFolder.name
            )
            await viewModel.addOrMoveToLibrary(
                listType: .favorites,
                folderId: destinationFolder.id,
                folderName: destinationFolder.name
            )

            let inSource = try await appState.database.fetchLibraryEntries(listType: .favorites, folderId: sourceFolder.id)
            let inDestination = try await appState.database.fetchLibraryEntries(listType: .favorites, folderId: destinationFolder.id)

            #expect(inSource.isEmpty)
            #expect(inDestination.count == 1)
            #expect(inDestination.first?.mediaId == preview.id)
            #expect(viewModel.isInFavorites)
            #expect(viewModel.libraryStatusMessage?.contains("Moved to \(destinationFolder.name)") == true)
        }
    }

    @MainActor
    @Test func toggleWatchlistShowsActionableMessageWhenIdentifierIsMissing() async throws {
        try await withIsolatedAppState { appState in
            let viewModel = DetailViewModel(appState: appState)
            await viewModel.toggleWatchlist()

            #expect(viewModel.libraryStatusMessage?.contains("missing media identifier") == true)
        }
    }

    @MainActor
    @Test func addOrMoveToLibraryShowsActionableMessageWhenIdentifierIsMissing() async throws {
        try await withIsolatedAppState { appState in
            let viewModel = DetailViewModel(appState: appState)
            await viewModel.addOrMoveToLibrary(listType: .favorites, folderId: "missing", folderName: "Missing")

            #expect(viewModel.libraryStatusMessage?.contains("missing media identifier") == true)
        }
    }
}
