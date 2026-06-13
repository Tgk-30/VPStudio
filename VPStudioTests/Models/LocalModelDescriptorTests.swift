import Testing
import Foundation
import GRDB
@testable import VPStudio

@Suite("LocalModelStatus Enum")
struct LocalModelStatusTests {
    @Test("LocalModelStatus raw values")
    func rawValues() {
        #expect(LocalModelStatus.available.rawValue == "available")
        #expect(LocalModelStatus.downloading.rawValue == "downloading")
        #expect(LocalModelStatus.paused.rawValue == "paused")
        #expect(LocalModelStatus.downloaded.rawValue == "downloaded")
        #expect(LocalModelStatus.corrupted.rawValue == "corrupted")
        #expect(LocalModelStatus.failed.rawValue == "failed")
    }

    @Test("LocalModelStatus Codable round-trip")
    func codableRoundTrip() throws {
        let original = LocalModelStatus.downloading
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LocalModelStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test("LocalModelStatus is Equatable")
    func equatableConformance() {
        #expect(LocalModelStatus.available == .available)
        #expect(LocalModelStatus.available != .downloading)
    }
}

@Suite("LocalModelValidation Enum")
struct LocalModelValidationTests {
    @Test("LocalModelValidation raw values")
    func rawValues() {
        #expect(LocalModelValidation.pending.rawValue == "pending")
        #expect(LocalModelValidation.valid.rawValue == "valid")
        #expect(LocalModelValidation.corrupt.rawValue == "corrupt")
    }

    @Test("LocalModelValidation Codable round-trip")
    func codableRoundTrip() throws {
        let original = LocalModelValidation.valid
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LocalModelValidation.self, from: data)
        #expect(decoded == original)
    }

    @Test("LocalModelValidation is Equatable")
    func equatableConformance() {
        #expect(LocalModelValidation.pending == .pending)
        #expect(LocalModelValidation.pending != .valid)
    }
}

@Suite("LocalModelDescriptor Properties")
struct LocalModelDescriptorModelTests {
    @Test("Database table name is correct")
    func databaseTableName() {
        #expect(LocalModelDescriptor.databaseTableName == "local_models")
    }

    @Test("Identifiable conformance")
    func identifiableConformance() {
        let descriptor = LocalModelDescriptor(
            id: "test-model",
            displayName: "Test Model",
            huggingFaceRepo: "test/repo",
            revision: "abc123",
            parameterCount: "4B",
            quantization: "4bit",
            diskSizeMB: 1000,
            minMemoryMB: 2000,
            expectedFileCount: 5,
            maxContextTokens: 32768,
            effectivePromptCap: 16384,
            effectiveOutputCap: 4096,
            status: .available,
            downloadProgress: 0.0,
            downloadedBytes: 0,
            totalBytes: 1000000,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        #expect(descriptor.id == "test-model")
    }

    @Test("Equatable conformance")
    func equatableConformance() {
        let now = Date()
        let descriptor1 = LocalModelDescriptor(
            id: "test-model",
            displayName: "Test Model",
            huggingFaceRepo: "test/repo",
            revision: "abc123",
            parameterCount: "4B",
            quantization: "4bit",
            diskSizeMB: 1000,
            minMemoryMB: 2000,
            expectedFileCount: 5,
            maxContextTokens: 32768,
            effectivePromptCap: 16384,
            effectiveOutputCap: 4096,
            status: .available,
            downloadProgress: 0.0,
            downloadedBytes: 0,
            totalBytes: 1000000,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: now,
            updatedAt: now
        )

        let descriptor2 = LocalModelDescriptor(
            id: "test-model",
            displayName: "Test Model",
            huggingFaceRepo: "test/repo",
            revision: "abc123",
            parameterCount: "4B",
            quantization: "4bit",
            diskSizeMB: 1000,
            minMemoryMB: 2000,
            expectedFileCount: 5,
            maxContextTokens: 32768,
            effectivePromptCap: 16384,
            effectiveOutputCap: 4096,
            status: .available,
            downloadProgress: 0.0,
            downloadedBytes: 0,
            totalBytes: 1000000,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: now,
            updatedAt: now
        )

        #expect(descriptor1 == descriptor2)
    }
}

@Suite("LocalModelDescriptor State Machine")
struct LocalModelDescriptorStateMachineModelTests {
    @Test("Valid status transitions")
    func validTransitions() {
        #expect(LocalModelDescriptor.canTransition(from: .available, to: .downloading) == true)
        #expect(LocalModelDescriptor.canTransition(from: .downloading, to: .downloaded) == true)
        #expect(LocalModelDescriptor.canTransition(from: .downloading, to: .paused) == true)
        #expect(LocalModelDescriptor.canTransition(from: .downloading, to: .failed) == true)
        #expect(LocalModelDescriptor.canTransition(from: .paused, to: .downloading) == true)
        #expect(LocalModelDescriptor.canTransition(from: .failed, to: .downloading) == true)
        #expect(LocalModelDescriptor.canTransition(from: .downloaded, to: .corrupted) == true)
        #expect(LocalModelDescriptor.canTransition(from: .corrupted, to: .available) == true)
    }

