import SwiftUI
import AVKit
#if os(macOS)
import AppKit

struct AVPlayerSurfaceView: NSViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    var allowsTransparentBackground = false

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = videoGravity
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
        nsView.controlsStyle = .none
        nsView.videoGravity = videoGravity
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player = nil
    }
}
#elseif canImport(UIKit)
import UIKit
import os

struct AVPlayerSurfaceView: UIViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    var allowsTransparentBackground = false

    func makeUIView(context: Context) -> AVPlayerSurfaceUIView {
        let view = AVPlayerSurfaceUIView()
        configure(view)
        return view
    }

    func updateUIView(_ uiView: AVPlayerSurfaceUIView, context: Context) {
        configure(uiView)
    }

    static func dismantleUIView(_ uiView: AVPlayerSurfaceUIView, coordinator: ()) {
        uiView.player = nil
    }

    private func configure(_ view: AVPlayerSurfaceUIView) {
        view.player = player
        view.playerLayer.videoGravity = videoGravity
        Self.applyTransparentBackground(to: view, enabled: allowsTransparentBackground)
    }

    static let transparentBackgroundTraversalNodeLimit = 96
    static let transparentBackgroundTraversalDepthLimit = 8

    static func applyTransparentBackground(to view: UIView, enabled: Bool) {
        var queue: [(view: UIView, depth: Int)] = [(view, 0)]
        var visited = Set<ObjectIdentifier>()
        var index = 0
        var visitedCount = 0

        while index < queue.count,
              visitedCount < transparentBackgroundTraversalNodeLimit {
            let item = queue[index]
            index += 1

            let identifier = ObjectIdentifier(item.view)
            guard visited.insert(identifier).inserted else { continue }
            visitedCount += 1

            item.view.backgroundColor = enabled ? .clear : .black
            item.view.isOpaque = !enabled

            guard item.depth < transparentBackgroundTraversalDepthLimit else { continue }
            for subview in item.view.subviews {
                queue.append((subview, item.depth + 1))
            }
        }
    }
}

final class AVPlayerSurfaceUIView: UIView {
    private static let logger = Logger(subsystem: "com.vpstudio", category: "avplayer-surface")

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        guard let layer = self.layer as? AVPlayerLayer else {
            Self.logger.error("Expected AVPlayerLayer backing layer.")
            return AVPlayerLayer()
        }
        return layer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
        }
    }
}
#endif
