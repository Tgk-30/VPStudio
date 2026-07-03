import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit

@MainActor
@Suite("DownloadsView macOS Render Coverage", .serialized)
struct DownloadsViewMacRenderCoverageTests {
    @Test
    func downloadsViewHostsGroupedRowStatesOnMacOS() async throws {
        let appState = AppState(testHooks: .init())
        let manager = SeededMacDownloadManaging(tasks: makeSeededDownloadTasks())
        let viewModel = DownloadsViewModel(appState: appState, downloadManager: manager)
        await viewModel.load()

        #expect(viewModel.groups.count == 2)
        #expect(viewModel.tasks.contains { $0.status == .completed })
        #expect(viewModel.tasks.contains { $0.status == .failed })
        #expect(viewModel.tasks.contains { !$0.status.isTerminal })

        let size = hostDownloadsView(
            NavigationStack {
                DownloadsView(
                    viewModel: viewModel,
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 840)
        )

        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test
    func downloadsViewHostsRootLoadingEmptyRootErrorAndInlineErrorStatesOnMacOS() async throws {
        let appState = AppState(testHooks: .init())

        let emptyViewModel = DownloadsViewModel(
            appState: appState,
            downloadManager: SeededMacDownloadManaging(tasks: [])
        )
        await emptyViewModel.load()

        let rootErrorViewModel = DownloadsViewModel(
            appState: appState,
            downloadManager: SeededMacDownloadManaging(tasks: [])
        )
        rootErrorViewModel.rootError = .network(.offline)

        let inlineErrorViewModel = DownloadsViewModel(
            appState: appState,
            downloadManager: SeededMacDownloadManaging(tasks: makeSeededDownloadTasks())
        )
        await inlineErrorViewModel.load()
        inlineErrorViewModel.rootError = .network(.transport("Seeded downloads refresh failed."))

        let variants: [(String, AnyView)] = [
            ("Root loading", AnyView(NavigationStack {
                DownloadsView(disablesAutomaticTasks: true)
            }.environment(appState))),
            ("Empty downloads", AnyView(NavigationStack {
                DownloadsView(viewModel: emptyViewModel, disablesAutomaticTasks: true)
            }.environment(appState))),
            ("Root error", AnyView(NavigationStack {
                DownloadsView(viewModel: rootErrorViewModel, disablesAutomaticTasks: true)
            }.environment(appState))),
            ("Inline error", AnyView(NavigationStack {
                DownloadsView(viewModel: inlineErrorViewModel, disablesAutomaticTasks: true)
            }.environment(appState))),
        ]

        for (name, view) in variants {
            let size = hostDownloadsView(view.frame(width: 980, height: 840))
            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }
    }

    @Test
    func downloadsViewHostsDialogAndPlaybackValidationStatesOnMacOS() async throws {
        let appState = AppState(testHooks: .init())
        let viewModel = DownloadsViewModel(
            appState: appState,
            downloadManager: SeededMacDownloadManaging(tasks: makeSeededDownloadTasks())
        )
        await viewModel.load()

        let firstGroup = try #require(viewModel.groups.first)
        let firstTask = try #require(viewModel.tasks.first)

        let variants: [(String, AnyView)] = [
            ("Group delete dialog", AnyView(NavigationStack {
                DownloadsView(
                    viewModel: viewModel,
                    initialConfirmDeleteMediaId: firstGroup.mediaId,
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
            ("Row delete dialog", AnyView(NavigationStack {
                DownloadsView(
                    viewModel: viewModel,
                    initialConfirmDeleteTaskID: firstTask.id,
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
            ("Validation alert", AnyView(NavigationStack {
                DownloadsView(
                    viewModel: viewModel,
                    initialPlaybackValidationMessage: "The downloaded file is no longer available on disk.",
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
        ]

        for (name, view) in variants {
            let size = hostDownloadsView(view.frame(width: 980, height: 840))
            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }
    }

    private func hostDownloadsView<Content: View>(_ view: Content) -> CGSize {
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = CGRect(x: 0, y: 0, width: 980, height: 840)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 840),
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

    private func makeSeededDownloadTasks() -> [DownloadTask] {
        let completedPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("vpstudio-mac-seeded-download-complete.mkv")
            .path
        let baseDate = Date(timeIntervalSince1970: 2_000)
        return [
            DownloadTask(
                id: "download-complete",
                mediaId: "movie-1",
                streamURL: "https://cdn.example.com/movie.mkv",
                fileName: "movie.mkv",
                status: .completed,
                progress: 1,
                bytesWritten: 900_000_000,
                totalBytes: 900_000_000,
                destinationPath: completedPath,
                mediaTitle: "Seeded Movie",
                mediaType: "movie",
                posterPath: "/seeded-movie.jpg",
                createdAt: baseDate,
                updatedAt: baseDate.addingTimeInterval(60)
            ),
            DownloadTask(
                id: "download-active",
                mediaId: "show-1",
                episodeId: "show-1-s1e1",
                streamURL: "https://cdn.example.com/show-s01e01.mkv",
                fileName: "show-s01e01.mkv",
                status: .downloading,
                progress: 0.42,
                bytesWritten: 420_000_000,
                totalBytes: 1_000_000_000,
                mediaTitle: "Seeded Show",
                mediaType: "series",
                seasonNumber: 1,
                episodeNumber: 1,
                episodeTitle: "Pilot",
                createdAt: baseDate.addingTimeInterval(10),
                updatedAt: baseDate.addingTimeInterval(50)
            ),
            DownloadTask(
                id: "download-queued",
                mediaId: "show-1",
                episodeId: "show-1-s1e2",
                streamURL: "https://cdn.example.com/show-s01e02.mkv",
                fileName: "show-s01e02.mkv",
                status: .queued,
                progress: 0,
                bytesWritten: 0,
                totalBytes: 800_000_000,
                mediaTitle: "Seeded Show",
                mediaType: "series",
                seasonNumber: 1,
                episodeNumber: 2,
                episodeTitle: "Signal",
                createdAt: baseDate.addingTimeInterval(20),
                updatedAt: baseDate.addingTimeInterval(40)
            ),
            DownloadTask(
                id: "download-failed",
                mediaId: "show-1",
                episodeId: "show-1-s1e3",
                streamURL: "https://cdn.example.com/show-s01e03.mkv",
                fileName: "show-s01e03.mkv",
                status: .failed,
                progress: 0.12,
                bytesWritten: 120_000_000,
                totalBytes: 1_000_000_000,
                errorMessage: "Seeded failure",
                mediaTitle: "Seeded Show",
                mediaType: "series",
                seasonNumber: 1,
                episodeNumber: 3,
                episodeTitle: "Retry",
                createdAt: baseDate.addingTimeInterval(30),
                updatedAt: baseDate.addingTimeInterval(30)
            ),
            DownloadTask(
                id: "download-cancelled",
                mediaId: "show-1",
                episodeId: "show-1-s1e4",
                streamURL: "https://cdn.example.com/show-s01e04.mkv",
                fileName: "show-s01e04.mkv",
                status: .cancelled,
                progress: 0.2,
                bytesWritten: 200_000_000,
                totalBytes: 1_000_000_000,
                mediaTitle: "Seeded Show",
                mediaType: "series",
                seasonNumber: 1,
                episodeNumber: 4,
                episodeTitle: "Cancelled",
                createdAt: baseDate.addingTimeInterval(35),
                updatedAt: baseDate.addingTimeInterval(20)
            ),
            DownloadTask(
                id: "download-resolving",
                mediaId: "show-1",
                episodeId: "show-1-s1e5",
                streamURL: "https://cdn.example.com/show-s01e05.mkv",
                fileName: "show-s01e05.mkv",
                status: .resolving,
                progress: 0.05,
                bytesWritten: 50_000_000,
                totalBytes: 1_000_000_000,
                mediaTitle: "Seeded Show",
                mediaType: "series",
                seasonNumber: 1,
                episodeNumber: 5,
                episodeTitle: "Resolving",
                createdAt: baseDate.addingTimeInterval(40),
                updatedAt: baseDate.addingTimeInterval(10)
            ),
        ]
    }

    private static var retainedWindows: [NSWindow] = []
}

private actor SeededMacDownloadManaging: DownloadManaging {
    private var tasks: [DownloadTask]

    init(tasks: [DownloadTask]) {
        self.tasks = tasks
    }

    func listDownloads() async throws -> [DownloadTask] {
        tasks
    }

    func cancelDownload(id: String) async {
        update(id: id) { $0.status = .cancelled }
    }

    func retryDownload(id: String) async throws {
        update(id: id) {
            $0.status = .queued
            $0.errorMessage = nil
        }
    }

    func removeDownload(id: String) async throws {
        tasks.removeAll { $0.id == id }
    }

    func removeDownloads(mediaId: String) async throws {
        tasks.removeAll { $0.mediaId == mediaId }
    }

    private func update(id: String, apply: (inout DownloadTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        apply(&tasks[index])
    }
}
#endif
