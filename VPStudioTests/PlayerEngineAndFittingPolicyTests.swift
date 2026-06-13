import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import VPStudio

// MARK: - Player Engine Selector

@Suite("Player Engine Selector")
struct PlayerEngineSelectorTests {
    private let selector = PlayerEngineSelector()

    // MARK: MV-HEVC

    @Test("MV-HEVC stream returns AVPlayer only")
    func mvHevcStreamReturnsOnlyAVPlayer() {
        let stream = Fixtures.stream(
            url: "https://example.com/spatial.mov",
            fileName: "Spatial.Video.mv-hevc.mov"
        )
        let order = selector.engineOrder(for: stream, strategy: .compatibility)
        #expect(order == [.avPlayer])
    }

    @Test("MV-HEVC with codec hint returns AVPlayer only")
    func mvHevcWithCodecHintReturnsOnlyAVPlayer() {
        // Simulate a stream where codec raw value hints at MV-HEVC
        // We can't easily mutate codec rawValue, but the title "mv-hevc" triggers it
        let mvHevcStream = Fixtures.stream(
            url: "https://example.com/video.mov",
            fileName: "movie.mv-hevc.mov"
        )
        let order = selector.engineOrder(for: mvHevcStream, strategy: .performance)
        #expect(order == [.avPlayer])
    }

    @Test("MV-HEVC ignores strategy and always returns single engine")
    func mvHevcIgnoresAllStrategies() {
        let stream = Fixtures.stream(fileName: "spatial.mv-hevc.mov")
        #expect(selector.engineOrder(for: stream, strategy: .adaptive) == [.avPlayer])
        #expect(selector.engineOrder(for: stream, strategy: .performance) == [.avPlayer])
        #expect(selector.engineOrder(for: stream, strategy: .compatibility) == [.avPlayer])
    }

    // MARK: Performance Strategy

