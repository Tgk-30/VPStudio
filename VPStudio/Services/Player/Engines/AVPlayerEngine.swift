import Foundation
import AVFoundation
import CoreGraphics

struct AVPlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind = .avPlayer
    private let resolveStream: @Sendable (StreamInfo) async throws -> StreamInfo

    init(resolveStream: @escaping @Sendable (StreamInfo) async throws -> StreamInfo = PlaybackStreamURLResolver.resolve) {
        self.resolveStream = resolveStream
    }

    func canHandle(stream: StreamInfo) -> Bool {
        PlayerStreamURLPolicy.isLaunchable(stream)
    }

    @MainActor
    func prepare(stream: StreamInfo) async throws -> PreparedPlaybackSession {
        // Direct play only — no transcode/remux. We hand the debrid stream URL
        // straight to AVPlayer; container/codec compatibility is handled by
        // engine selection (PlayerEngineSelector / DirectPlayPolicy), never by
        // rewriting the media.
        guard PlayerStreamURLPolicy.isLaunchable(stream) else {
            throw PlayerEngineError.invalidStreamURL(stream.streamURL.absoluteString)
        }
        let stream = try await resolveStream(stream)
        guard PlayerStreamURLPolicy.isLaunchable(stream) else {
            throw PlayerEngineError.invalidStreamURL(stream.streamURL.absoluteString)
        }

        let item: AVPlayerItem
        if let options = Self.assetOptions(for: stream) {
            let asset = AVURLAsset(url: stream.streamURL, options: options)
            item = AVPlayerItem(asset: asset)
        } else {
            item = AVPlayerItem(url: stream.streamURL)
        }
        item.preferredForwardBufferDuration = preferredForwardBufferDuration(for: stream)
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        let player = AVPlayer(playerItem: item)
        // Ordinary streams start fastest with stall-minimization off. High-demand
        // streams (4K/HDR/AV1/lossless/remux) stall far less — the main cause of
        // "stuck rebuffering" on big streams — when AVPlayer is allowed to build a
        // buffer before starting, so opt those into stall-minimization waiting.
        player.automaticallyWaitsToMinimizeStalling = Self.isHighDemandStream(stream)

        return PreparedPlaybackSession(
            engineKind: kind,
            streamURL: stream.streamURL,
            avPlayer: player,
            ksPlayerCoordinator: nil,
            ksOptions: nil
        )
    }

    private func preferredForwardBufferDuration(for stream: StreamInfo) -> TimeInterval {
        // A deeper forward buffer keeps demanding streams from stalling; ordinary
        // streams keep a small buffer for fast startup and low memory use.
        Self.isHighDemandStream(stream) ? 3.0 : 1.5
    }

    /// Streams whose codec/bitrate make them meaningfully more stall-prone than
    /// standard 1080p H.264, warranting a deeper buffer and stall-minimization.
    static func isHighDemandStream(_ stream: StreamInfo) -> Bool {
        if stream.quality == .uhd4k { return true }
        if stream.codec == .av1 { return true }
        if stream.hdr == .dolbyVision || stream.hdr == .hdr10Plus { return true }
        if stream.audio == .atmos || stream.audio == .trueHD || stream.audio == .dtsHDMA { return true }
        return stream.fileName.lowercased().contains("remux")
    }

    static func assetOptions(for stream: StreamInfo) -> [String: Any]? {
        guard let headers = StreamInfo.normalizedRequestHeaders(stream.requestHeaders) else {
            return nil
        }

        return ["AVURLAssetHTTPHeaderFieldsKey": headers]
    }

    /// Pure decision for whether AVPlayer playback has actually started *rendering
    /// video* — as opposed to an audio-only / black-screen start that AVPlayer
    /// happily reports as `rate > 0`.
    ///
    /// A start only "succeeded" when the player is playing AND there is at least
    /// one video track AND the item has a non-zero presentation size (the decoder
    /// has produced a frame the layer can present). When playback is rolling but
    /// no video is present, the caller should treat it as a failure and fail over
    /// to the next engine (KSPlayer) rather than leaving the user on a black
    /// screen with only sound.
    ///
    /// - Parameters:
    ///   - hasVideoTracks: Whether the current item exposes any video tracks.
    ///   - presentationSize: The item's `presentationSize` (the size of the
    ///     presented video frame; `.zero` until a frame is available / when none).
    ///   - isPlaying: Whether the player is actively playing (rate > 0 or
    ///     `timeControlStatus == .playing`).
    static func videoStartSucceeded(
        hasVideoTracks: Bool,
        presentationSize: CGSize,
        isPlaying: Bool
    ) -> Bool {
        guard isPlaying else { return false }
        guard hasVideoTracks else { return false }
        return presentationSize.width > 0 && presentationSize.height > 0
    }

    @MainActor
    static func itemHasVideoTracks(_ item: AVPlayerItem) -> Bool {
        item.tracks.contains { track in
            track.assetTrack?.mediaType == .video
        }
    }

    @MainActor
    static func waitUntilReady(
        player: AVPlayer,
        timeout: TimeInterval = 12,
        pollInterval: Duration = .milliseconds(150),
        onState: ((PlayerPlaybackState, String?) -> Void)? = nil
    ) async throws {
        guard timeout > 0 else {
            throw PlayerEngineError.initializationFailed(.avPlayer, "Invalid readiness timeout.")
        }

        guard let item = player.currentItem else {
            throw PlayerEngineError.initializationFailed(.avPlayer, "Missing AVPlayerItem.")
        }

        let deadline = Date().addingTimeInterval(timeout)
        // Tracks whether we ever observed AVPlayer rolling (rate > 0) without video.
        // If the deadline is reached in that state we throw an audio-only error so
        // the failover loop advances to KSPlayer, instead of a generic timeout.
        var sawAudioOnlyPlayback = false

        while Date() < deadline {
            if item.error != nil {
                throw PlayerEngineError.initializationFailed(.avPlayer, failureDescription(for: item))
            }

            switch item.status {
            case .failed:
                throw PlayerEngineError.initializationFailed(.avPlayer, failureDescription(for: item))

            case .readyToPlay:
                let isPlaying = player.rate > 0 || player.timeControlStatus == .playing
                let hasVideoTracks = itemHasVideoTracks(item)

                if videoStartSucceeded(
                    hasVideoTracks: hasVideoTracks,
                    presentationSize: item.presentationSize,
                    isPlaying: isPlaying
                ) {
                    onState?(.playing, "AVPlayer is rendering.")
                    return
                }

                if isPlaying {
                    // Playing but no video frame yet. If the item has no video
                    // tracks at all, this is a true audio-only/black-screen start:
                    // remember it so we can fail over once the deadline lapses
                    // (we keep polling briefly in case tracks/size arrive late).
                    if !hasVideoTracks {
                        sawAudioOnlyPlayback = true
                        onState?(.buffering, "Waiting for video — may fall back to compatibility engine.")
                    } else {
                        onState?(.buffering, "AVPlayer is rendering audio; waiting for first video frame.")
                    }
                } else if player.timeControlStatus == .waitingToPlayAtSpecifiedRate || item.isPlaybackBufferEmpty {
                    onState?(.buffering, "AVPlayer is buffering.")
                } else {
                    onState?(.buffering, "AVPlayer is ready; waiting for first frame.")
                }

            case .unknown:
                onState?(.preparing, "Loading stream metadata.")

            @unknown default:
                onState?(.buffering, "Waiting for AVPlayer readiness.")
            }

            try await Task.sleep(for: pollInterval)
        }

        // Deadline reached. Distinguish an audio-only/black-screen start (AVPlayer
        // is playing sound but never produced video) from a plain startup timeout
        // so the caller fails over to KSPlayer in both cases.
        if sawAudioOnlyPlayback {
            throw PlayerEngineError.initializationFailed(
                .avPlayer,
                "Stream started as audio-only (no video track); falling back to compatibility engine."
            )
        }

        throw PlayerEngineError.startupTimeout(.avPlayer)
    }

    private static func failureDescription(for item: AVPlayerItem) -> String {
        let statusCode = item.errorLog()?.events.last?.errorStatusCode ?? 0
        let comment = item.errorLog()?.events.last?.errorComment
        return failureDescription(statusCode: statusCode, comment: comment, itemError: item.error)
    }

    static func failureDescription(statusCode: Int, comment: String?, itemError: Error?) -> String {
        let trimmedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)

        if statusCode > 0, let trimmedComment, !trimmedComment.isEmpty {
            return "HTTP \(statusCode): \(IndexerLogSanitizer.redactedMessage(trimmedComment))"
        }

        if statusCode > 0 {
            return "HTTP \(statusCode) while loading stream."
        }

        if let trimmedComment, !trimmedComment.isEmpty {
            return IndexerLogSanitizer.redactedMessage(trimmedComment)
        }

        if let itemError = itemError {
            return IndexerLogSanitizer.redactedErrorMessage(itemError)
        }

        return "Unknown AVPlayer item error"
    }
}
