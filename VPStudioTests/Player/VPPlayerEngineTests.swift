import Foundation
import Testing
@testable import VPStudio

@Suite("VPPlayerEngine")
@MainActor
struct VPPlayerEngineTests {
    @Test
    func initialStateHasCorrectDefaults() {
        let engine = VPPlayerEngine()

        #expect(engine.isPlaying == false)
        #expect(engine.isBuffering == true)
        #expect(engine.currentTime == 0)
        #expect(engine.duration == 0)
        #expect(engine.playbackRate == 1.0)
        #expect(engine.volume == 1.0)
        #expect(engine.bufferedPercent == 0)
        #expect(engine.selectedSubtitleTrack == -1)
        #expect(engine.subtitlesEnabled == false)
        #expect(engine.stereoMode == .mono)
        #expect(engine.is3DContent == false)
        #expect(engine.error == nil)
        #expect(engine.currentTitle == nil)
    }

    @Test
    func resetSessionStateClearsAllPlaybackState() {
        let engine = VPPlayerEngine()
        engine.currentTitle = "Test Movie"
        engine.isPlaying = true
        engine.currentTime = 120
        engine.duration = 3600
        engine.bufferedPercent = 0.5
        engine.audioTracks = [VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "aac")]
        engine.subtitleTracks = [VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "srt")]
        engine.hdrMetadata = HDRDisplayMetadata(isHDR: false, isDolbyVision: false)
        engine.stereoMode = .sideBySide
        engine.error = "some error"

        engine.resetSessionState()

        #expect(engine.currentTitle == nil)
        #expect(engine.isPlaying == false)
        #expect(engine.isBuffering == true)
        #expect(engine.currentTime == 0)
        #expect(engine.duration == 0)
        #expect(engine.bufferedPercent == 0)
        #expect(engine.audioTracks.isEmpty)
        #expect(engine.subtitleTracks.isEmpty)
        #expect(engine.selectedSubtitleTrack == -1)
        #expect(engine.subtitlesEnabled == false)
        #expect(engine.hdrMetadata == nil)
        #expect(engine.stereoMode == .mono)
        #expect(engine.error == nil)
    }

    @Test
    func selectAudioTrackUpdatesSelectedTrack() {
        let engine = VPPlayerEngine()
        engine.audioTracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "aac"),
            VPPlayerEngine.TrackInfo(id: 1, name: "Spanish", language: "es", codec: "aac"),
        ]

        engine.selectAudioTrack(1)

        #expect(engine.selectedAudioTrack == 1)
    }

    @Test
    func selectAudioTrackRejectsInvalidTrackId() {
        let engine = VPPlayerEngine()
        engine.audioTracks = [
            VPPlayerEngine.TrackInfo(id: 5, name: "English", language: "en", codec: "aac"),
            VPPlayerEngine.TrackInfo(id: 10, name: "Spanish", language: "es", codec: "aac"),
        ]
        engine.selectedAudioTrack = 5

        engine.selectAudioTrack(7)

        #expect(engine.selectedAudioTrack == 5)
    }

    @Test
    func loadAudioTracksSelectsFirstTrackIfNoSelection() {
        let engine = VPPlayerEngine()
        engine.audioTracks = [
            VPPlayerEngine.TrackInfo(id: 5, name: "English", language: "en", codec: "aac"),
            VPPlayerEngine.TrackInfo(id: 10, name: "Spanish", language: "es", codec: "aac"),
        ]

        engine.loadAudioTracks(engine.audioTracks)

        #expect(engine.selectedAudioTrack == 5)
    }

    @Test
    func loadAudioTracksPreservesSelectedTrackIfStillAvailable() {
        let engine = VPPlayerEngine()
        engine.selectedAudioTrack = 10
        let tracks = [
            VPPlayerEngine.TrackInfo(id: 5, name: "English", language: "en", codec: "aac"),
            VPPlayerEngine.TrackInfo(id: 10, name: "Spanish", language: "es", codec: "aac"),
        ]

        engine.loadAudioTracks(tracks, selectedTrackID: 10)

        #expect(engine.selectedAudioTrack == 10)
    }

    @Test
    func loadAudioTracksFallsBackToFirstIfSelectedNotAvailable() {
        let engine = VPPlayerEngine()
        engine.selectedAudioTrack = 999
        let tracks = [
            VPPlayerEngine.TrackInfo(id: 5, name: "English", language: "en", codec: "aac"),
        ]

        engine.loadAudioTracks(tracks)

        #expect(engine.selectedAudioTrack == 5)
    }

    @Test
    func selectSubtitleTrackDisablesSubtitlesForIndexNegativeOne() {
        let engine = VPPlayerEngine()
        engine.subtitlesEnabled = true
        engine.currentSubtitleText = "Some text"

        engine.selectSubtitleTrack(-1)

        #expect(engine.selectedSubtitleTrack == -1)
        #expect(engine.subtitlesEnabled == false)
        #expect(engine.currentSubtitleText == nil)
    }

    @Test
    func selectSubtitleTrackValidIndexEnablesSubtitles() {
        let engine = VPPlayerEngine()
        engine.subtitleTracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "srt"),
        ]
        engine.subtitlesEnabled = false

        engine.selectSubtitleTrack(0)

        #expect(engine.selectedSubtitleTrack == 0)
        #expect(engine.subtitlesEnabled == true)
    }

    @Test
    func selectSubtitleTrackIgnoresInvalidNegativeIndex() {
        let engine = VPPlayerEngine()
        engine.subtitleTracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "srt"),
        ]

        engine.selectSubtitleTrack(-5)

        #expect(engine.selectedSubtitleTrack == -1)
    }

    @Test
    func selectSubtitleTrackIgnoresIndexBeyondBounds() {
        let engine = VPPlayerEngine()
        engine.subtitleTracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "srt"),
        ]

        engine.selectSubtitleTrack(5)

        #expect(engine.selectedSubtitleTrack == -1)
    }

    @Test
    func selectSubtitleTrackSupportsNonContiguousTrackIds() {
        let engine = VPPlayerEngine()
        engine.subtitleTracks = [
            VPPlayerEngine.TrackInfo(id: 10, name: "English", language: "en", codec: "srt"),
            VPPlayerEngine.TrackInfo(id: 20, name: "Spanish", language: "es", codec: "srt"),
        ]
        engine.subtitlesEnabled = false

        engine.selectSubtitleTrack(20)

        #expect(engine.selectedSubtitleTrack == 20)
        #expect(engine.subtitlesEnabled == true)
    }

    @Test
    func selectSubtitleTrackRejectsInvalidTrackIdEvenWhenLarge() {
        let engine = VPPlayerEngine()
        engine.subtitleTracks = [
            VPPlayerEngine.TrackInfo(id: 10, name: "English", language: "en", codec: "srt"),
            VPPlayerEngine.TrackInfo(id: 20, name: "Spanish", language: "es", codec: "srt"),
        ]
        engine.subtitlesEnabled = false

        engine.selectSubtitleTrack(99)

        #expect(engine.selectedSubtitleTrack == -1)
        #expect(engine.subtitlesEnabled == false)
    }

    @Test
    func cycleRateAdvancesThroughRateList() {
        let engine = VPPlayerEngine()
        engine.playbackRate = 1.0

        engine.cycleRate()

        #expect(engine.playbackRate == 1.25)

        engine.cycleRate()
        #expect(engine.playbackRate == 1.5)

        engine.cycleRate()
        #expect(engine.playbackRate == 2.0)
    }

    @Test
    func cycleRateResetsToOnePointZeroIfCurrentRateNotInList() {
        let engine = VPPlayerEngine()
        engine.playbackRate = 3.0

        engine.cycleRate()

        #expect(engine.playbackRate == 1.0)
    }

    @Test
    func setRateUpdatesPlaybackRate() {
        let engine = VPPlayerEngine()

        engine.setRate(1.5)

        #expect(engine.playbackRate == 1.5)
    }

    @Test
    func loadChaptersSortsByStartTime() {
        let engine = VPPlayerEngine()
        let chapters = [
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 3", startTime: 300, endTime: 600),
            VPPlayerEngine.ChapterInfo(id: 2, title: "Chapter 1", startTime: 0, endTime: 100),
            VPPlayerEngine.ChapterInfo(id: 3, title: "Chapter 2", startTime: 100, endTime: 300),
        ]

        engine.loadChapters(chapters)

        #expect(engine.chapters.count == 3)
        #expect(engine.chapters[0].title == "Chapter 1")
        #expect(engine.chapters[1].title == "Chapter 2")
        #expect(engine.chapters[2].title == "Chapter 3")
    }

    @Test
    func currentChapterReturnsChapterContainingTime() {
        let engine = VPPlayerEngine()
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 1, title: "Intro", startTime: 0, endTime: 60),
            VPPlayerEngine.ChapterInfo(id: 2, title: "Main", startTime: 60, endTime: 300),
            VPPlayerEngine.ChapterInfo(id: 3, title: "Outro", startTime: 300, endTime: 360),
        ]
        engine.currentTime = 150

        let chapter = engine.currentChapter(at: 150)

        #expect(chapter?.title == "Main")
    }

    @Test
    func currentChapterReturnsLastChapterIfPastAllStartTimes() {
        let engine = VPPlayerEngine()
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 1, title: "Intro", startTime: 0, endTime: 60),
            VPPlayerEngine.ChapterInfo(id: 2, title: "Main", startTime: 60, endTime: 300),
        ]
        engine.currentTime = 500

        let chapter = engine.currentChapter(at: 500)

        #expect(chapter?.title == "Main")
    }

    @Test
    func currentChapterReturnsNilForEmptyChapters() {
        let engine = VPPlayerEngine()

        let chapter = engine.currentChapter(at: 100)

        #expect(chapter == nil)
    }

    @Test
    func nextChapterTimeReturnsStartOfNextChapter() {
        let engine = VPPlayerEngine()
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 1", startTime: 0, endTime: 100),
            VPPlayerEngine.ChapterInfo(id: 2, title: "Chapter 2", startTime: 100, endTime: 200),
        ]
        engine.currentTime = 50

        let nextTime = engine.nextChapterTime()

        #expect(nextTime == 100)
    }

    @Test
    func nextChapterTimeReturnsNilWhenAtLastChapter() {
        let engine = VPPlayerEngine()
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 1", startTime: 0, endTime: 100),
            VPPlayerEngine.ChapterInfo(id: 2, title: "Chapter 2", startTime: 100, endTime: 200),
        ]
        engine.currentTime = 150

        let nextTime = engine.nextChapterTime()

        #expect(nextTime == nil)
    }

    @Test
    func nextChapterTimeReturnsFirstChapterStartIfBeforeAll() {
        let engine = VPPlayerEngine()
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 1", startTime: 50, endTime: 100),
        ]
        engine.currentTime = 0

        let nextTime = engine.nextChapterTime()

        #expect(nextTime == 50)
    }

    @Test
    func previousChapterTimeRestartsCurrentChapterIfMoreThanThreeSecondsIn() {
        let engine = VPPlayerEngine()
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 1", startTime: 0, endTime: 100),
            VPPlayerEngine.ChapterInfo(id: 2, title: "Chapter 2", startTime: 100, endTime: 200),
        ]
        engine.currentTime = 150

        let prevTime = engine.previousChapterTime()

        #expect(prevTime == 100)
    }

    @Test
    func previousChapterTimeGoesToPreviousChapterIfWithinThreeSeconds() {
        let engine = VPPlayerEngine()
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 1", startTime: 0, endTime: 100),
            VPPlayerEngine.ChapterInfo(id: 2, title: "Chapter 2", startTime: 100, endTime: 200),
        ]
        engine.currentTime = 102

        let prevTime = engine.previousChapterTime()

        #expect(prevTime == 0)
    }

    @Test
    func previousChapterTimeReturnsCurrentStartIfFirstChapter() {
        let engine = VPPlayerEngine()
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 1", startTime: 0, endTime: 100),
        ]
        engine.currentTime = 50

        let prevTime = engine.previousChapterTime()

        #expect(prevTime == 0)
    }

    @Test
    func previousChapterTimeReturnsNilForEmptyChapters() {
        let engine = VPPlayerEngine()

        let prevTime = engine.previousChapterTime()

        #expect(prevTime == nil)
    }

    @Test
    func updateStereoModeFromTitleSetsCorrectMode() {
        let engine = VPPlayerEngine()

        engine.updateStereoMode(from: "Movie [SBS].mkv")
        #expect(engine.stereoMode == .sideBySide)

        engine.updateStereoMode(from: "Movie_OU.mkv")
        #expect(engine.stereoMode == .overUnder)

        engine.updateStereoMode(from: "Movie_HVC1.mkv", codecHint: "mv-hevc")
        #expect(engine.stereoMode == .mvHevc)

        engine.updateStereoMode(from: "RegularMovie.mp4")
        #expect(engine.stereoMode == .mono)
    }

    @Test
    func progressPercentReturnsZeroWhenDurationIsZero() {
        let engine = VPPlayerEngine()
        engine.currentTime = 100
        engine.duration = 0

        #expect(engine.progressPercent == 0)
    }

    @Test
    func progressPercentReturnsCorrectPercentage() {
        let engine = VPPlayerEngine()
        engine.currentTime = 500
        engine.duration = 1000

        #expect(engine.progressPercent == 0.5)
    }

    @Test
    func is3DContentIsTrueWhenStereoModeIsNotMono() {
        let engine = VPPlayerEngine()

        engine.stereoMode = .mono
        #expect(engine.is3DContent == false)

        engine.stereoMode = .sideBySide
        #expect(engine.is3DContent == true)

        engine.stereoMode = .overUnder
        #expect(engine.is3DContent == true)
    }
}
