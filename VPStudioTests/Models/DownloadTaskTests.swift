import Testing
import Foundation
import GRDB
@testable import VPStudio

@Suite("DownloadTask Status Transitions")
struct DownloadTaskStatusTests {
    @Test("Terminal statuses are correctly identified")
    func terminalStatuses() {
        #expect(DownloadStatus.completed.isTerminal == true)
        #expect(DownloadStatus.failed.isTerminal == true)
        #expect(DownloadStatus.cancelled.isTerminal == true)
        #expect(DownloadStatus.queued.isTerminal == false)
        #expect(DownloadStatus.resolving.isTerminal == false)
        #expect(DownloadStatus.downloading.isTerminal == false)
    }
}

@Suite("DownloadTask Progress Math")
struct DownloadTaskProgressTests {
    @Test("Progress is normalized to 0-1 range")
    func progressNormalization() {
        let task1 = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            status: .downloading,
            progress: -0.5
        )
        #expect(task1.progress == 0)

        let task2 = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            status: .downloading,
            progress: 1.5
        )
        #expect(task2.progress == 1)

        let task3 = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            status: .downloading,
            progress: 0.5
        )
        #expect(task3.progress == 0.5)
    }

    @Test("Completed status forces progress to 1")
    func completedProgress() {
        let task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            status: .completed,
            progress: 0.5
        )
        #expect(task.progress == 1)
    }
}

@Suite("DownloadTask ID Generation")
struct DownloadTaskIDTests {
    @Test("Default ID is generated")
    func defaultIDGeneration() {
        let task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4"
        )
        #expect(!task.id.isEmpty)
    }

    @Test("Custom ID is preserved")
    func customIDPreservation() {
        let customID = "custom-id-123"
        let task = DownloadTask(
            id: customID,
            mediaId: "test",
            fileName: "test.mp4"
        )
        #expect(task.id == customID)
    }
}

@Suite("DownloadTask Display Title")
struct DownloadTaskDisplayTitleTests {
    @Test("Episode display title with season and episode")
    func episodeDisplayTitle() {
        let task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            seasonNumber: 1,
            episodeNumber: 5,
            episodeTitle: "The Pilot"
        )
        #expect(task.displayTitle == "S01E05 - The Pilot")
    }

    @Test("Episode display title without episode title")
    func episodeDisplayTitleNoTitle() {
        let task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            seasonNumber: 2,
            episodeNumber: 10
        )
        #expect(task.displayTitle == "S02E10")
    }

    @Test("Movie display title uses media title")
    func movieDisplayTitle() {
        let task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            mediaTitle: "Inception"
        )
        #expect(task.displayTitle == "Inception")
    }

    @Test("Fallback to filename when media title is empty")
    func fallbackToFilename() {
        let task = DownloadTask(
            mediaId: "test",
            fileName: "movie.mp4",
            mediaTitle: ""
        )
        #expect(task.displayTitle == "movie.mp4")
    }
}

@Suite("DownloadTask Episode Sort Key")
struct DownloadTaskEpisodeSortKeyTests {
    @Test("Sort key calculation")
    func sortKeyCalculation() {
        let task1 = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            seasonNumber: 1,
            episodeNumber: 5
        )
        #expect(task1.episodeSortKey == 10005)

        let task2 = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            seasonNumber: 3,
            episodeNumber: 15
        )
        #expect(task2.episodeSortKey == 30015)

        let task3 = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            seasonNumber: nil,
            episodeNumber: nil
        )
        #expect(task3.episodeSortKey == 0)
    }
}

@Suite("DownloadTask URL Normalization")
struct DownloadTaskURLNormalizationTests {
    @Test("Stream URL is normalized for non-completed status")
    func streamURLNormalization() {
        let task = DownloadTask(
            mediaId: "test",
            streamURL: "  https://example.com/file.mp4  ",
            fileName: "test.mp4",
            status: .downloading
        )
        #expect(task.streamURL == "https://example.com/file.mp4")
    }

