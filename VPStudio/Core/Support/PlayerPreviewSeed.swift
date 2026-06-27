import Foundation

/// Realistic mock playback state for visual QA of the **real** Player surface (`PlayerView`).
///
/// Mirrors [`DiscoverPreviewSeed`] / [`DetailPreviewSeed`] / [`SearchPreviewSeed`]: instead of a
/// hand-built chrome mock, the Test Mode harness renders the production `PlayerView` with
/// `disablesAutomaticTasks: true` (so `preparePlayback` is skipped — no `AVPlayer` is created, no
/// network, no prepare/cleanup) and a pre-seeded `VPPlayerEngine` injected through the environment,
/// exactly how the live "player" window provides its `sharedEngine`. The seeded engine drives the
/// real scrubber, time labels, buffered fill, chapter ticks/nav, rate pill, and chapter title; the
/// view's `currentStream` / `activeEngine` drive the quality + engine pills and metadata line. The
/// session request carries a safe poster URL shape so the real player artwork fallback renders
/// instead of a blank black stage when no engine surface is attached.
enum PlayerPreviewSeed {
    /// Title shown in the player's top bar and metadata line.
    static let mediaTitle = "Dune: Part Two"

    /// The engine kind reflected by the "AVPlayer" pill and the metadata line.
    static let activeEngine: PlayerEngineKind = .avPlayer

    private static let durationSeconds: TimeInterval = 9960   // 2:46:00 total
    private static let currentSeconds: TimeInterval = 3501    // 58:21 elapsed
    private static let imdbID = "tt15239678"
    private static let previewPosterURL = "https://m.media-amazon.com/images/M/vpstudio-player-preview.jpg"

    /// Placeholder stream describing a believable 4K BluRay source. Its `streamURL` is **never
    /// loaded** — `PlayerView(disablesAutomaticTasks: true)` skips `preparePlayback`, so no AVPlayer
    /// or network request is ever created from it. The quality / codec / HDR / audio values feed the
    /// real quality pill, metadata line, and the stream-quality menu.
    static let stream = StreamInfo(
        streamURL: URL(string: "vpstudio-preview://seeded-player")!,
        quality: .uhd4k,
        codec: .h265,
        audio: .atmos,
        source: .bluRay,
        hdr: .hdr10,
        fileName: "Dune.Part.Two.2024.2160p.BluRay.x265.Atmos.mkv",
        sizeBytes: 24_800_000_000,
        debridService: "Preview"
    )

    static var sessionRequest: PlayerSessionRequest {
        PlayerSessionRequest(
            stream: stream,
            mediaTitle: mediaTitle,
            mediaId: imdbID,
            imdbId: imdbID,
            posterPath: previewPosterURL
        )
    }

    /// Builds a fully-seeded engine: roughly a third of the way through a long film, ~58% buffered,
    /// playing at 1.0×, with two audio tracks and a handful of chapters so the real chapter ticks,
    /// chapter-navigation buttons, and chapter title all render. Passthrough dimming is left **off**
    /// so opening the QA preview never darkens the room.
    @MainActor
    static func makeSeededEngine() -> VPPlayerEngine {
        let engine = VPPlayerEngine()
        engine.currentTitle = mediaTitle
        engine.duration = durationSeconds
        engine.currentTime = currentSeconds
        engine.bufferedPercent = 0.58
        engine.playbackRate = 1.0
        engine.isPlaying = true
        engine.isBuffering = false
        engine.isDimEnabled = false
        engine.loadAudioTracks([
            VPPlayerEngine.TrackInfo(id: 0, name: "English", language: "en", codec: "Atmos"),
            VPPlayerEngine.TrackInfo(id: 1, name: "English (Commentary)", language: "en", codec: "AAC"),
        ])
        engine.loadChapters([
            VPPlayerEngine.ChapterInfo(id: 0, title: "Opening", startTime: 0, endTime: 600),
            VPPlayerEngine.ChapterInfo(id: 1, title: "Arrakis", startTime: 600, endTime: 2400),
            VPPlayerEngine.ChapterInfo(id: 2, title: "The Fremen", startTime: 2400, endTime: 4200),
            VPPlayerEngine.ChapterInfo(id: 3, title: "The Battle", startTime: 4200, endTime: 7200),
            VPPlayerEngine.ChapterInfo(id: 4, title: "Finale", startTime: 7200, endTime: durationSeconds),
        ])
        return engine
    }
}
