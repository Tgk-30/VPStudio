import Foundation
import CoreGraphics
import Testing
@testable import VPStudio

// MARK: - VPPlayerEngine Core State Tests

@Suite("VPPlayerEngine — Core State Management")
struct VPPlayerEngineCoreStateTests {

    @Test @MainActor func defaultValuesAreCorrect() {
        let engine = VPPlayerEngine()

        #expect(engine.currentTitle == nil)
        #expect(engine.isPlaying == false)
        #expect(engine.isBuffering == true)
        #expect(engine.currentTime == 0)
        #expect(engine.duration == 0)
        #expect(engine.playbackRate == 1.0)
        #expect(engine.volume == 1.0)
        #expect(engine.bufferedPercent == 0)
        #expect(engine.selectedAudioTrack == 0)
        #expect(engine.selectedSubtitleTrack == -1)
        #expect(engine.subtitlesEnabled == false)
        #expect(engine.currentSubtitleText == nil)
        #expect(engine.videoSize == .zero)
        #expect(engine.fps == 0)
        #expect(engine.videoBitrate == 0)
        #expect(engine.hdrMetadata == nil)
        #expect(engine.stereoMode == .mono)
        #expect(engine.chapters.isEmpty)
        #expect(engine.error == nil)
        #expect(engine.isDimEnabled == true)
    }

    @Test @MainActor func is3DContentIsFalseForMono() {
        let engine = VPPlayerEngine()
        #expect(engine.is3DContent == false)
    }

    @Test @MainActor func is3DContentIsTrueForNonMono() {
        let engine = VPPlayerEngine()
        engine.stereoMode = .sideBySide
        #expect(engine.is3DContent == true)

        engine.stereoMode = .overUnder
        #expect(engine.is3DContent == true)

        engine.stereoMode = .mvHevc
        #expect(engine.is3DContent == true)

        engine.stereoMode = .sphere180
        #expect(engine.is3DContent == true)

        engine.stereoMode = .sphere360
        #expect(engine.is3DContent == true)
    }

    @Test @MainActor func settingCurrentTitleRoundTrips() {
        let engine = VPPlayerEngine()
        engine.currentTitle = "Dune: Part Two"
        #expect(engine.currentTitle == "Dune: Part Two")

        engine.currentTitle = nil
        #expect(engine.currentTitle == nil)
    }

    @Test @MainActor func settingIsDimEnabledRoundTrips() {
        let engine = VPPlayerEngine()
        #expect(engine.isDimEnabled == true)

        engine.isDimEnabled = false
        #expect(engine.isDimEnabled == false)

        engine.isDimEnabled = true
        #expect(engine.isDimEnabled == true)
    }

    @Test @MainActor func settingVideoSizeRoundTrips() {
        let engine = VPPlayerEngine()
        engine.videoSize = CGSize(width: 3840, height: 2160)
        #expect(engine.videoSize == CGSize(width: 3840, height: 2160))

        engine.videoSize = .zero
        #expect(engine.videoSize == .zero)
    }

    @Test @MainActor func settingFpsAndBitrateRoundTrips() {
        let engine = VPPlayerEngine()
        engine.fps = 24.0
        engine.videoBitrate = 15_000_000
        #expect(engine.fps == 24.0)
        #expect(engine.videoBitrate == 15_000_000)

        engine.fps = 0
        engine.videoBitrate = 0
        #expect(engine.fps == 0)
        #expect(engine.videoBitrate == 0)
    }

    @Test @MainActor func settingHdrMetadataRoundTrips() {
        let engine = VPPlayerEngine()
        let metadata = HDRDisplayMetadata(
            maxDisplayLuminance: 1000,
            minDisplayLuminance: 0.005,
            maxContentLightLevel: 1200,
            maxFrameAverageLightLevel: 420,
            colorPrimaries: "ITU_R_2020",
            transferFunction: "SMPTE_ST_2084_PQ",
            isHDR: true,
            isDolbyVision: false
        )

        engine.hdrMetadata = metadata
        #expect(engine.hdrMetadata == metadata)

        engine.hdrMetadata = nil
        #expect(engine.hdrMetadata == nil)
    }

    @Test @MainActor func settingErrorRoundTrips() {
        let engine = VPPlayerEngine()
        engine.error = "Decoder error: unsupported codec"
        #expect(engine.error == "Decoder error: unsupported codec")

        engine.error = nil
        #expect(engine.error == nil)
    }

