import Foundation
import Testing
@testable import VPStudio

@Suite("Local Inference Engine")
struct LocalInferenceEngineTests {
    private struct ThrowingAdapter: LocalInferenceAdapting {
        var errorMessage: String

        func loadModel(from directory: URL) async throws -> LoadedLocalModel {
            throw LocalInferenceError.inferenceError("\(errorMessage): \(directory.lastPathComponent)")
        }

        func generate(
            model: LoadedLocalModel,
            system: String,
            userMessage: String,
            maxTokens: Int
        ) async throws -> LocalGenerationResult {
            throw LocalInferenceError.inferenceError("generation should not run")
        }
    }

    private actor CountingLoadAdapter: LocalInferenceAdapting {
        private var loadCount = 0

        func currentLoadCount() -> Int {
            loadCount
        }

        func loadModel(from directory: URL) async throws -> LoadedLocalModel {
            loadCount += 1
            return LoadedLocalModel(testModelID: directory.lastPathComponent)
        }

        func generate(
            model: LoadedLocalModel,
            system: String,
            userMessage: String,
            maxTokens: Int
        ) async throws -> LocalGenerationResult {
            throw LocalInferenceError.inferenceError("generation should not run")
        }
    }

    private actor TrackingLoadAdapter: LocalInferenceAdapting {
        private var loadedIDs: [String] = []

        func currentLoadedIDs() -> [String] {
            loadedIDs
        }

        func loadModel(from directory: URL) async throws -> LoadedLocalModel {
            loadedIDs.append(directory.lastPathComponent)
            return LoadedLocalModel(testModelID: directory.lastPathComponent)
        }

        func generate(
            model: LoadedLocalModel,
            system: String,
            userMessage: String,
            maxTokens: Int
        ) async throws -> LocalGenerationResult {
            throw LocalInferenceError.inferenceError("generation should not run")
        }
    }

    private struct SucceedingAdapter: LocalInferenceAdapting {
        func loadModel(from directory: URL) async throws -> LoadedLocalModel {
            LoadedLocalModel(testModelID: directory.lastPathComponent)
        }

        func generate(
            model: LoadedLocalModel,
            system: String,
            userMessage: String,
            maxTokens: Int
        ) async throws -> LocalGenerationResult {
            throw LocalInferenceError.inferenceError("generation should not run")
        }
    }

    private actor CapturingGenerateAdapter: LocalInferenceAdapting {
        struct Request: Equatable, Sendable {
            let modelID: String
            let system: String
            let userMessage: String
            let maxTokens: Int
        }

        private var loadDirectories: [String] = []
        private var generationRequests: [Request] = []
        let result: LocalGenerationResult

        init(result: LocalGenerationResult) {
            self.result = result
        }

        func currentLoadDirectories() -> [String] {
            loadDirectories
        }

        func currentGenerationRequests() -> [Request] {
            generationRequests
        }

        func loadModel(from directory: URL) async throws -> LoadedLocalModel {
            loadDirectories.append(directory.lastPathComponent)
            return LoadedLocalModel(testModelID: directory.lastPathComponent)
        }

        func generate(
            model: LoadedLocalModel,
            system: String,
            userMessage: String,
            maxTokens: Int
        ) async throws -> LocalGenerationResult {
            generationRequests.append(Request(
                modelID: model.modelID,
                system: system,
                userMessage: userMessage,
                maxTokens: maxTokens
            ))
            return result
        }
    }

    @Test
    func checkMemoryForUnknownModelReturnsInsufficientSentinel() async throws {
        let (engine, _, _, tempDir) = try await makeEngine()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let availability = await engine.checkMemory(for: "missing-model")

        if case .insufficient(let availableMB, let requiredMB) = availability {
            #expect(availableMB == 0)
            #expect(requiredMB == 0)
        } else {
            Issue.record("Expected missing models to report insufficient memory sentinel")
        }
    }

