#if canImport(UIKit)
import AVFoundation
import AVKit
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("Player Platform Views")
struct PlayerPlatformViewVisionTests {
    #if os(visionOS)
    @Test func avPlayerSurfaceUsesLayerBackedViewForStableWindowPlayback() throws {
        let player = AVPlayer()
        let hostedSurface = try hostInVisibleWindow(
            AVPlayerSurfaceView(player: player, videoGravity: .resizeAspect)
        )
        let host = hostedSurface.host
        let window = hostedSurface.window
        defer { tearDownWindow(window) }

        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        let surface = try #require(host.view.firstSubview(ofType: AVPlayerSurfaceUIView.self))
        #expect(surface.layer is AVPlayerLayer)
        #expect(surface.player === player)
        #expect(surface.playerLayer.videoGravity == .resizeAspect)
        #expect(surface.backgroundColor == .black)
        #expect(surface.isOpaque)
    }

    @Test func avPlayerSurfaceCanUseTransparentBackgroundForAppleEnvironment() throws {
        let player = AVPlayer()
        let hostedSurface = try hostInVisibleWindow(
            AVPlayerSurfaceView(
                player: player,
                videoGravity: .resizeAspect,
                allowsTransparentBackground: true
            )
        )
        let host = hostedSurface.host
        let window = hostedSurface.window
        defer { tearDownWindow(window) }

        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        let surface = try #require(host.view.firstSubview(ofType: AVPlayerSurfaceUIView.self))
        #expect(surface.player === player)
        #expect(surface.playerLayer.videoGravity == .resizeAspect)
        #expect(surface.backgroundColor == .clear)
        #expect(surface.isOpaque == false)
    }

    @Test func transparentAppleEnvironmentSurfaceClearsNestedPlayerViews() {
        let container = UIView()
        container.backgroundColor = .black
        container.isOpaque = true

        let nestedSurface = UIView()
        nestedSurface.backgroundColor = .black
        nestedSurface.isOpaque = true
        container.addSubview(nestedSurface)

        AVPlayerSurfaceView.applyTransparentBackground(to: container, enabled: true)

        #expect(container.backgroundColor == .clear)
        #expect(container.isOpaque == false)
        #expect(nestedSurface.backgroundColor == .clear)
        #expect(nestedSurface.isOpaque == false)
    }

    @Test func normalAppleEnvironmentSurfaceRestoresNestedPlayerViews() {
        let container = UIView()
        container.backgroundColor = .clear
        container.isOpaque = false

        let nestedSurface = UIView()
        nestedSurface.backgroundColor = .clear
        nestedSurface.isOpaque = false
        container.addSubview(nestedSurface)

        AVPlayerSurfaceView.applyTransparentBackground(to: container, enabled: false)

        #expect(container.backgroundColor == .black)
        #expect(container.isOpaque)
        #expect(nestedSurface.backgroundColor == .black)
        #expect(nestedSurface.isOpaque)
    }

    @Test func avPlayerSurfaceDismantleClearsPlayer() {
        let view = AVPlayerSurfaceUIView()
        let player = AVPlayer()
        view.player = player

        AVPlayerSurfaceView.dismantleUIView(view, coordinator: ())

        #expect(view.player == nil)
    }

    @Test func defaultSurfaceViewUsesResizeAspectFill() throws {
        let player = AVPlayer()
        let hostedSurface = try hostInVisibleWindow(AVPlayerSurfaceView(player: player))
        let host = hostedSurface.host
        let window = hostedSurface.window
        defer { tearDownWindow(window) }

        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        let surface = try #require(host.view.firstSubview(ofType: AVPlayerSurfaceUIView.self))
        #expect(surface.player === player)
        #expect(surface.playerLayer.videoGravity == .resizeAspectFill)
    }

