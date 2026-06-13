import Foundation

actor RealDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType = .realDebrid
    private let apiToken: String
    private let baseURL = "https://api.real-debrid.com/rest/1.0"
    private let session: URLSession
    private var cacheEndpointAvailability: CacheEndpointAvailability = .unknown

    private enum CacheEndpointAvailability {
        case unknown
        case available
        case disabled
    }

    init(apiToken: String, session: URLSession = .shared) {
        self.apiToken = apiToken
        self.session = session
    }

    func validateToken() async throws -> Bool {
        let _: RDUserResponse = try await request(method: "GET", path: "/user")
        return true
    }

    func getAccountInfo() async throws -> DebridAccountInfo {
        let user: RDUserResponse = try await request(method: "GET", path: "/user")
        let formatter = ISO8601DateFormatter()
        let expiry = user.expiration.flatMap { formatter.date(from: $0) }
        return DebridAccountInfo(
            username: user.username,
            email: user.email,
            premiumExpiry: expiry,
            isPremium: user.type == "premium"
        )
    }

    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        guard !hashes.isEmpty else { return [:] }

        var result: [String: CacheStatus] = [:]
        let validHashes = hashes.compactMap(DebridHashValidator.normalizedInfoHash)
        for hash in hashes where DebridHashValidator.normalizedInfoHash(hash) == nil {
            result[hash] = .unknown
        }
        guard !validHashes.isEmpty else { return result }
        if case .disabled = cacheEndpointAvailability {
            return validHashes.reduce(into: result) { result, hash in
                result[hash] = .unknown
            }
        }

        // Batch hashes to keep URL under ~2000 chars. Each hash is 40 chars + 1 separator.
        // Path prefix "/torrents/instantAvailability/" = 30 chars, so ~48 hashes per batch.
        let batchSize = 48
        for batchStart in stride(from: 0, to: validHashes.count, by: batchSize) {
            let batch = Array(validHashes[batchStart ..< min(batchStart + batchSize, validHashes.count)])
            let hashStr = batch.joined(separator: "/")
            let response: [String: [RDCacheVariant]]
            do {
                response = try await request(
                    method: "GET",
                    path: "/torrents/instantAvailability/\(hashStr)"
                )
                cacheEndpointAvailability = .available
            } catch let error as DebridError where Self.isDisabledCacheEndpoint(error) {
                cacheEndpointAvailability = .disabled
                let remainingHashes = validHashes[batchStart...]
                for hash in remainingHashes {
                    result[hash] = .unknown
                }
                break
            }

            for hash in batch {
                let lowered = hash.lowercased()
                if let variants = response[lowered], !variants.isEmpty {
                    result[lowered] = .cached(fileId: nil, fileName: nil, fileSize: nil)
                } else {
                    result[lowered] = .notCached
                }
            }
        }
        return result
    }

    func addMagnet(hash: String) async throws -> String {
        try await addMagnet(hash: hash, magnetURI: nil)
    }

    func addMagnet(hash: String, magnetURI: String?) async throws -> String {
        let magnet = try DebridMagnetInput.preferredMagnetURI(
            hash: hash,
            suppliedMagnetURI: magnetURI
        )
        let body = "magnet=\(Self.formEncodedValue(magnet))"
        let response: RDAddMagnetResponse = try await request(method: "POST", path: "/torrents/addMagnet", body: body)
        return response.id
    }

    func selectFiles(torrentId: String, fileIds: [Int]) async throws {
        let ids = fileIds.isEmpty ? "all" : fileIds.map(String.init).joined(separator: ",")
        let body = "files=\(ids)"
        do {
            let _: EmptyResponse = try await request(method: "POST", path: "/torrents/selectFiles/\(torrentId)", body: body)
        } catch is DecodingError {
            // 204 No Content — file selection succeeded
        }
    }

    func selectMatchingEpisodeFile(torrentId: String, seasonNumber: Int, episodeNumber: Int) async throws -> Bool {
        let info: RDTorrentInfo = try await request(method: "GET", path: "/torrents/info/\(torrentId)")
        guard let matchedFile = preferredEpisodeFile(
            in: info.files,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            resolvedFileNameHint: nil,
            resolvedFileSizeHint: nil
        ) else {
            return false
        }
        try await selectFiles(torrentId: torrentId, fileIds: [matchedFile.id])
        return true
    }

    func selectMatchingEpisodeFile(
        torrentId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> Bool {
        let info: RDTorrentInfo = try await request(method: "GET", path: "/torrents/info/\(torrentId)")
        guard let matchedFile = preferredEpisodeFile(
            in: info.files,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            resolvedFileNameHint: resolvedFileNameHint,
            resolvedFileSizeHint: resolvedFileSizeHint
        ) else {
            return false
        }
        try await selectFiles(torrentId: torrentId, fileIds: [matchedFile.id])
        return true
    }

    func cleanupRemoteTransfer(torrentId: String) async throws {
        do {
            let _: EmptyResponse = try await request(method: "DELETE", path: "/torrents/delete/\(torrentId)")
        } catch is DecodingError {
            // Real-Debrid returns 204 No Content for successful deletes.
        }
    }

    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        let info: RDTorrentInfo = try await request(method: "GET", path: "/torrents/info/\(torrentId)")

        guard info.status == "downloaded" else {
            throw DebridError.fileNotReady(info.status ?? "unknown")
        }

        guard let candidate = preferredStreamLinkCandidate(from: info) else {
            throw DebridError.torrentNotFound(torrentId)
        }

        let unrestricted = try await unrestrictFile(link: candidate.link)
        let fileName = displayFileName(
            unrestrictFileName: unrestricted.filename,
            selectedPath: candidate.file?.path,
            torrentFileName: info.filename
        )
        let sizeBytes = normalizedPositiveBytes(unrestricted.filesize)
            ?? normalizedPositiveBytes(candidate.file?.bytes)
            ?? normalizedPositiveBytes(info.bytes)

        return StreamInfo(
            streamURL: unrestricted.downloadURL,
            quality: VideoQuality.parse(from: fileName),
            codec: VideoCodec.parse(from: fileName),
            audio: AudioFormat.parse(from: fileName),
            source: SourceType.parse(from: fileName),
            hdr: HDRFormat.parse(from: fileName),
            fileName: fileName,
            sizeBytes: sizeBytes,
            debridService: serviceType.rawValue
        )
    }

    func unrestrict(link: String) async throws -> URL {
        try await unrestrictFile(link: link).downloadURL
    }

    private func unrestrictFile(link: String) async throws -> RDUnrestrictedFile {
        let body = "link=\(Self.formEncodedValue(link))"
        let response: RDUnrestrictResponse = try await request(method: "POST", path: "/unrestrict/link", body: body)
        guard let url = URL(string: response.download) else {
            throw DebridError.networkError("Invalid unrestrict URL")
        }
        return RDUnrestrictedFile(
            downloadURL: url,
            filename: response.filename,
            filesize: response.filesize
        )
    }

    private func preferredStreamLinkCandidate(from info: RDTorrentInfo) -> RDStreamLinkCandidate? {
        guard let links = info.links, !links.isEmpty else {
            return nil
        }

        guard let files = info.files, !files.isEmpty else {
            return RDStreamLinkCandidate(link: links[0], file: nil)
        }

        let selectedFiles = files.filter { $0.selected == 1 }
        let linkFiles = selectedFiles.isEmpty ? files : selectedFiles

        if let preferredFile = Self.preferredPlayableFile(in: linkFiles),
           let index = linkFiles.firstIndex(where: { $0.id == preferredFile.id }),
           links.indices.contains(index) {
            return RDStreamLinkCandidate(link: links[index], file: preferredFile)
        }

        if links.count == 1 {
            return RDStreamLinkCandidate(link: links[0], file: linkFiles.first)
        }

        return RDStreamLinkCandidate(link: links[0], file: linkFiles.first)
    }

    func preferredEpisodeFile(
        in files: [RDFile]?,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) -> RDFile? {
        guard let files else { return nil }
        let videoFiles = files.filter { file in
            guard let path = file.path?.lowercased() else { return false }
            return Self.isProbablyVideoFile(path)
        }

        if let exactMatch = bestExactMatch(
            in: videoFiles,
            resolvedFileNameHint: resolvedFileNameHint,
            resolvedFileSizeHint: resolvedFileSizeHint
        ) {
            return exactMatch
        }

        let tokens = episodeMatchTokens(seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        let matchedVideoFiles = videoFiles.filter { file in
            guard let path = file.path?.lowercased() else { return false }
            return tokens.contains { path.contains($0) }
        }

        if matchedVideoFiles.isEmpty, videoFiles.count == 1 {
            return videoFiles.first
        }
        return matchedVideoFiles.max(by: { ($0.bytes ?? 0) < ($1.bytes ?? 0) })
    }

    func bestExactMatch(
        in files: [RDFile],
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) -> RDFile? {
        guard let normalizedHint = Self.normalizedFileName(resolvedFileNameHint) else {
            return nil
        }

        let candidates = files.filter { file in
            Self.normalizedFileName(file.path) == normalizedHint
        }
        guard !candidates.isEmpty else { return nil }

        if let resolvedFileSizeHint {
            if let exactSize = candidates.first(where: { $0.bytes == resolvedFileSizeHint }) {
                return exactSize
            }
        }

        return candidates.max(by: { ($0.bytes ?? 0) < ($1.bytes ?? 0) })
    }

    func episodeMatchTokens(seasonNumber: Int, episodeNumber: Int) -> [String] {
        let s2 = String(format: "%02d", seasonNumber)
        let e2 = String(format: "%02d", episodeNumber)
        return [
            "s\(s2)e\(e2)",
            "\(seasonNumber)x\(e2)",
            "season \(seasonNumber) episode \(episodeNumber)",
            "season.\(seasonNumber).episode.\(episodeNumber)",
            "ep\(e2)"
        ]
    }

    static func isProbablyVideoFile(_ path: String) -> Bool {
        [".mkv", ".mp4", ".avi", ".mov", ".m4v", ".ts"].contains { path.hasSuffix($0) }
    }

    static func preferredPlayableFile(in files: [RDFile]) -> RDFile? {
        files
            .filter { file in
                guard let path = file.path?.lowercased() else { return false }
                return isProbablyVideoFile(path)
            }
            .max(by: { ($0.bytes ?? 0) < ($1.bytes ?? 0) })
    }

    static func normalizedFileName(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed).lastPathComponent.lowercased()
    }

    private static func normalizedDisplayFileName(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lastComponent = URL(fileURLWithPath: trimmed).lastPathComponent
        return lastComponent.isEmpty ? trimmed : lastComponent
    }

    private func displayFileName(
        unrestrictFileName: String?,
        selectedPath: String?,
        torrentFileName: String?
    ) -> String {
        Self.normalizedDisplayFileName(unrestrictFileName)
            ?? Self.normalizedDisplayFileName(selectedPath)
            ?? Self.normalizedDisplayFileName(torrentFileName)
            ?? "Unknown"
    }

    private func normalizedPositiveBytes(_ bytes: Int64?) -> Int64? {
        guard let bytes, bytes > 0 else { return nil }
        return bytes
    }

    private static let formEncodingAllowed = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "-._*"))

    private static func formEncodedValue(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .addingPercentEncoding(withAllowedCharacters: formEncodingAllowed) ?? value
    }

    // MARK: - HTTP

    private func request<T: Decodable>(method: String, path: String, body: String? = nil) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw DebridError.networkError("Invalid request URL")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        if let body {
            urlRequest.httpBody = Data(body.utf8)
            urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }

        let (data, httpResponse) = try await DebridHTTPExecutor.data(for: urlRequest, session: session)

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw DebridError.unauthorized
        case 429:
            throw DebridError.rateLimited
        case 451:
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = message?.isEmpty == false ? message ?? "HTTP 451" : "HTTP 451"
            throw DebridError.unavailableForLegalReasons(
                "Real-Debrid \(path) returned \(detail)"
            )
        default:
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw DebridError.httpError(httpResponse.statusCode, msg)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    internal static func isDisabledCacheEndpoint(_ error: DebridError) -> Bool {
        guard case .httpError(403, let message) = error else {
            return false
        }
        return message.localizedCaseInsensitiveContains("disabled_endpoint")
    }
}

