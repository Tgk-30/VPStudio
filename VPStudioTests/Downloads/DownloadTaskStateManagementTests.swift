import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct DownloadTaskStateManagementTests {
    @Test func downloadTaskIdGeneration() {
        let task1 = DownloadTask(mediaId: "tt123", fileName: "test.mkv")
        #expect(!task1.id.isEmpty)

        let task2 = DownloadTask(id: "custom-id", mediaId: "tt456", fileName: "test2.mkv")
        #expect(task2.id == "custom-id")
    }

    @Test func downloadTaskDefaultValues() {
        let task = DownloadTask(mediaId: "tt001", fileName: "default.mkv")

        #expect(task.status == .queued)
        #expect(task.progress == 0)
        #expect(task.bytesWritten == 0)
        #expect(task.totalBytes == nil)
        #expect(task.destinationPath == nil)
        #expect(task.errorMessage == nil)
        #expect(task.mediaTitle == "")
        #expect(task.mediaType == "movie")
        #expect(task.posterPath == nil)
        #expect(task.seasonNumber == nil)
        #expect(task.episodeNumber == nil)
        #expect(task.episodeTitle == nil)
        #expect(task.recoveryContextJSON == nil)
        #expect(task.expectedBytes == nil)
        #expect(task.resumeDataBase64 == nil)
    }

    @Test func downloadTaskWithAllParameters() {
        let now = Date()
        let task = DownloadTask(
            id: "full-task",
            mediaId: "tt002",
            episodeId: "ep-1",
            streamURL: "https://cdn.example.com/video.mkv",
            fileName: "video.mkv",
            status: .downloading,
            progress: 0.5,
            bytesWritten: 500,
            totalBytes: 1000,
            destinationPath: "/path/to/video.mkv",
            errorMessage: nil,
            mediaTitle: "My Video",
            mediaType: "series",
            posterPath: "/poster.jpg",
            seasonNumber: 1,
            episodeNumber: 5,
            episodeTitle: "Episode 5",
            recoveryContextJSON: "{\"infoHash\":\"abc123\"}",
            expectedBytes: 1000,
            resumeDataBase64: "resumeData",
            createdAt: now,
            updatedAt: now
        )

        #expect(task.id == "full-task")
        #expect(task.mediaId == "tt002")
        #expect(task.episodeId == "ep-1")
        #expect(task.streamURL == "https://cdn.example.com/video.mkv")
        #expect(task.status == .downloading)
        #expect(task.progress == 0.5)
        #expect(task.bytesWritten == 500)
        #expect(task.totalBytes == 1000)
        #expect(task.destinationPath == "/path/to/video.mkv")
        #expect(task.mediaTitle == "My Video")
        #expect(task.mediaType == "series")
        #expect(task.posterPath == "/poster.jpg")
        #expect(task.seasonNumber == 1)
        #expect(task.episodeNumber == 5)
        #expect(task.episodeTitle == "Episode 5")
        #expect(task.expectedBytes == 1000)
    }

    @Test func downloadTaskPosterURL() {
        let task1 = DownloadTask(mediaId: "tt001", fileName: "test.mkv", posterPath: "/p/w500/abc.jpg")
        #expect(task1.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w342/p/w500/abc.jpg")

        let task2 = DownloadTask(mediaId: "tt002", fileName: "test.mkv")
        #expect(task2.posterURL == nil)

        let task3 = DownloadTask(mediaId: "tt003", fileName: "test.mkv", posterPath: "https://m.media-amazon.com/images/M/poster.jpg")
        #expect(task3.posterURL?.absoluteString == "https://m.media-amazon.com/images/M/poster.jpg")
    }

    @Test func downloadTaskEpisodeSortKey() {
        let task1 = DownloadTask(mediaId: "tt001", fileName: "test.mkv", seasonNumber: 1, episodeNumber: 5)
        #expect(task1.episodeSortKey == 10005)

        let task2 = DownloadTask(mediaId: "tt002", fileName: "test.mkv", seasonNumber: 5, episodeNumber: 12)
        #expect(task2.episodeSortKey == 50012)

        let task3 = DownloadTask(mediaId: "tt003", fileName: "test.mkv")
        #expect(task3.episodeSortKey == 0)
    }

    @Test func downloadTaskWithRecoveryContext() throws {
        let context = StreamRecoveryContext(
            infoHash: "abcd1234abcd1234abcd1234abcd1234",
            preferredService: .realDebrid,
            seasonNumber: 2,
            episodeNumber: 10
        )!

        let task = DownloadTask(
            mediaId: "tt-recovery",
            fileName: "recovery.mkv",
            recoveryContextJSON: try String(data: JSONEncoder().encode(context), encoding: .utf8)!
        )

        #expect(task.recoveryContext != nil)
        #expect(task.recoveryContext?.infoHash == context.infoHash)
        #expect(task.recoveryContext?.seasonNumber == 2)
        #expect(task.recoveryContext?.episodeNumber == 10)
    }

    @Test func recoveryContextSetterClearsNilAndIgnoresMalformedJSON() {
        var task = DownloadTask(
            mediaId: "tt-recovery-setter",
            fileName: "recovery-setter.mkv",
            recoveryContextJSON: "{not-json"
        )

        #expect(task.recoveryContext == nil)

        let context = StreamRecoveryContext(
            infoHash: "setter-hash-1234567890abcdef",
            preferredService: .realDebrid
        )!

        task.recoveryContext = context
        #expect(task.recoveryContext == context)

        task.recoveryContext = nil
        #expect(task.recoveryContext == nil)
        #expect(task.recoveryContextJSON == nil)
    }

    @Test func downloadTaskResumeDataPersistence() {
        let task1 = DownloadTask(
            mediaId: "tt-resume",
            fileName: "resume.mkv",
            status: .downloading,
            resumeDataBase64: Data("test-resume".utf8).base64EncodedString()
        )

        #expect(task1.resumeData == Data("test-resume".utf8))

        // Normalization to nil only happens at init time, not on status mutation
        let task2 = DownloadTask(
            mediaId: "tt-resume",
            fileName: "resume.mkv",
            status: .completed,
            resumeDataBase64: Data("test-resume".utf8).base64EncodedString()
        )
        #expect(task2.resumeData == nil)
        #expect(task2.resumeDataBase64 == nil)
    }

    @Test func resumeDataSetterPersistsValidDataAndClearsNil() {
        var task = DownloadTask(
            mediaId: "tt-resume-setter",
            fileName: "resume-setter.mkv",
            status: .downloading
        )

        task.resumeData = Data("resume-payload".utf8)
        #expect(task.resumeData == Data("resume-payload".utf8))
        #expect(task.resumeDataBase64 == Data("resume-payload".utf8).base64EncodedString())

        task.resumeData = nil
        #expect(task.resumeData == nil)
        #expect(task.resumeDataBase64 == nil)
    }

    @Test func downloadTaskStreamURLPersistence() {
        let task1 = DownloadTask(
            mediaId: "tt-stream",
            streamURL: "https://cdn.example.com/stream.mkv?token=secret",
            fileName: "stream.mkv",
            status: .downloading
        )

        #expect(task1.persistedStreamURL == "https://cdn.example.com/stream.mkv?token=secret")

        // Normalization to nil only happens at init time, not on status mutation
        let task2 = DownloadTask(
            mediaId: "tt-stream",
            streamURL: "https://cdn.example.com/stream.mkv?token=secret",
            fileName: "stream.mkv",
            status: .completed
        )
        #expect(task2.persistedStreamURL == nil)
    }

    @Test func streamURLSetterTrimsBlankAndRespectsCompletedStatus() {
        var task = DownloadTask(
            mediaId: "tt-stream-setter",
            fileName: "stream-setter.mkv",
            status: .downloading
        )

        task.streamURL = "  https://cdn.example.com/stream-setter.mkv  "
        #expect(task.persistedStreamURL == "https://cdn.example.com/stream-setter.mkv")

        task.streamURL = " \n "
        #expect(task.persistedStreamURL == nil)

        task.status = .completed
        task.streamURL = "https://cdn.example.com/final.mkv"
        #expect(task.streamURL == "")
        #expect(task.persistedStreamURL == nil)
    }

    @Test func downloadTaskWithExpectedBytes() {
        let task1 = DownloadTask(
            mediaId: "tt-bytes",
            fileName: "bytes.mkv",
            expectedBytes: 5_000_000
        )
        #expect(task1.expectedBytes == 5_000_000)

        let task2 = DownloadTask(
            mediaId: "tt-bad-bytes",
            fileName: "bad-bytes.mkv",
            expectedBytes: -100
        )
        #expect(task2.expectedBytes == nil)
    }

    @Test func downloadTaskEqualityById() {
        let now = Date()
        let task1 = DownloadTask(
            id: "same-id",
            mediaId: "tt001",
            fileName: "name1.mkv",
            status: .queued,
            progress: 0,
            bytesWritten: 0,
            createdAt: now,
            updatedAt: now
        )

        let task2 = DownloadTask(
            id: "same-id",
            mediaId: "tt002",
            fileName: "name2.mkv",
            status: .completed,
            progress: 1,
            bytesWritten: 1000,
            createdAt: now.addingTimeInterval(100),
            updatedAt: now.addingTimeInterval(100)
        )

        // Equatable is auto-synthesized comparing all properties, not just id
        #expect(task1 != task2)
    }

    @Test func downloadTaskRedactedForRecoveryPersistence() throws {
        let context = StreamRecoveryContext(
            infoHash: "secret-hash-1234567890abcdef",
            preferredService: .realDebrid
        )!

        let task = DownloadTask(
            mediaId: "tt-redact",
            streamURL: "https://cdn.example.com/stream.mkv?token=secret",
            fileName: "redact.mkv",
            status: .downloading,
            progress: 0.5,
            recoveryContextJSON: try JSONEncoder().encode(context).base64EncodedString(),
            resumeDataBase64: Data("resume-secret".utf8).base64EncodedString()
        )

        let redacted = task.redactedForRecoveryBackedPersistence

        #expect(redacted.persistedStreamURL == nil)
        #expect(redacted.resumeDataBase64 == nil)
        #expect(redacted.recoveryContextJSON == task.recoveryContextJSON)
    }

    @Test func downloadTaskSanitizedForPersistence() {
        let task = DownloadTask(
            mediaId: "tt-sanitize",
            fileName: "  trimmed.mkv  ",
            status: .queued
        )

        let sanitized = task.sanitizedForPersistence

        // sanitizedForPersistence copies values without trimming
        #expect(sanitized.fileName == "  trimmed.mkv  ")
    }

    @Test func downloadTaskWithEmptyMediaTitleUsesFilename() {
        let task1 = DownloadTask(mediaId: "tt-empty", fileName: "movie.mkv", mediaTitle: "")
        #expect(task1.displayTitle == "movie.mkv")

        let task2 = DownloadTask(mediaId: "tt-title", fileName: "movie.mkv", mediaTitle: "The Matrix")
        #expect(task2.displayTitle == "The Matrix")
    }

    @Test func downloadTaskCodableRoundTrip() throws {
        let original = DownloadTask(
            id: "codable-test",
            mediaId: "tt-codable",
            episodeId: "ep-1",
            streamURL: "https://cdn.example.com/video.mkv",
            fileName: "video.mkv",
            status: .downloading,
            progress: 0.75,
            bytesWritten: 750,
            totalBytes: 1000,
            destinationPath: "/path/to/video.mkv",
            errorMessage: "no error",
            mediaTitle: "Test Video",
            mediaType: "series",
            posterPath: "/poster.jpg",
            seasonNumber: 1,
            episodeNumber: 3,
            episodeTitle: "Test Episode",
            recoveryContextJSON: "{\"infoHash\":\"abc\"}",
            expectedBytes: 1000,
            resumeDataBase64: "cmVzdW1l",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DownloadTask.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.mediaId == original.mediaId)
        #expect(decoded.episodeId == original.episodeId)
        #expect(decoded.status == original.status)
        #expect(decoded.progress == 0.75)
        #expect(decoded.mediaTitle == original.mediaTitle)
        #expect(decoded.seasonNumber == original.seasonNumber)
        #expect(decoded.episodeNumber == original.episodeNumber)
    }

    @Test func downloadTaskDecodingNormalizesQueuedUnsafeValues() throws {
        let payload: [String: Any] = [
            "id": "decode-queued-normalized",
            "mediaId": "tt-decode",
            "streamURL": " \n ",
            "fileName": "decode.mkv",
            "status": "queued",
            "progress": -0.25,
            "bytesWritten": -50,
            "totalBytes": 0,
            "mediaTitle": "Decoded",
            "mediaType": "movie",
            "expectedBytes": -1,
            "resumeDataBase64": "not-base64",
            "createdAt": 0.0,
            "updatedAt": 1.0,
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoded = try JSONDecoder().decode(DownloadTask.self, from: data)

        #expect(decoded.status == .queued)
        #expect(decoded.progress == 0)
        #expect(decoded.bytesWritten == 0)
        #expect(decoded.totalBytes == nil)
        #expect(decoded.expectedBytes == nil)
        #expect(decoded.persistedStreamURL == nil)
        #expect(decoded.resumeDataBase64 == nil)
    }

    @Test func downloadTaskDecodingCompletedClearsReplayableState() throws {
        let payload: [String: Any] = [
            "id": "decode-completed-normalized",
            "mediaId": "tt-decode-completed",
            "streamURL": " https://cdn.example.com/signed.mkv ",
            "fileName": "completed.mkv",
            "status": "completed",
            "progress": 0.25,
            "bytesWritten": 500,
            "totalBytes": 1_000,
            "mediaTitle": "Completed",
            "mediaType": "movie",
            "expectedBytes": 1_000,
            "resumeDataBase64": Data("resume".utf8).base64EncodedString(),
            "createdAt": 0.0,
            "updatedAt": 1.0,
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoded = try JSONDecoder().decode(DownloadTask.self, from: data)

        #expect(decoded.status == .completed)
        #expect(decoded.progress == 1)
        #expect(decoded.bytesWritten == 500)
        #expect(decoded.totalBytes == 1_000)
        #expect(decoded.expectedBytes == 1_000)
        #expect(decoded.persistedStreamURL == nil)
        #expect(decoded.streamURL == "")
        #expect(decoded.resumeData == nil)
        #expect(decoded.resumeDataBase64 == nil)
    }

    @Test func downloadTaskRowInit() async throws {
        let task = DownloadTask(
            mediaId: "tt-row",
            fileName: "row-test.mkv",
            status: .queued,
            progress: 0.25
        )

        let database = try DatabaseManager(inMemoryNamed: "download-task-row-\(UUID().uuidString)")
        try await database.migrate()

        try await database.saveDownloadTask(task)
        let fetched = try await database.fetchDownloadTask(id: task.id)

        #expect(fetched != nil)
        #expect(fetched!.id == task.id)
        #expect(fetched!.mediaId == task.mediaId)
    }

    @Test func streamRecoveryContextWithAllFields() throws {
        let context = StreamRecoveryContext(
            infoHash: "fullhash1234567890abcdef12345678",
            preferredService: .allDebrid,
            seasonNumber: 3,
            episodeNumber: 7,
            torrentId: "rd-torrent-999",
            resolvedDebridService: DebridServiceType.realDebrid.rawValue,
            resolvedFileName: "resolved.mkv",
            resolvedFileSizeBytes: 10_000_000
        )!

        #expect(context.infoHash == "fullhash1234567890abcdef12345678")
        #expect(context.preferredService == .allDebrid)
        #expect(context.seasonNumber == 3)
        #expect(context.episodeNumber == 7)
        #expect(context.torrentId == "rd-torrent-999")
        #expect(context.resolvedDebridService == DebridServiceType.realDebrid.rawValue)
        #expect(context.resolvedFileName == "resolved.mkv")
        #expect(context.resolvedFileSizeBytes == 10_000_000)
    }

    @Test func streamRecoveryContextEquatable() throws {
        let context1 = StreamRecoveryContext(
            infoHash: "equal-hash-1234567890abcdef12345678",
            preferredService: .realDebrid
        )!

        let context2 = StreamRecoveryContext(
            infoHash: "equal-hash-1234567890abcdef12345678",
            preferredService: .realDebrid
        )!

        let context3 = StreamRecoveryContext(
            infoHash: "different-hash1234567890abcdef",
            preferredService: .realDebrid
        )!

        #expect(context1 == context2)
        #expect(context1 != context3)
    }

    @Test func streamRecoveryContextHashable() {
        let context1 = StreamRecoveryContext(
            infoHash: "hashable1-1234567890abcdef12345678",
            preferredService: .realDebrid
        )!

        let context2 = StreamRecoveryContext(
            infoHash: "hashable1-1234567890abcdef12345678",
            preferredService: .realDebrid
        )!

        var set = Set<StreamRecoveryContext>()
        set.insert(context1)
        set.insert(context2)

        #expect(set.count == 1)
    }

    @Test func streamRecoveryContextCodable() throws {
        let context = StreamRecoveryContext(
            infoHash: "codable-hash1234567890abcdef123456",
            preferredService: .realDebrid,
            seasonNumber: 1,
            episodeNumber: 1
        )!

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(StreamRecoveryContext.self, from: data)

        #expect(decoded == context)
    }

    @Test func streamInfoComputedProperties() {
        let stream = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/video.mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "video.mkv",
            sizeBytes: 1_000_000_000,
            debridService: DebridServiceType.realDebrid.rawValue
        )

        #expect(!stream.id.isEmpty)
        #expect(stream.sizeString == "954 MB")
        #expect(stream.qualityBadge == "1080p / H.264 / AAC")
    }

    @Test func streamInfoHDRBadge() {
        let streamSDR = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/sdr.mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "sdr.mkv",
            sizeBytes: 1000,
            debridService: DebridServiceType.realDebrid.rawValue
        )
        #expect(streamSDR.qualityBadge == "1080p / H.264 / AAC")

        let streamHDR = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/hdr.mkv")!,
            quality: .uhd4k,
            codec: .h265,
            audio: .aac,
            source: .webDL,
            hdr: .dolbyVision,
            fileName: "hdr.mkv",
            sizeBytes: 1000,
            debridService: DebridServiceType.realDebrid.rawValue
        )
        #expect(streamHDR.qualityBadge == "4K / DV / H.265 / AAC")
    }

    @Test func streamInfoWithRecoveryContext() {
        let context = StreamRecoveryContext(
            infoHash: "stream-recovery-hash1234567890abcd",
            preferredService: .realDebrid
        )!

        let stream = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/recovery.mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "recovery.mkv",
            sizeBytes: 5000,
            debridService: DebridServiceType.realDebrid.rawValue,
            recoveryContext: context
        )

        #expect(stream.recoveryContext != nil)
        #expect(stream.remoteTransferID == context.torrentId)
    }

    @Test func streamInfoWithStreamURLModification() {
        let original = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/original.mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "original.mkv",
            sizeBytes: 1000,
            debridService: DebridServiceType.realDebrid.rawValue
        )

        let modified = original.withStreamURL(URL(string: "https://cdn.example.com/modified.mkv")!)

        #expect(original.streamURL.absoluteString.contains("original"))
        #expect(modified.streamURL.absoluteString.contains("modified"))
    }

    @Test func streamInfoWithRecoveryContextModification() {
        let original = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/no-context.mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "no-context.mkv",
            sizeBytes: 1000,
            debridService: DebridServiceType.realDebrid.rawValue
        )

        #expect(original.recoveryContext == nil)

        let context = StreamRecoveryContext(
            infoHash: "new-context-hash1234567890abcd",
            preferredService: .realDebrid
        )!

        let modified = original.withRecoveryContext(context)

        #expect(original.recoveryContext == nil)
        #expect(modified.recoveryContext != nil)
    }

    @Test func downloadStatusAllCasesHaveIsTerminal() {
        #expect(DownloadStatus.queued.isTerminal == false)
        #expect(DownloadStatus.resolving.isTerminal == false)
        #expect(DownloadStatus.downloading.isTerminal == false)
        #expect(DownloadStatus.completed.isTerminal == true)
        #expect(DownloadStatus.failed.isTerminal == true)
        #expect(DownloadStatus.cancelled.isTerminal == true)
    }

    @Test func downloadStatusRawValues() {
        #expect(DownloadStatus.queued.rawValue == "queued")
        #expect(DownloadStatus.resolving.rawValue == "resolving")
        #expect(DownloadStatus.downloading.rawValue == "downloading")
        #expect(DownloadStatus.completed.rawValue == "completed")
        #expect(DownloadStatus.failed.rawValue == "failed")
        #expect(DownloadStatus.cancelled.rawValue == "cancelled")
    }
}
