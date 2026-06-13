#if os(visionOS)
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("Immersive Cinema Hosting")
struct ImmersiveCinemaHostingTests {
    @Test func cinemaSettingsPanelHostsComfortAndWarningStates() throws {
        let uncomfortable = CinemaSettings(screenWidth: 8, screenDistance: 1.5, loadPersisted: false)
        let comfortable = CinemaSettings(screenWidth: 3, screenDistance: 5, loadPersisted: false)

        for settings in [uncomfortable, comfortable] {
            let hosted = try hostInVisibleCinemaTestWindow(
                CinemaSettingsPanel(settings: settings)
                    .frame(width: 520, height: 720)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            #expect(hosted.host.view.bounds.width > 0)
            #expect(hosted.host.view.subviews.isEmpty == false)
            parkCinemaTestWindow(hosted.window)
        }

        #expect(uncomfortable.isComfortable == false)
        #expect(comfortable.isComfortable)
    }

    @Test func hdriSkyboxHostsNoEnvironmentFallbackPath() async throws {
        let appState = AppState(testHooks: .init())
        appState.selectedEnvironmentAsset = nil

        let engine = VPPlayerEngine()
        engine.currentSubtitleText = "Immersive subtitle"

        let hosted = try hostInVisibleCinemaTestWindow(
            HDRISkyboxEnvironment()
                .environment(appState)
                .environment(engine)
                .frame(width: 640, height: 480)
        )

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 180_000_000)

        #expect(appState.activeEnvironment == .hdriSkybox)
        #expect(appState.isImmersiveSpaceOpen)

        tearDownCinemaTestWindow(hosted.window)
        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(appState.isImmersiveSpaceOpen == false)
    }

    @Test func cinemaImmersiveContentHostsDefaultShellPath() async throws {
        let appState = AppState(testHooks: .init())
        let engine = VPPlayerEngine()
        let settings = CinemaSettings(loadPersisted: false)

        let hosted = try hostInVisibleCinemaTestWindow(
            CinemaImmersiveContent(settings: settings)
                .environment(appState)
                .environment(engine)
                .frame(width: 640, height: 480)
        )

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 180_000_000)

        #expect(appState.activeEnvironment == .cinemaEnvironment)
        #expect(appState.isImmersiveSpaceOpen)

        tearDownCinemaTestWindow(hosted.window)
        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(appState.isImmersiveSpaceOpen == false)
    }
}

@MainActor
private func hostInVisibleCinemaTestWindow<Content: View>(
    _ rootView: Content
) throws -> (host: UIHostingController<Content>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let host = UIHostingController(rootView: rootView)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 720, height: 720)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return (host, window)
}

@MainActor
private func tearDownCinemaTestWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.resignKey()
    window.isHidden = true
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.rootViewController = nil
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    CinemaTestWindowRetainer.windows.append(window)
}

@MainActor
private func parkCinemaTestWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    CinemaTestWindowRetainer.windows.append(window)
}

@MainActor
private enum CinemaTestWindowRetainer {
    static var windows: [UIWindow] = []
}
#endif