    @Test("Performance strategy always returns AVPlayer first")
    func performanceStrategyAlwaysReturnsAVPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.avi", fileName: "video.avi")
        let order = selector.engineOrder(for: stream, strategy: .performance)
        #expect(order == [.avPlayer, .ksPlayer])
    }

    // MARK: Compatibility Strategy

    @Test("Compatibility strategy prefers AVPlayer first on visionOS, KSPlayer otherwise")
    func compatibilityStrategyPlatformDependent() {
        let stream = Fixtures.stream(fileName: "video.mkv")
        let order = selector.engineOrder(for: stream, strategy: .compatibility)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    // MARK: Adaptive Strategy — Native Pipeline Preference

    @Test("Adaptive with Dolby Vision prefers AVPlayer first")
    func adaptiveWithDolbyVisionPrefersAVPlayerFirst() {
        let stream = Fixtures.stream(hdr: .dolbyVision, fileName: "video.mkv")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #expect(order == [.avPlayer, .ksPlayer])
    }

    @Test("Adaptive with HDR10+ prefers AVPlayer first")
    func adaptiveWithHDR10PlusPrefersAVPlayerFirst() {
        let stream = Fixtures.stream(hdr: .hdr10Plus, fileName: "video.mkv")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #expect(order == [.avPlayer, .ksPlayer])
    }

    @Test("Adaptive with spatial title prefers AVPlayer first")
    func adaptiveWithSpatialTitlePrefersAVPlayerFirst() {
        let stream = Fixtures.stream(fileName: "video.sbs.3d.mkv")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #expect(order == [.avPlayer, .ksPlayer])
    }

    @Test("Adaptive with 180 VR title prefers AVPlayer first")
    func adaptiveWith180VRPrefersAVPlayerFirst() {
        let stream = Fixtures.stream(fileName: "video.180.vr.mp4")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #expect(order == [.avPlayer, .ksPlayer])
    }

    @Test("Adaptive with 360 VR title prefers AVPlayer first")
    func adaptiveWith360VRPrefersAVPlayerFirst() {
        let stream = Fixtures.stream(fileName: "video.360.mp4")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #expect(order == [.avPlayer, .ksPlayer])
    }

    // MARK: Adaptive Strategy — Edge Formats

    @Test("Adaptive with AVI extension prefers KSPlayer first on non-visionOS")
    func adaptiveWithAVIPrefersKSPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.avi", fileName: "video.avi")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    @Test("Adaptive with WMV extension prefers KSPlayer first on non-visionOS")
    func adaptiveWithWMVPrefersKSPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.wmv", fileName: "video.wmv")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    @Test("Adaptive with FLV extension prefers KSPlayer first on non-visionOS")
    func adaptiveWithFLVPrefersKSPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.flv", fileName: "video.flv")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    @Test("Adaptive with TS extension prefers KSPlayer first on non-visionOS")
    func adaptiveWithTSPrefersKSPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.ts", fileName: "video.ts")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    @Test("Adaptive with M2TS extension prefers KSPlayer first on non-visionOS")
    func adaptiveWithM2TSPrefersKSPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.m2ts", fileName: "video.m2ts")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    @Test("Adaptive with MPEG extension prefers KSPlayer first on non-visionOS")
    func adaptiveWithMPEGPrefersKSPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.mpeg", fileName: "video.mpeg")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    @Test("Adaptive with MPG extension prefers KSPlayer first on non-visionOS")
    func adaptiveWithMPGPrefersKSPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.mpg", fileName: "video.mpg")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    @Test("Adaptive with Xvid in filename prefers KSPlayer first on non-visionOS")
    func adaptiveWithXvidPrefersKSPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.avi", fileName: "movie.xvid.avi")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    @Test("Adaptive with VC-1 in filename prefers KSPlayer first on non-visionOS")
    func adaptiveWithVC1PrefersKSPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.mkv", fileName: "movie.vc1.mkv")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    @Test("Adaptive with RealVideo in filename prefers KSPlayer first on non-visionOS")
    func adaptiveWithRealVideoPrefersKSPlayerFirst() {
        let stream = Fixtures.stream(url: "https://example.com/video.rmvb", fileName: "movie.realvideo.rmvb")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    @Test("Adaptive with unknown codec prefers KSPlayer first on non-visionOS")
    func adaptiveWithUnknownCodecPrefersKSPlayerFirst() {
        let stream = Fixtures.stream(codec: .unknown, fileName: "video.mp4")
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #if os(visionOS)
        #expect(order == [.avPlayer, .ksPlayer])
        #else
        #expect(order == [.ksPlayer, .avPlayer])
        #endif
    }

    // MARK: Adaptive Strategy — Safe Streams

    @Test("Adaptive with safe MP4/H264 prefers AVPlayer first")
    func adaptiveWithSafeStreamPrefersAVPlayerFirst() {
        let stream = Fixtures.stream(
            url: "https://example.com/video.mp4",
            codec: .h264,
            hdr: .sdr,
            fileName: "video.mp4"
        )
        let order = selector.engineOrder(for: stream, strategy: .adaptive)
        #expect(order == [.avPlayer, .ksPlayer])
    }

    @Test("Engine order always contains both engines for non-MV-HEVC streams")
    func engineOrderContainsBothEnginesForNonMvHevc() {
        let stream = Fixtures.stream(fileName: "video.mkv")
        let strategies: [PlayerEngineStrategy] = [.adaptive, .performance, .compatibility]
        for strategy in strategies {
            let order = selector.engineOrder(for: stream, strategy: strategy)
            #expect(Set(order) == Set(PlayerEngineKind.allCases), "Failed for strategy: \(strategy)")
        }
    }
}

// MARK: - Player Engine Kind

@Suite("Player Engine Kind Extended")
struct PlayerEngineKindExtendedTests {

    @Test("All cases contain expected values")
    func allCasesContainsExpectedValues() {
        let cases = PlayerEngineKind.allCases
        #expect(cases.contains(.ksPlayer))
        #expect(cases.contains(.avPlayer))
        #expect(cases.count == 2)
    }

    @Test("Display names match expected strings")
    func displayNamesMatchExpected() {
        #expect(PlayerEngineKind.ksPlayer.displayName == "KSPlayer")
        #expect(PlayerEngineKind.avPlayer.displayName == "AVPlayer")
    }

    @Test("Equality works for same cases")
    func equalityWorksForSameCases() {
        #expect(PlayerEngineKind.avPlayer == PlayerEngineKind.avPlayer)
        #expect(PlayerEngineKind.ksPlayer == PlayerEngineKind.ksPlayer)
    }

    @Test("Inequality works for different cases")
    func inequalityWorksForDifferentCases() {
        #expect(PlayerEngineKind.avPlayer != PlayerEngineKind.ksPlayer)
    }

    @Test("Raw values are correct")
    func rawValuesAreCorrect() {
        #expect(PlayerEngineKind.ksPlayer.rawValue == "ksPlayer")
        #expect(PlayerEngineKind.avPlayer.rawValue == "avPlayer")
    }
}

// MARK: - Player Aspect Ratio Policy

@Suite("Player Aspect Ratio Policy Ratios")
struct PlayerAspectRatioPolicyRatioTests {

    @Test("1920x1080 resolves to approximately 16:9")
    func ratioFrom1920x1080IsApproximately16By9() {
        let ratio = PlayerAspectRatioPolicy.ratio(from: CGSize(width: 1920, height: 1080))
        #expect(abs(ratio! - (16.0 / 9.0)) < 0.0001)
    }

    @Test("1280x720 resolves to approximately 16:9")
    func ratioFrom1280x720IsApproximately16By9() {
        let ratio = PlayerAspectRatioPolicy.ratio(from: CGSize(width: 1280, height: 720))
        #expect(abs(ratio! - (16.0 / 9.0)) < 0.0001)
    }

    @Test("3840x2160 resolves to approximately 16:9")
    func ratioFrom3840x2160IsApproximately16By9() {
        let ratio = PlayerAspectRatioPolicy.ratio(from: CGSize(width: 3840, height: 2160))
        #expect(abs(ratio! - (16.0 / 9.0)) < 0.0001)
    }

    @Test("2560x1080 resolves to approximately 21:9")
    func ratioFrom2560x1080IsApproximately21By9() {
        let ratio = PlayerAspectRatioPolicy.ratio(from: CGSize(width: 2560, height: 1080))
        #expect(abs(ratio! - (21.0 / 9.0)) < 0.05)
    }

    @Test("640x480 resolves to approximately 4:3")
    func ratioFrom640x480IsApproximately4By3() {
        let ratio = PlayerAspectRatioPolicy.ratio(from: CGSize(width: 640, height: 480))
        #expect(abs(ratio! - (4.0 / 3.0)) < 0.0001)
    }

    @Test("Square size resolves to 1:1")
    func ratioFromSquareIsOne() {
        let ratio = PlayerAspectRatioPolicy.ratio(from: CGSize(width: 1000, height: 1000))
        #expect(ratio == 1.0)
    }

    @Test("Zero size returns nil")
    func ratioFromZeroSizeIsNil() {
        #expect(PlayerAspectRatioPolicy.ratio(from: .zero) == nil)
    }

    @Test("Zero width returns nil")
    func ratioFromZeroWidthIsNil() {
        #expect(PlayerAspectRatioPolicy.ratio(from: CGSize(width: 0, height: 1080)) == nil)
    }

    @Test("Zero height returns nil")
    func ratioFromZeroHeightIsNil() {
        #expect(PlayerAspectRatioPolicy.ratio(from: CGSize(width: 1920, height: 0)) == nil)
    }

    @Test("Negative width returns nil")
    func ratioFromNegativeWidthIsNil() {
        #expect(PlayerAspectRatioPolicy.ratio(from: CGSize(width: -1920, height: 1080)) == nil)
    }

    @Test("Negative height returns nil")
    func ratioFromNegativeHeightIsNil() {
        #expect(PlayerAspectRatioPolicy.ratio(from: CGSize(width: 1920, height: -1080)) == nil)
    }
}

// MARK: - Video Fitting Policy

@Suite("Video Fitting Policy")
struct VideoFittingPolicyTestsPlayerengineandfittingpolicytests {

    @Test("Wider container fits to height")
    func fittedSizeForWiderContainerFitsToHeight() {
        let container = CGSize(width: 2500, height: 1000)
        let ratio: CGFloat = 16.0 / 9.0
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: ratio)
        #expect(result.height == 1000)
        #expect(abs(result.width - (1000 * ratio)) < 0.01)
    }

    @Test("Taller container fits to width")
    func fittedSizeForTallerContainerFitsToWidth() {
        let container = CGSize(width: 1000, height: 1000)
        let ratio: CGFloat = 16.0 / 9.0
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: ratio)
        #expect(result.width == 1000)
        #expect(abs(result.height - (1000 / ratio)) < 0.01)
    }

    @Test("Perfect aspect ratio match uses full container")
    func fittedSizeForPerfectMatchUsesFullContainer() {
        let container = CGSize(width: 1920, height: 1080)
        let ratio: CGFloat = 1920.0 / 1080.0
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: ratio)
        #expect(abs(result.width - 1920) < 0.01)
        #expect(abs(result.height - 1080) < 0.01)
    }

    @Test("Zero height returns container size unchanged")
    func fittedSizeWithZeroHeightReturnsContainer() {
        let container = CGSize(width: 1920, height: 0)
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: 16.0 / 9.0)
        #expect(result == container)
    }

    @Test("Zero ratio returns container size unchanged")
    func fittedSizeWithZeroRatioReturnsContainer() {
        let container = CGSize(width: 1920, height: 1080)
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: 0)
        #expect(result == container)
    }

    @Test("21:9 video in 16:9 container fits to width")
    func fittedSizeFor21By9In16By9ContainerFitsToWidth() {
        let container = CGSize(width: 1920, height: 1080)
        let ratio: CGFloat = 21.0 / 9.0
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: ratio)
        #expect(result.width == 1920)
        #expect(abs(result.height - (1920 / ratio)) < 0.01)
    }

    @Test("4:3 video in 16:9 container fits to height")
    func fittedSizeFor4By3In16By9ContainerFitsToHeight() {
        let container = CGSize(width: 1920, height: 1080)
        let ratio: CGFloat = 4.0 / 3.0
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: ratio)
        #expect(result.height == 1080)
        #expect(abs(result.width - (1080 * ratio)) < 0.01)
    }
}

