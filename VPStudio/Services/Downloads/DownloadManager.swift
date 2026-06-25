import Foundation

final class DownloadCancellationController: @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelledFlag = false
    private var callbacks: [@Sendable () -> Void] = []

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledFlag
    }

    func register(_ callback: @escaping @Sendable () -> Void) {
        let shouldInvokeImmediately: Bool
        lock.lock()
        if isCancelledFlag {
            shouldInvokeImmediately = true
        } else {
            callbacks.append(callback)
            shouldInvokeImmediately = false
        }
        lock.unlock()

        if shouldInvokeImmediately {
            callback()
        }
    }

    func cancel() {
        let pendingCallbacks: [@Sendable () -> Void]
        lock.lock()
        guard !isCancelledFlag else {
            lock.unlock()
            return
        }
        isCancelledFlag = true
        pendingCallbacks = callbacks
        callbacks.removeAll()
        lock.unlock()

        for callback in pendingCallbacks {
            callback()
        }
    }
}

enum DownloadTransferError: LocalizedError {
    case badHTTPStatus(Int)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case resumeDataProduced(Data)

    var errorDescription: String? {
        switch self {
        case .badHTTPStatus(let statusCode):
            return "Download failed with HTTP \(statusCode)."
        case .insufficientDiskSpace(let required, let available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "Not enough free space to start this download. Need \(formatter.string(fromByteCount: required)), only \(formatter.string(fromByteCount: max(available, 0))) is available."
        case .resumeDataProduced:
            return "Download paused."
        }
    }
}

actor DownloadManager {
    struct TransferRequest: Sendable {
        let url: URL?
        let resumeData: Data?
        let requestHeaders: [String: String]?

        init(url: URL?, resumeData: Data?, requestHeaders: [String: String]? = nil) {
            self.url = url
            self.resumeData = resumeData
            self.requestHeaders = StreamInfo.normalizedRequestHeaders(requestHeaders)
        }

        var hasTransportState: Bool {
            url != nil || resumeData != nil || requestHeaders != nil
        }
    }

    typealias DownloadPerformer = @Sendable (TransferRequest, @escaping @Sendable (Int64, Int64, Int64) -> Void, DownloadCancellationController) async throws -> (URL, URLResponse)
    typealias LinkRefresher = @Sendable (StreamRecoveryContext) async throws -> URL
    typealias RemoteTransferCleaner = @Sendable (StreamRecoveryContext) async -> Void
    typealias SleepClosure = @Sendable (Duration) async throws -> Void
    typealias AvailableDiskSpaceProvider = @Sendable (URL) throws -> Int64?

    private static let defaultMaxConcurrentTransfers = 2
    private static let badStreamURLMessage = "Invalid stream URL: bad URL."

    private let database: DatabaseManager
    private let fileManager: FileManager
    private let downloadsDirectory: URL
    private let performer: DownloadPerformer
    private let linkRefresher: LinkRefresher?
    private let remoteTransferCleaner: RemoteTransferCleaner?
    private let sleep: SleepClosure
    private let availableDiskSpace: AvailableDiskSpaceProvider
    private let maxConcurrentTransfers: Int
    private let minimumFreeSpaceBufferBytes: Int64

    private struct DownloadJob {
        let task: Task<Void, Never>
        let cancellationController: DownloadCancellationController
    }

    private var jobs: [String: DownloadJob] = [:]
    private var isSchedulingQueuedJobs: Bool = false
    private var shouldRescheduleQueuedJobs: Bool = false
    private var startingJobIDs: Set<String> = []
    private var removalBatchDepth: Int = 0
    private var inMemoryReplayableRequestsByTaskID: [String: TransferRequest] = [:]
    private var reservedDestinationByTaskID: [String: URL] = [:]
    private var reservedDestinationPaths: Set<String> = []
    private var reservedExpectedBytesByTaskID: [String: Int64] = [:]

    init(
        database: DatabaseManager,
        fileManager: FileManager = .default,
        downloadsDirectory: URL? = nil,
        performer: DownloadPerformer? = nil,
        linkRefresher: LinkRefresher? = nil,
        remoteTransferCleaner: RemoteTransferCleaner? = nil,
        maxConcurrentTransfers: Int = DownloadManager.defaultMaxConcurrentTransfers,
        minimumFreeSpaceBufferBytes: Int64 = 128 * 1_024 * 1_024,
        availableDiskSpace: @escaping AvailableDiskSpaceProvider = DownloadManager.defaultAvailableDiskSpace,
        resumePersistedDownloadsOnInit: Bool = true,
        sleep: @escaping SleepClosure = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.database = database
        self.fileManager = fileManager
        self.linkRefresher = linkRefresher
        self.remoteTransferCleaner = remoteTransferCleaner
        self.sleep = sleep

        if let downloadsDirectory {
            self.downloadsDirectory = downloadsDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.downloadsDirectory = appSupport
                .appendingPathComponent("VPStudio", isDirectory: true)
                .appendingPathComponent("Downloads", isDirectory: true)
        }

        self.performer = performer ?? Self.makeDefaultPerformer()
        self.maxConcurrentTransfers = max(1, maxConcurrentTransfers)
        self.minimumFreeSpaceBufferBytes = max(0, minimumFreeSpaceBufferBytes)
        self.availableDiskSpace = availableDiskSpace

        if resumePersistedDownloadsOnInit {
            Task { await self.resumePersistedDownloads() }
        }
    }

    func enqueueDownload(stream: StreamInfo, mediaId: String, episodeId: String?, mediaTitle: String = "", mediaType: String = "movie", posterPath: String? = nil, seasonNumber: Int? = nil, episodeNumber: Int? = nil, episodeTitle: String? = nil) async throws -> DownloadTask {
        try ensureSufficientDiskSpace(requiredBytes: stream.sizeBytes, forTaskID: nil)
        let persistReplayableState = shouldPersistReplayableState(for: stream)

        var recoveryJSON: String?
        if let ctx = persistedRecoveryContext(for: stream),
           let data = try? JSONEncoder().encode(ctx) {
            recoveryJSON = String(data: data, encoding: .utf8)
        }

        let task = DownloadTask(
            mediaId: mediaId,
            episodeId: episodeId,
            streamURL: persistReplayableState ? stream.streamURL.absoluteString : nil,
            fileName: sanitizedFileName(stream.fileName),
            totalBytes: stream.sizeBytes,
            mediaTitle: mediaTitle,
            mediaType: mediaType,
            posterPath: posterPath,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            episodeTitle: episodeTitle,
            recoveryContextJSON: recoveryJSON,
            expectedBytes: stream.sizeBytes
        )

        cacheReplayableTransferRequestIfNeeded(
            id: task.id,
            taskHasRecoveryContext: task.recoveryContext != nil,
            request: TransferRequest(
                url: stream.streamURL,
                resumeData: nil,
                requestHeaders: stream.requestHeaders
            )
        )
        try await database.saveDownloadTask(persistenceReadyTask(task))
        reserveDestinationIfNeeded(for: task.id, fileName: task.fileName)
        notifyDownloadsChanged()
        await maybeStartQueuedJobs()
        return task
    }

    func listDownloads() async throws -> [DownloadTask] {
        try await database.fetchDownloadTasks()
    }

    func cancelDownload(id: String) async {
        let existingTask = try? await database.fetchDownloadTask(id: id)
        if let job = jobs[id] {
            await requestJobCancellation(id: id, job: job, allowGracefulResume: true)

            if let currentTask = try? await database.fetchDownloadTask(id: id),
               !currentTask.status.isTerminal {
                try? await database.updateDownloadTaskStatus(id: id, status: .cancelled, errorMessage: nil)
            }
        } else {
            releaseReservedDestination(for: id)
            try? await database.updateDownloadTaskStatus(id: id, status: .cancelled, errorMessage: nil)
        }
        if let existingTask {
            await clearReplayableTransferStateIfNeeded(for: existingTask, id: id)
            await cleanupRemoteTransferIfNeeded(for: existingTask)
        }
        notifyDownloadsChanged()
    }

    func retryDownload(id: String) async throws {
        if let job = jobs[id] {
            await requestJobCancellation(id: id, job: job, allowGracefulResume: true)
        }

        guard let existing = try await database.fetchDownloadTask(id: id) else { return }

        let persistReplayableState = shouldPersistReplayableState(for: existing)
        var replayableRequest = replayableTransferRequest(for: existing)

        if persistReplayableState,
           let refreshedURLString = existing.persistedStreamURL,
           let refreshedURL = URL(string: refreshedURLString),
           replayableRequest.url != refreshedURL {
            replayableRequest = TransferRequest(
                url: refreshedURL,
                resumeData: replayableRequest.resumeData,
                requestHeaders: replayableRequest.requestHeaders
            )
        }

        let canResumePartially = replayableRequest.resumeData != nil

        let resetTask = DownloadTask(
            id: existing.id,
            mediaId: existing.mediaId,
            episodeId: existing.episodeId,
            streamURL: persistReplayableState ? replayableRequest.url?.absoluteString : nil,
            fileName: existing.fileName,
            status: .queued,
            progress: normalizedRestartProgress(existing.progress, canResumePartially: canResumePartially),
            bytesWritten: normalizedRestartBytesWritten(existing.bytesWritten, canResumePartially: canResumePartially),
            totalBytes: existing.expectedBytes ?? existing.totalBytes,
            destinationPath: nil,
            errorMessage: nil,
            mediaTitle: existing.mediaTitle,
            mediaType: existing.mediaType,
            posterPath: existing.posterPath,
            seasonNumber: existing.seasonNumber,
            episodeNumber: existing.episodeNumber,
            episodeTitle: existing.episodeTitle,
            recoveryContextJSON: existing.recoveryContextJSON,
            expectedBytes: existing.expectedBytes ?? existing.totalBytes,
            resumeDataBase64: persistReplayableState ? replayableRequest.resumeData?.base64EncodedString() : nil,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )

        cacheReplayableTransferRequestIfNeeded(
            id: existing.id,
            taskHasRecoveryContext: existing.recoveryContext != nil,
            request: replayableRequest
        )
        try await database.saveDownloadTask(persistenceReadyTask(resetTask))
        reserveDestinationIfNeeded(for: id, fileName: resetTask.fileName)
        notifyDownloadsChanged()
        await maybeStartQueuedJobs()
    }

    func removeDownload(id: String) async throws {
        if let job = jobs[id] {
            await requestJobCancellation(id: id, job: job, allowGracefulResume: false)
        } else {
            releaseReservedDestination(for: id)
        }

        let existing = try await database.fetchDownloadTask(id: id)
        let stagedDestination: (original: URL, staged: URL)?
        if let destination = existing?.destinationURL,
           fileManager.fileExists(atPath: destination.path) {
            let stagedURL = destination
                .deletingLastPathComponent()
                .appendingPathComponent(".vpstudio-delete-\(UUID().uuidString)-\(destination.lastPathComponent)")
            try fileManager.moveItem(at: destination, to: stagedURL)
            stagedDestination = (destination, stagedURL)
        } else {
            stagedDestination = nil
        }

        do {
            try await database.deleteDownloadTask(id: id)
        } catch {
            if let stagedDestination,
               fileManager.fileExists(atPath: stagedDestination.staged.path) {
                try? fileManager.moveItem(at: stagedDestination.staged, to: stagedDestination.original)
            }
            throw error
        }

        if let stagedDestination,
           fileManager.fileExists(atPath: stagedDestination.staged.path) {
            try? fileManager.removeItem(at: stagedDestination.staged)
        }
        inMemoryReplayableRequestsByTaskID[id] = nil
        releaseReservedDestination(for: id)
        if let existing {
            await cleanupRemoteTransferIfNeeded(for: existing)
        }
        notifyDownloadsChanged()
    }

    func removeDownloads(mediaId: String) async throws {
        removalBatchDepth += 1
        defer {
            removalBatchDepth -= 1
            Task { await self.maybeStartQueuedJobs() }
        }

        let tasks = try await database.fetchDownloadTasks()
        let matching = tasks.filter { $0.mediaId == mediaId }
        for task in matching {
            try await removeDownload(id: task.id)
        }
    }

    private func startJob(for id: String) -> Bool {
        guard jobs[id] == nil else { return false }
        guard !startingJobIDs.contains(id) else { return false }

        startingJobIDs.insert(id)

        let cancellationController = DownloadCancellationController()
        let task = Task {
            await self.processDownload(id: id, cancellationController: cancellationController)
        }
        jobs[id] = DownloadJob(task: task, cancellationController: cancellationController)
        return true
    }

    private func waitForJobTeardown(id: String) async {
        while jobs[id] != nil {
            try? await sleep(.milliseconds(25))
        }
    }

    private func waitForJobTeardown(id: String, timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while jobs[id] != nil {
            if ContinuousClock.now >= deadline {
                return false
            }
            try? await sleep(.milliseconds(25))
        }
        return true
    }

    private func requestJobCancellation(id: String, job: DownloadJob, allowGracefulResume: Bool) async {
        job.cancellationController.cancel()

        let cancelledGracefully = allowGracefulResume
            ? await waitForJobTeardown(id: id, timeout: .seconds(1))
            : false

        if !cancelledGracefully {
            job.task.cancel()
            await waitForJobTeardown(id: id)
        }
    }

    private func escalateCancellationIfNeeded(id: String, job: DownloadJob) async {
        let cancelledGracefully = await waitForJobTeardown(id: id, timeout: .seconds(1))
        guard !cancelledGracefully else {
            return
        }
        job.task.cancel()
    }

    private func resumePersistedDownloads() async {
        guard let tasks = try? await database.fetchDownloadTasks() else { return }

        var didNormalizeState = false
        for task in tasks where !task.status.isTerminal {
            if await finalizeIfDestinationAlreadyExists(task) {
                didNormalizeState = true
                continue
            }

            let persistReplayableState = shouldPersistReplayableState(for: task)
            let replayableRequest = replayableTransferRequest(for: task)
            let canResumePartially = replayableRequest.resumeData != nil
            let normalized = DownloadTask(
                id: task.id,
                mediaId: task.mediaId,
                episodeId: task.episodeId,
                streamURL: persistReplayableState ? replayableRequest.url?.absoluteString : nil,
                fileName: task.fileName,
                status: .queued,
                progress: normalizedRestartProgress(task.progress, canResumePartially: canResumePartially),
                bytesWritten: normalizedRestartBytesWritten(task.bytesWritten, canResumePartially: canResumePartially),
                totalBytes: task.expectedBytes ?? task.totalBytes,
                destinationPath: nil,
                errorMessage: nil,
                mediaTitle: task.mediaTitle,
                mediaType: task.mediaType,
                posterPath: task.posterPath,
                seasonNumber: task.seasonNumber,
                episodeNumber: task.episodeNumber,
                episodeTitle: task.episodeTitle,
                recoveryContextJSON: task.recoveryContextJSON,
                expectedBytes: task.expectedBytes ?? task.totalBytes,
                resumeDataBase64: persistReplayableState ? replayableRequest.resumeData?.base64EncodedString() : nil,
                createdAt: task.createdAt,
                updatedAt: Date()
            )

            cacheReplayableTransferRequestIfNeeded(
                id: normalized.id,
                taskHasRecoveryContext: task.recoveryContext != nil,
                request: replayableRequest
            )
            try? await database.saveDownloadTask(persistenceReadyTask(normalized))
            reserveDestinationIfNeeded(for: normalized.id, fileName: normalized.fileName)
            didNormalizeState = true
        }

        if didNormalizeState {
            notifyDownloadsChanged()
        }

        await maybeStartQueuedJobs()
    }

    private func processDownload(id: String, cancellationController: DownloadCancellationController) async {
        defer {
            jobs[id] = nil
            startingJobIDs.remove(id)
            releaseReservedDestination(for: id)
            reservedExpectedBytesByTaskID[id] = nil
            Task { await self.maybeStartQueuedJobs() }
        }

        guard let task = try? await database.fetchDownloadTask(id: id) else {
            try? await database.updateDownloadTaskStatus(
                id: id,
                status: .failed,
                errorMessage: "Invalid stream URL"
            )
            notifyDownloadsChanged()
            return
        }

        guard task.status == .downloading else {
            notifyDownloadsChanged()
            return
        }

        let request: TransferRequest
        do {
            request = try await startingRequest(for: task, id: id)
        } catch {
            try? await database.updateDownloadTaskStatus(
                id: id,
                status: .failed,
                errorMessage: Self.errorMessage(forStartingRequestError: error)
            )
            notifyDownloadsChanged()
            return
        }

        do {
            try ensureSufficientDiskSpace(requiredBytes: requiredBytesToReserve(for: task), forTaskID: id)
        } catch {
            try? await database.updateDownloadTaskStatus(
                id: id,
                status: .failed,
                errorMessage: error.localizedDescription
            )
            notifyDownloadsChanged()
            return
        }

        if let reservedBytes = requiredBytesToReserve(for: task), reservedBytes > 0 {
            reservedExpectedBytesByTaskID[id] = reservedBytes
        }

        reserveDestinationIfNeeded(for: id, fileName: task.fileName)
        try? await database.updateDownloadTaskStatus(id: id, status: .downloading, errorMessage: nil)
        notifyDownloadsChanged()

        var currentRequest = request
        var linkRefreshAttempted = false

        do {
            guard Self.isViableDownloadRequest(currentRequest) else {
                try? await database.updateDownloadTaskStatus(
                    id: id,
                    status: .failed,
                    errorMessage: Self.badStreamURLMessage
                )
                notifyDownloadsChanged()
                return
            }

            let tempURL = try await attemptDownload(request: currentRequest, id: id, cancellationController: cancellationController)
            defer { try? fileManager.removeItem(at: tempURL) }

            try Task.checkCancellation()
            try await completeDownload(tempURL: tempURL, task: task, id: id)
        } catch let error as DownloadTransferError {
            switch error {
            case .resumeDataProduced(let resumeData):
                await persistCancelledTransfer(id: id, fallbackTask: task, resumeData: resumeData)
                return
            case .badHTTPStatus, .insufficientDiskSpace:
                break
            }

            let shouldInvalidateReplayState = Self.isLinkExpiredError(error)
                && shouldInvalidateReplayableStateAfterExpiredLink(for: task)
            if shouldInvalidateReplayState {
                await invalidateReplayableTransferState(id: id)
            }

            if !linkRefreshAttempted,
               Self.isLinkExpiredError(error),
               let refresher = linkRefresher,
               let context = task.recoveryContext {
                linkRefreshAttempted = true

                do {
                    try? await database.updateDownloadTaskStatus(id: id, status: .resolving, errorMessage: nil)
                    notifyDownloadsChanged()

                    let freshURL = try await refresher(context)
                    currentRequest = TransferRequest(
                        url: freshURL,
                        resumeData: nil,
                        requestHeaders: currentRequest.requestHeaders
                    )

                    await persistReplayableTransferStateForRetry(request: currentRequest, task: task, id: id)

                    try? await database.updateDownloadTaskStatus(id: id, status: .downloading, errorMessage: nil)
                    notifyDownloadsChanged()

                    let tempURL = try await attemptDownload(request: currentRequest, id: id, cancellationController: cancellationController)
                    defer { try? fileManager.removeItem(at: tempURL) }

                    try Task.checkCancellation()
                    try await completeDownload(tempURL: tempURL, task: task, id: id)
                    return
                } catch is CancellationError {
                    await persistCancelledTransfer(
                        id: id,
                        fallbackTask: task,
                        resumeData: resumeDataToPersistOnCancellation(
                            request: currentRequest,
                            fallbackTask: task
                        )
                    )
                    return
                } catch let refreshError as DownloadTransferError {
                    if case .resumeDataProduced(let resumeData) = refreshError {
                        await persistCancelledTransfer(id: id, fallbackTask: task, resumeData: resumeData)
                        return
                    }
                } catch {
                    // Link refresh also failed — fall through to failure.
                }
            }

            try? await database.updateDownloadTaskStatus(
                id: id,
                status: .failed,
                errorMessage: error.localizedDescription
            )
            notifyDownloadsChanged()
        } catch is CancellationError {
            await persistCancelledTransfer(
                id: id,
                fallbackTask: task,
                resumeData: resumeDataToPersistOnCancellation(
                    request: currentRequest,
                    fallbackTask: task
                )
            )
        } catch {
            let shouldInvalidateReplayState = Self.isLinkExpiredError(error)
                && shouldInvalidateReplayableStateAfterExpiredLink(for: task)
            if shouldInvalidateReplayState {
                await invalidateReplayableTransferState(id: id)
            }

            if !linkRefreshAttempted,
               Self.isLinkExpiredError(error),
               let refresher = linkRefresher,
               let context = task.recoveryContext {
                linkRefreshAttempted = true

                do {
                    try? await database.updateDownloadTaskStatus(id: id, status: .resolving, errorMessage: nil)
                    notifyDownloadsChanged()

                    let freshURL = try await refresher(context)
                    currentRequest = TransferRequest(
                        url: freshURL,
                        resumeData: nil,
                        requestHeaders: currentRequest.requestHeaders
                    )

                    await persistReplayableTransferStateForRetry(request: currentRequest, task: task, id: id)

                    // Retry with fresh URL
                    try? await database.updateDownloadTaskStatus(id: id, status: .downloading, errorMessage: nil)
                    notifyDownloadsChanged()

                    let tempURL = try await attemptDownload(request: currentRequest, id: id, cancellationController: cancellationController)
                    defer { try? fileManager.removeItem(at: tempURL) }

                    try Task.checkCancellation()
                    try await completeDownload(tempURL: tempURL, task: task, id: id)
                    return
                } catch is CancellationError {
                    await persistCancelledTransfer(
                        id: id,
                        fallbackTask: task,
                        resumeData: resumeDataToPersistOnCancellation(
                            request: currentRequest,
                            fallbackTask: task
                        )
                    )
                    return
                } catch {
                    // Link refresh also failed — fall through to failure
                }
            }

            try? await database.updateDownloadTaskStatus(
                id: id,
                status: .failed,
                errorMessage: error.localizedDescription
            )
            notifyDownloadsChanged()
        }
    }

    private func startingRequest(for task: DownloadTask, id: String) async throws -> TransferRequest {
        if shouldPersistReplayableState(for: task) {
            if let inMemoryRequest = inMemoryReplayableRequestsByTaskID[id] {
                let persistedRequestURL = task.persistedStreamURL.flatMap(URL.init(string:))
                let merged = TransferRequest(
                    url: inMemoryRequest.url ?? persistedRequestURL,
                    resumeData: task.resumeData ?? inMemoryRequest.resumeData,
                    requestHeaders: inMemoryRequest.requestHeaders
                )

                if merged.hasTransportState {
                    return merged
                }
            }

            return TransferRequest(
                url: task.persistedStreamURL.flatMap(URL.init(string:)),
                resumeData: task.resumeData
            )
        }

        if let inMemoryRequest = inMemoryReplayableRequestsByTaskID[id] {
            let merged = TransferRequest(
                url: inMemoryRequest.url ?? task.persistedStreamURL.flatMap(URL.init(string:)),
                resumeData: inMemoryRequest.resumeData ?? task.resumeData,
                requestHeaders: inMemoryRequest.requestHeaders
            )

            if Self.isViableDownloadRequest(merged) {
                return merged
            }
        }

        if !shouldPersistReplayableState(for: task),
           let refresher = linkRefresher,
           let context = task.recoveryContext {
            let requestHeaders = inMemoryReplayableRequestsByTaskID[id]?.requestHeaders
            await clearReplayableTransferStateIfNeeded(for: task, id: id)
            try? await database.updateDownloadTaskStatus(id: id, status: .resolving, errorMessage: nil)
            notifyDownloadsChanged()
            return TransferRequest(url: try await refresher(context), resumeData: nil, requestHeaders: requestHeaders)
        }

        if let resumeData = task.resumeData {
            return TransferRequest(
                url: task.persistedStreamURL.flatMap(URL.init(string:)),
                resumeData: resumeData
            )
        }

        if let persistedURL = task.persistedStreamURL,
           let streamURL = URL(string: persistedURL) {
            return TransferRequest(url: streamURL, resumeData: nil)
        }

        guard let refresher = linkRefresher,
              let context = task.recoveryContext else {
            throw URLError(.badURL)
        }

        try? await database.updateDownloadTaskStatus(id: id, status: .resolving, errorMessage: nil)
        notifyDownloadsChanged()
        return TransferRequest(
            url: try await refresher(context),
            resumeData: nil,
            requestHeaders: inMemoryReplayableRequestsByTaskID[id]?.requestHeaders
        )
    }

    private func attemptDownload(request: TransferRequest, id: String, cancellationController: DownloadCancellationController) async throws -> URL {
        let lastUpdateTime = ManagedAtomic<UInt64>(0)
        let updateInFlight = ManagedAtomic<Bool>(false)

        let downloadResult = try await withTaskCancellationHandler(
            operation: {
                try await performer(request, { bytesWritten, totalBytesWritten, totalBytesExpected in
                    guard !cancellationController.isCancelled else { return }

                    let now = DispatchTime.now().uptimeNanoseconds
                    let last = lastUpdateTime.load()
                    let elapsed = now - last
                    guard elapsed > 1_000_000_000 || totalBytesWritten == totalBytesExpected else { return }

                    let progress = totalBytesExpected > 0
                        ? Double(totalBytesWritten) / Double(totalBytesExpected)
                        : 0.0
                    guard !updateInFlight.load() else { return }
                    // Advance the throttle clock only once a write is actually committed. Storing it
                    // above the in-flight guard meant a skipped tick still reset the clock, deferring
                    // the next progress write by an extra ~1s and making the progress bar choppy.
                    lastUpdateTime.store(now)
                    updateInFlight.store(true)
                    let db = self.database
                    Task {
                        defer { updateInFlight.store(false) }
                        guard !cancellationController.isCancelled else { return }
                        try? await db.updateDownloadTaskProgress(
                            id: id,
                            progress: min(progress, 0.99),
                            bytesWritten: totalBytesWritten,
                            totalBytes: totalBytesExpected > 0 ? totalBytesExpected : nil,
                            destinationPath: nil
                        )
                        self.notifyDownloadsChanged()
                    }
                }, cancellationController)
            },
            onCancel: {
                cancellationController.cancel()
            }
        )
        let (tempURL, response) = downloadResult
        var shouldCleanupTempURL: URL? = tempURL
        defer {
            if let tempURL = shouldCleanupTempURL {
                try? fileManager.removeItem(at: tempURL)
            }
        }
        try Self.validateSuccessfulDownloadResponse(response)
        shouldCleanupTempURL = nil
        return tempURL
    }

    private func completeDownload(tempURL: URL, task: DownloadTask, id: String) async throws {
        defer { try? fileManager.removeItem(at: tempURL) }

        try ensureDownloadsDirectory()

        let destination = reservedDestinationURL(for: id, fileName: task.fileName)
        let finalBytes = max(0, (try? fileSize(at: tempURL)) ?? task.bytesWritten)
        let preCompletionBytes = finalBytes > 0 ? finalBytes : max(0, task.bytesWritten)

        try await database.updateDownloadTaskProgress(
            id: id,
            progress: 0.99,
            bytesWritten: preCompletionBytes,
            totalBytes: preCompletionBytes > 0 ? preCompletionBytes : task.totalBytes,
            destinationPath: destination.path
        )

        do {
            try fileManager.moveItem(at: tempURL, to: destination)
        } catch {
            if var rollback = try? await database.fetchDownloadTask(id: id) {
                rollback.destinationPath = nil
                rollback.progress = 0
                rollback.bytesWritten = 0
                rollback.updatedAt = Date()
                try? await database.saveDownloadTask(rollback)
            }
            throw error
        }

        let completedBytes = max(0, (try? fileSize(at: destination)) ?? preCompletionBytes)

        try await database.updateDownloadTaskProgress(
            id: id,
            progress: 1.0,
            bytesWritten: completedBytes,
            totalBytes: completedBytes > 0 ? completedBytes : nil,
            destinationPath: destination.path
        )
        try await database.updateDownloadTaskStatus(id: id, status: .completed, errorMessage: nil)
        try? await database.clearDownloadTaskReplayableTransportState(id: id)
        inMemoryReplayableRequestsByTaskID[id] = nil
        await cleanupRemoteTransferIfNeeded(for: task)
        notifyDownloadsChanged()
    }

    private func persistCancelledTransfer(id: String, fallbackTask: DownloadTask, resumeData: Data?) async {
        var updatedTask = (try? await database.fetchDownloadTask(id: id)) ?? fallbackTask
        updatedTask.status = .cancelled
        updatedTask.errorMessage = nil
        let shouldPersistReplayableState = shouldPersistReplayableState(for: updatedTask)
        let persistedResumeData = shouldPersistReplayableState ? resumeData : nil
        let shouldCacheReplayState = shouldPersistReplayableState || linkRefresher == nil
        let cachedResumeData = shouldCacheReplayState ? resumeData : nil
        updatedTask.resumeData = persistedResumeData
        if shouldPersistReplayableState {
            let fallbackRequest = inMemoryReplayableRequestsByTaskID[id]
            let fallbackURL = fallbackRequest?.url ?? fallbackTask.persistedStreamURL.flatMap(URL.init(string:))
            cacheReplayableTransferRequestIfNeeded(
                id: id,
                taskHasRecoveryContext: false,
                request: TransferRequest(
                    url: fallbackURL,
                    resumeData: cachedResumeData,
                    requestHeaders: fallbackRequest?.requestHeaders
                )
            )
        } else {
            let fallbackRequest = inMemoryReplayableRequestsByTaskID[id]
            let fallbackURL = shouldCacheReplayState
                ? (fallbackRequest?.url ?? fallbackTask.persistedStreamURL.flatMap(URL.init(string:)))
                : nil
            cacheReplayableTransferRequestIfNeeded(
                id: id,
                taskHasRecoveryContext: true,
                request: TransferRequest(
                    url: fallbackURL,
                    resumeData: cachedResumeData,
                    requestHeaders: fallbackRequest?.requestHeaders
                )
            )
        }
        updatedTask.updatedAt = Date()
        try? await database.saveDownloadTask(persistenceReadyTask(updatedTask))
        notifyDownloadsChanged()
    }

    private func cleanupRemoteTransferIfNeeded(for task: DownloadTask) async {
        guard let remoteTransferCleaner,
              let context = task.recoveryContext else {
            return
        }
        await remoteTransferCleaner(context)
    }

    private func normalizedRestartProgress(_ progress: Double, canResumePartially: Bool) -> Double {
        guard canResumePartially else {
            return 0
        }
        return min(max(progress, 0), 0.99)
    }

    private func normalizedRestartBytesWritten(_ bytesWritten: Int64, canResumePartially: Bool) -> Int64 {
        guard canResumePartially else {
            return 0
        }
        return max(0, bytesWritten)
    }

    private func requiredBytesToReserve(for task: DownloadTask) -> Int64? {
        guard let expected = task.expectedBytes ?? task.totalBytes,
              expected > 0 else {
            return nil
        }

        let alreadyDownloaded = max(0, task.bytesWritten)
        if task.resumeData != nil {
            return max(0, expected - alreadyDownloaded)
        }

        return expected
    }

    private func resumeDataToPersistOnCancellation(
        request: TransferRequest,
        fallbackTask: DownloadTask
    ) -> Data? {
        guard shouldPersistReplayableState(for: fallbackTask) else {
            return nil
        }
        if let resumeData = request.resumeData {
            return resumeData
        }
        guard request.url?.absoluteString == fallbackTask.persistedStreamURL else {
            return nil
        }
        return fallbackTask.resumeData
    }

    /// Detect network errors that indicate an expired or dead download link.
    /// Works for any debrid service — checks for SSL timeouts, connection refused, HTTP 403/410/451.
    private static func isLinkExpiredError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // SSL/TLS handshake timeout (the exact error from the logs: domain 4, code -2205)
        if nsError.domain == "kCFErrorDomainCFNetwork" || nsError.domain == NSURLErrorDomain {
            // CFNetwork code 303 = secure connection failed
            if nsError.code == 303 { return true }
            // NSURLError codes for connection issues
            switch nsError.code {
            case NSURLErrorSecureConnectionFailed,     // -1200
                 NSURLErrorTimedOut,                    // -1001
                 NSURLErrorCannotConnectToHost,         // -1004
                 NSURLErrorNetworkConnectionLost,       // -1005
                 NSURLErrorServerCertificateUntrusted,  // -1202
                 NSURLErrorCannotFindHost:              // -1003
                return true
            default:
                break
            }
        }

        // Check underlying SSL error (kCFStreamErrorDomainSSL = 4, errSSLNetworkTimeout = -2205)
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return Self.isLinkExpiredError(underlyingError)
        }