    @Test func hostedAVPlayerSurfaceUpdatesConfiguredLayerBackedView() throws {
        let originalPlayer = AVPlayer()
        let replacementPlayer = AVPlayer()
        let hostedSurface = try hostInVisibleWindow(
            AVPlayerSurfaceView(player: originalPlayer, videoGravity: .resizeAspect)
        )
        let host = hostedSurface.host
        let window = hostedSurface.window
        defer { tearDownWindow(window) }

        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        host.rootView = AVPlayerSurfaceView(player: replacementPlayer, videoGravity: .resizeAspectFill)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        let surface = try #require(host.view.firstSubview(ofType: AVPlayerSurfaceUIView.self))
        #expect(surface.player === replacementPlayer)
        #expect(surface.playerLayer.videoGravity == .resizeAspectFill)
        #expect(surface.backgroundColor == .black)
        #expect(surface.isOpaque)
    }
    #else
    @Test func avPlayerSurfaceUIViewUsesAVPlayerLayerAndStoresPlayer() {
        let view = AVPlayerSurfaceUIView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        let player = AVPlayer()

        #expect(view.layer is AVPlayerLayer)

        view.player = player
        view.playerLayer.videoGravity = .resizeAspect

        #expect(view.player === player)
        #expect(view.playerLayer.player === player)
        #expect(view.playerLayer.videoGravity == .resizeAspect)

        view.player = nil
        #expect(view.player == nil)
    }

    @Test func avPlayerSurfaceRepresentableDismantleClearsPlayer() {
        let view = AVPlayerSurfaceUIView()
        let player = AVPlayer()
        view.player = player

        AVPlayerSurfaceView.dismantleUIView(view, coordinator: ())

        #expect(view.player == nil)
    }

    @Test func hostedAVPlayerSurfaceCreatesConfiguredUIKitView() throws {
        let player = AVPlayer()
        let hostedSurface = try hostInVisibleWindow(
            AVPlayerSurfaceView(player: player, videoGravity: .resizeAspect)
        )
        let host = hostedSurface.host
        let window = hostedSurface.window
        defer { tearDownWindow(window) }

        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let surface = host.view.firstSubview(ofType: AVPlayerSurfaceUIView.self)
        #expect(surface?.player === player)
        #expect(surface?.playerLayer.videoGravity == .resizeAspect)
    }

    @Test func defaultSurfaceViewUsesResizeAspectFill() throws {
        let player = AVPlayer()
        let hostedSurface = try hostInVisibleWindow(AVPlayerSurfaceView(player: player))
        let host = hostedSurface.host
        let window = hostedSurface.window
        defer { tearDownWindow(window) }

        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let surface = host.view.firstSubview(ofType: AVPlayerSurfaceUIView.self)
        #expect(surface?.player === player)
        #expect(surface?.playerLayer.videoGravity == .resizeAspectFill)
    }

    @Test func hostedAVPlayerSurfaceUpdatesConfiguredUIKitView() throws {
        let originalPlayer = AVPlayer()
        let replacementPlayer = AVPlayer()
        let hostedSurface = try hostInVisibleWindow(
            AVPlayerSurfaceView(player: originalPlayer, videoGravity: .resizeAspect)
        )
        let host = hostedSurface.host
        let window = hostedSurface.window
        defer { tearDownWindow(window) }

        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        host.rootView = AVPlayerSurfaceView(player: replacementPlayer, videoGravity: .resizeAspectFill)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let surface = host.view.firstSubview(ofType: AVPlayerSurfaceUIView.self)
        #expect(surface?.player === replacementPlayer)
        #expect(surface?.playerLayer.videoGravity == .resizeAspectFill)
    }
    #endif

    @Test func apmpDisplayViewInstallsReplacesLaysOutAndClearsDisplayLayer() {
        let view = APMPDisplayView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        let firstLayer = AVSampleBufferDisplayLayer()
        let secondLayer = AVSampleBufferDisplayLayer()

        view.setDisplayLayer(firstLayer)

        #expect(firstLayer.superlayer === view.layer)
        #expect(firstLayer.frame == view.bounds)
        #expect(firstLayer.videoGravity == .resizeAspect)

        view.bounds = CGRect(x: 0, y: 0, width: 640, height: 360)
        view.layoutSubviews()
        #expect(firstLayer.frame == view.bounds)

        view.setDisplayLayer(secondLayer)
        #expect(firstLayer.superlayer == nil)
        #expect(secondLayer.superlayer === view.layer)

        view.setDisplayLayer(secondLayer)
        let hostedCount = view.layer.sublayers?.filter { $0 === secondLayer }.count ?? 0
        #expect(hostedCount == 1)

        view.clearDisplayLayer()
        #expect(secondLayer.superlayer == nil)
    }

