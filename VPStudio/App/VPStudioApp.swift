import SwiftUI
#if os(visionOS)
import RealityKit
#endif
#if os(macOS)
import AppKit
#endif
#if !os(macOS)
import AVFoundation
#endif
import os

// MARK: - macOS App Delegate

#if os(macOS)
/// Prevents macOS from terminating the app when the player window closes
/// while the main window is suppressed (zero-window transient state).
final class VPStudioAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
#endif

// MARK: - App

@main
struct VPStudioApp: App {
    private static let logger = Logger(subsystem: "com.vpstudio", category: "app")

    #if os(macOS)
    @NSApplicationDelegateAdaptor(VPStudioAppDelegate.self) private var appDelegate
    #endif

    init() {
        // Configure audio session for media playback, allowing it to mix or route properly
        #if !os(macOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
            if #available(iOS 15.0, tvOS 15.0, visionOS 1.0, *) {
                try session.setSupportsMultichannelContent(true)
            }
            try session.setActive(true)
        } catch {
            Self.logger.error("Failed to configure AVAudioSession: \(error.localizedDescription, privacy: .public)")
        }
        #endif

        // Large shared image/data cache so posters & backdrops load from disk (~1ms) instead of
        // re-fetching over the network on every tab switch / scroll-back. Cached bytes are identical
        // to the network response — same resolution, zero quality change.
        URLCache.shared = URLCache(memoryCapacity: 50_000_000, diskCapacity: 300_000_000)
    }

    @State private var appState = AppState()
    @State private var sharedEngine = VPPlayerEngine()
    #if os(visionOS)
    @State private var cinemaSettings = CinemaSettings()
    @State private var hdriImmersionStyle: ImmersionStyle = .full
    @State private var customEnvImmersionStyle: ImmersionStyle = .full
    @State private var cinemaImmersionStyle: ImmersionStyle = .full
    #endif

    var body: some SwiftUI.Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appState)
        }
        .defaultSize(width: 1200, height: 800)
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif

        WindowGroup(id: "player", for: PlayerSessionRequest.self) { $request in
            if let request {
                // The scene value round-trips through Codable, which drops the runtime-only
                // StreamInfo.requestHeaders (Stremio proxy headers). Prefer the in-memory
                // session (headers intact) whenever it matches this window's id; fall back to
                // the decoded value only on a cold scene restore. Without this, header-gated
                // direct-play streams 403 because the player loses their proxy headers.
                let resolved: PlayerSessionRequest = {
                    if let active = appState.activePlayerSession, active.id == request.id {
                        return active
                    }
                    return request
                }()
                PlayerView(
                    stream: resolved.stream,
                    availableStreams: resolved.availableStreams,
                    mediaTitle: resolved.mediaTitle,
                    mediaId: resolved.mediaId,
                    tmdbId: resolved.tmdbId,
                    episodeId: resolved.episodeId,
                    nextEpisode: resolved.nextEpisode,
                    sessionID: resolved.id,
                    sessionRequest: resolved
                )
                    .environment(appState)
                    .environment(sharedEngine)
                    #if os(visionOS)
                    .environment(cinemaSettings)
                    #endif
            }
        }
        .defaultSize(width: 1400, height: 788)
#if os(macOS)
        .windowStyle(.plain)
#endif
        #if os(visionOS)
        .windowResizability(.automatic)
        #endif

        #if os(visionOS)
        ImmersiveSpace(id: "hdriSkybox") {
            HDRISkyboxEnvironment()
                .environment(appState)
                .environment(sharedEngine)
        }
        .immersionStyle(selection: $hdriImmersionStyle, in: .full)
        .upperLimbVisibility(.visible)

        ImmersiveSpace(id: "customEnvironment") {
            CustomEnvironmentView()
                .environment(appState)
                .environment(sharedEngine)
        }
        .immersionStyle(selection: $customEnvImmersionStyle, in: .full)
        .upperLimbVisibility(.visible)

        ImmersiveSpace(id: "cinemaEnvironment") {
            CinemaImmersiveContent(settings: cinemaSettings)
                .environment(appState)
                .environment(sharedEngine)
        }
        .immersionStyle(selection: $cinemaImmersionStyle, in: .full)
        .upperLimbVisibility(.visible)
        #endif
    }
}