        if case let DownloadTransferError.badHTTPStatus(statusCode) = error {
            return statusCode == 403 || statusCode == 410 || statusCode == 451
        }

        return false
    }

    private static func validateSuccessfulDownloadResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw DownloadTransferError.badHTTPStatus(http.statusCode)
        }
    }

    private static func isViableDownloadRequest(_ request: TransferRequest) -> Bool {
        guard request.url != nil || request.resumeData != nil else {
            return false
        }

        if request.resumeData != nil {
            return true
        }

        guard let url = request.url else {
            return true
        }

        if url.isFileURL {
            return true
        }

        guard let host = url.host, !host.isEmpty else {
            return false
        }
        return true
    }

    private static func errorMessage(forStartingRequestError error: Error) -> String {
        if let urlError = error as? URLError, urlError.code == .badURL {
            return badStreamURLMessage
        }

        return error.localizedDescription
    }

    private func persistedRecoveryContext(for stream: StreamInfo) -> StreamRecoveryContext? {
        stream.recoveryContext?.enrichedForDownloadPersistence(
            fileName: stream.fileName,
            sizeBytes: stream.sizeBytes,
            debridService: stream.debridService
        )
    }

    private func shouldPersistReplayableState(for stream: StreamInfo) -> Bool {
        stream.recoveryContext == nil
    }

    private func shouldPersistReplayableState(for task: DownloadTask) -> Bool {
        task.recoveryContext == nil
    }

    private func shouldInvalidateReplayableStateAfterExpiredLink(for task: DownloadTask) -> Bool {
        task.recoveryContext != nil && linkRefresher != nil
    }

    private func clearReplayableTransferStateIfNeeded(for task: DownloadTask, id: String) async {
        guard !shouldPersistReplayableState(for: task) else { return }
        await clearPersistedReplayableTransferState(id: id)
    }

    private func invalidateReplayableTransferState(id: String) async {
        inMemoryReplayableRequestsByTaskID[id] = nil
        await clearPersistedReplayableTransferState(id: id)
    }

    private func clearPersistedReplayableTransferState(id: String) async {
        try? await database.clearDownloadTaskReplayableTransportState(id: id)
    }

    private func finalizeIfDestinationAlreadyExists(_ task: DownloadTask) async -> Bool {
        guard let destination = task.destinationURL,
              fileManager.fileExists(atPath: destination.path) else {
            return false
        }

        let finalBytes = max(0, (try? fileSize(at: destination)) ?? task.bytesWritten)
        if let expectedBytes = task.expectedBytes ?? task.totalBytes, expectedBytes > 0, finalBytes != expectedBytes {
            return false
        }

        try? await database.updateDownloadTaskProgress(
            id: task.id,
            progress: 1.0,
            bytesWritten: finalBytes,
            totalBytes: finalBytes > 0 ? finalBytes : task.totalBytes,
            destinationPath: destination.path
        )
        try? await database.updateDownloadTaskStatus(id: task.id, status: .completed, errorMessage: nil)
        try? await database.clearDownloadTaskReplayableTransportState(id: task.id)
        inMemoryReplayableRequestsByTaskID[task.id] = nil
        return true
    }

    private func persistReplayableTransferStateForRetry(request: TransferRequest, task: DownloadTask, id: String) async {
        cacheReplayableTransferRequestIfNeeded(
            id: id,
            taskHasRecoveryContext: task.recoveryContext != nil,
            request: request
        )
        if shouldPersistReplayableState(for: task) {
            try? await database.updateDownloadTaskStreamURL(id: id, streamURL: request.url?.absoluteString)
            try? await database.clearDownloadTaskResumeData(id: id)
            return
        }

        await invalidateReplayableTransferState(id: id)
    }

    private func persistenceReadyTask(_ task: DownloadTask) -> DownloadTask {
        if shouldPersistReplayableState(for: task) {
            return task
        }
        return task.redactedForRecoveryBackedPersistence
    }

    private func replayableTransferRequest(for task: DownloadTask) -> TransferRequest {
        if task.recoveryContext != nil,
           linkRefresher != nil,
           task.resumeData != nil {
            return TransferRequest(url: nil, resumeData: nil)
        }

        let persistedURL = task.persistedStreamURL.flatMap(URL.init(string:))
        let persistedResumeData = task.resumeData

        if let inMemoryRequest = inMemoryReplayableRequestsByTaskID[task.id], let _ = task.recoveryContext, linkRefresher != nil {
            if let persistedURL = task.persistedStreamURL,
               inMemoryRequest.url?.absoluteString != persistedURL {
                return TransferRequest(
                    url: URL(string: persistedURL),
                    resumeData: inMemoryRequest.resumeData ?? persistedResumeData,
                    requestHeaders: inMemoryRequest.requestHeaders
                )
            }

            if task.status == .queued || task.status == .downloading || task.status == .resolving {
                return TransferRequest(
                    url: inMemoryRequest.url ?? persistedURL,
                    resumeData: inMemoryRequest.resumeData ?? persistedResumeData,
                    requestHeaders: inMemoryRequest.requestHeaders
                )
            }
        }

        if let inMemoryRequest = inMemoryReplayableRequestsByTaskID[task.id] {
            return TransferRequest(
                url: inMemoryRequest.url ?? persistedURL,
                resumeData: inMemoryRequest.resumeData ?? persistedResumeData,
                requestHeaders: inMemoryRequest.requestHeaders
            )
        }
        return TransferRequest(
            url: persistedURL,
            resumeData: persistedResumeData
        )
    }

    private func cacheReplayableTransferRequestIfNeeded(id: String, taskHasRecoveryContext: Bool, request: TransferRequest) {
        if taskHasRecoveryContext && linkRefresher != nil {
            inMemoryReplayableRequestsByTaskID[id] = request.requestHeaders.map {
                TransferRequest(url: nil, resumeData: nil, requestHeaders: $0)
            }
            return
        }

        guard request.hasTransportState else {
            inMemoryReplayableRequestsByTaskID[id] = nil
            return
        }
        inMemoryReplayableRequestsByTaskID[id] = request
    }

    // MARK: - Default Performer (delegate-based URLSession)

    private static func makeDefaultPerformer() -> DownloadPerformer {
        { request, progressHandler, cancellationController in
            let delegate = DownloadProgressDelegate(onProgress: progressHandler)
            let config = URLSessionConfiguration.default
            config.urlCache = nil                       // downloads don't need URL caching
            config.httpMaximumConnectionsPerHost = 4    // limit per-host concurrency
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

            guard request.resumeData != nil || request.url != nil else {
                throw URLError(.badURL)
            }

            return try await withCheckedThrowingContinuation { continuation in
                let task: URLSessionDownloadTask
                if let resumeData = request.resumeData {
                    task = session.downloadTask(withResumeData: resumeData)
                } else {
                    guard let url = request.url else {
                        continuation.resume(throwing: URLError(.badURL))
                        return
                    }

                    var urlRequest = URLRequest(url: url)
                    for (name, value) in request.requestHeaders ?? [:] {
                        urlRequest.setValue(value, forHTTPHeaderField: name)
                    }
                    task = session.downloadTask(with: urlRequest)
                }
                delegate.setContinuation(continuation)
                cancellationController.register {
                    task.cancel(byProducingResumeData: { resumeData in
                        session.invalidateAndCancel()
                        if let resumeData, !resumeData.isEmpty {
                            delegate.resumeIfNeeded(throwing: DownloadTransferError.resumeDataProduced(resumeData))
                        } else {
                            delegate.resumeIfNeeded(throwing: CancellationError())
                        }
                    })
                }
                task.resume()
            }
        }
    }

    private static func defaultAvailableDiskSpace(at url: URL) throws -> Int64? {
        let targetDirectory = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
        let existingDirectory = targetDirectory.path.isEmpty ? FileManager.default.temporaryDirectory : targetDirectory

        if let resourceValues = try? existingDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = resourceValues.volumeAvailableCapacityForImportantUsage,
           capacity > 0 {
            return capacity
        }

        if let resourceValues = try? existingDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let capacity = resourceValues.volumeAvailableCapacity {
            return Int64(capacity)
        }

        let fileSystemAttributes = try FileManager.default.attributesOfFileSystem(forPath: existingDirectory.path)
        if let freeSize = fileSystemAttributes[.systemFreeSize] as? NSNumber {
            return freeSize.int64Value
        }
        return nil
    }

    // MARK: - Directory Helpers

    private func ensureDownloadsDirectory() throws {
        try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    }

    private func reserveDestinationIfNeeded(for id: String, fileName: String) {
        guard reservedDestinationByTaskID[id] == nil else { return }

        let destination = uniqueDestinationURL(for: fileName)
        reservedDestinationByTaskID[id] = destination
        reservedDestinationPaths.insert(destination.path)
    }

    private func reservedDestinationURL(for id: String, fileName: String) -> URL {
        if let destination = reservedDestinationByTaskID[id] {
            return destination
        }

        let destination = uniqueDestinationURL(for: fileName)
        reservedDestinationByTaskID[id] = destination
        reservedDestinationPaths.insert(destination.path)
        return destination
    }

    private func releaseReservedDestination(for id: String) {
        guard let destination = reservedDestinationByTaskID.removeValue(forKey: id) else { return }
        reservedDestinationPaths.remove(destination.path)
    }

    private func isDestinationAvailable(_ candidate: URL) -> Bool {
        !reservedDestinationPaths.contains(candidate.path) && !fileManager.fileExists(atPath: candidate.path)
    }

    private func uniqueDestinationURL(for fileName: String) -> URL {
        let candidate = downloadsDirectory.appendingPathComponent(fileName)
        if isDestinationAvailable(candidate) {
            return candidate
        }

        let ext = candidate.pathExtension
        let base = candidate.deletingPathExtension().lastPathComponent
        var index = 1
        while true {
            let suffix = " (\(index))"
            let name = ext.isEmpty ? "\(base)\(suffix)" : "\(base)\(suffix).\(ext)"
            let next = downloadsDirectory.appendingPathComponent(name)
            if isDestinationAvailable(next) {
                return next
            }
            index += 1
        }
    }

    private func sanitizedFileName(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(
            of: "[^a-zA-Z0-9._ -]",
            with: "_",
            options: .regularExpression
        )
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "." || trimmed == ".." {
            return "download-\(UUID().uuidString).mp4"
        }
        return trimmed
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }

    private func ensureSufficientDiskSpace(requiredBytes: Int64?, forTaskID id: String?) throws {
        guard let requiredBytes, requiredBytes > 0 else { return }

        try ensureDownloadsDirectory()
        guard let availableBytes = try availableDiskSpace(downloadsDirectory) else { return }

        let reservedBytes = reservedExpectedBytesByTaskID.reduce(into: Int64(0)) { total, entry in
            guard entry.key != id else { return }
            total += entry.value
        }
        let effectiveAvailableBytes = max(0, availableBytes - reservedBytes)
        let totalRequiredBytes = requiredBytes + minimumFreeSpaceBufferBytes
        guard effectiveAvailableBytes >= totalRequiredBytes else {
            throw DownloadTransferError.insufficientDiskSpace(
                required: totalRequiredBytes,
                available: effectiveAvailableBytes
            )
        }
    }

    private func maybeStartQueuedJobs() async {
        guard removalBatchDepth == 0 else {
            shouldRescheduleQueuedJobs = true
            return
        }

        guard !isSchedulingQueuedJobs else {
            shouldRescheduleQueuedJobs = true
            return
        }

        guard jobs.count < maxConcurrentTransfers else {
            return
        }

        isSchedulingQueuedJobs = true
        defer {
            isSchedulingQueuedJobs = false

            if shouldRescheduleQueuedJobs {
                shouldRescheduleQueuedJobs = false
                Task { await self.maybeStartQueuedJobs() }
            }
        }

        guard let tasks = try? await database.fetchDownloadTasks() else {
            return
        }

        let activeIDs = Set(jobs.keys)
        let queued = tasks
            .filter { $0.status == .queued && !activeIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id < rhs.id
                }
                return lhs.createdAt < rhs.createdAt
            }

        let availableSlots = maxConcurrentTransfers - jobs.count
        guard availableSlots > 0 else { return }

        for task in queued.prefix(availableSlots) {
            guard let currentTask = try? await database.fetchDownloadTask(id: task.id),
                  currentTask.status == .queued else {
                continue
            }

            let wasClaimed = (try? await database.claimDownloadTaskForDownloadStart(id: task.id)) ?? false
            guard wasClaimed else {
                continue
            }

            guard startJob(for: task.id) else { continue }
        }
    }

    nonisolated private func notifyDownloadsChanged() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .downloadsDidChange, object: nil)
        }
    }
}

