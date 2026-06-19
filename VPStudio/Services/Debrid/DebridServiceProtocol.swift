import Foundation

enum CacheStatus: Sendable, Equatable {
    case cached(fileId: String?, fileName: String?, fileSize: Int64?)
    case notCached
    case unknown
}

struct DebridAccountInfo: Sendable {
    var username: String
    var email: String?
    var premiumExpiry: Date?
    var isPremium: Bool?
}

protocol DebridServiceProtocol: Sendable {
    var serviceType: DebridServiceType { get }

    func validateToken() async throws -> Bool
    func getAccountInfo() async throws -> DebridAccountInfo
    func checkCache(hashes: [String]) async throws -> [String: CacheStatus]
    func addMagnet(hash: String) async throws -> String
    func addMagnet(hash: String, magnetURI: String?) async throws -> String
    func selectFiles(torrentId: String, fileIds: [Int]) async throws
    func selectMatchingEpisodeFile(
        torrentId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> Bool
    func cleanupRemoteTransfer(torrentId: String) async throws
    func getStreamURL(torrentId: String) async throws -> StreamInfo
    func unrestrict(link: String) async throws -> URL
}

extension DebridServiceProtocol {
    func addMagnet(hash: String, magnetURI: String?) async throws -> String {
        try await addMagnet(hash: hash)
    }

    func selectMatchingEpisodeFile(
        torrentId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> Bool {
        let _ = torrentId
        let _ = seasonNumber
        let _ = episodeNumber
        let _ = resolvedFileNameHint
        let _ = resolvedFileSizeHint
        return false
    }

    func cleanupRemoteTransfer(torrentId: String) async throws {
        let _ = torrentId
    }
}

enum DebridStreamMetadata {
    static func quality(from candidates: [String?]) -> VideoQuality {
        firstNonDefault(in: candidates, defaultValue: .unknown, parse: VideoQuality.parse(from:))
    }

    static func codec(from candidates: [String?]) -> VideoCodec {
        firstNonDefault(in: candidates, defaultValue: .unknown, parse: VideoCodec.parse(from:))
    }

    static func audio(from candidates: [String?]) -> AudioFormat {
        firstNonDefault(in: candidates, defaultValue: .unknown, parse: AudioFormat.parse(from:))
    }

    static func source(from candidates: [String?]) -> SourceType {
        firstNonDefault(in: candidates, defaultValue: .unknown, parse: SourceType.parse(from:))
    }

    static func hdr(from candidates: [String?]) -> HDRFormat {
        firstNonDefault(in: candidates, defaultValue: .sdr, parse: HDRFormat.parse(from:))
    }

    private static func firstNonDefault<T: Equatable>(
        in candidates: [String?],
        defaultValue: T,
        parse: (String) -> T
    ) -> T {
        for candidate in candidates {
            guard let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !candidate.isEmpty else {
                continue
            }
            let parsed = parse(candidate)
            if parsed != defaultValue {
                return parsed
            }
        }
        return defaultValue
    }
}

enum DebridMagnetInput {
    static func preferredMagnetURI(hash: String, suppliedMagnetURI: String?) throws -> String {
        let normalizedHash = try DebridHashValidator.validatedInfoHash(hash)
        guard let candidate = suppliedMagnetURI?.trimmingCharacters(in: .whitespacesAndNewlines),
              !candidate.isEmpty else {
            return bareMagnetURI(for: normalizedHash)
        }

        if let components = URLComponents(string: candidate),
           components.scheme?.lowercased() == "magnet" {
            let xtItems = components.queryItems?.filter { $0.name.lowercased() == "xt" } ?? []
            if !xtItems.isEmpty {
                for item in xtItems {
                    guard let value = item.value,
                          value.lowercased().hasPrefix("urn:btih:") else {
                        continue
                    }

                    let rawCandidateHash = String(value.dropFirst("urn:btih:".count))
                    // Normalize both sides (handles hex/base32 mismatch) so a magnet
                    // whose btih is base32 still matches and keeps its tracker list.
                    if DebridHashValidator.normalizedInfoHash(rawCandidateHash) == normalizedHash {
                        return candidate
                    }
                }
                return bareMagnetURI(for: normalizedHash)
            }

            return bareMagnetURI(for: normalizedHash)
        }

        guard let candidateHash = JSONValueParsing.extractInfoHash(from: candidate) else {
            return candidate.localizedCaseInsensitiveContains(normalizedHash)
                ? candidate
                : bareMagnetURI(for: normalizedHash)
        }

        return candidateHash == normalizedHash ? candidate : bareMagnetURI(for: normalizedHash)
    }

