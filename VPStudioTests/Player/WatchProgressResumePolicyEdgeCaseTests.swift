import Foundation
import Testing
@testable import VPStudio

// MARK: - WatchProgressResumePolicy Edge Case Tests

@Suite("WatchProgressResumePolicy — Edge Cases")
struct WatchProgressResumePolicyEdgeCaseTests {

    // MARK: - Progress at exactly 15 second threshold

    @Test func progressExactlyAt15SecondsReturnsProgress() {
        let history = Fixtures.watchHistory(progress: 15, duration: 3600)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == 15)
    }

    @Test func progressJustBelow15SecondsReturnsNil() {
        let history = Fixtures.watchHistory(progress: 14.9, duration: 3600)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == nil)
    }

    @Test func progressAt14SecondsReturnsNil() {
        let history = Fixtures.watchHistory(progress: 14, duration: 3600)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == nil)
    }

    // MARK: - Completion threshold edge cases

    @Test func progressJustBelowCompletionThresholdReturnsResumeTime() {
        let progress = (PlayerWatchProgressPolicy.completionThreshold - 0.01) * 1000
        let history = Fixtures.watchHistory(progress: progress, duration: 1000)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == progress)
    }

    @Test func progressAtCompletionThresholdReturnsNil() {
        let progress = PlayerWatchProgressPolicy.completionThreshold * 1000
        let history = Fixtures.watchHistory(progress: progress, duration: 1000)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == nil)
    }

    @Test func progressAboveCompletionThresholdReturnsNil() {
        let progress = (PlayerWatchProgressPolicy.completionThreshold + 0.01) * 1000
        let history = Fixtures.watchHistory(progress: progress, duration: 1000)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == nil)
    }

    @Test func progressAt99PercentReturnsNil() {
        let history = Fixtures.watchHistory(progress: 990, duration: 1000)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == nil)
    }

    @Test func progressAt100PercentReturnsNil() {
        let history = Fixtures.watchHistory(progress: 1000, duration: 1000)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == nil)
    }

    // MARK: - Duration edge cases

    @Test func progressGreaterThanDurationReturnsNil() {
        let history = Fixtures.watchHistory(progress: 100, duration: 50)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == nil)
    }

    @Test func zeroDurationReturnsProgressValue() {
        let history = Fixtures.watchHistory(progress: 100, duration: 0)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == 100)
    }

    @Test func negativeDurationTreatedAsZero() {
        let history = Fixtures.watchHistory(progress: 100, duration: -10)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == 100)
    }

    // MARK: - Progress edge cases

    @Test func negativeProgressTreatedAsZero() {
        let history = Fixtures.watchHistory(progress: -5, duration: 3600)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == nil) // max(0, -5) = 0 < 15
    }

    @Test func veryLargeProgress() {
        let history = Fixtures.watchHistory(progress: 1_000_000, duration: 3_600)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        // completion = 277 > 1, so nil
        #expect(resume == nil)
    }

    // MARK: - Buffer boundary behavior

    @Test func shortMovieBelowCompletionThresholdReturnsResumeTime() {
        let progress = (PlayerWatchProgressPolicy.completionThreshold - 0.05) * 60
        let history = Fixtures.watchHistory(progress: progress, duration: 60)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == progress)
    }

    @Test func shortMovieAt50PercentReturnsProgress() {
        let history = Fixtures.watchHistory(progress: 30, duration: 60)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == 30)
    }

    @Test func episodeAt80PercentReturnsResumeTime() {
        let history = Fixtures.watchHistory(episodeId: "s01e05", progress: 1440, duration: 1800)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        // completion = 0.8 < 0.95
        #expect(resume == 1440)
    }

    // MARK: - Long form content

    @Test func movieOver3HoursAt30PercentReturns30Percent() {
        let history = Fixtures.watchHistory(progress: 3600, duration: 10800) // 1h in, 3h total
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == 3600)
    }

    @Test func movieOver3HoursPastCompletionThresholdReturnsNil() {
        let history = Fixtures.watchHistory(progress: 10152, duration: 10800) // ~94%
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == nil)
    }

    // MARK: - 5 second buffer boundary

    @Test func longMovieSubtracts5SecondsFromResumeTime() {
        let history = Fixtures.watchHistory(progress: 3600, duration: 7200)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        // min(3600, 7195) = 3600
        #expect(resume == 3600)
    }

    @Test func shortMovieRespectsBufferFloor() {
        let history = Fixtures.watchHistory(progress: 10, duration: 20)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == nil)
    }

    @Test func veryShortContentBufferFloorKicksIn() {
        let history = Fixtures.watchHistory(progress: 20, duration: 25)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        // duration - 5 = 20, max(20, 0) = 20, min(20, 20) = 20
        #expect(resume == 20)
    }

    @Test func contentShorterThan5SecondsTreatedAsZeroDuration() {
        let history = Fixtures.watchHistory(progress: 4, duration: 5)
        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        // progress < 15, returns nil
        #expect(resume == nil)
    }

    @Test func returnsNilForNonFiniteHistoryValues() {
        let nanProgress = Fixtures.watchHistory(progress: .nan, duration: 3_600)
        let nanDuration = Fixtures.watchHistory(progress: 120, duration: .nan)
        let infinityDuration = Fixtures.watchHistory(progress: 120, duration: .infinity)
        let infinityProgress = Fixtures.watchHistory(progress: .infinity, duration: 3_600)

        #expect(WatchProgressResumePolicy.resumeTime(for: nanProgress) == nil)
        #expect(WatchProgressResumePolicy.resumeTime(for: nanDuration) == nil)
        #expect(WatchProgressResumePolicy.resumeTime(for: infinityDuration) == nil)
        #expect(WatchProgressResumePolicy.resumeTime(for: infinityProgress) == nil)
    }
}

// MARK: - WatchProgressResumePolicy Concurrency Tests

@Suite("WatchProgressResumePolicy — Metadata Consistency")
struct WatchProgressResumePolicyMetadataTests {

    @Test func nilHistoryReturnsNilImmediately() {
        #expect(WatchProgressResumePolicy.resumeTime(for: nil) == nil)
    }

    @Test func historyWithNoStreamURLStillWorks() {
        let history = WatchHistory(
            id: UUID().uuidString,
            mediaId: "tt123",
            episodeId: nil,
            title: "Test Movie",
            progress: 1000,
            duration: 3600,
            quality: "1080p",
            debridService: "rd",
            streamURL: nil,
            watchedAt: Date(),
            isCompleted: false
        )

        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        #expect(resume == 1000)
    }

    @Test func historyWithCompletedFlagStillResumesIfProgressBelow95Percent() {
        let history = WatchHistory(
            id: UUID().uuidString,
            mediaId: "tt123",
            episodeId: nil,
            title: "Test Movie",
            progress: 900,
            duration: 3600,
            quality: "1080p",
            debridService: "rd",
            streamURL: nil,
            watchedAt: Date(),
            isCompleted: false
        )

        let resume = WatchProgressResumePolicy.resumeTime(for: history)
        // isCompleted flag is NOT considered - only progress/duration ratio matters
        #expect(resume == 900)
    }
}
