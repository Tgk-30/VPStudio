import Foundation
import CryptoKit
import Hub
import os

/// Actor managing HuggingFace model downloads with resume, integrity checks, and stall detection.
actor LocalDownloadService {
    typealias SnapshotDownloader = @Sendable (
        _ repo: String,
        _ revision: String,
        _ progressHandler: @escaping @Sendable (Progress) -> Void
    ) async throws -> URL
    typealias RevisionResolver = @Sendable (_ repo: String, _ revision: String) async throws -> String
    typealias DiskSpaceProvider = @Sendable (URL) -> Int64?

    private let catalogStore: LocalModelCatalogStore
    private let snapshotDownloader: SnapshotDownloader
    private let revisionResolver: RevisionResolver
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
        self.revisionResolver = Self.defaultRevisionResolver
        self.diskSpaceProvider = diskSpaceProvider
        self.fileManager = fileManager
        self.appSupportDirectory = appSupportDirectory
        self.cachesDirectory = cachesDirectory
    }

    init(
        catalogStore: LocalModelCatalogStore,
        snapshotDownloader: @escaping SnapshotDownloader,
        revisionResolver: @escaping RevisionResolver = LocalDownloadService.defaultRevisionResolver,
        fileManager: FileManager = .default,
        appSupportDirectory: URL? = nil,
        cachesDirectory: URL? = nil,
        diskSpaceProvider: DiskSpaceProvider? = nil
    ) {
        self.catalogStore = catalogStore
        self.snapshotDownloader = snapshotDownloader
        self.revisionResolver = revisionResolver
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

        let repo = model.huggingFaceRepo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repo.isEmpty else {
            logger.error("Refusing to download local model \(id): Hugging Face repo is blank")
            try? await catalogStore.updateStatus(id: id, to: .failed)
            return
        }
        guard Self.permitsRemoteSnapshotDownload(model) else {
            logger.error("Refusing to download local model \(id): mutable revision requires a catalog checksum")
            try? await catalogStore.updateStatus(id: id, to: .failed)
            return
        }

        let revision: String
        do {
            revision = try await resolveImmutableRevision(for: model, repo: repo)
        } catch {
            let reason = IndexerLogSanitizer.redactedErrorMessage(error)
            logger.error("Refusing to download local model \(id): \(reason)")
            try? await catalogStore.updateStatus(id: id, to: .failed)
            return
        }

        // Preflight: check disk space
        let requiredBytes = Int64(model.diskSizeMB) * 1_048_576
        let maximumSnapshotBytes = Self.maximumSnapshotBytes(forDiskSizeMB: model.diskSizeMB)
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

        let catalogStore = self.catalogStore
        let throttle = ProgressNotifyThrottle()
        let expectedChecksum = model.checksumSHA256

        let task = Task {
            do {
                try Task.checkCancellation()

                // Download model snapshot from HuggingFace Hub
                let localDir = try await self.snapshotDownloader(
                    repo,
                    revision,
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

                try LocalModelSnapshotIntegrity.verifySnapshotSize(
                    at: localDir,
                    maximumBytes: maximumSnapshotBytes,
                    fileManager: self.fileManager
                )
                try LocalModelSnapshotIntegrity.verifySnapshot(
                    at: localDir,
                    expectedSHA256: expectedChecksum,
                    fileManager: self.fileManager
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

    private func resolveImmutableRevision(for model: LocalModelDescriptor, repo: String) async throws -> String {
        if let immutableRevision = LocalModelRevisionPolicy.normalizedImmutableRevision(model.revision) {
            return immutableRevision
        }

        let requestedRevision = model.revision.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedRevision.isEmpty else {
            throw LocalModelDownloadPreflightError.blankRevision
        }

        let resolvedRevision = try await revisionResolver(repo, requestedRevision)
        guard let immutableRevision = LocalModelRevisionPolicy.normalizedImmutableRevision(resolvedRevision) else {
            throw LocalModelDownloadPreflightError.mutableRevision(requestedRevision)
        }

        try? await catalogStore.updateRevision(id: model.id, to: immutableRevision)
        return immutableRevision
    }

    private static func permitsRemoteSnapshotDownload(_ model: LocalModelDescriptor) -> Bool {
        if LocalModelRevisionPolicy.normalizedImmutableRevision(model.revision) != nil {
            return true
        }
        return model.checksumSHA256?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func maximumSnapshotBytes(forDiskSizeMB diskSizeMB: Int) -> Int64 {
        let expectedBytes = Int64(max(1, diskSizeMB)) * 1_048_576
        let tolerance = max(Int64(64 * 1_048_576), expectedBytes / 5)
        return expectedBytes + tolerance
    }

    private func clearActiveTaskIfCurrent(token: UUID, modelID: String) {
        guard activeTaskToken == token, activeModelID == modelID else { return }
        activeTask = nil
        activeModelID = nil
        activeTaskToken = nil
    }

    private static func defaultSnapshotDownloader(
        repo: String,
        revision: String,
        progressHandler: @escaping @Sendable (Progress) -> Void
    ) async throws -> URL {
        let hubRepo = Hub.Repo(id: repo)
        return try await HubApi.shared.snapshot(
            from: hubRepo,
            revision: revision,
            matching: ["*.mlmodelc/*", "*.mlpackage/*", "*.json", "*.jinja", "tokenizer*", "*.safetensors"],
            progressHandler: progressHandler
        )
    }

    private static func defaultRevisionResolver(repo: String, revision: String) async throws -> String {
        guard let url = HuggingFaceRevisionAPI.modelRevisionURL(repo: repo, revision: revision) else {
            throw LocalModelDownloadPreflightError.invalidRevisionURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await BoundedHTTPResponseLoader.data(
                from: url,
                session: .shared,
                maximumBytes: HTTPResponseBudget.modelRevisionMetadata
            )
        } catch is BoundedHTTPResponseError {
            throw LocalModelDownloadPreflightError.revisionResolutionFailed
        }
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw LocalModelDownloadPreflightError.revisionResolutionFailed
        }

        let payload = try JSONDecoder().decode(HuggingFaceRevisionAPI.Response.self, from: data)
        return payload.sha
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

// MARK: - Revision and Integrity Guards

enum LocalModelRevisionPolicy {
    private static let fullGitSHARegex = SensitiveURLQueryPolicy.regularExpression(pattern: #"^[0-9a-fA-F]{40}$"#)

    static func normalizedImmutableRevision(_ revision: String) -> String? {
        let trimmed = revision.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let fullGitSHARegex else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard fullGitSHARegex.firstMatch(in: trimmed, range: range) != nil else { return nil }
        return trimmed.lowercased()
    }
}

enum LocalModelDownloadPreflightError: LocalizedError {
    case blankRevision
    case invalidRevisionURL
    case revisionResolutionFailed
    case mutableRevision(String)
    case snapshotTooLarge(limitBytes: Int64, actualBytes: Int64)
    case checksumMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .blankRevision:
            return "local model revision is blank"
        case .invalidRevisionURL:
            return "local model revision could not be encoded for Hugging Face"
        case .revisionResolutionFailed:
            return "Hugging Face did not return an immutable commit revision"
        case .mutableRevision(let revision):
            return "revision '\(revision)' did not resolve to an immutable commit"
        case .snapshotTooLarge(let limitBytes, let actualBytes):
            return "snapshot exceeded local size budget; limit \(limitBytes) bytes, got \(actualBytes) bytes"
        case .checksumMismatch(let expected, let actual):
            return "snapshot checksum mismatch; expected \(expected), got \(actual)"
        }
    }
}

private enum HuggingFaceRevisionAPI {
    struct Response: Decodable {
        let sha: String
    }

    static func modelRevisionURL(repo: String, revision: String) -> URL? {
        let repoPath = repo
            .split(separator: "/", omittingEmptySubsequences: true)
            .compactMap { encodePathComponent(String($0)) }
            .joined(separator: "/")
        guard !repoPath.isEmpty,
              let encodedRevision = encodePathComponent(revision.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return URL(string: "https://huggingface.co/api/models/\(repoPath)/revision/\(encodedRevision)")
    }

    private static func encodePathComponent(_ component: String) -> String? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return component.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}

enum LocalModelSnapshotIntegrity {
    static func verifySnapshotSize(
        at directory: URL,
        maximumBytes: Int64,
        fileManager: FileManager = .default
    ) throws {
        let actual = try snapshotSizeBytes(at: directory, fileManager: fileManager)
        guard actual <= maximumBytes else {
            throw LocalModelDownloadPreflightError.snapshotTooLarge(
                limitBytes: maximumBytes,
                actualBytes: actual
            )
        }
    }

    static func verifySnapshot(
        at directory: URL,
        expectedSHA256: String?,
        fileManager: FileManager = .default
    ) throws {
        guard let expectedSHA256,
              !expectedSHA256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let actual = try snapshotDigest(at: directory, fileManager: fileManager)
        guard actual.caseInsensitiveCompare(expectedSHA256.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame else {
            throw LocalModelDownloadPreflightError.checksumMismatch(expected: expectedSHA256, actual: actual)
        }
    }

    static func snapshotSizeBytes(at directory: URL, fileManager: FileManager = .default) throws -> Int64 {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true else { continue }
            let size = values.totalFileAllocatedSize ?? values.fileSize ?? 0
            let safeSize = Int64(max(0, size))
            if total > Int64.max - safeSize {
                throw LocalModelDownloadPreflightError.snapshotTooLarge(
                    limitBytes: Int64.max,
                    actualBytes: Int64.max
                )
            }
            total += safeSize
        }
        return total
    }

    static func snapshotDigest(at directory: URL, fileManager: FileManager = .default) throws -> String {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return ""
        }

        var files: [URL] = []
        for item in enumerator {
            guard let url = item as? URL else { continue }
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            if values.isRegularFile == true {
                files.append(url)
            }
        }
        files.sort { $0.path < $1.path }

        var hasher = SHA256()
        for fileURL in files {
            let relativePath = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")
            hasher.update(data: Data(relativePath.utf8))
            hasher.update(data: Data([0]))

            let handle = try FileHandle(forReadingFrom: fileURL)
            while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            try? handle.close()
            hasher.update(data: Data([0]))
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
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