    static func bareMagnetURI(for normalizedHash: String) -> String {
        "magnet:?xt=urn:btih:\(normalizedHash)"
    }
}

enum DebridHashValidator {
    private static let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")

    static func normalizedInfoHash(_ hash: String) -> String? {
        let trimmed = hash.trimmingCharacters(in: .whitespacesAndNewlines)

        // BitTorrent v1 info-hashes are sometimes published in 32-character RFC 4648
        // base32 form (some Torznab/indexer feeds emit `urn:btih:` this way). Decode
        // to the canonical 40-char hex so these torrents aren't rejected as invalid —
        // and so a supplied magnet that uses a base32 btih still matches the requested
        // hash and keeps its tracker list instead of being rebuilt as a bare magnet.
        if trimmed.count == 32, let hex = hexFromBase32(trimmed) {
            return hex
        }

        guard trimmed.count == 40 || trimmed.count == 64 else {
            return nil
        }

        guard trimmed.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) else {
            return nil
        }

        return trimmed.lowercased()
    }

    /// Decodes a 32-character RFC 4648 base32 string (the canonical encoding of a
    /// 20-byte BitTorrent v1 info-hash) to its 40-character lowercase hex form.
    /// Returns nil if the input is not exactly 32 valid base32 characters.
    private static func hexFromBase32(_ input: String) -> String? {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(20)
        var accumulator = 0
        var bitsPending = 0

        for scalar in input.unicodeScalars {
            guard let value = base32Value(scalar) else { return nil }
            accumulator = (accumulator << 5) | value
            bitsPending += 5
            if bitsPending >= 8 {
                bitsPending -= 8
                bytes.append(UInt8((accumulator >> bitsPending) & 0xFF))
                accumulator &= (1 << bitsPending) - 1
            }
        }

        // A valid info-hash is exactly 20 bytes; the 32-char input leaves no
        // partial-byte remainder (32 × 5 = 160 bits = 20 bytes).
        guard bytes.count == 20 else { return nil }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func base32Value(_ scalar: Unicode.Scalar) -> Int? {
        switch scalar {
        case "A"..."Z": return Int(scalar.value - Unicode.Scalar("A").value)
        case "a"..."z": return Int(scalar.value - Unicode.Scalar("a").value)
        case "2"..."7": return Int(scalar.value - Unicode.Scalar("2").value) + 26
        default: return nil
        }
    }

    static func validatedInfoHash(_ hash: String) throws -> String {
        guard let normalized = normalizedInfoHash(hash) else {
            throw DebridError.invalidHash(hash)
        }
        return normalized
    }
}

enum DebridError: LocalizedError, Equatable, Sendable {
    case unauthorized
    case notPremium
    case invalidHash(String)
    case torrentNotFound(String)
    case fileNotReady(String)
    case rateLimited
    case unavailableForLegalReasons(String)
    case httpError(Int, String)
    case networkError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Invalid or expired API token"
        case .notPremium: return "Premium account required"
        case .invalidHash(let hash): return "Invalid torrent hash: \(hash)"
        case .torrentNotFound(let id): return "Torrent not found: \(id)"
        case .fileNotReady(let msg): return "File not ready: \(msg)"
        case .rateLimited: return "Rate limited. Try again shortly."
        case .unavailableForLegalReasons(let msg): return "Unavailable for legal or regional reasons: \(msg)"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .timeout: return "Request timed out"
        }
    }
}

