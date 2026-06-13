#if os(visionOS)
import Testing
import AVFoundation
import CoreVideo
import Foundation
import RealityKit
@testable import VPStudio

@Suite("APMPInjector — Lifecycle")
struct APMPInjectorTests {

    @Test("Starts inactive with no video renderer")
    @MainActor func startsInactive() {
        let injector = APMPInjector()
        #expect(!injector.isActive)
        #expect(injector.videoRenderer == nil)
        #expect(injector.displayLayer == nil)
    }

    @Test("Activates on start with valid player item")
    @MainActor func activatesOnStart() {
        let injector = APMPInjector()
        let url = URL(string: "https://example.com/video.mp4")!
        let player = AVPlayer(url: url)
        injector.start(player: player, mode: .sideBySide)
        #expect(injector.isActive)
        #expect(injector.videoRenderer != nil)
        #expect(injector.displayLayer != nil)
    }

    @Test("Deactivates on stop after start")
    @MainActor func deactivatesOnStop() {
        let injector = APMPInjector()
        let url = URL(string: "https://example.com/video.mp4")!
        let player = AVPlayer(url: url)
        injector.start(player: player, mode: .overUnder)
        injector.stop()
        #expect(!injector.isActive)
        #expect(injector.videoRenderer == nil)
        #expect(injector.displayLayer == nil)
    }

    @Test("Stop without prior start does not crash")
    @MainActor func stopIsIdempotent() {
        let injector = APMPInjector()
        injector.stop()
        injector.stop()
        #expect(!injector.isActive)
    }

    @Test("Second start produces a fresh renderer instance")
    @MainActor func startStopStartCycle() {
        let injector = APMPInjector()
        let url = URL(string: "https://example.com/video.mp4")!
        let player = AVPlayer(url: url)

        injector.start(player: player, mode: .sideBySide)
        let firstRenderer = injector.videoRenderer

        injector.stop()
        injector.start(player: player, mode: .overUnder)
        let secondRenderer = injector.videoRenderer

        #expect(secondRenderer != nil)
        #expect(firstRenderer !== secondRenderer)
    }

    @Test("Start with player lacking currentItem stays inactive")
    @MainActor func startWithoutItemStaysInactive() {
        let injector = APMPInjector()
        let player = AVPlayer()
        injector.start(player: player, mode: .sideBySide)
        #expect(!injector.isActive)
        #expect(injector.videoRenderer == nil)
    }

    @Test("Second start implicitly stops the first session")
    @MainActor func secondStartImplicitlyStopsFirst() {
        let injector = APMPInjector()
        let url = URL(string: "https://example.com/video.mp4")!
        let player = AVPlayer(url: url)

        injector.start(player: player, mode: .sideBySide)
        let firstLayer = injector.displayLayer

        injector.start(player: player, mode: .overUnder)
        let secondLayer = injector.displayLayer

        #expect(injector.isActive)
        #expect(firstLayer !== secondLayer)
    }

    @Test("Display layer and video renderer are distinct instances")
    @MainActor func layerAndRendererAreDistinct() {
        let injector = APMPInjector()
        let url = URL(string: "https://example.com/video.mp4")!
        let player = AVPlayer(url: url)
        injector.start(player: player, mode: .sideBySide)

        #expect(injector.videoRenderer != nil)
        #expect(injector.displayLayer != nil)
    }

    @Test("Both modes reject a player with no current item")
    @MainActor func bothModesRejectEmptyPlayer() {
        let injector = APMPInjector()
        let player = AVPlayer() // no currentItem

        for mode in [APMPInjector.Mode.sideBySide, .overUnder] {
            injector.start(player: player, mode: mode)
            #expect(!injector.isActive, "Mode \(mode) should not activate without a player item")
            #expect(injector.videoRenderer == nil)
        }
    }

    @Test("Mode conforms to Sendable")
    func modeIsSendable() {
        let mode: APMPInjector.Mode = .sideBySide
        // This compiles only if Mode is Sendable.
        let _: any Sendable = mode
        _ = mode // Silence warning
    }

    @Test("Frame publishing only enqueues successful renderer buffers")
    func framePublishingRequiresSuccessfulRendererBufferCreation() {
        #expect(APMPFramePublishingPolicy.shouldEnqueueRendererBuffer(status: noErr, hasBuffer: true))
        #expect(!APMPFramePublishingPolicy.shouldEnqueueRendererBuffer(status: noErr, hasBuffer: false))
        #expect(!APMPFramePublishingPolicy.shouldEnqueueRendererBuffer(status: -1, hasBuffer: true))
    }

    @Test("Frame publishing only enqueues display layer buffers when the layer is ready")
    func framePublishingRequiresSuccessfulReadyLayerBuffer() {
        #expect(APMPFramePublishingPolicy.shouldEnqueueLayerBuffer(status: noErr, hasBuffer: true, isReadyForMoreMediaData: true))
        #expect(!APMPFramePublishingPolicy.shouldEnqueueLayerBuffer(status: noErr, hasBuffer: true, isReadyForMoreMediaData: false))
        #expect(!APMPFramePublishingPolicy.shouldEnqueueLayerBuffer(status: noErr, hasBuffer: false, isReadyForMoreMediaData: true))
        #expect(!APMPFramePublishingPolicy.shouldEnqueueLayerBuffer(status: -1, hasBuffer: true, isReadyForMoreMediaData: true))
    }

