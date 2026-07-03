import Foundation

/// Pure mapping from a `TorrentResult` to a display descriptor for the Detail
/// source-selection row. This is the testable seam for the AIOStreams-grade row:
/// it decides the cached-badge variant, provider label, and formatted metadata
/// strings without importing SwiftUI or AVKit. The view binds the descriptor to
/// concrete `Color`/SF Symbols.
enum SourceRowPolicy {
    /// Tri-state cached badge for a source.
    enum CacheBadge: Equatable, Sendable {
        /// Instantly playable from a debrid cache — green + bolt.
        case instant
        /// Confirmed uncached, must be downloaded first — orange + download arrow.
        case mustDownload
        /// Cache status not yet known — no badge.
        case none

        /// Stable tint identifier the view maps to a concrete `Color`.
        var tint: BadgeTint? {
            switch self {
            case .instant: return .green
            case .mustDownload: return .orange
            case .none: return nil
            }
        }

        /// User-facing label, or `nil` when no badge should be drawn.
        var label: String? {
            switch self {
            case .instant: return "Instant"
            case .mustDownload: return "Must Download"
            case .none: return nil
            }
        }

        /// SF Symbol name, or `nil` when no badge should be drawn.
        var symbol: String? {
            switch self {
            case .instant: return "bolt.fill"
            case .mustDownload: return "arrow.down.circle.fill"
            case .none: return nil
            }
        }
    }

    /// Stable, SwiftUI-free tint identifier the view maps to a `Color`.
    enum BadgeTint: Equatable, Sendable {
        case green
        case orange
    }

    /// The full display descriptor for one source row.
    struct Descriptor: Equatable, Sendable {
        var cacheBadge: CacheBadge
        var sizeString: String
        /// Formatted seeders (e.g. `"42"`), or `nil` when there are none to show.
        var seedersString: String?
        /// Provider label: the cached service's display name when cached, else the indexer.
        var providerLabel: String
        /// Trailing release group (e.g. `"RARBG"`), or `nil` when not parsed.
        var releaseGroup: String?
    }

    static func descriptor(for torrent: TorrentResult) -> Descriptor {
        Descriptor(
            cacheBadge: cacheBadge(for: torrent),
            sizeString: torrent.sizeString,
            seedersString: seedersString(for: torrent),
            providerLabel: providerLabel(for: torrent),
            releaseGroup: normalizedReleaseGroup(torrent.releaseGroup)
        )
    }

    static func cacheBadge(for torrent: TorrentResult) -> CacheBadge {
        switch torrent.cacheAvailability {
        case .cached: return .instant
        case .notCached: return .mustDownload
        case .unknown: return .none
        }
    }

    static func seedersString(for torrent: TorrentResult) -> String? {
        torrent.seeders > 0 ? "\(torrent.seeders)" : nil
    }

    /// Prefers the cached debrid service's display name when the source is cached on
    /// a recognized service; otherwise falls back to the indexer name.
    static func providerLabel(for torrent: TorrentResult) -> String {
        if torrent.cacheAvailability == .cached,
           let raw = torrent.cachedOnService?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            if let service = DebridServiceType(rawValue: raw) {
                return service.displayName
            }
            return raw
        }
        return torrent.indexerName
    }

    private static func normalizedReleaseGroup(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
