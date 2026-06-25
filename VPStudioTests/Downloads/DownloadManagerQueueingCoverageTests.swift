import Foundation
import Testing
@testable import VPStudio

private actor RequestOrderRecorder {
    private var urls: [String] = []

    func record(_ request: DownloadManager.TransferRequest) {
        urls.append(request.url?.absoluteString ?? "")
    }

    func snapshot() -> [String] {
        urls
    }
}

private actor DownloadStartGate {
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

    func releaseOne() {
        if let continuation = continuations.first {
            continuations.removeFirst()
            continuation.resume()
        } else {
            bufferedReleases += 1
        }
    }

    func releaseAll() {
        let pending = continuations
        continuations.removeAll()
        for continuation in pending {
            continuation.resume()
        }
    }
}

private enum QueueingDiskProbeError: Error {
    case unavailable
}

private struct TimeoutStatusError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
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

private actor DownloadCallTracker {
    private var totalCalls = 0
    private var activeCalls = 0
    private var maxActiveCalls = 0

    func recordStart() {
        totalCalls += 1
        activeCalls += 1
        maxActiveCalls = max(maxActiveCalls, activeCalls)
    }

    func recordFinish() {
        activeCalls = max(0, activeCalls - 1)
    }

    func snapshot() -> (totalCalls: Int, activeCalls: Int, maxActiveCalls: Int) {
        (totalCalls, activeCalls, maxActiveCalls)
    }
}

