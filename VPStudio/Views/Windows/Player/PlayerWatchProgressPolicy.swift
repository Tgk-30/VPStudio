import Foundation

enum PlayerWatchProgressPolicy {
    static let completionThreshold = 0.9

    static func makeSnapshot(
        mediaId: String?,
        episodeId: String?,
        mediaTitle: String?,
        stream: StreamInfo,
        currentTime: TimeInterval,
        duration: TimeInterval,
        watchedAt: Date = Date()
    ) -> WatchHistory? {
        guard let mediaId else { return nil }
        guard duration.isFinite, duration > 0 else { return nil }
        let safeCurrentTime = currentTime.isFinite ? currentTime : 0
        let normalizedCurrentTime = min(max(0, safeCurrentTime), duration)

        return WatchHistory(
            id: episodeId.map { "\(mediaId)-\($0)-progress" } ?? "\(mediaId)-progress",
            mediaId: mediaId,
            episodeId: episodeId,
            title: mediaTitle ?? stream.fileName,
            progress: normalizedCurrentTime,
            duration: duration,
            quality: stream.quality.rawValue,
            debridService: stream.debridService,
            streamURL: stream.streamURL.absoluteString,
            watchedAt: watchedAt,
            isCompleted: normalizedCurrentTime / duration >= completionThreshold
        )
    }
}
