#if canImport(UIKit) && !os(macOS)
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("Player Window Scene Accessor")
struct PlayerWindowSceneAccessorVisionTests {
    @Test
    func observingViewReportsNilSceneWhenDetached() {
        let view = WindowSceneObservingView()
        var didReportScene = false
        var observedScene: UIWindowScene?
        view.onSceneChange = {
            didReportScene = true
            observedScene = $0
        }

        view.didMoveToWindow()

        #expect(didReportScene)
        #expect(observedScene == nil)
    }

    @Test
    func accessorCanBeConstructedWithSceneBinding() {
        var observedScene: UIWindowScene?
        let accessor = PlayerWindowSceneAccessor(
            windowScene: Binding(
                get: { observedScene },
                set: { observedScene = $0 }
            )
        )

        _ = accessor
        #expect(observedScene == nil)
    }
}
#endif
