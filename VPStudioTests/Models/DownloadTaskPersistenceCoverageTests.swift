import Foundation
import GRDB
import Testing
@testable import VPStudio

@Suite("DownloadTask Persistence Coverage")
struct DownloadTaskPersistenceCoverageTests {
    @Test
    func codableEncodingSanitizesCompletedTaskAfterStatusMutation() throws {
        var task = DownloadTask(
            id: "completed-mutation",
            mediaId: "movie-1",
            streamURL: "  https://cdn.example.com/private.mkv?token=secret  ",
            fileName: "Movie.1080p.mkv",
            status: .downloading,
            progress: 0.42,
            bytesWritten: 512,
            totalBytes: 1_024,
            resumeDataBase64: Data("resume-token".utf8).base64EncodedString()
        )

        task.status = .completed

        let encoded = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(DownloadTask.self, from: encoded)

        #expect(decoded.status == .completed)
        #expect(decoded.progress == 1)
        #expect(decoded.streamURL.isEmpty)
        #expect(decoded.persistedStreamURL == nil)
        #expect(decoded.resumeData == nil)
        #expect(decoded.resumeDataBase64 == nil)
        #expect(decoded.bytesWritten == 512)
        #expect(decoded.totalBytes == 1_024)
    }

    @Test
    func rowInitializerCoercesIntegerProgressAndDefaultsMissingIdentityFields() {
        let row = Row([
            "id": nil,
            "mediaId": nil,
            "episodeId": nil,
            "streamURL": " \n ",
            "fileName": nil,
            "status": DownloadStatus.downloading.rawValue,
            "progress": 1,
            "bytesWritten": 17,
            "totalBytes": Int64(2048),
            "destinationPath": nil,
            "errorMessage": nil,
            "mediaTitle": nil,
            "mediaType": nil,
            "posterPath": nil,
            "seasonNumber": nil,
            "episodeNumber": nil,
            "episodeTitle": nil,
            "recoveryContextJSON": nil,
            "expectedBytes": Int64(4096),
            "resumeDataBase64": "not-base64",
            "createdAt": nil,
            "updatedAt": nil,
        ])

        let task = DownloadTask(row: row)

        #expect(!task.id.isEmpty)
        #expect(task.mediaId == "")
        #expect(task.fileName.hasPrefix("download-"))
        #expect(task.fileName.hasSuffix(".mp4"))
        #expect(task.status == .downloading)
        #expect(task.progress == 1)
        #expect(task.bytesWritten == 17)
        #expect(task.totalBytes == 2048)
        #expect(task.expectedBytes == 4096)
        #expect(task.streamURL.isEmpty)
        #expect(task.persistedStreamURL == nil)
        #expect(task.resumeData == nil)
        #expect(task.resumeDataBase64 == nil)
        #expect(task.mediaTitle == "")
        #expect(task.mediaType == "movie")
    }
}
