import Foundation
import Testing
@testable import VPStudio

@Suite("LocalModelCatalogStore", .serialized)
struct LocalModelCatalogStoreTests {
    @Test func seedCatalogInsertsBuiltInModelsAndSkipsExistingRows() async throws {
        let database = try await makeCatalogDatabase()
        let store = LocalModelCatalogStore(database: database)

        await store.seedCatalog()
        let firstSeed = try await store.availableModels()

        #expect(firstSeed.count == 3)
        #expect(firstSeed.map(\.id) == [
            "apple/SmolLM2-360M-Instruct-CoreML",
            "apple/OpenELM-3B-Instruct-CoreML",
            "apple/Phi-3-mini-128k-instruct-CoreML",
        ])
        #expect(firstSeed.first?.isDefault == true)
        #expect(firstSeed.allSatisfy { $0.status == .available })

        await store.seedCatalog()
        let secondSeed = try await store.availableModels()

        #expect(secondSeed.map(\.id) == firstSeed.map(\.id))
        #expect(secondSeed.count == 3)
    }

    @Test func queryMethodsReturnAvailableDownloadedAndSingleModels() async throws {
        let database = try await makeCatalogDatabase()
        let store = LocalModelCatalogStore(database: database)
        let downloadedDefault = makeCatalogModel(
            id: "downloaded-default",
            name: "Default Downloaded",
            status: .downloaded,
            isDefault: true
        )
        let downloadedOther = makeCatalogModel(
            id: "downloaded-other",
            name: "Other Downloaded",
            status: .downloaded,
            isDefault: false
        )
        let available = makeCatalogModel(
            id: "available-only",
            name: "Available Only",
            status: .available,
            isDefault: false
        )
        try await database.saveLocalModel(available)
        try await database.saveLocalModel(downloadedOther)
        try await database.saveLocalModel(downloadedDefault)

        let all = try await store.availableModels()
        let downloaded = try await store.downloadedModels()
        let fetched = try #require(try await store.model(id: "downloaded-other"))

        #expect(all.map(\.id) == ["downloaded-default", "available-only", "downloaded-other"])
        #expect(downloaded.map(\.id) == ["downloaded-default", "downloaded-other"])
        #expect(fetched.displayName == "Other Downloaded")
        #expect(try await store.model(id: "missing") == nil)
    }

    @Test func updateStatusIgnoresMissingAndIllegalTransitionsBeforePersistingAllowedTransition() async throws {
        let database = try await makeCatalogDatabase()
        let store = LocalModelCatalogStore(database: database)
        let model = makeCatalogModel(id: "transition-model", name: "Transition", status: .available)
        try await database.saveLocalModel(model)

        try await store.updateStatus(id: "missing-model", to: .downloading)
        try await store.updateStatus(id: model.id, to: .downloaded, localPath: "/tmp/illegal")

        let unchanged = try #require(try await store.model(id: model.id))
        #expect(unchanged.status == .available)
        #expect(unchanged.localPath == nil)

        try await store.updateStatus(id: model.id, to: .downloading)
        try await store.updateStatus(id: model.id, to: .downloaded, localPath: "/tmp/transition-model")

        let updated = try #require(try await store.model(id: model.id))
        #expect(updated.status == .downloaded)
        #expect(updated.localPath == "/tmp/transition-model")
    }

    @Test func updateProgressAndResetToAvailablePersistExpectedFields() async throws {
        let database = try await makeCatalogDatabase()
        let store = LocalModelCatalogStore(database: database)
        var model = makeCatalogModel(id: "progress-model", name: "Progress", status: .downloading)
        model.downloadProgress = 0.1
        model.downloadedBytes = 10
        model.totalBytes = 100
        model.localPath = "/tmp/progress-model"
        model.partialDownloadPath = "/tmp/progress-model.partial"
        model.validationState = .valid
        try await database.saveLocalModel(model)

        try await store.updateProgress(id: model.id, progress: 0.42, downloadedBytes: 42, totalBytes: 100)

        let progressing = try #require(try await store.model(id: model.id))
        #expect(progressing.downloadProgress == 0.42)
        #expect(progressing.downloadedBytes == 42)
        #expect(progressing.totalBytes == 100)
        #expect(progressing.lastProgressAt != nil)

        try await store.resetToAvailable(id: model.id)
        try await store.resetToAvailable(id: "missing-model")

        let reset = try #require(try await store.model(id: model.id))
        #expect(reset.status == .available)
        #expect(reset.downloadProgress == 0)
        #expect(reset.downloadedBytes == 0)
        #expect(reset.localPath == nil)
        #expect(reset.partialDownloadPath == nil)
        #expect(reset.validationState == .pending)
    }

    private func makeCatalogDatabase() async throws -> DatabaseManager {
        let database = try DatabaseManager(inMemoryNamed: "local-catalog-store-\(UUID().uuidString)")
        try await database.migrate()
        return database
    }

    private func makeCatalogModel(
        id: String,
        name: String,
        status: LocalModelStatus,
        isDefault: Bool = false
    ) -> LocalModelDescriptor {
        LocalModelDescriptor(
            id: id,
            displayName: name,
            huggingFaceRepo: "fixture/\(id)",
            revision: "main",
            parameterCount: "1B",
            quantization: "4bit",
            diskSizeMB: 512,
            minMemoryMB: 1_024,
            expectedFileCount: 3,
            maxContextTokens: 4_096,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 512,
            status: status,
            downloadProgress: status == .downloaded ? 1 : 0,
            downloadedBytes: status == .downloaded ? 512 : 0,
            totalBytes: 512,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: status == .downloaded ? .valid : .pending,
            localPath: status == .downloaded ? "/tmp/\(id)" : nil,
            partialDownloadPath: status == .downloading ? "/tmp/\(id).partial" : nil,
            isDefault: isDefault,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