    @Test("Stream URL is nil for completed status")
    func completedStreamURL() {
        let task = DownloadTask(
            mediaId: "test",
            streamURL: "https://example.com/file.mp4",
            fileName: "test.mp4",
            status: .completed
        )
        #expect(task.streamURL.isEmpty)
    }

    @Test("Empty stream URL becomes nil")
    func emptyStreamURL() {
        let task = DownloadTask(
            mediaId: "test",
            streamURL: "",
            fileName: "test.mp4",
            status: .downloading
        )
        #expect(task.streamURL == "")
        #expect(task.persistedStreamURL == nil)
    }

    @Test("Stream URL setter trims and clears according to current status")
    func streamURLSetterNormalizesAgainstCurrentStatus() {
        var task = DownloadTask(
            mediaId: "test",
            streamURL: "https://example.com/initial.mp4",
            fileName: "test.mp4",
            status: .downloading
        )

        task.streamURL = "  https://example.com/updated.mp4  "
        #expect(task.streamURL == "https://example.com/updated.mp4")
        #expect(task.persistedStreamURL == "https://example.com/updated.mp4")

        task.streamURL = " \n "
        #expect(task.streamURL == "")
        #expect(task.persistedStreamURL == nil)

        task.status = .completed
        task.streamURL = "https://example.com/completed.mp4"
        #expect(task.streamURL == "")
        #expect(task.persistedStreamURL == nil)
    }
}

@Suite("DownloadTask Destination URL")
struct DownloadTaskDestinationURLTests {
    @Test("Destination URL reflects the destination path")
    func destinationURLReflectsPath() {
        let task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            destinationPath: "/tmp/video file.mp4"
        )

        #expect(task.destinationURL?.path == "/tmp/video file.mp4")
    }

    @Test("Destination URL is nil without a destination path")
    func destinationURLNilWithoutPath() {
        let task = DownloadTask(mediaId: "test", fileName: "test.mp4")

        #expect(task.destinationURL == nil)
    }
}

@Suite("DownloadTask Resume Data")
struct DownloadTaskResumeDataTests {
    @Test("Resume data is normalized for non-completed status")
    func resumeDataNormalization() {
        let base64Data = "SGVsbG8gV29ybGQ="
        let task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            status: .downloading,
            resumeDataBase64: "  " + base64Data + "  "
        )
        #expect(task.resumeData != nil)
        #expect(task.resumeDataBase64 == base64Data)
    }

    @Test("Resume data is nil for completed status")
    func completedResumeData() {
        let task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            status: .completed,
            resumeDataBase64: "SGVsbG8gV29ybGQ="
        )
        #expect(task.resumeData == nil)
        #expect(task.resumeDataBase64 == nil)
    }

    @Test("Invalid base64 resume data becomes nil")
    func invalidResumeData() {
        let task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            status: .downloading,
            resumeDataBase64: "invalid-base64!"
        )
        #expect(task.resumeData == nil)
        #expect(task.resumeDataBase64 == nil)
    }

    @Test("Resume data setter stores base64 and clears nil values")
    func resumeDataSetterNormalizesData() {
        var task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            status: .downloading
        )
        let resume = Data("resume-token".utf8)

        task.resumeData = resume
        #expect(task.resumeData == resume)
        #expect(task.resumeDataBase64 == resume.base64EncodedString())

        task.resumeData = nil
        #expect(task.resumeData == nil)
        #expect(task.resumeDataBase64 == nil)
    }

    @Test("Resume data setter redacts completed tasks")
    func resumeDataSetterRedactsCompletedTask() {
        var task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            status: .completed
        )

        task.resumeData = Data("resume-token".utf8)

        #expect(task.resumeData == nil)
        #expect(task.resumeDataBase64 == nil)
    }
}