// MARK: - VPPlayerEngine State

@Suite("VPPlayerEngine State")
@MainActor
struct VPPlayerEngineStateTests {
    private let engine = VPPlayerEngine()

    // MARK: Playback Rate

    @Test("Playback rate cycles through expected values")
    func playbackRateCyclesThroughValues() {
        engine.playbackRate = 0.5
        engine.cycleRate()
        #expect(engine.playbackRate == 0.75)
        engine.cycleRate()
        #expect(engine.playbackRate == 1.0)
        engine.cycleRate()
        #expect(engine.playbackRate == 1.25)
        engine.cycleRate()
        #expect(engine.playbackRate == 1.5)
        engine.cycleRate()
        #expect(engine.playbackRate == 2.0)
    }

    @Test("Playback rate cycles from max back to min")
    func playbackRateCyclesFromMaxToMin() {
        engine.playbackRate = 2.0
        engine.cycleRate()
        #expect(engine.playbackRate == 0.5)
    }

    @Test("Playback rate unknown rate resets to 1.0")
    func playbackRateUnknownRateResetsToOne() {
        engine.playbackRate = 3.0
        engine.cycleRate()
        #expect(engine.playbackRate == 1.0)
    }

    @Test("Set rate updates playback rate directly")
    func setRateUpdatesPlaybackRate() {
        engine.setRate(1.5)
        #expect(engine.playbackRate == 1.5)
    }

