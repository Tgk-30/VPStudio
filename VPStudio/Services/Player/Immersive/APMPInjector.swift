#if os(visionOS)
import AVFoundation
import CoreMedia
import CoreVideo
import os
import QuartzCore

private let logger = Logger(subsystem: "com.vpstudio", category: "APMPInjector")

/// Injects spatial-video metadata into frames from an `AVPlayer` item so that
/// an `AVSampleBufferVideoRenderer` (used by RealityKit `VideoMaterial`) and an
/// `AVSampleBufferDisplayLayer` (used in the PlayerView window) both receive
/// properly-tagged sample buffers for side-by-side or over-under 3D content.
///
/// ## Stereo Tagging
/// Each sample buffer's format description includes `ProjectionKind`,
/// `ViewPackingKind`, `HasLeftStereoEyeView`, `HasRightStereoEyeView`, and
/// `HeroStereoEye` extensions matching the configured `Mode`. This tells the
/// visionOS spatial compositor how to present the two eye views.
///
/// ## Buffer Isolation
/// The renderer and display layer each receive their own `CMSampleBuffer`
/// instance (backed by the same pixel buffer). This prevents one consumer's
/// lifecycle from affecting the other.
@MainActor
final class APMPInjector {
    enum Mode: Sendable { case sideBySide, overUnder }

    private(set) var isActive = false
    private(set) var videoRenderer: AVSampleBufferVideoRenderer?
    private(set) var displayLayer: AVSampleBufferDisplayLayer?

    private var displayLink: CADisplayLink?
    private var videoOutput: AVPlayerItemVideoOutput?
    private weak var weakPlayer: AVPlayer?
    /// Strong reference to the player item that owns our `videoOutput`.
    /// Stored directly so `stop()` can reliably remove the output even if the
    /// player's `currentItem` has changed since `start()`.
    private var trackedItem: AVPlayerItem?

    @MainActor deinit {
        stop()
    }

    func start(player: AVPlayer, mode: Mode) {
        stop()
        guard let item = player.currentItem else { return }
        weakPlayer = player
        trackedItem = item

        let output = AVPlayerItemVideoOutput(outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        item.add(output)
        videoOutput = output

        let renderer = AVSampleBufferVideoRenderer()
        videoRenderer = renderer

        let layer = AVSampleBufferDisplayLayer()
        displayLayer = layer

        let target = DisplayLinkTarget(output: output, renderer: renderer, layer: layer, mode: mode)
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        isActive = true
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        if let item = trackedItem, let output = videoOutput {
            item.remove(output)
        }
        videoOutput = nil
        trackedItem = nil
        weakPlayer = nil
        videoRenderer?.flush()
        videoRenderer = nil
        displayLayer?.sampleBufferRenderer.flush()
        displayLayer = nil
        isActive = false
    }

    nonisolated static func stereoMetadataExtensions(for mode: APMPInjector.Mode) -> [String: Any] {
        var extensions: [String: Any] = [
            "ProjectionKind": "Rectilinear",
            "HasLeftStereoEyeView": true,
            "HasRightStereoEyeView": true,
            "HeroStereoEye": "Left"
        ]

        switch mode {
        case .sideBySide:
            extensions["ViewPackingKind"] = "SideBySide"
        case .overUnder:
            extensions["ViewPackingKind"] = "OverUnder"
        }

        return extensions
    }
}

enum APMPFramePublishingPolicy {
    static func shouldEnqueueRendererBuffer(status: OSStatus, hasBuffer: Bool) -> Bool {
        status == noErr && hasBuffer
    }

    static func shouldEnqueueLayerBuffer(status: OSStatus, hasBuffer: Bool, isReadyForMoreMediaData: Bool) -> Bool {
        status == noErr && hasBuffer && isReadyForMoreMediaData
    }
}

enum APMPStereoFormatCachePolicy {
    static func shouldReuseFormatDescription(
        cachedWidth: Int,
        cachedHeight: Int,
        cachedMode: APMPInjector.Mode?,
        pixelWidth: Int,
        pixelHeight: Int,
        mode: APMPInjector.Mode
    ) -> Bool {
        cachedWidth == pixelWidth && cachedHeight == pixelHeight && cachedMode == mode
    }

    static func resetStateAfterFormatDescriptionFailure() -> (width: Int, height: Int, mode: APMPInjector.Mode?) {
        (width: 0, height: 0, mode: nil)
    }
}

enum APMPSampleTimingPolicy {
    static func timingInfo(for itemTime: CMTime) -> CMSampleTimingInfo {
        CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: itemTime,
            decodeTimeStamp: .invalid
        )
    }
}

enum APMPStereoFormatDescriptionFactory {
    static func make(
        pixelFormat: OSType,
        width: Int,
        height: Int,
        mode: APMPInjector.Mode
    ) -> (status: OSStatus, description: CMVideoFormatDescription?) {
        guard width > 0, height > 0 else {
            return (kCMFormatDescriptionError_InvalidParameter, nil)
        }

        let extensions = APMPInjector.stereoMetadataExtensions(for: mode)
        var description: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: nil,
            codecType: CMVideoCodecType(pixelFormat),
            width: Int32(width),
            height: Int32(height),
            extensions: extensions as CFDictionary,
            formatDescriptionOut: &description
        )
        return (status, description)
    }
}

// MARK: - CADisplayLink trampoline (avoids retain cycle)

