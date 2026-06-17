import Foundation

enum WatchProgressResumePolicy {
    static func resumeTime(for history: WatchHistory?) -> TimeInterval? {
        guard let history else { return nil }
        guard history.hasFiniteNumericValues else { return nil }

        guard history.progress.isFinite, history.duration.isFinite else { return nil }

        let progress = max(0, history.progress)
        let duration = max(0, history.duration)
        guard progress >= 15 else { return nil }

        if duration > 0 {
            let completion = progress / duration
            // Past the completion threshold the title counts as watched, so don't offer a
            // resume point — start it over instead. Kept in sync with auto-watched + the
            // Continue Watching filter via the single PlayerWatchProgressPolicy constant.
            if completion >= PlayerWatchProgressPolicy.completionThreshold {
                return nil
            }
            return min(progress, max(duration - 5, 0))
        }

        return progress
    }

    /// Whether the engine should be re-seeked to a freshly-loaded resume target
    /// after returning from a suspended/inactive scene phase.
    ///
    /// Returns `false` when there is no persisted resume point. Otherwise it only
    /// returns `true` when the engine has drifted away from the persisted point by
    /// more than `tolerance` seconds — which is the signal that the underlying
    /// player was reset (e.g. back to 0 after a doff/don or wake) and needs to be
    /// re-anchored. Drift exactly equal to `tolerance` is treated as in-tolerance.
    static func shouldReseek(
        persistedResume: TimeInterval?,
        engineCurrentTime: TimeInterval,
        tolerance: TimeInterval = 2
    ) -> Bool {
        guard let persistedResume else { return false }
        return abs(engineCurrentTime - persistedResume) > tolerance
    }
}
