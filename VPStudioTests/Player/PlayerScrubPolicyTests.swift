import Testing
@testable import VPStudio

@Suite("PlayerScrubPolicy Chapter Snap Constants")
struct PlayerScrubPolicyChapterSnapConstantsTests {
    @Test("Chapter snap threshold fraction")
    func chapterSnapThresholdFraction() {
        #expect(PlayerScrubPolicy.chapterSnapThresholdFraction == 0.008)
    }

    @Test("Chapter snap minimum seconds")
    func chapterSnapMinimumSeconds() {
        #expect(PlayerScrubPolicy.chapterSnapMinimumSeconds == 2.0)
    }

    @Test("Chapter snap maximum seconds")
    func chapterSnapMaximumSeconds() {
        #expect(PlayerScrubPolicy.chapterSnapMaximumSeconds == 12.0)
    }

    @Test("Minimum is less than maximum")
    func minLessThanMax() {
        #expect(PlayerScrubPolicy.chapterSnapMinimumSeconds < PlayerScrubPolicy.chapterSnapMaximumSeconds)
    }
}

@Suite("PlayerScrubPolicy Chapter Snap Distance")
struct PlayerScrubPolicyChapterSnapDistanceTests {
    @Test("Zero duration returns minimum")
    func zeroDuration() {
        #expect(PlayerScrubPolicy.chapterSnapDistance(duration: 0) == PlayerScrubPolicy.chapterSnapMinimumSeconds)
    }

    @Test("Negative duration returns minimum")
    func negativeDuration() {
        #expect(PlayerScrubPolicy.chapterSnapDistance(duration: -100) == PlayerScrubPolicy.chapterSnapMinimumSeconds)
    }

    @Test("NaN duration clamps to minimum")
    func nonFiniteDuration() {
        #expect(PlayerScrubPolicy.chapterSnapDistance(duration: .nan) == PlayerScrubPolicy.chapterSnapMinimumSeconds)
    }

    @Test("Short duration returns minimum")
    func shortDuration() {
        #expect(PlayerScrubPolicy.chapterSnapDistance(duration: 10) == PlayerScrubPolicy.chapterSnapMinimumSeconds)
    }

    @Test("Long duration returns maximum")
    func longDuration() {
        #expect(PlayerScrubPolicy.chapterSnapDistance(duration: 10000) == PlayerScrubPolicy.chapterSnapMaximumSeconds)
    }

    @Test("Medium duration is proportional")
    func mediumDuration() {
        let distance = PlayerScrubPolicy.chapterSnapDistance(duration: 1000)
        #expect(distance > PlayerScrubPolicy.chapterSnapMinimumSeconds)
        #expect(distance < PlayerScrubPolicy.chapterSnapMaximumSeconds)
    }
}

@Suite("PlayerScrubPolicy Nearest Chapter Snap")
struct PlayerScrubPolicyNearestChapterSnapTests {
    @Test("Zero duration returns nil")
    func zeroDuration() {
        let chapters = [PlayerScrubPolicy.ChapterBoundary(startTime: 60, title: "Chapter 1")]
        #expect(PlayerScrubPolicy.nearestChapterSnap(scrubTime: 30, chapters: chapters, duration: 0) == nil)
    }

    @Test("No chapters returns nil")
    func noChapters() {
        #expect(PlayerScrubPolicy.nearestChapterSnap(scrubTime: 30, chapters: [], duration: 3600) == nil)
    }

    @Test("Non-finite duration returns nil")
    func nonFiniteDurationReturnsNil() {
        let chapters = [PlayerScrubPolicy.ChapterBoundary(startTime: 60, title: "Chapter 1")]
        #expect(PlayerScrubPolicy.nearestChapterSnap(scrubTime: 30, chapters: chapters, duration: .nan) == nil)
    }

    @Test("Chapter at start time of 0 is ignored")
    func chapterAtZeroIgnored() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 0, title: "Intro"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 60, title: "Chapter 1")
        ]
        #expect(PlayerScrubPolicy.nearestChapterSnap(scrubTime: 5, chapters: chapters, duration: 3600) == nil)
    }

    @Test("Finds nearest chapter within threshold")
    func findsNearestChapter() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 60, title: "Chapter 1"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 120, title: "Chapter 2")
        ]
        #expect(PlayerScrubPolicy.nearestChapterSnap(scrubTime: 65, chapters: chapters, duration: 3600) == 60)
    }

    @Test("breaks ties by picking earliest chapter")
    func findsNearestChapterByDistanceThenEarliest() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 70, title: "Earlier Chapter"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 80, title: "Later Chapter")
        ]
        #expect(PlayerScrubPolicy.nearestChapterSnap(scrubTime: 75, chapters: chapters, duration: 3600) == 70)
    }

    @Test("finds nearest chapter regardless of chapter order")
    func findsNearestChapterWhenUnsorted() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 80, title: "Chapter 1"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 70, title: "Chapter 2")
        ]
        #expect(PlayerScrubPolicy.nearestChapterSnap(scrubTime: 74, chapters: chapters, duration: 3600) == 70)
    }

    @Test("Outside threshold returns nil")
    func outsideThreshold() {
        let chapters = [PlayerScrubPolicy.ChapterBoundary(startTime: 60, title: "Chapter 1")]
        #expect(PlayerScrubPolicy.nearestChapterSnap(scrubTime: 100, chapters: chapters, duration: 3600) == nil)
    }
}

