import Foundation

enum SourceFilterPreset: String, CaseIterable, Identifiable, Sendable, Codable {
    case balanced
    case instant
    case cinema
    case compact
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .instant: return "Instant"
        case .cinema: return "Cinema"
        case .compact: return "Compact"
        case .custom: return "Custom"
        }
    }

    var summary: String {
        switch self {
        case .balanced:
            return "Hides camera sources while keeping the broadest useful result set."
        case .instant:
            return "Prioritizes sources that are cached or directly playable and hides confirmed downloads."
        case .cinema:
            return "Keeps 1080p-or-better releases with enough seeders for reliable resolving."
        case .compact:
            return "Keeps smaller files for quick starts and limited storage."
        case .custom:
            return "Uses your manual source rules below."
        }
    }

    var defaultOptions: SourceFilterOptions {
        switch self {
        case .balanced:
            return SourceFilterOptions(
                preset: self,
                hideConfirmedDownloads: false,
                hideCamSources: true,
                minimumSeeders: 0,
                maximumSizeGB: nil,
                minimumQuality: nil
            )
        case .instant:
            return SourceFilterOptions(
                preset: self,
                hideConfirmedDownloads: true,
                hideCamSources: true,
                minimumSeeders: 0,
                maximumSizeGB: nil,
                minimumQuality: nil
            )
        case .cinema:
            return SourceFilterOptions(
                preset: self,
                hideConfirmedDownloads: false,
                hideCamSources: true,
                minimumSeeders: 5,
                maximumSizeGB: nil,
                minimumQuality: .hd1080p
            )
        case .compact:
            return SourceFilterOptions(
                preset: self,
                hideConfirmedDownloads: false,
                hideCamSources: true,
                minimumSeeders: 1,
                maximumSizeGB: 12,
                minimumQuality: nil
            )
        case .custom:
            return SourceFilterOptions(
                preset: self,
                hideConfirmedDownloads: false,
                hideCamSources: true,
                minimumSeeders: 0,
                maximumSizeGB: nil,
                minimumQuality: nil
            )
        }
    }
}

struct SourceFilterOptions: Equatable, Sendable, Codable {
    static let maximumSizeLimitGB: Double = 250
    static let `default` = SourceFilterPreset.balanced.defaultOptions

    var preset: SourceFilterPreset
    var hideConfirmedDownloads: Bool
    var hideCamSources: Bool
    var minimumSeeders: Int
    var maximumSizeGB: Double?
    var minimumQuality: VideoQuality?

    var maximumSizeBytes: Int64? {
        guard let maximumSizeGB, maximumSizeGB > 0 else { return nil }
        return Int64((maximumSizeGB * 1_073_741_824).rounded())
    }

    var activeDescriptions: [String] {
        var descriptions: [String] = []
        if hideConfirmedDownloads { descriptions.append("Instant only") }
        if hideCamSources { descriptions.append("No CAM") }
        if minimumSeeders > 0 { descriptions.append("\(minimumSeeders)+ seeders") }
        if let maximumSizeGB, maximumSizeGB > 0 {
            descriptions.append("\(Self.formatGB(maximumSizeGB)) GB max")
        }
        if let minimumQuality {
            descriptions.append("\(minimumQuality.rawValue)+")
        }
        return descriptions
    }

    static func fromStoredValues(
        presetRawValue: String?,
        hideConfirmedDownloads: Bool?,
        hideCamSources: Bool?,
        minimumSeedersRawValue: String?,
        maximumSizeGBRawValue: String?,
        minimumQualityRawValue: String?
    ) -> SourceFilterOptions {
        let preset = presetRawValue
            .flatMap(SourceFilterPreset.init(rawValue:))
            ?? .balanced

        var options = preset.defaultOptions
        guard preset == .custom else { return options }

        if let hideConfirmedDownloads {
            options.hideConfirmedDownloads = hideConfirmedDownloads
        }
        if let hideCamSources {
            options.hideCamSources = hideCamSources
        }
        if let parsedSeeders = minimumSeedersRawValue.flatMap({ Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }) {
            options.minimumSeeders = max(0, min(500, parsedSeeders))
        }
        if let parsedMaximumSize = maximumSizeGBRawValue.flatMap({ Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }) {
            options.maximumSizeGB = parsedMaximumSize > 0 ? max(1, min(Self.maximumSizeLimitGB, parsedMaximumSize)) : nil
        }
        if let minimumQualityRawValue,
           !minimumQualityRawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let quality = VideoQuality(rawValue: minimumQualityRawValue) {
            options.minimumQuality = quality == .unknown ? nil : quality
        }

        return options
    }

    private static func formatGB(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

enum SourceFilterPolicy {
    static func filtered(
        _ torrents: [TorrentResult],
        options: SourceFilterOptions
    ) -> [TorrentResult] {
        torrents.filter { shouldKeep($0, options: options) }
    }

    static func shouldKeep(
        _ torrent: TorrentResult,
        options: SourceFilterOptions
    ) -> Bool {
        if options.hideConfirmedDownloads,
           torrent.cacheAvailability == .notCached {
            return false
        }

        if options.hideCamSources, torrent.source == .cam {
            return false
        }

        if torrent.seeders < options.minimumSeeders {
            return false
        }

        if let maximumSizeBytes = options.maximumSizeBytes,
           torrent.sizeBytes > maximumSizeBytes {
            return false
        }

        if let minimumQuality = options.minimumQuality,
           torrent.quality != .unknown,
           torrent.quality.sortOrder < minimumQuality.sortOrder {
            return false
        }

        return true
    }
}