// MARK: - Download Progress Delegate

/// Bridges `URLSessionDownloadDelegate` callbacks into the async performer closure.
private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let onProgress: @Sendable (Int64, Int64, Int64) -> Void

    private let lock = NSLock()
    private var continuation: CheckedContinuation<(URL, URLResponse), any Error>?

    init(onProgress: @escaping @Sendable (Int64, Int64, Int64) -> Void) {
        self.onProgress = onProgress
    }

    func setContinuation(_ continuation: CheckedContinuation<(URL, URLResponse), any Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func resumeIfNeeded(returning value: (URL, URLResponse)) {
        let continuation = takeContinuation()
        continuation?.resume(returning: value)
    }

    func resumeIfNeeded(throwing error: any Error) {
        let continuation = takeContinuation()
        continuation?.resume(throwing: error)
    }

    private func takeContinuation() -> CheckedContinuation<(URL, URLResponse), any Error>? {
        lock.lock()
        defer { lock.unlock() }
        let continuation = continuation
        self.continuation = nil
        return continuation
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-" + location.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: location, to: tmp)
            resumeIfNeeded(returning: (tmp, downloadTask.response ?? URLResponse()))
        } catch {
            resumeIfNeeded(throwing: error)
        }
        session.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error {
            resumeIfNeeded(throwing: error)
        }
        session.finishTasksAndInvalidate()
    }
}

// MARK: - Atomic helper (lock-based access)

private final class ManagedAtomic<Value>: @unchecked Sendable {
    private var _value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        _value = value
    }

    func load(ordering: Void = ()) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func store(_ value: Value, ordering: Void = ()) {
        lock.lock()
        defer { lock.unlock() }
        _value = value
    }
}