@Suite("DownloadTask Byte Count Normalization")
struct DownloadTaskByteCountTests {
    @Test("Zero or negative byte counts become nil")
    func zeroByteCount() {
        let task1 = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            totalBytes: 0
        )
        #expect(task1.totalBytes == nil)

        let task2 = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            totalBytes: -100
        )
        #expect(task2.totalBytes == nil)
    }

    @Test("Positive byte counts are preserved")
    func positiveByteCount() {
        let task = DownloadTask(
            mediaId: "test",
            fileName: "test.mp4",
            totalBytes: 1024
        )
        #expect(task.totalBytes == 1024)
    }
}

@Suite("DownloadTask Persistence Views")
struct DownloadTaskPersistenceViewTests {
    @Test("Redacted persistence clears stream URL and resume data")
    func redactedPersistenceClearsSensitiveFields() {
        var task = DownloadTask(
            mediaId: "test",
            streamURL: "https://example.com/private.mp4?token=secret",
            fileName: "test.mp4",
            status: .downloading,
            resumeDataBase64: Data("resume-token".utf8).base64EncodedString()
        )
        task.resumeData = Data("new-resume-token".utf8)

        let redacted = task.redactedForRecoveryBackedPersistence

        #expect(redacted.streamURL == "")
        #expect(redacted.persistedStreamURL == nil)
        #expect(redacted.resumeData == nil)
        #expect(redacted.resumeDataBase64 == nil)
        #expect(redacted.mediaId == task.mediaId)
        #expect(redacted.fileName == task.fileName)
    }
}

@Suite("DownloadTask Codable Round-Trip")
struct DownloadTaskCodableTests {
    @Test("DownloadTask encodes and decodes correctly")
    func codableRoundTrip() throws {
        let originalTask = DownloadTask(
            id: "test-id",
            mediaId: "media-123",
            episodeId: "episode-456",
            streamURL: "https://example.com/stream.mp4",
            fileName: "movie.mp4",
            status: .downloading,
            progress: 0.75,
            bytesWritten: 512,
            totalBytes: 1024,
            destinationPath: "/downloads/movie.mp4",
            errorMessage: nil,
            mediaTitle: "Test Movie",
            mediaType: "movie",
            posterPath: "/poster.jpg",
            seasonNumber: 1,
            episodeNumber: 5,
            episodeTitle: "Pilot",
            recoveryContextJSON: nil,
            expectedBytes: 1024,
            resumeDataBase64: "SGVsbG8gV29ybGQ=",
            createdAt: Date(timeIntervalSince1970: 123456789),
            updatedAt: Date(timeIntervalSince1970: 123456790)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalTask)
        let decoder = JSONDecoder()
        let decodedTask = try decoder.decode(DownloadTask.self, from: data)

        #expect(decodedTask.id == originalTask.id)
        #expect(decodedTask.mediaId == originalTask.mediaId)
        #expect(decodedTask.episodeId == originalTask.episodeId)
        #expect(decodedTask.streamURL == originalTask.streamURL)
        #expect(decodedTask.fileName == originalTask.fileName)
        #expect(decodedTask.status == originalTask.status)
        #expect(decodedTask.progress == originalTask.progress)
        #expect(decodedTask.bytesWritten == originalTask.bytesWritten)
        #expect(decodedTask.totalBytes == originalTask.totalBytes)
        #expect(decodedTask.destinationPath == originalTask.destinationPath)
        #expect(decodedTask.mediaTitle == originalTask.mediaTitle)
        #expect(decodedTask.mediaType == originalTask.mediaType)
        #expect(decodedTask.posterPath == originalTask.posterPath)
        #expect(decodedTask.seasonNumber == originalTask.seasonNumber)
        #expect(decodedTask.episodeNumber == originalTask.episodeNumber)
        #expect(decodedTask.episodeTitle == originalTask.episodeTitle)
        #expect(decodedTask.expectedBytes == originalTask.expectedBytes)
        #expect(decodedTask.resumeDataBase64 == originalTask.resumeDataBase64)
    }

