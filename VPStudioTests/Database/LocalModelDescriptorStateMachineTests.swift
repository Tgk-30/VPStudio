import Foundation
import Testing
@testable import VPStudio

@Suite("Local Model Descriptor State Machine")
struct LocalModelDescriptorStateMachineTests {

    // MARK: - Valid Transitions

    @Test func canTransitionFromAvailableToDownloading() {
        #expect(LocalModelDescriptor.canTransition(from: .available, to: .downloading))
    }

    @Test func canTransitionFromDownloadingToDownloaded() {
        #expect(LocalModelDescriptor.canTransition(from: .downloading, to: .downloaded))
    }

    @Test func canTransitionFromDownloadingToPaused() {
        #expect(LocalModelDescriptor.canTransition(from: .downloading, to: .paused))
    }

    @Test func canTransitionFromDownloadingToFailed() {
        #expect(LocalModelDescriptor.canTransition(from: .downloading, to: .failed))
    }

    @Test func canTransitionFromPausedToDownloading() {
        #expect(LocalModelDescriptor.canTransition(from: .paused, to: .downloading))
    }

    @Test func canTransitionFromFailedToDownloading() {
        #expect(LocalModelDescriptor.canTransition(from: .failed, to: .downloading))
    }

    @Test func canTransitionFromDownloadedToCorrupted() {
        #expect(LocalModelDescriptor.canTransition(from: .downloaded, to: .corrupted))
    }

    @Test func canTransitionFromCorruptedToAvailable() {
        #expect(LocalModelDescriptor.canTransition(from: .corrupted, to: .available))
    }

    // MARK: - Invalid Transitions

    @Test func cannotTransitionFromAvailableToAvailable() {
        #expect(!LocalModelDescriptor.canTransition(from: .available, to: .available))
    }

    @Test func cannotTransitionFromAvailableToDownloaded() {
        #expect(!LocalModelDescriptor.canTransition(from: .available, to: .downloaded))
    }

    @Test func cannotTransitionFromAvailableToFailed() {
        #expect(!LocalModelDescriptor.canTransition(from: .available, to: .failed))
    }

    @Test func cannotTransitionFromDownloadingToAvailable() {
        #expect(!LocalModelDescriptor.canTransition(from: .downloading, to: .available))
    }

    @Test func cannotTransitionFromPausedToDownloaded() {
        #expect(!LocalModelDescriptor.canTransition(from: .paused, to: .downloaded))
    }

    @Test func cannotTransitionFromDownloadedToAvailable() {
        #expect(!LocalModelDescriptor.canTransition(from: .downloaded, to: .available))
    }

    @Test func cannotTransitionFromDownloadedToDownloaded() {
        #expect(!LocalModelDescriptor.canTransition(from: .downloaded, to: .downloaded))
    }

    @Test func cannotTransitionFromCorruptedToDownloaded() {
        #expect(!LocalModelDescriptor.canTransition(from: .corrupted, to: .downloaded))
    }

    // MARK: - Reset to Available

    @Test func resetToAvailableSetsStatusToAvailable() {
        var descriptor = makeDescriptor(status: .failed)
        descriptor.resetToAvailable()
        #expect(descriptor.status == .available)
    }

    @Test func resetToAvailableZerosDownloadProgress() {
        var descriptor = makeDescriptor(downloadProgress: 0.73)
        descriptor.resetToAvailable()
        #expect(descriptor.downloadProgress == 0)
    }

    @Test func resetToAvailableZerosDownloadedBytes() {
        var descriptor = makeDescriptor(downloadedBytes: 42_000)
        descriptor.resetToAvailable()
        #expect(descriptor.downloadedBytes == 0)
    }

    @Test func resetToAvailableClearsLastProgressAt() {
        var descriptor = makeDescriptor(lastProgressAt: Date())
        descriptor.resetToAvailable()
        #expect(descriptor.lastProgressAt == nil)
    }

    @Test func resetToAvailableClearsLocalPath() {
        var descriptor = makeDescriptor(localPath: "/models/test.gguf")
        descriptor.resetToAvailable()
        #expect(descriptor.localPath == nil)
    }

    @Test func resetToAvailableResetsValidationStateToPending() {
        var descriptor = makeDescriptor(validationState: .corrupt)
        descriptor.resetToAvailable()
        #expect(descriptor.validationState == .pending)
    }

    // MARK: - Effective Caps

    @Test func effectiveCapsVisionProPromptCapCappedAt8192() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 100_000, isVisionPro: true)
        #expect(caps.promptCap == 8192)
    }

    @Test func effectiveCapsMacPromptCapCappedAt32768() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 100_000, isVisionPro: false)
        #expect(caps.promptCap == 32768)
    }

    @Test func effectiveCapsVisionProPromptCapAtExactBoundary() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 8192, isVisionPro: true)
        #expect(caps.promptCap == 8192)
    }

    @Test func effectiveCapsMacPromptCapAtExactBoundary() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 32768, isVisionPro: false)
        #expect(caps.promptCap == 32768)
    }

    @Test func effectiveCapsVisionProPromptCapBelowBoundary() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 4096, isVisionPro: true)
        #expect(caps.promptCap == 4096)
    }

    @Test func effectiveCapsMacPromptCapBelowBoundary() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 16384, isVisionPro: false)
        #expect(caps.promptCap == 16384)
    }

    @Test func effectiveCapsWithZeroNativeContext() {
        let visionPro = LocalModelDescriptor.effectiveCaps(nativeContext: 0, isVisionPro: true)
        let mac = LocalModelDescriptor.effectiveCaps(nativeContext: 0, isVisionPro: false)
        #expect(visionPro.promptCap == 0)
        #expect(mac.promptCap == 0)
        #expect(visionPro.outputCap == 2048)
        #expect(mac.outputCap == 4096)
    }

    @Test func effectiveCapsVisionProOutputCapIs2048() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 16384, isVisionPro: true)
        #expect(caps.outputCap == 2048)
    }

    @Test func effectiveCapsMacOutputCapIs4096() {
        let caps = LocalModelDescriptor.effectiveCaps(nativeContext: 16384, isVisionPro: false)
        #expect(caps.outputCap == 4096)
    }

    @Test func effectiveCapsOutputCapIndependentOfNativeContext() {
        let small = LocalModelDescriptor.effectiveCaps(nativeContext: 512, isVisionPro: false)
        let large = LocalModelDescriptor.effectiveCaps(nativeContext: 131_072, isVisionPro: false)
        #expect(small.outputCap == 4096)
        #expect(large.outputCap == 4096)
    }

    // MARK: - Helpers

    private func makeDescriptor(
        status: LocalModelStatus = .available,
        downloadProgress: Double = 0,
        downloadedBytes: Int64 = 0,
        lastProgressAt: Date? = nil,
        localPath: String? = nil,
        validationState: LocalModelValidation = .pending
    ) -> LocalModelDescriptor {
        LocalModelDescriptor(
            id: "local/test",
            displayName: "Test Model",
            huggingFaceRepo: "local/test",
            revision: "main",
            parameterCount: "1B",
            quantization: "4bit",
            diskSizeMB: 100,
            minMemoryMB: 256,
            expectedFileCount: 1,
            maxContextTokens: 2048,
            effectivePromptCap: 1024,
            effectiveOutputCap: 512,
            status: status,
            downloadProgress: downloadProgress,
            downloadedBytes: downloadedBytes,
            totalBytes: 100_000,
            lastProgressAt: lastProgressAt,
            checksumSHA256: "abc123",
            validationState: validationState,
            localPath: localPath,
            partialDownloadPath: nil,
            isDefault: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
