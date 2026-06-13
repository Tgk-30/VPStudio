import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct DownloadDatabaseTests {
    @Test func migrationSupportsDownloadTaskCRUDRoundTrip() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-roundtrip.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let task = DownloadTask(
            id: "download-1",
            mediaId: "tt123",
            episodeId: "ep-1",
            streamURL: "https://cdn.example.com/a.mkv",
            fileName: "a.mkv",
            status: .queued,
            progress: 0,
            bytesWritten: 0,
            totalBytes: nil,
            destinationPath: nil,
            errorMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await database.saveDownloadTask(task)

        let fetched = try await database.fetchDownloadTask(id: task.id)
        #expect(fetched?.id == task.id)
        #expect(fetched?.status == .queued)

        try await database.updateDownloadTaskProgress(
            id: task.id,
            progress: 0.42,
            bytesWritten: 420,
            totalBytes: 1000,
            destinationPath: "/tmp/a.mkv"
        )
        try await database.updateDownloadTaskStatus(id: task.id, status: .downloading, errorMessage: nil)

        let updated = try await database.fetchDownloadTask(id: task.id)
        #expect(updated?.progress == 0.42)
        #expect(updated?.status == .downloading)
        #expect(updated?.destinationPath == "/tmp/a.mkv")

        try await database.deleteDownloadTask(id: task.id)
        let deleted = try await database.fetchDownloadTask(id: task.id)
        #expect(deleted == nil)
    }

    @Test func claimDownloadTaskForDownloadStartWorksOnce() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-claim-start-once.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let task = DownloadTask(
            id: "download-claim-once",
            mediaId: "tt-claim-once",
            streamURL: "https://cdn.example.com/claim-once.mkv",
            fileName: "claim-once.mkv",
            status: .queued,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await database.saveDownloadTask(task)
        let firstClaim = try await database.claimDownloadTaskForDownloadStart(id: task.id)
        let secondClaim = try await database.claimDownloadTaskForDownloadStart(id: task.id)
        let missingClaim = try await database.claimDownloadTaskForDownloadStart(id: "missing-task")

        let updated = try await database.fetchDownloadTask(id: task.id)

        #expect(firstClaim)
        #expect(!secondClaim)
        #expect(!missingClaim)
        #expect(updated?.status == .downloading)
    }

    @Test func claimDownloadTaskForDownloadStartIgnoresTerminalTask() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-claim-start-terminal.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let completed = DownloadTask(
            id: "download-claim-terminal",
            mediaId: "tt-claim-terminal",
            streamURL: "https://cdn.example.com/claim-terminal.mkv",
            fileName: "claim-terminal.mkv",
            status: .completed,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await database.saveDownloadTask(completed)
        let wasClaimed = try await database.claimDownloadTaskForDownloadStart(id: completed.id)
        let updated = try await database.fetchDownloadTask(id: completed.id)

        #expect(!wasClaimed)
        #expect(updated?.status == .completed)
    }

    @Test func claimDownloadTaskForDownloadStartIsAtomicUnderConcurrency() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-claim-start-concurrent.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let task = DownloadTask(
            id: "download-claim-concurrent",
            mediaId: "tt-claim-concurrent",
            streamURL: "https://cdn.example.com/claim-concurrent.mkv",
            fileName: "claim-concurrent.mkv",
            status: .queued,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await database.saveDownloadTask(task)

        try await withThrowingTaskGroup(of: Bool.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    return try await database.claimDownloadTaskForDownloadStart(id: task.id)
                }
            }

            var successCount = 0
            for try await claimed in group {
                if claimed {
                    successCount += 1
                }
            }

            #expect(successCount == 1)
        }

        let updated = try await database.fetchDownloadTask(id: task.id)
        #expect(updated?.status == .downloading)
    }

    @Test func statusUpdateRefreshesUpdatedAt() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-updated-at.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let initialDate = Date(timeIntervalSince1970: 1_000)
        let task = DownloadTask(
            id: "download-2",
            mediaId: "tt456",
            episodeId: nil,
            streamURL: "https://cdn.example.com/b.mkv",
            fileName: "b.mkv",
            status: .queued,
            progress: 0,
            bytesWritten: 0,
            totalBytes: nil,
            destinationPath: nil,
            errorMessage: nil,
            createdAt: initialDate,
            updatedAt: initialDate
        )

        try await database.saveDownloadTask(task)
        try await Task.sleep(for: .milliseconds(10))
        try await database.updateDownloadTaskStatus(id: task.id, status: .failed, errorMessage: "failed")

        let updated = try await database.fetchDownloadTask(id: task.id)
        #expect(updated?.status == .failed)
        #expect((updated?.updatedAt ?? initialDate) > initialDate)
    }

    @Test func updateDownloadTaskStatusCompletedClearsReplayableStateAndForcesProgress() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-update-status-completed.sql")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let initialDate = Date(timeIntervalSince1970: 2_400)
        let payload = Data("complete-me".utf8)
        let task = DownloadTask(
            id: "download-status-complete",
            mediaId: "tt462",
            episodeId: nil,
            streamURL: "https://cdn.example.com/complete.mkv?token=secret",
            fileName: "complete.mkv",
            status: .downloading,
            progress: 0.42,
            bytesWritten: 420,
            totalBytes: 1_024,
            destinationPath: nil,
            errorMessage: "in progress",
            resumeDataBase64: payload.base64EncodedString(),
            createdAt: initialDate,
            updatedAt: initialDate
        )

        try await database.saveDownloadTask(task)
        try await Task.sleep(for: .milliseconds(10))
        try await database.updateDownloadTaskStatus(
            id: task.id,
            status: .completed,
            errorMessage: "done"
        )

        let updated = try await database.fetchDownloadTask(id: task.id)
        #expect(updated?.status == .completed)
        #expect(updated?.progress == 1.0)
        #expect(updated?.persistedStreamURL == nil)
        #expect(updated?.resumeData == nil)
        #expect(updated?.errorMessage == "done")
        #expect(updated?.bytesWritten == 420)
        #expect(updated?.updatedAt != initialDate)
    }

    @Test func updateDownloadTaskStatusFailedPreservesReplayableFields() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-update-status-failed.sql")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let initialDate = Date(timeIntervalSince1970: 2_500)
        let payload = Data("preserve-me".utf8)
        let task = DownloadTask(
            id: "download-status-failed",
            mediaId: "tt463",
            episodeId: nil,
            streamURL: "https://cdn.example.com/failed.mkv",
            fileName: "failed.mkv",
            status: .downloading,
            progress: 0.77,
            bytesWritten: 770,
            totalBytes: 1_024,
            destinationPath: nil,
            errorMessage: nil,
            resumeDataBase64: payload.base64EncodedString(),
            createdAt: initialDate,
            updatedAt: initialDate
        )

        try await database.saveDownloadTask(task)
        try await database.updateDownloadTaskStatus(id: task.id, status: .failed, errorMessage: "network lost")

        let updated = try await database.fetchDownloadTask(id: task.id)
        #expect(updated?.status == .failed)
        #expect(updated?.progress == 0.77)
        #expect(updated?.persistedStreamURL == "https://cdn.example.com/failed.mkv")
        #expect(updated?.resumeData == payload)
        #expect(updated?.errorMessage == "network lost")
        #expect(updated?.updatedAt != initialDate)
    }

    @Test func updateDownloadTaskProgressDoesNotAffectTerminalStatuses() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-progress-terminal-guard.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let initialDate = Date(timeIntervalSince1970: 1_100)
        let task = DownloadTask(
            id: "download-terminal-progress",
            mediaId: "tt457",
            episodeId: nil,
            streamURL: "https://cdn.example.com/terminal-progress.mkv",
            fileName: "terminal-progress.mkv",
            status: .failed,
            progress: 0.25,
            bytesWritten: 125,
            totalBytes: 500,
            destinationPath: nil,
            errorMessage: "failed before test",
            createdAt: initialDate,
            updatedAt: initialDate
        )

        try await database.saveDownloadTask(task)
        try await database.updateDownloadTaskProgress(
            id: task.id,
            progress: 0.9,
            bytesWritten: 900,
            totalBytes: 1_000
        )

        let updated = try await database.fetchDownloadTask(id: task.id)
        #expect(updated?.status == .failed)
        #expect(updated?.progress == 0.25)
        #expect(updated?.bytesWritten == 125)
        #expect(updated?.totalBytes == 500)
        #expect(updated?.updatedAt == initialDate)
    }

    @Test func updateDownloadTaskStreamURLSkipsCompletedTasks() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-stream-url-completed-guard.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let initialDate = Date(timeIntervalSince1970: 2_000)
        let task = DownloadTask(
            id: "download-stream-url-guard",
            mediaId: "tt458",
            episodeId: nil,
            streamURL: "https://cdn.example.com/before.mkv",
            fileName: "before.mkv",
            status: .completed,
            progress: 1.0,
            bytesWritten: 10,
            totalBytes: 10,
            destinationPath: nil,
            errorMessage: nil,
            createdAt: initialDate,
            updatedAt: initialDate
        )

        try await database.saveDownloadTask(task)
        try await database.updateDownloadTaskStreamURL(
            id: task.id,
            streamURL: "https://cdn.example.com/attempted-update.mkv"
        )

        let updated = try await database.fetchDownloadTask(id: task.id)
        #expect(updated?.status == .completed)
        #expect(updated?.persistedStreamURL == nil)
        #expect(updated?.updatedAt != initialDate)
    }

    @Test func updateDownloadTaskStreamURLNormalizesWhitespace() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-stream-url-whitespace.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let initialDate = Date(timeIntervalSince1970: 2_100)
        let task = DownloadTask(
            id: "download-stream-url-normalize",
            mediaId: "tt459",
            episodeId: nil,
            streamURL: "https://cdn.example.com/untrimmed.mkv",
            fileName: "untrimmed.mkv",
            status: .queued,
            progress: 0,
            bytesWritten: 0,
            totalBytes: nil,
            destinationPath: nil,
            errorMessage: nil,
            createdAt: initialDate,
            updatedAt: initialDate
        )

        try await database.saveDownloadTask(task)
        try await database.updateDownloadTaskStreamURL(
            id: task.id,
            streamURL: "   https://cdn.example.com/trimmed.mkv   "
        )

        let updated = try await database.fetchDownloadTask(id: task.id)
        #expect(updated?.persistedStreamURL == "https://cdn.example.com/trimmed.mkv")
    }

    @Test func updateDownloadTaskResumeDataRejectsInvalidBase64() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-resume-data-invalid-base64.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let initialDate = Date(timeIntervalSince1970: 2_200)
        let task = DownloadTask(
            id: "download-resume-data-invalid-base64",
            mediaId: "tt460",
            episodeId: nil,
            streamURL: "https://cdn.example.com/resume-invalid-base64.mkv",
            fileName: "resume-invalid-base64.mkv",
            status: .queued,
            progress: 0,
            bytesWritten: 0,
            totalBytes: nil,
            destinationPath: nil,
            errorMessage: nil,
            createdAt: initialDate,
            updatedAt: initialDate
        )

        try await database.saveDownloadTask(task)
        try await database.updateDownloadTaskResumeData(
            id: task.id,
            resumeDataBase64: "not-base64!!"
        )

        let updated = try await database.fetchDownloadTask(id: task.id)
        #expect(updated?.resumeData == nil)
        #expect(updated?.persistedStreamURL == task.streamURL)
    }

    @Test func clearDownloadTaskReplayableTransportStateRemovesStreamURLAndResumeData() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-clear-replayable-transport-state.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let payload = Data("replayable-state".utf8)
        let initialDate = Date(timeIntervalSince1970: 2_300)
        let task = DownloadTask(
            id: "download-clear-replayable",
            mediaId: "tt461",
            episodeId: nil,
            streamURL: "https://cdn.example.com/replayable-clear.mkv",
            fileName: "replayable-clear.mkv",
            status: .downloading,
            progress: 0.1,
            bytesWritten: 7,
            totalBytes: 99,
            destinationPath: nil,
            errorMessage: nil,
            resumeDataBase64: payload.base64EncodedString(),
            createdAt: initialDate,
            updatedAt: initialDate
        )

        try await database.saveDownloadTask(task)
        try await database.clearDownloadTaskReplayableTransportState(id: task.id)

        let cleared = try await database.fetchDownloadTask(id: task.id)
        #expect(cleared?.persistedStreamURL == nil)
        #expect(cleared?.resumeData == nil)
        #expect(cleared?.status == .downloading)
    }

    @Test func recoveryBackedTasksPersistWithoutReplayableTransportState() async throws {
        let (database, rootDir) = try await makeDatabase(named: "download-db-recovery-redaction.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let context = try #require(
            StreamRecoveryContext(
                infoHash: "00112233445566778899aabbccddeeff00112233",
                preferredService: .realDebrid
            )
        )

        let task = DownloadTask(
            id: "download-redacted",
            mediaId: "tt999",
            streamURL: nil,
            fileName: "episode.mkv",
            status: .queued,
            progress: 0,
            bytesWritten: 0,
            totalBytes: nil,
            destinationPath: nil,
            errorMessage: nil,
            mediaTitle: "Episode",
            mediaType: "series",
            recoveryContextJSON: try context.jsonString(),
            expectedBytes: 1_024,
            resumeDataBase64: Data("resume".utf8).base64EncodedString(),
            createdAt: Date(),
            updatedAt: Date()
        )

        try await database.saveDownloadTask(task.redactedForRecoveryBackedPersistence)
        let fetched = try #require(try await database.fetchDownloadTask(id: task.id))
        #expect(fetched.persistedStreamURL == nil)
        #expect(fetched.resumeData == nil)
        #expect(fetched.recoveryContext?.infoHash == context.infoHash)
    }

    private func makeDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, rootDir)
    }
}