    // MARK: Playback State

    @Test("Buffering state can be toggled")
    func bufferingStateCanBeToggled() {
        engine.isBuffering = true
        #expect(engine.isBuffering == true)
        engine.isBuffering = false
        #expect(engine.isBuffering == false)
    }

    @Test("Playing state can be toggled")
    func isPlayingStateCanBeToggled() {
        engine.isPlaying = false
        #expect(engine.isPlaying == false)
        engine.isPlaying = true
        #expect(engine.isPlaying == true)
    }

    @Test("Time update changes current time")
    func timeUpdateChangesCurrentTime() {
        engine.currentTime = 120.5
        #expect(engine.currentTime == 120.5)
    }

    @Test("Duration update changes duration")
    func durationUpdateChangesDuration() {
        engine.duration = 3600.0
        #expect(engine.duration == 3600.0)
    }

    // MARK: Spatial / Stereo Mode

    @Test("Update stereo mode sets mode from title")
    func updateStereoModeSetsStereoModeFromTitle() {
        engine.updateStereoMode(from: "movie.sbs.3d.mkv")
        #expect(engine.stereoMode == .sideBySide)

        engine.updateStereoMode(from: "movie.ou.mkv")
        #expect(engine.stereoMode == .overUnder)

        engine.updateStereoMode(from: "movie.180.vr.mp4")
        #expect(engine.stereoMode == .sphere180)

        engine.updateStereoMode(from: "movie.360.mp4")
        #expect(engine.stereoMode == .sphere360)
    }