    @Test func hostedAPMPRendererCreatesConfiguredDisplayView() throws {
        let displayLayer = AVSampleBufferDisplayLayer()
        let hostedRenderer = try hostInVisibleWindow(APMPRendererView(displayLayer: displayLayer))
        let host = hostedRenderer.host
        let window = hostedRenderer.window
        defer { tearDownWindow(window) }

        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let displayView = try #require(host.view.firstSubview(ofType: APMPDisplayView.self))
        #expect(displayLayer.superlayer === displayView.layer)
        #expect(displayLayer.videoGravity == .resizeAspect)
    }

    @Test func hostedAPMPRendererUpdatesDisplayLayer() throws {
        let firstLayer = AVSampleBufferDisplayLayer()
        let secondLayer = AVSampleBufferDisplayLayer()
        let hostedRenderer = try hostInVisibleWindow(APMPRendererView(displayLayer: firstLayer))
        let host = hostedRenderer.host
        let window = hostedRenderer.window
        defer { tearDownWindow(window) }

        host.rootView = APMPRendererView(displayLayer: secondLayer)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let displayView = try #require(host.view.firstSubview(ofType: APMPDisplayView.self))
        #expect(firstLayer.superlayer == nil)
        #expect(secondLayer.superlayer === displayView.layer)
    }

    @Test func apmpRendererDismantleClearsDisplayLayer() {
        let view = APMPDisplayView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        let displayLayer = AVSampleBufferDisplayLayer()
        view.setDisplayLayer(displayLayer)

        APMPRendererView.dismantleUIView(view, coordinator: ())

        #expect(displayLayer.superlayer == nil)
    }

    @Test func windowSceneObservingViewReportsNilWhenDetached() async {
        let view = WindowSceneObservingView()
        var callbackScene: UIWindowScene?
        var didCallCallback = false
        view.onSceneChange = { scene in
            callbackScene = scene
            didCallCallback = true
        }

        view.didMoveToWindow()

        #expect(!didCallCallback)
        await Task.yield()
        await Task.yield()

        #expect(didCallCallback)
        #expect(callbackScene == nil)
    }

    @Test func windowSceneObservingViewAllowsCallbackToBeCleared() {
        let view = WindowSceneObservingView()
        view.onSceneChange = nil

        view.didMoveToWindow()
    }

    #if os(visionOS)
    @Test func playerEnvironmentMenuHostsWithActiveCinemaAndAssets() throws {
        let appState = AppState()
        appState.isImmersiveSpaceOpen = true
        appState.activeEnvironment = .cinemaEnvironment
        appState.selectedEnvironmentAsset = Self.importedEnvironmentAsset

        let hostedMenu = try hostInVisibleWindow(
            PlayerEnvironmentMenu(
                assets: [Self.activeBundledEnvironmentAsset, Self.importedEnvironmentAsset],
                onSelectCinema: {},
                onSelect: { _ in },
                onDismiss: {}
            )
            .environment(appState)
        )
        let window = hostedMenu.window
        defer { tearDownWindow(window) }

        hostedMenu.host.view.setNeedsLayout()
        hostedMenu.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(hostedMenu.host.view.bounds.size == CGSize(width: 320, height: 180))
        #expect(hostedMenu.host.view.subviews.isEmpty == false)
    }

    @Test func playerEnvironmentButtonHostsWithEmptyAndInactiveStates() throws {
        let appState = AppState()
        appState.isImmersiveSpaceOpen = false
        appState.activeEnvironment = nil
        appState.selectedEnvironmentAsset = nil

        let hostedButton = try hostInVisibleWindow(
            PlayerEnvironmentButton(
                assets: [],
                onSelectCinema: {},
                onSelect: { _ in },
                onDismiss: {}
            )
            .environment(appState)
        )
        let window = hostedButton.window
        defer { tearDownWindow(window) }

        hostedButton.host.view.setNeedsLayout()
        hostedButton.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(hostedButton.host.view.bounds.size == CGSize(width: 320, height: 180))
        #expect(hostedButton.host.view.subviews.isEmpty == false)
    }

