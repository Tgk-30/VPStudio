import Foundation
import AVFoundation

/// Manages spatial audio configuration for immersive and windowed playback modes.
/// Configures AVAudioSession for optimal spatial rendering on visionOS.
@MainActor
@Observable
final class SpatialAudioManager {
    private(set) var isImmersiveMode = false
    private(set) var isSpatialAudioAvailable = false

    init() {
        refreshSpatialCapabilities()
        observeAudioRouteChanges()
    }

    deinit {
        #if !os(macOS)
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    // MARK: - Immersive Mode Transitions

    /// Call when entering immersive space. Configures audio session for spatial rendering.
    func enterImmersiveMode() {
        isImmersiveMode = true
        configureForImmersive()
    }

    /// Call when leaving immersive space. Restores standard audio session.
    func exitImmersiveMode() {
        isImmersiveMode = false
        configureForWindowed()
    }

    // MARK: - Configuration

    private func configureForImmersive() {
        #if !os(macOS)
        AudioSessionConfigurator.configurePlaybackAsync(policy: .immersive)
        #endif

        refreshSpatialCapabilities()
    }

    private func configureForWindowed() {
        #if !os(macOS)
        AudioSessionConfigurator.configurePlaybackAsync(policy: .standard)
        #endif
    }

    // MARK: - Spatial Capability Detection

    func refreshSpatialCapabilities() {
        #if !os(macOS)
        if #available(iOS 15.0, tvOS 15.0, visionOS 1.0, *) {
            let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
            isSpatialAudioAvailable = outputs.contains { $0.isSpatialAudioEnabled }
        } else {
            isSpatialAudioAvailable = false
        }
        #else
        isSpatialAudioAvailable = false
        #endif
    }

    // MARK: - Observers

    private func observeAudioRouteChanges() {
        #if !os(macOS)
        NotificationCenter.default.removeObserver(self)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        if #available(iOS 15.0, tvOS 15.0, visionOS 1.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSpatialPlaybackCapabilitiesChange(_:)),
                name: AVAudioSession.spatialPlaybackCapabilitiesChangedNotification,
                object: nil
            )
        }
        #endif
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        // CoreAudio posts route-change notifications on an arbitrary thread; this @MainActor
        // @Observable's state must be mutated on the main actor (mirrors NetworkMonitor).
        Task { @MainActor in self.refreshSpatialCapabilities() }
    }

    @available(iOS 15.0, tvOS 15.0, visionOS 1.0, *)
    @objc private func handleSpatialPlaybackCapabilitiesChange(_ notification: Notification) {
        Task { @MainActor in self.refreshSpatialCapabilities() }
    }
}
