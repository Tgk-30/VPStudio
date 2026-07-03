import Foundation

#if !os(macOS)
import AVFoundation
import os
#endif

enum AudioSessionPlaybackPolicy: Sendable {
    case standard
    case longFormVideo
    case immersive
}

enum AudioSessionConfigurator {
    #if !os(macOS)
    private static let logger = Logger(subsystem: "com.vpstudio", category: "audio-session")

    static func configurePlaybackAsync(policy: AudioSessionPlaybackPolicy) {
        Task.detached(priority: .userInitiated) {
            configurePlayback(policy: policy)
        }
    }

    private static func configurePlayback(policy: AudioSessionPlaybackPolicy) {
        let session = AVAudioSession.sharedInstance()

        do {
            switch policy {
            case .standard:
                try session.setCategory(.playback, mode: .moviePlayback)
            case .longFormVideo, .immersive:
                try session.setCategory(
                    .playback,
                    mode: .moviePlayback,
                    policy: .longFormVideo,
                    options: []
                )
            }

            if #available(iOS 15.0, tvOS 15.0, visionOS 1.0, *) {
                try session.setSupportsMultichannelContent(true)
            }

            if policy == .immersive {
                let maxChannels = session.maximumOutputNumberOfChannels
                if maxChannels > 2 {
                    try session.setPreferredOutputNumberOfChannels(maxChannels)
                }
            }

            try session.setActive(true)
        } catch {
            let reason = IndexerLogSanitizer.redactedErrorMessage(error)
            logger.error("Failed to configure AVAudioSession: \(reason, privacy: .public)")
        }
    }
    #else
    static func configurePlaybackAsync(policy: AudioSessionPlaybackPolicy) {}
    #endif
}
