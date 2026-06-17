import Foundation
import Testing
@testable import VPStudio

// MARK: - WatchProgressResumePolicy.shouldReseek Tests
//
// Covers the post-wake / post-doff re-anchor decision: after returning to the
// active scene phase the engine may have been reset to 0, in which case we must
// re-seek to the persisted resume point. Within-tolerance drift is left alone so
// we never fight normal playback.

@Suite("WatchProgressResumePolicy — Reanchor / shouldReseek")
struct WatchProgressReanchorTests {

    // MARK: - Nil persisted resume

    @Test func nilPersistedResumeNeverReseeks() {
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: nil,
                engineCurrentTime: 0
            ) == false
        )
        // Even with a large engine time, a nil target means there's nothing to anchor to.
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: nil,
                engineCurrentTime: 5000
            ) == false
        )
    }

    // MARK: - Within tolerance -> false

    @Test func engineMatchingPersistedDoesNotReseek() {
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: 1200,
                engineCurrentTime: 1200
            ) == false
        )
    }

    @Test func smallDriftWithinToleranceDoesNotReseek() {
        // 1.5s of drift is below the default 2s tolerance.
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: 1200,
                engineCurrentTime: 1201.5
            ) == false
        )
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: 1200,
                engineCurrentTime: 1198.5
            ) == false
        )
    }

    // MARK: - Boundary: drift == tolerance -> false

    @Test func driftExactlyAtToleranceDoesNotReseek() {
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: 1200,
                engineCurrentTime: 1202 // exactly +2s
            ) == false
        )
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: 1200,
                engineCurrentTime: 1198 // exactly -2s
            ) == false
        )
    }

    @Test func customToleranceBoundaryDoesNotReseek() {
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: 100,
                engineCurrentTime: 105,
                tolerance: 5
            ) == false
        )
    }

    // MARK: - Engine reset after wake -> true

    @Test func engineResetToZeroAfterWakeReseeks() {
        // The classic doff/don failure: engine restarts at 0 while the persisted
        // resume point is well into the title.
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: 1200,
                engineCurrentTime: 0
            ) == true
        )
    }

    @Test func driftJustBeyondToleranceReseeks() {
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: 1200,
                engineCurrentTime: 1202.01
            ) == true
        )
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: 1200,
                engineCurrentTime: 1197.99
            ) == true
        )
    }

    @Test func customToleranceJustBeyondReseeks() {
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: 100,
                engineCurrentTime: 105.5,
                tolerance: 5
            ) == true
        )
    }

    // MARK: - Integration with resumeTime via Fixtures

    @Test func resumeTargetFromHistoryReseeksWhenEngineReset() {
        let history = Fixtures.watchHistory(progress: 1440, duration: 1800) // 80%, resume = 1440
        let target = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(target == 1440)
        // After wake the engine is back at 0, so we must re-anchor.
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: target,
                engineCurrentTime: 0
            ) == true
        )
        // But if the engine held the position, leave it alone.
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: target,
                engineCurrentTime: 1440
            ) == false
        )
    }

    @Test func completedHistoryHasNoResumeSoNeverReseeks() {
        let history = Fixtures.watchHistory(progress: 1750, duration: 1800) // ~97% -> watched
        let target = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(target == nil)
        #expect(
            WatchProgressResumePolicy.shouldReseek(
                persistedResume: target,
                engineCurrentTime: 0
            ) == false
        )
    }
}