    @Test @MainActor func audioTrackSelectionRoundTrips() {
        let engine = VPPlayerEngine()
        engine.audioTracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "aac"),
            VPPlayerEngine.TrackInfo(id: 1, name: "Spanish", language: "es", codec: "aac"),
            VPPlayerEngine.TrackInfo(id: 2, name: "French", language: "fr", codec: "aac"),
        ]

        engine.selectAudioTrack(1)
        #expect(engine.selectedAudioTrack == 1)

        engine.selectAudioTrack(0)
        #expect(engine.selectedAudioTrack == 0)

        engine.selectAudioTrack(2)
        #expect(engine.selectedAudioTrack == 2)
    }

    @Test @MainActor func subtitleTrackSelectionDisablesSubtitlesWhenDisabled() {
        let engine = VPPlayerEngine()
        engine.subtitleTracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "srt"),
        ]
        engine.subtitlesEnabled = true

        engine.selectSubtitleTrack(-1)

        #expect(engine.selectedSubtitleTrack == -1)
        #expect(engine.subtitlesEnabled == false)
        #expect(engine.currentSubtitleText == nil)
    }

    @Test @MainActor func subtitleTrackSelectionEnablesSubtitles() {
        let engine = VPPlayerEngine()
        engine.subtitleTracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "srt"),
        ]

        engine.selectSubtitleTrack(0)

        #expect(engine.selectedSubtitleTrack == 0)
        #expect(engine.subtitlesEnabled == true)
    }

    @Test @MainActor func selectSubtitleTrackRejectsOutOfBoundsIndices() {
        let engine = VPPlayerEngine()
        engine.subtitleTracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "srt"),
        ]
        engine.selectSubtitleTrack(0)

        engine.selectSubtitleTrack(5)

        #expect(engine.selectedSubtitleTrack == 0)
    }

    @Test @MainActor func selectSubtitleTrackRejectsNegativeBeyondBounds() {
        let engine = VPPlayerEngine()
        engine.subtitleTracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "srt"),
        ]
        engine.selectSubtitleTrack(0)

        engine.selectSubtitleTrack(-2)

        #expect(engine.selectedSubtitleTrack == 0)
    }
}

// MARK: - VPPlayerEngine Previous Chapter Time Edge Cases

@Suite("VPPlayerEngine — Previous Chapter Edge Cases")
struct VPPlayerEnginePreviousChapterEdgeCaseTests {

    @Test @MainActor func previousChapterTimeAtChapterStartLessThan3Seconds() {
        let engine = VPPlayerEngine()
        engine.loadChapters([
            VPPlayerEngine.ChapterInfo(id: 0, title: "Chapter 1", startTime: 0, endTime: 60),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 2", startTime: 60, endTime: 120),
        ])
        engine.currentTime = 61 // 1s into Chapter 2 (less than 3s)

        let prev = engine.previousChapterTime()

        #expect(prev == 0) // Goes back to Chapter 1
    }

    @Test @MainActor func previousChapterTimeAtExact3SecondBoundary() {
        let engine = VPPlayerEngine()
        engine.loadChapters([
            VPPlayerEngine.ChapterInfo(id: 0, title: "Chapter 1", startTime: 0, endTime: 60),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 2", startTime: 60, endTime: 120),
        ])
        engine.currentTime = 63 // Exactly 3s into Chapter 2

        let prev = engine.previousChapterTime()

        #expect(prev == 0)
    }

    @Test @MainActor func previousChapterTimeJustPast3SecondBoundary() {
        let engine = VPPlayerEngine()
        engine.loadChapters([
            VPPlayerEngine.ChapterInfo(id: 0, title: "Chapter 1", startTime: 0, endTime: 60),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 2", startTime: 60, endTime: 120),
        ])
        engine.currentTime = 64 // 4s into Chapter 2

        let prev = engine.previousChapterTime()

        #expect(prev == 60) // Restarts Chapter 2
    }

    @Test @MainActor func previousChapterTimeWithManyChapters() {
        let engine = VPPlayerEngine()
        var chapters: [VPPlayerEngine.ChapterInfo] = []
        for i in 0..<10 {
            chapters.append(VPPlayerEngine.ChapterInfo(id: i, title: "Chapter \(i)", startTime: Double(i * 60), endTime: Double((i + 1) * 60)))
        }
        engine.loadChapters(chapters)

        engine.currentTime = 301 // 1s into Chapter 6
        #expect(engine.previousChapterTime() == 240)

        engine.currentTime = 305 // 5s into Chapter 6
        #expect(engine.previousChapterTime() == 300) // Restarts Chapter 6
    }

    @Test @MainActor func previousChapterTimeAtVeryStartOfTimeline() {
        let engine = VPPlayerEngine()
        engine.loadChapters([
            VPPlayerEngine.ChapterInfo(id: 0, title: "Opening", startTime: 0, endTime: 30),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Chapter 1", startTime: 30, endTime: 90),
        ])

        engine.currentTime = 5
        let prev = engine.previousChapterTime()

        #expect(prev == 0) // Restarts Opening since there's nothing before
    }

