import Foundation

struct StreamRecoveryContext: Codable, Sendable, Equatable, Hashable {
    var infoHash: String
    var preferredService: DebridServiceType?
    var magnetURI: String?
    var seasonNumber: Int?
    var episodeNumber: Int?
    var torrentId: String?
    var resolvedDebridService: String?
    var resolvedFileName: String?
    var resolvedFileSizeBytes: Int64?

    init?(
        infoHash: String,
        preferredService: DebridServiceType? = nil,
        magnetURI: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        torrentId: String? = nil,
        resolvedDebridService: String? = nil,
        resolvedFileName: String? = nil,
        resolvedFileSizeBytes: Int64? = nil
    ) {
        let normalizedHash = infoHash
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalizedHash.isEmpty else { return nil }

        self.infoHash = normalizedHash
        self.preferredService = preferredService
        self.magnetURI = Self.normalizedOptionalString(magnetURI)
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.torrentId = Self.normalizedOptionalString(torrentId)
        self.resolvedDebridService = Self.normalizedOptionalString(resolvedDebridService)
        self.resolvedFileName = Self.normalizedOptionalString(resolvedFileName)
        self.resolvedFileSizeBytes = Self.normalizedByteCount(resolvedFileSizeBytes)
    }

    private static func normalizedOptionalString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func normalizedByteCount(_ value: Int64?) -> Int64? {
        guard let value, value > 0 else { return nil }
        return value
    }
}

struct StreamInfo: Codable, Sendable, Identifiable, Equatable, Hashable {
    private static let maxRequestHeaderValueLength = 2_048
    private static let allowedRequestHeaderNames: [String: String] = [
        "accept": "Accept",
        "accept-language": "Accept-Language",
        "origin": "Origin",
        "referer": "Referer",
        "referrer": "Referer",
        "user-agent": "User-Agent",
    ]

    private enum CodingKeys: String, CodingKey {
        case streamURL
        case quality
        case codec
        case audio
        case source
        case hdr
        case fileName
        case sizeBytes
        case debridService
        case recoveryContext
    }

    var id: String {
        "\(debridService)-\(fileName)-\(quality.rawValue)-\(codec.rawValue)-\(transportIdentity)"
    }

    var streamURL: URL
    var quality: VideoQuality
    var codec: VideoCodec
    var audio: AudioFormat
    var source: SourceType
    var hdr: HDRFormat
    var fileName: String
    var sizeBytes: Int64?
    var debridService: String
    var recoveryContext: StreamRecoveryContext?
    var requestHeaders: [String: String]? = nil
    var remoteTransferID: String? {
        recoveryContext?.torrentId
    }

    init(
        streamURL: URL,
        quality: VideoQuality,
        codec: VideoCodec,
        audio: AudioFormat,
        source: SourceType,
        hdr: HDRFormat,
        fileName: String,
        sizeBytes: Int64?,
        debridService: String,
        recoveryContext: StreamRecoveryContext? = nil,
        requestHeaders: [String: String]? = nil
    ) {
        self.streamURL = streamURL
        self.quality = quality
        self.codec = codec
        self.audio = audio
        self.source = source
        self.hdr = hdr
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.debridService = debridService
        self.recoveryContext = recoveryContext
        self.requestHeaders = Self.normalizedRequestHeaders(requestHeaders)
    }

    func withRecoveryContext(_ recoveryContext: StreamRecoveryContext?) -> StreamInfo {
        var copy = self
        copy.recoveryContext = recoveryContext
        return copy
    }

    func withStreamURL(_ streamURL: URL) -> StreamInfo {
        var copy = self
        copy.streamURL = streamURL
        return copy
    }

    func withRequestHeaders(_ requestHeaders: [String: String]?) -> StreamInfo {
        var copy = self
        copy.requestHeaders = Self.normalizedRequestHeaders(requestHeaders)
        return copy
    }

