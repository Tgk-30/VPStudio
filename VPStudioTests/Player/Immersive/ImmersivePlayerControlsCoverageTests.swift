#if os(visionOS)
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("Immersive Player Controls Coverage")
struct ImmersivePlayerControlsCoverageTests {
    @Test
    func controlsHostPlayingStateWithChaptersSubtitlesAndScreenSize() throws {
        let engine = VPPlayerEngine()
        engine.currentTitle = "Coverage Episode"
        engine.currentTime = 42
        engine.duration = 300
        engine.bufferedPercent = 0.65
        engine.isPlaying = true
        engine.isBuffering = false
        engine.playbackRate = 1.25
        engine.subtitlesEnabled = true
        engine.currentSubtitleText = "A short subtitle."
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 1, title: "Opening", startTime: 0, endTime: 60),
            VPPlayerEngine.ChapterInfo(id: 2, title: "Middle", startTime: 60, endTime: 240),
            VPPlayerEngine.ChapterInfo(id: 3, title: "Finale", startTime: 240, endTime: 300),
        ]

        let hosted = try hostInVisibleImmersiveCoverageWindow(
            ImmersivePlayerControlsView(showsScreenSizeControl: true)
                .environment(engine)
                .frame(width: 560, height: 280)
        )
        defer { parkImmersiveCoverageWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
        #expect(engine.currentChapter(at: engine.currentTime)?.title == "Opening")
        #expect(engine.progressPercent > 0)
    }

    @Test
    func controlsHostErrorBufferingAndNoScreenSizeBranch() throws {
        let engine = VPPlayerEngine()
        engine.currentTitle = "Coverage Movie"
        engine.currentTime = 0
        engine.duration = 0
        engine.bufferedPercent = 0
        engine.isPlaying = false
        engine.isBuffering = true
        engine.playbackRate = 2.0
        engine.error = "Decoder failed"

        let hosted = try hostInVisibleImmersiveCoverageWindow(
            ImmersivePlayerControlsView(showsScreenSizeControl: false)
                .environment(engine)
                .frame(width: 560, height: 260)
        )
        defer { parkImmersiveCoverageWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        #expect(hosted.host.view.bounds.height > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
        #expect(engine.durationFormatted == "0:00")
        #expect(engine.remainingFormatted == "0:00")
    }

    @Test
    func controlsSourcePostsEveryExpectedImmersiveNotification() throws {
        let source = try sourceContents(of: "VPStudio/Views/Immersive/ImmersivePlayerControlsView.swift")

        for expectedNotification in [
            ".immersiveControlPreviousChapter",
            ".immersiveControlSeekBack",
            ".immersiveControlTogglePlayPause",
            ".immersiveControlSeekForward",
            ".immersiveControlNextChapter",
            ".immersiveControlCycleRate",
            ".immersiveControlToggleSubtitles",
            ".immersiveControlToggleAudio",
            ".immersiveControlCycleScreenSize",
            ".immersiveControlRequestEnvironmentSwitch",
            ".immersiveControlDismiss"
        ] {
            #expect(source.contains("NotificationCenter.default.post(name: \(expectedNotification)"))
        }

        #expect(source.contains("guard engine.duration > 0 else { return current.formattedDuration }"))
        #expect(source.contains("return \"\\(current.formattedDuration) of \\(engine.durationFormatted)\""))
        #expect(source.contains("case .increment:"))
        #expect(source.contains("case .decrement:"))
        #expect(source.contains("if showsScreenSizeControl {"))
    }
}

@MainActor
private func hostInVisibleImmersiveCoverageWindow<Content: View>(
    _ rootView: Content
) throws -> (host: UIHostingController<Content>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let host = UIHostingController(rootView: rootView)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 640, height: 360)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.08))
    return (host, window)
}

@MainActor
private func parkImmersiveCoverageWindow(_ window: UIWindow) {
    window.endEditing(true)
    window.resignKey()
    window.isHidden = true
    window.rootViewController = nil
    ImmersiveCoverageWindowRetainer.windows.append(window)
}

@MainActor
private enum ImmersiveCoverageWindowRetainer {
    static var windows: [UIWindow] = []
}

private func sourceContents(of relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
#endif