private actor ResumeDataUsageRecorder {
    private var sawResumeData = false

    func record(_ request: DownloadManager.TransferRequest) {
        if request.resumeData != nil {
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

@Suite(.serialized)
struct DownloadManagerQueueingCoverageTests {
    private static let ampleDiskSpace: DownloadManager.AvailableDiskSpaceProvider = { _ in 10_000_000_000 }

    @Test func queuedDownloadsStartInStableOrderWhenCreatedAtMatches() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-queue-order.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let recorder = RequestOrderRecorder()
        let gate = DownloadStartGate()
        let callTracker = DownloadCallTracker()
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let firstURL = URL(string: "https://cdn.example.com/a.mkv")!
        let secondURL = URL(string: "https://cdn.example.com/b.mkv")!

        let first = DownloadTask(
            id: "a-task",
            mediaId: "tt-queue-order",
            streamURL: firstURL.absoluteString,
            fileName: "a.mkv",
            status: .queued,
            createdAt: startedAt,
            updatedAt: startedAt
        )
        let second = DownloadTask(
            id: "b-task",
            mediaId: "tt-queue-order",
            streamURL: secondURL.absoluteString,
            fileName: "b.mkv",
            status: .queued,
            createdAt: startedAt,
            updatedAt: startedAt
        )
        try await database.saveDownloadTask(second)
        try await database.saveDownloadTask(first)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await recorder.record(request)
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }
                await gate.wait()

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x11, count: 8).write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/queued.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 8,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 2,
            availableDiskSpace: Self.ampleDiskSpace
        )

        defer {
            Task { await gate.releaseAll() }
        }

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if await recorder.snapshot().count >= 2 {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        let startOrder = await recorder.snapshot()
        let callStats = await callTracker.snapshot()
        #expect(startOrder == [firstURL.absoluteString, secondURL.absoluteString])
        #expect(callStats.totalCalls == 2)
        #expect(callStats.maxActiveCalls == 2)

        await gate.releaseAll()
        _ = try await waitForStatus(database: database, id: first.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: second.id, expected: .completed)

        _ = manager
    }

    @Test func concurrentRetryCallsDoNotCreateDuplicateTaskStarts() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-concurrent-retry-no-duplicates.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let recorder = RequestOrderRecorder()
        let callTracker = DownloadCallTracker()
        let baseDate = Date(timeIntervalSince1970: 1_700_070_000)

        let activeStream = makeStream(name: "active.mkv", sizeBytes: 4)
        let queuedStream = makeStream(name: "queued.mkv", sizeBytes: 4)
        let failed = DownloadTask(
            id: "retry-active-failed-concurrent",
            mediaId: "tt-retry-active-queue-concurrent",
            streamURL: "https://cdn.example.com/retry-before-queued-concurrent.mkv",
            fileName: "retry-before-queued-concurrent.mkv",
            status: .failed,
            expectedBytes: 4,
            createdAt: baseDate,
            updatedAt: baseDate
        )

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await recorder.record(request)
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }
                await gate.wait()

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x11, count: 4).write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/retry-ordered.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 4,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let active = try await manager.enqueueDownload(
            stream: activeStream,
            mediaId: "tt-retry-active-queue-concurrent",
            episodeId: nil as String?
        )
        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)

        let laterQueued = DownloadTask(
            id: "retry-queued-later-concurrent",
            mediaId: "tt-retry-active-queue-concurrent",
            streamURL: queuedStream.streamURL.absoluteString,
            fileName: queuedStream.fileName,
            status: .queued,
            expectedBytes: 4,
            createdAt: baseDate.addingTimeInterval(5),
            updatedAt: baseDate.addingTimeInterval(5)
        )
        try await database.saveDownloadTask(laterQueued)
        try await database.saveDownloadTask(failed)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await manager.retryDownload(id: failed.id) }
            group.addTask { try await manager.retryDownload(id: failed.id) }
            try await group.waitForAll()
        }

        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)
        _ = try await waitForStatus(database: database, id: failed.id, expected: .queued)
        _ = try await waitForStatus(database: database, id: laterQueued.id, expected: .queued)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: active.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: failed.id, expected: .downloading)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: failed.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: laterQueued.id, expected: .downloading)

        await gate.releaseOne()
        _ = try await waitForAllStatus(
            database: database,
            ids: [active.id, failed.id, laterQueued.id],
            expected: .completed
        )

        let startOrder = await recorder.snapshot()
        let callStats = await callTracker.snapshot()
        #expect(startOrder == [
            activeStream.streamURL.absoluteString,
            failed.streamURL,
            laterQueued.streamURL
        ])
        #expect(callStats.totalCalls == 3)
        #expect(callStats.maxActiveCalls == 1)

        _ = manager
    }

    @Test func concurrentRetryDifferentTasksKeepGlobalQueueOrderWithSingleSlot() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-concurrent-retry-different-tasks-order.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let recorder = RequestOrderRecorder()
        let callTracker = DownloadCallTracker()
        let startedAt = Date(timeIntervalSince1970: 1_700_090_000)

        let firstFailed = DownloadTask(
            id: "retry-concurrent-a",
            mediaId: "tt-retry-concurrent-order",
            streamURL: "https://cdn.example.com/retry-a.mkv",
            fileName: "retry-a.mkv",
            status: .failed,
            expectedBytes: 1,
            createdAt: startedAt,
            updatedAt: startedAt
        )
        let secondFailed = DownloadTask(
            id: "retry-concurrent-b",
            mediaId: "tt-retry-concurrent-order",
            streamURL: "https://cdn.example.com/retry-b.mkv",
            fileName: "retry-b.mkv",
            status: .failed,
            expectedBytes: 1,
            createdAt: startedAt,
            updatedAt: startedAt
        )

        try await database.saveDownloadTask(firstFailed)
        try await database.saveDownloadTask(secondFailed)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await recorder.record(request)
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }
                await gate.wait()

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x14, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/retry-order.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await manager.retryDownload(id: firstFailed.id) }
            group.addTask { try await manager.retryDownload(id: secondFailed.id) }
            try await group.waitForAll()
        }

        _ = try await waitForStatus(database: database, id: firstFailed.id, expected: .downloading)
        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: firstFailed.id, expected: .completed)

        _ = try await waitForStatus(database: database, id: secondFailed.id, expected: .downloading)
        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: secondFailed.id, expected: .completed)

        let startOrder = await recorder.snapshot()
        #expect(startOrder == [
            firstFailed.streamURL,
            secondFailed.streamURL
        ])
        let callStats = await callTracker.snapshot()
        #expect(callStats.totalCalls == 2)
        #expect(callStats.maxActiveCalls == 1)
    }

    @Test func removeDownloadsDeletesEveryMatchingMediaId() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-many.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let keeper = DownloadTask(
            id: "keeper-task",
            mediaId: "tt-keep",
            fileName: "keep.mkv",
            status: .completed
        )
        let first = DownloadTask(
            id: "remove-task-a",
            mediaId: "tt-remove",
            fileName: "remove-a.mkv",
            status: .completed
        )
        let second = DownloadTask(
            id: "remove-task-b",
            mediaId: "tt-remove",
            fileName: "remove-b.mkv",
            status: .completed
        )
        try await database.saveDownloadTask(keeper)
        try await database.saveDownloadTask(first)
        try await database.saveDownloadTask(second)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x22, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/remove.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace,
            resumePersistedDownloadsOnInit: false
        )

        try await manager.removeDownloads(mediaId: "tt-remove")

        #expect(try await database.fetchDownloadTask(id: keeper.id) != nil)
        #expect(try await database.fetchDownloadTask(id: first.id) == nil)
        #expect(try await database.fetchDownloadTask(id: second.id) == nil)
    }

    @Test func removePersistedQueuedDownloadRemovesRowAndFileWithoutInvokingPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-queued-no-start.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("queued-removal.mkv")
        try Data(repeating: 0x55, count: 32).write(to: destinationURL)
        let callTracker = DownloadCallTracker()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x55, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/queued-removed.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace,
            resumePersistedDownloadsOnInit: false
        )

        let queued = DownloadTask(
            id: "remove-queued-task",
            mediaId: "tt-queue-remove",
            streamURL: "https://cdn.example.com/queued-removed.mkv",
            fileName: "queued-removed.mkv",
            status: .queued,
            progress: 0.31,
            bytesWritten: 31,
            totalBytes: 100,
            destinationPath: destinationURL.path,
            expectedBytes: 100
        )
        try await database.saveDownloadTask(queued)

        try await manager.removeDownload(id: queued.id)

        #expect(try await database.fetchDownloadTask(id: queued.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
        #expect(await callTracker.snapshot().totalCalls == 0)
    }

    @Test func removeMissingDownloadIsNoOp() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-missing-noop.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x77, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/missing-remove.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace,
            resumePersistedDownloadsOnInit: false
        )

        try await manager.removeDownload(id: "does-not-exist")
        let remaining = try await manager.listDownloads()
        #expect(remaining.isEmpty)
    }

    @Test func cancelQueuedDownloadDoesNotInvokePerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-queued-wont-start.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let callTracker = DownloadCallTracker()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }

                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x55, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/active.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let active = try await manager.enqueueDownload(
            stream: makeStream(name: "active.mkv"),
            mediaId: "tt-cancel-queued",
            episodeId: nil as String?
        )
        let queued = try await manager.enqueueDownload(
            stream: makeStream(name: "queued.mkv"),
            mediaId: "tt-cancel-queued",
            episodeId: nil as String?
        )

        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)
        let queuedState = try await database.fetchDownloadTask(id: queued.id)
        let maybeQueuedState = try #require(queuedState)
        #expect(maybeQueuedState.status == DownloadStatus.queued)

        await manager.cancelDownload(id: queued.id)
        _ = try await waitForStatus(database: database, id: queued.id, expected: .cancelled)

        let calls = await callTracker.snapshot()
        #expect(calls.totalCalls == 1)

        Task { await gate.releaseAll() }
        _ = try await waitForStatus(database: database, id: active.id, expected: .completed)
    }

    @Test func cancelQueuedDownloadReleasesReservedDestinationForFilenameReuse() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-queued-releases-reservation.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let fileName = "queued-reuse.mkv"

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0xAA, count: 1_024).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/queued-reuse.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1_024,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let active = try await manager.enqueueDownload(
            stream: makeStream(name: "active-holder.mkv"),
            mediaId: "tt-cancel-queued-reserve",
            episodeId: nil as String?
        )
        let queued = try await manager.enqueueDownload(
            stream: makeStream(name: fileName),
            mediaId: "tt-cancel-queued-reserve",
            episodeId: nil as String?
        )

        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)
        let queuedBeforeCancel = try await waitForStatus(database: database, id: queued.id, expected: .queued)
        #expect(queuedBeforeCancel.fileName == fileName)

        await manager.cancelDownload(id: queued.id)
        _ = try await waitForStatus(database: database, id: queued.id, expected: .cancelled)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: active.id, expected: .completed, timeoutSeconds: 10)

        await gate.releaseOne()
        let replacement = try await manager.enqueueDownload(
            stream: makeStream(name: fileName),
            mediaId: "tt-cancel-queued-reserve-replacement",
            episodeId: nil as String?
        )

        let completedReplacement = try await waitForStatus(database: database, id: replacement.id, expected: .completed, timeoutSeconds: 10)
        let completedPath = try #require(completedReplacement.destinationPath)
        let completedName = URL(fileURLWithPath: completedPath).lastPathComponent

        #expect(completedName == fileName)
    }

    @Test func removeQueuedDownloadReleasesReservedDestinationForFilenameReuse() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-queued-releases-reservation.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let fileName = "queued-removed-reuse.mkv"

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0xCC, count: 1_024).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/queued-removed-reuse.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1_024,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let active = try await manager.enqueueDownload(
            stream: makeStream(name: "active-holder.mkv"),
            mediaId: "tt-remove-queued-reuse",
            episodeId: nil as String?
        )
        let queued = try await manager.enqueueDownload(
            stream: makeStream(name: fileName),
            mediaId: "tt-remove-queued-reuse",
            episodeId: nil as String?
        )

        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)
        _ = try await waitForStatus(database: database, id: queued.id, expected: .queued)

        try await manager.removeDownload(id: queued.id)
        #expect(try await database.fetchDownloadTask(id: queued.id) == nil)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: active.id, expected: .completed, timeoutSeconds: 10)

        await gate.releaseOne()
        let replacement = try await manager.enqueueDownload(
            stream: makeStream(name: fileName),
            mediaId: "tt-remove-queued-reuse-replacement",
            episodeId: nil as String?
        )

        let completedReplacement = try await waitForStatus(database: database, id: replacement.id, expected: .completed, timeoutSeconds: 10)
        let completedPath = try #require(completedReplacement.destinationPath)
        let completedName = URL(fileURLWithPath: completedPath).lastPathComponent

        #expect(completedName == fileName)
    }

    @Test func removeDownloadsReleasesQueuedReservationsForBatchedQueuedTasks() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-downloads-batch-queued-reservations.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let sharedFileName = "shared-queued-removal.mkv"

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, cancellationController in
                cancellationController.register {
                    Task { await gate.releaseAll() }
                }
                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0xAA, count: 1_024).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/shared-queued-removal.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1_024,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        _ = try await manager.enqueueDownload(
            stream: makeStream(name: "active-holder.mkv"),
            mediaId: "tt-remove-downloads-reservation",
            episodeId: nil as String?
        )
        let firstQueued = try await manager.enqueueDownload(
            stream: makeStream(name: sharedFileName),
            mediaId: "tt-remove-downloads-reservation",
            episodeId: nil as String?
        )
        let secondQueued = try await manager.enqueueDownload(
            stream: makeStream(name: sharedFileName),
            mediaId: "tt-remove-downloads-reservation",
            episodeId: nil as String?
        )

        _ = try await waitForStatus(database: database, id: firstQueued.id, expected: .queued)
        _ = try await waitForStatus(database: database, id: secondQueued.id, expected: .queued)

        try await manager.removeDownloads(mediaId: "tt-remove-downloads-reservation")

        #expect(try await database.fetchDownloadTask(id: firstQueued.id) == nil)
        #expect(try await database.fetchDownloadTask(id: secondQueued.id) == nil)

        await gate.releaseOne()
        let replacement = try await manager.enqueueDownload(
            stream: makeStream(name: sharedFileName),
            mediaId: "tt-remove-downloads-reservation-replacement",
            episodeId: nil as String?
        )

        let completedReplacement = try await waitForStatus(database: database, id: replacement.id, expected: .completed, timeoutSeconds: 10)
        let completedPath = try #require(completedReplacement.destinationPath)
        let completedName = URL(fileURLWithPath: completedPath).lastPathComponent

        #expect(completedName == sharedFileName)
    }

    @Test func removeDownloadsWithNoMatchingMediaIdIsNoOp() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-nomatch.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let keeper = DownloadTask(
            id: "keeper-task",
            mediaId: "tt-keep",
            fileName: "keep.mkv",
            status: .completed
        )
        try await database.saveDownloadTask(keeper)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x22, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/remove.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace,
            resumePersistedDownloadsOnInit: false
        )

        try await manager.removeDownloads(mediaId: "tt-missing")
        #expect(try await database.fetchDownloadTask(id: keeper.id) != nil)
    }

    @Test func removeDownloadsCancelsActiveAndQueuedTasksForMatchingMediaId() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-downloads-cancel-active.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let callTracker = DownloadCallTracker()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, cancellationController in
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                    cancellationController.register {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let active = try await manager.enqueueDownload(
            stream: makeStream(name: "active-removal.mkv"),
            mediaId: "tt-remove-active-media",
            episodeId: nil as String?
        )
        let queued = try await manager.enqueueDownload(
            stream: makeStream(name: "queued-removal.mkv"),
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
        #expect(await callTracker.snapshot().totalCalls == 1)
    }

    @Test func removeDownloadsCancelsActiveAndQueuedTasksAndAllowsFilenameReuse() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-downloads-reuse-after-cancel-active-queued.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let sharedFileName = "active-queued-reuse.mkv"

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                try await Task.sleep(for: .milliseconds(500))
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x77, count: 1_024)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/active-queued-reuse.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let active = try await manager.enqueueDownload(
            stream: makeStream(name: sharedFileName),
            mediaId: "tt-remove-downloads-active-queued-reuse",
            episodeId: nil as String?
        )
        let queued = try await manager.enqueueDownload(
            stream: makeStream(name: sharedFileName),
            mediaId: "tt-remove-downloads-active-queued-reuse",
            episodeId: nil as String?
        )

        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)
        _ = try await waitForStatus(database: database, id: queued.id, expected: .queued)

        try await manager.removeDownloads(mediaId: "tt-remove-downloads-active-queued-reuse")

        #expect(try await database.fetchDownloadTask(id: active.id) == nil)
        #expect(try await database.fetchDownloadTask(id: queued.id) == nil)

        let replacement = try await manager.enqueueDownload(
            stream: makeStream(name: sharedFileName),
            mediaId: "tt-remove-downloads-active-queued-reuse-replacement",
            episodeId: nil as String?
        )

        let completedReplacement = try await waitForStatus(
            database: database,
            id: replacement.id,
            expected: .completed,
            timeoutSeconds: 10
        )
        let replacementName = URL(fileURLWithPath: try #require(completedReplacement.destinationPath)).lastPathComponent
        #expect(replacementName == sharedFileName)
    }

    @Test func removeDownloadCancelsActiveRecoveryBackedTaskAndInvokesRemoteCleanup() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-active-recovery-cleanup.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let callTracker = DownloadCallTracker()
        let cleanupRecorder = RemoteCleanupRecorder()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "222233334444555566667777888899990000aaaa",
                preferredService: .realDebrid,
                torrentId: "rd-cleanup-1",
                resolvedDebridService: DebridServiceType.realDebrid.rawValue
            )
        )
        let stream = makeStream(name: "remove-active-cleanup.mkv", recoveryContext: recoveryContext)
        let expectedCleanupContext = recoveryContext.enrichedForDownloadPersistence(
            fileName: stream.fileName,
            sizeBytes: stream.sizeBytes,
            debridService: DebridServiceType.realDebrid.rawValue
        )

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, cancellationController in
                await callTracker.recordStart()
                defer { Task { await callTracker.recordFinish() } }
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                    cancellationController.register {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            },
            remoteTransferCleaner: { context in
                await cleanupRecorder.record(context)
            },
            minimumFreeSpaceBufferBytes: 0,
            availableDiskSpace: { _ in 1_024 }
        )

        let active = try await manager.enqueueDownload(
            stream: stream,
            mediaId: "tt-remove-active-cleanup",
            episodeId: nil as String?
        )

        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)
        try await waitForCallCount(callTracker, expectedTotalCalls: 1)
        try await manager.removeDownload(id: active.id)

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if try await database.fetchDownloadTask(id: active.id) == nil {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(try await database.fetchDownloadTask(id: active.id) == nil)
        #expect(await callTracker.snapshot().totalCalls == 1)
        #expect(await cleanupRecorder.snapshot() == [expectedCleanupContext])
    }

    @Test func removeDownloadsDeletesAllMatchingTasksAndDeletesAllDestinationFiles() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-remove-downloads-deletes-all-destination-files.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let completedPath = downloadsDir.appendingPathComponent("remove-complete-with-file.mkv")
        let queuedPath = downloadsDir.appendingPathComponent("remove-queued-with-file.mkv")
        try Data(repeating: 0x33, count: 16).write(to: completedPath)
        try Data(repeating: 0x44, count: 16).write(to: queuedPath)

        let completed = DownloadTask(
            id: "remove-completed-file-id",
            mediaId: "tt-remove-downloads-mixed",
            fileName: completedPath.lastPathComponent,
            status: .completed,
            progress: 1.0,
            bytesWritten: 16,
            totalBytes: 16,
            destinationPath: completedPath.path
        )
        let queued = DownloadTask(
            id: "remove-queued-file-id",
            mediaId: "tt-remove-downloads-mixed",
            streamURL: "https://cdn.example.com/remove-queued-with-file.mkv",
            fileName: queuedPath.lastPathComponent,
            status: .queued,
            progress: 0.0,
            bytesWritten: 0,
            totalBytes: 16,
            destinationPath: queuedPath.path
        )
        try await database.saveDownloadTask(completed)
        try await database.saveDownloadTask(queued)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x55, count: 16)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/unused.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace,
            resumePersistedDownloadsOnInit: false
        )

        try await manager.removeDownloads(mediaId: "tt-remove-downloads-mixed")

        #expect(try await database.fetchDownloadTask(id: completed.id) == nil)
        #expect(try await database.fetchDownloadTask(id: queued.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: completedPath.path))
        #expect(!FileManager.default.fileExists(atPath: queuedPath.path))
    }

    @Test func maxConcurrentTransfersZeroFallsBackToOne() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-max-concurrent-zero.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let tracker = DownloadCallTracker()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await tracker.recordStart()
                defer {
                    Task { await tracker.recordFinish() }
                }

                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x66, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/many.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 0,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let first = try await manager.enqueueDownload(
            stream: makeStream(name: "first.mkv"),
            mediaId: "tt-max1",
            episodeId: nil as String?
        )
        let second = try await manager.enqueueDownload(
            stream: makeStream(name: "second.mkv"),
            mediaId: "tt-max1",
            episodeId: nil as String?
        )
        let third = try await manager.enqueueDownload(
            stream: makeStream(name: "third.mkv"),
            mediaId: "tt-max1",
            episodeId: nil as String?
        )

        let runningIdAfterRelease = try await waitForAnyStatus(
            database: database,
            ids: [first.id, second.id, third.id],
            expected: .downloading
        )

        try await waitForCallCount(tracker, expectedTotalCalls: 1)
        let beforeResume = await tracker.snapshot()
        #expect(beforeResume.totalCalls == 1)
        #expect(beforeResume.maxActiveCalls == 1)

        let states = try await fetchTasks(database: database, ids: [first.id, second.id, third.id])
        #expect(states.values.filter { $0.status == DownloadStatus.downloading }.count == 1)
        #expect(states.values.filter { $0.status == DownloadStatus.queued }.count == 2)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: runningIdAfterRelease, expected: .completed)

        let remaining = [first.id, second.id, third.id].filter { $0 != runningIdAfterRelease }
        let nextRunningId = try await waitForAnyStatus(
            database: database,
            ids: remaining,
            expected: .downloading
        )
        try await waitForCallCount(tracker, expectedTotalCalls: 2)
        let mid1 = try await fetchTasks(database: database, ids: [runningIdAfterRelease] + remaining)
        #expect(mid1.values.filter { $0.status == DownloadStatus.downloading }.count == 1)
        #expect(mid1.values.filter { $0.status == DownloadStatus.queued }.count == 1)
        #expect(await tracker.snapshot().totalCalls == 2)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: nextRunningId, expected: .completed)

        let finalRunningId = [first.id, second.id, third.id].first { $0 != runningIdAfterRelease && $0 != nextRunningId }!
        try await waitForCallCount(tracker, expectedTotalCalls: 3)
        #expect(await tracker.snapshot().totalCalls == 3)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: finalRunningId, expected: .completed)

        let afterRun = await tracker.snapshot()
        #expect(afterRun.maxActiveCalls == 1)
    }

    @Test func maxConcurrentTransfersNegativeFallsBackToOne() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-max-concurrent-negative.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let tracker = DownloadCallTracker()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await tracker.recordStart()
                defer {
                    Task { await tracker.recordFinish() }
                }

                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x99, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/many.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: -2,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let first = try await manager.enqueueDownload(
            stream: makeStream(name: "first.mkv"),
            mediaId: "tt-max-neg",
            episodeId: nil as String?
        )
        let second = try await manager.enqueueDownload(
            stream: makeStream(name: "second.mkv"),
            mediaId: "tt-max-neg",
            episodeId: nil as String?
        )

        _ = try await waitForAnyStatus(
            database: database,
            ids: [first.id, second.id],
            expected: .downloading
        )

        try await waitForCallCount(tracker, expectedTotalCalls: 1)
        let beforeResume = await tracker.snapshot()
        #expect(beforeResume.totalCalls == 1)
        #expect(beforeResume.maxActiveCalls == 1)

        let states = try await fetchTasks(database: database, ids: [first.id, second.id])
        #expect(states.values.filter { $0.status == DownloadStatus.downloading }.count == 1)
        #expect(states.values.filter { $0.status == DownloadStatus.queued }.count == 1)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: first.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: second.id, expected: .downloading)
        await gate.releaseOne()
        try await waitForAllStatus(database: database, ids: [first.id, second.id], expected: .completed)

        let afterRun = await tracker.snapshot()
        #expect(afterRun.maxActiveCalls == 1)
    }

    @Test func maxConcurrentTransfersOneIsHonored() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-max-concurrent-one.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let tracker = DownloadCallTracker()

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await tracker.recordStart()
                defer {
                    Task { await tracker.recordFinish() }
                }

                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x77, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/many.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let first = try await manager.enqueueDownload(
            stream: makeStream(name: "first.mkv"),
            mediaId: "tt-max-one",
            episodeId: nil as String?
        )
        let second = try await manager.enqueueDownload(
            stream: makeStream(name: "second.mkv"),
            mediaId: "tt-max-one",
            episodeId: nil as String?
        )

        _ = try await waitForAnyStatus(
            database: database,
            ids: [first.id, second.id],
            expected: .downloading
        )

        try await waitForCallCount(tracker, expectedTotalCalls: 1)
        let beforeResume = await tracker.snapshot()
        #expect(beforeResume.totalCalls == 1)
        #expect(beforeResume.maxActiveCalls == 1)

        let states = try await fetchTasks(database: database, ids: [first.id, second.id])
        #expect(states.values.filter { $0.status == DownloadStatus.downloading }.count == 1)
        #expect(states.values.filter { $0.status == DownloadStatus.queued }.count == 1)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: first.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: second.id, expected: .downloading)
        await gate.releaseOne()
        try await waitForAllStatus(database: database, ids: [first.id, second.id], expected: .completed)

        let afterRun = await tracker.snapshot()
        #expect(afterRun.maxActiveCalls == 1)
    }

    @Test func maxConcurrentTransfersOneStartsQueuedInCreationOrder() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-max-concurrent-one-ordered.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let recorder = RequestOrderRecorder()
        let callTracker = DownloadCallTracker()

        let firstStream = makeStream(name: "ordered-1.mkv")
        let secondStream = makeStream(name: "ordered-2.mkv")
        let thirdStream = makeStream(name: "ordered-3.mkv")

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await recorder.record(request)
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }
                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x88, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/ordered.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let first = try await manager.enqueueDownload(
            stream: firstStream,
            mediaId: "tt-ordered",
            episodeId: nil as String?
        )
        try await Task.sleep(for: .milliseconds(5))
        let second = try await manager.enqueueDownload(
            stream: secondStream,
            mediaId: "tt-ordered",
            episodeId: nil as String?
        )
        try await Task.sleep(for: .milliseconds(5))
        let third = try await manager.enqueueDownload(
            stream: thirdStream,
            mediaId: "tt-ordered",
            episodeId: nil as String?
        )

        _ = try await waitForAnyStatus(
            database: database,
            ids: [first.id, second.id],
            expected: .downloading
        )
        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: first.id, expected: .completed)
        _ = try await waitForAnyStatus(
            database: database,
            ids: [second.id],
            expected: .downloading
        )
        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: second.id, expected: .completed)
        _ = try await waitForAnyStatus(
            database: database,
            ids: [third.id],
            expected: .downloading
        )
        await gate.releaseOne()

        _ = try await waitForStatus(database: database, id: third.id, expected: .completed)
        let startOrder = await recorder.snapshot()
        #expect(startOrder == [
            firstStream.streamURL.absoluteString,
            secondStream.streamURL.absoluteString,
            thirdStream.streamURL.absoluteString
        ])
        let callStats = await callTracker.snapshot()
        #expect(callStats.totalCalls == 3)
        #expect(callStats.maxActiveCalls == 1)
    }

    @Test func resumePersistedQueuedDownloadsRespectMaxConcurrentTransfers() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-resume-queued-max-concurrent.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        let tracker = DownloadCallTracker()

        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let first = DownloadTask(
            id: "resume-max-1",
            mediaId: "tt-resume-max",
            streamURL: "https://cdn.example.com/resume-max-1.mkv",
            fileName: "resume-max-1.mkv",
            status: .queued,
            expectedBytes: 64,
            createdAt: baseDate,
            updatedAt: baseDate
        )
        let second = DownloadTask(
            id: "resume-max-2",
            mediaId: "tt-resume-max",
            streamURL: "https://cdn.example.com/resume-max-2.mkv",
            fileName: "resume-max-2.mkv",
            status: .queued,
            expectedBytes: 64,
            createdAt: baseDate.addingTimeInterval(1),
            updatedAt: baseDate.addingTimeInterval(1)
        )
        let third = DownloadTask(
            id: "resume-max-3",
            mediaId: "tt-resume-max",
            streamURL: "https://cdn.example.com/resume-max-3.mkv",
            fileName: "resume-max-3.mkv",
            status: .queued,
            expectedBytes: 64,
            createdAt: baseDate.addingTimeInterval(2),
            updatedAt: baseDate.addingTimeInterval(2)
        )
        try await database.saveDownloadTask(first)
        try await database.saveDownloadTask(second)
        try await database.saveDownloadTask(third)

        defer {
            Task { await gate.releaseAll() }
        }

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await tracker.recordStart()
                defer {
                    Task { await tracker.recordFinish() }
                }

                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x77, count: 64).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/resume-max.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 64,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 2,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let allIDs = [first.id, second.id, third.id]
        try await waitForQueuedAndDownloadingCounts(
            database: database,
            ids: allIDs,
            expectedQueued: 1,
            expectedDownloading: 2
        )

        let initialStates = try await fetchTasks(database: database, ids: allIDs)
        #expect(initialStates.count == allIDs.count)
        #expect(initialStates.values.filter { $0.status == .downloading }.count == 2)
        #expect(initialStates.values.filter { $0.status == .queued }.count == 1)

        let queuedTaskID = try #require(initialStates.values.first(where: { $0.status == .queued })?.id)
        let snapshot = await tracker.snapshot()
        #expect(snapshot.totalCalls == 2)
        #expect(snapshot.maxActiveCalls == 2)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: queuedTaskID, expected: .downloading)

        await gate.releaseAll()
        try await waitForAllStatus(database: database, ids: allIDs, expected: .completed)
        #expect(await tracker.snapshot().maxActiveCalls == 2)
    }

    @Test func resumePersistedQueuedDownloadsUseStableCreatedAtOrderOnInit() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-resume-queued-order.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let recorder = RequestOrderRecorder()
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let callTracker = DownloadCallTracker()
        let baseDate = Date(timeIntervalSince1970: 1_700_010_000)

        let first = DownloadTask(
            id: "resume-order-a",
            mediaId: "tt-resume-order",
            streamURL: "https://cdn.example.com/resume-order-a.mkv",
            fileName: "resume-order-a.mkv",
            status: .queued,
            createdAt: baseDate,
            updatedAt: baseDate
        )
        let second = DownloadTask(
            id: "resume-order-b",
            mediaId: "tt-resume-order",
            streamURL: "https://cdn.example.com/resume-order-b.mkv",
            fileName: "resume-order-b.mkv",
            status: .queued,
            createdAt: baseDate,
            updatedAt: baseDate
        )
        let third = DownloadTask(
            id: "resume-order-c",
            mediaId: "tt-resume-order",
            streamURL: "https://cdn.example.com/resume-order-c.mkv",
            fileName: "resume-order-c.mkv",
            status: .queued,
            createdAt: baseDate,
            updatedAt: baseDate
        )

        try await database.saveDownloadTask(third)
        try await database.saveDownloadTask(first)
        try await database.saveDownloadTask(second)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await recorder.record(request)
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }
                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x88, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/resume-order.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        _ = try await waitForStatus(database: database, id: first.id, expected: .downloading)
        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: first.id, expected: .completed)

        _ = try await waitForStatus(database: database, id: second.id, expected: .downloading)
        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: second.id, expected: .completed)

        _ = try await waitForStatus(database: database, id: third.id, expected: .downloading)
        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: third.id, expected: .completed)

        let startOrder = await recorder.snapshot()
        #expect(startOrder == [
            first.streamURL,
            second.streamURL,
            third.streamURL
        ])
        let callStats = await callTracker.snapshot()
        #expect(callStats.totalCalls == 3)
        #expect(callStats.maxActiveCalls == 1)
        _ = manager
    }

    @Test func retryFailedTaskRespectsOriginalQueueOrderByCreatedAt() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-failed-order.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let recorder = RequestOrderRecorder()
        let callTracker = DownloadCallTracker()
        let baseDate = Date(timeIntervalSince1970: 1_700_050_000)

        let failed = DownloadTask(
            id: "retry-failed-old",
            mediaId: "tt-retry-order",
            streamURL: "https://cdn.example.com/retry-old.mkv",
            fileName: "retry-old.mkv",
            status: .failed,
            expectedBytes: 1,
            createdAt: baseDate,
            updatedAt: baseDate
        )
        let queuedFirst = DownloadTask(
            id: "retry-queued-new",
            mediaId: "tt-retry-order",
            streamURL: "https://cdn.example.com/retry-new-1.mkv",
            fileName: "retry-new-1.mkv",
            status: .queued,
            expectedBytes: 1,
            createdAt: baseDate.addingTimeInterval(1),
            updatedAt: baseDate.addingTimeInterval(1)
        )
        let queuedSecond = DownloadTask(
            id: "retry-queued-newer",
            mediaId: "tt-retry-order",
            streamURL: "https://cdn.example.com/retry-new-2.mkv",
            fileName: "retry-new-2.mkv",
            status: .queued,
            expectedBytes: 1,
            createdAt: baseDate.addingTimeInterval(2),
            updatedAt: baseDate.addingTimeInterval(2)
        )
        try await database.saveDownloadTask(failed)
        try await database.saveDownloadTask(queuedFirst)
        try await database.saveDownloadTask(queuedSecond)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await recorder.record(request)
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }
                await gate.wait()
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x88, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/retry-order.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        try await manager.retryDownload(id: failed.id)

        _ = try await waitForStatus(database: database, id: failed.id, expected: .downloading)
        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: failed.id, expected: .completed)

        _ = try await waitForStatus(database: database, id: queuedFirst.id, expected: .downloading)
        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: queuedFirst.id, expected: .completed)

        _ = try await waitForStatus(database: database, id: queuedSecond.id, expected: .downloading)
        await gate.releaseAll()
        _ = try await waitForAllStatus(
            database: database,
            ids: [failed.id, queuedFirst.id, queuedSecond.id],
            expected: .completed
        )

        let startOrder = await recorder.snapshot()
        #expect(startOrder == [
            failed.streamURL,
            queuedFirst.streamURL,
            queuedSecond.streamURL
        ])
        let callStats = await callTracker.snapshot()
        #expect(callStats.totalCalls == 3)
        #expect(callStats.maxActiveCalls == 1)
        _ = manager
    }

    @Test func retryDownloadUsesCollisionSafeDestinationWhenCompletedFileExists() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-collision-destination.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let existingPath = downloadsDir.appendingPathComponent("collision.mkv")
        try Data(repeating: 0x11, count: 2).write(to: existingPath)

        let existing = DownloadTask(
            id: "retry-collision-completed",
            mediaId: "tt-retry-collision",
            fileName: existingPath.lastPathComponent,
            status: .completed,
            progress: 1.0,
            bytesWritten: 2,
            totalBytes: 2,
            destinationPath: existingPath.path,
            expectedBytes: 2
        )
        let failed = DownloadTask(
            id: "retry-collision-failed",
            mediaId: "tt-retry-collision",
            streamURL: "https://cdn.example.com/retry-collision.mkv",
            fileName: existingPath.lastPathComponent,
            status: .failed,
            expectedBytes: 2
        )
        try await database.saveDownloadTask(existing)
        try await database.saveDownloadTask(failed)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x55, count: 2).write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/retry-collision.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 2,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        try await manager.retryDownload(id: failed.id)

        let completed = try await waitForStatus(database: database, id: failed.id, expected: .completed)
        let completedPath = try #require(completed.destinationPath)
        let completedName = URL(fileURLWithPath: completedPath).lastPathComponent

        #expect(FileManager.default.fileExists(atPath: existingPath.path))
        #expect(FileManager.default.fileExists(atPath: completedPath))
        #expect(completedName != existingPath.lastPathComponent)
        #expect(completedName.contains(" (1)."))
        #expect(existingPath.lastPathComponent != completedName)
        _ = manager
    }

    @Test func retryFailedTaskStartsNextInStableCreatedAtOrderWhenActiveSlotIsBusy() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-queued-behind-active-order.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let gate = DownloadStartGate()
        defer { Task { await gate.releaseAll() } }
        let recorder = RequestOrderRecorder()
        let callTracker = DownloadCallTracker()
        let baseDate = Date(timeIntervalSince1970: 1_700_060_000)

        let activeStream = makeStream(name: "active.mkv", sizeBytes: 4)
        let queuedStream = makeStream(name: "queued.mkv", sizeBytes: 4)
        let failed = DownloadTask(
            id: "retry-active-failed",
            mediaId: "tt-retry-active-queue",
            streamURL: "https://cdn.example.com/retry-before-queued.mkv",
            fileName: "retry-before-queued.mkv",
            status: .failed,
            expectedBytes: 4,
            createdAt: baseDate,
            updatedAt: baseDate
        )

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await recorder.record(request)
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }
                await gate.wait()

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x11, count: 4).write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/retry-ordered.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 4,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let active = try await manager.enqueueDownload(
            stream: activeStream,
            mediaId: "tt-retry-active-queue",
            episodeId: nil as String?
        )
        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)

        let laterQueued = DownloadTask(
            id: "retry-queued-later",
            mediaId: "tt-retry-active-queue",
            streamURL: queuedStream.streamURL.absoluteString,
            fileName: queuedStream.fileName,
            status: .queued,
            expectedBytes: 4,
            createdAt: baseDate.addingTimeInterval(5),
            updatedAt: baseDate.addingTimeInterval(5)
        )
        try await database.saveDownloadTask(laterQueued)

        try await database.saveDownloadTask(failed)
        try await manager.retryDownload(id: failed.id)

        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)
        _ = try await waitForStatus(database: database, id: failed.id, expected: .queued)
        _ = try await waitForStatus(database: database, id: laterQueued.id, expected: .queued)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: active.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: failed.id, expected: .downloading)

        await gate.releaseOne()
        _ = try await waitForStatus(database: database, id: failed.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: laterQueued.id, expected: .downloading)

        await gate.releaseOne()
        _ = try await waitForAllStatus(
            database: database,
            ids: [active.id, failed.id, laterQueued.id],
            expected: .completed
        )

        let startOrder = await recorder.snapshot()
        let callStats = await callTracker.snapshot()
        #expect(startOrder == [
            activeStream.streamURL.absoluteString,
            failed.streamURL,
            laterQueued.streamURL
        ])
        #expect(callStats.totalCalls == 3)
    }

    @Test func retryDownloadPreservesRequestHeadersOnRetryPath() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-retry-preserves-headers.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let counter = AttemptCounter()
        let requestRecorder = TransferRequestRecorder()
        let headers = ["Authorization": "Bearer unit-test"]
        let stream = makeStream(name: "headers-retry.mkv", sizeBytes: 1).withRequestHeaders(headers)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await requestRecorder.record(request: request)
                let attempt = await counter.next()
                if attempt == 1 {
                    throw URLError(.badServerResponse)
                }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x11, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/headers-retry.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let task = try await manager.enqueueDownload(
            stream: stream,
            mediaId: "tt-retry-headers",
            episodeId: nil as String?
        )

        _ = try await waitForStatus(database: database, id: task.id, expected: .failed)

        #expect(await counter.snapshot() == 1)
        #expect(await requestRecorder.snapshot().count == 1)
        #expect(await requestRecorder.snapshot().first?.requestHeaders == headers)

        try await manager.retryDownload(id: task.id)
        _ = try await waitForStatus(database: database, id: task.id, expected: .completed)

        let requests = await requestRecorder.snapshot()
        #expect(requests.count == 2)
        #expect(requests[0].requestHeaders == headers)
        #expect(requests[1].requestHeaders == headers)
    }

    @Test func resumePersistedDownloadWithExistingDestinationCompletesWithoutPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-resume-existing-destination.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("existing-destination.mkv", isDirectory: false)
        try Data(repeating: 0x22, count: 13).write(to: destinationURL)

        let tracker = DownloadCallTracker()
        let task = DownloadTask(
            id: "resume-existing-destination",
            mediaId: "tt-resume-existing",
            streamURL: "https://cdn.example.com/resume-existing.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .downloading,
            bytesWritten: 4,
            totalBytes: 13,
            destinationPath: destinationURL.path,
            expectedBytes: 13
        )
        try await database.saveDownloadTask(task)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await tracker.recordStart()
                defer {
                    Task { await tracker.recordFinish() }
                }
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x33, count: 13).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/resume-existing.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 13,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let calls = await tracker.snapshot()

        #expect(completed.destinationPath == destinationURL.path)
        #expect(completed.progress == 1.0)
        #expect(completed.totalBytes == 13)
        #expect(completed.bytesWritten == 13)
        #expect(completed.errorMessage == nil)
        #expect(calls.totalCalls == 0)

        _ = manager
    }

    @Test func startupQueuedDownloadWithPartialExistingDestinationRetriesInsteadOfAutoCompleting() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-partial-existing-destination.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("partial-existing-destination.mkv", isDirectory: false)
        try Data(repeating: 0x22, count: 4).write(to: destinationURL)

        let callTracker = DownloadCallTracker()
        let task = DownloadTask(
            id: "startup-partial-existing-destination",
            mediaId: "tt-startup-partial-existing",
            streamURL: "https://cdn.example.com/startup-partial-existing.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .queued,
            bytesWritten: 4,
            totalBytes: 13,
            destinationPath: destinationURL.path,
            expectedBytes: 13
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x33, count: 13).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-partial-existing.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 13,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let calls = await callTracker.snapshot()
        let finalDestination = try #require(completed.destinationPath)
        let previousDestination = try #require(FileManager.default.contents(atPath: destinationURL.path))
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(calls.totalCalls == 1)
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 13)
        #expect(previousDestination.count == 4)
    }

    @Test func startupQueuedDownloadWithNilExpectedBytesAndPartialExistingDestinationRetriesInsteadOfAutoCompleting() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-partial-existing-destination-without-expected-bytes.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("partial-existing-destination-without-expected.mkv", isDirectory: false)
        try Data(repeating: 0x24, count: 5).write(to: destinationURL)

        let callTracker = DownloadCallTracker()
        let task = DownloadTask(
            id: "startup-partial-existing-destination-no-expected",
            mediaId: "tt-startup-partial-existing-no-expected",
            streamURL: "https://cdn.example.com/startup-partial-existing-no-expected.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .downloading,
            bytesWritten: 5,
            totalBytes: 16,
            destinationPath: destinationURL.path,
            expectedBytes: nil
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x34, count: 16).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-partial-existing-no-expected.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 16,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let calls = await callTracker.snapshot()
        let finalDestination = try #require(completed.destinationPath)
        let previousDestination = try #require(FileManager.default.contents(atPath: destinationURL.path))
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(calls.totalCalls == 1)
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 16)
        #expect(previousDestination.count == 5)
    }

    @Test func startupQueuedDownloadWithPartialExistingDestinationAndResumeDataUsesResumeData() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-partial-existing-destination-uses-resume-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("partial-existing-resume-data.mkv", isDirectory: false)
        try Data(repeating: 0x39, count: 4).write(to: destinationURL)

        let recorder = DownloadCallTracker()
        let transferRecorder = TransferRequestRecorder()
        let resumeData = Data("startup-partial-resume-data".utf8)

        let task = DownloadTask(
            id: "startup-partial-existing-resume-data",
            mediaId: "tt-startup-partial-existing-resume-data",
            streamURL: "https://cdn.example.com/startup-partial-existing-resume-data.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .queued,
            bytesWritten: 4,
            totalBytes: 12,
            destinationPath: destinationURL.path,
            expectedBytes: 12,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await recorder.recordStart()
                defer { Task { await recorder.recordFinish() } }
                await transferRecorder.record(request: request)

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x71, count: 12).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-partial-existing-resume-data.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 12,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let calls = await recorder.snapshot()
        let request = try #require(await transferRecorder.snapshot().first)
        let finalDestination = try #require(completed.destinationPath)
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(calls.totalCalls == 1)
        #expect(request.usedResumeData)
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 12)
    }

    @Test func startupQueuedDownloadWithOversizedExistingDestinationRetriesInsteadOfAutoCompleting() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-oversized-existing-destination.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("oversized-existing-destination.mkv", isDirectory: false)
        try Data(repeating: 0x25, count: 20).write(to: destinationURL)

        let callTracker = DownloadCallTracker()
        let task = DownloadTask(
            id: "startup-oversized-existing-destination",
            mediaId: "tt-startup-oversized-existing",
            streamURL: "https://cdn.example.com/startup-oversized-existing.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .downloading,
            bytesWritten: 13,
            totalBytes: 13,
            destinationPath: destinationURL.path,
            expectedBytes: 13
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x36, count: 13).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-oversized-existing.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 13,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let calls = await callTracker.snapshot()
        let finalDestination = try #require(completed.destinationPath)
        let previousDestination = try #require(FileManager.default.contents(atPath: destinationURL.path))
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(calls.totalCalls == 1)
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 13)
        #expect(previousDestination.count == 20)
    }

    @Test func startupQueuedDownloadWithZeroLengthExistingDestinationRetriesAndRedownloads() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-empty-existing-destination.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("empty-existing-destination.mkv", isDirectory: false)
        try Data().write(to: destinationURL)

        let callTracker = DownloadCallTracker()
        let task = DownloadTask(
            id: "startup-empty-existing-destination",
            mediaId: "tt-startup-empty-existing",
            streamURL: "https://cdn.example.com/startup-empty-existing.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .queued,
            bytesWritten: 0,
            totalBytes: 9,
            destinationPath: destinationURL.path,
            expectedBytes: 9
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x37, count: 9).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-empty-existing.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 9,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let calls = await callTracker.snapshot()
        let finalDestination = try #require(completed.destinationPath)
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(calls.totalCalls == 1)
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 9)
    }

    @Test func startupResolvingDownloadWithPartialExistingDestinationRetriesInsteadOfAutoCompleting() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resolving-partial-existing-destination.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("partial-existing-resolving-destination.mkv", isDirectory: false)
        try Data(repeating: 0x42, count: 6).write(to: destinationURL)

        let callTracker = DownloadCallTracker()
        let task = DownloadTask(
            id: "startup-resolving-partial-existing-destination",
            mediaId: "tt-startup-resolving-partial-existing",
            streamURL: "https://cdn.example.com/startup-resolving-partial-existing.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .resolving,
            bytesWritten: 6,
            totalBytes: 14,
            destinationPath: destinationURL.path,
            expectedBytes: 14
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x43, count: 14).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-resolving-partial-existing.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 14,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let calls = await callTracker.snapshot()
        let finalDestination = try #require(completed.destinationPath)
        let previousDestination = try #require(FileManager.default.contents(atPath: destinationURL.path))
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(calls.totalCalls == 1)
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 14)
        #expect(previousDestination.count == 6)
    }

    @Test func startupResolvingDownloadWithPartialExistingDestinationAndResumeDataUsesResumeData() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resolving-partial-existing-destination-resume-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("partial-existing-resolving-resume-data.mkv", isDirectory: false)
        try Data(repeating: 0x44, count: 6).write(to: destinationURL)

        let recorder = DownloadCallTracker()
        let transferRecorder = TransferRequestRecorder()
        let resumeData = Data("startup-resolving-partial-resume-data".utf8)

        let task = DownloadTask(
            id: "startup-resolving-partial-existing-resume-data",
            mediaId: "tt-startup-resolving-partial-existing-resume-data",
            streamURL: "https://cdn.example.com/startup-resolving-partial-existing-resume-data.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .resolving,
            bytesWritten: 6,
            totalBytes: 15,
            destinationPath: destinationURL.path,
            expectedBytes: 15,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await recorder.recordStart()
                defer { Task { await recorder.recordFinish() } }
                await transferRecorder.record(request: request)

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x45, count: 15).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-resolving-partial-existing-resume-data.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 15,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let calls = await recorder.snapshot()
        let request = try #require(await transferRecorder.snapshot().first)
        let finalDestination = try #require(completed.destinationPath)
        let previousDestination = try #require(FileManager.default.contents(atPath: destinationURL.path))
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(calls.totalCalls == 1)
        #expect(request.usedResumeData)
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 15)
        #expect(previousDestination.count == 6)
    }

    @Test func startupResolvingDownloadWithNilExpectedBytesAndPartialExistingDestinationRetriesInsteadOfAutoCompleting() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resolving-partial-existing-destination-no-expected.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("partial-existing-resolving-no-expected.mkv", isDirectory: false)
        try Data(repeating: 0x4A, count: 6).write(to: destinationURL)

        let callTracker = DownloadCallTracker()
        let task = DownloadTask(
            id: "startup-resolving-partial-existing-no-expected",
            mediaId: "tt-startup-resolving-partial-no-expected",
            streamURL: "https://cdn.example.com/startup-resolving-partial-no-expected.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .resolving,
            bytesWritten: 6,
            totalBytes: 14,
            destinationPath: destinationURL.path,
            expectedBytes: nil
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x4B, count: 14).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-resolving-partial-no-expected.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 14,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let calls = await callTracker.snapshot()
        let finalDestination = try #require(completed.destinationPath)
        let previousDestination = try #require(FileManager.default.contents(atPath: destinationURL.path))
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(calls.totalCalls == 1)
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 14)
        #expect(previousDestination.count == 6)
    }

    @Test func startupResolvingDownloadWithUsableResumeDataAndUnusableURLFallsBackToResumeData() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resolving-partial-existing-destination-unusable-url-resume-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("partial-existing-resolving-unusable-url-resume-data.mkv", isDirectory: false)
        try Data(repeating: 0x4C, count: 6).write(to: destinationURL)

        let transferRecorder = TransferRequestRecorder()
        let resumeData = Data("startup-resolving-partial-unusable-resume-data".utf8)

        let task = DownloadTask(
            id: "startup-resolving-partial-unusable-url-resume-data",
            mediaId: "tt-startup-resolving-partial-unusable-url-resume-data",
            streamURL: "https://",
            fileName: destinationURL.lastPathComponent,
            status: .resolving,
            bytesWritten: 6,
            totalBytes: 15,
            destinationPath: destinationURL.path,
            expectedBytes: 15,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await transferRecorder.record(request: request)

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x4D, count: 15).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-resolving-partial-unusable-url-resume-data.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 15,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let request = try #require(await transferRecorder.snapshot().first)
        let finalDestination = try #require(completed.destinationPath)
        let previousDestination = try #require(FileManager.default.contents(atPath: destinationURL.path))
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(request.usedResumeData)
        #expect(request.url == "https://")
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 15)
        #expect(previousDestination.count == 6)
    }

    @Test func startupResolvingDownloadWithoutUsableStreamWithoutRecoveryFails() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resolving-no-url-fails.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let callTracker = DownloadCallTracker()

        let invalid = DownloadTask(
            id: "startup-resolving-no-url-fails",
            mediaId: "tt-startup-resolving-no-url-fails",
            streamURL: "https://",
            fileName: "startup-resolving-no-url-fails.mkv",
            status: .resolving,
            expectedBytes: 64
        )
        try await database.saveDownloadTask(invalid)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer { Task { await callTracker.recordFinish() } }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x4E, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/resolving-no-url.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let failed = try await waitForStatus(database: database, id: invalid.id, expected: .failed)
        #expect(failed.errorMessage != nil)
        #expect(await callTracker.snapshot().totalCalls == 0)
    }

    @Test func startupDownloadingDownloadWithPartialExistingDestinationRetriesInsteadOfAutoCompleting() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-downloading-partial-existing-destination-retries.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("partial-downloading-existing-destination.mkv", isDirectory: false)
        try Data(repeating: 0x52, count: 6).write(to: destinationURL)

        let callTracker = DownloadCallTracker()
        let task = DownloadTask(
            id: "startup-downloading-partial-existing-destination",
            mediaId: "tt-startup-downloading-partial-existing",
            streamURL: "https://cdn.example.com/startup-downloading-partial-existing.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .downloading,
            bytesWritten: 6,
            totalBytes: 14,
            destinationPath: destinationURL.path,
            expectedBytes: 14
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer {
                    Task { await callTracker.recordFinish() }
                }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x53, count: 14).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-downloading-partial-existing.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 14,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let calls = await callTracker.snapshot()
        let finalDestination = try #require(completed.destinationPath)
        let previousDestination = try #require(FileManager.default.contents(atPath: destinationURL.path))
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(calls.totalCalls == 1)
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 14)
        #expect(previousDestination.count == 6)
    }

    @Test func startupDownloadingDownloadWithPartialExistingDestinationAndResumeDataUsesResumeData() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-downloading-partial-existing-resume-data-retries.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destinationURL = downloadsDir.appendingPathComponent("partial-downloading-existing-destination-resume-data.mkv", isDirectory: false)
        try Data(repeating: 0x54, count: 6).write(to: destinationURL)

        let transferRecorder = TransferRequestRecorder()
        let resumeData = Data("startup-downloading-partial-resume-data".utf8)

        let task = DownloadTask(
            id: "startup-downloading-partial-existing-resume-data",
            mediaId: "tt-startup-downloading-partial-existing-resume-data",
            streamURL: "https://cdn.example.com/startup-downloading-partial-existing-resume-data.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .downloading,
            bytesWritten: 6,
            totalBytes: 15,
            destinationPath: destinationURL.path,
            expectedBytes: 15,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(task)

        let _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await transferRecorder.record(request: request)

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x55, count: 15).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-downloading-partial-existing-resume-data.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 15,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: task.id, expected: .completed)
        let request = try #require(await transferRecorder.snapshot().first)
        let finalDestination = try #require(completed.destinationPath)
        let previousDestination = try #require(FileManager.default.contents(atPath: destinationURL.path))
        let finalDestinationContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(request.usedResumeData)
        #expect(finalDestination != destinationURL.path)
        #expect(finalDestinationContents.count == 15)
        #expect(previousDestination.count == 6)
    }

    @Test func startupDownloadingDownloadWithoutUsableStreamWithoutRecoveryFails() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-downloading-no-url-fails.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let callTracker = DownloadCallTracker()

        let invalid = DownloadTask(
            id: "startup-downloading-no-url-fails",
            mediaId: "tt-startup-downloading-no-url-fails",
            streamURL: "://",
            fileName: "startup-downloading-no-url-fails.mkv",
            status: .downloading,
            expectedBytes: 64
        )
        try await database.saveDownloadTask(invalid)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer { Task { await callTracker.recordFinish() } }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x57, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/downloading-no-url.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let failed = try await waitForStatus(database: database, id: invalid.id, expected: .failed)
        #expect(failed.errorMessage != nil)
        #expect(await callTracker.snapshot().totalCalls == 0)
    }

    @Test func resumePersistedResolvingTaskWithExistingDestinationCompletesWithoutPerformer() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-resume-resolving-existing-destination.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let destinationURL = downloadsDir.appendingPathComponent("existing-resolving-destination.mkv", isDirectory: false)
        try Data(repeating: 0x22, count: 13).write(to: destinationURL)

        let tracker = DownloadCallTracker()
        let completedViaDestination = DownloadTask(
            id: "resume-existing-destination-resolving",
            mediaId: "tt-resume-existing-resolving",
            streamURL: "https://cdn.example.com/resume-existing-resolving.mkv",
            fileName: destinationURL.lastPathComponent,
            status: .resolving,
            bytesWritten: 4,
            totalBytes: 13,
            destinationPath: destinationURL.path,
            expectedBytes: 13
        )
        let queuedToStart = DownloadTask(
            id: "resume-resolving-should-start",
            mediaId: "tt-resume-existing-resolving",
            streamURL: "https://cdn.example.com/resume-start.mkv",
            fileName: "resume-start.mkv",
            status: .resolving,
            expectedBytes: 13,
            createdAt: Date(timeIntervalSince1970: 1_700_020_001)
        )
        try await database.saveDownloadTask(completedViaDestination)
        try await database.saveDownloadTask(queuedToStart)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await tracker.recordStart()
                defer {
                    Task { await tracker.recordFinish() }
                }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x33, count: 13).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/resume-start.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 13,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            maxConcurrentTransfers: 1,
            availableDiskSpace: Self.ampleDiskSpace
        )

        _ = try await waitForStatus(database: database, id: completedViaDestination.id, expected: .completed)
        _ = try await waitForStatus(database: database, id: queuedToStart.id, expected: .completed)

        let completedTask = try #require(await database.fetchDownloadTask(id: completedViaDestination.id))
        #expect(completedTask.destinationPath == destinationURL.path)
        #expect(completedTask.progress == 1.0)
        #expect(await tracker.snapshot().totalCalls == 1)

        _ = manager
    }

    @Test func startupQueuedRecoveryBackedDownloadUsesRefreshedURLAndCompletes() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-recovery-startup-refreshes-link.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)

        let freshURL = URL(string: "https://cdn.example.com/refresh-fresh.mkv?token=fresh")!
        let refresherCounter = AttemptCounter()
        let requestRecorder = RequestOrderRecorder()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "abcdefabcdefabcdefabcdefabcdefabcdefab12",
                preferredService: .realDebrid
            )
        )
        let recoveryContextJSON = try String(decoding: JSONEncoder().encode(recoveryContext), as: UTF8.self)

        let persisted = DownloadTask(
            id: "startup-recovery-refresh",
            mediaId: "tt-startup-recovery-refresh",
            streamURL: nil,
            fileName: "startup-recovery-refresh.mkv",
            status: .queued,
            recoveryContextJSON: recoveryContextJSON,
            expectedBytes: 256
        )
        try await database.saveDownloadTask(persisted)

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await requestRecorder.record(request)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x60, count: 256)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? freshURL,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            linkRefresher: { _ in
                _ = await refresherCounter.next()
                return freshURL
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)

        #expect(completed.streamURL == "")
        #expect(completed.persistedStreamURL == nil)
        #expect(completed.destinationPath != nil)
        #expect(await requestRecorder.snapshot() == [freshURL.absoluteString])
        #expect(await refresherCounter.snapshot() == 1)
        _ = manager
    }

    @Test func startupRecoveryBackedDownloadWithExpiredLinkRefreshFailurePreservesFailureStatusAndClearsReplayState() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-recovery-startup-refresh-fails-clears-state.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let attemptCounter = AttemptCounter()
        let refresherCounter = AttemptCounter()

        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "aaaaabbbbbcccccddddd11111222223333344444",
                preferredService: .realDebrid
            )
        )
        let recoveryContextJSON = try String(decoding: JSONEncoder().encode(recoveryContext), as: UTF8.self)
        let stalePayload = Data("stale-resume".utf8)

        let persisted = DownloadTask(
            id: "startup-recovery-refresh-fail",
            mediaId: "tt-startup-recovery-refresh-fail",
            streamURL: "https://cdn.example.com/refresh-fails.mkv?token=stale",
            fileName: "startup-recovery-refresh-fail.mkv",
            status: .queued,
            recoveryContextJSON: recoveryContextJSON,
            expectedBytes: 128,
            resumeDataBase64: stalePayload.base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                _ = await attemptCounter.next()
                throw DownloadTransferError.badHTTPStatus(403)
            },
            linkRefresher: { _ in
                _ = await refresherCounter.next()
                throw DownloadTransferError.badHTTPStatus(451)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let failed = try await waitForStatus(database: database, id: persisted.id, expected: .failed)
        #expect(failed.status == .failed)
        #expect(failed.persistedStreamURL == nil)
        #expect(failed.resumeData == nil)
        #expect(failed.errorMessage != nil)
        #expect(await attemptCounter.snapshot() == 0)
        #expect(await refresherCounter.snapshot() == 1)
        #expect(failed.updatedAt > persisted.createdAt)
    }

    @Test func startupRecoveryBackedQueuedTaskWithoutRefresherFailsForUnusableURL() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-recovery-startup-invalid-url-fails.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let callTracker = DownloadCallTracker()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "0123456789abcdef0123456789abcdef01234567",
                preferredService: .realDebrid
            )
        )
        let recoveryContextJSON = try String(decoding: JSONEncoder().encode(recoveryContext), as: UTF8.self)

        let invalidTask = DownloadTask(
            id: "startup-recovery-invalid-url",
            mediaId: "tt-startup-recovery-invalid-url",
            streamURL: "https://",
            fileName: "startup-recovery-invalid-url.mkv",
            status: .queued,
            recoveryContextJSON: recoveryContextJSON,
            expectedBytes: 128
        )
        try await database.saveDownloadTask(invalidTask)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer { Task { await callTracker.recordFinish() } }
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x61, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/invalid.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let failed = try await waitForStatus(database: database, id: invalidTask.id, expected: .failed)
        #expect(failed.errorMessage != nil)
        #expect(await callTracker.snapshot().totalCalls == 0)
    }

    @Test func startupRecoveryBackedResolvingTaskWithPersistedResumeDataAndUnusableURLFallsBackToResumeData() async throws {
        let (database, rootDir) = try await makeDatabase(
            named: "download-manager-recovery-startup-resolving-resume-data-unusable-url.sqlite"
        )
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let transferRecorder = TransferRequestRecorder()
        let resumeData = Data("startup-recovery-resolve-resume-data".utf8)

        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "abcdeffedcba0123456789abcdeffedcba01234567",
                preferredService: .realDebrid
            )
        )
        let recoveryContextJSON = try String(decoding: JSONEncoder().encode(recoveryContext), as: UTF8.self)

        let persisted = DownloadTask(
            id: "startup-recovery-resolving-resume-data-unusable-url",
            mediaId: "tt-startup-recovery-resolving-resume-data-unusable-url",
            streamURL: "https://",
            fileName: "startup-recovery-resolving-resume-data-unusable-url.mkv",
            status: .resolving,
            recoveryContextJSON: recoveryContextJSON,
            expectedBytes: 9,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await transferRecorder.record(request: request)

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x4F, count: 9).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-recovery-resolving-resume-data-unusable-url.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 9,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        let request = try #require(await transferRecorder.snapshot().first)
        let finalDestination = try #require(completed.destinationPath)
        let finalContents = try #require(FileManager.default.contents(atPath: finalDestination))

        #expect(request.usedResumeData)
        #expect(request.url == "https://")
        #expect(request.requestHeaders == nil)
        #expect(finalContents.count == 9)
        #expect(completed.status == .completed)
    }

    @Test func cancelActiveRecoveryBackedDownloadInvokesRemoteCleanupAndCancelsTask() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-cancel-active-recovery-cleanup.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let cleanupRecorder = RemoteCleanupRecorder()
        let callTracker = DownloadCallTracker()

        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "1234567890abcdef1234567890abcdef12345678",
                preferredService: .realDebrid
            )
        )
        let stream = makeStream(name: "cancel-active-cleanup.mkv", recoveryContext: recoveryContext)
        let expectedCleanupContext = recoveryContext.enrichedForDownloadPersistence(
            fileName: stream.fileName,
            sizeBytes: stream.sizeBytes,
            debridService: DebridServiceType.realDebrid.rawValue
        )

        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, cancellationController in
                await callTracker.recordStart()
                defer { Task { await callTracker.recordFinish() } }

                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
                    cancellationController.register {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            },
            remoteTransferCleaner: { context in
                await cleanupRecorder.record(context)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let active = try await manager.enqueueDownload(
            stream: stream,
            mediaId: "tt-cancel-active-cleanup",
            episodeId: nil as String?
        )

        _ = try await waitForStatus(database: database, id: active.id, expected: .downloading)

        await manager.cancelDownload(id: active.id)
        let cancelled = try await waitForStatus(database: database, id: active.id, expected: .cancelled)
        let calls = await callTracker.snapshot()
        let cleanupContexts = await cleanupRecorder.snapshot()

        #expect(cancelled.status == .cancelled)
        #expect(cancelled.errorMessage == nil)
        #expect(calls.totalCalls == 1)
        #expect(cleanupContexts == [expectedCleanupContext])
    }

    @Test func startupRecoveryBackedResolvingTaskWithoutRefresherFailsForUnusableURL() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-recovery-startup-resolving-invalid-url-fails.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let callTracker = DownloadCallTracker()
        let recoveryContext = try #require(
            StreamRecoveryContext(
                infoHash: "fedcba9876543210fedcba9876543210fedcba98",
                preferredService: .realDebrid
            )
        )
        let recoveryContextJSON = try String(decoding: JSONEncoder().encode(recoveryContext), as: UTF8.self)

        let invalid = DownloadTask(
            id: "startup-recovery-invalid-url-resolving",
            mediaId: "tt-startup-recovery-invalid-url-resolving",
            streamURL: "https://",
            fileName: "startup-recovery-invalid-url-resolving.mkv",
            status: .resolving,
            recoveryContextJSON: recoveryContextJSON,
            expectedBytes: 128
        )
        try await database.saveDownloadTask(invalid)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer { Task { await callTracker.recordFinish() } }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x62, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/invalid-resolving.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let failed = try await waitForStatus(database: database, id: invalid.id, expected: .failed)
        #expect(failed.errorMessage != nil)
        #expect(await callTracker.snapshot().totalCalls == 0)
    }

    @Test func startupQueuedDownloadWithPersistedResumeDataUsesResumeDataAndCompletes() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resume-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let callTracker = DownloadCallTracker()
        let resumeDataRecorder = ResumeDataUsageRecorder()

        let resumeData = Data("startup-resume-data".utf8)
        let persisted = DownloadTask(
            id: "startup-resume-data",
            mediaId: "tt-startup-resume-data",
            streamURL: nil,
            fileName: "startup-resume-data.mkv",
            status: .queued,
            progress: 0,
            bytesWritten: 0,
            totalBytes: 768,
            expectedBytes: 768,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await callTracker.recordStart()
                await resumeDataRecorder.record(request)

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x70, count: 768)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-resume-data.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        #expect(completed.status == DownloadStatus.completed)
        #expect(await callTracker.snapshot().totalCalls == 1)
        #expect(await resumeDataRecorder.snapshot())
    }

    @Test func startupQueuedDownloadWithMalformedStreamAndResumeDataUsesResumeDataAndCompletes() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-resume-data-malformed-url.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let callTracker = DownloadCallTracker()
        let resumeDataRecorder = ResumeDataUsageRecorder()

        let resumeData = Data("startup-resume-data-malformed-url".utf8)
        let persisted = DownloadTask(
            id: "startup-resume-data-malformed-url",
            mediaId: "tt-startup-resume-data-malformed-url",
            streamURL: "::::",
            fileName: "startup-resume-data-malformed-url.mkv",
            status: .queued,
            progress: 0,
            bytesWritten: 0,
            totalBytes: 768,
            expectedBytes: 768,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await callTracker.recordStart()
                await resumeDataRecorder.record(request)

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x71, count: 768)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/startup-resume-data-malformed-url.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        #expect(completed.status == DownloadStatus.completed)
        #expect(await callTracker.snapshot().totalCalls == 1)
        #expect(await resumeDataRecorder.snapshot())
    }

    @Test func startupQueuedDownloadWithoutUsableStreamWithoutRecoveryFails() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-no-url-fails.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let callTracker = DownloadCallTracker()

        let invalid = DownloadTask(
            id: "startup-no-url-fails",
            mediaId: "tt-startup-no-url-fails",
            streamURL: "",
            fileName: "startup-no-url-fails.mkv",
            status: .queued,
            expectedBytes: 64
        )
        try await database.saveDownloadTask(invalid)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { _, _, _ in
                await callTracker.recordStart()
                defer { Task { await callTracker.recordFinish() } }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try Data(repeating: 0x71, count: 1).write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/no-url.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: 1,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let failed = try await waitForStatus(database: database, id: invalid.id, expected: .failed)
        #expect(failed.errorMessage != nil)
        #expect(await callTracker.snapshot().totalCalls == 0)
    }

    @Test func startupInFlightDownloadWithPersistedResumeDataUsesResumeData() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-downloading-resume-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let transferRecorder = TransferRequestRecorder()

        let resumeData = Data("downloading-resume-data".utf8)
        let persisted = DownloadTask(
            id: "startup-downloading-resume-data",
            mediaId: "tt-startup-downloading-resume-data",
            streamURL: "https://cdn.example.com/downloading-resume-data.mkv",
            fileName: "downloading-resume-data.mkv",
            status: .downloading,
            progress: 0.2,
            bytesWritten: 128,
            totalBytes: 1_024,
            mediaTitle: "Downloading Resume Data",
            expectedBytes: 1_024,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await transferRecorder.record(request: request)

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x72, count: 1_024)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: request.url ?? URL(string: "https://cdn.example.com/downloading-resume-data.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        let request = try #require(await transferRecorder.snapshot().first)

        #expect(completed.status == .completed)
        #expect(completed.resumeData == nil)
        #expect(completed.bytesWritten == 1_024)
        #expect(request.usedResumeData)
        #expect(request.url == "https://cdn.example.com/downloading-resume-data.mkv")
    }

    @Test func startupInFlightDownloadWithResumeDataButNoUsableURLFallsBackToResumeData() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-startup-downloading-resume-data-no-url.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let callTracker = DownloadCallTracker()
        let transferRecorder = TransferRequestRecorder()

        let resumeData = Data("resume-data-only".utf8)
        let persisted = DownloadTask(
            id: "startup-downloading-resume-data-no-url",
            mediaId: "tt-startup-downloading-resume-data-no-url",
            streamURL: nil,
            fileName: "downloading-resume-data-no-url.mkv",
            status: .downloading,
            expectedBytes: 1_024,
            resumeDataBase64: resumeData.base64EncodedString()
        )
        try await database.saveDownloadTask(persisted)

        _ = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            performer: { request, _, _ in
                await callTracker.recordStart()
                await transferRecorder.record(request: request)

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let data = Data(repeating: 0x73, count: 1_024)
                try data.write(to: tempURL)
                let response = URLResponse(
                    url: URL(string: "https://cdn.example.com/downloading-resume-data-no-url.mkv")!,
                    mimeType: "video/x-matroska",
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                return (tempURL, response)
            },
            availableDiskSpace: Self.ampleDiskSpace
        )

        let completed = try await waitForStatus(database: database, id: persisted.id, expected: .completed)
        let request = try #require(await transferRecorder.snapshot().first)

        #expect(completed.status == .completed)
        #expect(completed.resumeData == nil)
        #expect(request.usedResumeData)
        #expect(request.url == nil)
        #expect(await callTracker.snapshot().totalCalls == 1)
    }

    @Test func diskSpaceProviderFailureRejectsNewDownload() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-manager-disk-space-provider-failure.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let downloadsDir = rootDir.appendingPathComponent("downloads", isDirectory: true)
        let manager = DownloadManager(
            database: database,
            downloadsDirectory: downloadsDir,
            availableDiskSpace: { _ in
                throw QueueingDiskProbeError.unavailable
            }
        )

        var didThrow = false
        do {
            _ = try await manager.enqueueDownload(
                stream: makeStream(name: "probe-fail.mkv"),
                mediaId: "tt-probe-fail",
                episodeId: nil as String?
            )
        } catch is QueueingDiskProbeError {
            didThrow = true
        }

        #expect(didThrow)
        let tasks = try await manager.listDownloads()
        #expect(tasks.isEmpty)
    }

    private func makeDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, rootDir)
    }

    private func waitForAnyStatus(
        database: DatabaseManager,
        ids: [String],
        expected: DownloadStatus,
        timeoutSeconds: TimeInterval = 10
    ) async throws -> String {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            for id in ids {
                if let task = try await database.fetchDownloadTask(id: id), task.status == expected {
                    return id
                }
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        throw NSError(domain: "DownloadManagerQueueingCoverageTests", code: 2)
    }

    private func waitForQueuedAndDownloadingCounts(
        database: DatabaseManager,
        ids: [String],
        expectedQueued: Int,
        expectedDownloading: Int,
        timeoutSeconds: TimeInterval = 10
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            let tasks = try await fetchTasks(database: database, ids: ids)
            if tasks.count == ids.count &&
                tasks.values.filter({ $0.status == .queued }).count == expectedQueued &&
                tasks.values.filter({ $0.status == .downloading }).count == expectedDownloading {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        let finalStates = try await fetchTasks(database: database, ids: ids)
        let finalSummary = finalStates
            .sorted { lhs, rhs in lhs.key < rhs.key }
            .map { "\( $0.value.id):\($0.value.status.rawValue)" }
            .joined(separator: ", ")
        throw TimeoutStatusError(
            message: "Timed out waiting for queued/downloading distribution. Expected queued=\(expectedQueued), downloading=\(expectedDownloading). Observed: [\(finalSummary)]"
        )
    }

    private func fetchTasks(database: DatabaseManager, ids: [String]) async throws -> [String: DownloadTask] {
        var tasks: [String: DownloadTask] = [:]
        for id in ids {
            if let task = try await database.fetchDownloadTask(id: id) {
                tasks[id] = task
            }
        }
        return tasks
    }

    private func waitForAllStatus(
        database: DatabaseManager,
        ids: [String],
        expected: DownloadStatus,
        timeoutSeconds: TimeInterval = 10
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            let tasks = try await fetchTasks(database: database, ids: ids)
            if tasks.count == ids.count, tasks.values.allSatisfy({ $0.status == expected }) {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        let finalTasks = try await fetchTasks(database: database, ids: ids)
        let finalStatuses = finalTasks
            .sorted { lhs, rhs in
                if lhs.key == rhs.key { return false }
                return lhs.key < rhs.key
            }
            .map { "\( $0.value.id):\($0.value.status.rawValue)"}
            .joined(separator: ", ")
        throw TimeoutStatusError(message: "Timed out waiting for all tasks to be \(expected). Observed: [\(finalStatuses)]")
    }

    private func waitForCallCount(
        _ tracker: DownloadCallTracker,
        expectedTotalCalls: Int,
        timeoutSeconds: TimeInterval = 10
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            if await tracker.snapshot().totalCalls >= expectedTotalCalls {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }

        let snapshot = await tracker.snapshot()
        throw TimeoutStatusError(
            message: "Timed out waiting for \(expectedTotalCalls) transfer calls. Observed totalCalls=\(snapshot.totalCalls)."
        )
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

        throw NSError(domain: "DownloadManagerQueueingCoverageTests", code: 1)
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
}