    @Test("DownloadTask with minimal data encodes and decodes")
    func minimalCodableRoundTrip() throws {
        let originalTask = DownloadTask(
            mediaId: "media-123",
            fileName: "movie.mp4"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalTask)
        let decoder = JSONDecoder()
        let decodedTask = try decoder.decode(DownloadTask.self, from: data)

        #expect(decodedTask.mediaId == originalTask.mediaId)
        #expect(decodedTask.fileName == originalTask.fileName)
        #expect(decodedTask.status == .queued)
        #expect(decodedTask.progress == 0)
    }
}

@Suite("DownloadTask Row Initialization")
struct DownloadTaskRowInitializationTests {
    @Test("Row initializer normalizes malformed stored values")
    func rowInitializerNormalizesMalformedStoredValues() {
        let createdAt = Date(timeIntervalSince1970: 123)
        let row = Row([
            "id": "row-task",
            "mediaId": nil,
            "episodeId": "episode-1",
            "streamURL": "  https://example.com/private.mkv?token=secret  ",
            "fileName": "   ",
            "status": "not-a-status",
            "progress": Float(1.7),
            "bytesWritten": Int64(-25),
            "totalBytes": Int64(0),
            "destinationPath": "/downloads/private.mkv",
            "errorMessage": "stored error",
            "mediaTitle": nil,
            "mediaType": nil,
            "posterPath": "/poster.jpg",
            "seasonNumber": 1,
            "episodeNumber": 2,
            "episodeTitle": "Pilot",
            "recoveryContextJSON": "not-json",
            "expectedBytes": Int64(-50),
            "resumeDataBase64": Data("resume".utf8).base64EncodedString(),
            "createdAt": createdAt,
            "updatedAt": nil,
        ])

        let task = DownloadTask(row: row)

        #expect(task.id == "row-task")
        #expect(task.mediaId == "")
        #expect(task.fileName == "download-row-task.mp4")
        #expect(task.status == .queued)
        #expect(task.progress == 1)
        #expect(task.bytesWritten == 0)
        #expect(task.totalBytes == nil)
        #expect(task.expectedBytes == nil)
        #expect(task.streamURL == "https://example.com/private.mkv?token=secret")
        #expect(task.mediaTitle == "")
        #expect(task.mediaType == "movie")
        #expect(task.recoveryContext == nil)
        #expect(task.resumeData == Data("resume".utf8))
        #expect(task.updatedAt == createdAt)
    }

    @Test("Row initializer redacts completed-task sensitive state")
    func rowInitializerRedactsCompletedSensitiveState() {
        let row = Row([
            "id": nil,
            "mediaId": "movie-1",
            "episodeId": nil,
            "streamURL": "https://example.com/private.mkv?token=secret",
            "fileName": nil,
            "status": DownloadStatus.completed.rawValue,
            "progress": Int64(0),
            "bytesWritten": 42,
            "totalBytes": Int64(42),
            "destinationPath": nil,
            "errorMessage": nil,
            "mediaTitle": "Movie",
            "mediaType": "movie",
            "posterPath": nil,
            "seasonNumber": nil,
            "episodeNumber": nil,
            "episodeTitle": nil,
            "recoveryContextJSON": nil,
            "expectedBytes": Int64(42),
            "resumeDataBase64": Data("resume".utf8).base64EncodedString(),
            "createdAt": nil,
            "updatedAt": nil,
        ])

        let task = DownloadTask(row: row)

        #expect(!task.id.isEmpty)
        #expect(task.fileName.hasPrefix("download-"))
        #expect(task.fileName.hasSuffix(".mp4"))
        #expect(task.status == .completed)
        #expect(task.progress == 1)
        #expect(task.bytesWritten == 42)
        #expect(task.totalBytes == 42)
        #expect(task.expectedBytes == 42)
        #expect(task.streamURL.isEmpty)
        #expect(task.persistedStreamURL == nil)
        #expect(task.resumeData == nil)
        #expect(task.resumeDataBase64 == nil)
    }
}

