import Foundation

enum PlayerCinemaEnvironmentPolicy {
    static let menuDismissalDelay: Duration = .milliseconds(180)
    static let unavailableMessage = "Cinema Environment requires AVPlayer playback."

    static func canOpen(activeEngine: PlayerEngineKind?, hasAVPlayer: Bool) -> Bool {
        activeEngine == .avPlayer && hasAVPlayer
    }

    static func iconName(forAssetPath assetPath: String) -> String {
        let ext = URL(fileURLWithPath: assetPath).pathExtension.lowercased()
        // hdr/exr + equirectangular png/jpg are all skyboxes (match the broadened import).
        return ["hdr", "exr", "png", "jpg", "jpeg"].contains(ext) ? "pano" : "cube.transparent"
    }
}
