import Foundation
#if canImport(Darwin)
import Darwin
#endif

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
        let decodedLastPathComponent = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let lastPathComponent = decodedLastPathComponent.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
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
              let host = url.host, !host.isEmpty,
              // Untrusted addon payloads must not be able to point playback or
              // downloads at the local machine, the LAN, or cloud-metadata
              // endpoints — that would turn a stream URL into an SSRF primitive.
              !PrivateNetworkHostPolicy.isPrivateOrReserved(host: host) else {
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

/// Classifies a URL host as private/reserved so untrusted, third-party-provided
/// stream URLs can be rejected before the app ever connects to them.
///
/// Stremio addons (and any other untrusted indexer) can return arbitrary
/// `http(s)` direct-stream URLs. Without this gate a malicious or man-in-the-middled
/// addon could hand the player a URL such as `http://127.0.0.1:…`,
/// `http://192.168.1.1/…`, or `http://169.254.169.254/…` (cloud metadata) and the
/// app would dutifully fetch it — a classic SSRF / local-network probe primitive.
///
/// IP literals are parsed with the system resolver (`getaddrinfo` + `AI_NUMERICHOST`,
/// which performs no DNS), so the bytes classified are exactly the bytes URLSession
/// would connect to — closing the `inet_aton`-vs-`getaddrinfo` octal/decimal
/// divergence. Any numeric-looking host the strict parser rejects fails *closed*
/// rather than leaking through as a "hostname".
///
/// Scope: this is a literal-host gate. It does NOT resolve DNS or follow redirects,
/// so it cannot by itself stop DNS-rebinding or a public host that 30x-redirects to
/// a private one. Those require enforcement at fetch/playback time; this policy is
/// the cheap, always-on first layer. Pure value logic with no I/O — fully testable.
enum PrivateNetworkHostPolicy {
    /// Returns `true` when `host` refers to the local machine, a private/LAN range,
    /// a link-local / unique-local address, a documentation/benchmark range, or a
    /// single-label name that only resolves through local search domains.
    static func isPrivateOrReserved(host rawHost: String) -> Bool {
        var host = rawHost
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .lowercased()
        // Drop a single trailing root dot so the FQDN form ("localhost.",
        // "nas.local.") classifies the same as the bare form.
        if host.hasSuffix(".") {
            host.removeLast()
        }
        guard !host.isEmpty else { return true }

        // Numeric IP literal (IPv4 or IPv6, any spelling) — classify by the ACTUAL
        // address bytes the system resolver would connect to. Using getaddrinfo with
        // AI_NUMERICHOST (no DNS) mirrors URLSession's own resolution, so octal vs.
        // decimal leading-zero interpretations can't diverge into a fail-open the
        // way inet_aton (which treats "010" as octal) does.
        if let bytes = numericLiteralBytes(host) {
            return bytes.count == 16 ? isPrivateIPv6(bytes) : isPrivateIPv4(bytes)
        }

        // A colon host that the resolver didn't accept as a numeric literal is not
        // a real public host — fail closed.
        if host.contains(":") {
            return true
        }

        // Any all-numeric dotted/hex form the strict parser rejected (e.g.
        // "0177.0.0.1", "010.0.0.1", "0x7f.0.0.1") is a disguised IP attempt and
        // must not slip through as a "hostname" — fail closed.
        if looksLikeNumericIPLiteral(host) {
            return true
        }

        // Local / reserved hostname suffixes that never identify a public CDN.
        if host == "localhost"
            || host.hasSuffix(".localhost")
            || host.hasSuffix(".local")
            || host.hasSuffix(".internal")
            || host.hasSuffix(".home.arpa") {
            return true
        }

        // Single-label hostnames (no dot) resolve via the host's local search
        // domains, so they are an SSRF vector and never a legitimate public stream.
        if !host.contains(".") {
            return true
        }

        return false
    }

    /// Address bytes (4 for IPv4, 16 for IPv6) if `host` is a numeric literal the
    /// system resolver accepts, else `nil`. `AI_NUMERICHOST` disables DNS, so this
    /// only parses literals and never makes a network request.
    private static func numericLiteralBytes(_ host: String) -> [UInt8]? {
        var hints = addrinfo()
        hints.ai_flags = AI_NUMERICHOST
        hints.ai_family = AF_UNSPEC
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let info = result else {
            return nil
        }
        defer { freeaddrinfo(result) }
        guard let sockaddrPtr = info.pointee.ai_addr else { return nil }
        let family = info.pointee.ai_family
        if family == AF_INET {
            return sockaddrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ptr in
                var addr = ptr.pointee.sin_addr.s_addr
                return withUnsafeBytes(of: &addr) { Array($0) }
            }
        }
        if family == AF_INET6 {
            return sockaddrPtr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { ptr in
                var addr = ptr.pointee.sin6_addr
                return withUnsafeBytes(of: &addr) { Array($0.prefix(16)) }
            }
        }
        return nil
    }

    /// True when every dot-separated label is a decimal/octal/hex number — i.e. the
    /// host is a numeric IPv4 spelling. Real public hostnames always carry a
    /// non-numeric label (the TLD), so this never matches a legitimate CDN name.
    private static func looksLikeNumericIPLiteral(_ host: String) -> Bool {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(labels.count) else { return false }
        for label in labels {
            if label.hasPrefix("0x") {
                let hex = label.dropFirst(2)
                guard !hex.isEmpty, hex.allSatisfy(\.isHexDigit) else { return false }
            } else {
                guard !label.isEmpty, label.allSatisfy(\.isNumber) else { return false }
            }
        }
        return true
    }

    private static func isPrivateIPv4(_ o: [UInt8]) -> Bool {
        guard o.count == 4 else { return true }
        switch (o[0], o[1]) {
        case (0, _): return true                          // 0.0.0.0/8 "this host"
        case (10, _): return true                         // 10.0.0.0/8 private
        case (127, _): return true                        // loopback
        case (169, 254): return true                      // link-local
        case (172, 16...31): return true                  // 172.16.0.0/12 private
        case (192, 168): return true                      // 192.168.0.0/16 private
        case (100, 64...127): return true                 // 100.64.0.0/10 CGNAT
        case (192, 0): return o[2] == 0 || o[2] == 2      // 192.0.0.0/24, 192.0.2.0/24
        case (198, 18), (198, 19): return true            // 198.18.0.0/15 benchmark
        case (198, 51): return o[2] == 100                // 198.51.100.0/24 TEST-NET-2
        case (203, 0): return o[2] == 113                 // 203.0.113.0/24 TEST-NET-3
        case (255, 255): return o[2] == 255 && o[3] == 255 // broadcast
        default:
            return o[0] >= 224                            // 224.0.0.0+ multicast/reserved
        }
    }

    private static func isPrivateIPv6(_ b: [UInt8]) -> Bool {
        guard b.count == 16 else { return true }
        // Unspecified ::
        if b.allSatisfy({ $0 == 0 }) { return true }
        // Loopback ::1
        if b[0..<15].allSatisfy({ $0 == 0 }), b[15] == 1 { return true }
        // IPv4-mapped (::ffff:a.b.c.d) / IPv4-compatible (::a.b.c.d) — classify tail.
        if b[0..<10].allSatisfy({ $0 == 0 }) {
            let isMapped = b[10] == 0xff && b[11] == 0xff
            let isCompat = b[10] == 0 && b[11] == 0
            if isMapped || isCompat {
                return isPrivateIPv4([b[12], b[13], b[14], b[15]])
            }
        }
        // Unique-local fc00::/7
        if (b[0] & 0xfe) == 0xfc { return true }
        // Link-local fe80::/10
        if b[0] == 0xfe, (b[1] & 0xc0) == 0x80 { return true }
        return false
    }
}
