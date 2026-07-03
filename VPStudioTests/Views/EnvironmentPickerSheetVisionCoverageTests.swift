#if os(visionOS)
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("EnvironmentPickerSheet visionOS coverage", .serialized)
struct EnvironmentPickerSheetVisionCoverageTests {
    @Test
    func emptyAndErrorStatesRenderWithoutAutomaticTasks() throws {
        let appState = AppState(testHooks: .init())
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                EnvironmentPickerSheet(
                    onSelect: { _ in },
                    onDismiss: {},
                    onSelectCinema: nil,
                    initialEnvironments: [],
                    initialImportError: "Could not import this environment.",
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test
    func gridAndExitButtonStateRenderWithImportedAndBundledAssets() throws {
        let appState = AppState(testHooks: .init())
        appState.isImmersiveSpaceOpen = true
        appState.selectedEnvironmentAsset = EnvironmentAsset(
            id: "imported-hdr",
            name: "Night HDRI",
            sourceType: .imported,
            assetPath: "/tmp/night.hdr"
        )

        let assets = [
            EnvironmentAsset(
                id: "imported-hdr",
                name: "Night HDRI",
                sourceType: .imported,
                assetPath: "/tmp/night.hdr"
            ),
            EnvironmentAsset(
                id: "bundled-scene",
                name: "Theater Scene",
                sourceType: .bundled,
                assetPath: "/tmp/theater.reality"
            ),
        ]

        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                EnvironmentPickerSheet(
                    onSelect: { _ in },
                    onDismiss: {},
                    onSelectCinema: {},
                    initialEnvironments: assets,
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test
    func environmentAndCinemaPreviewCardsConstructAcrossStates() throws {
        let importedHDR = EnvironmentAsset(
            id: "imported-hdr",
            name: "Night HDRI",
            sourceType: .imported,
            assetPath: "/tmp/night.hdr"
        )
        let bundledScene = EnvironmentAsset(
            id: "bundled-scene",
            name: "Theater Scene",
            sourceType: .bundled,
            assetPath: "/tmp/theater.reality"
        )

        let views: [(String, AnyView)] = [
            (
                "Active HDR card",
                AnyView(
                    EnvironmentPreviewCard(
                        asset: importedHDR,
                        status: .active,
                        onSelect: {},
                        onDelete: {}
                    )
                )
            ),
            (
                "Inactive bundled scene card",
                AnyView(
                    EnvironmentPreviewCard(
                        asset: bundledScene,
                        status: .inactive,
                        onSelect: {}
                    )
                )
            ),
            (
                "Standard room card",
                AnyView(
                    NoEnvironmentPreviewCard(
                        status: .current,
                        onSelect: {}
                    )
                )
            ),
            (
                "Cinema environment card",
                AnyView(
                    CinemaEnvironmentPreviewCard(
                        status: .active,
                        onSelect: {}
                    )
                )
            ),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(view.frame(width: 420, height: 260))
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should build host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }
}

@MainActor
private func hostInVisibleVisionWindow<Content: View>(
    _ rootView: Content
) throws -> (host: UIHostingController<AnyView>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )

    let host = UIHostingController(rootView: AnyView(rootView))
    host.view.backgroundColor = .clear
    let window = UIWindow(windowScene: scene)
    window.rootViewController = host
    window.frame = CGRect(x: 0, y: 0, width: 980, height: 820)
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return (host, window)
}

@MainActor
private func tearDownVisionWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
    EnvironmentPickerCoverageWindowRetainer.windows.append(window)
    if EnvironmentPickerCoverageWindowRetainer.windows.count > 8 {
        EnvironmentPickerCoverageWindowRetainer.windows.removeFirst(
            EnvironmentPickerCoverageWindowRetainer.windows.count - 8
        )
    }
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
}

@MainActor
private enum EnvironmentPickerCoverageWindowRetainer {
    static var windows: [UIWindow] = []
}
#endif