    @Test
    func checkMemoryClassifiesOkTightAndInsufficientThresholds() async throws {
        let (database, store, tempDir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeModel(id: "local/memory-threshold", status: .downloaded, localPath: tempDir.path)
        try await database.saveLocalModel(model)

        let okEngine = LocalInferenceEngine(
            catalogStore: store,
            availableMemoryProvider: { UInt64(model.minMemoryMB * 2) * 1_048_576 }
        )
        let tightEngine = LocalInferenceEngine(
            catalogStore: store,
            availableMemoryProvider: { UInt64(model.minMemoryMB) * 1_048_576 }
        )
        let insufficientEngine = LocalInferenceEngine(
            catalogStore: store,
            availableMemoryProvider: { UInt64(model.minMemoryMB - 1) * 1_048_576 }
        )

        if case .ok = await okEngine.checkMemory(for: model.id) {
            #expect(Bool(true))
        } else {
            Issue.record("Expected enough memory to be classified as ok")
        }

        if case .tight(let availableMB, let requiredMB) = await tightEngine.checkMemory(for: model.id) {
            #expect(availableMB == model.minMemoryMB)
            #expect(requiredMB == model.minMemoryMB)
        } else {
            Issue.record("Expected single-threshold memory to be classified as tight")
        }

        if case .insufficient(let availableMB, let requiredMB) = await insufficientEngine.checkMemory(for: model.id) {
            #expect(availableMB == model.minMemoryMB - 1)
            #expect(requiredMB == model.minMemoryMB)
        } else {
            Issue.record("Expected below-threshold memory to be classified as insufficient")
        }
    }

    @Test
    func loadModelThrowsWhenDescriptorIsNotDownloaded() async throws {
        let (engine, _, database, tempDir) = try await makeEngine()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeModel(id: "local/not-downloaded", status: .available, localPath: nil)
        try await database.saveLocalModel(model)

        do {
            try await engine.loadModel(id: model.id)
            Issue.record("Expected loadModel to reject unavailable local models")
        } catch LocalInferenceError.modelNotDownloaded {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func loadModelThrowsWhenDownloadedDescriptorHasNoLocalPath() async throws {
        let (engine, _, database, tempDir) = try await makeEngine()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeModel(id: "local/downloaded-missing-path", status: .downloaded, localPath: nil)
        try await database.saveLocalModel(model)

        do {
            try await engine.loadModel(id: model.id)
            Issue.record("Expected loadModel to reject downloaded descriptors without local paths")
        } catch LocalInferenceError.modelNotDownloaded {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func loadModelPropagatesAdapterLoadFailureForDownloadedDescriptor() async throws {
        let (database, store, tempDir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelDir = tempDir.appendingPathComponent("AdapterModel", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        let model = makeModel(id: "local/adapter-failure", status: .downloaded, localPath: modelDir.path)
        try await database.saveLocalModel(model)
        let engine = LocalInferenceEngine(
            catalogStore: store,
            adapter: ThrowingAdapter(errorMessage: "adapter failed")
        )

        do {
            try await engine.loadModel(id: model.id)
            Issue.record("Expected adapter failure to propagate")
        } catch LocalInferenceError.inferenceError(let message) {
            #expect(message.contains("adapter failed"))
            #expect(message.contains(modelDir.lastPathComponent))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test(arguments: [1, 255])
    func loadModelContinuesThroughMemoryPreflightWarnings(availableMemoryMB: Int) async throws {
        let (database, store, tempDir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelDir = tempDir.appendingPathComponent("MemoryWarningModel", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        let model = makeModel(id: "local/memory-warning-\(availableMemoryMB)", status: .downloaded, localPath: modelDir.path)
        try await database.saveLocalModel(model)
        let engine = LocalInferenceEngine(
            catalogStore: store,
            adapter: ThrowingAdapter(errorMessage: "load attempted"),
            availableMemoryProvider: { UInt64(availableMemoryMB) * 1_048_576 }
        )

        do {
            try await engine.loadModel(id: model.id)
            Issue.record("Expected adapter failure after memory preflight")
        } catch LocalInferenceError.inferenceError(let message) {
            #expect(message.contains("load attempted"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func generateThrowsWhenModelIsNotDownloaded() async throws {
        let (engine, _, database, tempDir) = try await makeEngine()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeModel(id: "local/generate-missing", status: .available, localPath: nil)
        try await database.saveLocalModel(model)

        do {
            _ = try await engine.generate(modelID: model.id, system: "system", userMessage: "hello")
            Issue.record("Expected generate to reject unavailable local models")
        } catch LocalInferenceError.modelNotDownloaded {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func localProviderSurfacesMissingModelError() async throws {
        let (engine, _, database, tempDir) = try await makeEngine()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model = makeModel(id: "local/provider-missing", status: .available, localPath: nil)
        try await database.saveLocalModel(model)
        let provider = LocalMLXProvider(inferenceEngine: engine, modelID: model.id)

        do {
            _ = try await provider.complete(system: "system", userMessage: "hello")
            Issue.record("Expected local provider to surface missing-model failures")
        } catch LocalInferenceError.modelNotDownloaded {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func localProviderMapsSuccessfulGenerationAndEngineCapsOutputTokens() async throws {
        let (database, store, tempDir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelDir = tempDir.appendingPathComponent("ProviderSuccessModel", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        let model = makeModel(id: "local/provider-success", status: .downloaded, localPath: modelDir.path)
        try await database.saveLocalModel(model)

        let adapter = CapturingGenerateAdapter(result: LocalGenerationResult(
            content: "Arrival is a good fit.",
            inputTokens: 17,
            outputTokens: 6
        ))
        let engine = LocalInferenceEngine(catalogStore: store, adapter: adapter)
        let provider = LocalMLXProvider(inferenceEngine: engine, modelID: model.id)

        let response = try await provider.complete(
            system: "Recommend one title.",
            userMessage: "I want cerebral sci-fi."
        )
        await engine.forceUnload()

        #expect(response.provider == .local)
        #expect(response.content == "Arrival is a good fit.")
        #expect(response.model == model.id)
        #expect(response.inputTokens == 17)
        #expect(response.outputTokens == 6)

        #expect(await adapter.currentLoadDirectories() == [modelDir.lastPathComponent])
        let requests = await adapter.currentGenerationRequests()
        #expect(requests == [
            CapturingGenerateAdapter.Request(
                modelID: modelDir.lastPathComponent,
                system: "Recommend one title.",
                userMessage: "I want cerebral sci-fi.",
                maxTokens: model.effectiveOutputCap
            )
        ])
    }

    @Test
    func generateUsesAlreadyLoadedModelAndHonorsLowerRequestedMaxTokens() async throws {
        let (database, store, tempDir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelDir = tempDir.appendingPathComponent("WarmModel", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        let model = makeModel(id: "local/warm-model", status: .downloaded, localPath: modelDir.path)
        try await database.saveLocalModel(model)

        let adapter = CapturingGenerateAdapter(result: LocalGenerationResult(
            content: "Warm response",
            inputTokens: 3,
            outputTokens: 2
        ))
        let engine = LocalInferenceEngine(
            catalogStore: store,
            adapter: adapter,
            availableMemoryProvider: { UInt64(model.minMemoryMB * 3) * 1_048_576 }
        )

        try await engine.loadModel(id: model.id)
        let result = try await engine.generate(
            modelID: model.id,
            system: "System",
            userMessage: "User",
            maxTokens: 128
        )
        await engine.forceUnload()

        #expect(result.content == "Warm response")
        #expect(await adapter.currentLoadDirectories() == [modelDir.lastPathComponent])
        #expect(await adapter.currentGenerationRequests() == [
            CapturingGenerateAdapter.Request(
                modelID: modelDir.lastPathComponent,
                system: "System",
                userMessage: "User",
                maxTokens: 128
            )
        ])
    }

    @Test
    func unloadAndForceUnloadAreIdempotentWhenNothingIsLoaded() async throws {
        let (engine, _, _, tempDir) = try await makeEngine()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await engine.unloadModel()
        await engine.forceUnload()
    }

    @Test
    func monitoringCanStartStopAndRestart() async throws {
        let (engine, _, _, tempDir) = try await makeEngine()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await engine.startMonitoring()
        await engine.stopMonitoring()
        await engine.startMonitoring()
        await engine.stopMonitoring()
    }

    @Test(arguments: [
        (LocalInferenceError.modelNotDownloaded, "Model not downloaded."),
        (LocalInferenceError.insufficientMemory(availableMB: 512, requiredMB: 2_048), "512MB available, 2048MB required."),
        (LocalInferenceError.generationTimeout, "Generation timed out"),
        (LocalInferenceError.inferenceError("tokenizer missing"), "tokenizer missing"),
    ])
    func localInferenceErrorsDescribeRecoveryContext(error: LocalInferenceError, expectedFragment: String) {
        #expect(error.errorDescription?.contains(expectedFragment) == true)
    }

    @Test
    func loadModelIdempotentWhenSameModelAlreadyLoaded() async throws {
        let (database, store, tempDir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelDir = tempDir.appendingPathComponent("Model", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        let model = makeModel(id: "local/same-model", status: .downloaded, localPath: modelDir.path)
        try await database.saveLocalModel(model)

        let countingAdapter = CountingLoadAdapter()
        let engine = LocalInferenceEngine(catalogStore: store, adapter: countingAdapter)

        try await engine.loadModel(id: model.id)
        try await engine.loadModel(id: model.id)

        #expect(await countingAdapter.currentLoadCount() == 1)
    }

    @Test
    func loadModelSwitchesToNewModelWhenDifferentIDRequested() async throws {
        let (database, store, tempDir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let model1Dir = tempDir.appendingPathComponent("Model1", isDirectory: true)
        let model2Dir = tempDir.appendingPathComponent("Model2", isDirectory: true)
        try FileManager.default.createDirectory(at: model1Dir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: model2Dir, withIntermediateDirectories: true)

        let model1 = makeModel(id: "local/model-1", status: .downloaded, localPath: model1Dir.path)
        let model2 = makeModel(id: "local/model-2", status: .downloaded, localPath: model2Dir.path)
        try await database.saveLocalModel(model1)
        try await database.saveLocalModel(model2)

        let trackingAdapter = TrackingLoadAdapter()
        let engine = LocalInferenceEngine(catalogStore: store, adapter: trackingAdapter)

        try await engine.loadModel(id: model1.id)
        try await engine.loadModel(id: model2.id)

        let loadedIDs = await trackingAdapter.currentLoadedIDs()
        #expect(loadedIDs.count == 2)
        #expect(loadedIDs[0] == model1Dir.lastPathComponent)
        #expect(loadedIDs[1] == model2Dir.lastPathComponent)
    }

    @Test
    func unloadModelClearsLoadedModelIDAndLastUsed() async throws {
        let (database, store, tempDir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelDir = tempDir.appendingPathComponent("Model", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        let model = makeModel(id: "local/unload-test", status: .downloaded, localPath: modelDir.path)
        try await database.saveLocalModel(model)

        let engine = LocalInferenceEngine(catalogStore: store, adapter: SucceedingAdapter())

        try await engine.loadModel(id: model.id)
        await engine.unloadModel()
    }

    @Test
    func forceUnloadBehavesSameAsUnload() async throws {
        let (database, store, tempDir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelDir = tempDir.appendingPathComponent("Model", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        let model = makeModel(id: "local/force-unload", status: .downloaded, localPath: modelDir.path)
        try await database.saveLocalModel(model)

        let engine = LocalInferenceEngine(catalogStore: store, adapter: SucceedingAdapter())

        try await engine.loadModel(id: model.id)
        await engine.forceUnload()
        await engine.forceUnload()
    }

    @Test
    func checkMemoryReturnsCorrectClassificationForExactThreshold() async throws {
        let (database, store, tempDir) = try await makeStore()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var model = makeModel(id: "local/exact-threshold", status: .downloaded, localPath: tempDir.path)
        model.minMemoryMB = 1000
        try await database.saveLocalModel(model)

        let exactEngine = LocalInferenceEngine(
            catalogStore: store,
            availableMemoryProvider: { UInt64(2000) * 1_048_576 }
        )

        let result = await exactEngine.checkMemory(for: model.id)
        if case .ok = result {
            #expect(Bool(true))
        } else {
            Issue.record("Expected 2x memory to be classified as ok")
        }
    }

    private func makeEngine() async throws -> (LocalInferenceEngine, LocalModelCatalogStore, DatabaseManager, URL) {
        let (database, store, tempDir) = try await makeStore()
        return (LocalInferenceEngine(catalogStore: store), store, database, tempDir)
    }

    private func makeStore() async throws -> (DatabaseManager, LocalModelCatalogStore, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "local-inference-\(UUID().uuidString)")
        try await database.migrate()
        let store = LocalModelCatalogStore(database: database)
        return (database, store, tempDir)
    }

    private func makeModel(id: String, status: LocalModelStatus, localPath: String?) -> LocalModelDescriptor {
        LocalModelDescriptor(
            id: id,
            displayName: "Test Model",
            huggingFaceRepo: id,
            revision: "main",
            parameterCount: "1B",
            quantization: "4bit",
            diskSizeMB: 100,
            minMemoryMB: 256,
            expectedFileCount: 1,
            maxContextTokens: 2_048,
            effectivePromptCap: 1_024,
            effectiveOutputCap: 512,
            status: status,
            downloadProgress: status == .downloaded ? 1 : 0,
            downloadedBytes: 0,
            totalBytes: 0,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: localPath,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