    @Test func playerEnvironmentMenuHostsWithoutImmersiveDismissBranch() throws {
        let appState = AppState()
        appState.isImmersiveSpaceOpen = false
        appState.activeEnvironment = nil
        appState.selectedEnvironmentAsset = nil

        let hostedMenu = try hostInVisibleWindow(
            PlayerEnvironmentMenu(
                assets: [Self.importedEnvironmentAsset],
                onSelectCinema: {},
                onSelect: { _ in },
                onDismiss: {}
            )
            .environment(appState)
        )
        let window = hostedMenu.window
        defer { tearDownWindow(window) }

        hostedMenu.host.view.setNeedsLayout()
        hostedMenu.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(hostedMenu.host.view.bounds.size == CGSize(width: 320, height: 180))
        #expect(hostedMenu.host.view.subviews.isEmpty == false)
    }

    @Test func playerEnvironmentButtonHostsWithSelectedAssetAndImmersiveState() throws {
        let appState = AppState()
        appState.isImmersiveSpaceOpen = true
        appState.activeEnvironment = .customEnvironment
        appState.selectedEnvironmentAsset = Self.importedEnvironmentAsset

        let hostedButton = try hostInVisibleWindow(
            PlayerEnvironmentButton(
                assets: [Self.importedEnvironmentAsset, Self.activeBundledEnvironmentAsset],
                onSelectCinema: {},
                onSelect: { _ in },
                onDismiss: {}
            )
            .environment(appState)
        )
        let window = hostedButton.window
        defer { tearDownWindow(window) }

        hostedButton.host.view.setNeedsLayout()
        hostedButton.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(hostedButton.host.view.bounds.size == CGSize(width: 320, height: 180))
        #expect(hostedButton.host.view.subviews.isEmpty == false)
    }

    @Test func startupOverlayHostsFailureLoadingAndRebufferVariants() throws {
        let overlays: [(String, PlayerStartupStateOverlayView)] = [
            (
                "failure with retry choices",
                PlayerStartupStateOverlayView(
                    playbackState: .failed,
                    title: "Playback Failed",
                    message: "The selected stream stopped responding.",
                    hasPlayedOnce: true,
                    hasNextStream: true,
                    onRetry: {},
                    onTryNextStream: {}
                )
            ),
            (
                "initial loading",
                PlayerStartupStateOverlayView(
                    playbackState: .preparing,
                    title: "Preparing Playback",
                    message: "Opening stream",
                    hasPlayedOnce: false,
                    hasNextStream: false,
                    onRetry: {},
                    onTryNextStream: {}
                )
            ),
            (
                "inline rebuffer",
                PlayerStartupStateOverlayView(
                    playbackState: .buffering,
                    title: "Buffering",
                    message: "Rebuffering...",
                    hasPlayedOnce: true,
                    hasNextStream: false,
                    onRetry: {},
                    onTryNextStream: {}
                )
            ),
        ]

        for (name, overlay) in overlays {
            let hostedOverlay = try hostInVisibleWindow(overlay)
            let window = hostedOverlay.window

            hostedOverlay.host.view.setNeedsLayout()
            hostedOverlay.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            #expect(hostedOverlay.host.view.bounds.size == CGSize(width: 320, height: 180), "\(name) should lay out")
            #expect(hostedOverlay.host.view.window === window, "\(name) should attach to the visible test window")
            #expect(hostedOverlay.host.view.isHidden == false, "\(name) should keep the hosted view visible")
            #expect(hostedOverlay.host.view.alpha > 0, "\(name) should keep the hosted view opaque")
            tearDownWindow(window)
        }
    }