    static func normalizedRequestHeaders(_ headers: [String: String]?) -> [String: String]? {
        guard let headers else { return nil }

        let normalized = headers.reduce(into: [String: String]()) { result, pair in
            let rawName = pair.key
            let rawValue = pair.value
            guard rawName.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n:")) == nil else { return }
            guard rawValue.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n")) == nil else { return }

            let name = pair.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = pair.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            guard let canonicalName = allowedRequestHeaderNames[name.lowercased()] else { return }
            guard let value = normalizedRequestHeaderValue(value, canonicalName: canonicalName) else { return }
            result[canonicalName] = value
        }

        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedRequestHeaderValue(_ value: String, canonicalName: String) -> String? {
        guard !value.isEmpty,
              value.utf8.count <= maxRequestHeaderValueLength,
              value.rangeOfCharacter(from: .controlCharacters) == nil else {
            return nil
        }

        if canonicalName == "Origin" || canonicalName == "Referer" {
            guard isPublicHTTPHeaderURL(value),
                  !containsCredentialMaterial(inHeaderURLString: value) else { return nil }
        }

        return value
    }

    private static func isPublicHTTPHeaderURL(_ value: String) -> Bool {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty,
              !PrivateNetworkHostPolicy.isPrivateOrReserved(host: host) else {
            return false
        }
        return true
    }

    private static func containsCredentialMaterial(inHeaderURLString value: String) -> Bool {
        guard let url = URL(string: value) else {
            return true
        }

        return url.user != nil
            || url.password != nil
            || SensitiveURLQueryPolicy.containsSensitiveQueryItem(in: url)
            || containsSensitiveFragment(in: url)
    }

    private static func containsSensitiveFragment(in url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let fragment = components.percentEncodedFragment,
              !fragment.isEmpty else {
            return false
        }

        return SensitiveURLQueryPolicy.containsSensitiveAssignment(in: fragment)
    }

    private var transportIdentity: String {
        guard var components = URLComponents(url: streamURL, resolvingAgainstBaseURL: false) else {
            return streamURL.absoluteString
        }

        components.query = nil
        components.fragment = nil

        if let normalizedURL = components.url {
            return normalizedURL.absoluteString
        }

        let normalizedString = components.string ?? ""
        return normalizedString.isEmpty ? streamURL.absoluteString : normalizedString
    }

    // `requestHeaders` is a runtime-only field: it is intentionally excluded from
    // `CodingKeys`, so it never survives a Codable round-trip (always decodes to
    // `nil`). The synthesized Equatable/Hashable would still include it, which made
    // equality depend on a field that the encoded form drops — a `StreamInfo`
    // carrying headers would compare unequal to its own round-tripped copy. That
    // inconsistency propagated up through `PlayerSessionRequest` and broke
    // `dismissWindow(id:value:)` window matching. Custom conformance keeps equality
    // and hashing consistent with the Codable contract by excluding `requestHeaders`.
    static func == (lhs: StreamInfo, rhs: StreamInfo) -> Bool {
        lhs.streamURL == rhs.streamURL
            && lhs.quality == rhs.quality
            && lhs.codec == rhs.codec
            && lhs.audio == rhs.audio
            && lhs.source == rhs.source
            && lhs.hdr == rhs.hdr
            && lhs.fileName == rhs.fileName
            && lhs.sizeBytes == rhs.sizeBytes
            && lhs.debridService == rhs.debridService
            && lhs.recoveryContext == rhs.recoveryContext
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(streamURL)
        hasher.combine(quality)
        hasher.combine(codec)
        hasher.combine(audio)
        hasher.combine(source)
        hasher.combine(hdr)
        hasher.combine(fileName)
        hasher.combine(sizeBytes)
        hasher.combine(debridService)
        hasher.combine(recoveryContext)
    }

    var sizeString: String {
        guard let bytes = sizeBytes else { return "" }
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    var qualityBadge: String {
        var parts: [String] = []
        if quality != .unknown { parts.append(quality.rawValue) }
        if hdr != .sdr { parts.append(hdr.rawValue) }
        if codec != .unknown { parts.append(codec.rawValue) }
        if audio != .unknown { parts.append(audio.rawValue) }
        return parts.joined(separator: " / ")
    }
}

extension StreamInfo {
    /// Direct-play contract (see `DirectPlayPolicy`): VPStudio always plays the
    /// stream's bytes directly through a native engine — never transcodes or
    /// remuxes. Computed, no stored property / schema change.
    var playbackMode: PlaybackMode {
        DirectPlayPolicy.playbackMode(for: self)
    }

    /// Convenience flag, backed by `DirectPlayPolicy`. Always true today.
    var isDirectPlay: Bool {
        DirectPlayPolicy.isDirectPlay(self)
    }
}

extension StreamRecoveryContext {
    func enrichedForDownloadPersistence(
        fileName: String,
        sizeBytes: Int64?,
        debridService: String
    ) -> StreamRecoveryContext {
        StreamRecoveryContext(
            infoHash: infoHash,
            preferredService: preferredService,
            magnetURI: magnetURI,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            torrentId: torrentId,
            resolvedDebridService: debridService,
            resolvedFileName: fileName,
            resolvedFileSizeBytes: sizeBytes
        ) ?? self
    }
}
