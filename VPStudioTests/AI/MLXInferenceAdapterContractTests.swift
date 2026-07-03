import CoreML
import Foundation
import Testing
@testable import VPStudio

@Suite("MLX Inference Adapter Contracts")
struct MLXInferenceAdapterContractTests {
    @Test
    func modelArtifactDiscoveryOnlyConsidersTopLevelArtifacts() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let nestedParent = tempDir.appendingPathComponent("Nested", isDirectory: true)
        let nestedArtifact = nestedParent.appendingPathComponent("Ignored.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedArtifact, withIntermediateDirectories: true)
        try "{}".write(
            to: tempDir.appendingPathComponent("tokenizer.json"),
            atomically: true,
            encoding: .utf8
        )

        #expect(try CoreMLInferenceAdapter.modelArtifactURL(in: tempDir) == nil)
    }

    @Test
    func modelArtifactDiscoveryPrefersTopLevelBundleOverNestedArtifact() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let topLevel = tempDir.appendingPathComponent("TopLevel.mlmodelc", isDirectory: true)
        let nested = tempDir
            .appendingPathComponent("Nested", isDirectory: true)
            .appendingPathComponent("Ignored.mlpackage", isDirectory: true)

        try FileManager.default.createDirectory(at: topLevel, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let selected = try CoreMLInferenceAdapter.modelArtifactURL(in: tempDir)
        #expect(selected?.lastPathComponent == "TopLevel.mlmodelc")
    }

    @Test
    func promptFormattingPreservesMultilineContentWithoutExtraSentinels() {
        let system = "Line one.\nLine two."
        let user = "Question A?\nQuestion B?"
        let prompt = CoreMLInferenceAdapter.prompt(system: system, userMessage: user)

        #expect(prompt.contains(system))
        #expect(prompt.contains(user))
        #expect(prompt.components(separatedBy: "<|system|>").count - 1 == 1)
        #expect(prompt.components(separatedBy: "<|user|>").count - 1 == 1)
        #expect(prompt.components(separatedBy: "<|assistant|>").count - 1 == 1)
        #expect(prompt.components(separatedBy: "<|end|>").count - 1 == 2)
        #expect(prompt.hasSuffix("<|assistant|>\n"))
    }

    @Test
    func greedyTokenSelectionSupportsThreeDimensionalLogits() throws {
        let logits = try MLMultiArray(shape: [1, 3, 4], dataType: .float32)
        let values: [Float] = [
            9, 1, 0, 0,
            0, 2, 1, 0,
            1, 3, 8, 4,
        ]

        for (index, value) in values.enumerated() {
            logits[index] = NSNumber(value: value)
        }

        #expect(CoreMLInferenceAdapter.greedyNextTokenID(logits: logits, tokenCount: 3) == 2)
    }

    @Test
    func nextTokenActionRejectsNonTensorLogitsFeatures() throws {
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "logits": MLFeatureValue(string: "not-a-tensor")
        ])

        #expect(
            CoreMLInferenceAdapter.nextTokenAction(
                from: provider,
                tokenCount: 1,
                eosTokenID: nil
            ) == nil
        )
    }

    @Test
    func downloaderPatternsStayStableAndUnique() {
        let expected = ["*.mlmodelc/*", "*.mlpackage/*", "*.json", "*.jinja", "tokenizer*"]

        #expect(LocalModelDownloader.snapshotMatchingPatterns == expected)
        #expect(Set(LocalModelDownloader.snapshotMatchingPatterns).count == expected.count)
    }

    @Test
    func localInferenceErrorDescriptionsRemainUserReadable() {
        #expect(LocalInferenceError.modelNotDownloaded.errorDescription == "Model not downloaded.")
        #expect(
            LocalInferenceError.insufficientMemory(availableMB: 768, requiredMB: 2048).errorDescription
                == "Insufficient memory: 768MB available, 2048MB required."
        )
        #expect(LocalInferenceError.generationTimeout.errorDescription == "Generation timed out.")
        #expect(LocalInferenceError.inferenceError("tokenizer.json missing").errorDescription == "tokenizer.json missing")
    }

    @Test
    func sourceContractLoadsTokenizerFromModelDirectory() throws {
        let source = try adapterSource()

        #expect(source.contains("AutoTokenizer.from(modelFolder: directory, hubApi: HubApi.shared)"))
    }

    @Test
    func sourceContractUsesDirectoryNameAsLoadedModelIdentifier() throws {
        let source = try adapterSource()

        #expect(source.contains("modelID: directory.lastPathComponent"))
    }

    @Test
    func sourceContractDownloaderDelegatesUsingSharedMatchingPatterns() throws {
        let source = try adapterSource()

        #expect(source.contains("static let snapshotMatchingPatterns = [\"*.mlmodelc/*\", \"*.mlpackage/*\", \"*.json\", \"*.jinja\", \"tokenizer*\"]"))
        #expect(source.contains("revision: String,"))
        #expect(source.contains("LocalModelRevisionPolicy.normalizedImmutableRevision(revision)"))
        #expect(source.contains("let request = snapshotRequest(repoID: repoID, revision: immutableRevision)"))
        #expect(source.contains("revision: request.revision"))
        #expect(source.contains("matching: request.matchingPatterns"))
        #expect(source.contains("return try await HubApi.shared.snapshot("))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func adapterSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let repoRoot = testsDirectory.deletingLastPathComponent()
        let sourceURL = repoRoot.appendingPathComponent("VPStudio/Services/AI/Local/MLXInferenceAdapter.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
