import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct LocalDownloadServiceTests {
    private final class ControlledSnapshotDownloader: @unchecked Sendable {
        private let lock = NSLock()
        private var continuations: [String: CheckedContinuation<URL, Error>] = [:]
        private var startedRepos: [String] = []
        private var progressHandlers: [String: @Sendable (Progress) -> Void] = [:]

        func downloader(
            repo: String,
            progressHandler: @escaping @Sendable (Progress) -> Void
        ) async throws -> URL {
            recordStarted(repo: repo)
            storeProgressHandler(progressHandler, for: repo)

            return try await withCheckedThrowingContinuation { continuation in
                storeContinuation(continuation, for: repo)
            }
        }

        func waitUntilStarted(repo: String) async {
            // Fast Task.yield polling (preserves the original timing so race tests still
            // observe transient start states), but BOUNDED by a wall-clock deadline so it
            // can never hang forever the way a `while true` loop could under executor
            // starvation. Mirrors the project's own `waitUntil` test helper.
            let deadline = ContinuousClock.now + .seconds(10)
            while ContinuousClock.now < deadline {
                if readyToResume(repo: repo) { return }
                await Task.yield()
            }
            Issue.record("Timed out waiting for download to start for repo \(repo)")
        }

        func started(repo: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            let didStart = startedRepos.contains(repo)
            return didStart
        }

        func startCount() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return startedRepos.count
        }

        func readyToResume(repo: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return startedRepos.contains(repo) && continuations[repo] != nil
        }

        func reportProgress(repo: String, completed: Int64, total: Int64) {
            let handler: (@Sendable (Progress) -> Void)? = {
                lock.lock()
                defer { lock.unlock() }
                return progressHandlers[repo]
            }()
            let progress = Progress(totalUnitCount: total)
            progress.completedUnitCount = completed
            handler?(progress)
        }

        func complete(repo: String, url: URL) {
            let continuation = takeContinuation(for: repo)
            continuation?.resume(returning: url)
        }

        func fail(repo: String, error: some Error) {
            let continuation = takeContinuation(for: repo)
            continuation?.resume(throwing: error)
        }

        private func recordStarted(repo: String) {
            lock.lock()
            defer { lock.unlock() }
            startedRepos.append(repo)
        }

        private func storeContinuation(_ continuation: CheckedContinuation<URL, Error>, for repo: String) {
            lock.lock()
            defer { lock.unlock() }
            continuations[repo] = continuation
        }

        private func storeProgressHandler(_ progressHandler: @escaping @Sendable (Progress) -> Void, for repo: String) {
            lock.lock()
            defer { lock.unlock() }
            progressHandlers[repo] = progressHandler
        }

        private func takeContinuation(for repo: String) -> CheckedContinuation<URL, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return continuations.removeValue(forKey: repo)
        }
    }

    private func makeTemporaryDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    private func makeLocalModel(
        id: String,
        displayName: String
    ) -> LocalModelDescriptor {
        let now = Date()
        return LocalModelDescriptor(
            id: id,
            displayName: displayName,
            huggingFaceRepo: id,
            revision: "main",
            parameterCount: "360M",
            quantization: "float16",
            diskSizeMB: 700,
            minMemoryMB: 800,
            expectedFileCount: 5,
            maxContextTokens: 2_048,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 1_024,
            status: .available,
            downloadProgress: 0,
            downloadedBytes: 0,
            totalBytes: 0,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: now,
            updatedAt: now
        )
    }

    private func waitForStatus(
        store: LocalModelCatalogStore,
        id: String,
        status expected: LocalModelStatus
    ) async throws -> LocalModelDescriptor {
        for _ in 0..<200 {
            if let model = try await store.model(id: id), model.status == expected {
                return model
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let model = try #require(try await store.model(id: id))
        Issue.record("Timed out waiting for \(id) to reach \(expected.rawValue); current status is \(model.status.rawValue)")
        return model
    }

    private func waitForProgress(
        store: LocalModelCatalogStore,
        id: String,
        minimumProgress: Double
    ) async throws -> LocalModelDescriptor {
        for _ in 0..<200 {
            if let model = try await store.model(id: id), model.downloadProgress >= minimumProgress {
                return model
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let model = try #require(try await store.model(id: id))
        Issue.record("Timed out waiting for \(id) progress >= \(minimumProgress); current progress is \(model.downloadProgress)")
        return model
    }

    @Test
    func staleCleanupTokenDoesNotClearNewerActiveDownload() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-race.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let first = makeLocalModel(id: "apple/first-model", displayName: "First")
        let second = makeLocalModel(id: "apple/second-model", displayName: "Second")
        let third = makeLocalModel(id: "apple/third-model", displayName: "Third")
        try await database.saveLocalModel(first)
        try await database.saveLocalModel(second)
        try await database.saveLocalModel(third)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(
            catalogStore: store,
            snapshotDownloader: downloader.downloader,
            diskSpaceProvider: { _ in .max } // ample free space so the race flow proceeds (each model needs ~700MB)
        )

        await service.downloadModel(id: first.id)
        await downloader.waitUntilStarted(repo: first.huggingFaceRepo)
        let firstState = await service.activeDownloadStateForTesting()
        #expect(firstState.modelID == first.id)
        #expect(firstState.token != nil)

        await service.cancelDownload(id: first.id)
        await service.downloadModel(id: second.id)
        await downloader.waitUntilStarted(repo: second.huggingFaceRepo)
        let secondState = await service.activeDownloadStateForTesting()
        #expect(secondState.modelID == second.id)
        #expect(secondState.token != nil)

        await service.clearActiveTaskIfCurrentForTesting(
            token: try #require(firstState.token),
            modelID: first.id
        )

        await service.downloadModel(id: third.id)
        #expect(!downloader.started(repo: third.huggingFaceRepo))

        let currentState = await service.activeDownloadStateForTesting()
        #expect(currentState.modelID == second.id)
        #expect(currentState.token == secondState.token)

        downloader.fail(repo: first.huggingFaceRepo, error: CancellationError())
        downloader.fail(repo: second.huggingFaceRepo, error: CancellationError())
    }

    @Test
    func matchingCleanupTokenClearsActiveDownloadState() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-token-clear.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeLocalModel(id: "apple/test-model", displayName: "Test")
        try await database.saveLocalModel(model)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)

        await service.downloadModel(id: model.id)
        await downloader.waitUntilStarted(repo: model.huggingFaceRepo)
        let state = await service.activeDownloadStateForTesting()
        #expect(state.modelID == model.id)

        await service.clearActiveTaskIfCurrentForTesting(
            token: try #require(state.token),
            modelID: model.id
        )

        let clearedState = await service.activeDownloadStateForTesting()
        #expect(clearedState.modelID == nil)
        #expect(clearedState.token == nil)

        downloader.fail(repo: model.huggingFaceRepo, error: CancellationError())
    }

    @Test
    func successfulDownloadUpdatesProgressStatusAndLocalPath() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-success.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeLocalModel(id: "apple/success-model", displayName: "Success")
        try await database.saveLocalModel(model)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)
        let downloadURL = tempDir.appendingPathComponent("downloaded-model", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadURL, withIntermediateDirectories: true)

        await service.downloadModel(id: model.id)
        await downloader.waitUntilStarted(repo: model.huggingFaceRepo)
        downloader.reportProgress(repo: model.huggingFaceRepo, completed: 64, total: 128)
        let progressed = try await waitForProgress(store: store, id: model.id, minimumProgress: 0.5)
        #expect(progressed.downloadedBytes == 64)
        #expect(progressed.totalBytes == 128)

        downloader.complete(repo: model.huggingFaceRepo, url: downloadURL)

        let downloaded = try await waitForStatus(store: store, id: model.id, status: .downloaded)
        #expect(downloaded.localPath == downloadURL.path)

        for _ in 0..<100 {
            let state = await service.activeDownloadStateForTesting()
            if state.modelID == nil {
                #expect(state.token == nil)
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("Successful download did not clear active state")
    }

    @Test
    func failedDownloadMarksModelFailedAndClearsActiveState() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-failure.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeLocalModel(id: "apple/failure-model", displayName: "Failure")
        try await database.saveLocalModel(model)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)

        await service.downloadModel(id: model.id)
        await downloader.waitUntilStarted(repo: model.huggingFaceRepo)
        downloader.fail(repo: model.huggingFaceRepo, error: URLError(.badServerResponse))

        _ = try await waitForStatus(store: store, id: model.id, status: .failed)

        for _ in 0..<100 {
            let state = await service.activeDownloadStateForTesting()
            if state.modelID == nil {
                #expect(state.token == nil)
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("Failed download did not clear active state")
    }

    @Test
    func unknownModelDoesNotStartDownloader() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-missing.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)

        await service.downloadModel(id: "missing/model")

        #expect(downloader.startCount() == 0)
        let state = await service.activeDownloadStateForTesting()
        #expect(state.modelID == nil)
        #expect(state.token == nil)
    }

    @Test
    func cancelNonActiveDownloadIsNoOp() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-cancel-noop.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)

        await service.cancelDownload(id: "missing/model")

        #expect(downloader.startCount() == 0)
        let state = await service.activeDownloadStateForTesting()
        #expect(state.modelID == nil)
        #expect(state.token == nil)
    }

    @Test
    func deleteModelResetsCatalogStateAndClearsActiveDownload() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeLocalModel(
            id: "local-delete-\(UUID().uuidString)/model",
            displayName: "Delete"
        )
        try await database.saveLocalModel(model)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)

        await service.downloadModel(id: model.id)
        await downloader.waitUntilStarted(repo: model.huggingFaceRepo)
        #expect((await service.activeDownloadStateForTesting()).modelID == model.id)

        await service.deleteModel(id: model.id)

        let reset = try #require(try await store.model(id: model.id))
        #expect(reset.status == .available)
        #expect(reset.downloadProgress == 0)
        #expect(reset.localPath == nil)
        #expect(reset.partialDownloadPath == nil)
        #expect((await service.activeDownloadStateForTesting()).modelID == nil)

        downloader.fail(repo: model.huggingFaceRepo, error: CancellationError())
    }

    @Test
    func directoryHelpersBuildStableAppAndHubPaths() throws {
        let appSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let caches = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let models = LocalDownloadService.modelsDirectoryURL(appSupportDirectory: appSupport)
        let hubRoot = try #require(LocalDownloadService.hubCacheRootDirectoryURL(cachesDirectory: caches))
        let repoCache = try #require(LocalDownloadService.hubCacheDirectoryURL(for: "apple/Test-Model", cachesDirectory: caches))

        #expect(models == appSupport.appendingPathComponent("VPStudio/Models", isDirectory: true))
        #expect(hubRoot == caches.appendingPathComponent("huggingface/hub", isDirectory: true))
        #expect(repoCache.lastPathComponent == "models--apple--Test-Model")
        #expect(repoCache.deletingLastPathComponent() == hubRoot)
    }

    @Test
    func progressNotifyThrottleAllowsFirstAndThrottlesImmediateRepeat() async {
        let throttle = ProgressNotifyThrottle()

        #expect(await throttle.shouldNotify(interval: 60))
        #expect(await throttle.shouldNotify(interval: 60) == false)
        #expect(await throttle.shouldNotify(interval: 0))
    }

    @Test
    func downloadFailsWhenDiskSpaceInsufficient() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-disk-space.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var model = makeLocalModel(id: "apple/large-model", displayName: "Large")
        model.diskSizeMB = 1_000_000
        try await database.saveLocalModel(model)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()

        // Deterministic 1-byte free space (far below the model's ~1TB requirement) so the
        // disk-space preflight reliably fails without depending on the host's real disk.
        let service = LocalDownloadService(
            catalogStore: store,
            snapshotDownloader: downloader.downloader,
            diskSpaceProvider: { _ in 1 }
        )

        await service.downloadModel(id: model.id)

        let failed = try await waitForStatus(store: store, id: model.id, status: .failed)
        #expect(failed.status == .failed)
        #expect((await service.activeDownloadStateForTesting()).modelID == nil)
        #expect(downloader.startCount() == 0)
    }

    @Test
    func secondDownloadWhileFirstInProgressIsNoOp() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-duplicate.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let first = makeLocalModel(id: "apple/first", displayName: "First")
        let second = makeLocalModel(id: "apple/second", displayName: "Second")
        try await database.saveLocalModel(first)
        try await database.saveLocalModel(second)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)

        await service.downloadModel(id: first.id)
        await downloader.waitUntilStarted(repo: first.huggingFaceRepo)

        await service.downloadModel(id: second.id)

        #expect(downloader.startCount() == 1)

        downloader.fail(repo: first.huggingFaceRepo, error: CancellationError())
    }

    @Test
    func cancelActiveDownloadResetsStatusToAvailable() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-cancel-active.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeLocalModel(id: "apple/cancel-test", displayName: "CancelTest")
        try await database.saveLocalModel(model)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)

        await service.downloadModel(id: model.id)
        await downloader.waitUntilStarted(repo: model.huggingFaceRepo)

        let downloading = try #require(try await store.model(id: model.id))
        #expect(downloading.status == .downloading)

        await service.cancelDownload(id: model.id)

        let afterCancel = try #require(try await store.model(id: model.id))
        #expect(afterCancel.status == .available)
        #expect((await service.activeDownloadStateForTesting()).modelID == nil)
    }

    @Test
    func deleteModelCleansUpHubCacheDirectory() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-delete-hubcache.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeLocalModel(id: "apple/hubcache-test", displayName: "HubCacheTest")
        try await database.saveLocalModel(model)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let cachesDir = tempDir.appendingPathComponent("Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
        let service = LocalDownloadService(
            catalogStore: store,
            snapshotDownloader: downloader.downloader,
            cachesDirectory: cachesDir
        )

        let hubRoot = LocalDownloadService.hubCacheRootDirectoryURL(cachesDirectory: cachesDir)
        let hubRootPath = try #require(hubRoot)
        try FileManager.default.createDirectory(at: hubRootPath, withIntermediateDirectories: true)

        let modelCachePath = LocalDownloadService.hubCacheDirectoryURL(for: model.huggingFaceRepo, cachesDirectory: cachesDir)
        let modelCache = try #require(modelCachePath)
        let modelCacheDir = modelCache
        try FileManager.default.createDirectory(at: modelCacheDir, withIntermediateDirectories: true)
        try "fake-model-data".write(to: modelCacheDir.appendingPathComponent("model.bin"), atomically: true, encoding: .utf8)

        await service.deleteModel(id: model.id)

        #expect(FileManager.default.fileExists(atPath: modelCacheDir.path) == false)
    }

    @Test
    func deleteModelCleansUpSanitizedAppSupportModelDirectory() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-delete-appsupport.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeLocalModel(id: "apple/delete-target", displayName: "DeleteTarget")
        try await database.saveLocalModel(model)

        let appSupport = tempDir.appendingPathComponent("ApplicationSupport", isDirectory: true)
        let modelDir = LocalDownloadService.modelsDirectoryURL(appSupportDirectory: appSupport)
            .appendingPathComponent("apple_delete-target", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        try "fake-model-data".write(to: modelDir.appendingPathComponent("model.bin"), atomically: true, encoding: .utf8)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(
            catalogStore: store,
            snapshotDownloader: downloader.downloader,
            appSupportDirectory: appSupport
        )

        await service.deleteModel(id: model.id)

        let reset = try #require(try await store.model(id: model.id))
        #expect(reset.status == .available)
        #expect(FileManager.default.fileExists(atPath: modelDir.path) == false)
    }

    @Test
    func downloadCancellationErrorResetsStatusToAvailable() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-cancellation.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeLocalModel(id: "apple/cancellation-test", displayName: "CancellationTest")
        try await database.saveLocalModel(model)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)

        await service.downloadModel(id: model.id)
        await downloader.waitUntilStarted(repo: model.huggingFaceRepo)

        downloader.fail(repo: model.huggingFaceRepo, error: CancellationError())

        let reset = try await waitForStatus(store: store, id: model.id, status: .available)
        #expect(reset.status == .available)
    }

    @Test
    func deleteNonExistentModelIsNoOp() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-delete-nonexistent.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)

        await service.deleteModel(id: "nonexistent/model")

        let state = await service.activeDownloadStateForTesting()
        #expect(state.modelID == nil)
        #expect(state.token == nil)
    }

    @Test
    func deleteMissingModelCleansHubCacheUsingRequestedID() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-delete-missing-cache.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cachesDir = tempDir.appendingPathComponent("Caches", isDirectory: true)
        let missingID = "missing/model"
        let cacheDirectory = try #require(
            LocalDownloadService.hubCacheDirectoryURL(for: missingID, cachesDirectory: cachesDir)
        )
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try "orphan-cache".write(
            to: cacheDirectory.appendingPathComponent("snapshot.bin"),
            atomically: true,
            encoding: .utf8
        )

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(
            catalogStore: store,
            snapshotDownloader: downloader.downloader,
            cachesDirectory: cachesDir
        )

        await service.deleteModel(id: missingID)

        #expect(FileManager.default.fileExists(atPath: cacheDirectory.path) == false)
        let state = await service.activeDownloadStateForTesting()
        #expect(state.modelID == nil)
        #expect(state.token == nil)
    }

    @Test
    func downloadWithZeroDiskSizeSucceeds() async throws {
        let (database, tempDir) = try await makeTemporaryDatabase(named: "local-download-zero-size.sqlite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var model = makeLocalModel(id: "apple/zero-size", displayName: "ZeroSize")
        model.diskSizeMB = 0
        try await database.saveLocalModel(model)

        let store = LocalModelCatalogStore(database: database)
        let downloader = ControlledSnapshotDownloader()
        let service = LocalDownloadService(catalogStore: store, snapshotDownloader: downloader.downloader)
        let downloadURL = tempDir.appendingPathComponent("downloaded", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadURL, withIntermediateDirectories: true)

        await service.downloadModel(id: model.id)
        await downloader.waitUntilStarted(repo: model.huggingFaceRepo)
        downloader.complete(repo: model.huggingFaceRepo, url: downloadURL)

        let downloaded = try await waitForStatus(store: store, id: model.id, status: .downloaded)
        #expect(downloaded.localPath == downloadURL.path)
    }
}