    @Test func playerViewHostsStartupOverlayVariantsWithoutAutomaticPlayback() throws {
        let primaryStream = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/player-startup-overlay-1080p.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Player.Startup.1080p.mp4",
            sizeBytes: 3_000_000_000,
            debridService: "fixture"
        )
        let fallbackStream = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/player-startup-overlay-720p.mp4")!,
            quality: .hd720p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Player.Startup.720p.mp4",
            sizeBytes: 1_500_000_000,
            debridService: "fixture"
        )

        func makeView(
            playbackState: PlayerPlaybackState,
            playbackMessage: String?,
            playbackError: String?
        ) -> some View {
            PlayerView(
                stream: primaryStream,
                availableStreams: [primaryStream, fallbackStream],
                mediaTitle: "Startup Coverage",
                mediaId: "startup-coverage",
                episodeId: nil,
                sessionID: UUID(),
                initialPlaybackState: playbackState,
                initialPlaybackMessage: playbackMessage,
                initialPlaybackError: playbackError,
                initialActiveEngine: .avPlayer,
                initialEnvironmentAssets: [Self.importedEnvironmentAsset],
                disablesAutomaticTasks: true
            )
            .environment(AppState(testHooks: .init()))
            .environment(VPPlayerEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 920, height: 560)
        }

        let views: [(String, AnyView)] = [
            (
                "preparing player view",
                AnyView(makeView(
                    playbackState: .preparing,
                    playbackMessage: "Opening stream",
                    playbackError: nil
                ))
            ),
            (
                "failed player view",
                AnyView(makeView(
                    playbackState: .failed,
                    playbackMessage: "Use retry or try the next stream.",
                    playbackError: "The selected stream stopped responding."
                ))
            ),
            (
                "buffering player view",
                AnyView(makeView(
                    playbackState: .buffering,
                    playbackMessage: "Buffering…",
                    playbackError: nil
                ))
            ),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleWindow(view)
            let window = hosted.window

            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a host subtree")
            tearDownWindow(window)
        }
    }

    @Test func playerViewHostsPremiumControlsAutoplaySubtitlesAndAudioBranches() throws {
        let subtitleFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vpstudio-player-coverage-\(UUID().uuidString).srt")
        try """
        1
        00:00:01,000 --> 00:00:04,000
        The signal is clean from the direct link.

        """.write(to: subtitleFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: subtitleFileURL) }

        let stream = Self.coverageStream(
            url: "https://cdn.example.com/vision-qa-feature-2160p-sbs.mkv",
            fileName: "Vision.QA.Feature.3D.SBS.2160p.mkv",
            quality: .uhd4k
        )
        let fallback = Self.coverageStream(
            url: "https://cdn.example.com/vision-qa-feature-1080p.mkv",
            fileName: "Vision.QA.Feature.1080p.mkv",
            quality: .hd1080p
        )
        let nextEpisode = PlayerSessionRequest.NextEpisodeCandidate(
            episodeId: "series-1-episode-2",
            seasonNumber: 1,
            episodeNumber: 2,
            title: "Premium Controls Follow-up"
        )
        let appState = AppState(testHooks: .init())
        appState.isImmersiveSpaceOpen = true
        appState.activeEnvironment = .customEnvironment
        appState.selectedEnvironmentAsset = Self.importedEnvironmentAsset

        let engine = Self.coverageEngine(subtitleFileURL: subtitleFileURL)
        let view = PlayerView(
            stream: stream,
            availableStreams: [stream, fallback],
            mediaTitle: "Vision QA Feature",
            mediaId: "tt1234567",
            episodeId: "series-1-episode-1",
            nextEpisode: nextEpisode,
            sessionID: UUID(),
            initialPlaybackState: .playing,
            initialPlaybackMessage: "Direct link ready",
            initialPlaybackError: nil,
            initialActiveEngine: .ksPlayer,
            initialIsShowingControls: true,
            initialSubtitleFontSize: 30,
            initialCapabilityWarnings: ["HDR metadata unavailable; using SDR presentation."],
            initialEnvironmentAssets: [Self.activeBundledEnvironmentAsset, Self.importedEnvironmentAsset],
            initialSubtitleCandidates: [Self.coverageSubtitleCandidate],
            initialSubtitleCatalogMessage: "1 subtitle match",
            initialIsShowingAutoPlayNextPrompt: true,
            initialIsResolvingAutoPlayNextEpisode: false,
            initialAutoPlayNextCountdownRemaining: 4,
            initialAspectRatioSelection: .twentyOneByNine,
            disablesAutomaticTasks: true
        )
        .environment(appState)
        .environment(engine)
        .environment(CinemaSettings(loadPersisted: false))
        .frame(width: 980, height: 620)

        let hosted = try hostInVisibleWindow(AnyView(view), size: CGSize(width: 980, height: 620))
        let window = hosted.window
        defer { tearDownWindow(window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        #expect(engine.currentSubtitleText == "The signal is clean from the direct link.")
        #expect(engine.selectedAudioTrack == 1)
        #expect(engine.chapters.count == 3)
        #expect(hosted.host.view.bounds.size == CGSize(width: 980, height: 620))
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test func playerViewHostsSubtitleAndAudioPickerSheetStatesWithoutPlaybackTasks() throws {
        let subtitleFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vpstudio-player-sheet-coverage-\(UUID().uuidString).srt")
        try """
        1
        00:00:01,000 --> 00:00:05,000
        Subtitle sheet coverage.

        """.write(to: subtitleFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: subtitleFileURL) }

        let stream = Self.coverageStream(
            url: "https://cdn.example.com/sheet-coverage-1080p.mkv",
            fileName: "Sheet.Coverage.1080p.mkv",
            quality: .hd1080p
        )

        let sheetVariants: [(String, AnyView)] = [
            (
                "subtitle direct link tracks",
                AnyView(
                    Self.playerSheetCoverageView(
                        stream: stream,
                        engine: Self.coverageEngine(subtitleFileURL: subtitleFileURL),
                        isShowingSubtitlePicker: true,
                        isShowingAudioPicker: false,
                        subtitleCandidates: [],
                        subtitleCatalogMessage: "Direct link subtitle tracks",
                        isRefreshingSubtitleCatalog: false,
                        isDownloadingSubtitle: false,
                        ksSubtitleOptions: [
                            VPPlayerEngine.TrackInfo(id: 4, name: "English Forced", language: "en", codec: "srt"),
                            VPPlayerEngine.TrackInfo(id: 5, name: "French SDH", language: "fr", codec: "vtt"),
                        ]
                    )
                )
            ),
            (
                "subtitle candidates",
                AnyView(
                    Self.playerSheetCoverageView(
                        stream: stream,
                        engine: Self.coverageEngine(subtitleFileURL: subtitleFileURL),
                        isShowingSubtitlePicker: true,
                        isShowingAudioPicker: false,
                        subtitleCandidates: [Self.coverageSubtitleCandidate],
                        subtitleCatalogMessage: nil,
                        isRefreshingSubtitleCatalog: false,
                        isDownloadingSubtitle: false
                    )
                )
            ),
            (
                "subtitle busy state",
                AnyView(
                    Self.playerSheetCoverageView(
                        stream: stream,
                        engine: Self.coverageEngine(subtitleFileURL: subtitleFileURL),
                        isShowingSubtitlePicker: true,
                        isShowingAudioPicker: false,
                        subtitleCandidates: [],
                        subtitleCatalogMessage: "Searching OpenSubtitles",
                        isRefreshingSubtitleCatalog: true,
                        isDownloadingSubtitle: true
                    )
                )
            ),
            (
                "audio direct link tracks",
                AnyView(
                    Self.playerSheetCoverageView(
                        stream: stream,
                        engine: Self.coverageEngine(subtitleFileURL: subtitleFileURL),
                        isShowingSubtitlePicker: false,
                        isShowingAudioPicker: true,
                        subtitleCandidates: [],
                        subtitleCatalogMessage: nil,
                        isRefreshingSubtitleCatalog: false,
                        isDownloadingSubtitle: false
                    )
                )
            ),
            (
                "audio empty state",
                AnyView(
                    Self.playerSheetCoverageView(
                        stream: stream,
                        engine: VPPlayerEngine(),
                        isShowingSubtitlePicker: false,
                        isShowingAudioPicker: true,
                        subtitleCandidates: [],
                        subtitleCatalogMessage: nil,
                        isRefreshingSubtitleCatalog: false,
                        isDownloadingSubtitle: false
                    )
                )
            ),
        ]

        for (name, view) in sheetVariants {
            let hosted = try hostInVisibleWindow(view, size: CGSize(width: 760, height: 520))
            let window = hosted.window

            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.16))

            #expect(hosted.host.view.bounds.size == CGSize(width: 760, height: 520), "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a host subtree")
            tearDownWindow(window)
        }
    }

    @Test func playerViewHostsEnvironmentAndCinemaSheetsWithoutPlaybackTasks() throws {
        let stream = Self.coverageStream(
            url: "https://cdn.example.com/environment-sheet-coverage-2160p.mkv",
            fileName: "Environment.Sheet.Coverage.2160p.mkv",
            quality: .uhd4k
        )

        func makeView(
            isShowingEnvironmentPicker: Bool,
            isShowingCinemaSettings: Bool
        ) -> some View {
            let appState = AppState(testHooks: .init())
            appState.isImmersiveSpaceOpen = true
            appState.activeEnvironment = .customEnvironment
            appState.selectedEnvironmentAsset = Self.importedEnvironmentAsset

            return PlayerView(
                stream: stream,
                availableStreams: [stream],
                mediaTitle: "Environment Sheet Coverage",
                mediaId: "tt9988776",
                episodeId: nil,
                sessionID: UUID(),
                initialPlaybackState: .playing,
                initialPlaybackMessage: "Environment controls ready",
                initialPlaybackError: nil,
                initialActiveEngine: .avPlayer,
                initialIsShowingControls: true,
                initialIsShowingEnvironmentPicker: isShowingEnvironmentPicker,
                initialIsShowingCinemaSettings: isShowingCinemaSettings,
                initialEnvironmentAssets: [
                    Self.activeBundledEnvironmentAsset,
                    Self.importedEnvironmentAsset,
                ],
                disablesAutomaticTasks: true
            )
            .environment(appState)
            .environment(Self.coverageEngine(subtitleFileURL: nil))
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 820, height: 560)
        }

        let sheetVariants: [(String, AnyView)] = [
            (
                "environment picker sheet",
                AnyView(makeView(isShowingEnvironmentPicker: true, isShowingCinemaSettings: false))
            ),
            (
                "cinema settings sheet",
                AnyView(makeView(isShowingEnvironmentPicker: false, isShowingCinemaSettings: true))
            ),
        ]

        for (name, view) in sheetVariants {
            let hosted = try hostInVisibleWindow(view, size: CGSize(width: 820, height: 560))
            let window = hosted.window

            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.16))

            #expect(hosted.host.view.bounds.size == CGSize(width: 820, height: 560), "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a host subtree")
            tearDownWindow(window)
        }
    }

    private static func coverageStream(
        url: String,
        fileName: String,
        quality: VideoQuality
    ) -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: url)!,
            quality: quality,
            codec: .h265,
            audio: .atmos,
            source: .webDL,
            hdr: .hdr10,
            fileName: fileName,
            sizeBytes: 7_500_000_000,
            debridService: "fixture",
            recoveryContext: StreamRecoveryContext(
                infoHash: "abcdef1234567890abcdef1234567890abcdef12",
                preferredService: .realDebrid,
                seasonNumber: 1,
                episodeNumber: 1,
                torrentId: "fixture-transfer"
            )
        )
    }

    private static func coverageEngine(subtitleFileURL: URL) -> VPPlayerEngine {
        let engine = VPPlayerEngine()
        engine.currentTitle = "Vision QA Feature"
        engine.isPlaying = true
        engine.isBuffering = false
        engine.currentTime = 2
        engine.duration = 7_200
        engine.bufferedPercent = 0.72
        engine.setRate(1.25)
        engine.videoSize = CGSize(width: 3840, height: 1606)
        engine.fps = 23.976
        engine.videoBitrate = 42_000_000
        engine.updateStereoMode(from: "Vision.QA.Feature.3D.SBS.2160p.mkv")
        engine.loadAudioTracks(
            [
                VPPlayerEngine.TrackInfo(id: 0, name: "English 5.1", language: "en", codec: "aac"),
                VPPlayerEngine.TrackInfo(id: 1, name: "English Atmos", language: "en", codec: "eac3"),
            ],
            selectedTrackID: 1
        )
        engine.loadChapters([
            VPPlayerEngine.ChapterInfo(id: 1, title: "Opening", startTime: 0, endTime: 420),
            VPPlayerEngine.ChapterInfo(id: 2, title: "Midpoint", startTime: 3_600, endTime: 4_200),
            VPPlayerEngine.ChapterInfo(id: 3, title: "Finale", startTime: 6_900, endTime: 7_200),
        ])
        engine.loadExternalSubtitles([
            Subtitle(
                id: "local-subtitle",
                language: "en",
                fileName: "Vision.QA.Feature.en.srt",
                url: subtitleFileURL.absoluteString,
                format: .srt,
                fileId: 42,
                rating: 9.4,
                downloadCount: 12_000,
                isHearingImpaired: false,
                source: "Fixture"
            ),
        ])
        engine.selectSubtitleTrack(0)
        engine.updateSubtitleText(at: 2)
        return engine
    }

    private static func coverageEngine(subtitleFileURL: URL?) -> VPPlayerEngine {
        guard let subtitleFileURL else {
            let engine = VPPlayerEngine()
            engine.currentTitle = "Environment Sheet Coverage"
            engine.isPlaying = true
            engine.currentTime = 64
            engine.duration = 7_200
            engine.bufferedPercent = 0.5
            engine.loadAudioTracks([
                VPPlayerEngine.TrackInfo(id: 0, name: "Main Mix", language: "en", codec: "aac"),
            ])
            return engine
        }
        return coverageEngine(subtitleFileURL: subtitleFileURL)
    }

    private static func playerSheetCoverageView(
        stream: StreamInfo,
        engine: VPPlayerEngine,
        isShowingSubtitlePicker: Bool,
        isShowingAudioPicker: Bool,
        subtitleCandidates: [Subtitle],
        subtitleCatalogMessage: String?,
        isRefreshingSubtitleCatalog: Bool,
        isDownloadingSubtitle: Bool,
        ksSubtitleOptions: [VPPlayerEngine.TrackInfo] = []
    ) -> some View {
        PlayerView(
            stream: stream,
            availableStreams: [stream],
            mediaTitle: "Sheet Coverage",
            mediaId: "tt7654321",
            episodeId: nil,
            sessionID: UUID(),
            initialPlaybackState: .playing,
            initialPlaybackMessage: "Track metadata ready",
            initialPlaybackError: nil,
            initialActiveEngine: .ksPlayer,
            initialIsShowingControls: true,
            initialIsShowingSubtitlePicker: isShowingSubtitlePicker,
            initialIsShowingAudioPicker: isShowingAudioPicker,
            initialSubtitleCandidates: subtitleCandidates,
            initialSubtitleCatalogMessage: subtitleCatalogMessage,
            initialIsRefreshingSubtitleCatalog: isRefreshingSubtitleCatalog,
            initialIsDownloadingSubtitle: isDownloadingSubtitle,
            initialKSSubtitleOptions: ksSubtitleOptions,
            initialSelectedKSSubtitleID: ksSubtitleOptions.first.map { String($0.id) },
            disablesAutomaticTasks: true
        )
        .environment(AppState(testHooks: .init()))
        .environment(engine)
        .environment(CinemaSettings(loadPersisted: false))
        .frame(width: 760, height: 520)
    }

    private static var coverageSubtitleCandidate: Subtitle {
        Subtitle(
            id: "open-subtitles-candidate",
            language: "en",
            fileName: "Vision.QA.Feature.OpenSubtitles.en.srt",
            url: "https://subtitles.example.com/vision-qa-feature.srt",
            format: .srt,
            fileId: 99,
            rating: 8.7,
            downloadCount: 55_000,
            isHearingImpaired: true,
            source: "OpenSubtitles"
        )
    }

    private static var activeBundledEnvironmentAsset: EnvironmentAsset {
        EnvironmentAsset(
            id: "bundled-cinema",
            name: "Bundled Cinema",
            sourceType: .bundled,
            assetPath: "bundle://cinema.usdz",
            isActive: true
        )
    }

    private static var importedEnvironmentAsset: EnvironmentAsset {
        EnvironmentAsset(
            id: "imported-sky",
            name: "Imported Sky",
            sourceType: .imported,
            assetPath: "/tmp/imported-sky.hdr",
            isActive: false
        )
    }
    #endif
}

private extension UIView {
    func firstSubview<T: UIView>(ofType type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }

        for subview in subviews {
            if let match = subview.firstSubview(ofType: type) {
                return match
            }
        }

        return nil
    }
}

private extension UIViewController {
    func firstChildController<T: UIViewController>(ofType type: T.Type) -> T? {
        if let controller = self as? T {
            return controller
        }

        for child in children {
            if let match = child.firstChildController(ofType: type) {
                return match
            }
        }

        return presentedViewController?.firstChildController(ofType: type)
    }
}

@MainActor
private func hostInVisibleWindow<Content: View>(
    _ rootView: Content,
    size: CGSize = CGSize(width: 320, height: 180)
) throws -> (host: UIHostingController<Content>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let host = UIHostingController(rootView: rootView)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(origin: .zero, size: size)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return (host, window)
}

@MainActor
private func tearDownWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    PlayerPlatformWindowRetainer.windows.append(window)
}

@MainActor
private enum PlayerPlatformWindowRetainer {
    static var windows: [UIWindow] = []
}
#endif