/// `NSObject` subclass used as the `CADisplayLink` target.
/// Holds strong references to the output and renderers so they survive even if
/// `APMPInjector` is stopped and released during a tick. This object is pinned
/// to the main actor because `CADisplayLink` runs on the main run loop.
@MainActor
private final class DisplayLinkTarget: NSObject {
    let output: AVPlayerItemVideoOutput
    let renderer: AVSampleBufferVideoRenderer
    let layer: AVSampleBufferDisplayLayer
    let mode: APMPInjector.Mode

    /// Cached stereo format description. Built once on first frame to avoid
    /// re-creating it every tick.
    private var stereoFormatDesc: CMVideoFormatDescription?
    private var cachedWidth: Int = 0
    private var cachedHeight: Int = 0
    private var cachedMode: APMPInjector.Mode? = nil

    init(
        output: AVPlayerItemVideoOutput,
        renderer: AVSampleBufferVideoRenderer,
        layer: AVSampleBufferDisplayLayer,
        mode: APMPInjector.Mode
    ) {
        self.output = output
        self.renderer = renderer
        self.layer = layer
        self.mode = mode
    }

    @objc func tick(_ link: CADisplayLink) {
        // Use link.timestamp (current vsync) rather than targetTimestamp
        // (next vsync prediction) for accurate current-frame sampling.
        let itemTime = output.itemTime(forHostTime: link.timestamp)
        guard output.hasNewPixelBuffer(forItemTime: itemTime),
              let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
        else { return }
        injectFrame(pixelBuffer: pixelBuffer, itemTime: itemTime)
    }

#if DEBUG
    func _testInjectFrame(pixelBuffer: CVPixelBuffer, itemTime: CMTime) {
        injectFrame(pixelBuffer: pixelBuffer, itemTime: itemTime)
    }

    func _testStereoFormatDescription(for pixelBuffer: CVPixelBuffer) -> CMVideoFormatDescription? {
        stereoFormatDescription(for: pixelBuffer)
    }
#endif

    private func injectFrame(pixelBuffer: CVPixelBuffer, itemTime: CMTime) {
        let formatDesc = stereoFormatDescription(for: pixelBuffer)
        guard let formatDesc else { return }

        var timingInfo = APMPSampleTimingPolicy.timingInfo(for: itemTime)

        // Create separate sample buffers for each consumer so their
        // lifecycles don't interfere with each other (P1-IM-002).
        // OSStatus returns are now checked (P1-046).
        var rendererBuffer: CMSampleBuffer?
        let rendererStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil,
            imageBuffer: pixelBuffer,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &rendererBuffer
        )

        var layerBuffer: CMSampleBuffer?
        let layerStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil,
            imageBuffer: pixelBuffer,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &layerBuffer
        )

        if APMPFramePublishingPolicy.shouldEnqueueRendererBuffer(
            status: rendererStatus,
            hasBuffer: rendererBuffer != nil
        ), let rendererBuffer {
            renderer.enqueue(rendererBuffer)
        }

        let layerRenderer = layer.sampleBufferRenderer
        if APMPFramePublishingPolicy.shouldEnqueueLayerBuffer(
            status: layerStatus,
            hasBuffer: layerBuffer != nil,
            isReadyForMoreMediaData: layerRenderer.isReadyForMoreMediaData
        ), let layerBuffer {
            layerRenderer.enqueue(layerBuffer)
        }
    }

    /// Returns a `CMVideoFormatDescription` with stereo packing extensions
    /// matching the configured `mode`. Cached after the first call and
    /// invalidated if the pixel buffer dimensions change.
    private func stereoFormatDescription(for pixelBuffer: CVPixelBuffer) -> CMVideoFormatDescription? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        if let cached = stereoFormatDesc,
           APMPStereoFormatCachePolicy.shouldReuseFormatDescription(
               cachedWidth: cachedWidth,
               cachedHeight: cachedHeight,
               cachedMode: cachedMode,
               pixelWidth: width,
               pixelHeight: height,
               mode: mode
           ) {
            return cached
        }

        cachedWidth = width
        cachedHeight = height
        cachedMode = mode

        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let result = APMPStereoFormatDescriptionFactory.make(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mode: mode
        )
        let status = result.status
        let desc = result.description

        if status == noErr {
            stereoFormatDesc = desc
        } else {
            // Reset caches so the next frame retries from scratch.
            let reset = APMPStereoFormatCachePolicy.resetStateAfterFormatDescriptionFailure()
            stereoFormatDesc = nil
            cachedWidth = reset.width
            cachedHeight = reset.height
            cachedMode = reset.mode
            logger.warning(
                "Failed to create stereo format description: OSStatus \(status), \(width)x\(height)"
            )
        }
        return desc
    }
}

#if DEBUG
@MainActor
final class APMPDisplayLinkTargetTestHarness {
    private let target: DisplayLinkTarget

    var videoRenderer: AVSampleBufferVideoRenderer {
        target.renderer
    }

    init(mode: APMPInjector.Mode) {
        target = DisplayLinkTarget(
            output: AVPlayerItemVideoOutput(outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]),
            renderer: AVSampleBufferVideoRenderer(),
            layer: AVSampleBufferDisplayLayer(),
            mode: mode
        )
    }

    func stereoFormatDescription(for pixelBuffer: CVPixelBuffer) -> CMVideoFormatDescription? {
        target._testStereoFormatDescription(for: pixelBuffer)
    }

    func injectFrame(pixelBuffer: CVPixelBuffer, itemTime: CMTime) {
        target._testInjectFrame(pixelBuffer: pixelBuffer, itemTime: itemTime)
    }
}
#endif
#endif