    @Test("Update stereo mode with MV-HEVC codec hint")
    func updateStereoModeWithCodecHintSetsMvHevc() {
        engine.updateStereoMode(from: "movie.mov", codecHint: "mv-hevc")
        #expect(engine.stereoMode == .mvHevc)
    }

    @Test("Update stereo mode with compact MVHEVC codec hint")
    func updateStereoModeWithCompactCodecHintSetsMvHevc() {
        engine.updateStereoMode(from: "movie.mov", codecHint: "mvhevc")
        #expect(engine.stereoMode == .mvHevc)
    }

    @Test("is3DContent is true for non-mono modes")
    func is3DContentIsTrueForNonMono() {
        engine.stereoMode = .sideBySide
        #expect(engine.is3DContent == true)
        engine.stereoMode = .overUnder
        #expect(engine.is3DContent == true)
        engine.stereoMode = .mvHevc
        #expect(engine.is3DContent == true)
    }

    @Test("is3DContent is false for mono")
    func is3DContentIsFalseForMono() {
        engine.stereoMode = .mono
        #expect(engine.is3DContent == false)
    }

    // MARK: Reset

    @Test("Reset session state clears all properties")
    func resetSessionStateClearsAllProperties() {
        engine.currentTitle = "Test"
        engine.currentTime = 100
        engine.duration = 200
        engine.bufferedPercent = 50
        engine.isPlaying = true
        engine.isBuffering = false
        engine.audioTracks = [VPPlayerEngine.TrackInfo(id: 1, name: "English", language: "en", codec: "aac")]
        engine.subtitleTracks = [VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "srt")]
        engine.selectedAudioTrack = 1
        engine.selectedSubtitleTrack = 0
        engine.subtitlesEnabled = true
        engine.currentSubtitleText = "Hello"
        engine.videoSize = CGSize(width: 1920, height: 1080)
        engine.fps = 24
        engine.videoBitrate = 5000
        engine.stereoMode = .sideBySide
        engine.chapters = [VPPlayerEngine.ChapterInfo(id: 0, title: "Intro", startTime: 0, endTime: 60)]
        engine.error = "Some error"

        engine.resetSessionState()

