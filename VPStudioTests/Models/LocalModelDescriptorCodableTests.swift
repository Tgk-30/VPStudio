import Testing
import Foundation
@testable import VPStudio

@Suite("LocalModelStatus Codable Round-Trip")
struct LocalModelStatusCodableTests {
    @Test("LocalModelStatus all cases encode and decode correctly")
    func localModelStatusAllCasesCodableRoundTrip() throws {
        let statuses: [LocalModelStatus] = [.available, .downloading, .paused, .downloaded, .corrupted, .failed]

        for status in statuses {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(LocalModelStatus.self, from: encoded)
            #expect(decoded == status)
        }
    }
}

@Suite("LocalModelValidation Codable Round-Trip")
struct LocalModelValidationCodableTests {
    @Test("LocalModelValidation all cases encode and decode correctly")
    func localModelValidationAllCasesCodableRoundTrip() throws {
        let validations: [LocalModelValidation] = [.pending, .valid, .corrupt]

        for validation in validations {
            let encoded = try JSONEncoder().encode(validation)
            let decoded = try JSONDecoder().decode(LocalModelValidation.self, from: encoded)
            #expect(decoded == validation)
        }
    }
}

@Suite("LocalModelDescriptor Codable Round-Trip")
struct LocalModelDescriptorCodableTests {
    @Test("LocalModelDescriptor with all fields encodes and decodes correctly")
    func localModelDescriptorFullCodableRoundTrip() throws {
        let original = LocalModelDescriptor(
            id: "mlx-community/Qwen3.5-4B-4bit",
            displayName: "Qwen 3.5 4B",
            huggingFaceRepo: "mlx-community/Qwen3.5-4B",
            revision: "abc123def456",
            parameterCount: "4B",
            quantization: "4bit",
            diskSizeMB: 2500,
            minMemoryMB: 8000,
            expectedFileCount: 5,
            maxContextTokens: 32768,
            effectivePromptCap: 16384,
            effectiveOutputCap: 4096,
            status: .downloaded,
            downloadProgress: 1.0,
            downloadedBytes: 2_500_000_000,
            totalBytes: 2_500_000_000,
            lastProgressAt: Date(timeIntervalSince1970: 123456789),
            checksumSHA256: "abc123def456",
            validationState: .valid,
            localPath: "/models/qwen3.5-4b",
            partialDownloadPath: nil,
            isDefault: true,
            createdAt: Date(timeIntervalSince1970: 123456780),
            updatedAt: Date(timeIntervalSince1970: 123456789)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LocalModelDescriptor.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.huggingFaceRepo == original.huggingFaceRepo)
        #expect(decoded.revision == original.revision)
        #expect(decoded.parameterCount == original.parameterCount)
        #expect(decoded.quantization == original.quantization)
        #expect(decoded.diskSizeMB == original.diskSizeMB)
        #expect(decoded.minMemoryMB == original.minMemoryMB)
        #expect(decoded.expectedFileCount == original.expectedFileCount)
        #expect(decoded.maxContextTokens == original.maxContextTokens)
        #expect(decoded.effectivePromptCap == original.effectivePromptCap)
        #expect(decoded.effectiveOutputCap == original.effectiveOutputCap)
        #expect(decoded.status == original.status)
        #expect(decoded.downloadProgress == original.downloadProgress)
        #expect(decoded.downloadedBytes == original.downloadedBytes)
        #expect(decoded.totalBytes == original.totalBytes)
        #expect(decoded.checksumSHA256 == original.checksumSHA256)
        #expect(decoded.validationState == original.validationState)
        #expect(decoded.localPath == original.localPath)
        #expect(decoded.partialDownloadPath == nil)
        #expect(decoded.isDefault == original.isDefault)
    }

