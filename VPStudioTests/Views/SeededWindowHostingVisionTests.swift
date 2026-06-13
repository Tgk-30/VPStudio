#if os(visionOS)
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("Seeded Window Hosting visionOS")
struct SeededWindowHostingVisionTests {
    @Test func downloadsViewHostsGroupedRowStatesOnVisionOS() async throws {
        let appState = AppState(testHooks: .init())
        let manager = SeededDownloadManaging(tasks: makeSeededDownloadTasks())
        let viewModel = DownloadsViewModel(appState: appState, downloadManager: manager)
        await viewModel.load()

        #expect(viewModel.groups.count == 2)
        #expect(viewModel.tasks.contains { $0.status == .completed })
        #expect(viewModel.tasks.contains { $0.status == .failed })
        #expect(viewModel.tasks.contains { !$0.status.isTerminal })

        let hosted = try await hostInVisibleSeededWindow(
            NavigationStack {
                DownloadsView(viewModel: viewModel)
            }
            .environment(appState)
            .frame(width: 980, height: 840)
        )
        defer { tearDownSeededWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test func downloadsViewAutoCreatesViewModelAndLoadsEmptyStateOnVisionOS() async throws {
        let database = try DatabaseManager(inMemoryNamed: "downloads-auto-create-\(UUID().uuidString)")
        try await database.migrate()
        let downloadManager = DownloadManager(
            database: database,
            resumePersistedDownloadsOnInit: false
        )
        let appState = AppState(
            database: database,
            downloadManager: downloadManager,
            testHooks: .init()
        )

        let hosted = try await hostInVisibleSeededWindow(
            NavigationStack {
                DownloadsView(disablesAutomaticTasks: false)
            }
            .environment(appState)
            .frame(width: 980, height: 840)
        )
        defer { tearDownSeededWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
        #expect(try await downloadManager.listDownloads().isEmpty)
    }

    @Test func downloadsViewHostsErrorAndDialogStatesOnVisionOS() async throws {
        let appState = AppState(testHooks: .init())

        let rootErrorViewModel = DownloadsViewModel(
            appState: appState,
            downloadManager: SeededDownloadManaging(tasks: [])
        )
        rootErrorViewModel.rootError = .network(.offline)

        let inlineErrorViewModel = DownloadsViewModel(
            appState: appState,
            downloadManager: SeededDownloadManaging(tasks: makeSeededDownloadTasks())
        )
        await inlineErrorViewModel.load()
        inlineErrorViewModel.rootError = .network(.transport("Seeded downloads refresh failed."))

        let dialogViewModel = DownloadsViewModel(
            appState: appState,
            downloadManager: SeededDownloadManaging(tasks: makeSeededDownloadTasks())
        )
        await dialogViewModel.load()

        let views: [(String, AnyView)] = [
            ("Downloads root error", AnyView(NavigationStack {
                DownloadsView(
                    viewModel: rootErrorViewModel,
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
            ("Downloads inline error with group delete dialog", AnyView(NavigationStack {
                DownloadsView(
                    viewModel: inlineErrorViewModel,
                    initialConfirmDeleteMediaId: inlineErrorViewModel.groups.first?.mediaId,
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
            ("Downloads row delete dialog", AnyView(NavigationStack {
                DownloadsView(
                    viewModel: dialogViewModel,
                    initialConfirmDeleteTaskID: dialogViewModel.tasks.first?.id,
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
            ("Downloads validation alert", AnyView(NavigationStack {
                DownloadsView(
                    viewModel: dialogViewModel,
                    initialPlaybackValidationMessage: "The downloaded file is no longer available on disk.",
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
        ]

        for (name, view) in views {
            let hosted = try await hostInVisibleSeededWindow(
                view.frame(width: 980, height: 840)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 80_000_000)

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownSeededWindow(hosted.window)
        }
    }

    @Test func debridSettingsViewHostsSupportedAndUnsupportedRowsOnVisionOS() async throws {
        let fixture = try await makeSeededWindowFixture(named: "debrid-settings-seeded.sqlite")
        defer { try? FileManager.default.removeItem(at: fixture.rootDirectory) }

        let now = Date(timeIntervalSince1970: 1_000)
        let configs = [
            DebridConfig(
                id: "real-debrid-seeded",
                serviceType: .realDebrid,
                apiTokenRef: SecretReference.encode(
                    key: DebridConfig.secretKey(for: "real-debrid-seeded", serviceType: .realDebrid)
                ),
                isActive: true,
                priority: 0,
                createdAt: now,
                updatedAt: now
            ),
            DebridConfig(
                id: "easynews-seeded",
                serviceType: .easyNews,
                apiTokenRef: SecretReference.encode(
                    key: DebridConfig.secretKey(for: "easynews-seeded", serviceType: .easyNews)
                ),
                isActive: false,
                priority: 1,
                createdAt: now,
                updatedAt: now
            ),
        ]

        try await fixture.secretStore.setSecret(
            "real-token",
            for: DebridConfig.secretKey(for: "real-debrid-seeded", serviceType: .realDebrid)
        )
        try await fixture.secretStore.setSecret(
            "easy-token",
            for: DebridConfig.secretKey(for: "easynews-seeded", serviceType: .easyNews)
        )
        for config in configs {
            try await fixture.database.saveDebridConfig(config)
        }

        let appState = AppState(
            database: fixture.database,
            secretStore: fixture.secretStore,
            testHooks: .init()
        )

        let hosted = try await hostInVisibleSeededWindow(
            NavigationStack {
                DebridSettingsView(initialConfigs: configs)
            }
            .environment(appState)
            .frame(width: 720, height: 820)
        )
        defer { tearDownSeededWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(hosted.host.view.bounds.height > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test func indexerSettingsViewHostsConfiguredAndReAddRowsOnVisionOS() async throws {
        let fixture = try await makeSeededWindowFixture(named: "indexer-settings-seeded.sqlite")
        defer { try? FileManager.default.removeItem(at: fixture.rootDirectory) }

        let custom = IndexerConfig(
            id: "jackett-seeded",
            name: "Seeded Jackett",
            indexerType: .jackett,
            baseURL: "https://jackett.example",
            apiKey: SecretReference.encode(key: IndexerConfig.secretKey(for: "jackett-seeded")),
            isActive: true,
            priority: 0,
            endpointPath: "/api/v2.0/indexers/all/results/torznab/api",
            categoryFilter: "2000,5000",
            apiKeyTransport: .header
        )

        try await fixture.secretStore.setSecret(
            "jackett-token",
            for: IndexerConfig.secretKey(for: "jackett-seeded")
        )
        try await fixture.database.saveIndexerConfig(custom)

        let appState = AppState(
            database: fixture.database,
            secretStore: fixture.secretStore,
            testHooks: .init()
        )

        let hosted = try await hostInVisibleSeededWindow(
            NavigationStack {
                IndexerSettingsView(initialConfigs: [custom])
            }
            .environment(appState)
            .frame(width: 820, height: 900)
        )
        defer { tearDownSeededWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    private func makeSeededDownloadTasks() -> [DownloadTask] {
        let completedPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("vpstudio-seeded-download-complete.mkv")
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
}

private actor SeededDownloadManaging: DownloadManaging {
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

private actor SeededWindowSecretStore: SecretStore {
    private var secrets: [String: String] = [:]

    func setSecret(_ secret: String, for key: String) async throws {
        secrets[key] = secret
    }

    func getSecret(for key: String) async throws -> String? {
        secrets[key]
    }

    func deleteSecret(for key: String) async throws {
        secrets[key] = nil
    }

    func deleteAllSecrets() async throws {
        secrets.removeAll()
    }
}

@MainActor
private func makeSeededWindowFixture(
    named databaseName: String
) async throws -> (database: DatabaseManager, secretStore: SeededWindowSecretStore, rootDirectory: URL) {
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    let database = try DatabaseManager(inMemoryNamed: "\(databaseName)-\(UUID().uuidString)")
    try await database.migrate()
    return (database, SeededWindowSecretStore(), rootDirectory)
}

@MainActor
private func hostInVisibleSeededWindow<Content: View>(
    _ rootView: Content
) async throws -> (host: UIHostingController<Content>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let host = UIHostingController(rootView: rootView)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 980, height: 900)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    try await Task.sleep(nanoseconds: 120_000_000)
    return (host, window)
}

@MainActor
private func tearDownSeededWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    SeededWindowRetainer.windows.append(window)
}

@MainActor
private enum SeededWindowRetainer {
    static var windows: [UIWindow] = []
}
#endif