// MARK: - Real-Debrid API Models

private struct RDUserResponse: Sendable {
    let username: String
    let email: String
    let type: String
    let expiration: String?
}
extension RDUserResponse: Decodable {}

private struct RDCacheVariant: Sendable {}
extension RDCacheVariant: Decodable {}

private struct RDAddMagnetResponse: Sendable {
    let id: String
    let uri: String?
}
extension RDAddMagnetResponse: Decodable {}

private struct RDTorrentInfo: Sendable {
    let id: String
    let filename: String?
    let hash: String?
    let bytes: Int64?
    let status: String?
    let links: [String]?
    let files: [RDFile]?
}
extension RDTorrentInfo: Decodable {}

private struct RDStreamLinkCandidate: Sendable {
    let link: String
    let file: RDFile?
}

struct RDFile: Sendable {
    let id: Int
    let path: String?
    let bytes: Int64?
    let selected: Int?
}
extension RDFile: Decodable {}

private struct RDUnrestrictResponse: Sendable {
    let id: String
    let filename: String
    let download: String
    let filesize: Int64?
}
extension RDUnrestrictResponse: Decodable {}

private struct RDUnrestrictedFile: Sendable {
    let downloadURL: URL
    let filename: String
    let filesize: Int64?
}

private struct EmptyResponse: Sendable {}
extension EmptyResponse: Decodable {}