@Suite("DownloadTask Database Round-Trip")
struct DownloadTaskDatabaseRoundTripTests {
    private func makeTempDatabase() async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "download-task-test-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test func roundTripsThroughDatabaseManager() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(
            id: "test-task-1",
            mediaId: "movie-123",
            fileName: "test.mp4",
            status: .downloading,
            progress: 0.5
        )
        try await database.saveDownloadTask(task)
        let fetched = try await database.fetchDownloadTask(id: "test-task-1")

        #expect(fetched != nil)
        #expect(fetched?.id == task.id)
        #expect(fetched?.mediaId == task.mediaId)
        #expect(fetched?.fileName == task.fileName)
        #expect(fetched?.status == task.status)
        #expect(fetched?.progress == task.progress)
    }

    @Test
    func downloadTaskWithAllFieldsRoundTripsCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(
            id: "full-task",
            mediaId: "series-456",
            streamURL: "file:///tmp/test.mkv",
            fileName: "Show.S01E01.720p.mkv",
            status: .downloading,
            progress: 0.5,
            bytesWritten: 1_000_000,
            totalBytes: 1_000_000,
            seasonNumber: 1,
            episodeNumber: 1,
            episodeTitle: "Pilot Episode"
        )
        try await database.saveDownloadTask(task)
        let fetched = try await database.fetchDownloadTask(id: "full-task")

        #expect(fetched != nil)
        #expect(fetched?.seasonNumber == 1)
        #expect(fetched?.episodeNumber == 1)
        #expect(fetched?.episodeTitle == "Pilot Episode")
        #expect(fetched?.totalBytes == 1_000_000)
        #expect(fetched?.bytesWritten == 1_000_000)
        #expect(fetched?.streamURL == "file:///tmp/test.mkv")
    }

    @Test
    func multipleDownloadTasksRoundTripCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let tasks = [
            DownloadTask(id: "task-a", mediaId: "m1", fileName: "a.mp4", status: .queued),
            DownloadTask(id: "task-b", mediaId: "m2", fileName: "b.mp4", status: .downloading, progress: 0.3),
            DownloadTask(id: "task-c", mediaId: "m3", fileName: "c.mp4", status: .completed)
        ]

        for task in tasks {
            try await database.saveDownloadTask(task)
        }

        let fetched = try await database.fetchDownloadTasks()
        #expect(fetched.count == 3)
        #expect(fetched.contains { $0.id == "task-a" })
        #expect(fetched.contains { $0.id == "task-b" })
        #expect(fetched.contains { $0.id == "task-c" })
    }

    @Test
    func downloadTaskStatusUpdatesPersist() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(id: "status-test", mediaId: "m1", fileName: "test.mp4", status: .queued)
        try await database.saveDownloadTask(task)

        try await database.updateDownloadTaskStatus(id: "status-test", status: .downloading, errorMessage: nil)
        let updated = try await database.fetchDownloadTask(id: "status-test")
        #expect(updated?.status == .downloading)
    }

    @Test
    func downloadTaskProgressUpdatesPersist() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(id: "progress-test", mediaId: "m1", fileName: "test.mp4", status: .downloading, progress: 0)
        try await database.saveDownloadTask(task)

        try await database.updateDownloadTaskProgress(id: "progress-test", progress: 0.75, bytesWritten: 750_000, totalBytes: 1_000_000)
        let updated = try await database.fetchDownloadTask(id: "progress-test")
        #expect(updated?.progress == 0.75)
    }

    @Test
    func deletedDownloadTaskDoesNotExist() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let task = DownloadTask(id: "to-delete", mediaId: "m1", fileName: "test.mp4", status: .queued)
        try await database.saveDownloadTask(task)
        try await database.deleteDownloadTask(id: "to-delete")

        let fetched = try await database.fetchDownloadTask(id: "to-delete")
        #expect(fetched == nil)
    }
}
