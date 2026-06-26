import Foundation
import Testing
@testable import VPStudio

private enum DownloadManagerTestError: Error {
    case timeout
}

private enum DiskProbeError: Error {
    case unavailable
}

private func waitForFile(at url: URL, timeoutSeconds: TimeInterval = 10) async throws {
    let deadline = Date().addingTimeInterval(timeoutSeconds)

    while Date() < deadline {
        if FileManager.default.fileExists(atPath: url.path) {
            return
        }
        try await Task.sleep(for: .milliseconds(25))
    }

    throw DownloadManagerTestError.timeout
}

private func replaceDirectoryWithBlockingFile(at url: URL) async throws {
    let fileManager = FileManager.default
    let fileURL = URL(fileURLWithPath: url.path)

    for _ in 0..<50 {
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }

        if fileManager.createFile(atPath: fileURL.path, contents: Data([0x00])) {
            return
        }

        try await Task.sleep(for: .milliseconds(20))
    }

    try Data([0x00]).write(to: fileURL)
}

private actor AttemptCounter {
    private var count = 0

    func next() -> Int {
        count += 1
        return count
    }

    func snapshot() -> Int {
        count
    }
}

private actor RetryCancellationRecorder {
    private var firstAttemptCancelledAt: Date?
    private var secondAttemptStartedAt: Date?

    func markFirstAttemptCancelled() {
        firstAttemptCancelledAt = Date()
    }

    func markSecondAttemptStarted() {
        secondAttemptStartedAt = Date()
    }

    func snapshot() -> (Date?, Date?) {
        (firstAttemptCancelledAt, secondAttemptStartedAt)
    }
}

private actor BlockingDownloadGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isResumed = false

    func wait() async {
        if isResumed {
            isResumed = false
            return
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        if let continuation {
            continuation.resume()
            self.continuation = nil
        } else {
            isResumed = true
        }
    }
}

private actor MultiDownloadGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var bufferedReleases = 0

    func wait() async {
        if bufferedReleases > 0 {
            bufferedReleases -= 1
            return
        }

        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeOne() {
        if !continuations.isEmpty {
            continuations.removeFirst().resume()
        } else {
            bufferedReleases += 1
        }
    }

    func resumeAll() {
        let pending = continuations
        continuations.removeAll()
        for continuation in pending {
            continuation.resume()
        }
    }
}

private actor ResumeDataRecorder {
    private var sawResumeData = false

    func record(_ resumeData: Data?) {
        if resumeData != nil {
            sawResumeData = true
        }
    }

    func snapshot() -> Bool {
        sawResumeData
    }
}

private actor TransferRequestRecorder {
    struct Snapshot: Equatable {
        let usedResumeData: Bool
        let url: String?
        let requestHeaders: [String: String]?

        init(usedResumeData: Bool, url: String?, requestHeaders: [String: String]? = nil) {
            self.usedResumeData = usedResumeData
            self.url = url
            self.requestHeaders = requestHeaders
        }
    }

    private var snapshots: [Snapshot] = []

    func record(request: DownloadManager.TransferRequest) {
        snapshots.append(
            Snapshot(
                usedResumeData: request.resumeData != nil,
                url: request.url?.absoluteString,
                requestHeaders: request.requestHeaders
            )
        )
    }

    func snapshot() -> [Snapshot] {
        snapshots
    }
}

private actor RemoteCleanupRecorder {
    private var cleanedContexts: [StreamRecoveryContext] = []

    func record(_ context: StreamRecoveryContext) {
        cleanedContexts.append(context)
    }

    func snapshot() -> [StreamRecoveryContext] {
        cleanedContexts
    }
}

private final class SyncCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    func snapshot() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

@Suite(.serialized)
struct DownloadManagerTests {
    @Test func cancellationControllerInvokesCallbacksOnceAndLateCallbacksImmediately() {
        final class CallbackRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var labels: [String] = []

            func append(_ label: String) {
                lock.lock()
                labels.append(label)
                lock.unlock()
            }

            func snapshot() -> [String] {
                lock.lock()
                defer { lock.unlock() }
                return labels
            }
        }

        let controller = DownloadCancellationController()
        let recorder = CallbackRecorder()

        controller.register { recorder.append("first") }
        controller.register { recorder.append("second") }

        #expect(controller.isCancelled == false)
        controller.cancel()
        controller.cancel()
        controller.register { recorder.append("late") }