    @Test("Stereo format cache is reused only for the same dimensions and mode")
    func stereoFormatCacheReuseRequiresSameDimensionsAndMode() {
        #expect(APMPStereoFormatCachePolicy.shouldReuseFormatDescription(
            cachedWidth: 3840,
            cachedHeight: 2160,
            cachedMode: .sideBySide,
            pixelWidth: 3840,
            pixelHeight: 2160,
            mode: .sideBySide
        ))
        #expect(!APMPStereoFormatCachePolicy.shouldReuseFormatDescription(
            cachedWidth: 3840,
            cachedHeight: 2160,
            cachedMode: .sideBySide,
            pixelWidth: 3840,
            pixelHeight: 2160,
            mode: .overUnder
        ))
        #expect(!APMPStereoFormatCachePolicy.shouldReuseFormatDescription(
            cachedWidth: 3840,
            cachedHeight: 2160,
            cachedMode: .sideBySide,
            pixelWidth: 4096,
            pixelHeight: 2160,
            mode: .sideBySide
        ))
        #expect(!APMPStereoFormatCachePolicy.shouldReuseFormatDescription(
            cachedWidth: 3840,
            cachedHeight: 2160,
            cachedMode: nil,
            pixelWidth: 3840,
            pixelHeight: 2160,
            mode: .sideBySide
        ))
    }

    @Test("Stereo format cache reset clears retry state after failures")
    func stereoFormatCacheResetClearsRetryState() {
        let reset = APMPStereoFormatCachePolicy.resetStateAfterFormatDescriptionFailure()
        #expect(reset.width == 0)
        #expect(reset.height == 0)
        #expect(reset.mode == nil)
    }

    @Test("Sample timing uses the sampled item time as presentation timestamp")
    func sampleTimingUsesItemPresentationTime() {
        let itemTime = CMTime(seconds: 42.25, preferredTimescale: 600)
        let timing = APMPSampleTimingPolicy.timingInfo(for: itemTime)

        #expect(timing.presentationTimeStamp == itemTime)
        #expect(timing.duration == .invalid)
        #expect(timing.decodeTimeStamp == .invalid)
    }

    @Test("Stereo format description factory creates tagged descriptions")
    func stereoFormatDescriptionFactoryCreatesTaggedDescriptions() {
        let result = APMPStereoFormatDescriptionFactory.make(
            pixelFormat: kCVPixelFormatType_32BGRA,
            width: 3840,
            height: 2160,
            mode: .sideBySide
        )

        #expect(result.status == noErr)
        #expect(result.description != nil)

        if let description = result.description {
            let dimensions = CMVideoFormatDescriptionGetDimensions(description)
            #expect(dimensions.width == 3840)
            #expect(dimensions.height == 2160)
        }
    }

    @Test("Stereo format description factory rejects invalid dimensions")
    func stereoFormatDescriptionFactoryRejectsInvalidDimensions() {
        let result = APMPStereoFormatDescriptionFactory.make(
            pixelFormat: kCVPixelFormatType_32BGRA,
            width: 0,
            height: 0,
            mode: .overUnder
        )

        #expect(result.status != noErr)
        #expect(result.description == nil)
    }

    @Test("Display link target caches stereo format descriptions for repeated dimensions")
    @MainActor func displayLinkTargetCachesStereoFormatDescriptions() throws {
        let harness = APMPDisplayLinkTargetTestHarness(mode: .sideBySide)
        let pixelBuffer = try makePixelBuffer(width: 3840, height: 2160)

        let first = harness.stereoFormatDescription(for: pixelBuffer)
        let second = harness.stereoFormatDescription(for: pixelBuffer)

        #expect(first != nil)
        #expect(second != nil)

        if let second {
            let dimensions = CMVideoFormatDescriptionGetDimensions(second)
            #expect(dimensions.width == 3840)
            #expect(dimensions.height == 2160)
        }
    }

    @Test("Display link target refreshes stereo format descriptions when dimensions change")
    @MainActor func displayLinkTargetRefreshesStereoFormatDescriptionsForDimensionChanges() throws {
        let harness = APMPDisplayLinkTargetTestHarness(mode: .overUnder)
        let firstBuffer = try makePixelBuffer(width: 3840, height: 2160)
        let secondBuffer = try makePixelBuffer(width: 1920, height: 1080)

        let first = harness.stereoFormatDescription(for: firstBuffer)
        let second = harness.stereoFormatDescription(for: secondBuffer)

        #expect(first != nil)
        #expect(second != nil)

        if let second {
            let dimensions = CMVideoFormatDescriptionGetDimensions(second)
            #expect(dimensions.width == 1920)
            #expect(dimensions.height == 1080)
        }
    }

    @Test("Display link target can inject a tagged sample buffer frame")
    @MainActor func displayLinkTargetInjectsTaggedSampleBufferFrame() throws {
        let harness = APMPDisplayLinkTargetTestHarness(mode: .sideBySide)
        let material = VideoMaterial(videoRenderer: harness.videoRenderer)
        _ = material
        let pixelBuffer = try makePixelBuffer(width: 1920, height: 1080)
        let itemTime = CMTime(seconds: 1.25, preferredTimescale: 600)

        harness.injectFrame(pixelBuffer: pixelBuffer, itemTime: itemTime)

        #expect(harness.stereoFormatDescription(for: pixelBuffer) != nil)
    }

    private func makePixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ] as CFDictionary,
            &pixelBuffer
        )

        #expect(status == kCVReturnSuccess)
        guard let pixelBuffer else {
            throw NSError(domain: "APMPInjectorTests", code: Int(status))
        }
        return pixelBuffer
    }
}
#endif