    @Test @MainActor func previousChapterTimeBeforeFirstChapterStart() {
        let engine = VPPlayerEngine()
        engine.loadChapters([
            VPPlayerEngine.ChapterInfo(id: 0, title: "Delayed Chapter", startTime: 30, endTime: 90),
        ])

        engine.currentTime = 10 // Before chapter starts

        let prev = engine.previousChapterTime()

        #expect(prev == nil)
    }
}

// MARK: - VPPlayerEngine Audio Track Loading Edge Cases

@Suite("VPPlayerEngine — Audio Track Loading Edge Cases")
struct VPPlayerEngineAudioTrackLoadingTests {

    @Test @MainActor func loadAudioTracksWithEmptyArray() {
        let engine = VPPlayerEngine()
        engine.selectAudioTrack(5)
        engine.audioTracks = [VPPlayerEngine.TrackInfo(id: 1, name: "English", language: "en", codec: "aac")]
        engine.loadAudioTracks([])

        #expect(engine.audioTracks.isEmpty)
        #expect(engine.selectedAudioTrack == 0)
    }

    @Test @MainActor func loadAudioTracksWithSingleTrackAutoSelects() {
        let engine = VPPlayerEngine()
        let tracks = [VPPlayerEngine.TrackInfo(id: 10, name: "Stereo", language: "en", codec: "aac")]

        engine.loadAudioTracks(tracks)

        #expect(engine.audioTracks.count == 1)
        #expect(engine.selectedAudioTrack == 10)
    }

    @Test @MainActor func loadAudioTracksPreservesSelectionWhenStillValid() {
        let engine = VPPlayerEngine()
        let tracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "aac"),
            VPPlayerEngine.TrackInfo(id: 1, name: "Spanish", language: "es", codec: "aac"),
        ]

        engine.selectAudioTrack(1)
        engine.loadAudioTracks(tracks, selectedTrackID: nil)

        #expect(engine.selectedAudioTrack == 1)
    }

    @Test @MainActor func loadAudioTracksFallsBackWhenSelectionNoLongerExists() {
        let engine = VPPlayerEngine()
        let tracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "aac"),
            VPPlayerEngine.TrackInfo(id: 1, name: "Spanish", language: "es", codec: "aac"),
        ]

        engine.selectAudioTrack(99) // Non-existent selection
        engine.loadAudioTracks(tracks, selectedTrackID: nil)

        #expect(engine.selectedAudioTrack == 0) // Falls back to first
    }

    @Test @MainActor func loadAudioTracksWithExplicitSelectedTrackID() {
        let engine = VPPlayerEngine()
        let tracks = [
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "aac"),
            VPPlayerEngine.TrackInfo(id: 1, name: "Director Commentary", language: "en", codec: "aac"),
        ]

        engine.loadAudioTracks(tracks, selectedTrackID: 1)

        #expect(engine.selectedAudioTrack == 1)
    }
}

// MARK: - VPPlayerEngine Video Size Ratio Calculation

@Suite("VPPlayerEngine — Video Size Calculations")
struct VPPlayerEngineVideoSizeTests {

    @Test @MainActor func videoSizeAspectRatio16x9() {
        let engine = VPPlayerEngine()
        engine.videoSize = CGSize(width: 1920, height: 1080)

        let ratio = engine.videoSize.width / engine.videoSize.height
        #expect(abs(ratio - 16.0/9.0) < 0.001)
    }

    @Test @MainActor func videoSizeAspectRatio4x3() {
        let engine = VPPlayerEngine()
        engine.videoSize = CGSize(width: 1440, height: 1080)

        let ratio = engine.videoSize.width / engine.videoSize.height
        #expect(abs(ratio - 4.0/3.0) < 0.001)
    }

    @Test @MainActor func videoSizeAspectRatio21x9() {
        let engine = VPPlayerEngine()
        engine.videoSize = CGSize(width: 2560, height: 1080)

        let ratio = engine.videoSize.width / engine.videoSize.height
        #expect(abs(ratio - 64.0/27.0) < 0.001)
    }

    @Test @MainActor func videoSizeAspectRatioForVerticalVideo() {
        let engine = VPPlayerEngine()
        engine.videoSize = CGSize(width: 1080, height: 1920)

        let ratio = engine.videoSize.width / engine.videoSize.height
        #expect(abs(ratio - 9.0/16.0) < 0.001)
    }

    @Test @MainActor func videoSizeAspectRatioFor4K() {
        let engine = VPPlayerEngine()
        engine.videoSize = CGSize(width: 3840, height: 2160)

        let ratio = engine.videoSize.width / engine.videoSize.height
        #expect(abs(ratio - 16.0/9.0) < 0.001)
    }

    @Test @MainActor func videoSizeAspectRatioFor8K() {
        let engine = VPPlayerEngine()
        engine.videoSize = CGSize(width: 7680, height: 4320)

        let ratio = engine.videoSize.width / engine.videoSize.height
        #expect(abs(ratio - 16.0/9.0) < 0.001)
    }
}
