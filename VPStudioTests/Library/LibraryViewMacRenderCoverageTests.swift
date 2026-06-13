import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit

@MainActor
@Suite("Library View macOS Render Coverage", .serialized)
struct LibraryViewMacRenderCoverageTests {
    @Test
    func hostsSeededLibraryStatesOnMacOS() {
        let appState = AppState(testHooks: .init())
        let now = Date(timeIntervalSince1970: 1_800)
        let watchlistRoot = makeLibraryFolder(
            id: LibraryFolder.systemFolderID(for: .watchlist),
            name: "Watchlist",
            listType: .watchlist,
            folderKind: .systemRoot,
            isSystem: true
        )
        let favoritesRoot = makeLibraryFolder(
            id: LibraryFolder.systemFolderID(for: .favorites),
            name: "Favorites",
            listType: .favorites,
            folderKind: .systemRoot,
            isSystem: true
        )
        let sciFi = makeLibraryFolder(
            id: "mac-folder-sci-fi",
            name: "Sci-Fi",
            parentId: watchlistRoot.id,
            listType: .watchlist
        )
        let miniseries = makeLibraryFolder(
            id: "mac-folder-miniseries",
            name: "Miniseries",
            parentId: favoritesRoot.id,
            listType: .favorites
        )
        let arrival = makeLibraryMediaItem(id: "mac-library-arrival", title: "Arrival", year: 2016)
        let severance = makeLibraryMediaItem(
            id: "mac-library-severance",
            type: .series,
            title: "Severance",
            year: 2022,
            posterPath: "/severance.jpg"
        )
        let historyItem = makeLibraryMediaItem(
            id: "mac-library-history",
            title: "Dune",
            year: 2021,
            backdropPath: "/dune-backdrop.jpg"
        )
        let mediaItems = [
            arrival.id: arrival,
            severance.id: severance,
            historyItem.id: historyItem,
        ]

        let variants: [(String, LibraryView)] = [
            ("Loading selection", LibraryView(
                initialIsLoadingSelection: true,
                disablesAutomaticTasks: true
            )),
            ("Empty favorites", LibraryView(
                initialSelectedList: .favorites,
                initialFolders: [favoritesRoot, miniseries],
                initialStatusMessage: "Import finished: no new library items were added.",
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Populated watchlist folder", LibraryView(
                initialSelectedList: .watchlist,
                initialSelectedFolderID: sciFi.id,
                initialEntries: [
                    makeLibraryEntry(id: "mac-entry-arrival", mediaId: arrival.id, folderId: sciFi.id, listType: .watchlist, addedAt: now),
                    makeLibraryEntry(id: "mac-entry-severance", mediaId: severance.id, folderId: watchlistRoot.id, listType: .watchlist, addedAt: now.addingTimeInterval(-60)),
                ],
                initialFolders: [watchlistRoot, sciFi],
                initialMediaItems: mediaItems,
                initialUserRatings: [
                    arrival.id: TasteEvent(mediaId: arrival.id, eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 9),
                ],
                initialStatusMessage: "Folder order updated.",
                initialManualFolderOrderIDs: [sciFi.id],
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("History dedupe", LibraryView(
                initialSelectedList: .history,
                initialHistoryEntries: [
                    makeWatchHistory(id: "mac-history-1", mediaId: historyItem.id, title: historyItem.title, watchedAt: now),
                    makeWatchHistory(id: "mac-history-2", mediaId: historyItem.id, title: historyItem.title, watchedAt: now.addingTimeInterval(-120)),
                ],
                initialMediaItems: mediaItems,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Action error refreshing", LibraryView(
                initialSelectedList: .watchlist,
                initialFolders: [watchlistRoot],
                initialActionError: .unknown("Could not refresh the library in macOS render coverage."),
                initialIsRefreshingTitleDuplicates: true,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Create folder sheet", LibraryView(
                initialSelectedList: .watchlist,
                initialFolders: [watchlistRoot, sciFi],
                initialIsShowingCreateFolderSheet: true,
                initialCreateFolderListType: .watchlist,
                initialIsLoadingSelection: false,
                initialCreateFolderName: "Weekend",
                initialCreateFolderErrorMessage: "Folder already exists.",
                autoFocusesCreateFolderNameField: false,
                disablesAutomaticTasks: true
            )),
            ("CSV import sheet", LibraryView(
                initialSelectedList: .favorites,
                initialFolders: [favoritesRoot, miniseries],
                initialIsShowingCSVImportSheet: true,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("CSV export sheet", LibraryView(
                initialSelectedList: .history,
                initialHistoryEntries: [
                    makeWatchHistory(id: "mac-export-history", mediaId: historyItem.id, title: historyItem.title, watchedAt: now),
                ],
                initialMediaItems: mediaItems,
                initialIsShowingCSVExportSheet: true,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Delete folder dialog", LibraryView(
                initialSelectedList: .watchlist,
                initialSelectedFolderID: sciFi.id,
                initialFolders: [watchlistRoot, sciFi],
                initialFolderPendingDeletion: sciFi,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in variants {
            let size = host(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 980, height: 820)
            )

            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }
    }

    private func makeLibraryMediaItem(
        id: String,
        type: MediaType = .movie,
        title: String,
        year: Int?,
        posterPath: String? = nil,
        backdropPath: String? = nil
    ) -> MediaItem {
        MediaItem(
            id: id,
            type: type,
            title: title,
            year: year,
            posterPath: posterPath,
            backdropPath: backdropPath,
            overview: "Library macOS render fixture.",
            genres: ["Drama"],
            imdbRating: 8.0,
            runtime: 120,
            status: "Released",
            tmdbId: 100
        )
    }

    private func makeLibraryEntry(
        id: String,
        mediaId: String,
        folderId: String,
        listType: UserLibraryEntry.ListType,
        addedAt: Date
    ) -> UserLibraryEntry {
        UserLibraryEntry(
            id: id,
            mediaId: mediaId,
            folderId: folderId,
            listType: listType,
            addedAt: addedAt
        )
    }

    private func makeLibraryFolder(
        id: String,
        name: String,
        parentId: String? = nil,
        listType: UserLibraryEntry.ListType,
        folderKind: LibraryFolder.FolderKind = .manual,
        isSystem: Bool = false
    ) -> LibraryFolder {
        LibraryFolder(
            id: id,
            name: name,
            parentId: parentId,
            listType: listType,
            folderKind: folderKind,
            isSystem: isSystem
        )
    }

    private func makeWatchHistory(
        id: String,
        mediaId: String,
        title: String,
        watchedAt: Date
    ) -> WatchHistory {
        WatchHistory(
            id: id,
            mediaId: mediaId,
            title: title,
            progress: 1_800,
            duration: 7_200,
            watchedAt: watchedAt,
            isCompleted: false
        )
    }

    private func host<Content: View>(_ view: Content) -> CGSize {
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = CGRect(x: 0, y: 0, width: 980, height: 820)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 820),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        window.orderOut(nil)
        Self.retainedWindows.append(window)
        if Self.retainedWindows.count > 8 {
            Self.retainedWindows.removeFirst(Self.retainedWindows.count - 8)
        }
        return size
    }

    private static var retainedWindows: [NSWindow] = []
}
#endif
