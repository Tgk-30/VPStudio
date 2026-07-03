#if os(macOS)
import AppKit
import SwiftUI

struct PlayerWindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.onWindowChange = { [binding = $window] newWindow in
            binding.wrappedValue = newWindow
        }
        return view
    }

    func updateNSView(_ nsView: WindowObservingView, context: Context) {}
}

/// Custom NSView that reports window changes via `viewDidMoveToWindow`,
/// avoiding unsafe `@Binding` writes from `DispatchQueue.main.async`
/// during SwiftUI view update cycles.
final class WindowObservingView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
#elseif canImport(UIKit)
import UIKit
import SwiftUI

/// UIViewRepresentable that captures the player view's actual UIWindowScene,
/// ensuring geometry preferences target the correct window (not the main window).
struct PlayerWindowSceneAccessor: UIViewRepresentable {
    @Binding var windowScene: UIWindowScene?

    func makeUIView(context: Context) -> WindowSceneObservingView {
        let view = WindowSceneObservingView()
        view.onSceneChange = { [binding = $windowScene] scene in
            binding.wrappedValue = scene
        }
        return view
    }

    func updateUIView(_ uiView: WindowSceneObservingView, context: Context) {}
}

final class WindowSceneObservingView: UIView {
    var onSceneChange: ((UIWindowScene?) -> Void)?
    private var pendingScenePublishTask: Task<Void, Never>?
    private var lastPublishedSceneID: ObjectIdentifier?
    private var didPublishScene = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        publishSceneChange(window?.windowScene)
    }

    deinit {
        pendingScenePublishTask?.cancel()
    }

    private func publishSceneChange(_ scene: UIWindowScene?) {
        let sceneID = scene.map { ObjectIdentifier($0) }
        guard !didPublishScene || sceneID != lastPublishedSceneID else { return }

        didPublishScene = true
        lastPublishedSceneID = sceneID
        pendingScenePublishTask?.cancel()
        // Deferred (not synchronous) so callers can observe the pre-publish state,
        // but only one hop away so observers are notified within a single runloop turn.
        pendingScenePublishTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            guard self.lastPublishedSceneID == sceneID else { return }
            let currentScene = self.window?.windowScene
            guard currentScene.map({ ObjectIdentifier($0) }) == sceneID else { return }
            self.onSceneChange?(currentScene)
            self.pendingScenePublishTask = nil
        }
    }
}
#endif
