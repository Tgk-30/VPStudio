import Foundation
import AVFoundation

struct AVPlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind = .avPlayer

    func canHandle(stream: StreamInfo) -> Bool {
        URL(string: stream.streamURL.absoluteString) != nil
    }

    @MainActor
    func prepare(stream: StreamInfo) async throws -> PreparedPlaybackSession {
        guard URL(string: stream.streamURL.absoluteString) != nil else {
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
        // Prefer faster first-frame start and lower memory pressure; fallback
        // logic handles streams that still need compatibility decoding.
        player.automaticallyWaitsToMinimizeStalling = false

        return PreparedPlaybackSession(
            engineKind: kind,
            streamURL: stream.streamURL,
            avPlayer: player,
            ksPlayerCoordinator: nil,
            ksOptions: nil
        )
    }

    private func preferredForwardBufferDuration(for stream: StreamInfo) -> TimeInterval {
        if stream.quality == .uhd4k || stream.hdr == .dolbyVision || stream.hdr == .hdr10Plus {
            return 3.0
        }
        return 1.5
    }

    static func assetOptions(for stream: StreamInfo) -> [String: Any]? {
        guard let headers = StreamInfo.normalizedRequestHeaders(stream.requestHeaders) else {
            return nil
        }

        return ["AVURLAssetHTTPHeaderFieldsKey": headers]
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

        while Date() < deadline {
            if item.error != nil {
                throw PlayerEngineError.initializationFailed(.avPlayer, failureDescription(for: item))
            }

            switch item.status {
            case .failed:
                throw PlayerEngineError.initializationFailed(.avPlayer, failureDescription(for: item))

            case .readyToPlay:
                if player.rate > 0 || player.timeControlStatus == .playing {
                    onState?(.playing, "AVPlayer is rendering.")
                    return
                }

                if player.timeControlStatus == .waitingToPlayAtSpecifiedRate || item.isPlaybackBufferEmpty {
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
            return "HTTP \(statusCode): \(trimmedComment)"
        }

        if statusCode > 0 {
            return "HTTP \(statusCode) while loading stream."
        }

        if let trimmedComment, !trimmedComment.isEmpty {
            return trimmedComment
        }

        if let itemError = itemError {
            return itemError.localizedDescription
        }

        return "Unknown AVPlayer item error"
    }
}
