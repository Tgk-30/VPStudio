import Foundation

/// The playback mode for a resolved stream.
///
/// VPStudio is a **direct-play-only** player: it hands the stream URL to a
/// native engine (AVPlayer or KSPlayer) and plays the bytes as-is. There is no
/// transcoding or remuxing anywhere in the app — not on a server, not on
/// device. This enum exists to make that invariant explicit and testable; today
/// it has a single meaningful case.
enum PlaybackMode: String, Equatable, Sendable {
    /// Play the stream's bytes directly through a native engine. No transcode,
    /// no remux.
    case directPlay
}

/// Pure policy that codifies and locks VPStudio's direct-play contract.
///
/// ## Contract
/// Debrid services return standard HTTP(S) progressive or HLS streams
/// (`.mp4`, `.mkv`, `.m3u8`, etc.). The player streams those bytes straight
/// into AVPlayer or KSPlayer. Codec/container compatibility is handled by
/// *engine selection* (see `PlayerEngineSelector`), NOT by rewriting the media:
/// if AVPlayer can't open a container, KSPlayer (FFmpeg-backed) is tried — but
/// in both cases the original bytes are played untouched.
///
/// This means **every** stream — across formats, resolutions (incl. 4K), HDR
/// variants (HDR10/HDR10+/Dolby Vision/HLG), and native stereoscopic MV-HEVC —
/// resolves to `.directPlay`. There is intentionally no branch that returns a
/// transcode/remux mode, because no such pipeline exists in the codebase. Tests
/// guard this so the invariant can't silently regress.
enum DirectPlayPolicy {
    /// Returns the playback mode for the given stream.
    ///
    /// Always `.directPlay`. The parameter is retained so the call site reads
    /// intentionally (and so the contract is enforced per-stream in tests),
    /// even though the result is currently format-independent by design.
    static func playbackMode(for stream: StreamInfo) -> PlaybackMode {
        _ = stream
        return .directPlay
    }

    /// Whether the stream is played directly (always true under the contract).
    static func isDirectPlay(_ stream: StreamInfo) -> Bool {
        playbackMode(for: stream) == .directPlay
    }
}
