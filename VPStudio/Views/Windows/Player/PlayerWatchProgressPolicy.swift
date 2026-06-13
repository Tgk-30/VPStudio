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
        lastFrameImagePath: String? = nil,
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
            lastFrameImagePath: lastFrameImagePath,
            recoveryContextJSON: encodedRecoveryContext(stream.recoveryContext),
            watchedAt: watchedAt,
            isCompleted: normalizedCurrentTime / duration >= completionThreshold
        )
    }

    /// JSON-encodes the stream's recovery context so a Continue Watching tap can re-resolve
    /// the source via debrid without re-searching the indexer. Nil when unavailable.
    static func encodedRecoveryContext(_ context: StreamRecoveryContext?) -> String? {
        guard let context else { return nil }
        guard let data = try? JSONEncoder().encode(context) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
