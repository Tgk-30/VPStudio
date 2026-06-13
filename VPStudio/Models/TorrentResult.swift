import Foundation

struct TorrentResult: Codable, Sendable, Identifiable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case infoHash
        case title
        case sizeBytes
        case seeders
        case leechers
        case quality
        case codec
        case audio
        case source
        case hdr
        case indexerName
        case magnetURI
        case directStreamURL
        case isCached
        case cachedOnService
    }

    var id: String { "\(infoHash)-\(indexerName)" }

    var infoHash: String
    var title: String
    var sizeBytes: Int64
    var seeders: Int
    var leechers: Int
    var quality: VideoQuality
    var codec: VideoCodec
    var audio: AudioFormat
    var source: SourceType
    var hdr: HDRFormat
    var indexerName: String
    var magnetURI: String?
    var directStreamURL: String?
    var directStreamRequestHeaders: [String: String]? = nil

    var isCached: Bool = false
    var cachedOnService: String?

    var requiresDebridResolution: Bool {
        if prefersDebridResolutionOverDirectURL {
            return true
        }
        return directStreamInfo == nil
    }

    var hasResolvableDebridHash: Bool {
        DebridHashValidator.normalizedInfoHash(infoHash) != nil
            || JSONValueParsing.extractInfoHash(from: magnetURI).flatMap(DebridHashValidator.normalizedInfoHash) != nil
    }

    var prefersDebridResolutionOverDirectURL: Bool {
        guard hasResolvableDebridHash,
              let directStreamURL,
              let url = URL(string: directStreamURL) else {
            return false
        }

        return Self.isStremioDebridResolverURL(url, indexerName: indexerName)
    }

    var sizeString: String {
        let gb = Double(sizeBytes) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(sizeBytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    var qualityBadge: String {
        var parts: [String] = []
        if quality != .unknown { parts.append(quality.rawValue) }
        if hdr != .sdr { parts.append(hdr.rawValue) }
        if codec != .unknown { parts.append(codec.rawValue) }
        if audio != .unknown { parts.append(audio.rawValue) }
        if source != .unknown { parts.append(source.rawValue) }
        return parts.joined(separator: " / ")
    }

    static func fromSearch(
        infoHash: String,
        title: String,
        sizeBytes: Int64,
        seeders: Int,
        leechers: Int,
        indexerName: String,
        magnetURI: String? = nil,
        directStreamURL: String? = nil,
        directStreamRequestHeaders: [String: String]? = nil
    ) -> TorrentResult {
        TorrentResult(
            infoHash: infoHash.lowercased(),
            title: title,
            sizeBytes: sizeBytes,
            seeders: seeders,
            leechers: leechers,
            quality: VideoQuality.parse(from: title),
            codec: VideoCodec.parse(from: title),
            audio: AudioFormat.parse(from: title),
            source: SourceType.parse(from: title),
            hdr: HDRFormat.parse(from: title),
            indexerName: indexerName,
            magnetURI: magnetURI,
            directStreamURL: normalizedDirectStreamURLString(directStreamURL),
            directStreamRequestHeaders: StreamInfo.normalizedRequestHeaders(directStreamRequestHeaders)
        )
    }

    var directStreamInfo: StreamInfo? {
        guard let normalized = Self.normalizedDirectStreamURLString(directStreamURL),
              let url = URL(string: normalized) else {
            return nil
        }

        let fallbackName = title
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lastPathComponent = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let fileName = lastPathComponent.isEmpty ? (fallbackName ?? title) : lastPathComponent

        return StreamInfo(
            streamURL: url,
            quality: quality,
            codec: codec,
            audio: audio,
            source: source,
            hdr: hdr,
            fileName: fileName,
            sizeBytes: sizeBytes > 0 ? sizeBytes : nil,
            debridService: indexerName,
            requestHeaders: directStreamRequestHeaders
        )
    }

    static func normalizedDirectStreamURLString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else {
            return nil
        }
        return url.absoluteString
    }

    static func isStremioDebridResolverURL(_ url: URL, indexerName: String) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        let stremioNamed = indexerName.localizedCaseInsensitiveContains("stremio")

        if host == "torrentio.strem.fun" || host.hasSuffix(".strem.fun") {
            return path.contains("/resolve")
        }

        if host == "mediafusion.elfhosted.com" || (stremioNamed && host.contains("mediafusion")) {
            return path.contains("/streaming_provider") || path.contains("/resolve")
        }

        return stremioNamed && path.contains("/resolve") && host.contains("strem")
    }
}
