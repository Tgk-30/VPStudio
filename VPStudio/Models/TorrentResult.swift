import Foundation

/// Tri-state debrid cache availability for a source.
///
/// `.unknown` means we have not yet confirmed cache status (or the check failed);
/// `.cached` means the source plays instantly from a debrid service; `.notCached`
/// means a confirmed-uncached source that must be downloaded before it can play.
enum CacheAvailability: String, Codable, Sendable, Equatable {
    case cached
    case notCached
    case unknown
}

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
        case releaseGroup
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

    /// Tri-state cache status. Stored backing for the `isCached` bridge below.
    var cacheAvailability: CacheAvailability = .unknown
    var cachedOnService: String?

    /// Trailing scene/p2p release group (e.g. `RARBG`), parsed from the title.
    var releaseGroup: String?

    /// Back-compat bridge over `cacheAvailability`. Reads `true` only when confirmed
    /// cached; setting `true` marks `.cached` and `false` resets to `.unknown` (the
    /// pre-tri-state "not known to be cached" meaning). Used by TorrentRanking and
    /// stream resolution.
    var isCached: Bool {
        get { cacheAvailability == .cached }
        set { cacheAvailability = newValue ? .cached : .unknown }
    }

    /// Preserves the historical memberwise initializer signature (callers and tests
    /// pass `isCached:`/`cachedOnService:` as the trailing labels). A computed
    /// `isCached` plus custom `Codable` suppresses synthesis, so this is explicit.
    /// The new `releaseGroup` is appended last with a default so existing call-sites
    /// keep compiling unchanged.
    init(
        infoHash: String,
        title: String,
        sizeBytes: Int64,
        seeders: Int,
        leechers: Int,
        quality: VideoQuality,
        codec: VideoCodec,
        audio: AudioFormat,
        source: SourceType,
        hdr: HDRFormat,
        indexerName: String,
        magnetURI: String? = nil,
        directStreamURL: String? = nil,
        directStreamRequestHeaders: [String: String]? = nil,
        isCached: Bool = false,
        cachedOnService: String? = nil,
        releaseGroup: String? = nil
    ) {
        self.infoHash = infoHash
        self.title = title
        self.sizeBytes = sizeBytes
        self.seeders = seeders
        self.leechers = leechers
        self.quality = quality
        self.codec = codec
        self.audio = audio
        self.source = source
        self.hdr = hdr
        self.indexerName = indexerName
        self.magnetURI = magnetURI
        self.directStreamURL = directStreamURL
        self.directStreamRequestHeaders = directStreamRequestHeaders
        self.cacheAvailability = isCached ? .cached : .unknown
        self.cachedOnService = cachedOnService
        self.releaseGroup = releaseGroup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        infoHash = try container.decode(String.self, forKey: .infoHash)
        title = try container.decode(String.self, forKey: .title)
        sizeBytes = try container.decode(Int64.self, forKey: .sizeBytes)
        seeders = try container.decode(Int.self, forKey: .seeders)
        leechers = try container.decode(Int.self, forKey: .leechers)
        quality = try container.decode(VideoQuality.self, forKey: .quality)
        codec = try container.decode(VideoCodec.self, forKey: .codec)
        audio = try container.decode(AudioFormat.self, forKey: .audio)
        source = try container.decode(SourceType.self, forKey: .source)
        hdr = try container.decode(HDRFormat.self, forKey: .hdr)
        indexerName = try container.decode(String.self, forKey: .indexerName)
        magnetURI = try container.decodeIfPresent(String.self, forKey: .magnetURI)
        directStreamURL = try container.decodeIfPresent(String.self, forKey: .directStreamURL)
        // Preserve the historical `isCached` Bool wire format; legacy payloads have no
        // tri-state, so a stored `false` decodes to `.unknown` (matching the bridge).
        let decodedIsCached = try container.decodeIfPresent(Bool.self, forKey: .isCached) ?? false
        cacheAvailability = decodedIsCached ? .cached : .unknown
        cachedOnService = try container.decodeIfPresent(String.self, forKey: .cachedOnService)
        releaseGroup = try container.decodeIfPresent(String.self, forKey: .releaseGroup)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(infoHash, forKey: .infoHash)
        try container.encode(title, forKey: .title)
        try container.encode(sizeBytes, forKey: .sizeBytes)
        try container.encode(seeders, forKey: .seeders)
        try container.encode(leechers, forKey: .leechers)
        try container.encode(quality, forKey: .quality)
        try container.encode(codec, forKey: .codec)
        try container.encode(audio, forKey: .audio)
        try container.encode(source, forKey: .source)
        try container.encode(hdr, forKey: .hdr)
        try container.encode(indexerName, forKey: .indexerName)
        try container.encodeIfPresent(magnetURI, forKey: .magnetURI)
        try container.encodeIfPresent(directStreamURL, forKey: .directStreamURL)
        try container.encode(isCached, forKey: .isCached)
        try container.encodeIfPresent(cachedOnService, forKey: .cachedOnService)
        try container.encodeIfPresent(releaseGroup, forKey: .releaseGroup)
    }

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
            directStreamRequestHeaders: StreamInfo.normalizedRequestHeaders(directStreamRequestHeaders),
            releaseGroup: ReleaseNameParser.releaseGroup(from: title)
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