        #expect(engine.currentTitle == nil)
        #expect(engine.currentTime == 0)
        #expect(engine.duration == 0)
        #expect(engine.bufferedPercent == 0)
        #expect(engine.isPlaying == false)
        #expect(engine.isBuffering == true)
        #expect(engine.audioTracks.isEmpty)
        #expect(engine.subtitleTracks.isEmpty)
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
    }

    // MARK: Progress

    @Test("Progress percent is zero when duration is zero")
    func progressPercentIsZeroWhenDurationIsZero() {
        engine.currentTime = 100
        engine.duration = 0
        #expect(engine.progressPercent == 0)
    }

    @Test("Progress percent calculates correctly")
    func progressPercentCalculatesCorrectly() {
        engine.currentTime = 30
        engine.duration = 120
        #expect(abs(engine.progressPercent - 0.25) < 0.001)
    }

    // MARK: Track Selection

    @Test("Select audio track updates index")
    func selectAudioTrackUpdatesIndex() {
        engine.selectAudioTrack(2)
        #expect(engine.selectedAudioTrack == 2)
    }

    // MARK: Chapter Navigation

    @Test("Current chapter returns correct chapter")
    func currentChapterReturnsCorrectChapter() {
        let chapters = [
            VPPlayerEngine.ChapterInfo(id: 0, title: "Intro", startTime: 0, endTime: 60),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Act 1", startTime: 60, endTime: 120),
            VPPlayerEngine.ChapterInfo(id: 2, title: "Act 2", startTime: 120, endTime: 180)
        ]
        engine.loadChapters(chapters)
        engine.currentTime = 90

        let chapter = engine.currentChapter(at: 90)
        #expect(chapter?.title == "Act 1")
    }

    @Test("Next chapter time returns correct value")
    func nextChapterTimeReturnsCorrectValue() {
        let chapters = [
            VPPlayerEngine.ChapterInfo(id: 0, title: "Intro", startTime: 0, endTime: 60),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Act 1", startTime: 60, endTime: 120)
        ]
        engine.loadChapters(chapters)
        engine.currentTime = 30

        #expect(engine.nextChapterTime() == 60)
    }

    @Test("Next chapter time returns nil when past last chapter")
    func nextChapterTimeReturnsNilWhenPastLast() {
        let chapters = [
            VPPlayerEngine.ChapterInfo(id: 0, title: "Intro", startTime: 0, endTime: 60)
        ]
        engine.loadChapters(chapters)
        engine.currentTime = 90

        #expect(engine.nextChapterTime() == nil)
    }

    @Test("Previous chapter time restarts current chapter when more than 3 seconds in")
    func previousChapterTimeRestartsCurrentChapter() {
        let chapters = [
            VPPlayerEngine.ChapterInfo(id: 0, title: "Intro", startTime: 0, endTime: 60),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Act 1", startTime: 60, endTime: 120)
        ]
        engine.loadChapters(chapters)
        engine.currentTime = 65

        #expect(engine.previousChapterTime() == 60)
    }

    @Test("Previous chapter time goes to previous chapter when less than 3 seconds in")
    func previousChapterTimeGoesToPreviousChapter() {
        let chapters = [
            VPPlayerEngine.ChapterInfo(id: 0, title: "Intro", startTime: 0, endTime: 60),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Act 1", startTime: 60, endTime: 120)
        ]
        engine.loadChapters(chapters)
        engine.currentTime = 61

        #expect(engine.previousChapterTime() == 0)
    }

    @Test("Previous chapter time returns nil when before any chapter")
    func previousChapterTimeReturnsNilBeforeAnyChapter() {
        let chapters = [
            VPPlayerEngine.ChapterInfo(id: 0, title: "Intro", startTime: 60, endTime: 120)
        ]
        engine.loadChapters(chapters)
        engine.currentTime = 30

        #expect(engine.previousChapterTime() == nil)
    }

    // MARK: Volume

    @Test("Volume can be mutated")
    func volumeCanBeMutated() {
        engine.volume = 0.5
        #expect(engine.volume == 0.5)
    }

    // MARK: Video Info

    @Test("Video size can be mutated")
    func videoSizeCanBeMutated() {
        engine.videoSize = CGSize(width: 1920, height: 1080)
        #expect(engine.videoSize.width == 1920)
        #expect(engine.videoSize.height == 1080)
    }

    @Test("FPS can be mutated")
    func fpsCanBeMutated() {
        engine.fps = 60.0
        #expect(engine.fps == 60.0)
    }

    // MARK: Formatted Times

    @Test("Formatted time produces expected strings")
    func formattedTimeProducesExpectedStrings() {
        engine.currentTime = 3661 // 1h 1m 1s
        engine.duration = 7200    // 2h
        #expect(engine.currentTimeFormatted == "1:01:01")
        #expect(engine.durationFormatted == "2:00:00")
        #expect(engine.remainingFormatted == "58:59")
    }

    // MARK: Dim Passthrough

    @Test("Dim enabled defaults to true and can be toggled")
    func dimEnabledDefaultsToTrueAndCanBeToggled() {
        #expect(engine.isDimEnabled == true)
        engine.isDimEnabled = false
        #expect(engine.isDimEnabled == false)
    }
}
