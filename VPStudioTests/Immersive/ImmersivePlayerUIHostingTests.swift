#if os(visionOS)
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("Immersive Player UI Hosting")
struct ImmersivePlayerUIHostingTests {
    @Test func controlsViewHostsWithPlaybackStateAndScreenSizeControl() throws {
        let engine = makeEngine()

        let hosted = try hostInVisibleImmersiveTestWindow(
            ImmersivePlayerControlsView(showsScreenSizeControl: true)
                .environment(engine)
                .frame(width: 560, height: 240)
        )
        defer { parkImmersiveTestWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test func controlsViewHostsWithoutScreenSizeControl() throws {
        let engine = makeEngine()
        engine.subtitlesEnabled = true
        engine.playbackRate = 2.0

        let hosted = try hostInVisibleImmersiveTestWindow(
            ImmersivePlayerControlsView(showsScreenSizeControl: false)
                .environment(engine)
                .frame(width: 560, height: 240)
        )
        defer { parkImmersiveTestWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(hosted.host.view.bounds.height > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test func customEnvironmentViewUpdatesImmersiveLifecycleWhenHosted() async throws {
        let appState = AppState(testHooks: .init())
        let engine = makeEngine()

        let hosted = try hostInVisibleImmersiveTestWindow(
            CustomEnvironmentView()
                .environment(appState)
                .environment(engine)
                .frame(width: 600, height: 480)
        )

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(appState.activeEnvironment == .customEnvironment)
        #expect(appState.isImmersiveSpaceOpen)

        tearDownImmersiveTestWindow(hosted.window)
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(appState.isImmersiveSpaceOpen == false)
    }

    private func makeEngine() -> VPPlayerEngine {
        let engine = VPPlayerEngine()
        engine.currentTitle = "Test Episode"
        engine.currentTime = 12
        engine.duration = 120
        engine.isPlaying = true
        engine.isBuffering = false
        engine.playbackRate = 1.5
        engine.chapters = [
            VPPlayerEngine.ChapterInfo(id: 0, title: "Intro", startTime: 0, endTime: 30),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Main", startTime: 30, endTime: 120),
        ]
        return engine
    }
}

@MainActor
private func hostInVisibleImmersiveTestWindow<Content: View>(
    _ rootView: Content
) throws -> (host: UIHostingController<Content>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let host = UIHostingController(rootView: rootView)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return (host, window)
}

@MainActor
private func tearDownImmersiveTestWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.resignKey()
    window.isHidden = true
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.rootViewController = nil
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    ImmersiveTestWindowRetainer.windows.append(window)
}

@MainActor
private func parkImmersiveTestWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    ImmersiveTestWindowRetainer.windows.append(window)
}

@MainActor
private enum ImmersiveTestWindowRetainer {
    static var windows: [UIWindow] = []
}
#endif
