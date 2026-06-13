import Foundation
import Testing
@testable import VPStudio

// MARK: - LocalInferenceAdapting Conformance Tests

@Suite("LocalInferenceAdapting Conformance")
struct LocalInferenceAdaptingConformanceTests {

    @Test func coreMLInferenceAdapterConformsToLocalInferenceAdapting() throws {
        let adapter = CoreMLInferenceAdapter()
        #expect(Self.acceptsLocalInferenceAdapter(adapter))
    }

    @Test func localInferenceAdapterConformanceWithMock() {
        struct TestAdapter: LocalInferenceAdapting {
            func loadModel(from directory: URL) async throws -> LoadedLocalModel {
                throw CancellationError()
            }
            func generate(model: LoadedLocalModel, system: String, userMessage: String, maxTokens: Int) async throws -> LocalGenerationResult {
                throw CancellationError()
            }
        }
        let adapter = TestAdapter()
        #expect(Self.acceptsLocalInferenceAdapter(adapter))
    }

    private static func acceptsLocalInferenceAdapter<T: LocalInferenceAdapting>(_ adapter: T) -> Bool {
        _ = adapter
        return true
    }
}

// MARK: - CoreMLInferenceAdapter Static Tests

@Suite("CoreMLInferenceAdapter Static Methods")
struct CoreMLInferenceAdapterStaticTests {

    @Test func modelArtifactURLFindsMlmodelc() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelBundle = tempDir.appendingPathComponent("Test.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: modelBundle, withIntermediateDirectories: true)

        let found = try CoreMLInferenceAdapter.modelArtifactURL(in: tempDir)
        #expect(found != nil)
        #expect(found?.pathExtension == "mlmodelc")
    }

    @Test func modelArtifactURLFindsMlpackage() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelPackage = tempDir.appendingPathComponent("Test.mlpackage", isDirectory: true)
        try FileManager.default.createDirectory(at: modelPackage, withIntermediateDirectories: true)

        let found = try CoreMLInferenceAdapter.modelArtifactURL(in: tempDir)
        #expect(found != nil)
        #expect(found?.pathExtension == "mlpackage")
    }

    @Test func modelArtifactURLReturnsNilWhenNoModel() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("config.json", isDirectory: false), withIntermediateDirectories: true)

        let found = try CoreMLInferenceAdapter.modelArtifactURL(in: tempDir)
        #expect(found == nil)
    }

    @Test func promptUsesExpectedTemplate() {
        let prompt = CoreMLInferenceAdapter.prompt(
            system: "You are helpful.",
            userMessage: "Tell me about movies."
        )

        #expect(prompt.hasPrefix("<|system|>"))
        #expect(prompt.contains("You are helpful."))
        #expect(prompt.contains("<|user|>"))
        #expect(prompt.contains("Tell me about movies."))
        #expect(prompt.contains("<|end|>"))
        #expect(prompt.hasSuffix("<|assistant|>\n"))
    }

    @Test func promptWithEmptyStringsStillWorks() {
        let prompt = CoreMLInferenceAdapter.prompt(system: "", userMessage: "")
        #expect(prompt.hasPrefix("<|system|>"))
        #expect(prompt.contains("<|end|>"))
    }
}

// MARK: - LocalGenerationResult Tests

@Suite("LocalGenerationResult")
struct LocalGenerationResultTests {

    @Test func resultStoresContent() {
        let result = LocalGenerationResult(content: "Generated text", inputTokens: 10, outputTokens: 5)
        #expect(result.content == "Generated text")
    }

    @Test func resultStoresTokenCounts() {
        let result = LocalGenerationResult(content: "test", inputTokens: 50, outputTokens: 25)
        #expect(result.inputTokens == 50)
        #expect(result.outputTokens == 25)
    }

    @Test func resultIsSendable() {
        let result = LocalGenerationResult(content: "test", inputTokens: 1, outputTokens: 1)
        func assertSendable<T: Sendable>(_ value: T) {}
        assertSendable(result)
    }
}

// MARK: - LocalInferenceError Tests

@Suite("LocalInferenceError")
struct LocalInferenceErrorTestsLocalinferenceadapterprotocolconformancetests {

    @Test func modelNotDownloadedHasDescription() {
        let error = LocalInferenceError.modelNotDownloaded
        #expect(error.errorDescription == "Model not downloaded.")
    }

    @Test func insufficientMemoryHasDescription() {
        let error = LocalInferenceError.insufficientMemory(availableMB: 512, requiredMB: 2048)
        #expect(error.errorDescription?.contains("512MB available") == true)
        #expect(error.errorDescription?.contains("2048MB required") == true)
    }

    @Test func generationTimeoutHasDescription() {
        let error = LocalInferenceError.generationTimeout
        #expect(error.errorDescription == "Generation timed out.")
    }

    @Test func inferenceErrorHasDescription() {
        let error = LocalInferenceError.inferenceError("Tokenizer not found")
        #expect(error.errorDescription == "Tokenizer not found")
    }

    @Test func errorsAreEquatable() {
        #expect(LocalInferenceError.modelNotDownloaded == .modelNotDownloaded)
        #expect(LocalInferenceError.generationTimeout == .generationTimeout)
        #expect(LocalInferenceError.inferenceError("a") == .inferenceError("a"))
        #expect(LocalInferenceError.inferenceError("a") != .inferenceError("b"))
    }
}

// MARK: - LocalModelDownloader Tests

@Suite("LocalModelDownloader")
struct LocalModelDownloaderTests {

    @Test func snapshotMatchingPatternsIncludeCoreML() {
        #expect(LocalModelDownloader.snapshotMatchingPatterns.contains("*.mlmodelc/*"))
    }

    @Test func snapshotMatchingPatternsIncludeMlpackage() {
        #expect(LocalModelDownloader.snapshotMatchingPatterns.contains("*.mlpackage/*"))
    }

    @Test func snapshotMatchingPatternsIncludeConfig() {
        #expect(LocalModelDownloader.snapshotMatchingPatterns.contains("*.json"))
    }

    @Test func snapshotMatchingPatternsIncludeJinja() {
        #expect(LocalModelDownloader.snapshotMatchingPatterns.contains("*.jinja"))
    }

    @Test func snapshotMatchingPatternsIncludeTokenizer() {
        #expect(LocalModelDownloader.snapshotMatchingPatterns.contains("tokenizer*"))
    }
}