        #expect(controller.isCancelled)
        #expect(recorder.snapshot() == ["first", "second", "late"])
    }

    @Test func downloadTransferErrorDescriptionsRemainUserFacing() {
        let badStatus = DownloadTransferError.badHTTPStatus(429)
        let insufficientSpace = DownloadTransferError.insufficientDiskSpace(required: 10_000, available: -1)
        let paused = DownloadTransferError.resumeDataProduced(Data("resume".utf8))

        #expect(badStatus.errorDescription == "Download failed with HTTP 429.")
        #expect(insufficientSpace.errorDescription?.contains("Not enough free space to start this download.") == true)
        #expect(insufficientSpace.errorDescription?.contains("only") == true)
        #expect(insufficientSpace.errorDescription?.contains("is available.") == true)
        #expect(paused.errorDescription == "Download paused.")
    }

    @Test func queuedDownloadCompletesAndPersists() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-complete.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 2048)
        )

        let task = try await manager.enqueueDownload(stream: makeStream(name: "movie.mkv"), mediaId: "tt100", episodeId: nil)

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        #expect(completed.progress == 1.0)
        #expect(completed.destinationURL != nil)
        #expect(completed.totalBytes == 2048)
        #expect(FileManager.default.fileExists(atPath: completed.destinationURL!.path))

        let listed = try await manager.listDownloads()
        #expect(listed.contains(where: { $0.id == task.id && $0.status == .completed }))
    }

    @Test func retryDownloadForPersistedTaskWithoutTransportStateSkipsPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-no-transport.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x10, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/no-transport.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            resumePersistedDownloadsOnInit: false
        )

        let invalid = DownloadTask(
            id: "retry-no-transport",
            mediaId: "tt-retry-no-transport",
            fileName: "retry-no-transport.mkv",
            status: .queued
        )
        try await database.saveDownloadTask(invalid)

        try await manager.retryDownload(id: invalid.id)
        let failed = try await waitForStatus(database: database, id: invalid.id, expected: .failed, timeoutSeconds: 12)

        #expect(failed.errorMessage != nil)
        #expect(await attemptCounter.snapshot() == 0)
    }

    @Test func retryPersistedDownloadUsesPersistedResumeDataFromDatabase() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-persisted-resume-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let resumeData = Data("persisted-resume".utf8)
        let persisted = DownloadTask(
            id: "retry-persisted-resume-data",
            mediaId: "tt-retry-persisted-resume-data",
            streamURL: "https://cdn.example.com/persisted-resume.mkv",
            fileName: "retry-persisted-resume.mkv",
            status: .failed,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await requestRecorder.record(request: request)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x65, count: 512)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/persisted-resume.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        let requests = await requestRecorder.snapshot()

        #expect(requests == [.init(usedResumeData: true, url: persisted.streamURL, requestHeaders: nil)])
        #expect(completed.resumeData == nil)
        #expect(completed.destinationURL != nil)
    }

    @Test func fileURLStreamIsConsideredViableAndDownloads() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-file-url.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let source = rootDir.appendingPathComponent("local-file-source.mkv")
        let sourceData = Data(repeating: 0x5A, count: 256)
        try sourceData.write(to: source)
        let requestRecorder = TransferRequestRecorder()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await requestRecorder.record(request: request)

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try sourceData.write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? source,
                    mimeType: "video/x-matroska",
                    expectedContentLength: sourceData.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let stream = StreamInfo(
            streamURL: source,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "file-url.mkv",
            sizeBytes: Int64(sourceData.count),
            debridService: DebridServiceType.realDebrid.rawValue
        )

        let task = try await manager.enqueueDownload(
            stream: stream,
            mediaId: "tt-file-url",
            episodeId: nil as String?
        )
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let requests = await requestRecorder.snapshot()
        let completedRequest = try #require(requests.first)
        let requestURL = try #require(completedRequest.url)
        let destinationURL = try #require(completed.destinationURL)

        #expect(requests.count == 1)
        #expect(completedRequest.usedResumeData == false)
        #expect(URL(string: requestURL)?.isFileURL == true)
        #expect(completed.status == DownloadStatus.completed)
        #expect(destinationURL.path != source.path)
        #expect(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    @Test func httpErrorResponsesDoNotCompleteDownload() async throws {
        try await assertHTTPErrorResponseDoesNotComplete(statusCode: 403, fileName: "forbidden.mkv", databaseName: "download-manager-http-403.sqlite")
        try await assertHTTPErrorResponseDoesNotComplete(statusCode: 410, fileName: "gone.mkv", databaseName: "download-manager-http-410.sqlite")
    }

    @Test func serverErrorResponsesDoNotCompleteDownload() async throws {
        try await assertHTTPErrorResponseDoesNotComplete(statusCode: 500, fileName: "server-error.mkv", databaseName: "download-manager-http-500.sqlite")
    }

    @Test func cancelMarksTaskCancelled() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeDelayedPerformer()
        )

        let task = try await manager.enqueueDownload(stream: makeStream(name: "cancel.mkv"), mediaId: "tt101", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading, timeoutSeconds: 10)

        await manager.cancelDownload(id: task.id)

        let cancelled = try await waitForStatus(database: database, id: task.id, expected: .cancelled)
        #expect(cancelled.status == .cancelled)
    }

    @Test func cancelDownloadForMissingTaskDoesNotThrowOrCreateRows() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-missing-task.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 10)
        )

        await manager.cancelDownload(id: "missing-task-id")
        let tasks = try await manager.listDownloads()
        #expect(tasks.isEmpty)
    }

    @Test func cancelDirectDownloadDoesNotInvokeRemoteCleanup() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-direct-no-cleanup.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let cleanupCounter = SyncCounter()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeDelayedPerformer(),
            remoteTransferCleaner: { _ in
                cleanupCounter.increment()
            }
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "cancel-direct-no-cleanup.mkv"),
            mediaId: "tt-cancel-direct-no-cleanup",
            episodeId: nil
        )
        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading, timeoutSeconds: 10)

        await manager.cancelDownload(id: task.id)
        _ = try await waitForStatus(database: database, id: task.id, expected: .cancelled)
        #expect(cleanupCounter.snapshot() == 0)
    }

    @Test func cancelDirectDownloadPersistsResumeDataForRetry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-retry-with-resume-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let resumeData = Data("cancel-retry-token".utf8)
        let attemptCounter = AttemptCounter()
        let requestRecorder = TransferRequestRecorder()

        let performer: DownloadManager.DownloadPerformer = { request, _, cancellationController in
            await requestRecorder.record(request: request)

            let attempt = await attemptCounter.next()
            if attempt == 1 {
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                    cancellationController.register {
                        continuation.resume(throwing: DownloadTransferError.resumeDataProduced(resumeData))
                    }
                }
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x72, count: 1_024)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: request.url ?? URL(string: "https://cdn.example.com/retry-after-cancel.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            maxConcurrentTransfers: 1
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "cancel-retry.mkv", sizeBytes: 1_024),
            mediaId: "tt-cancel-retry",
            episodeId: nil
        )
        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading)

        await manager.cancelDownload(id: task.id)
        let cancelled = try await waitForStatus(database: database, id: task.id, expected: .cancelled)
        #expect(cancelled.resumeData == resumeData)
        #expect(await attemptCounter.snapshot() == 1)

        try await manager.retryDownload(id: task.id)
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let requests = await requestRecorder.snapshot()

        #expect(completed.resumeData == nil)
        #expect(requests.count == 2)
        #expect(requests[0] == .init(usedResumeData: false, url: task.streamURL, requestHeaders: nil))
        #expect(requests[1] == .init(usedResumeData: true, url: task.streamURL, requestHeaders: nil))
        #expect(await attemptCounter.snapshot() == 2)
    }

    @Test func cancelRecoveryBackedDownloadDoesNotPersistResumeDataFromCancellation() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-recovery-ignore-resume-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let resumeData = Data("refresh-resume-token".utf8)
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "cafebabecafebabecafebabecafebabecafebabe",
                preferredService: .realDebrid
            )
        )
        let attemptCounter = AttemptCounter()

        let freshURL = URL(string: "https://cdn.example.com/retry-after-cancel-recovery.mkv")!
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, cancellationController in
                let attempt = await attemptCounter.next()
                if attempt == 1 {
                    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                        cancellationController.register {
                            continuation.resume(throwing: DownloadTransferError.resumeDataProduced(resumeData))
                        }
                    }
                }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x73, count: 1_024)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: freshURL,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            linkRefresher: { _ in freshURL },
            maxConcurrentTransfers: 1
        )

        let stream = makeStream(name: "recovery-cancel.mkv", sizeBytes: 1_024, recoveryContext: recoveryContext)
        let task = try await manager.enqueueDownload(stream: stream, mediaId: "tt-cancel-recovery-no-resume", episodeId: nil)

        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading)
        await manager.cancelDownload(id: task.id)

        let cancelled = try await waitForStatus(database: database, id: task.id, expected: .cancelled)
        #expect(cancelled.resumeData == nil)
        #expect(cancelled.persistedStreamURL == nil)
        #expect(await attemptCounter.snapshot() == 1)

        try await manager.retryDownload(id: task.id)
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)

        #expect(completed.resumeData == nil)
        #expect(completed.persistedStreamURL == nil)
        #expect(await attemptCounter.snapshot() == 2)
    }

    @Test func cancelDownloadEscalatesCancellationWhenCallbackDoesNotStopTransfer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-escalates.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()

        let performer: DownloadManager.DownloadPerformer = { _, _, cancellationController in
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                cancellationController.register {
                    // Intentionally no-op so cancellation relies on task cancellation escalation.
                }
                try await Task.sleep(for: .seconds(8))
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try Data(repeating: 0x5B, count: 256).write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/queued-recovery.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: 256,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            maxConcurrentTransfers: 1
        )

        let first = try await manager.enqueueDownload(stream: makeStream(name: "cancel-escalates-1.mkv"), mediaId: "tt-cancel-escalates", episodeId: nil)
        let second = try await manager.enqueueDownload(stream: makeStream(name: "cancel-escalates-2.mkv"), mediaId: "tt-cancel-escalates", episodeId: nil)

        _ = try await waitForStatus(database: database, id: first.id, expected: .downloading)
        _ = try await waitForStatus(database: database, id: second.id, expected: .queued)

        await manager.cancelDownload(id: first.id)

        _ = try await waitForStatus(database: database, id: first.id, expected: .cancelled)
        _ = try await waitForStatus(database: database, id: second.id, expected: .completed, timeoutSeconds: 8)

        #expect(await attemptCounter.snapshot() == 2)
    }

    @Test func cancellingRecoveryBackedTaskInvokesRemoteCleanup() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-remote-cleanup.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let cleanupRecorder = RemoteCleanupRecorder()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "1111111111111111111111111111111111111111",
                preferredService: .realDebrid,
                torrentId: "rd-remote-1",
                resolvedDebridService: DebridServiceType.realDebrid.rawValue
            )
        )
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeDelayedPerformer(),
            remoteTransferCleaner: { context in
                await cleanupRecorder.record(context)
            }
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "cancel-cleanup.mkv", recoveryContext: recoveryContext),
            mediaId: "tt-cancel-cleanup",
            episodeId: nil
        )
        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading, timeoutSeconds: 10)

        await manager.cancelDownload(id: task.id)

        let cancelled = try await waitForStatus(database: database, id: task.id, expected: .cancelled)
        let expectedCleanupContext = recoveryContext.enrichedForDownloadPersistence(
            fileName: "cancel-cleanup.mkv",
            sizeBytes: 100,
            debridService: DebridServiceType.realDebrid.rawValue
        )
        #expect(cancelled.status == .cancelled)
        #expect(await cleanupRecorder.snapshot() == [expectedCleanupContext])
    }

    @Test func cancellingRecoveryBackedTaskClearsPersistedReplayableTransportState() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-redacts-recovery.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "deadc0dedeadc0dedeadc0dedeadc0dedeadc0de",
                preferredService: .realDebrid,
                seasonNumber: 2,
                episodeNumber: 5
            )
        )
        let persisted = DownloadTask(
            id: "cancel-recovery-backed",
            mediaId: "tt-cancel-recovery",
            streamURL: "https://cdn.example.com/stale.mkv?token=secret",
            fileName: "cancel-recovery.mkv",
            status: .failed,
            progress: 0.33,
            bytesWritten: 333,
            totalBytes: 1_000,
            mediaTitle: "Cancel Recovery",
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 1_000,
            resumeDataBase64: Data("legacy-resume".utf8).base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 1),
            linkRefresher: { _ in
                URL(string: "https://cdn.example.com/fresh.mkv")!
            }
        )

        await manager.cancelDownload(id: persisted.id)

        let cancelled = try await waitForStatus(database: database, id: persisted.id, expected: .cancelled)
        #expect(cancelled.persistedStreamURL == nil)
        #expect(cancelled.resumeData == nil)
    }

    @Test func diskSpacePreflightRejectsOversizedDownloadBeforeQueueing() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-disk-space.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 1_024),
            minimumFreeSpaceBufferBytes: 128,
            availableDiskSpace: { _ in 1_024 }
        )

        var didThrow = false
        do {
            _ = try await manager.enqueueDownload(
                stream: makeStream(name: "too-large.mkv", sizeBytes: 2_048),
                mediaId: "tt-disk-space",
                episodeId: nil
            )
        } catch let error as DownloadTransferError {
            didThrow = true
            if case .insufficientDiskSpace = error {
                #expect(Bool(true))
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        }

        #expect(didThrow)
        let stored = try await manager.listDownloads()
        #expect(stored.isEmpty)
    }

    @Test func diskSpaceProviderThrowingDuringEnqueueResultsInError() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-disk-space-provider-throw.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 1_024),
            availableDiskSpace: { _ in throw DiskProbeError.unavailable }
        )

        var didThrow = false
        do {
            _ = try await manager.enqueueDownload(
                stream: makeStream(name: "provider-error.mkv", sizeBytes: 1_024),
                mediaId: "tt-disk-space-provider",
                episodeId: nil
            )
        } catch {
            didThrow = true
            #expect(error is DiskProbeError)
        }

        #expect(didThrow)
        let stored = try await manager.listDownloads()
        #expect(stored.isEmpty)
    }

    @Test func zeroAvailableDiskSpaceDoesNotBlockDownloadWhenProviderCannotMeasureSpace() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-disk-space-unknown.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let performer: DownloadManager.DownloadPerformer = { _, _, _ in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x11, count: 256)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/unknown-space.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            availableDiskSpace: { _ in nil }
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "zero-space.mkv", sizeBytes: 128 * 1024),
            mediaId: "tt-zero-space",
            episodeId: nil
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        #expect(completed.status == DownloadStatus.completed)
    }

    @Test func zeroByteDownloadSkipsDiskSpaceProvider() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-disk-space-zero-bytes.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let diskProbeCounter = SyncCounter()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 100),
            availableDiskSpace: { _ in
                diskProbeCounter.increment()
                throw DiskProbeError.unavailable
            }
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "zero-size.mkv", sizeBytes: 0),
            mediaId: "tt-zero-size",
            episodeId: nil
        )
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        #expect(completed.status == DownloadStatus.completed)
        #expect(diskProbeCounter.snapshot() == 0)
    }

    @Test func negativeMinimumFreeSpaceBufferIsClampedToZero() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-negative-buffer.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 100),
            minimumFreeSpaceBufferBytes: -50,
            availableDiskSpace: { _ in 95 }
        )

        var didThrow = false
        do {
            _ = try await manager.enqueueDownload(
                stream: makeStream(name: "negative-buffer.mkv", sizeBytes: 100),
                mediaId: "tt-negative-buffer",
                episodeId: nil
            )
        } catch let error as DownloadTransferError {
            didThrow = true
            if case .insufficientDiskSpace = error {
                #expect(Bool(true))
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        }

        #expect(didThrow)
        #expect(try await manager.listDownloads().isEmpty)
    }

    @Test func startupQueuedTaskFailsWhenDiskSpaceProviderThrows() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-disk-space-throw.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()

        let task = DownloadTask(
            id: "startup-disk-fail",
            mediaId: "tt-startup-disk-fail",
            streamURL: "https://cdn.example.com/startup-disk-fail.mkv",
            fileName: "startup-disk-fail.mkv",
            status: .queued,
            totalBytes: 1_024,
            expectedBytes: 1_024
        )

        try await database.saveDownloadTask(task)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x12, count: 512)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-disk-fail.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: { _ in
                throw DiskProbeError.unavailable
            }
        )

        let failed = try await waitForStatus(database: database, id: task.id, expected: .failed)
        #expect(failed.status == .failed)
        #expect(await attemptCounter.snapshot() == 0)
        withExtendedLifetime(manager) {}
    }

    @Test func zeroByteDownloadCannotCreateDownloadsDirectory() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-complete-no-directory.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let badDownloadsDir = rootDir.appendingPathComponent("downloads-file", isDirectory: true)
        try Data([0x00]).write(to: badDownloadsDir)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: badDownloadsDir,
            performer: makeSuccessfulPerformer(bytes: 64)
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "completion-directory-fail.mkv", sizeBytes: 0),
            mediaId: "tt-complete-directory-fail",
            episodeId: nil
        )

        let failed = try await waitForStatus(database: database, id: task.id, expected: .failed)
        #expect(failed.status == .failed)
        #expect(failed.destinationPath == nil)
        #expect(failed.errorMessage != nil)
    }

    @Test func completionFailsWhenDownloadsDirectoryBecomesBlocked() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-completion-blocked-dir.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = BlockingDownloadGate()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x77, count: 2_048)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/completion-blocked.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            }
        )

        defer {
            Task { await gate.resume() }
        }

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "completion-blocked.mkv", sizeBytes: 2_048),
            mediaId: "tt-completion-blocked",
            episodeId: nil
        )

        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading, timeoutSeconds: 10)
        try await replaceDirectoryWithBlockingFile(at: downloadsDir)
        await gate.resume()

        let failed = try await waitForStatus(database: database, id: task.id, expected: .failed, timeoutSeconds: 10)
        #expect(failed.status == .failed)
        #expect(failed.destinationPath == nil)
        #expect(failed.destinationURL == nil)
        #expect(failed.progress == 0.0)
        #expect(failed.errorMessage != nil)
    }

    @Test func preExistingDownloadsDirectoryFileIsSkippedWhenReservingDestination() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-preexisting-file.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let fileName = "preexisting.mkv"
        let preexisting = downloadsDir.appendingPathComponent(fileName)
        try Data([0x00]).write(to: preexisting)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 256)
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: fileName),
            mediaId: "tt-preexisting",
            episodeId: nil
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let destination = try #require(completed.destinationURL)

        #expect(destination.lastPathComponent != fileName)
        #expect(destination.lastPathComponent.contains(" (1)"))
        #expect(destination.path != preexisting.path)
        #expect(FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func concurrentDownloadRejectsWhenEffectiveRemainingSpaceIsZero() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-disk-space-concurrent.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let gate = BlockingDownloadGate()

        let performer: DownloadManager.DownloadPerformer = { _, _, _ in
            let attempt = await attemptCounter.next()

            if attempt == 1 {
                await gate.wait()
            }

            let bytes = attempt == 1 ? 100 : 1
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x01, count: bytes)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/concurrent-space-test.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            maxConcurrentTransfers: 2,
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 100 }
        )

        let firstTask = try await manager.enqueueDownload(
            stream: makeStream(name: "first.mkv", sizeBytes: 100),
            mediaId: "tt-concurrent-disk-space",
            episodeId: nil as String?
        )
        var firstStarted = false
        for _ in 0..<200 {
            if await attemptCounter.snapshot() >= 1 {
                firstStarted = true
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        guard firstStarted else { throw DownloadManagerTestError.timeout }

        do {
            _ = try await manager.enqueueDownload(
                stream: makeStream(name: "second.mkv", sizeBytes: 1),
                mediaId: "tt-concurrent-disk-space-2",
                episodeId: nil as String?
            )
            #expect(Bool(false))
        } catch let error as DownloadTransferError {
            if case let .insufficientDiskSpace(required, available) = error {
                #expect(required > 0)
                #expect(available == 0)
            } else {
                Issue.record("Expected insufficientDiskSpace, got \(error)")
            }
        }

        Task { await gate.resume() }
        _ = try await waitForStatus(database: database, id: firstTask.id, expected: .completed)
        #expect(await attemptCounter.snapshot() == 1)
    }

    @Test func retryAfterFailureTransitionsToCompleted() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let recoveryContext = StreamRecoveryContext(
            infoHash: "0123456789abcdef0123456789abcdef01234567",
            preferredService: .realDebrid,
            seasonNumber: 1,
            episodeNumber: 2
        )!

        let performer: DownloadManager.DownloadPerformer = { _, _, _ in
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadTransferError.badHTTPStatus(500)
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let bytes = Data(repeating: 0x2A, count: 1024)
            try bytes.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/retry.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: 1024,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            resumePersistedDownloadsOnInit: false
        )
        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "retry.mkv", recoveryContext: recoveryContext),
            mediaId: "tt102",
            episodeId: nil
        )

        _ = try await waitForStatus(database: database, id: task.id, expected: .failed, timeoutSeconds: 60)

        try await manager.retryDownload(id: task.id)
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed, timeoutSeconds: 60)
        #expect(completed.errorMessage == nil)
        #expect(completed.destinationURL != nil)
        #expect(completed.recoveryContext?.infoHash == recoveryContext.infoHash)
        #expect(completed.recoveryContext?.preferredService == recoveryContext.preferredService)
        #expect(completed.recoveryContext?.seasonNumber == recoveryContext.seasonNumber)
        #expect(completed.recoveryContext?.episodeNumber == recoveryContext.episodeNumber)
        #expect(completed.recoveryContextJSON != nil)
    }

    @Test func completedRecoveryBackedDownloadInvokesRemoteCleanup() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-complete-remote-cleanup.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let cleanupRecorder = RemoteCleanupRecorder()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "2222222222222222222222222222222222222222",
                preferredService: .allDebrid,
                torrentId: "ad-remote-1",
                resolvedDebridService: DebridServiceType.allDebrid.rawValue
            )
        )
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 2_048),
            remoteTransferCleaner: { context in
                await cleanupRecorder.record(context)
            }
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "completed-cleanup.mkv", recoveryContext: recoveryContext),
            mediaId: "tt-complete-cleanup",
            episodeId: nil
        )

        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let expectedCleanupContext = recoveryContext.enrichedForDownloadPersistence(
            fileName: "completed-cleanup.mkv",
            sizeBytes: 100,
            debridService: DebridServiceType.realDebrid.rawValue
        )
        try await waitForRemoteCleanup(cleanupRecorder, expected: [expectedCleanupContext])
    }

    @Test func removingRecoveryBackedDownloadInvokesRemoteCleanup() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-remote-cleanup.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let cleanupRecorder = RemoteCleanupRecorder()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "3333333333333333333333333333333333333333",
                preferredService: .offcloud,
                torrentId: "offcloud-remote-1",
                resolvedDebridService: DebridServiceType.offcloud.rawValue
            )
        )
        let persisted = DownloadTask(
            id: "remove-recovery-backed",
            mediaId: "tt-remove-cleanup",
            streamURL: nil,
            fileName: "remove-cleanup.mkv",
            status: .cancelled,
            recoveryContextJSON: try recoveryContext.jsonString()
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 1),
            remoteTransferCleaner: { context in
                await cleanupRecorder.record(context)
            }
        )

        try await manager.removeDownload(id: persisted.id)

        #expect(try await database.fetchDownloadTask(id: persisted.id) == nil)
        #expect(await cleanupRecorder.snapshot() == [recoveryContext])
    }

    @Test func retryWaitsForCancelledTransferTeardownBeforeRestarting() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-cancel.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let attemptCounter = AttemptCounter()
        let recorder = RetryCancellationRecorder()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)

        let performer: DownloadManager.DownloadPerformer = { _, _, cancellationController in
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    cancellationController.register {
                        Task { await recorder.markFirstAttemptCancelled() }
                        continuation.resume(throwing: CancellationError())
                    }
                }
            }

            await recorder.markSecondAttemptStarted()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x3C, count: 256)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/restart.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: 256,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(database: database, downloadsDirectory: downloadsDir, performer: performer)
        let task = try await manager.enqueueDownload(stream: makeStream(name: "restart.mkv"), mediaId: "tt107", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading)

        try await manager.retryDownload(id: task.id)

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let (cancelledAt, secondStartedAt) = await recorder.snapshot()
        #expect(completed.status == DownloadStatus.completed)
        #expect(cancelledAt != nil)
        #expect(secondStartedAt != nil)
        if let cancelledAt, let secondStartedAt {
            #expect(secondStartedAt >= cancelledAt)
        }
    }

    @Test func retryPreservesProgressWhenResumeDataIsProduced() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-resume-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let secondAttemptGate = BlockingDownloadGate()
        let resumeRecorder = ResumeDataRecorder()
        let producedResumeData = Data("resume-point".utf8)
        let performer: DownloadManager.DownloadPerformer = { request, progressHandler, cancellationController in
            await resumeRecorder.record(request.resumeData)
            if request.resumeData == nil {
                progressHandler(200, 200, 1_000)
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                    cancellationController.register {
                        continuation.resume(throwing: DownloadTransferError.resumeDataProduced(producedResumeData))
                    }
                }
            }

            await secondAttemptGate.wait()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x7C, count: 800)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/resume-produced.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "resume-produced.mkv", sizeBytes: 1_000),
            mediaId: "tt108",
            episodeId: nil
        )
        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading)
        _ = try await waitForProgress(database: database, id: task.id, minimum: 0.2)

        try await manager.retryDownload(id: task.id)

        let resumed = try await waitForStatus(database: database, id: task.id, expected: .downloading)
        #expect(abs(resumed.progress - 0.2) < 0.001)
        #expect(resumed.bytesWritten == 200)
        #expect(resumed.resumeData != nil)

        var sawResumeData = false
        for _ in 0..<20 {
            if await resumeRecorder.snapshot() {
                sawResumeData = true
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(sawResumeData)

        await secondAttemptGate.resume()
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        #expect(completed.resumeData == nil)
    }

    @Test func retryWithoutResumeDataResetsObservedProgress() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-partial-no-resume.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let blocker = BlockingDownloadGate()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)

        let performer: DownloadManager.DownloadPerformer = { _, _, _ in
            await blocker.wait()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x3A, count: 1_024)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/no-resume-retry.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        try await database.saveDownloadTask(
            DownloadTask(
                id: "partial-no-resume",
                mediaId: "tt-no-resume",
                streamURL: "https://cdn.example.com/no-resume-retry.mkv",
                fileName: "no-resume-retry.mkv",
                status: .failed,
                progress: 0.42,
                bytesWritten: 420,
                totalBytes: 1_024,
                mediaTitle: "No Resume Retry",
                mediaType: "movie"
            )
        )

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer
        )

        try await manager.retryDownload(id: "partial-no-resume")

        let restarting = try await waitForStatus(database: database, id: "partial-no-resume", expected: .downloading)
        #expect(restarting.progress == 0)
        #expect(restarting.bytesWritten == 0)

        await blocker.resume()

        let completed = try await waitForStatus(database: database, id: "partial-no-resume", expected: .completed)
        #expect(completed.bytesWritten == 1_024)
    }

    @Test func retryWithResumeDataUsesRemainingDiskAllowance() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-remaining-bytes.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let blocker = BlockingDownloadGate()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)

        let performer: DownloadManager.DownloadPerformer = { _, _, _ in
            await blocker.wait()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x3A, count: 1_000)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/remaining-allowance.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let resumedTask = DownloadTask(
            id: "partial-resume",
            mediaId: "tt-resume-allowance",
            streamURL: "https://cdn.example.com/remaining-allowance.mkv",
            fileName: "remaining-allowance.mkv",
            status: .failed,
            progress: 0.42,
            bytesWritten: 800,
            mediaTitle: "Allowance Test",
            expectedBytes: 1_000,
            resumeDataBase64: Data("resume-point".utf8).base64EncodedString()
        )
        try await database.saveDownloadTask(resumedTask)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 250 }
        )

        try await manager.retryDownload(id: resumedTask.id)

        let restarting = try await waitForStatus(database: database, id: resumedTask.id, expected: .downloading)
        #expect(restarting.status == DownloadStatus.downloading)

        await blocker.resume()
        _ = try await waitForStatus(database: database, id: resumedTask.id, expected: .completed)
    }

    @Test func recoveryBackedDownloadsRedactReplayableURLButKeepEnrichedContext() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-recovery-context.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let gate = BlockingDownloadGate()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let replayableURL = URL(string: "https://cdn.example.com/replayable.mkv?token=abc123")!
        let recoveryContext = StreamRecoveryContext(
            infoHash: "fedcba9876543210fedcba9876543210fedcba98",
            preferredService: .realDebrid,
            seasonNumber: 1,
            episodeNumber: 4
        )!

        let performer: DownloadManager.DownloadPerformer = { _, _, _ in
            await gate.wait()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x2B, count: 128)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: replayableURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        defer {
            Task { await gate.resume() }
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in
                URL(string: "https://cdn.example.com/refreshed.mkv")!
            }
        )

        let task = try await manager.enqueueDownload(
            stream: StreamInfo(
                streamURL: replayableURL,
                quality: .hd1080p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: "Replayable.S01E04.mkv",
                sizeBytes: 4_096,
                debridService: DebridServiceType.realDebrid.rawValue,
                recoveryContext: recoveryContext
            ),
            mediaId: "tt-replayable",
            episodeId: "ep-4"
        )

        let stored = try #require(try await database.fetchDownloadTask(id: task.id))
        let storedContext = try #require(stored.recoveryContext)
        #expect(stored.persistedStreamURL == nil)
        #expect(storedContext.infoHash == recoveryContext.infoHash)
        #expect(storedContext.preferredService == recoveryContext.preferredService)
        #expect(storedContext.seasonNumber == recoveryContext.seasonNumber)
        #expect(storedContext.episodeNumber == recoveryContext.episodeNumber)
        #expect(storedContext.resolvedDebridService == DebridServiceType.realDebrid.rawValue)
        #expect(storedContext.resolvedFileName == "Replayable.S01E04.mkv")
        #expect(storedContext.resolvedFileSizeBytes == 4_096)
    }

    @Test func recoveryBackedDownloadsRetryInSameSessionWithoutPersistingReplayableTransportState() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-recovery-runtime-retry.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attempts = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let replayableURL = URL(string: "https://cdn.example.com/runtime-retry.mkv?token=abc123")!
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "abababababababababababababababababababab",
                preferredService: .realDebrid,
                seasonNumber: 1,
                episodeNumber: 6
            )
        )

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let attempt = await attempts.next()
            if attempt == 1 {
                throw DownloadManagerTestError.timeout
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x44, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: replayableURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer
        )

        let task = try await manager.enqueueDownload(
            stream: StreamInfo(
                streamURL: replayableURL,
                quality: .hd1080p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: "RuntimeRetry.S01E06.mkv",
                sizeBytes: 512,
                debridService: DebridServiceType.realDebrid.rawValue,
                recoveryContext: recoveryContext
            ),
            mediaId: "tt-runtime-retry",
            episodeId: "ep-6"
        )

        let failed = try await waitForStatus(database: database, id: task.id, expected: .failed)
        #expect(failed.persistedStreamURL == nil)
        #expect(failed.resumeData == nil)

        try await manager.retryDownload(id: task.id)

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        #expect(completed.persistedStreamURL == nil)
        #expect(completed.resumeData == nil)

        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: replayableURL.absoluteString, requestHeaders: nil),
            .init(usedResumeData: false, url: replayableURL.absoluteString, requestHeaders: nil),
        ])
    }

    @Test func directStreamRequestHeadersReachDownloadPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-direct-stream-headers.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let streamURL = URL(string: "https://cdn.example.com/protected.mkv")!
        let stream = StreamInfo(
            streamURL: streamURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Protected.mkv",
            sizeBytes: 512,
            debridService: "Stremio",
            requestHeaders: [
                "User-Agent": "Stremio",
                "Referer": "https://app.strem.io/",
                "Bad\nHeader": "ignored"
            ]
        )

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x44, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: streamURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer
        )

        let task = try await manager.enqueueDownload(stream: stream, mediaId: "tt-headers", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)

        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(
                usedResumeData: false,
                url: streamURL.absoluteString,
                requestHeaders: [
                    "User-Agent": "Stremio",
                    "Referer": "https://app.strem.io/"
                ]
            )
        ])
    }

    @Test func directStreamRequestHeadersSurviveLinkRefreshRetry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-direct-stream-refresh-headers.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let staleURL = URL(string: "https://cdn.example.com/protected-stale.mkv")!
        let freshURL = URL(string: "https://cdn.example.com/protected-fresh.mkv")!
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "0123456789abcdef0123456789abcdef01234567",
                preferredService: .realDebrid
            )
        )
        let stream = StreamInfo(
            streamURL: staleURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Protected.Refresh.mkv",
            sizeBytes: 512,
            debridService: "Stremio",
            recoveryContext: recoveryContext,
            requestHeaders: [
                "User-Agent": "Stremio",
                "Referer": "https://app.strem.io/",
                "Bad\nHeader": "ignored"
            ]
        )

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadTransferError.badHTTPStatus(451)
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x52, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: freshURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in freshURL },
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let task = try await manager.enqueueDownload(stream: stream, mediaId: "tt-refresh-headers", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)

        let expectedHeaders = [
            "User-Agent": "Stremio",
            "Referer": "https://app.strem.io/"
        ]
        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: freshURL.absoluteString, requestHeaders: expectedHeaders),
            .init(usedResumeData: false, url: freshURL.absoluteString, requestHeaders: expectedHeaders)
        ])
    }

    @Test func recoveryStreamRequestHeadersSurviveLinkRefreshRetry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-recovery-stream-refresh-headers.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let staleURL = URL(string: "https://cdn.example.com/recovery-stale.mkv")!
        let freshURL = URL(string: "https://cdn.example.com/recovery-fresh.mkv")!
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "feedfacecafebabecafebabecafebabecafebabe",
                preferredService: .realDebrid
            )
        )
        let stream = StreamInfo(
            streamURL: staleURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Recovery.RefreshHeaders.mkv",
            sizeBytes: 512,
            debridService: "Stremio",
            recoveryContext: recoveryContext,
            requestHeaders: [
                "User-Agent": "Stremio",
                "Referer": "https://app.strem.io/",
                "Bad\nHeader": "ignored"
            ]
        )

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadTransferError.badHTTPStatus(451)
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x54, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: freshURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in freshURL },
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let task = try await manager.enqueueDownload(stream: stream, mediaId: "tt-recovery-refresh-headers", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)

        let expectedHeaders = [
            "User-Agent": "Stremio",
            "Referer": "https://app.strem.io/"
        ]
        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: freshURL.absoluteString, requestHeaders: expectedHeaders),
            .init(usedResumeData: false, url: freshURL.absoluteString, requestHeaders: expectedHeaders),
        ])
    }

    @Test func directStreamRequestHeadersSurviveRetry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-direct-stream-retry-headers.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let streamURL = URL(string: "https://cdn.example.com/protected.mkv")!
        let stream = StreamInfo(
            streamURL: streamURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Protected.Retry.mkv",
            sizeBytes: 512,
            debridService: "Stremio",
            requestHeaders: [
                "User-Agent": "Stremio",
                "Referer": "https://app.strem.io/",
                "Bad\nHeader": "ignored"
            ]
        )

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadManagerTestError.timeout
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x58, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: streamURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let task = try await manager.enqueueDownload(stream: stream, mediaId: "tt-retry-headers", episodeId: nil)
        let failed = try await waitForStatus(database: database, id: task.id, expected: .failed)
        #expect(failed.errorMessage != nil)

        try await manager.retryDownload(id: task.id)

        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)

        let expectedHeaders = [
            "User-Agent": "Stremio",
            "Referer": "https://app.strem.io/"
        ]
        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: streamURL.absoluteString, requestHeaders: expectedHeaders),
            .init(usedResumeData: false, url: streamURL.absoluteString, requestHeaders: expectedHeaders),
        ])
    }

    @Test func directStreamRequestHeadersSurviveRefreshRetry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-direct-stream-refresh-headers.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let requestRecorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let staleURL = URL(string: "https://cdn.example.com/direct-refresh-old.mkv")!
        let freshURL = URL(string: "https://cdn.example.com/direct-refresh-new.mkv")!
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "1234567890abcdef1234567890abcdef12345678",
                preferredService: .realDebrid
            )
        )
        let expectedHeaders = [
            "User-Agent": "Stremio",
            "Referer": "https://app.strem.io/"
        ]

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await requestRecorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadTransferError.badHTTPStatus(403)
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x59, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: freshURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let stream = StreamInfo(
            streamURL: staleURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Direct.Refresh.Headers.mkv",
            sizeBytes: 512,
            debridService: "Stremio",
            recoveryContext: recoveryContext,
            requestHeaders: expectedHeaders.merging(["Bad\nHeader": "ignored"], uniquingKeysWith: { _, new in new })
        )

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in freshURL },
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let task = try await manager.enqueueDownload(stream: stream, mediaId: "tt-direct-refresh-headers", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)

        let requests = await requestRecorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: freshURL.absoluteString, requestHeaders: expectedHeaders),
            .init(usedResumeData: false, url: freshURL.absoluteString, requestHeaders: expectedHeaders),
        ])
        #expect(await attemptCounter.snapshot() == 2)
    }

    @Test func directStreamRequestHeadersSurviveResumeDataRetry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-direct-stream-resume-data-headers.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let requestRecorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let streamURL = URL(string: "https://cdn.example.com/protected-retry.mkv")!
        let expectedHeaders = [
            "User-Agent": "Stremio",
            "Referer": "https://app.strem.io/"
        ]
        let stream = StreamInfo(
            streamURL: streamURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Protected.ResumeRetry.mkv",
            sizeBytes: 512,
            debridService: "Stremio",
            requestHeaders: expectedHeaders.merging(["Bad\nHeader": "ignored"], uniquingKeysWith: { _, new in new })
        )

        let resumeData = Data("resume".utf8)
        let performer: DownloadManager.DownloadPerformer = { request, _, cancellationController in
            await requestRecorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                    cancellationController.register {
                        continuation.resume(throwing: DownloadTransferError.resumeDataProduced(resumeData))
                    }
                }
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x55, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: streamURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            maxConcurrentTransfers: 1,
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let task = try await manager.enqueueDownload(stream: stream, mediaId: "tt-resume-retry-headers", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading)
        await manager.cancelDownload(id: task.id)

        let cancelled = try await waitForStatus(database: database, id: task.id, expected: .cancelled)
        #expect(cancelled.resumeData == resumeData)
        #expect(await attemptCounter.snapshot() == 1)

        try await manager.retryDownload(id: task.id)
        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)

        let requests = await requestRecorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: streamURL.absoluteString, requestHeaders: expectedHeaders),
            .init(usedResumeData: true, url: streamURL.absoluteString, requestHeaders: expectedHeaders),
        ])
    }

    @Test func recoveryBackedStreamRequestHeadersSurviveCancelledRetry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-recovery-stream-resume-data-headers.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let requestRecorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let streamURL = URL(string: "https://cdn.example.com/protected-recovery-retry.mkv")!
        let expectedHeaders = [
            "User-Agent": "Stremio",
            "Referer": "https://app.strem.io/"
        ]
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                preferredService: .realDebrid
            )
        )
        let stream = StreamInfo(
            streamURL: streamURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Protected.Recovery.ResumeRetry.mkv",
            sizeBytes: 512,
            debridService: "Stremio",
            recoveryContext: recoveryContext,
            requestHeaders: expectedHeaders.merging(["Bad\nHeader": "ignored"], uniquingKeysWith: { _, new in new })
        )

        let resumeData = Data("recovery-retry-token".utf8)
        let performer: DownloadManager.DownloadPerformer = { request, _, cancellationController in
            await requestRecorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                    cancellationController.register {
                        continuation.resume(throwing: DownloadTransferError.resumeDataProduced(resumeData))
                    }
                }
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x66, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: streamURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            maxConcurrentTransfers: 1
        )

        let task = try await manager.enqueueDownload(stream: stream, mediaId: "tt-retry-recovery-headers", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading)
        await manager.cancelDownload(id: task.id)
        let cancelled = try await waitForStatus(database: database, id: task.id, expected: .cancelled)
        #expect(cancelled.resumeData == nil)
        #expect(await attemptCounter.snapshot() == 1)

        try await manager.retryDownload(id: task.id)
        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)

        let requests = await requestRecorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: streamURL.absoluteString, requestHeaders: expectedHeaders),
            .init(usedResumeData: true, url: streamURL.absoluteString, requestHeaders: expectedHeaders),
        ])
    }

    @Test func cfNetworkLikeExpiredErrorTriggersRefreshBeforeRetry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cfnetwork-refresh-retry.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let refreshCounter = AttemptCounter()
        let requestRecorder = TransferRequestRecorder()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "cfnetworkrefresh1234567890abcdef",
                preferredService: .realDebrid
            )
        )
        let freshURL = URL(string: "https://cdn.example.com/cfnetwork-fresh.mkv")!

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await requestRecorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw NSError(
                    domain: "kCFErrorDomainCFNetwork",
                    code: 303,
                    userInfo: [NSUnderlyingErrorKey: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)]
                )
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x5D, count: 256)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: freshURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in
                _ = await refreshCounter.next()
                return freshURL
            }
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "cfnetwork-refresh.mkv", recoveryContext: recoveryContext),
            mediaId: "tt-cfnetwork-refresh",
            episodeId: nil
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        #expect(await attemptCounter.snapshot() == 2)
        #expect(await refreshCounter.snapshot() == 2)
        #expect(completed.status == DownloadStatus.completed)

        let requests = await requestRecorder.snapshot()
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.usedResumeData == false })
        #expect(requests.first?.url == freshURL.absoluteString)
        #expect(requests.last?.url == freshURL.absoluteString)
    }

    @Test func duplicateFileNamesUseCollisionSafeSuffixes() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-duplicate.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let expectedFirstName = "same-name.mkv"
        let expectedSecondName = "same-name (1).mkv"
        let attemptCounter = AttemptCounter()
        let firstAttemptGate = BlockingDownloadGate()

        let performer: DownloadManager.DownloadPerformer = { _, _, _ in
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                await firstAttemptGate.wait()
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x01, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/video.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            resumePersistedDownloadsOnInit: false
        )

        let first = try await manager.enqueueDownload(stream: makeStream(name: "same-name.mkv"), mediaId: "tt103", episodeId: nil)
        let second = try await manager.enqueueDownload(stream: makeStream(name: "same-name.mkv"), mediaId: "tt104", episodeId: nil)
        await firstAttemptGate.resume()

        let secondCompleted = try await waitForStatus(database: database, id: second.id, expected: .completed)
        let firstCompleted = try await waitForStatus(database: database, id: first.id, expected: .completed)

        let firstPath = try #require(firstCompleted.destinationPath)
        let secondPath = try #require(secondCompleted.destinationPath)
        let firstName = URL(fileURLWithPath: firstPath).lastPathComponent
        let secondName = URL(fileURLWithPath: secondPath).lastPathComponent

        #expect(firstPath != secondPath)
        #expect(firstName == expectedFirstName)
        #expect(secondName == expectedSecondName)
        #expect(FileManager.default.fileExists(atPath: firstPath))
        #expect(FileManager.default.fileExists(atPath: secondPath))
    }

    @Test func duplicateFileNamesSkipExistingCollisionSuffixes() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-duplicate-existing-suffix.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        try Data([0x01]).write(to: downloadsDir.appendingPathComponent("same-name.mkv"))
        try Data([0x02]).write(to: downloadsDir.appendingPathComponent("same-name (1).mkv"))

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 64),
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "same-name.mkv", sizeBytes: 64),
            mediaId: "tt-duplicate-existing-suffix",
            episodeId: nil
        )
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let destinationPath = try #require(completed.destinationPath)

        #expect(URL(fileURLWithPath: destinationPath).lastPathComponent == "same-name (2).mkv")
        #expect(FileManager.default.fileExists(atPath: destinationPath))
    }

    @Test func downloadManagerRejectsBlankFileNameAndFallsBackToSafeDefault() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-fallback-filename.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 64)
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "   "),
            mediaId: "tt-blank-filename",
            episodeId: nil
        )
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)

        #expect(completed.fileName.hasPrefix("download-"))
        #expect(completed.fileName.hasSuffix(".mp4"))
        #expect(!completed.fileName.contains(" "))
    }

    @Test func retryDownloadSanitizesPersistedLegacyFileNameBeforeWriting() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-legacy-filename.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let legacy = DownloadTask(
            id: "legacy-file-name",
            mediaId: "tt-legacy-filename",
            streamURL: "https://cdn.example.com/legacy.mkv",
            fileName: "../bad:name?.mkv",
            status: .failed,
            expectedBytes: 64
        )
        try await database.saveDownloadTask(legacy)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 64),
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: legacy.id)

        let completed = try await waitForStatus(database: database, id: legacy.id, expected: .completed)
        let destinationPath = try #require(completed.destinationPath)
        let destinationURL = URL(fileURLWithPath: destinationPath)

        #expect(completed.fileName == "bad_name_.mkv")
        #expect(destinationURL.deletingLastPathComponent().standardizedFileURL.path == downloadsDir.standardizedFileURL.path)
        #expect(destinationURL.lastPathComponent == completed.fileName)
        #expect(!destinationPath.contains("../bad"))
    }

    private func schedulerCapsConcurrentDownloadsAndStartsQueuedWorkWhenSlotFrees() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-concurrency.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = BlockingDownloadGate()
        let attemptCounter = AttemptCounter()
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let attempt = await attemptCounter.next()
                if attempt == 1 {
                    await gate.wait()
                }
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x21, count: 256)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/queued.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1
        )

        let first = try await manager.enqueueDownload(stream: makeStream(name: "first.mkv"), mediaId: "tt201", episodeId: nil)
        let second = try await manager.enqueueDownload(stream: makeStream(name: "second.mkv"), mediaId: "tt202", episodeId: nil)

        var firstStarted = false
        for _ in 0..<200 {
            if await attemptCounter.snapshot() >= 1 {
                firstStarted = true
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        guard firstStarted else { throw DownloadManagerTestError.timeout }

        let queued = try #require(try await database.fetchDownloadTask(id: second.id))
        #expect(queued.status == .queued)

        await gate.resume()
        _ = try await waitForStatus(database: database, id: first.id, expected: .completed, timeoutSeconds: 30)
        _ = try await waitForStatus(database: database, id: second.id, expected: .completed, timeoutSeconds: 30)
        #expect(await attemptCounter.snapshot() == 2)
    }

    @Test func zeroMaxConcurrentTransfersStillProcessesDownloadsSerially() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-max-concurrent-zero.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = MultiDownloadGate()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x61, count: 256)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/serial.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 0
        )

        let first = try await manager.enqueueDownload(stream: makeStream(name: "serial-first.mkv"), mediaId: "tt-ser-1", episodeId: nil)
        let second = try await manager.enqueueDownload(stream: makeStream(name: "serial-second.mkv"), mediaId: "tt-ser-2", episodeId: nil)

        _ = try await waitForStatus(database: database, id: first.id, expected: .downloading)
        let secondQueued = try #require(await database.fetchDownloadTask(id: second.id))
        #expect(secondQueued.status == .queued)

        await gate.resumeOne()
        _ = try await waitForStatus(database: database, id: first.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: second.id, expected: .downloading)

        await gate.resumeOne()
        _ = try await waitForStatus(database: database, id: second.id, expected: .completed)
    }

    @Test func completedDownloadsAreVisibleAfterManagerRecreate() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-reload.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)

        let managerA = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 1024)
        )

        let task = try await managerA.enqueueDownload(stream: makeStream(name: "persist.mkv"), mediaId: "tt105", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)

        let managerB = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 256)
        )
        let listed = try await managerB.listDownloads()

        #expect(listed.contains(where: { $0.id == task.id && $0.status == .completed }))
    }

    @Test func startupRecoveryBackedQueuedTaskFailsWhenRefresherThrows() async throws {
        enum StartupRefresherError: Error {
            case expired
        }

        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-refresher-fail.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "0123456789abcdef0123456789abcdef01234567",
                preferredService: .realDebrid
            )
        )
        let recoveryContextJSON = try String(decoding: JSONEncoder().encode(recoveryContext), as: UTF8.self)
        let attemptCounter = AttemptCounter()
        let persisted = DownloadTask(
            id: "startup-refresher-fails",
            mediaId: "tt-startup-refresher-fails",
            streamURL: "https://cdn.example.com/stale.mkv?token=stale",
            fileName: "startup-refresher-fails.mkv",
            status: .queued,
            recoveryContextJSON: recoveryContextJSON,
            expectedBytes: 256
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                _ = await attemptCounter.next()
                throw StartupRefresherError.expired
            },
            linkRefresher: { _ in
                throw StartupRefresherError.expired
            }
        )

        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        let attempts = await attemptCounter.snapshot()

        #expect(attempts == 0)
        #expect(failed.errorMessage != nil)
        _ = manager
    }

    @Test func startupQueuedTaskWithoutTransportStateFailsWithoutInvokingPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-no-transport.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let performer = AttemptCounter()

        let persisted = DownloadTask(
            id: "startup-no-transport",
            mediaId: "tt-startup-no-transport",
            fileName: "startup-no-transport.mkv",
            status: .queued
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await performer.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x22, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-no-transport.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            }
        )

        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        #expect(failed.errorMessage != nil)
        #expect(await performer.snapshot() == 0)
        _ = manager
    }

    @Test func startupResolvingTaskWithoutTransportStateFailsWithoutInvokingPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resolving-no-transport.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let performer = AttemptCounter()

        let persisted = DownloadTask(
            id: "startup-resolving-no-transport",
            mediaId: "tt-startup-resolving-no-transport",
            fileName: "startup-resolving-no-transport.mkv",
            status: .resolving
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await performer.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x30, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-resolving-no-transport.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            }
        )

        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        #expect(failed.errorMessage != nil)
        #expect(await performer.snapshot() == 0)
        _ = manager
    }

    @Test func startupDownloadingTaskWithoutTransportStateFailsWithoutInvokingPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-downloading-no-transport.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()

        let persisted = DownloadTask(
            id: "startup-downloading-no-transport",
            mediaId: "tt-startup-downloading-no-transport",
            fileName: "startup-downloading-no-transport.mkv",
            status: .downloading
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x23, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-downloading-no-transport.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            }
        )

        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        #expect(failed.errorMessage != nil)
        #expect(await attemptCounter.snapshot() == 0)
        _ = manager
    }

    @Test func startupQueuedTaskWithInvalidHostFailsAsBadURLWithoutPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-invalid-host.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x3A, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/invalid-host.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            }
        )

        let persisted = DownloadTask(
            id: "startup-invalid-host",
            mediaId: "tt-startup-invalid-host",
            streamURL: "https:///invalid-host",
            fileName: "startup-invalid-host.mkv",
            status: .queued
        )
        try await database.saveDownloadTask(persisted)

        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        #expect(failed.errorMessage != nil)
        #expect(await attemptCounter.snapshot() == 0)
        _ = manager
    }

    @Test func startupRecoveryBackedQueuedTaskWithoutRefresherAndWithoutTransportStateFailsWithoutInvokingPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-recovery-no-refresher.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let performer = AttemptCounter()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await performer.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x31, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-recovery-no-refresher.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            }
        )

        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "feedbeeffeedbeeffeedbeeffeedbeeffeedbeef",
                preferredService: .realDebrid
            )
        )
        let persisted = DownloadTask(
            id: "startup-recovery-no-refresher",
            mediaId: "tt-startup-recovery-no-refresher",
            fileName: "startup-recovery-no-refresher.mkv",
            status: .queued,
            recoveryContextJSON: try recoveryContext.jsonString()
        )
        try await database.saveDownloadTask(persisted)

        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        #expect(failed.errorMessage != nil)
        #expect(await performer.snapshot() == 0)
        _ = manager
    }

    @Test func startupRecoveryBackedQueuedTaskRefreshesAfterCannotFindHostError() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-cannot-find-host.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let refreshCounter = AttemptCounter()
        let requestRecorder = TransferRequestRecorder()

        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "11112222333344445555666677778888999900001111",
                preferredService: .realDebrid
            )
        )
        let staleURL = "https://cdn.example.com/cannot-find-host.mkv"
        let freshURL = URL(string: "https://cdn.example.com/fresh-host.mkv")!

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await requestRecorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw URLError(.cannotFindHost)
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x79, count: 256)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: freshURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let persisted = DownloadTask(
            id: "startup-cannot-find-host",
            mediaId: "tt-startup-cannot-find-host",
            streamURL: staleURL,
            fileName: "startup-cannot-find-host.mkv",
            status: .queued,
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 256
        )
        try await database.saveDownloadTask(persisted)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in
                _ = await refreshCounter.next()
                return freshURL
            }
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        let requests = await requestRecorder.snapshot()
        let refreshes = await refreshCounter.snapshot()

        #expect(completed.status == DownloadStatus.completed)
        #expect(completed.persistedStreamURL == nil)
        #expect(refreshes == 2)
        #expect(requests == [
            .init(usedResumeData: false, url: freshURL.absoluteString),
            .init(usedResumeData: false, url: freshURL.absoluteString),
        ])
    }

    @Test func retryDownloadForMissingTaskIsNoOp() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-missing-task.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 10)
        )

        try await manager.retryDownload(id: "missing-task-id")
    }

    @Test func retryDownloadWithServerErrorDoesNotCallRefresher() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-server-error-no-refresh.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let refreshCounter = AttemptCounter()
        let staleURL = "https://cdn.example.com/non-recovery-non-expired-error.mkv?token=stale"

        let persisted = DownloadTask(
            id: "retry-server-error-no-refresh",
            mediaId: "tt-retry-server-error",
            streamURL: staleURL,
            fileName: "retry-recovery-server-error.mkv",
            status: .failed
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await requestRecorder.record(request: request)
                _ = await attemptCounter.next()
                throw DownloadTransferError.badHTTPStatus(500)
            },
            linkRefresher: { _ in
                _ = await refreshCounter.next()
                return URL(string: "https://cdn.example.com/retry-refresh-on-server-error.mkv")!
            },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        let requests = await requestRecorder.snapshot()

        #expect(requests == [.init(usedResumeData: false, url: staleURL, requestHeaders: nil)])
        #expect(await attemptCounter.snapshot() == 1)
        #expect(await refreshCounter.snapshot() == 0)
        #expect(failed.errorMessage != nil)
        #expect(failed.status == .failed)
    }

    @Test func genericTransferErrorDoesNotTriggerAdditionalLinkRefresh() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-generic-error-no-refresh.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let refreshCounter = AttemptCounter()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "retry-generic-error-no-refresh-11111111111111111111111111111111",
                preferredService: .realDebrid
            )
        )

        let persisted = DownloadTask(
            id: "retry-generic-error-no-refresh",
            mediaId: "tt-retry-generic-error",
            streamURL: "https://cdn.example.com/retry-generic-error.mkv",
            fileName: "retry-generic-error.mkv",
            status: .failed,
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 256
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                _ = await attemptCounter.next()
                throw NSError(domain: "com.vpstudio.unit-test", code: 1001, userInfo: nil)
            },
            linkRefresher: { _ in
                _ = await refreshCounter.next()
                return URL(string: "https://cdn.example.com/retry-generic-fresh.mkv")!
            },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)

        #expect(failed.errorMessage != nil)
        #expect(await attemptCounter.snapshot() == 1)
        #expect(await refreshCounter.snapshot() == 1)
    }

    @Test func retryWithPersistedResumeDataCanFailEarlyOnInsufficientDiskSpace() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-resume-insufficient-space.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let resumeData = Data("resume-insufficient-space".utf8)

        let persisted = DownloadTask(
            id: "retry-resume-insufficient-space",
            mediaId: "tt-retry-resume-insufficient-space",
            streamURL: "https://cdn.example.com/large-file.mkv",
            fileName: "retry-resume-insufficient-space.mkv",
            status: .failed,
            bytesWritten: 800,
            expectedBytes: 1_000,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x71, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/large-file.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 100 }
        )

        try await manager.retryDownload(id: persisted.id)
        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)

        #expect(failed.errorMessage != nil)
        #expect(failed.errorMessage?.contains("Not enough free space to start this download.") == true)
        #expect(await attemptCounter.snapshot() == 0)
    }

    @Test func startupQueuedTasksWithEqualCreatedAtSortById() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-createdat-order.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = BlockingDownloadGate()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

        let first = DownloadTask(
            id: "alpha-task",
            mediaId: "tt-startup-equal-createdat",
            streamURL: "https://cdn.example.com/alpha.mkv",
            fileName: "alpha.mkv",
            status: .queued,
            expectedBytes: 128,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let second = DownloadTask(
            id: "beta-task",
            mediaId: "tt-startup-equal-createdat",
            streamURL: "https://cdn.example.com/beta.mkv",
            fileName: "beta.mkv",
            status: .queued,
            expectedBytes: 128,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        try await database.saveDownloadTask(first)
        try await database.saveDownloadTask(second)

        let performer: DownloadManager.DownloadPerformer = { _, _, _ in
            await gate.wait()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x01, count: 128)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/ordered.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        defer {
            Task {
                await gate.resume()
                await gate.resume()
            }
        }

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            maxConcurrentTransfers: 1,
            resumePersistedDownloadsOnInit: true
        )

        _ = try await waitForStatus(database: database, id: first.id, expected: .downloading)
        let queued = try #require(await database.fetchDownloadTask(id: second.id))
        #expect(queued.status == .queued)

        await gate.resume()

        _ = try await waitForStatus(database: database, id: first.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: second.id, expected: .downloading)
        await gate.resume()

        _ = try await waitForStatus(database: database, id: second.id, expected: .completed)
    }

    @Test func retryDownloadFailsWhenDiskSpaceProviderThrowsDuringRetry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-disk-space-provider-throw.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()

        let persisted = DownloadTask(
            id: "retry-disk-space-provider-throw",
            mediaId: "tt-retry-disk-space-provider",
            streamURL: "https://cdn.example.com/retry-space-provider.mkv",
            fileName: "retry-space-provider.mkv",
            status: .failed,
            expectedBytes: 1_000
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x11, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/retry-space-provider.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: { _ in throw DiskProbeError.unavailable },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        #expect(await attemptCounter.snapshot() == 0)
        #expect(failed.errorMessage != nil)
    }

    @Test func startupRecoveryBackedQueuedTaskWithInvalidHostFailsWithoutRefresherOrPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-recovery-invalid-host-no-refresher.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()

        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "startup-recovery-invalid-host-99999999999999999999999999999999999999",
                preferredService: .realDebrid
            )
        )
        let persisted = DownloadTask(
            id: "startup-recovery-invalid-host",
            mediaId: "tt-startup-recovery-invalid-host",
            streamURL: "https:///invalid-host",
            fileName: "startup-recovery-invalid-host.mkv",
            status: .queued,
            recoveryContextJSON: try recoveryContext.jsonString()
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0xAA, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-recovery-invalid-host.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            resumePersistedDownloadsOnInit: true
        )

        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)

        #expect(failed.errorMessage != nil)
        #expect(await attemptCounter.snapshot() == 0)
        _ = manager
    }

    @Test func retryRecoveryBackedTaskWithHeadersRetainsHeadersAcrossRetryWhenNoRefresher() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-recovery-headers.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "retry-recovery-headers-11111111111111111111111111111111111111",
                preferredService: .realDebrid,
                seasonNumber: 1,
                episodeNumber: 1
            )
        )
        let expectedHeaders = [
            "User-Agent": "Stremio",
            "Referer": "https://app.strem.io/"
        ]
        let stream = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/retry-recovery-headered.mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "retry-recovery-headered.mkv",
            sizeBytes: 256,
            debridService: DebridServiceType.realDebrid.rawValue,
            recoveryContext: recoveryContext,
            requestHeaders: expectedHeaders
        )
        let attemptCounter = AttemptCounter()

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await requestRecorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadManagerTestError.timeout
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x64, count: 256)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: request.url ?? stream.streamURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            resumePersistedDownloadsOnInit: false
        )

        let task = try await manager.enqueueDownload(stream: stream, mediaId: "tt-retry-recovery-headered", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .failed)

        try await manager.retryDownload(id: task.id)

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let requests = await requestRecorder.snapshot()

        #expect(completed.status == DownloadStatus.completed)
        #expect(requests == [
            .init(usedResumeData: false, url: stream.streamURL.absoluteString, requestHeaders: expectedHeaders),
            .init(usedResumeData: false, url: stream.streamURL.absoluteString, requestHeaders: expectedHeaders),
        ])
        #expect(await attemptCounter.snapshot() == 2)
    }

    @Test func retryRecoveryBackedDownloadRefreshesAtMostOnceInSingleAttempt() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-refresh-once-per-attempt.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let refreshCounter = AttemptCounter()
        let requestCounter = AttemptCounter()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "refresh-once-test-1111111111111111111111111111111111111111",
                preferredService: .realDebrid
            )
        )
        let staleURL = "https://cdn.example.com/retry-refresh-stale.mkv?token=stale"
        let freshURL = URL(string: "https://cdn.example.com/retry-refresh-fresh.mkv?token=fresh")!

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            _ = await requestCounter.next()
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw URLError(.cannotConnectToHost)
            }
            throw URLError(.networkConnectionLost)
        }

        let persisted = DownloadTask(
            id: "retry-refresh-once",
            mediaId: "tt-retry-refresh-once",
            streamURL: staleURL,
            fileName: "retry-refresh-once.mkv",
            status: .failed,
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 256
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in
                _ = await refreshCounter.next()
                return freshURL
            },
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        let requests = await recorder.snapshot()

        #expect(requests.count == 2)
        #expect(requests == [
            .init(usedResumeData: false, url: freshURL.absoluteString, requestHeaders: nil),
            .init(usedResumeData: false, url: freshURL.absoluteString, requestHeaders: nil),
        ])
        #expect(await attemptCounter.snapshot() == 2)
        #expect(await refreshCounter.snapshot() == 2)
        #expect(await requestCounter.snapshot() == 2)
        #expect(failed.errorMessage != nil)
    }

    @Test func retryRecoveryBackedTaskWithoutRefresherCachesTransportStateAcrossRetries() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-recovery-no-refresher-cache.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let recoveryContext = StreamRecoveryContext(
            infoHash: "recovery-cache-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            preferredService: .realDebrid
        )!
        let originalURL = "https://cdn.example.com/retry-cache-original.mkv"
        let mutatedURL = "https://cdn.example.com/retry-cache-mutated.mkv"

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await requestRecorder.record(request: request)
            let attempt = await attemptCounter.next()

            if let requestURL = request.url?.absoluteString,
               requestURL == mutatedURL {
                throw DownloadManagerTestError.timeout
            }

            if attempt == 1 {
                throw DownloadManagerTestError.timeout
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x6E, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: originalURL)!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        var persisted = DownloadTask(
            id: "retry-recovery-no-refresher-cache",
            mediaId: "tt-retry-recovery-no-refresher-cache",
            streamURL: originalURL,
            fileName: "retry-cache.mkv",
            status: .failed,
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 512
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        _ = try await waitForStatus(database: database, id: persisted.id, expected: .failed)

        persisted.streamURL = mutatedURL
        try await database.saveDownloadTask(persisted)

        try await manager.retryDownload(id: persisted.id)
        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        let requests = await requestRecorder.snapshot()

        #expect(completed.status == DownloadStatus.completed)
        #expect(await attemptCounter.snapshot() == 2)
        #expect(requests.compactMap(\.url) == [originalURL, originalURL])
    }

    @Test func retryRecoveryBackedTaskWithRefresherDoesNotCacheTransportStateAcrossRetries() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-recovery-refresher-no-cache.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let refreshCounter = AttemptCounter()
        let recoveryContext = StreamRecoveryContext(
            infoHash: "recovery-no-cache-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            preferredService: .realDebrid
        )!
        let originalURL = "https://cdn.example.com/retry-nocache-original.mkv"
        let mutatedURL = "https://cdn.example.com/retry-nocache-mutated.mkv"

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await requestRecorder.record(request: request)
            _ = await attemptCounter.next()

            throw DownloadManagerTestError.timeout
        }

        var persisted = DownloadTask(
            id: "retry-recovery-refresher-nocache",
            mediaId: "tt-retry-recovery-refresher-nocache",
            streamURL: originalURL,
            fileName: "retry-nocache.mkv",
            status: .failed,
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 256
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in
                let attempt = await refreshCounter.next()
                return URL(string: attempt == 1 ? originalURL : mutatedURL)!
            },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        _ = try await waitForStatus(database: database, id: persisted.id, expected: .failed)

        persisted.streamURL = mutatedURL
        try await database.saveDownloadTask(persisted)

        try await manager.retryDownload(id: persisted.id)
        let secondAttemptFailed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        let requests = await requestRecorder.snapshot()

        #expect(secondAttemptFailed.status == DownloadStatus.failed)
        #expect(await attemptCounter.snapshot() == 2)
        #expect(await refreshCounter.snapshot() == 2)
        #expect(requests.compactMap(\.url) == [originalURL, mutatedURL])
    }

    @Test func retryDirectDownloadUsesMutatedPersistedURLWhenNoCachedReplayStateExists() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-direct-mutate-persisted-url.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let originalURL = "https://cdn.example.com/direct-retry-original.mkv"
        let mutatedURL = "https://cdn.example.com/direct-retry-mutated.mkv"

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await requestRecorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadManagerTestError.timeout
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x8C, count: 1_024)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: request.url ?? URL(string: originalURL)!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            resumePersistedDownloadsOnInit: false
        )

        let task = try await manager.enqueueDownload(
            stream: StreamInfo(
                streamURL: URL(string: originalURL)!,
                quality: .hd1080p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: "direct-retry-mutate.mkv",
                sizeBytes: 1_024,
                debridService: DebridServiceType.realDebrid.rawValue
            ),
            mediaId: "tt-retry-direct-mutate",
            episodeId: nil
        )

        _ = try await waitForStatus(database: database, id: task.id, expected: .failed)

        var failed = try await database.fetchDownloadTask(id: task.id)
        #expect(failed != nil)
        failed?.streamURL = mutatedURL
        if let updated = failed {
            try await database.saveDownloadTask(updated)
        }

        try await manager.retryDownload(id: task.id)
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let requests = await requestRecorder.snapshot()

        #expect(completed.status == DownloadStatus.completed)
        #expect(requests == [
            .init(usedResumeData: false, url: originalURL),
            .init(usedResumeData: false, url: mutatedURL),
        ])
        #expect(await attemptCounter.snapshot() == 2)
    }

    @Test func retryHeaderedDirectDownloadUsesMutatedPersistedURLFromDatabase() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-direct-headers-mutate-persisted-url.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let originalURL = "https://cdn.example.com/direct-retry-headered-original.mkv"
        let mutatedURL = "https://cdn.example.com/direct-retry-headered-mutated.mkv"

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await requestRecorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadManagerTestError.timeout
            }

            guard let requestURL = request.url, requestURL.absoluteString == mutatedURL else {
                throw DownloadManagerTestError.timeout
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x8D, count: 1_024)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: request.url!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            resumePersistedDownloadsOnInit: false
        )

        let task = try await manager.enqueueDownload(
            stream: StreamInfo(
                streamURL: URL(string: originalURL)!,
                quality: .hd1080p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: "direct-retry-headered.mkv",
                sizeBytes: 1_024,
                debridService: DebridServiceType.realDebrid.rawValue,
                requestHeaders: [
                    "User-Agent": "VPStudio",
                    "Referer": "https://app.example.com/"
                ]
            ),
            mediaId: "tt-retry-direct-headers-mutate",
            episodeId: nil
        )

        _ = try await waitForStatus(database: database, id: task.id, expected: .failed)

        var failedTask = try #require(await database.fetchDownloadTask(id: task.id))
        failedTask.streamURL = mutatedURL
        try await database.saveDownloadTask(failedTask)

        try await manager.retryDownload(id: task.id)

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let requests = await requestRecorder.snapshot()
        let expectedHeaders = [
            "User-Agent": "VPStudio",
            "Referer": "https://app.example.com/"
        ]

        #expect(completed.status == DownloadStatus.completed)
        #expect(requests == [
            .init(usedResumeData: false, url: originalURL, requestHeaders: expectedHeaders),
            .init(usedResumeData: false, url: mutatedURL, requestHeaders: expectedHeaders),
        ])
        #expect(await attemptCounter.snapshot() == 2)
    }

    @Test func retryDownloadWithoutTransportStateFailsWithoutInvokingPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-no-transport-state.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()

        let persisted = DownloadTask(
            id: "retry-no-transport-state",
            mediaId: "tt-retry-no-transport-state",
            fileName: "retry-no-transport-state.mkv",
            status: .failed,
            mediaTitle: "Retry no transport",
            mediaType: "movie"
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x55, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/no-transport-retry.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)

        #expect(failed.errorMessage != nil)
        #expect(await attemptCounter.snapshot() == 0)
    }

    @Test func retryRecoveryBackedTaskWithoutPersistedStreamUsesRefresher() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-recovery-no-stream.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let refreshCounter = AttemptCounter()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "recovery-no-stream-retry-2222222222222222222222222222222222222222",
                preferredService: .realDebrid
            )
        )
        let freshURL = URL(string: "https://cdn.example.com/retry-recovery-refreshed.mkv")!

        let persisted = DownloadTask(
            id: "retry-recovery-no-stream",
            mediaId: "tt-retry-recovery-no-stream",
            fileName: "retry-recovery-no-stream.mkv",
            status: .failed,
            mediaTitle: "Retry Recovery No Stream",
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 512
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await requestRecorder.record(request: request)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x66, count: 512)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: freshURL,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            linkRefresher: { _ in
                _ = await refreshCounter.next()
                return freshURL
            },
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        let requests = await requestRecorder.snapshot()

        #expect(completed.persistedStreamURL == nil)
        #expect(completed.resumeData == nil)
        #expect(requests == [.init(usedResumeData: false, url: freshURL.absoluteString, requestHeaders: nil)])
        #expect(await refreshCounter.snapshot() == 1)
    }

    @Test func retryRecoveryBackedTaskWithoutTransportAndRefresherErrorSkipsPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-recovery-refresher-fail.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "retry-refresher-fail-3333333333333333333333333333333333333333",
                preferredService: .realDebrid
            )
        )

        let persisted = DownloadTask(
            id: "retry-recovery-refresher-fail",
            mediaId: "tt-retry-recovery-refresher-fail",
            fileName: "retry-recovery-refresher-fail.mkv",
            status: .failed,
            mediaTitle: "Retry Recovery Refresher Fail",
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 256
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x77, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/retry-refresher-fail.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            linkRefresher: { _ in
                throw URLError(.timedOut)
            },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)

        #expect(failed.errorMessage != nil)
        #expect(await attemptCounter.snapshot() == 0)
    }

    @Test func retryRecoveryBackedTaskWithInvalidHostRefreshesUsingRefresher() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-recovery-invalid-host-refresher.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let refreshCounter = AttemptCounter()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "retry-recovery-invalid-host-refresher-11111111111111111111111111111111",
                preferredService: .realDebrid
            )
        )
        let freshURL = URL(string: "https://cdn.example.com/retry-recovery-invalid-host-fresh.mkv")!

        let persisted = DownloadTask(
            id: "retry-recovery-invalid-host-refresher",
            mediaId: "tt-retry-recovery-invalid-host-refresher",
            streamURL: "https://",
            fileName: "retry-recovery-invalid-host.mkv",
            status: .failed,
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 256
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await requestRecorder.record(request: request)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x55, count: 256)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: freshURL,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            linkRefresher: { _ in
                _ = await refreshCounter.next()
                return freshURL
            },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        let requests = await requestRecorder.snapshot()

        #expect(completed.status == DownloadStatus.completed)
        #expect(requests == [.init(usedResumeData: false, url: freshURL.absoluteString, requestHeaders: nil)])
        #expect(await refreshCounter.snapshot() == 1)
    }

    @Test func retryRecoveryBackedTaskWithInvalidHostSkipsPerformerWithoutRefresher() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-recovery-invalid-host-no-refresher.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "retry-recovery-invalid-host-noref-11111111111111111111111111111111",
                preferredService: .realDebrid
            )
        )

        let persisted = DownloadTask(
            id: "retry-recovery-invalid-host-no-refresher",
            mediaId: "tt-retry-recovery-invalid-host-no-refresher",
            streamURL: "https:///invalid-host",
            fileName: "retry-recovery-invalid-host-no-refresher.mkv",
            status: .failed,
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 128
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x66, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/retry-recovery-invalid-host-no-refresher.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)
        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)

        #expect(failed.errorMessage != nil)
        #expect(await attemptCounter.snapshot() == 0)
    }

    @Test func pathLikeFileNameIsSanitizedIntoSinglePathForDownloadDestination() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-filename-path-sanitization.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 128)
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "../weird/:name*?.mkv"),
            mediaId: "tt-filename-sanitized",
            episodeId: nil
        )
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let fileName = completed.fileName
        let destination = try #require(completed.destinationURL)

        #expect(!fileName.contains("/"))
        #expect(!fileName.contains("\\"))
        #expect(!fileName.contains(":"))
        #expect(!fileName.contains("*"))
        #expect(!fileName.contains("?"))
        #expect(fileName.hasSuffix(".mkv"))
        #expect(destination.deletingLastPathComponent().path == downloadsDir.path)
        #expect(FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func retryRecoveryBackedDownloadUsesCachedResumeDataWithoutRefresher() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-recovery-resume-cache.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let recoveredData = Data("checkpoint-data".utf8)
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "99998888777766665555444433332222111100000000",
                preferredService: .realDebrid,
                seasonNumber: 1,
                episodeNumber: 2
            )
        )
        let stream = makeStream(name: "retry-recovery-cache.mkv", recoveryContext: recoveryContext)

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            let attempt = await attemptCounter.next()
            await requestRecorder.record(request: request)

            if request.resumeData == nil {
                if attempt == 1 {
                    throw DownloadTransferError.resumeDataProduced(recoveredData)
                }
                throw DownloadManagerTestError.timeout
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x7D, count: 256)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: request.url ?? stream.streamURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer
        )

        let task = try await manager.enqueueDownload(stream: stream, mediaId: "tt-retry-recovery-cache", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .cancelled)

        try await manager.retryDownload(id: task.id)
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let requests = await requestRecorder.snapshot()

        #expect(completed.status == DownloadStatus.completed)
        #expect(requests.count == 2)
        #expect(requests == [
            .init(usedResumeData: false, url: stream.streamURL.absoluteString),
            .init(usedResumeData: true, url: stream.streamURL.absoluteString),
        ])
    }

    @Test func startupResumesResolvingTasksRespectingQueuedOrder() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resolving-order.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = MultiDownloadGate()
        let recorder = TransferRequestRecorder()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_500)

        let resolvingTask = DownloadTask(
            id: "resolve-order-a",
            mediaId: "tt-startup-order",
            streamURL: "https://cdn.example.com/startup-resolving.mkv",
            fileName: "startup-resolving.mkv",
            status: .resolving,
            expectedBytes: 128,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let queuedTask = DownloadTask(
            id: "resolve-order-b",
            mediaId: "tt-startup-order",
            streamURL: "https://cdn.example.com/startup-queued.mkv",
            fileName: "startup-queued.mkv",
            status: .queued,
            expectedBytes: 128,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        try await database.saveDownloadTask(queuedTask)
        try await database.saveDownloadTask(resolvingTask)

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            await gate.wait()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x44, count: 128)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: request.url ?? URL(string: "https://cdn.example.com/unknown.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            maxConcurrentTransfers: 1
        )

        _ = try await waitForStatus(database: database, id: resolvingTask.id, expected: .downloading)
        let queued = try #require(try await database.fetchDownloadTask(id: queuedTask.id))
        #expect(queued.status == .queued)

        await gate.resumeOne()
        _ = try await waitForStatus(database: database, id: queuedTask.id, expected: .downloading)
        await gate.resumeAll()

        _ = try await waitForStatus(database: database, id: resolvingTask.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: queuedTask.id, expected: .completed)

        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(
                usedResumeData: false,
                url: resolvingTask.streamURL,
                requestHeaders: nil
            ),
            .init(
                usedResumeData: false,
                url: queuedTask.streamURL,
                requestHeaders: nil
            )
        ])
    }

    @Test func inFlightDownloadWithCompletedDestinationRepairsOnStartup() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-repair.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let destinationURL = downloadsDir.appendingPathComponent("startup-repair.mkv")
        let bytes = Data(repeating: 0x2D, count: 512)
        try bytes.write(to: destinationURL)

        let attemptCounter = AttemptCounter()
        let task = DownloadTask(
            id: "startup-repair",
            mediaId: "tt-repair",
            streamURL: "https://cdn.example.com/startup-repair.mkv",
            fileName: "startup-repair.mkv",
            status: .downloading,
            progress: 0.99,
            bytesWritten: 512,
            totalBytes: 512,
            destinationPath: destinationURL.path,
            mediaTitle: "Startup Repair",
            mediaType: "movie"
        )
        try await database.saveDownloadTask(task)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                _ = await attemptCounter.next()
                throw DownloadManagerTestError.timeout
            }
        )

        let repaired = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let attempts = await attemptCounter.snapshot()
        #expect(attempts == 0)
        #expect(repaired.progress == 1.0)
        #expect(repaired.destinationURL?.path == destinationURL.path)
        #expect(repaired.resumeData == nil)
    }

    @Test func inFlightDownloadWithMismatchedDestinationSizeTriggersRedownload() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-repair-mismatch.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = BlockingDownloadGate()
        let requestCounter = AttemptCounter()
        let stalePath = downloadsDir.appendingPathComponent("startup-repair-mismatch.mkv")
        let staleBytes = Data(repeating: 0x11, count: 64)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        try staleBytes.write(to: stalePath)

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            _ = await requestCounter.next()
            await gate.wait()

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x77, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: request.url ?? URL(string: "https://cdn.example.com/fallback.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let persisted = DownloadTask(
            id: "startup-repair-mismatch",
            mediaId: "tt-startup-repair-mismatch",
            streamURL: "https://cdn.example.com/startup-repair-mismatch.mkv",
            fileName: "startup-repair-mismatch.mkv",
            status: .downloading,
            progress: 0.4,
            bytesWritten: Int64(staleBytes.count),
            totalBytes: 512,
            destinationPath: stalePath.path,
            mediaTitle: "Startup Repair Mismatch",
            mediaType: "movie",
            expectedBytes: 512
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer
        )
        defer {
            Task { await gate.resume() }
        }

        _ = try await waitForStatus(database: database, id: persisted.id, expected: .downloading, timeoutSeconds: 10)

        await gate.resume()
        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed, timeoutSeconds: 12)
        let finalURL = try #require(completed.destinationURL)

        #expect(await requestCounter.snapshot() == 1)
        #expect(finalURL.lastPathComponent.hasSuffix("(1).mkv"))
        #expect(finalURL.path != stalePath.path)
        #expect(FileManager.default.fileExists(atPath: stalePath.path))
        let staleContents = try Data(contentsOf: stalePath)
        #expect(!staleContents.isEmpty)
        withExtendedLifetime(manager) {}
    }

    @Test func startupResolvingTaskWithMismatchedDestinationSizeTriggersRedownload() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resolving-mismatch.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = BlockingDownloadGate()
        let requestCounter = AttemptCounter()
        let stalePath = downloadsDir.appendingPathComponent("startup-resolving-mismatch.mkv")
        let staleBytes = Data(repeating: 0x11, count: 64)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        try staleBytes.write(to: stalePath)

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            _ = await requestCounter.next()
            await gate.wait()

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x77, count: 512)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: request.url ?? URL(string: "https://cdn.example.com/fallback.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let persisted = DownloadTask(
            id: "startup-resolving-mismatch",
            mediaId: "tt-startup-resolving-mismatch",
            streamURL: "https://cdn.example.com/startup-resolving-mismatch.mkv",
            fileName: "startup-resolving-mismatch.mkv",
            status: .resolving,
            progress: 0.4,
            bytesWritten: Int64(staleBytes.count),
            totalBytes: nil,
            destinationPath: stalePath.path,
            mediaTitle: "Startup Resolving Repair Mismatch",
            mediaType: "movie",
            expectedBytes: 512
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer
        )
        defer {
            Task { await gate.resume() }
        }

        _ = try await waitForStatus(database: database, id: persisted.id, expected: .downloading, timeoutSeconds: 10)
        #expect(await requestCounter.snapshot() == 1)

        await gate.resume()
        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed, timeoutSeconds: 12)
        let finalURL = try #require(completed.destinationURL)

        #expect(await requestCounter.snapshot() == 1)
        #expect(finalURL.path != stalePath.path)
        #expect(finalURL.lastPathComponent.hasSuffix("(1).mkv"))
        withExtendedLifetime(manager) {}
    }

    @Test func inFlightDownloadWithDestinationAndNoExpectedSizeRepairsOnStartup() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-missing-size-repair.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let destinationURL = downloadsDir.appendingPathComponent("startup-repair-missing-size.mkv")
        let bytes = Data(repeating: 0x21, count: 384)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        try bytes.write(to: destinationURL)

        let persisted = DownloadTask(
            id: "startup-repair-missing-size",
            mediaId: "tt-startup-repair-missing-size",
            fileName: "startup-repair-missing-size.mkv",
            status: .downloading,
            progress: 0.45,
            bytesWritten: 128,
            totalBytes: nil,
            destinationPath: destinationURL.path,
            mediaTitle: "Startup Repair Missing Size",
            mediaType: "movie"
        )
        try await database.saveDownloadTask(persisted)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                _ = await attemptCounter.next()
                return (URL(fileURLWithPath: "/tmp/unused.bin"), URLResponse())
            }
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        #expect(completed.progress == 1.0)
        #expect(completed.bytesWritten == Int64(bytes.count))
        #expect(completed.totalBytes == Int64(bytes.count))
        #expect(completed.destinationPath == destinationURL.path)
        #expect(await attemptCounter.snapshot() == 0)
    }

    @Test func startupResolvingTaskWithDestinationAndNoExpectedSizeRepairsOnStartup() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resolving-repair-metadata-lost.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let destinationURL = downloadsDir.appendingPathComponent("startup-resolving-repair-missing-size.mkv")
        let bytes = Data(repeating: 0x22, count: 256)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        try bytes.write(to: destinationURL)

        let persisted = DownloadTask(
            id: "startup-resolving-repair-missing-size",
            mediaId: "tt-startup-resolving-repair-missing-size",
            fileName: "startup-resolving-repair-missing-size.mkv",
            status: .resolving,
            bytesWritten: 64,
            totalBytes: nil,
            destinationPath: destinationURL.path,
            mediaTitle: "Startup Resolving Repair Missing Size",
            mediaType: "movie"
        )
        try await database.saveDownloadTask(persisted)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                _ = await attemptCounter.next()
                return (URL(fileURLWithPath: "/tmp/unused.bin"), URLResponse())
            }
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        #expect(completed.progress == 1.0)
        #expect(completed.bytesWritten == Int64(bytes.count))
        #expect(completed.totalBytes == Int64(bytes.count))
        #expect(completed.destinationPath == destinationURL.path)
        #expect(await attemptCounter.snapshot() == 0)
    }

    @Test func queuedDownloadsWithSameCreatedAtStartInLexicographicIDOrder() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-queue-order-tie.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let requestRecorder = TransferRequestRecorder()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_500)
        let baseURL = URL(string: "https://cdn.example.com/queue-order-")!

        try await database.saveDownloadTask(
            DownloadTask(
                id: "queue-order-c",
                mediaId: "tt-queue-order",
                streamURL: "\(baseURL)C.mkv",
                fileName: "queue-order-c.mkv",
                status: .queued,
                expectedBytes: 64,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        )
        try await database.saveDownloadTask(
            DownloadTask(
                id: "queue-order-a",
                mediaId: "tt-queue-order",
                streamURL: "\(baseURL)A.mkv",
                fileName: "queue-order-a.mkv",
                status: .queued,
                expectedBytes: 64,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        )
        try await database.saveDownloadTask(
            DownloadTask(
                id: "queue-order-b",
                mediaId: "tt-queue-order",
                streamURL: "\(baseURL)B.mkv",
                fileName: "queue-order-b.mkv",
                status: .queued,
                expectedBytes: 64,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        )

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await requestRecorder.record(request: request)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x7F, count: 64)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/fallback.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1
        )

        _ = try await waitForStatus(database: database, id: "queue-order-a", expected: .completed, timeoutSeconds: 12)
        _ = try await waitForStatus(database: database, id: "queue-order-b", expected: .completed, timeoutSeconds: 12)
        _ = try await waitForStatus(database: database, id: "queue-order-c", expected: .completed, timeoutSeconds: 12)

        let requests = await requestRecorder.snapshot()
        #expect(requests.count == 3)
        #expect(requests == [
            .init(usedResumeData: false, url: "\(baseURL)A.mkv"),
            .init(usedResumeData: false, url: "\(baseURL)B.mkv"),
            .init(usedResumeData: false, url: "\(baseURL)C.mkv"),
        ])

        withExtendedLifetime(manager) {}
    }

    @Test func persistedInFlightDownloadResumesAfterManagerRecreate() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-resume.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let recoveryContext = StreamRecoveryContext(
            infoHash: "abcdefabcdefabcdefabcdefabcdefabcdefabcd",
            preferredService: .realDebrid,
            seasonNumber: 3,
            episodeNumber: 7
        )!
        let persisted = DownloadTask(
            mediaId: "tt150",
            episodeId: "tmdb-123-s3e7",
            streamURL: "https://cdn.example.com/resume.mkv",
            fileName: "resume.mkv",
            status: .downloading,
            progress: 0.42,
            bytesWritten: 420,
            totalBytes: 1_000,
            destinationPath: nil,
            errorMessage: "stale",
            mediaTitle: "Resume Test",
            mediaType: "series",
            seasonNumber: 3,
            episodeNumber: 7,
            episodeTitle: "Resume",
            recoveryContextJSON: try recoveryContext.jsonString()
        )
        try await database.saveDownloadTask(persisted)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 1_024)
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        #expect(completed.status == DownloadStatus.completed)
        #expect(completed.progress == 1.0)
        #expect(completed.errorMessage == nil)
        #expect(completed.recoveryContext?.infoHash == recoveryContext.infoHash)
        #expect(completed.recoveryContext?.preferredService == recoveryContext.preferredService)
        #expect(completed.recoveryContext?.seasonNumber == recoveryContext.seasonNumber)
        #expect(completed.recoveryContext?.episodeNumber == recoveryContext.episodeNumber)
    }

    @Test func expiredLinkRecoveryClearsStaleResumeDataAndReusesFreshURL() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-expired-link-retry.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let staleURL = "https://cdn.example.com/stale-link.mkv?token=expired"
        let freshURL = URL(string: "https://cdn.example.com/fresh-link.mkv?token=fresh")!
        let recoveryContext = StreamRecoveryContext(
            infoHash: "00112233445566778899aabbccddeeff00112233",
            preferredService: .realDebrid
        )!

        let persisted = DownloadTask(
            id: "expired-link-retry",
            mediaId: "tt-expired-link",
            streamURL: staleURL,
            fileName: "expired-link.mkv",
            status: .failed,
            progress: 0.4,
            bytesWritten: 400,
            totalBytes: 1_000,
            mediaTitle: "Expired Link",
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 1_000,
            resumeDataBase64: Data("stale-resume-data".utf8).base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            switch attempt {
            case 1:
                throw DownloadTransferError.badHTTPStatus(403)
            case 2:
                throw DownloadManagerTestError.timeout
            default:
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x4F, count: 1_000)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: freshURL,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            }
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in freshURL }
        )

        try await manager.retryDownload(id: persisted.id)

        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        #expect(failed.resumeData == nil)
        #expect(failed.persistedStreamURL == nil)

        try await manager.retryDownload(id: persisted.id)
        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        #expect(completed.resumeData == nil)

        let requests = await recorder.snapshot()
        #expect(requests.count == 3)
        #expect(requests[0] == .init(usedResumeData: false, url: freshURL.absoluteString))
        #expect(requests[1] == .init(usedResumeData: false, url: freshURL.absoluteString))
        #expect(requests[2] == .init(usedResumeData: false, url: freshURL.absoluteString))
    }

    @Test func refreshedRecoveryDownloadCompletesAfterExpiredHTTPStatus() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-refresh-http-success.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let freshURL = URL(string: "https://cdn.example.com/fresh-http-success.mkv?token=fresh")!
        let recoveryContext = StreamRecoveryContext(
            infoHash: "abcdefabcdefabcdefabcdefabcdefabcdef1234",
            preferredService: .realDebrid
        )!

        let persisted = DownloadTask(
            id: "refresh-http-success",
            mediaId: "tt-refresh-http-success",
            streamURL: "https://cdn.example.com/stale-http-success.mkv?token=stale",
            fileName: "refresh-http-success.mkv",
            status: .failed,
            progress: 0.5,
            bytesWritten: 500,
            totalBytes: 1_000,
            mediaTitle: "Refresh HTTP Success",
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 1_000,
            resumeDataBase64: Data("stale-resume".utf8).base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadTransferError.badHTTPStatus(451)
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x52, count: 1_000)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: freshURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in freshURL },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        #expect(completed.persistedStreamURL == nil)
        #expect(completed.resumeData == nil)
        #expect(completed.destinationURL != nil)
        if let destination = completed.destinationURL {
            #expect(FileManager.default.fileExists(atPath: destination.path))
        }

        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: freshURL.absoluteString),
            .init(usedResumeData: false, url: freshURL.absoluteString),
        ])
    }

    @Test func refreshedRecoveryDownloadCompletesAfterURLTimeout() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-refresh-timeout-success.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let freshURL = URL(string: "https://cdn.example.com/fresh-timeout-success.mkv?token=fresh")!
        let recoveryContext = StreamRecoveryContext(
            infoHash: "1234abcdef1234abcdef1234abcdef1234abcdef",
            preferredService: .realDebrid
        )!

        let persisted = DownloadTask(
            id: "refresh-timeout-success",
            mediaId: "tt-refresh-timeout-success",
            streamURL: "https://cdn.example.com/stale-timeout-success.mkv?token=stale",
            fileName: "refresh-timeout-success.mkv",
            status: .failed,
            progress: 0.25,
            bytesWritten: 250,
            totalBytes: 1_000,
            mediaTitle: "Refresh Timeout Success",
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 1_000,
            resumeDataBase64: Data("stale-resume".utf8).base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw URLError(.timedOut)
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x54, count: 1_000)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: freshURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in freshURL },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        #expect(completed.persistedStreamURL == nil)
        #expect(completed.resumeData == nil)
        #expect(completed.bytesWritten == 1_000)

        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: freshURL.absoluteString),
            .init(usedResumeData: false, url: freshURL.absoluteString),
        ])
    }

    @Test func cancellingRefreshedRecoveryDownloadDoesNotRestoreLegacyResumeData() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-refresh-cancel-redaction.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let freshURL = URL(string: "https://cdn.example.com/fresh-after-expiry.mkv?token=fresh")!
        let recoveryContext = StreamRecoveryContext(
            infoHash: "9988776655443322110099887766554433221100",
            preferredService: .realDebrid
        )!

        let persisted = DownloadTask(
            id: "refresh-cancel-redaction",
            mediaId: "tt-refresh-cancel",
            streamURL: "https://cdn.example.com/stale-before-refresh.mkv?token=stale",
            fileName: "refresh-cancel.mkv",
            status: .failed,
            progress: 0.4,
            bytesWritten: 400,
            totalBytes: 1_000,
            mediaTitle: "Refresh Cancel",
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 1_000,
            resumeDataBase64: Data("legacy-resume-data".utf8).base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        let performer: DownloadManager.DownloadPerformer = { request, _, cancellationController in
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadTransferError.badHTTPStatus(403)
            }

            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                cancellationController.register {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in freshURL }
        )

        try await manager.retryDownload(id: persisted.id)
        _ = try await waitForStatus(database: database, id: persisted.id, expected: .downloading)

        await manager.cancelDownload(id: persisted.id)

        let cancelled = try await waitForStatus(database: database, id: persisted.id, expected: .cancelled)
        #expect(cancelled.persistedStreamURL == nil)
        #expect(cancelled.resumeData == nil)

        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: freshURL.absoluteString),
            .init(usedResumeData: false, url: freshURL.absoluteString),
        ])
    }

    @Test func cancellingRecoveryDownloadAfterURLTimeoutRefreshKeepsStateRedacted() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-refresh-timeout-cancel-redaction.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let refreshCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let freshURL = URL(string: "https://cdn.example.com/fresh-timeout-cancel.mkv?token=fresh")!
        let recoveryContext = StreamRecoveryContext(
            infoHash: "7766554433221100998877665544332211009988",
            preferredService: .realDebrid
        )!

        let persisted = DownloadTask(
            id: "refresh-timeout-cancel-redaction",
            mediaId: "tt-refresh-timeout-cancel",
            streamURL: "https://cdn.example.com/stale-timeout-cancel.mkv?token=stale",
            fileName: "refresh-timeout-cancel.mkv",
            status: .failed,
            progress: 0.4,
            bytesWritten: 400,
            totalBytes: 1_000,
            mediaTitle: "Refresh Timeout Cancel",
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 1_000
        )
        try await database.saveDownloadTask(persisted)

        let performer: DownloadManager.DownloadPerformer = { request, _, cancellationController in
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw URLError(.timedOut)
            }

            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                cancellationController.register {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in
                _ = await refreshCounter.next()
                return freshURL
            },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)

        var secondAttemptStarted = false
        for _ in 0..<200 {
            if await attemptCounter.snapshot() >= 2 {
                secondAttemptStarted = true
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        guard secondAttemptStarted else { throw DownloadManagerTestError.timeout }

        await manager.cancelDownload(id: persisted.id)

        let cancelled = try await waitForStatus(database: database, id: persisted.id, expected: .cancelled)
        #expect(cancelled.persistedStreamURL == nil)
        #expect(cancelled.resumeData == nil)

        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: freshURL.absoluteString),
            .init(usedResumeData: false, url: freshURL.absoluteString),
        ])
        #expect(await refreshCounter.snapshot() == 2)
    }

    @Test func refreshedRecoveryDownloadDropsResumeDataProducedDuringRetry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-refresh-resume-data-redaction.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let freshURL = URL(string: "https://cdn.example.com/fresh-resume-redacted.mkv?token=fresh")!
        let recoveryContext = StreamRecoveryContext(
            infoHash: "aabbccddeeff0011223344556677889900112233",
            preferredService: .realDebrid
        )!

        let persisted = DownloadTask(
            id: "refresh-resume-redaction",
            mediaId: "tt-refresh-resume",
            streamURL: "https://cdn.example.com/stale-before-resume.mkv?token=stale",
            fileName: "refresh-resume.mkv",
            status: .failed,
            progress: 0.4,
            bytesWritten: 400,
            totalBytes: 1_000,
            mediaTitle: "Refresh Resume",
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 1_000,
            resumeDataBase64: Data("legacy-resume-data".utf8).base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        let producedResumeData = Data("resume-from-refreshed-request".utf8)
        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                throw DownloadTransferError.badHTTPStatus(403)
            }
            throw DownloadTransferError.resumeDataProduced(producedResumeData)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in freshURL },
            resumePersistedDownloadsOnInit: false
        )

        try await manager.retryDownload(id: persisted.id)

        let cancelled = try await waitForStatus(database: database, id: persisted.id, expected: .cancelled)
        #expect(cancelled.persistedStreamURL == nil)
        #expect(cancelled.resumeData == nil)

        let requests = await recorder.snapshot()
        #expect(requests == [
            .init(usedResumeData: false, url: freshURL.absoluteString),
            .init(usedResumeData: false, url: freshURL.absoluteString),
        ])
    }

    @Test func recoveryBackedPersistedDownloadsIgnoreLegacyResumeDataOnStartup() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-legacy-recovery-redaction.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let freshURL = URL(string: "https://cdn.example.com/recovered.mkv?token=fresh")!
        let recoveryContext = StreamRecoveryContext(
            infoHash: "1111222233334444555566667777888899990000",
            preferredService: .realDebrid
        )!

        let persisted = DownloadTask(
            id: "legacy-recovery-download",
            mediaId: "tt-legacy",
            streamURL: "https://cdn.example.com/stale.mkv?token=stale",
            fileName: "legacy-recovery.mkv",
            status: .downloading,
            progress: 0.2,
            bytesWritten: 200,
            totalBytes: 1_000,
            mediaTitle: "Legacy Recovery",
            recoveryContextJSON: try recoveryContext.jsonString(),
            expectedBytes: 1_000,
            resumeDataBase64: Data("legacy-resume".utf8).base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x6B, count: 1_000)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: freshURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in freshURL }
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        #expect(completed.persistedStreamURL == nil)
        #expect(completed.resumeData == nil)

        let requests = await recorder.snapshot()
        #expect(requests == [.init(usedResumeData: false, url: freshURL.absoluteString)])
    }

    @Test func retryQueuedRecoveryDownloadKeepsHeadersWhenPersistedURLDiffersFromMemory() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-queued-recovery-mismatch.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let recorder = TransferRequestRecorder()
        let attemptCounter = AttemptCounter()
        let refreshCounter = AttemptCounter()
        let firstAttemptGate = BlockingDownloadGate()
        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let freshURL = URL(string: "https://cdn.example.com/fresh-queued-recovery.mkv?token=fresh")!
        let recoveryContext = StreamRecoveryContext(
            infoHash: "abcabcabcabcabcabcabcabcabcabcabcabcabc1",
            preferredService: .realDebrid
        )!
        let headers = ["Authorization": "Bearer original"]

        let performer: DownloadManager.DownloadPerformer = { request, _, _ in
            await recorder.record(request: request)
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                await firstAttemptGate.wait()
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x46, count: 64)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: request.url ?? freshURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            linkRefresher: { _ in
                _ = await refreshCounter.next()
                return freshURL
            },
            maxConcurrentTransfers: 1,
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let first = try await manager.enqueueDownload(
            stream: makeStream(name: "retry-queued-holder.mkv", sizeBytes: 64),
            mediaId: "tt-retry-queued-holder",
            episodeId: nil
        )

        var firstStarted = false
        for _ in 0..<200 {
            if await attemptCounter.snapshot() > 0 {
                firstStarted = true
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        guard firstStarted else { throw DownloadManagerTestError.timeout }

        let second = try await manager.enqueueDownload(
            stream: makeStream(
                name: "retry-queued-recovery.mkv",
                sizeBytes: 64,
                recoveryContext: recoveryContext
            ).withRequestHeaders(headers),
            mediaId: "tt-retry-queued-recovery",
            episodeId: nil
        )
        try await database.updateDownloadTaskStreamURL(
            id: second.id,
            streamURL: "https://cdn.example.com/stale-queued-recovery.mkv?token=stale"
        )

        try await manager.retryDownload(id: second.id)
        await firstAttemptGate.resume()

        _ = try await waitForStatus(database: database, id: first.id, expected: .completed)
        let completed = try await waitForStatus(database: database, id: second.id, expected: .completed, timeoutSeconds: 30)
        #expect(completed.persistedStreamURL == nil)
        #expect(completed.resumeData == nil)

        let requests = await recorder.snapshot()
        #expect(requests.count == 2)
        #expect(requests[1] == .init(
            usedResumeData: false,
            url: freshURL.absoluteString,
            requestHeaders: headers
        ))
        #expect(await refreshCounter.snapshot() == 1)
    }

    @Test func completedDownloadClearsPersistedStreamURL() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-redacts-completed-url.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 512),
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let task = try await manager.enqueueDownload(stream: makeStream(name: "redact-on-complete.mkv"), mediaId: "tt151", episodeId: nil)
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)

        #expect(completed.streamURL.isEmpty)
        #expect(completed.persistedStreamURL == nil)
    }

    @Test func removeDownloadDeletesCompletedFileFromFilesystem() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-completed-file.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 512)
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "completed-to-delete.mkv"),
            mediaId: "tt-remove-completed",
            episodeId: nil
        )
        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let destination = try #require(completed.destinationURL)
        #expect(FileManager.default.fileExists(atPath: destination.path))

        try await manager.removeDownload(id: completed.id)

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if try await database.fetchDownloadTask(id: completed.id) == nil {
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(try await database.fetchDownloadTask(id: completed.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func remoteCleanupNotInvokedForDirectDownloadRemoval() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-direct-no-cleanup.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let cleanupRecorder = RemoteCleanupRecorder()
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 256),
            remoteTransferCleaner: { context in
                await cleanupRecorder.record(context)
            }
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "remove-no-cleanup.mkv"),
            mediaId: "tt-remove-no-cleanup",
            episodeId: nil
        )
        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)
        try await manager.removeDownload(id: task.id)

        let cleaned = await cleanupRecorder.snapshot()
        #expect(cleaned.isEmpty)
    }

    @Test func removeDownloadForMissingTaskIsNoOp() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-missing-task.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 10)
        )

        let listed = try await manager.listDownloads()
        #expect(listed.isEmpty)

        try await manager.removeDownload(id: "missing-task-id")
        let after = try await manager.listDownloads()
        #expect(after.isEmpty)
    }

    @Test func removeDownloadsNoopWhenNoMediaIdMatch() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-downloads-no-match.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let _ = await attemptCounter.next()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x5C, count: 1)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/remove-downloads-no-match.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 2,
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let first = try await manager.enqueueDownload(
            stream: makeStream(name: "remove-no-match-1.mkv"),
            mediaId: "tt-keep-1",
            episodeId: nil
        )
        let second = try await manager.enqueueDownload(
            stream: makeStream(name: "remove-no-match-2.mkv"),
            mediaId: "tt-keep-2",
            episodeId: nil
        )

        _ = try await waitForStatus(database: database, id: first.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: second.id, expected: .completed)

        try await manager.removeDownloads(mediaId: "tt-does-not-exist")

        #expect(try await database.fetchDownloadTask(id: first.id) != nil)
        #expect(try await database.fetchDownloadTask(id: second.id) != nil)
        #expect(await attemptCounter.snapshot() == 2)
    }

    @Test func removeDownloadsReleasesRemoteCleanupForRecoveryBackedTasks() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-downloads-recovery-cleanup.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let cleanupRecorder = RemoteCleanupRecorder()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "a11ba11ba11ba11ba11ba11ba11ba11ba11ba11ba1",
                preferredService: .realDebrid,
                resolvedFileName: "unused"
            )
        )

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, cancellationController in
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                    cancellationController.register {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            },
            remoteTransferCleaner: { context in
                await cleanupRecorder.record(context)
            },
            maxConcurrentTransfers: 1
        )

        let first = try await manager.enqueueDownload(
            stream: makeStream(name: "remove-cleanup-1.mkv", recoveryContext: recoveryContext),
            mediaId: "tt-remove-download-cleanup",
            episodeId: nil
        )
        let second = try await manager.enqueueDownload(
            stream: makeStream(name: "remove-cleanup-2.mkv", recoveryContext: recoveryContext),
            mediaId: "tt-remove-download-cleanup",
            episodeId: nil
        )

        _ = try await waitForStatus(database: database, id: first.id, expected: .downloading)
        _ = try await waitForStatus(database: database, id: second.id, expected: .queued)

        try await manager.removeDownloads(mediaId: "tt-remove-download-cleanup")

        let cleanupContexts = await cleanupRecorder.snapshot()
        let expectedFirst = first.recoveryContext!.enrichedForDownloadPersistence(
            fileName: first.fileName,
            sizeBytes: first.expectedBytes ?? 100,
            debridService: DebridServiceType.realDebrid.rawValue
        )
        let expectedSecond = second.recoveryContext!.enrichedForDownloadPersistence(
            fileName: second.fileName,
            sizeBytes: second.expectedBytes ?? 100,
            debridService: DebridServiceType.realDebrid.rawValue
        )

        let expectedSet = Set([expectedFirst, expectedSecond])
        #expect(Set(cleanupContexts) == expectedSet)
        #expect(try await database.fetchDownloadTask(id: first.id) == nil)
        #expect(try await database.fetchDownloadTask(id: second.id) == nil)
    }

    @Test func removeDownloadsOnlyRemovesMatchingMediaId() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-downloads-by-media-match.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 64),
            maxConcurrentTransfers: 2,
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let keep = try await manager.enqueueDownload(
            stream: makeStream(name: "keep.mkv"),
            mediaId: "tt-keep",
            episodeId: nil
        )
        let removeFirst = try await manager.enqueueDownload(
            stream: makeStream(name: "remove-a.mkv"),
            mediaId: "tt-remove",
            episodeId: nil
        )
        let removeSecond = try await manager.enqueueDownload(
            stream: makeStream(name: "remove-b.mkv"),
            mediaId: "tt-remove",
            episodeId: nil
        )

        #expect(try await database.fetchDownloadTask(id: keep.id) != nil)
        #expect(try await database.fetchDownloadTask(id: removeFirst.id) != nil)
        #expect(try await database.fetchDownloadTask(id: removeSecond.id) != nil)

        try await manager.removeDownloads(mediaId: "tt-remove")

        #expect(try await database.fetchDownloadTask(id: keep.id) != nil)
        #expect(try await database.fetchDownloadTask(id: removeFirst.id) == nil)
        #expect(try await database.fetchDownloadTask(id: removeSecond.id) == nil)
    }

    @Test func removeDownloadKeepsRowWhenFileDeletionFails() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-fails.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let fileURL = downloadsDir.appendingPathComponent("locked-file.mkv")
        try Data(repeating: 0x5A, count: 64).write(to: fileURL)
        let task = DownloadTask(
            mediaId: "tt151",
            streamURL: "https://cdn.example.com/locked-file.mkv",
            fileName: "locked-file.mkv",
            status: .completed,
            progress: 1.0,
            bytesWritten: 64,
            totalBytes: 64,
            destinationPath: fileURL.path,
            mediaTitle: "Locked",
            mediaType: "movie"
        )
        try await database.saveDownloadTask(task)

        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: downloadsDir.path)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: downloadsDir.path)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 1)
        )

        var didThrow = false
        do {
            try await manager.removeDownload(id: task.id)
        } catch {
            didThrow = true
        }

        #expect(didThrow)
        let stored = try #require(try await database.fetchDownloadTask(id: task.id))
        #expect(stored.id == task.id)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func removeDownloadSucceedsWhenCompletedFileIsMissing() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-missing-file.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let fileURL = downloadsDir.appendingPathComponent("ghost.mkv")
        let task = DownloadTask(
            mediaId: "tt153",
            streamURL: "https://cdn.example.com/ghost.mkv",
            fileName: "ghost.mkv",
            status: .completed,
            progress: 1.0,
            bytesWritten: 64,
            totalBytes: 64,
            destinationPath: fileURL.path,
            mediaTitle: "Missing File",
            mediaType: "movie"
        )
        try await database.saveDownloadTask(task)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 1)
        )

        try await manager.removeDownload(id: task.id)

        #expect(try await database.fetchDownloadTask(id: task.id) == nil)
    }

    @Test func removeDownloadDoesNotDeleteStoredPathOutsideDownloadsDirectory() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-outside-path.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let outsideDir = rootDir.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        let outsideFile = outsideDir.appendingPathComponent("keep.mkv", isDirectory: false)
        try Data(repeating: 0x44, count: 32).write(to: outsideFile)

        let task = DownloadTask(
            mediaId: "tt-outside-remove",
            streamURL: "https://cdn.example.com/keep.mkv",
            fileName: "keep.mkv",
            status: .completed,
            progress: 1.0,
            bytesWritten: 32,
            totalBytes: 32,
            destinationPath: outsideFile.path,
            mediaTitle: "Outside Path",
            mediaType: "movie"
        )
        try await database.saveDownloadTask(task)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeSuccessfulPerformer(bytes: 1)
        )

        try await manager.removeDownload(id: task.id)

        #expect(try await database.fetchDownloadTask(id: task.id) == nil)
        #expect(FileManager.default.fileExists(atPath: outsideFile.path))
    }

    @Test func cancellationStopsProgressSimulationUpdates() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-progress.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let performer: DownloadManager.DownloadPerformer = { _, progressHandler, cancellationController in
            _ = await attemptCounter.next()
            // Report partial progress before blocking so the test can observe it
            progressHandler(512, 512, 10_000)
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                cancellationController.register {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            sleep: { _ in
                try await Task.sleep(for: .milliseconds(20))
            }
        )

        let task = try await manager.enqueueDownload(stream: makeStream(name: "blocked.mkv"), mediaId: "tt106", episodeId: nil)
        var didStart = false
        for _ in 0..<200 {
            if await attemptCounter.snapshot() > 0 {
                didStart = true
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        guard didStart else { throw DownloadManagerTestError.timeout }

        await manager.cancelDownload(id: task.id)
        _ = try await waitForStatus(database: database, id: task.id, expected: .cancelled, timeoutSeconds: 10)

        try await Task.sleep(for: .milliseconds(100))
        let baselineTask = try #require(try await database.fetchDownloadTask(id: task.id))
        let baselineProgress = baselineTask.progress

        try await Task.sleep(for: .milliseconds(300))
        let laterTask = try #require(try await database.fetchDownloadTask(id: task.id))
        let laterProgress = laterTask.progress

        #expect(abs(laterProgress - baselineProgress) < 0.0001)
    }

    @Test func moveFailureCleansTemporaryFile() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-move-failure.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let gate = BlockingDownloadGate()
        let tempURL = rootDir.appendingPathComponent("move-failure-temp.bin")
        let fileName = "move-failure.mkv"
        let destinationPath = downloadsDir.appendingPathComponent(fileName)

        let performer: DownloadManager.DownloadPerformer = { _, _, _ in
            await gate.wait()
            let data = Data(repeating: 0x33, count: 256)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/move-failure.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer
        )

        let task = try await manager.enqueueDownload(stream: makeStream(name: fileName), mediaId: "tt152", episodeId: nil)
        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading)

        try FileManager.default.createDirectory(at: destinationPath, withIntermediateDirectories: true)
        Task { await gate.resume() }

        let failed = try await waitForStatus(database: database, id: task.id, expected: .failed)
        #expect(failed.status == .failed)
        #expect(failed.destinationPath == nil)
        #expect(failed.progress == 0.0)
        #expect(failed.bytesWritten == 0)
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))
    }

    @Test func removeActiveDownloadCancelsJobAndRemovesRow() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-active.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let cleanupRecorder = RemoteCleanupRecorder()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "feedfacefeedfacefeedfacefeedfacefeedface",
                preferredService: .realDebrid
            )
        )

        let performer: DownloadManager.DownloadPerformer = { _, _, cancellationController in
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                cancellationController.register {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            remoteTransferCleaner: { context in
                await cleanupRecorder.record(context)
            }
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: "remove-active.mkv", recoveryContext: recoveryContext),
            mediaId: "tt-remove-active",
            episodeId: nil
        )
        _ = try await waitForStatus(database: database, id: task.id, expected: .downloading)

        try await manager.removeDownload(id: task.id)

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let fetched = try await database.fetchDownloadTask(id: task.id)
            if fetched == nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(try await database.fetchDownloadTask(id: task.id) == nil)
        let expectedCleanupContext = recoveryContext.enrichedForDownloadPersistence(
            fileName: task.fileName,
            sizeBytes: task.expectedBytes ?? 100,
            debridService: DebridServiceType.realDebrid.rawValue
        )
        #expect(await cleanupRecorder.snapshot() == [expectedCleanupContext])
    }

    @Test func removeDownloadsCancelsActiveAndQueuedTasksForMatchingMediaId() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-downloads-cancel-active-tracked.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, cancellationController in
                let _ = await attemptCounter.next()
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                    cancellationController.register {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            },
            maxConcurrentTransfers: 1,
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let active = try await manager.enqueueDownload(
            stream: makeStream(name: "remove-active.mkv"),
            mediaId: "tt-remove-active-media",
            episodeId: nil as String?
        )
        let queued = try await manager.enqueueDownload(
            stream: makeStream(name: "queued-for-remove.mkv"),
            mediaId: "tt-remove-active-media",
            episodeId: nil as String?
        )

        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)
        _ = try await waitForStatus(database: database, id: queued.id, expected: .queued)

        try await manager.removeDownloads(mediaId: "tt-remove-active-media")

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if try await database.fetchDownloadTask(id: active.id) == nil,
               try await database.fetchDownloadTask(id: queued.id) == nil {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(try await database.fetchDownloadTask(id: active.id) == nil)
        #expect(try await database.fetchDownloadTask(id: queued.id) == nil)
        #expect(await attemptCounter.snapshot() == 1)
    }

    @Test func removingActiveDownloadReleasesReservedDestinationForSameFilenameReuse() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-active-releases-slot.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let fileName = "slot-reuse.mkv"

        let performer: DownloadManager.DownloadPerformer = { _, _, cancellationController in
            let attempt = await attemptCounter.next()
            if attempt == 1 {
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                    cancellationController.register {
                        continuation.resume(throwing: CancellationError())
                    }
                }
                throw CancellationError()
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x44, count: 256)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/slot-reuse.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            maxConcurrentTransfers: 1
        )

        let first = try await manager.enqueueDownload(stream: makeStream(name: fileName), mediaId: "tt-slot-reuse-first", episodeId: nil)
        var firstStarted = false
        for _ in 0..<200 {
            if await attemptCounter.snapshot() >= 1 {
                firstStarted = true
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        guard firstStarted else { throw DownloadManagerTestError.timeout }

        try await manager.removeDownload(id: first.id)
        #expect(try await database.fetchDownloadTask(id: first.id) == nil)

        let second = try await manager.enqueueDownload(stream: makeStream(name: fileName), mediaId: "tt-slot-reuse-second", episodeId: nil)
        var secondStarted = false
        for _ in 0..<200 {
            if await attemptCounter.snapshot() >= 2 {
                secondStarted = true
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        guard secondStarted else { throw DownloadManagerTestError.timeout }

        let completed = try await waitForStatus(database: database, id: second.id, expected: .completed)
        let expectedPathSuffix = "/\(fileName)"
        #expect(completed.destinationPath?.hasSuffix(expectedPathSuffix) == true)
    }

    @Test func cancelQueuedDownloadReleasesReservedDestinationForSameFilenameReuse() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-queued-releases-slot.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = BlockingDownloadGate()
        let fileName = "slot-reuse.mkv"
        let activeURL = URL(string: "https://cdn.example.com/active-block.mkv")!

        let performer: DownloadManager.DownloadPerformer = { request, _, cancellationController in
            if request.url == activeURL {
                await gate.wait()
            }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x44, count: 256)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: request.url ?? activeURL,
                mimeType: "video/x-matroska",
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            return (tempURL, response)
        }

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: performer,
            maxConcurrentTransfers: 1
        )

        let active = try await manager.enqueueDownload(
            stream: StreamInfo(
                streamURL: activeURL,
                quality: .hd1080p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: "active.mkv",
                sizeBytes: 256,
                debridService: DebridServiceType.realDebrid.rawValue
            ),
            mediaId: "tt-cancel-queued-releases-active",
            episodeId: nil
        )
        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)

        let queued = try await manager.enqueueDownload(
            stream: StreamInfo(
                streamURL: URL(string: "https://cdn.example.com/queued-slot.mkv")!,
                quality: .hd1080p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: fileName,
                sizeBytes: 256,
                debridService: DebridServiceType.realDebrid.rawValue
            ),
            mediaId: "tt-cancel-queued-releases-queued",
            episodeId: nil
        )
        _ = try await waitForStatus(database: database, id: queued.id, expected: .queued)

        await manager.cancelDownload(id: queued.id)
        _ = try await waitForStatus(database: database, id: queued.id, expected: .cancelled)

        let replacement = try await manager.enqueueDownload(
            stream: StreamInfo(
                streamURL: URL(string: "https://cdn.example.com/replacement-slot.mkv")!,
                quality: .hd1080p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: fileName,
                sizeBytes: 256,
                debridService: DebridServiceType.realDebrid.rawValue
            ),
            mediaId: "tt-cancel-queued-releases-replacement",
            episodeId: nil
        )
        _ = try await waitForStatus(database: database, id: replacement.id, expected: .queued)

        await gate.resume()
        _ = try await waitForStatus(database: database, id: active.id, expected: .completed)
        let completed = try await waitForStatus(database: database, id: replacement.id, expected: .completed)

        let expectedPath = downloadsDir.appendingPathComponent(fileName).path
        #expect(completed.destinationPath == expectedPath)
    }

    private func makeDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, rootDir)
    }

    private func waitForStatus(
        database: DatabaseManager,
        id: String,
        expected: DownloadStatus,
        timeoutSeconds: TimeInterval = 10
    ) async throws -> DownloadTask {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            if let task = try await database.fetchDownloadTask(id: id), task.status == expected {
                return task
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        throw DownloadManagerTestError.timeout
    }

    private func waitForProgress(
        database: DatabaseManager,
        id: String,
        minimum: Double,
        timeoutSeconds: TimeInterval = 10
    ) async throws -> DownloadTask {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            if let task = try await database.fetchDownloadTask(id: id), task.progress >= minimum {
                return task
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        throw DownloadManagerTestError.timeout
    }

    private func makeSuccessfulPerformer(bytes: Int) -> DownloadManager.DownloadPerformer {
        { _, _, _ in
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let data = Data(repeating: 0x01, count: bytes)
            try data.write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/video.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: bytes,
                textEncodingName: nil
            )
            return (tempURL, response)
        }
    }

    private func makeHTTPErrorPerformer(statusCode: Int, tempURL: URL, bytes: Int = 512) -> DownloadManager.DownloadPerformer {
        { _, _, _ in
            let data = Data(repeating: 0x45, count: bytes)
            try data.write(to: tempURL)
            let response = HTTPURLResponse(
                url: URL(string: "https://cdn.example.com/error-page.mkv")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "text/html; charset=utf-8",
                ]
            ) ?? URLResponse(
                url: URL(string: "https://cdn.example.com/error-page.mkv")!,
                mimeType: "text/html",
                expectedContentLength: bytes,
                textEncodingName: "utf-8"
            )
            return (tempURL, response)
        }
    }

    private func assertHTTPErrorResponseDoesNotComplete(
        statusCode: Int,
        fileName: String,
        databaseName: String
    ) async throws {
        let (database, rootDir) = try await makeDatabase(named: databaseName)
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let tempURL = rootDir.appendingPathComponent("error-source-\(statusCode).bin")
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: makeHTTPErrorPerformer(statusCode: statusCode, tempURL: tempURL)
        )

        let task = try await manager.enqueueDownload(
            stream: makeStream(name: fileName),
            mediaId: "tt-http-\(statusCode)",
            episodeId: nil
        )

        let finished = try await waitForStatus(database: database, id: task.id, expected: .failed)
        #expect(finished.status == .failed)
        #expect(finished.destinationURL == nil)
        #expect(finished.errorMessage != nil)
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))
    }

    private func makeDelayedPerformer() -> DownloadManager.DownloadPerformer {
        { _, _, _ in
            try await Task.sleep(for: .seconds(5))
            try Task.checkCancellation()

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try Data([0]).write(to: tempURL)
            let response = URLResponse(
                url: URL(string: "https://cdn.example.com/delayed.mkv")!,
                mimeType: "video/x-matroska",
                expectedContentLength: 1,
                textEncodingName: nil
            )
            return (tempURL, response)
        }
    }

    private func makeStream(name: String, sizeBytes: Int64 = 100, recoveryContext: StreamRecoveryContext? = nil) -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/\(UUID().uuidString).mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: name,
            sizeBytes: sizeBytes,
            debridService: DebridServiceType.realDebrid.rawValue,
            recoveryContext: recoveryContext
        )
    }

    private func waitForRemoteCleanup(
        _ recorder: RemoteCleanupRecorder,
        expected: [StreamRecoveryContext],
        timeoutSeconds: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if await recorder.snapshot() == expected {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(await recorder.snapshot() == expected)
    }
}

