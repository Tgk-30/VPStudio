import Foundation
import CoreML
import Testing
@testable import VPStudio

@Suite("CoreML Inference Adapter")
struct MLXInferenceAdapterTests {
    @Test
    func modelArtifactURLFindsCompiledModelBundle() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelBundle = tempDir.appendingPathComponent("Model.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: modelBundle, withIntermediateDirectories: true)

        let selected = try CoreMLInferenceAdapter.modelArtifactURL(in: tempDir)
        #expect(selected?.lastPathComponent == modelBundle.lastPathComponent)
        #expect(selected?.pathExtension == "mlmodelc")
    }

    @Test
    func modelArtifactURLFindsModelPackageBundle() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let modelPackage = tempDir.appendingPathComponent("Model.mlpackage", isDirectory: true)
        try FileManager.default.createDirectory(at: modelPackage, withIntermediateDirectories: true)

        let selected = try CoreMLInferenceAdapter.modelArtifactURL(in: tempDir)
        #expect(selected?.lastPathComponent == modelPackage.lastPathComponent)
        #expect(selected?.pathExtension == "mlpackage")
    }

    @Test
    func modelArtifactURLIgnoresTokenizerAndMetadataFiles() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "metadata".write(
            to: tempDir.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "tokenizer".write(
            to: tempDir.appendingPathComponent("tokenizer.json"),
            atomically: true,
            encoding: .utf8
        )

        #expect(try CoreMLInferenceAdapter.modelArtifactURL(in: tempDir) == nil)
    }

    @Test
    func modelArtifactURLPropagatesMissingDirectoryErrors() throws {
        let missingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            _ = try CoreMLInferenceAdapter.modelArtifactURL(in: missingDir)
            Issue.record("Expected missing model directory lookup to throw")
        } catch {
            #expect((error as NSError).domain == NSCocoaErrorDomain)
        }
    }

    @Test
    func promptUsesExpectedChatTemplateSeparators() {
        let prompt = CoreMLInferenceAdapter.prompt(
            system: "Be concise.",
            userMessage: "Recommend something."
        )

        #expect(prompt == "<|system|>\nBe concise.<|end|>\n<|user|>\nRecommend something.<|end|>\n<|assistant|>\n")
    }

    @Test
    func downloaderPatternsIncludeModelTokenizerAndTemplateAssets() {
        #expect(LocalModelDownloader.snapshotMatchingPatterns.contains("*.mlmodelc/*"))
        #expect(LocalModelDownloader.snapshotMatchingPatterns.contains("*.mlpackage/*"))
        #expect(LocalModelDownloader.snapshotMatchingPatterns.contains("*.json"))
        #expect(LocalModelDownloader.snapshotMatchingPatterns.contains("*.jinja"))
        #expect(LocalModelDownloader.snapshotMatchingPatterns.contains("tokenizer*"))
    }

    @Test
    func loadModelFromDirectoryWithoutCoreMLBundleThrowsInferenceError() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let adapter = CoreMLInferenceAdapter()

        do {
            _ = try await adapter.loadModel(from: tempDir)
            Issue.record("Expected missing CoreML bundle to throw")
        } catch LocalInferenceError.inferenceError(let message) {
            #expect(message.contains("No CoreML model found"))
            #expect(message.contains(tempDir.lastPathComponent))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func placeholderLoadedModelThrowsWhenCoreMLResourcesAreRequested() throws {
        let model = LoadedLocalModel(testModelID: "unit-placeholder")

        do {
            _ = try model.coreMLResources()
            Issue.record("Expected placeholder model to reject CoreML resource access")
        } catch LocalInferenceError.inferenceError(let message) {
            #expect(message == "Test model stub does not contain inference resources")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(model.modelID == "unit-placeholder")
    }

    @Test
    func generateWithPlaceholderModelFailsBeforeTokenization() async throws {
        let adapter = CoreMLInferenceAdapter()
        let model = LoadedLocalModel(testModelID: "unit-placeholder")

        do {
            _ = try await adapter.generate(
                model: model,
                system: "System",
                userMessage: "User",
                maxTokens: 4
            )
            Issue.record("Expected placeholder generation to throw")
        } catch LocalInferenceError.inferenceError(let message) {
            #expect(message == "Test model stub does not contain inference resources")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func loadModelWithInvalidCoreMLBundlePropagatesLoadFailure() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let invalidBundle = tempDir.appendingPathComponent("Broken.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: invalidBundle, withIntermediateDirectories: true)

        let adapter = CoreMLInferenceAdapter()

        do {
            _ = try await adapter.loadModel(from: tempDir)
            Issue.record("Expected invalid CoreML bundle to throw")
        } catch LocalInferenceError.inferenceError {
            Issue.record("Expected CoreML load failure, not missing-bundle wrapper")
        } catch {
            #expect(String(describing: error).isEmpty == false)
        }
    }

    @Test
    func promptWithEmptyStringsProducesValidTemplate() {
        let prompt = CoreMLInferenceAdapter.prompt(system: "", userMessage: "")
        #expect(prompt == "<|system|>\n<|end|>\n<|user|>\n<|end|>\n<|assistant|>\n")
    }

    @Test
    func promptWithSpecialCharactersPreservesContent() {
        let prompt = CoreMLInferenceAdapter.prompt(system: "You are a <bot>.", userMessage: "Hello & goodbye")
        #expect(prompt.contains("You are a <bot>."))
        #expect(prompt.contains("Hello & goodbye"))
        #expect(prompt.hasPrefix("<|system|>"))
        #expect(prompt.hasSuffix("<|assistant|>\n"))
    }

    @Test
    func greedyNextTokenSelectsArgmaxFromLastTokenRow() throws {
        let logits = try MLMultiArray(shape: [2, 4], dataType: .float32)
        for (index, value) in [0.1, 0.2, 0.3, 0.4, -1.0, 8.0, 2.0, 7.0].enumerated() {
            logits[index] = NSNumber(value: value)
        }

        #expect(CoreMLInferenceAdapter.greedyNextTokenID(logits: logits, tokenCount: 2) == 1)
    }

    @Test
    func greedyNextTokenReturnsNilForEmptyOrMalformedLogits() throws {
        let logits = try MLMultiArray(shape: [1, 3], dataType: .float32)
        logits[0] = 1
        logits[1] = 2
        logits[2] = 3

        #expect(CoreMLInferenceAdapter.greedyNextTokenID(logits: logits, tokenCount: 0) == nil)
        #expect(CoreMLInferenceAdapter.greedyNextTokenID(logits: logits, tokenCount: 2) == nil)
    }

    @Test
    func greedyNextTokenReturnsNilForZeroVocabularyLogits() throws {
        let logits = try MLMultiArray(shape: [1, 0], dataType: .float32)

        #expect(CoreMLInferenceAdapter.greedyNextTokenID(logits: logits, tokenCount: 1) == nil)
    }

    @Test
    func greedyNextTokenBreaksTiesByKeepingFirstMaximumIndex() throws {
        let logits = try MLMultiArray(shape: [1, 4], dataType: .float32)
        for (index, value) in [5.0, 9.0, 9.0, 1.0].enumerated() {
            logits[index] = NSNumber(value: value)
        }

        #expect(CoreMLInferenceAdapter.greedyNextTokenID(logits: logits, tokenCount: 1) == 1)
    }

    @Test
    func generationStepLimitClampsNegativeMaxTokensToZero() {
        #expect(CoreMLGenerationPolicy.stepLimit(maxTokens: -8) == 0)
        #expect(CoreMLGenerationPolicy.stepLimit(maxTokens: 0) == 0)
        #expect(CoreMLGenerationPolicy.stepLimit(maxTokens: 12) == 12)
    }

    @Test
    func generationEOSPolicyStopsOnlyOnMatchingToken() {
        #expect(CoreMLGenerationPolicy.shouldStopForEOS(nextTokenID: 7, eosTokenID: 7))
        #expect(!CoreMLGenerationPolicy.shouldStopForEOS(nextTokenID: 7, eosTokenID: 8))
        #expect(!CoreMLGenerationPolicy.shouldStopForEOS(nextTokenID: 7, eosTokenID: nil))
    }

    @Test
    func generationNextTokenActionStopsForEOSOtherwiseAppends() {
        #expect(CoreMLGenerationPolicy.nextTokenAction(nextTokenID: 7, eosTokenID: 7) == .stop)
        #expect(CoreMLGenerationPolicy.nextTokenAction(nextTokenID: 7, eosTokenID: 8) == .append(7))
        #expect(CoreMLGenerationPolicy.nextTokenAction(nextTokenID: 7, eosTokenID: nil) == .append(7))
    }

    @Test
    func generationStateAfterAppendingTokenAddsOnlyTheNewToken() {
        let state = CoreMLGenerationPolicy.stateAfterAppendingToken(
            42,
            to: [10, 11],
            generatedCount: 3
        )

        #expect(state.tokens == [10, 11, 42])
        #expect(state.generatedCount == 4)
    }

    @Test
    func generationStepStateStopsWithoutMutatingTokens() {
        #expect(
            CoreMLGenerationPolicy.state(
                after: .stop,
                tokens: [10, 11],
                generatedCount: 2
            ) == .stop
        )
    }

    @Test
    func generationStepStateAppendsTokenAndCount() {
        #expect(
            CoreMLGenerationPolicy.state(
                after: .append(42),
                tokens: [10, 11],
                generatedCount: 2
            ) == .append(tokens: [10, 11, 42], generatedCount: 3)
        )
    }

    @Test
    func generatedTokenSliceReturnsOnlyNewTokensAndClampsCounts() {
        #expect(CoreMLGenerationPolicy.generatedTokenSlice(from: [10, 11, 12, 13], generatedCount: 2) == [12, 13])
        #expect(CoreMLGenerationPolicy.generatedTokenSlice(from: [10, 11], generatedCount: 5) == [10, 11])
        #expect(CoreMLGenerationPolicy.generatedTokenSlice(from: [10, 11], generatedCount: 0).isEmpty)
        #expect(CoreMLGenerationPolicy.generatedTokenSlice(from: [10, 11], generatedCount: -1).isEmpty)
        #expect(CoreMLGenerationPolicy.generatedTokenSlice(from: [], generatedCount: 3).isEmpty)
    }

    @Test
    func modelArtifactURLPrefersCompiledModelBundles() throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mlmodelc = tempDir.appendingPathComponent("Preferred.mlmodelc", isDirectory: true)
        let mlpackage = tempDir.appendingPathComponent("AlsoAvailable.mlpackage", isDirectory: true)
        try FileManager.default.createDirectory(at: mlmodelc, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mlpackage, withIntermediateDirectories: true)

        let selected = try CoreMLInferenceAdapter.modelArtifactURL(in: tempDir)
        #expect(selected?.lastPathComponent == "Preferred.mlmodelc")
        #expect(selected?.pathExtension == "mlmodelc")
    }

    @Test
    func modelArtifactURLUsesStableNameOrderingWithinSameArtifactRank() throws {
        let compiledDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: compiledDir) }

        let lastCompiled = compiledDir.appendingPathComponent("Zulu.mlmodelc", isDirectory: true)
        let firstCompiled = compiledDir.appendingPathComponent("Alpha.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: lastCompiled, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: firstCompiled, withIntermediateDirectories: true)

        let selectedCompiled = try CoreMLInferenceAdapter.modelArtifactURL(in: compiledDir)
        #expect(selectedCompiled?.lastPathComponent == "Alpha.mlmodelc")

        let packageDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: packageDir) }

        let lastPackage = packageDir.appendingPathComponent("Zulu.mlpackage", isDirectory: true)
        let firstPackage = packageDir.appendingPathComponent("Alpha.mlpackage", isDirectory: true)
        try FileManager.default.createDirectory(at: lastPackage, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: firstPackage, withIntermediateDirectories: true)

        let selectedPackage = try CoreMLInferenceAdapter.modelArtifactURL(in: packageDir)
        #expect(selectedPackage?.lastPathComponent == "Alpha.mlpackage")
    }

    @Test
    func modelConfigurationUsesAllComputeUnits() {
        #expect(CoreMLInferenceAdapter.modelConfiguration().computeUnits == .all)
    }

    @Test
    func inputFeatureProviderBuildsInputIDsArray() throws {
        let provider = try CoreMLInferenceAdapter.inputFeatureProvider(tokens: [5, 7, 9])
        let input = try #require(provider.featureValue(for: "input_ids")?.multiArrayValue)

        #expect(input.shape.map(\.intValue) == [1, 3])
        #expect(input[0].intValue == 5)
        #expect(input[1].intValue == 7)
        #expect(input[2].intValue == 9)
    }

    @Test
    func inputFeatureProviderAcceptsEmptyTokenList() throws {
        let provider = try CoreMLInferenceAdapter.inputFeatureProvider(tokens: [])
        let input = try #require(provider.featureValue(for: "input_ids")?.multiArrayValue)

        #expect(input.shape.map(\.intValue) == [1, 0])
        #expect(input.count == 0)
    }

    @Test
    func nextTokenActionReadsLogitsAndAppliesEOSPolicy() throws {
        let logits = try MLMultiArray(shape: [2, 4], dataType: .float32)
        for (index, value) in [0.1, 0.2, 0.3, 0.4, -1.0, 4.0, 9.0, 7.0].enumerated() {
            logits[index] = NSNumber(value: value)
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: ["logits": logits])

        #expect(
            CoreMLInferenceAdapter.nextTokenAction(
                from: provider,
                tokenCount: 2,
                eosTokenID: nil
            ) == .append(2)
        )
        #expect(
            CoreMLInferenceAdapter.nextTokenAction(
                from: provider,
                tokenCount: 2,
                eosTokenID: 2
            ) == .stop
        )
    }

    @Test
    func nextTokenActionReturnsNilForMissingOrMalformedLogits() throws {
        let logits = try MLMultiArray(shape: [1, 3], dataType: .float32)
        logits[0] = 1
        logits[1] = 2
        logits[2] = 3
        let providerWithoutLogits = try MLDictionaryFeatureProvider(dictionary: ["hidden_states": logits])
        let providerWithShortLogits = try MLDictionaryFeatureProvider(dictionary: ["logits": logits])

        #expect(
            CoreMLInferenceAdapter.nextTokenAction(
                from: providerWithoutLogits,
                tokenCount: 1,
                eosTokenID: nil
            ) == nil
        )
        #expect(
            CoreMLInferenceAdapter.nextTokenAction(
                from: providerWithShortLogits,
                tokenCount: 2,
                eosTokenID: nil
            ) == nil
        )
        #expect(
            CoreMLInferenceAdapter.nextTokenAction(
                from: providerWithShortLogits,
                tokenCount: 0,
                eosTokenID: nil
            ) == nil
        )
    }

    @Test
    func nextTokenActionReturnsNilForZeroVocabularyLogits() throws {
        let logits = try MLMultiArray(shape: [1, 0], dataType: .float32)
        let provider = try MLDictionaryFeatureProvider(dictionary: ["logits": logits])

        #expect(
            CoreMLInferenceAdapter.nextTokenAction(
                from: provider,
                tokenCount: 1,
                eosTokenID: nil
            ) == nil
        )
    }

    @Test
    func loadedLocalModelDebugStubSurfacesInferenceError() throws {
#if DEBUG
        let model = LoadedLocalModel(testModelID: "fixture/local-model")

        #expect(model.modelID == "fixture/local-model")

        do {
            _ = try model.coreMLResources()
            Issue.record("Expected debug test stub to throw when asked for CoreML resources")
        } catch LocalInferenceError.inferenceError(let message) {
            #expect(message.contains("Test model stub does not contain inference resources"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
#endif
    }

    @Test
    func generateWithDebugStubFailsBeforeCoreMLPrediction() async throws {
#if DEBUG
        let adapter = CoreMLInferenceAdapter()
        let model = LoadedLocalModel(testModelID: "fixture/local-model")

        do {
            _ = try await adapter.generate(
                model: model,
                system: "Be terse.",
                userMessage: "Recommend a movie.",
                maxTokens: 8
            )
            Issue.record("Expected debug test stub to reject generation")
        } catch LocalInferenceError.inferenceError(let message) {
            #expect(message.contains("Test model stub does not contain inference resources"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
#endif
    }

    @Test
    func localGenerationResultStoresContentAndTokenCounts() {
        let result = LocalGenerationResult(content: "Hello world", inputTokens: 5, outputTokens: 2)
        #expect(result.content == "Hello world")
        #expect(result.inputTokens == 5)
        #expect(result.outputTokens == 2)
    }

    @Test
    func localGenerationResultIsSendable() {
        let result = LocalGenerationResult(content: "test", inputTokens: 1, outputTokens: 1)
        func assertSendable<T: Sendable>(_ value: T) {}
        assertSendable(result)
    }

    @Test
    func makeGenerationResultPreservesDecodedTextAndTokenCounts() {
        let result = CoreMLInferenceAdapter.makeGenerationResult(
            decodedText: "Decoded response",
            inputTokenCount: 13,
            generatedCount: 4
        )

        #expect(result.content == "Decoded response")
        #expect(result.inputTokens == 13)
        #expect(result.outputTokens == 4)
    }

    @Test
    func snapshotRequestUsesDefaultMatchingPatterns() {
        let request = LocalModelDownloader.snapshotRequest(repoID: "acme/local-model")

        #expect(request.repoID == "acme/local-model")
        #expect(request.matchingPatterns == LocalModelDownloader.snapshotMatchingPatterns)
    }

    @Test
    func snapshotRequestAllowsPatternOverridesWithoutMutation() {
        let custom = ["weights.bin", "tokenizer.json"]
        let request = LocalModelDownloader.snapshotRequest(
            repoID: "acme/local-model",
            matchingPatterns: custom
        )

        #expect(request.repoID == "acme/local-model")
        #expect(request.matchingPatterns == custom)
        #expect(LocalModelDownloader.snapshotMatchingPatterns != custom)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}
