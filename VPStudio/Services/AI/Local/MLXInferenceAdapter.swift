import CoreML
import Foundation
import Hub
import Tokenizers

// MARK: - Adapter Protocol

protocol LocalInferenceAdapting: Sendable {
    func loadModel(from directory: URL) async throws -> LoadedLocalModel
    func generate(
        model: LoadedLocalModel,
        system: String,
        userMessage: String,
        maxTokens: Int
    ) async throws -> LocalGenerationResult
}

// MARK: - Result Types

final class LoadedLocalModel: @unchecked Sendable {
    private enum Storage {
        case coreML(model: MLModel, tokenizer: any Tokenizers.Tokenizer)
#if DEBUG
        case placeholder
#endif
    }

    private let storage: Storage
    let modelID: String

    init(coreMLModel: MLModel, tokenizer: any Tokenizers.Tokenizer, modelID: String) {
        self.storage = .coreML(model: coreMLModel, tokenizer: tokenizer)
        self.modelID = modelID
    }

#if DEBUG
    convenience init(testModelID: String) {
        self.init(storage: .placeholder, modelID: testModelID)
    }
#endif

    private init(storage: Storage, modelID: String) {
        self.storage = storage
        self.modelID = modelID
    }

    func coreMLResources() throws -> (model: MLModel, tokenizer: any Tokenizers.Tokenizer) {
        switch storage {
        case .coreML(let model, let tokenizer):
            (model, tokenizer)
#if DEBUG
        case .placeholder:
            throw LocalInferenceError.inferenceError("Test model stub does not contain inference resources")
#endif
        }
    }
}

struct LocalGenerationResult: Sendable {
    let content: String
    let inputTokens: Int
    let outputTokens: Int
}

enum CoreMLGenerationPolicy {
    enum NextTokenAction: Equatable {
        case append(Int)
        case stop
    }

    enum StepState: Equatable {
        case append(tokens: [Int], generatedCount: Int)
        case stop
    }

    static func stepLimit(maxTokens: Int) -> Int {
        max(0, maxTokens)
    }

    static func shouldStopForEOS(nextTokenID: Int, eosTokenID: Int?) -> Bool {
        eosTokenID == nextTokenID
    }

    static func nextTokenAction(nextTokenID: Int, eosTokenID: Int?) -> NextTokenAction {
        shouldStopForEOS(nextTokenID: nextTokenID, eosTokenID: eosTokenID) ? .stop : .append(nextTokenID)
    }

    static func stateAfterAppendingToken(
        _ tokenID: Int,
        to tokens: [Int],
        generatedCount: Int
    ) -> (tokens: [Int], generatedCount: Int) {
        (tokens: tokens + [tokenID], generatedCount: generatedCount + 1)
    }

    static func state(
        after action: NextTokenAction,
        tokens: [Int],
        generatedCount: Int
    ) -> StepState {
        switch action {
        case .stop:
            return .stop
        case .append(let tokenID):
            let nextState = stateAfterAppendingToken(
                tokenID,
                to: tokens,
                generatedCount: generatedCount
            )
            return .append(tokens: nextState.tokens, generatedCount: nextState.generatedCount)
        }
    }

    static func generatedTokenSlice(from tokens: [Int], generatedCount: Int) -> [Int] {
        guard generatedCount > 0 else { return [] }
        return Array(tokens.suffix(min(generatedCount, tokens.count)))
    }
}

// MARK: - CoreML Implementation

struct CoreMLInferenceAdapter: LocalInferenceAdapting {
    static func makeGenerationResult(
        decodedText: String,
        inputTokenCount: Int,
        generatedCount: Int
    ) -> LocalGenerationResult {
        LocalGenerationResult(
            content: decodedText,
            inputTokens: inputTokenCount,
            outputTokens: generatedCount
        )
    }

    static func modelConfiguration() -> MLModelConfiguration {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        return config
    }

