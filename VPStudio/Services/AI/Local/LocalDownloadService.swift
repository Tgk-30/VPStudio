import Foundation
import Hub
import os

/// Actor managing HuggingFace model downloads with resume, integrity checks, and stall detection.
actor LocalDownloadService {
    typealias SnapshotDownloader = @Sendable (
        _ repo: String,
        _ progressHandler: @escaping @Sendable (Progress) -> Void
    ) async throws -> URL
    typealias DiskSpaceProvider = @Sendable (URL) -> Int64?

    private let catalogStore: LocalModelCatalogStore
    private let snapshotDownloader: SnapshotDownloader
    private let diskSpaceProvider: DiskSpaceProvider?
    private let fileManager: FileManager
    private let appSupportDirectory: URL?
    private let cachesDirectory: URL?
    private let logger = Logger(subsystem: "com.vpstudio", category: "local-download")

    private var activeTask: Task<Void, Never>?
    private var activeModelID: String?
    private var activeTaskToken: UUID?

    init(
        catalogStore: LocalModelCatalogStore,
        fileManager: FileManager = .default,
        appSupportDirectory: URL? = nil,
        cachesDirectory: URL? = nil,
        diskSpaceProvider: DiskSpaceProvider? = nil
    ) {
        self.catalogStore = catalogStore
        self.snapshotDownloader = Self.defaultSnapshotDownloader
        self.diskSpaceProvider = diskSpaceProvider
        self.fileManager = fileManager
        self.appSupportDirectory = appSupportDirectory
        self.cachesDirectory = cachesDirectory
    }

    init(
        catalogStore: LocalModelCatalogStore,
        snapshotDownloader: @escaping SnapshotDownloader,
        fileManager: FileManager = .default,
        appSupportDirectory: URL? = nil,
        cachesDirectory: URL? = nil,
        diskSpaceProvider: DiskSpaceProvider? = nil
    ) {
        self.catalogStore = catalogStore
        self.snapshotDownloader = snapshotDownloader
        self.diskSpaceProvider = diskSpaceProvider
        self.fileManager = fileManager
        self.appSupportDirectory = appSupportDirectory
        self.cachesDirectory = cachesDirectory
    }

    // MARK: - Models Directory

    static var modelsDirectory: URL {
        modelsDirectoryURL()
    }

    static func modelsDirectoryURL(
        fileManager: FileManager = .default,
        appSupportDirectory: URL? = nil
    ) -> URL {
        let appSupport = appSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("VPStudio/Models", isDirectory: true)
    }

    static func hubCacheRootDirectoryURL(
        fileManager: FileManager = .default,
        cachesDirectory: URL? = nil
    ) -> URL? {
        (cachesDirectory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first)?
            .appendingPathComponent("huggingface/hub", isDirectory: true)
    }

    static func hubCacheDirectoryURL(
        for repo: String,
        fileManager: FileManager = .default,
        cachesDirectory: URL? = nil
    ) -> URL? {
        hubCacheRootDirectoryURL(fileManager: fileManager, cachesDirectory: cachesDirectory)?
            .appendingPathComponent("models--\(repo.replacingOccurrences(of: "/", with: "--"))")
    }

    // MARK: - Download

    func downloadModel(id: String) async {
        guard self.activeTask == nil else {
            self.logger.warning("Download already in progress for \(self.activeModelID ?? "unknown")")
            return
        }

        guard let model = try? await catalogStore.model(id: id) else {
            logger.error("Model not found in catalog: \(id)")
            return
        }

        // Preflight: check disk space
        let requiredBytes = Int64(model.diskSizeMB) * 1_048_576
        if let available = diskSpaceAvailable(), available < requiredBytes {
            logger.error("Insufficient disk space: need \(model.diskSizeMB)MB, have \(available / 1_048_576)MB")
            try? await catalogStore.updateStatus(id: id, to: .failed)
            return
        }

        activeModelID = id
        let taskToken = UUID()
        activeTaskToken = taskToken
        try? await catalogStore.updateStatus(id: id, to: .downloading)
        await postDidChange() // Notify UI immediately so status shows "downloading"

        let repo = model.huggingFaceRepo
        let catalogStore = self.catalogStore
        let throttle = ProgressNotifyThrottle()

        let task = Task {
            do {
                try Task.checkCancellation()

                // Download model snapshot from HuggingFace Hub
                let localDir = try await self.snapshotDownloader(
                    repo,
                    { progress in
                        Task {
                            // Drop writes from a download that was cancelled or superseded
                            // (cancelDownload/deleteModel nil out activeTaskToken), so a stale
                            // tick can't resurrect cancelled progress or regress the percentage.
                            guard await self.isActiveToken(taskToken) else { return }
                            try? await catalogStore.updateProgress(
                                id: id,
                                progress: progress.fractionCompleted,
                                downloadedBytes: Int64(progress.completedUnitCount),
                                totalBytes: Int64(progress.totalUnitCount)
                            )
                            if await throttle.shouldNotify() {
                                await MainActor.run {
                                    NotificationCenter.default.post(name: .localModelsDidChange, object: nil)
                                }
                            }
                        }
                    }
                )

                try? await catalogStore.updateStatus(id: id, to: .downloaded, localPath: localDir.path)
                self.clearActiveTaskIfCurrent(token: taskToken, modelID: id)
                await self.postDidChange()
            } catch is CancellationError {
                try? await catalogStore.resetToAvailable(id: id)
                self.clearActiveTaskIfCurrent(token: taskToken, modelID: id)
                await self.postDidChange()
            } catch {
                try? await catalogStore.updateStatus(id: id, to: .failed)
                self.clearActiveTaskIfCurrent(token: taskToken, modelID: id)
                await self.postDidChange()
            }
        }
        activeTask = task
    }

    /// True while `token` is still the in-flight download's token. Progress callbacks that
    /// fire after the download was cancelled or superseded (which nil out `activeTaskToken`)
    /// use this to drop stale writes.
    func isActiveToken(_ token: UUID) -> Bool {
        activeTaskToken == token
    }

    // MARK: - Cancel

    func cancelDownload(id: String) async {
        guard activeModelID == id else { return }
        activeTask?.cancel()
        activeTask = nil
        activeModelID = nil
        activeTaskToken = nil
        try? await catalogStore.resetToAvailable(id: id)
        await postDidChange()
    }

    // MARK: - Delete

    func deleteModel(id: String) async {
        // Cancel if actively downloading
        if activeModelID == id {
            await cancelDownload(id: id)
        }

        let model = try? await catalogStore.model(id: id)

        // Remove files
        let modelDir = Self.modelsDirectoryURL(
            fileManager: fileManager,
            appSupportDirectory: appSupportDirectory
        ).appendingPathComponent(
            id.replacingOccurrences(of: "/", with: "_"),
            isDirectory: true
        )
        try? fileManager.removeItem(at: modelDir)

        // Also clean up MLXLLM's default cache location
        let repo = model?.huggingFaceRepo ?? id
        if let repoDir = Self.hubCacheDirectoryURL(
            for: repo,
            fileManager: fileManager,
            cachesDirectory: cachesDirectory
        ) {
            try? fileManager.removeItem(at: repoDir)
        }

        try? await catalogStore.resetToAvailable(id: id)
        await postDidChange()
    }

    // MARK: - Helpers

    private func diskSpaceAvailable() -> Int64? {
        let url = Self.modelsDirectoryURL(
            fileManager: fileManager,
            appSupportDirectory: appSupportDirectory
        )
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        if let diskSpaceProvider {
            return diskSpaceProvider(url)
        }
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage,
           capacity > 0 {
            return capacity
        }
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let capacity = values.volumeAvailableCapacity {
            return Int64(capacity)
        }
        return nil
    }

    private static func hubCacheDirectory(for repo: String) -> URL? {
        hubCacheDirectoryURL(for: repo)
    }

    private func postDidChange() async {
        await MainActor.run {
            NotificationCenter.default.post(name: .localModelsDidChange, object: nil)
        }
    }

    private func clearActiveTaskIfCurrent(token: UUID, modelID: String) {
        guard activeTaskToken == token, activeModelID == modelID else { return }
        activeTask = nil
        activeModelID = nil
        activeTaskToken = nil
    }

    private static func defaultSnapshotDownloader(
        repo: String,
        progressHandler: @escaping @Sendable (Progress) -> Void
    ) async throws -> URL {
        let hubRepo = Hub.Repo(id: repo)
        return try await HubApi.shared.snapshot(
            from: hubRepo,
            matching: ["*.mlmodelc/*", "*.mlpackage/*", "*.json", "*.jinja", "tokenizer*", "*.safetensors"],
            progressHandler: progressHandler
        )
    }

#if DEBUG
    func activeDownloadStateForTesting() -> (modelID: String?, token: UUID?) {
        (activeModelID, activeTaskToken)
    }

    func clearActiveTaskIfCurrentForTesting(token: UUID, modelID: String) {
        clearActiveTaskIfCurrent(token: token, modelID: modelID)
    }
#endif
}

// MARK: - Thread-safe Progress Throttle

/// Sendable throttle for progress notifications.
actor ProgressNotifyThrottle {
    private var lastNotifyTime = Date.distantPast

    func shouldNotify(interval: TimeInterval = 2) -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastNotifyTime) >= interval {
            lastNotifyTime = now
            return true
        }
        return false
    }
}
