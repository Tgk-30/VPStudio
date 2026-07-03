import Foundation
@preconcurrency import KSPlayer
#if canImport(VideoToolbox)
import VideoToolbox
#endif

struct KSPlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind = .ksPlayer
    private let resolveStream: @Sendable (StreamInfo) async throws -> StreamInfo

    init(resolveStream: @escaping @Sendable (StreamInfo) async throws -> StreamInfo = PlaybackStreamURLResolver.resolve) {
        self.resolveStream = resolveStream
    }

    struct ReadinessObservation: Equatable, Sendable {
        let playbackState: PlayerPlaybackState
        let message: String
        let hasStartedPlayback: Bool
        let terminalFailureMessage: String?
    }

    struct TuningProfile: Equatable, Sendable {
        let preferredForwardBufferDuration: Double
        let maxBufferDuration: Double
        let probesize: Int64
        let maxAnalyzeDuration: Int64
        let autoSelectEmbedSubtitle: Bool
    }

    func canHandle(stream: StreamInfo) -> Bool {
        PlayerStreamURLPolicy.isLaunchable(stream)
    }

    @MainActor
    func prepare(stream: StreamInfo) async throws -> PreparedPlaybackSession {
        // Direct play only — no transcode/remux. KSPlayer decodes the original
        // debrid stream bytes in-place (FFmpeg-backed) for containers/codecs
        // AVPlayer can't open; it never rewrites or re-encodes the media. See
        // DirectPlayPolicy for the contract.
        guard PlayerStreamURLPolicy.isLaunchable(stream) else {
            throw PlayerEngineError.invalidStreamURL(stream.streamURL.absoluteString)
        }
        let stream = try await resolveStream(stream)
        guard PlayerStreamURLPolicy.isLaunchable(stream) else {
            throw PlayerEngineError.invalidStreamURL(stream.streamURL.absoluteString)
        }

        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.isAutoPlay = true
        KSOptions.isSecondOpen = false
        KSOptions.logLevel = .error
        #if targetEnvironment(simulator)
        // The simulator's audio HAL often cannot create the AVAudioSession
        // proxy ("Creating proxy session failed... Session lookup failed",
        // AURemoteIO "no reporter associated"). With the default
        // AudioEnginePlayer, AVAudioEngine.start() then throws (KSPlayer only
        // logs it) and the audio clock never starts; streams with an audio
        // track pin KSPlayer's main clock to that frozen audio clock and
        // startup stalls in .buffering forever. AVSampleBufferAudioRenderer's
        // synchronizer timebase advances without hardware audio, so simulator
        // and QA runs still get advancing (possibly silent) playback.
        KSOptions.audioPlayerType = AudioRendererPlayer.self
        #endif

        let options = KSOptions()

        // Always enable hardware decode and async decompression.
        // KSPlayer will fall back to software if the hardware decoder
        // can't handle the stream (e.g. interlaced content).
        options.hardwareDecode = true
        options.asynchronousDecompression = true

        // Note: KSPlayer's AVCodecID → CMVideoCodecType mapping does NOT
        // include AV1, so VideoToolbox hardware decode is not used for AV1
        // even when options.hardwareDecode is true. KSPlayer decodes AV1
        // via the dav1d software decoder. On visionOS, prefer AVPlayer for
        // AV1 streams to get M2 hardware decode (see PlayerEngineSelector).
        #if os(visionOS)
        if stream.codec == .av1,
           VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1) {
            KSLog("[VPStudio] AV1 hardware decode supported — prefer AVPlayer for this stream")
        }
        #endif

        // Per-stream buffer/probe tuning with a lower-RAM baseline.
        let profile = Self.tuningProfile(for: stream)
        options.preferredForwardBufferDuration = profile.preferredForwardBufferDuration
        options.maxBufferDuration = profile.maxBufferDuration
        options.probesize = profile.probesize
        options.maxAnalyzeDuration = profile.maxAnalyzeDuration
        options.autoSelectEmbedSubtitle = profile.autoSelectEmbedSubtitle

        // Hard read-timeout: if FFmpeg can't get data within 30 s it raises an
        // error rather than hanging the readiness poll indefinitely.
        options.formatContextOptions["rw_timeout"] = 30_000_000 // 30 s in µs
        Self.applyRequestHeaders(from: stream, to: options)

        return PreparedPlaybackSession(
            engineKind: kind,
            streamURL: stream.streamURL,
            avPlayer: nil,
            ksPlayerCoordinator: KSVideoPlayer.Coordinator(),
            ksOptions: options
        )
    }

    // MARK: - Readiness Timeout

    /// Returns a stream-aware readiness timeout for `waitUntilReady`.
    ///
    /// Demanding streams need more time for codec probing, hardware-decoder
    /// negotiation, and initial network buffering:
    /// - 4K / HDR / lossless audio / AV1 → 24 s
    /// - Container formats that require FFmpeg demuxing (MKV, TS, AVI…) → 18 s
    /// - Standard HTTP streams → 12 s (unchanged default)
    static func timeout(for stream: StreamInfo) -> TimeInterval {
        if isHighDemandStream(stream) { return 24 }
        let ext = stream.streamURL.pathExtension.lowercased()
        if ["mkv", "ts", "m2ts", "avi", "wmv", "flv", "webm"].contains(ext) { return 18 }
        return 12
    }

    static func ffmpegHeaderString(for headers: [String: String]) -> String? {
        guard let normalized = StreamInfo.normalizedRequestHeaders(headers) else {
            return nil
        }

        let lines = normalized
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)" }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private static func applyRequestHeaders(from stream: StreamInfo, to options: KSOptions) {
        guard let headers = StreamInfo.normalizedRequestHeaders(stream.requestHeaders),
              let headerString = ffmpegHeaderString(for: headers) else {
            return
        }

        options.formatContextOptions["headers"] = headerString
        if let userAgent = headers.first(where: { $0.key.localizedCaseInsensitiveCompare("User-Agent") == .orderedSame })?.value {
            options.formatContextOptions["user_agent"] = userAgent
        }
    }

    // MARK: - Readiness Poll

    @MainActor
    static func waitUntilReady(
        coordinator: KSVideoPlayer.Coordinator,
        timeout: TimeInterval = 12,
        pollInterval: Duration = .milliseconds(150),
        onState: ((PlayerPlaybackState, String?) -> Void)? = nil,
        failureMessage: @escaping () -> String?
    ) async throws {
        guard timeout > 0 else {
            throw PlayerEngineError.initializationFailed(.ksPlayer, "Invalid readiness timeout.")
        }

        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let state = coordinator.state
            switch state {
            case .error:
                // The onFinish callback may not have fired yet when the state
                // transitions to .error, so failureMessage() can be nil.
                // Give the callback a brief window to populate the error.
                if failureMessage() == nil {
                    try await Task.sleep(for: .milliseconds(100))
                }
                let detail = failureMessage()
                let message: String
                if let detail, !detail.isEmpty {
                    message = "KSPlayer decode error: \(IndexerLogSanitizer.redactedMessage(detail))"
                } else {
                    message = "KSPlayer failed to initialize (no error detail from decoder)"
                }
                throw PlayerEngineError.initializationFailed(.ksPlayer, message)

            default:
                let observation = readinessObservation(for: state)
                if let terminalFailureMessage = observation.terminalFailureMessage {
                    throw PlayerEngineError.initializationFailed(.ksPlayer, terminalFailureMessage)
                }
                onState?(observation.playbackState, observation.message)
                if observation.hasStartedPlayback {
                    return
                }
            }

            try await Task.sleep(for: pollInterval)
        }

        throw PlayerEngineError.startupTimeout(.ksPlayer)
    }

    // MARK: - Private Helpers

    static func readinessObservation(for state: KSPlayerState) -> ReadinessObservation {
        switch state {
        case .initialized, .preparing:
            return ReadinessObservation(
                playbackState: .preparing,
                message: "Initializing KSPlayer.",
                hasStartedPlayback: false,
                terminalFailureMessage: nil
            )

        case .readyToPlay:
            return ReadinessObservation(
                playbackState: .buffering,
                message: "KSPlayer is ready; starting playback.",
                hasStartedPlayback: false,
                terminalFailureMessage: nil
            )

        case .buffering:
            // KSPlayerLayer enters .buffering the moment play() is requested —
            // before any frame renders or the playback clock starts — so it
            // must NOT satisfy startup readiness. A stream stuck here past the
            // startup budget falls through to PlayerEngineError.startupTimeout
            // so the UI can offer the next stream instead of waiting forever.
            return ReadinessObservation(
                playbackState: .buffering,
                message: "KSPlayer is buffering the stream start.",
                hasStartedPlayback: false,
                terminalFailureMessage: nil
            )

        case .bufferFinished:
            return ReadinessObservation(
                playbackState: .playing,
                message: "KSPlayer is rendering.",
                hasStartedPlayback: true,
                terminalFailureMessage: nil
            )

        case .paused:
            return ReadinessObservation(
                playbackState: .buffering,
                message: "KSPlayer is ready; waiting for playback.",
                hasStartedPlayback: false,
                terminalFailureMessage: nil
            )

        case .playedToTheEnd:
            return ReadinessObservation(
                playbackState: .failed,
                message: "KSPlayer reached the end before playback started.",
                hasStartedPlayback: false,
                terminalFailureMessage: "KSPlayer reached the end before playback started."
            )

        case .error:
            return ReadinessObservation(
                playbackState: .failed,
                message: "KSPlayer failed to initialize.",
                hasStartedPlayback: false,
                terminalFailureMessage: "KSPlayer failed to initialize."
            )
        }
    }

    /// Returns `true` for streams where codec initialisation and buffering are
    /// meaningfully slower than standard 1080p H.264 content.
    private static func isHighDemandStream(_ stream: StreamInfo) -> Bool {
        if stream.quality == .uhd4k { return true }
        if stream.codec == .av1 { return true }
        if stream.hdr == .dolbyVision || stream.hdr == .hdr10Plus { return true }
        if stream.audio == .atmos || stream.audio == .trueHD || stream.audio == .dtsHDMA { return true }
        let lower = stream.fileName.lowercased()
        return lower.contains("remux") || lower.contains("bdremux")
    }

    nonisolated static func tuningProfile(for stream: StreamInfo) -> TuningProfile {
        if isHighDemandStream(stream) {
            #if os(visionOS)
            // Vision Pro has 16 GB shared memory; M2 hardware decode is fast
            // enough that less buffering is fine. Reduce to save ~40% buffer RAM.
            return TuningProfile(
                preferredForwardBufferDuration: 2.0,
                maxBufferDuration: 10.0,
                probesize: 6_000_000,
                maxAnalyzeDuration: 6_000_000,
                autoSelectEmbedSubtitle: false
            )
            #else
            return TuningProfile(
                preferredForwardBufferDuration: 3.0,
                maxBufferDuration: 16.0,
                probesize: 6_000_000,
                maxAnalyzeDuration: 6_000_000,
                autoSelectEmbedSubtitle: false
            )
            #endif
        }

        #if os(visionOS)
        return TuningProfile(
            preferredForwardBufferDuration: 1.0,
            maxBufferDuration: 5.0,
            probesize: 2_000_000,
            maxAnalyzeDuration: 2_500_000,
            autoSelectEmbedSubtitle: true
        )
        #else
        return TuningProfile(
            preferredForwardBufferDuration: 1.5,
            maxBufferDuration: 8.0,
            probesize: 2_000_000,
            maxAnalyzeDuration: 2_500_000,
            autoSelectEmbedSubtitle: true
        )
        #endif
    }
}