    static func modelArtifactURL(in directory: URL, fileManager: FileManager = .default) throws -> URL? {
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let modelArtifacts = contents.filter { $0.pathExtension == "mlmodelc" || $0.pathExtension == "mlpackage" }
        return modelArtifacts.min { lhs, rhs in
            let lhsRank = lhs.pathExtension == "mlmodelc" ? 0 : 1
            let rhsRank = rhs.pathExtension == "mlmodelc" ? 0 : 1

            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
    }

    static func prompt(system: String, userMessage: String) -> String {
        "<|system|>\n\(system)<|end|>\n<|user|>\n\(userMessage)<|end|>\n<|assistant|>\n"
    }

    static func greedyNextTokenID(logits: MLMultiArray, tokenCount: Int) -> Int? {
        guard tokenCount > 0,
              let vocabSize = logits.shape.last?.intValue,
              vocabSize > 0 else {
            return nil
        }

        let lastPosition = tokenCount - 1
        let rowStart = lastPosition * vocabSize
        guard rowStart >= 0,
              rowStart + vocabSize <= logits.count else {
            return nil
        }

        var maxIndex = 0
        var maxValue = Float(-1e9)
        for vocabIndex in 0..<vocabSize {
            let value = logits[rowStart + vocabIndex].floatValue
            if value > maxValue {
                maxValue = value
                maxIndex = vocabIndex
            }
        }
        return maxIndex
    }

    static func inputFeatureProvider(tokens: [Int]) throws -> MLFeatureProvider {
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
        for (index, token) in tokens.enumerated() {
            inputArray[index] = NSNumber(value: token)
        }
        return try MLDictionaryFeatureProvider(dictionary: ["input_ids": inputArray])
    }

    static func nextTokenAction(
        from output: MLFeatureProvider,
        tokenCount: Int,
        eosTokenID: Int?
    ) -> CoreMLGenerationPolicy.NextTokenAction? {
        guard let logits = output.featureValue(for: "logits")?.multiArrayValue,
              let tokenID = greedyNextTokenID(logits: logits, tokenCount: tokenCount) else {
            return nil
        }
        return CoreMLGenerationPolicy.nextTokenAction(nextTokenID: tokenID, eosTokenID: eosTokenID)
    }

    func loadModel(from directory: URL) async throws -> LoadedLocalModel {
        // Find .mlmodelc or .mlpackage in directory
        guard let modelURL = try Self.modelArtifactURL(in: directory) else {
            throw LocalInferenceError.inferenceError("No CoreML model found in \(directory.lastPathComponent)")
        }

        let model = try await MLModel.load(contentsOf: modelURL, configuration: Self.modelConfiguration())

        // Load tokenizer from same directory
        let tokenizer = try await AutoTokenizer.from(modelFolder: directory, hubApi: HubApi.shared)

        return LoadedLocalModel(
            coreMLModel: model,
            tokenizer: tokenizer,
            modelID: directory.lastPathComponent
        )
    }

    func generate(
        model: LoadedLocalModel,
        system: String,
        userMessage: String,
        maxTokens: Int
    ) async throws -> LocalGenerationResult {
        let resources = try model.coreMLResources()
        let coreMLModel = resources.model
        let tokenizer = resources.tokenizer
        let prompt = Self.prompt(system: system, userMessage: userMessage)
        let inputTokens = tokenizer.encode(text: prompt)
        var tokens = inputTokens
        var generatedCount = 0

        generationLoop: for _ in 0..<CoreMLGenerationPolicy.stepLimit(maxTokens: maxTokens) {
            try Task.checkCancellation()

            let input = try Self.inputFeatureProvider(tokens: tokens)
            let output = try await coreMLModel.prediction(from: input)

            let eosId = tokenizer.eosToken.flatMap { tokenizer.convertTokenToId($0) }
            guard let action = Self.nextTokenAction(
                from: output,
                tokenCount: tokens.count,
                eosTokenID: eosId
            ) else {
                break
            }

            switch CoreMLGenerationPolicy.state(
                after: action,
                tokens: tokens,
                generatedCount: generatedCount
            ) {
            case .stop:
                break generationLoop
            case .append(let nextTokens, let nextGeneratedCount):
                tokens = nextTokens
                generatedCount = nextGeneratedCount
            }
        }

        let outputTokens = CoreMLGenerationPolicy.generatedTokenSlice(from: tokens, generatedCount: generatedCount)
        let text = tokenizer.decode(tokens: outputTokens)

        return Self.makeGenerationResult(
            decodedText: text,
            inputTokenCount: inputTokens.count,
            generatedCount: generatedCount
        )
    }
}

// MARK: - Model Downloader

enum LocalModelDownloader {
    struct SnapshotRequest: Equatable {
        let repoID: String
        let matchingPatterns: [String]
    }

    static let snapshotMatchingPatterns = ["*.mlmodelc/*", "*.mlpackage/*", "*.json", "*.jinja", "tokenizer*"]

    static func snapshotRequest(
        repoID: String,
        matchingPatterns: [String] = snapshotMatchingPatterns
    ) -> SnapshotRequest {
        SnapshotRequest(repoID: repoID, matchingPatterns: matchingPatterns)
    }

    /// Downloads a HuggingFace model repo snapshot to local storage.
    static func download(
        repoID: String,
        to directory: URL,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        let request = snapshotRequest(repoID: repoID)
        let repo = Hub.Repo(id: request.repoID)
        return try await HubApi.shared.snapshot(
            from: repo,
            matching: request.matchingPatterns,
            progressHandler: progressHandler
        )
    }
}