    @Test("LocalModelDescriptor with nil optionals encodes and decodes correctly")
    func localModelDescriptorNilOptionalsCodableRoundTrip() throws {
        let original = LocalModelDescriptor(
            id: "minimal-model",
            displayName: "Minimal Model",
            huggingFaceRepo: "org/model",
            revision: "rev123",
            parameterCount: "3B",
            quantization: "8bit",
            diskSizeMB: 5000,
            minMemoryMB: 4000,
            expectedFileCount: 3,
            maxContextTokens: 8192,
            effectivePromptCap: 4096,
            effectiveOutputCap: 1024,
            status: .available,
            downloadProgress: 0.0,
            downloadedBytes: 0,
            totalBytes: 5_000_000_000,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LocalModelDescriptor.self, from: encoded)

        #expect(decoded.lastProgressAt == nil)
        #expect(decoded.checksumSHA256 == nil)
        #expect(decoded.localPath == nil)
        #expect(decoded.partialDownloadPath == nil)
    }

    @Test("LocalModelDescriptor canTransition is correct for all combinations")
    func localModelDescriptorCanTransitionCombinations() {
        let validTransitions: [(LocalModelStatus, LocalModelStatus)] = [
            (.available, .downloading),
            (.available, .failed),
            (.downloading, .downloaded),
            (.downloading, .paused),
            (.downloading, .failed),
            (.paused, .downloading),
            (.failed, .downloading),
            (.downloaded, .corrupted),
            (.corrupted, .available),
        ]

        for (from, to) in validTransitions {
            #expect(LocalModelDescriptor.canTransition(from: from, to: to) == true)
        }

        let invalidTransitions: [(LocalModelStatus, LocalModelStatus)] = [
            (.available, .paused),
            (.downloading, .available),
            (.paused, .downloaded),
            (.downloaded, .available),
            (.corrupted, .downloading),
        ]

        for (from, to) in invalidTransitions {
            #expect(LocalModelDescriptor.canTransition(from: from, to: to) == false)
        }
    }

    @Test("LocalModelDescriptor resetToAvailable works correctly")
    func localModelDescriptorResetToAvailable() throws {
        var descriptor = LocalModelDescriptor(
            id: "test-model",
            displayName: "Test",
            huggingFaceRepo: "test/repo",
            revision: "abc",
            parameterCount: "4B",
            quantization: "4bit",
            diskSizeMB: 1000,
            minMemoryMB: 2000,
            expectedFileCount: 5,
            maxContextTokens: 32768,
            effectivePromptCap: 16384,
            effectiveOutputCap: 4096,
            status: .downloaded,
            downloadProgress: 1.0,
            downloadedBytes: 1_000_000,
            totalBytes: 1_000_000,
            lastProgressAt: Date(),
            checksumSHA256: "checksum",
            validationState: .valid,
            localPath: "/path/to/model",
            partialDownloadPath: "/path/to/partial",
            isDefault: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        descriptor.resetToAvailable()

        #expect(descriptor.status == .available)
        #expect(descriptor.downloadProgress == 0.0)
        #expect(descriptor.downloadedBytes == 0)
        #expect(descriptor.lastProgressAt == nil)
        #expect(descriptor.localPath == nil)
        #expect(descriptor.partialDownloadPath == nil)
        #expect(descriptor.validationState == .pending)
    }

    @Test("LocalModelDescriptor effectiveCaps for Vision Pro")
    func localModelDescriptorEffectiveCapsVisionPro() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 32768, isVisionPro: true)
        #expect(caps.promptCap == 8192)
        #expect(caps.outputCap == 2048)
    }

    @Test("LocalModelDescriptor effectiveCaps for Mac")
    func localModelDescriptorEffectiveCapsMac() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 32768, isVisionPro: false)
        #expect(caps.promptCap == 32768)
        #expect(caps.outputCap == 4096)
    }

    @Test("LocalModelDescriptor effectiveCaps respects native context limits")
    func localModelDescriptorEffectiveCapsRespectsLimits() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 4096, isVisionPro: false)
        #expect(caps.promptCap == 4096)
        #expect(caps.outputCap == 4096)
    }
}
