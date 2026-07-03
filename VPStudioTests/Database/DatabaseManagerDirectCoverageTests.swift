import Foundation
import Testing
@testable import VPStudio

@Suite("Database Manager Direct Coverage", .serialized)
struct DatabaseManagerDirectCoverageTests {
    @Test
    func clearDownloadTaskResumeDataClearsPersistedResumePayload() async throws {
        let database = try await makeDatabase()
        let resumeData = Data("resume-payload".utf8).base64EncodedString()
        let task = DownloadTask(
            id: "resume-wrapper",
            mediaId: "movie-1",
            streamURL: "https://example.com/movie.mkv",
            fileName: "movie.mkv",
            status: .downloading,
            resumeDataBase64: resumeData
        )
        try await database.saveDownloadTask(task)

        try await database.clearDownloadTaskResumeData(id: task.id)

        let updated = try #require(try await database.fetchDownloadTask(id: task.id))
        #expect(updated.resumeDataBase64 == nil)
    }

    @Test
    func fetchDownloadedLocalModelsReturnsOnlyDownloadedSortedByDefaultThenName() async throws {
        let database = try await makeDatabase()
        try await database.saveLocalModel(makeModel(id: "available", name: "Available", status: .available, isDefault: true))
        try await database.saveLocalModel(makeModel(id: "downloaded-z", name: "Zeta", status: .downloaded, isDefault: false))
        try await database.saveLocalModel(makeModel(id: "downloaded-a", name: "Alpha", status: .downloaded, isDefault: false))
        try await database.saveLocalModel(makeModel(id: "downloaded-default", name: "Default", status: .downloaded, isDefault: true))

        let downloaded = try await database.fetchDownloadedLocalModels()

        #expect(downloaded.map(\.id) == ["downloaded-default", "downloaded-a", "downloaded-z"])
        #expect(downloaded.allSatisfy { $0.status == .downloaded })
    }

    private func makeDatabase() async throws -> DatabaseManager {
        let database = try DatabaseManager(inMemoryNamed: "direct-db-coverage-\(UUID().uuidString)")
        try await database.migrate()
        return database
    }

    private func makeModel(
        id: String,
        name: String,
        status: LocalModelStatus,
        isDefault: Bool
    ) -> LocalModelDescriptor {
        LocalModelDescriptor(
            id: id,
            displayName: name,
            huggingFaceRepo: "fixture/\(id)",
            revision: "main",
            parameterCount: "4B",
            quantization: "4bit",
            diskSizeMB: 1_024,
            minMemoryMB: 8_192,
            expectedFileCount: 3,
            maxContextTokens: 4_096,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 512,
            status: status,
            downloadProgress: status == .downloaded ? 1 : 0,
            downloadedBytes: status == .downloaded ? 1_024 : 0,
            totalBytes: 1_024,
            validationState: status == .downloaded ? .valid : .pending,
            localPath: status == .downloaded ? "/tmp/\(id)" : nil,
            partialDownloadPath: nil,
            isDefault: isDefault,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