enum DebridHTTPExecutor {
    private static let initialBackoffNanoseconds: UInt64 = 250_000_000
    private static let maximumBackoffNanoseconds: UInt64 = 5_000_000_000
    private static let maximumRetryAfterNanoseconds: UInt64 = 60_000_000_000
    private static let maxAttempts = 4
    private static let retryableStatusCodes: Set<Int> = [408, 425, 429, 500, 502, 503, 504]
    private static let retryableTransportErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .networkConnectionLost,
        .notConnectedToInternet,
        .resourceUnavailable
    ]

    static func data(
        for request: URLRequest,
        session: URLSession
    ) async throws -> (Data, HTTPURLResponse) {
        try await dataWithRetry(for: request, session: session, attempt: 0)
    }

    private static func dataWithRetry(
        for request: URLRequest,
        session: URLSession,
        attempt: Int
    ) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            try Task.checkCancellation()
            (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where shouldRetry(urlError: urlError) {
            guard attempt < maxAttempts - 1 else {
                throw mapTransportError(urlError)
            }

            try await Task.sleep(
                nanoseconds: retryDelayNanoseconds(from: nil, attempt: attempt)
            )
            return try await dataWithRetry(for: request, session: session, attempt: attempt + 1)
        } catch let urlError as URLError {
            if urlError.code == .cancelled {
                throw CancellationError()
            }
            throw mapTransportError(urlError)
        } catch {
            throw DebridError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DebridError.networkError("Invalid response")
        }

        guard retryableStatusCodes.contains(httpResponse.statusCode) else {
            return (data, httpResponse)
        }

        guard attempt < maxAttempts - 1 else {
            if httpResponse.statusCode == 429 {
                throw DebridError.rateLimited
            }
            return (data, httpResponse)
        }

        let retryAfterNanoseconds = retryDelayNanoseconds(
            from: httpResponse.value(forHTTPHeaderField: "Retry-After"),
            attempt: attempt
        )
        try await Task.sleep(nanoseconds: retryAfterNanoseconds)
        return try await dataWithRetry(for: request, session: session, attempt: attempt + 1)
    }

    private static func retryDelayNanoseconds(from retryAfter: String?, attempt: Int) -> UInt64 {
        let exponentialDelay = min(
            maximumBackoffNanoseconds,
            initialBackoffNanoseconds * UInt64(1 << min(attempt, 5))
        )

        guard let retryAfter else {
            return exponentialDelay
        }

        let trimmed = retryAfter.trimmingCharacters(in: .whitespacesAndNewlines)
        if let retryAfterSeconds = TimeInterval(trimmed), retryAfterSeconds > 0 {
            // Cap in Double space BEFORE converting — a hostile `Retry-After: 1e12` makes
            // UInt64(1e21) trap before the min() clamp can run.
            let cappedSeconds = min(retryAfterSeconds, Double(maximumRetryAfterNanoseconds) / 1_000_000_000)
            let retryAfterDelay = UInt64((cappedSeconds * 1_000_000_000).rounded())
            return min(maximumRetryAfterNanoseconds, max(exponentialDelay, retryAfterDelay))
        }

        guard let retryAfterDate = RetryHeaderDateParser.date(from: trimmed) else {
            return exponentialDelay
        }

        let retryAfterSeconds = retryAfterDate.timeIntervalSinceNow
        guard retryAfterSeconds > 0 else {
            return exponentialDelay
        }

        // Cap in Double space BEFORE converting (a far-future date would overflow UInt64).
        let cappedSeconds = min(retryAfterSeconds, Double(maximumRetryAfterNanoseconds) / 1_000_000_000)
        let retryAfterDelay = UInt64((cappedSeconds * 1_000_000_000).rounded())
        return min(maximumRetryAfterNanoseconds, max(exponentialDelay, retryAfterDelay))
    }

    private static func shouldRetry(urlError: URLError) -> Bool {
        retryableTransportErrorCodes.contains(urlError.code)
    }

    private static func mapTransportError(_ error: URLError) -> DebridError {
        if error.code == .timedOut {
            return .timeout
        }
        if error.code == .networkConnectionLost {
            return .networkError("network connection was lost")
        }
        return .networkError(error.localizedDescription)
    }
}

private enum RetryHeaderDateParser {
    private static let formatters: [DateFormatter] = {
        let formatter1 = DateFormatter()
        formatter1.locale = Locale(identifier: "en_US_POSIX")
        formatter1.timeZone = TimeZone(secondsFromGMT: 0)
        formatter1.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"

        let formatter2 = DateFormatter()
        formatter2.locale = Locale(identifier: "en_US_POSIX")
        formatter2.timeZone = TimeZone(secondsFromGMT: 0)
        formatter2.dateFormat = "EEEE',' dd-MMM-yy HH':'mm':'ss zzz"

        let formatter3 = DateFormatter()
        formatter3.locale = Locale(identifier: "en_US_POSIX")
        formatter3.timeZone = TimeZone(secondsFromGMT: 0)
        formatter3.dateFormat = "EEE MMM d HH':'mm':'ss yyyy"

        return [formatter1, formatter2, formatter3]
    }()

    static func date(from value: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