    @Test("Invalid status transitions")
    func invalidTransitions() {
        #expect(LocalModelDescriptor.canTransition(from: .available, to: .paused) == false)
        #expect(LocalModelDescriptor.canTransition(from: .available, to: .failed) == false)
        #expect(LocalModelDescriptor.canTransition(from: .downloading, to: .available) == false)
        #expect(LocalModelDescriptor.canTransition(from: .paused, to: .downloaded) == false)
        #expect(LocalModelDescriptor.canTransition(from: .downloaded, to: .available) == false)
        #expect(LocalModelDescriptor.canTransition(from: .corrupted, to: .downloading) == false)
    }

    @Test("Reset to available state")
    func resetToAvailable() {
        let originalUpdatedAt = Date(timeIntervalSince1970: 10)
        var descriptor = LocalModelDescriptor(
            id: "test-model",
            displayName: "Test Model",
            huggingFaceRepo: "test/repo",
            revision: "abc123",
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
            downloadedBytes: 1000000,
            totalBytes: 1000000,
            lastProgressAt: Date(),
            checksumSHA256: "abc123",
            validationState: .valid,
            localPath: "/path/to/model",
            partialDownloadPath: "/path/to/partial",
            isDefault: true,
            createdAt: Date(),
            updatedAt: originalUpdatedAt
        )

        let beforeReset = Date()
        descriptor.resetToAvailable()

        #expect(descriptor.status == .available)
        #expect(descriptor.downloadProgress == 0.0)
        #expect(descriptor.downloadedBytes == 0)
        #expect(descriptor.lastProgressAt == nil)
        #expect(descriptor.localPath == nil)
        #expect(descriptor.partialDownloadPath == nil)
        #expect(descriptor.validationState == .pending)
        #expect(descriptor.updatedAt >= beforeReset)
        #expect(descriptor.updatedAt != originalUpdatedAt)
    }
}

@Suite("LocalModelDescriptor Device Caps")
struct LocalModelDescriptorDeviceCapsTests {
    @Test("Vision Pro device caps")
    func visionProCaps() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 32768, isVisionPro: true)
        #expect(caps.promptCap == 8192)
        #expect(caps.outputCap == 2048)
    }

    @Test("Mac device caps")
    func macCaps() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 32768, isVisionPro: false)
        #expect(caps.promptCap == 32768)
        #expect(caps.outputCap == 4096)
    }

    @Test("Device caps respect native context limits")
    func respectNativeContextLimits() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 10000, isVisionPro: false)
        #expect(caps.promptCap == 10000)
        #expect(caps.outputCap == 4096)
    }

    @Test("Vision Pro caps also respect smaller native context limits")
    func visionProCapsRespectSmallNativeContext() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 4096, isVisionPro: true)
        #expect(caps.promptCap == 4096)
        #expect(caps.outputCap == 2048)
    }
}