extension StreamRecoveryContext {
    func jsonString() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(decoding: data, as: UTF8.self)
    }
}


extension DownloadTask {
    static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        lhs.id == rhs.id &&
        lhs.mediaId == rhs.mediaId &&
        lhs.episodeId == rhs.episodeId &&
        lhs.streamURL == rhs.streamURL &&
        lhs.fileName == rhs.fileName &&
        lhs.status == rhs.status &&
        lhs.progress == rhs.progress &&
        lhs.bytesWritten == rhs.bytesWritten &&
        lhs.totalBytes == rhs.totalBytes &&
        lhs.destinationPath == rhs.destinationPath &&
        lhs.errorMessage == rhs.errorMessage &&
        lhs.mediaTitle == rhs.mediaTitle &&
        lhs.mediaType == rhs.mediaType &&
        lhs.posterPath == rhs.posterPath &&
        lhs.seasonNumber == rhs.seasonNumber &&
        lhs.episodeNumber == rhs.episodeNumber &&
        lhs.episodeTitle == rhs.episodeTitle &&
        lhs.expectedBytes == rhs.expectedBytes &&
        lhs.resumeDataBase64 == rhs.resumeDataBase64
        // Intentionally ignore createdAt/updatedAt which can vary across persistence round-trips.
    }
}
