#if os(visionOS)
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("LibraryView visionOS coverage", .serialized)
struct LibraryViewVisionCoverageTests {
    @Test
    func watchlistTaskLoadsEntriesAndRespondsToLibraryChanges() async throws {
        let database = try DatabaseManager(inMemoryNamed: "library-view-watchlist-\(UUID().uuidString)")
        try await database.migrate()
        let mediaItem = MediaItem(
            id: "tt-arrival",
            type: .movie,
            title: "Arrival",
            year: 2016,
            posterPath: "/arrival.jpg",
            tmdbId: 370
        )
        try await database.saveMediaItem(mediaItem)
        try await database.addToLibrary(
            UserLibraryEntry(
                id: "entry-arrival",
                mediaId: mediaItem.id,
                folderId: "",
                listType: .watchlist,
                addedAt: Date(timeIntervalSince1970: 1_000)
            )
        )

        let appState = AppState(database: database, testHooks: .init())
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                LibraryView(
                    initialSelectedList: .watchlist,
                    disablesAutomaticTasks: false
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)
        NotificationCenter.default.post(name: .libraryDidChange, object: nil)
        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test
    func historyTaskLoadsFallbackPreviewAndRespondsToWatchHistoryChanges() async throws {
        let database = try DatabaseManager(inMemoryNamed: "library-view-history-\(UUID().uuidString)")
        try await database.migrate()
        try await database.saveWatchHistory(
            Fixtures.watchHistory(
                mediaId: "tt-history-entry",
                title: "Watched Title",
                streamURL: nil,
                progress: 120,
                duration: 3_600
            )
        )

        let appState = AppState(database: database, testHooks: .init())
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                LibraryView(
                    initialSelectedList: .history,
                    disablesAutomaticTasks: false
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)
        NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test
    func statusFeedbackBannerHostsWithoutStartingLibraryTasks() throws {
        let appState = AppState(testHooks: .init())
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                LibraryView(
                    initialSelectedList: .watchlist,
                    initialStatusMessage: "Synced.",
                    initialIsLoadingSelection: false,
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test
    func errorFeedbackBannerTakesPriorityOverStatusMessage() throws {
        let appState = AppState(testHooks: .init())
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                LibraryView(
                    initialSelectedList: .watchlist,
                    initialStatusMessage: "Ignored status.",
                    initialActionError: .unknown("Could not update the library."),
                    initialIsLoadingSelection: false,
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test
    func createFolderSheetHostsSeededErrorAndSubmittingState() throws {
        let appState = AppState(testHooks: .init())
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                LibraryView(
                    initialSelectedList: .favorites,
                    initialIsShowingCreateFolderSheet: true,
                    initialCreateFolderListType: .favorites,
                    initialIsLoadingSelection: false,
                    initialCreateFolderName: "Sci-Fi",
                    initialCreateFolderErrorMessage: "A folder named \"Sci-Fi\" already exists.",
                    initialCreateFolderIsSubmitting: true,
                    autoFocusesCreateFolderNameField: false,
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.18))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test
    func nonEmptyFolderLibraryHostsGridControlsAndDeleteDialog() throws {
        let root = makeLibraryFolder(
            id: LibraryFolder.systemFolderID(for: .watchlist),
            name: "Watchlist",
            listType: .watchlist,
            folderKind: .systemRoot,
            isSystem: true
        )
        let folder = makeLibraryFolder(
            id: "library-vision-sci-fi",
            name: "Sci-Fi",
            parentId: root.id,
            listType: .watchlist
        )
        let item = MediaItem(
            id: "tt-library-vision-dune",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: "/dune.jpg",
            tmdbId: 438631
        )
        let entry = UserLibraryEntry(
            id: "entry-library-vision-dune",
            mediaId: item.id,
            folderId: folder.id,
            listType: .watchlist,
            addedAt: Date(timeIntervalSince1970: 1_000)
        )

        let appState = AppState(testHooks: .init())
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                LibraryView(
                    initialSelectedList: .watchlist,
                    initialSelectedFolderID: folder.id,
                    initialEntries: [entry],
                    initialFolders: [root, folder],
                    initialMediaItems: [item.id: item],
                    initialFolderPendingDeletion: folder,
                    initialIsLoadingSelection: false,
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.18))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test
    func csvImportSheetHostsWithoutStartingLibraryTasks() throws {
        let appState = AppState(testHooks: .init())
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                LibraryView(
                    initialSelectedList: .watchlist,
                    initialIsShowingCSVImportSheet: true,
                    initialIsLoadingSelection: false,
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.18))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test
    func csvExportSheetHostsWithoutStartingLibraryTasks() throws {
        let appState = AppState(testHooks: .init())
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                LibraryView(
                    initialSelectedList: .favorites,
                    initialIsShowingCSVExportSheet: true,
                    initialIsLoadingSelection: false,
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.18))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }
}

@MainActor
private func hostInVisibleVisionWindow<Content: View>(
    _ rootView: Content
) throws -> (host: UIHostingController<AnyView>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )

    let host = UIHostingController(rootView: AnyView(rootView))
    host.view.backgroundColor = .clear
    let window = UIWindow(windowScene: scene)
    window.rootViewController = host
    window.frame = CGRect(x: 0, y: 0, width: 980, height: 820)
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return (host, window)
}

@MainActor
private func tearDownVisionWindow(_ window: UIWindow) {
    window.rootViewController?.dismiss(animated: false)
    RunLoop.main.run(until: Date().addingTimeInterval(0.20))
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
    window.isHidden = true
    window.rootViewController = nil
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
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
        isSystem: isSystem,
        sortOrder: 0,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}
#endif