@Suite("LocalModelDescriptor GRDB Row")
struct LocalModelDescriptorGRDBRowTests {
    @Test("LocalModelDescriptor initializes from a full GRDB row")
    func rowInitialization() throws {
        let lastProgressAt = Date(timeIntervalSince1970: 300)
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let row = Row([
            "id": "mlx/test-model",
            "displayName": "Test Model",
            "huggingFaceRepo": "mlx/test-model",
            "revision": "abc123",
            "parameterCount": "4B",
            "quantization": "4bit",
            "diskSizeMB": 1234,
            "minMemoryMB": 2048,
            "expectedFileCount": 12,
            "maxContextTokens": 32768,
            "effectivePromptCap": 8192,
            "effectiveOutputCap": 2048,
            "status": LocalModelStatus.downloading.rawValue,
            "downloadProgress": 0.42,
            "downloadedBytes": Int64(420),
            "totalBytes": Int64(1000),
            "lastProgressAt": lastProgressAt,
            "checksumSHA256": "checksum",
            "validationState": LocalModelValidation.pending.rawValue,
            "localPath": "/models/test",
            "partialDownloadPath": "/models/test.partial",
            "isDefault": true,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
        ])

        let descriptor = try LocalModelDescriptor(row: row)

        #expect(descriptor.id == "mlx/test-model")
        #expect(descriptor.displayName == "Test Model")
        #expect(descriptor.huggingFaceRepo == "mlx/test-model")
        #expect(descriptor.status == .downloading)
        #expect(descriptor.downloadProgress == 0.42)
        #expect(descriptor.downloadedBytes == 420)
        #expect(descriptor.totalBytes == 1000)
        #expect(descriptor.lastProgressAt == lastProgressAt)
        #expect(descriptor.checksumSHA256 == "checksum")
        #expect(descriptor.validationState == .pending)
        #expect(descriptor.localPath == "/models/test")
        #expect(descriptor.partialDownloadPath == "/models/test.partial")
        #expect(descriptor.isDefault)
        #expect(descriptor.createdAt == createdAt)
        #expect(descriptor.updatedAt == updatedAt)
    }
}

@Suite("LocalModelDescriptor Codable")
struct LocalModelDescriptorCodableTestsModelsLocalmodeldescriptortests {
    @Test("LocalModelDescriptor encodes and decodes correctly")
    func codableRoundTrip() throws {
        let original = LocalModelDescriptor(
            id: "test-model",
            displayName: "Test Model",
            huggingFaceRepo: "test/repo",
            revision: "abc123",
            parameterCount: "4B",
            quantization: "4bit",
            diskSizeMB: 1000,
            minMemoryMB: 2000,
            expectedFileCount: 5,
            maxContextTokens: 32768,
            effectivePromptCap: 16384,
            effectiveOutputCap: 4096,
            status: .available,
            downloadProgress: 0.0,
            downloadedBytes: 0,
            totalBytes: 1000000,
            lastProgressAt: nil,
            checksumSHA256: "abc123",
            validationState: .pending,
            localPath: "/path/to/model",
            partialDownloadPath: "/path/to/partial",
            isDefault: false,
            createdAt: Date(timeIntervalSince1970: 123456789),
            updatedAt: Date(timeIntervalSince1970: 123456790)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LocalModelDescriptor.self, from: data)

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
        #expect(decoded.partialDownloadPath == original.partialDownloadPath)
        #expect(decoded.isDefault == original.isDefault)
        #expect(decoded.createdAt == original.createdAt)
        #expect(decoded.updatedAt == original.updatedAt)
    }

    @Test("LocalModelDescriptor with nil optional fields")
    func codableWithNilOptionals() throws {
        let original = LocalModelDescriptor(
            id: "test-model",
            displayName: "Test Model",
            huggingFaceRepo: "test/repo",
            revision: "abc123",
            parameterCount: "4B",
            quantization: "4bit",
            diskSizeMB: 1000,
            minMemoryMB: 2000,
            expectedFileCount: 5,
            maxContextTokens: 32768,
            effectivePromptCap: 16384,
            effectiveOutputCap: 4096,
            status: .available,
            downloadProgress: 0.0,
            downloadedBytes: 0,
            totalBytes: 1000000,
            lastProgressAt: nil,
            checksumSHA256: nil,
            validationState: .pending,
            localPath: nil,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LocalModelDescriptor.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.lastProgressAt == nil)
        #expect(decoded.checksumSHA256 == nil)
        #expect(decoded.localPath == nil)
        #expect(decoded.partialDownloadPath == nil)
    }
}