@Suite("PlayerScrubPolicy Fine vs Coarse Scrubbing")
struct PlayerScrubPolicyFineCoarseScrubbingTests {
    @Test("Fine scrub velocity threshold")
    func fineScrubVelocityThreshold() {
        #expect(PlayerScrubPolicy.fineScrubVelocityThreshold == 80.0)
    }

    @Test("Fine scrub scale")
    func fineScrubScale() {
        #expect(PlayerScrubPolicy.fineScrubScale == 0.25)
    }

    @Test("Zero bar width returns zero")
    func zeroBarWidth() {
        #expect(PlayerScrubPolicy.scrubPercentDelta(translationX: 100, velocityX: 50, barWidth: 0) == 0)
    }

    @Test("Coarse scrubbing returns raw delta")
    func coarseScrubbing() {
        let delta = PlayerScrubPolicy.scrubPercentDelta(translationX: 100, velocityX: 200, barWidth: 1000)
        #expect(delta == 0.1)
    }

    @Test("Fine scrubbing scales delta down")
    func fineScrubbing() {
        let fineDelta = PlayerScrubPolicy.scrubPercentDelta(translationX: 100, velocityX: 50, barWidth: 1000)
        let coarseDelta = PlayerScrubPolicy.scrubPercentDelta(translationX: 100, velocityX: 200, barWidth: 1000)
        #expect(abs(fineDelta) < abs(coarseDelta))
    }

    @Test("Negative delta preserved")
    func negativeDelta() {
        let delta = PlayerScrubPolicy.scrubPercentDelta(translationX: -100, velocityX: 200, barWidth: 1000)
        #expect(delta == -0.1)
    }

    @Test("Non-finite translation returns zero")
    func nonFiniteTranslationReturnsZero() {
        #expect(
            PlayerScrubPolicy.scrubPercentDelta(
                translationX: .nan,
                velocityX: 50,
                barWidth: 1000
            ) == 0
        )
    }

    @Test("Non-finite velocity returns zero")
    func nonFiniteVelocityReturnsZero() {
        #expect(
            PlayerScrubPolicy.scrubPercentDelta(
                translationX: 100,
                velocityX: .infinity,
                barWidth: 1000
            ) == 0
        )
    }

    @Test("Non-finite bar width returns zero")
    func nonFiniteBarWidthReturnsZero() {
        #expect(
            PlayerScrubPolicy.scrubPercentDelta(
                translationX: 100,
                velocityX: 50,
                barWidth: .nan
            ) == 0
        )
    }
}

@Suite("PlayerScrubPolicy Preview")
struct PlayerScrubPolicyPreviewTests {
    @Test("Preview label formats time")
    func previewLabel() {
        let label = PlayerScrubPolicy.previewLabel(for: 125)
        #expect(!label.isEmpty)
    }

    @Test("Preview chapter title finds correct chapter")
    func previewChapterTitle() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 0, title: "Intro"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 60, title: "Chapter 1"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 120, title: "Chapter 2")
        ]
        #expect(PlayerScrubPolicy.previewChapterTitle(at: 90, chapters: chapters) == "Chapter 1")
        #expect(PlayerScrubPolicy.previewChapterTitle(at: 130, chapters: chapters) == "Chapter 2")
    }

    @Test("uses chapter 0 marker for preview title")
    func previewChapterTitleUsesZeroChapter() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 0, title: "Intro"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 10, title: "Chapter 1"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 20, title: "Chapter 2")
        ]
        #expect(PlayerScrubPolicy.previewChapterTitle(at: 5, chapters: chapters) == "Intro")
    }

    @Test("does not return title for non-finite times")
    func previewChapterTitleReturnsNilForNonFiniteTime() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 10, title: "Chapter 1")
        ]
        #expect(PlayerScrubPolicy.previewChapterTitle(at: .nan, chapters: chapters) == nil)
    }

    @Test("preview title uses nearest previous chapter regardless of chapter order")
    func previewChapterTitleUnsorted() {
        let chapters = [
            PlayerScrubPolicy.ChapterBoundary(startTime: 120, title: "Chapter 2"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 60, title: "Chapter 1"),
            PlayerScrubPolicy.ChapterBoundary(startTime: 0, title: "Intro")
        ]
        #expect(PlayerScrubPolicy.previewChapterTitle(at: 90, chapters: chapters) == "Chapter 1")
    }

    @Test("Preview chapter title returns nil for empty chapters")
    func previewChapterTitleEmpty() {
        #expect(PlayerScrubPolicy.previewChapterTitle(at: 90, chapters: []) == nil)
    }
}
