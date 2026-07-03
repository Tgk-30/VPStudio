import Foundation

protocol OpenSubtitlesServicing: Sendable {
    func search(
        imdbId: String?,
        tmdbId: Int?,
        query: String?,
        season: Int?,
        episode: Int?,
        languages: [String]
    ) async throws -> [Subtitle]

    func downloadSubtitle(fileId: Int) async throws -> String

    func downloadFirstMatch(
        query: String,
        languages: [String]
    ) async throws -> Subtitle

    func downloadFirstMatch(
        query: String,
        languages: [String],
        season: Int?,
        episode: Int?
    ) async throws -> Subtitle

    func downloadFirstMatch(
        imdbId: String?,
        tmdbId: Int?,
        query: String,
        languages: [String],
        season: Int?,
        episode: Int?
    ) async throws -> Subtitle
}

extension OpenSubtitlesServicing {
    func downloadFirstMatch(
        query: String,
        languages: [String],
        season: Int?,
        episode: Int?
    ) async throws -> Subtitle {
        try await downloadFirstMatch(query: query, languages: languages)
    }

    func downloadFirstMatch(
        imdbId: String?,
        tmdbId: Int?,
        query: String,
        languages: [String],
        season: Int?,
        episode: Int?
    ) async throws -> Subtitle {
        try await downloadFirstMatch(
            query: query,
            languages: languages,
            season: season,
            episode: episode
        )
    }
}

/// OpenSubtitles.com REST API client
actor OpenSubtitlesService {
    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        return URLSession(configuration: configuration)
    }()
    private static let defaultBaseURL = "https://api.opensubtitles.com/api/v1"

    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?
    private var lastRequestDate: Date?
    private var nextAllowedRequestDate: Date?
    private let minimumRequestInterval: TimeInterval = 0.15

    init(apiKey: String, session: URLSession? = nil) {
        self.init(apiKey: apiKey, session: session, baseURL: Self.defaultBaseURL)
    }

    init(apiKey: String, session: URLSession? = nil, baseURL: String) {
        self.apiKey = apiKey
        self.session = session ?? Self.defaultSession
        let sanitizedBaseURL = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.baseURL = URL(string: sanitizedBaseURL) ?? URL(string: Self.defaultBaseURL) ?? URL(fileURLWithPath: "/")
    }

    // MARK: - Authentication

    func login(username: String, password: String) async throws -> String {
        let body: [String: String] = ["username": username, "password": password]
        let response: LoginResponse = try await post(path: "/login", body: body)
        authToken = response.token
        return response.token
    }

    // MARK: - Search

    func search(imdbId: String? = nil, tmdbId: Int? = nil, query: String? = nil,
                season: Int? = nil, episode: Int? = nil, languages: [String] = ["en"]) async throws -> [Subtitle] {
        var params: [String: String] = [
            "languages": languages.joined(separator: ","),
        ]
        if let imdbId = IMDbIdentifierPolicy.appScopedID(in: imdbId) {
            params["imdb_id"] = String(imdbId.dropFirst(2))
        }
        if let tmdbId { params["tmdb_id"] = String(tmdbId) }
        if let query { params["query"] = query }
        if let season { params["season_number"] = String(season) }
        if let episode { params["episode_number"] = String(episode) }

        let response: SubtitleSearchResponse = try await get(path: "/subtitles", params: params)
        return response.data.compactMap { usableSubtitle(from: $0) }
    }

    func searchByHash(movieHash: String, movieSize: Int64) async throws -> [Subtitle] {
        let params: [String: String] = [
            "moviehash": movieHash,
            "moviebytesize": String(movieSize),
        ]
        let response: SubtitleSearchResponse = try await get(path: "/subtitles", params: params)
        return response.data.compactMap { usableSubtitle(from: $0) }
    }

    // MARK: - Download

    func getDownloadURL(fileId: Int) async throws -> URL {
        let body: [String: Any] = ["file_id": fileId]
        let response: DownloadResponse = try await post(path: "/download", body: body)
        guard let url = URL(string: response.link),
              Self.permitsSubtitleDownloadURL(url) else {
            throw SubtitleError.invalidDownloadURL
        }
        return url
    }

    func downloadSubtitle(fileId: Int) async throws -> String {
        let url = try await getDownloadURL(fileId: fileId)
        let request = URLRequest(url: url)
        let (data, response) = try await sendRequest(
            request,
            maximumBytes: SubtitleParser.maximumInputBytes
        )
        guard let finalURL = response.url,
              Self.permitsSubtitleDownloadURL(finalURL) else {
            throw SubtitleError.invalidDownloadURL
        }
        guard data.count <= SubtitleParser.maximumInputBytes else {
            throw SubtitleError.subtitleDownloadTooLarge
        }
        guard let content = decodeSubtitleContent(from: data) else {
            throw SubtitleError.decodingFailed
        }
        return content
    }

    func downloadFirstMatch(
        query: String,
        languages: [String] = ["en"]
    ) async throws -> Subtitle {
        try await downloadFirstMatch(query: query, languages: languages, season: nil, episode: nil)
    }

    func downloadFirstMatch(
        query: String,
        languages: [String] = ["en"],
        season: Int?,
        episode: Int?
    ) async throws -> Subtitle {
        let candidates = try await search(
            imdbId: nil,
            tmdbId: nil,
            query: query,
            season: season,
            episode: episode,
            languages: languages
        )
        return try await downloadFirstRenderableSubtitle(from: candidates)
    }

    func downloadFirstMatch(
        imdbId: String?,
        tmdbId: Int?,
        query: String,
        languages: [String] = ["en"],
        season: Int?,
        episode: Int?
    ) async throws -> Subtitle {
        let candidates = try await search(
            imdbId: imdbId,
            tmdbId: tmdbId,
            query: query,
            season: season,
            episode: episode,
            languages: languages
        )
        return try await downloadFirstRenderableSubtitle(from: candidates)
    }

    private func downloadFirstRenderableSubtitle(from candidates: [Subtitle]) async throws -> Subtitle {
        guard let selected = candidates.first(where: { $0.fileId != nil && $0.isSupportedSubtitle }),
              let fileId = selected.fileId else {
            throw SubtitleError.noSubtitlesFound
        }

        let content = try await downloadSubtitle(fileId: fileId)
        let fileURL = try writeTemporarySubtitleFile(
            content: content,
            fileName: selected.fileName,
            format: selected.format
        )

        var hydrated = selected
        hydrated.url = fileURL.absoluteString
        return hydrated
    }

    // MARK: - Networking

    private func get<T: Decodable & Sendable>(path: String, params: [String: String]) async throws -> T {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = normalizedPath(for: path)
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            throw SubtitleError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("VPStudio v1.0", forHTTPHeaderField: "User-Agent")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await sendRequest(
            request,
            maximumBytes: HTTPResponseBudget.subtitleMetadata
        )
        return try decodeResponse(data, as: T.self)
    }

    private func post<T: Decodable & Sendable>(path: String, body: Any) async throws -> T {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = normalizedPath(for: path)

        guard let url = components.url else { throw SubtitleError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("VPStudio v1.0", forHTTPHeaderField: "User-Agent")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await sendRequest(
            request,
            maximumBytes: HTTPResponseBudget.subtitleMetadata
        )
        return try decodeResponse(data, as: T.self)
    }

    private func sendRequest(
        _ request: URLRequest,
        maximumBytes: Int
    ) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            attempt += 1
            try await waitForRequestSlot()

            let (data, response): (Data, URLResponse)
            let redirectGuard = OpenSubtitlesRedirectGuard(originalRequest: request)
            do {
                (data, response) = try await BoundedHTTPResponseLoader.data(
                    for: request,
                    session: session,
                    delegate: redirectGuard,
                    maximumBytes: maximumBytes
                )
            } catch is BoundedHTTPResponseError {
                if maximumBytes == SubtitleParser.maximumInputBytes {
                    throw SubtitleError.subtitleDownloadTooLarge
                }
                throw SubtitleError.httpError(0)
            } catch let urlError as URLError where urlError.code == .cancelled && redirectGuard.blockedRedirectURL != nil {
                throw SubtitleError.invalidDownloadURL
            } catch let urlError as URLError {
                // A transient transport failure (timeout/offline/connection-lost) is NOT a
                // config error — don't mislabel it as "Invalid subtitle API URL". Propagate
                // cancellation as cancellation; map the rest to a generic transport error.
                if urlError.code == .cancelled { throw CancellationError() }
                if urlError.code == .badURL { throw SubtitleError.invalidURL }
                throw SubtitleError.httpError(0)
            }
            guard let http = response as? HTTPURLResponse else {
                throw SubtitleError.httpError(0)
            }
            guard OpenSubtitlesRedirectPolicy.permitsFinalResponse(for: request, responseURL: http.url) else {
                throw SubtitleError.invalidDownloadURL
            }

            switch http.statusCode {
            case 200...299:
                lastRequestDate = Date()
                return (data, http)
            case 401:
                authToken = nil
                throw SubtitleError.unauthorized
            case 429:
                let delay = retryAfterDelay(from: http) ?? minimumRequestInterval
                nextAllowedRequestDate = Date().addingTimeInterval(max(delay, minimumRequestInterval))
                if attempt < 2 {
                    continue
                }
                throw SubtitleError.httpError(429)
            default:
                throw SubtitleError.httpError(http.statusCode)
            }
        }
    }

    private func waitForRequestSlot() async throws {
        let now = Date()
        let earliestAllowed = max(
            nextAllowedRequestDate ?? now,
            lastRequestDate?.addingTimeInterval(minimumRequestInterval) ?? now
        )
        let delay = earliestAllowed.timeIntervalSince(now)
        if delay > 0 {
            try await Task.sleep(nanoseconds: Self.nanoseconds(for: delay))
        }
    }

    private func retryAfterDelay(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return Double(value).map { max($0, 0) }
    }

    private func normalizedPath(for endpoint: String) -> String {
        let basePath = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch (basePath.isEmpty, trimmedEndpoint.isEmpty) {
        case (true, true):
            return "/"
        case (true, false):
            return "/\(trimmedEndpoint)"
        case (false, true):
            return "/\(basePath)"
        case (false, false):
            return "/\(basePath)/\(trimmedEndpoint)"
        }
    }

    private func decodeResponse<T: Decodable & Sendable>(_ data: Data, as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(T.self, from: data) {
            return decoded
        }
        if let wrapped = try? decoder.decode(EnvelopeResponse<T>.self, from: data) {
            return wrapped.data
        }
        throw SubtitleError.decodingFailed
    }

    private func usableSubtitle(from item: SubtitleItem) -> Subtitle? {
        let attr = item.attributes
        let supportedFile = attr.files.first(where: { SubtitleFormat.parse(from: $0.fileName).isSupportedSubtitle })
        let hasFiles = !attr.files.isEmpty
        let file = hasFiles ? (supportedFile ?? attr.files.first) : nil
        let fileName = file?.fileName ?? attr.release ?? "Unknown"
        let format = file.map { SubtitleFormat.parse(from: $0.fileName) } ?? SubtitleFormat.parse(from: fileName)
        if hasFiles, !format.isSupportedSubtitle {
            return nil
        }

        return Subtitle(
            id: String(item.id),
            language: attr.language,
            fileName: fileName,
            url: "",
            format: format,
            fileId: file?.fileId,
            rating: attr.ratings,
            downloadCount: attr.downloadCount,
            isHearingImpaired: attr.hearingImpaired,
            source: "OpenSubtitles"
        )
    }

    func decodeSubtitleContent(from data: Data) -> String? {
        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .isoLatin1]
        for encoding in encodings {
            if (encoding == .utf8 || encoding == .isoLatin1), !isLikelyTextSubtitleData(data) {
                continue
            }
            if let content = String(data: data, encoding: encoding),
               isLikelySubtitleText(content) {
                return content.trimmingLeadingBOM()
            }
        }
        return nil
    }

    func isLikelyTextSubtitleData(_ data: Data) -> Bool {
        guard !data.isEmpty else { return true }
        guard data.count <= SubtitleParser.maximumInputBytes else { return false }
        var controlCount = 0
        for byte in data {
            if byte == 0 { return false }
            if byte < 0x20, byte != 0x09, byte != 0x0A, byte != 0x0D {
                controlCount += 1
            }
        }
        return Double(controlCount) / Double(data.count) < 0.05
    }

    func isLikelySubtitleText(_ content: String) -> Bool {
        guard !content.isEmpty else { return true }
        guard content.utf8.count <= SubtitleParser.maximumInputBytes else { return false }
        var controlCount = 0
        var totalCount = 0
        for scalar in content.unicodeScalars {
            totalCount += 1
            if CharacterSet.controlCharacters.contains(scalar),
               scalar != "\t",
               scalar != "\n",
               scalar != "\r" {
                controlCount += 1
            }
        }
        return totalCount == 0 || Double(controlCount) / Double(totalCount) < 0.05
    }

    func writeTemporarySubtitleFile(
        content: String,
        fileName: String,
        format: SubtitleFormat
    ) throws -> URL {
        let resolved = format == .unknown ? SubtitleFormat.parse(from: fileName) : format
        let extensionForFile = resolved == .unknown ? "srt" : resolved.rawValue

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(extensionForFile)
        try content.trimmingLeadingBOM().write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private nonisolated static func permitsSubtitleDownloadURL(_ url: URL) -> Bool {
        OpenSubtitlesRedirectPolicy.permitsPublicHTTPURL(url)
    }
}

private final class OpenSubtitlesRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let originalRequest: URLRequest
    private let lock = NSLock()
    private var blockedURL: URL?

    init(originalRequest: URLRequest) {
        self.originalRequest = originalRequest
    }

    var blockedRedirectURL: URL? {
        lock.lock()
        defer { lock.unlock() }
        return blockedURL
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard OpenSubtitlesRedirectPolicy.allowsRedirect(from: originalRequest, to: request) else {
            lock.lock()
            blockedURL = request.url
            lock.unlock()
            completionHandler(nil)
            task.cancel()
            return
        }

        completionHandler(request)
    }
}

enum OpenSubtitlesRedirectPolicy {
    static func allowsRedirect(from originalRequest: URLRequest, to redirectRequest: URLRequest) -> Bool {
        permitsFinalResponse(for: originalRequest, responseURL: redirectRequest.url)
    }

    static func permitsFinalResponse(for originalRequest: URLRequest, responseURL: URL?) -> Bool {
        guard let responseURL,
              permitsPublicHTTPURL(responseURL) else {
            return false
        }

        guard containsSensitiveCredential(originalRequest) else {
            return true
        }

        guard let originalHost = normalizedHost(originalRequest.url),
              let responseHost = normalizedHost(responseURL) else {
            return false
        }
        return originalHost == responseHost
    }

    static func permitsPublicHTTPURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host,
              !host.isEmpty,
              !PrivateNetworkHostPolicy.isPrivateOrReserved(host: host),
              !PublicNetworkHostResolver.resolvesToPrivateOrReservedAddress(host: host) else {
            return false
        }
        return true
    }

    private static func containsSensitiveCredential(_ request: URLRequest) -> Bool {
        if request.value(forHTTPHeaderField: "Api-Key")?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return true
        }
        if request.value(forHTTPHeaderField: "Authorization")?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return true
        }
        return false
    }

    private static func normalizedHost(_ url: URL?) -> String? {
        guard let url,
              let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host else {
            return nil
        }
        return host
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }
}

extension OpenSubtitlesService: OpenSubtitlesServicing {}

// MARK: - Response Models

private struct LoginResponse: Sendable {
    let token: String
}
extension LoginResponse: Decodable {}

private struct EnvelopeResponse<T: Decodable & Sendable>: Sendable {
    let data: T
}
extension EnvelopeResponse: Decodable {}

private struct SubtitleSearchResponse: Sendable {
    let data: [SubtitleItem]
}
extension SubtitleSearchResponse: Decodable {}

private struct SubtitleItem: Sendable {
    let id: Int
    let attributes: SubtitleAttributes
}
extension SubtitleItem: Decodable {}

private struct SubtitleAttributes: Sendable {
    let language: String
    let release: String?
    // Display-only metadata — optional so one item missing a key doesn't fail the WHOLE
    // /subtitles array decode (which would return zero subtitles instead of the valid ones).
    let ratings: Double?
    let downloadCount: Int?
    let hearingImpaired: Bool?
    let files: [SubtitleFile]

    enum CodingKeys: String, CodingKey {
        case language, release, ratings, files
        case downloadCount = "download_count"
        case hearingImpaired = "hearing_impaired"
    }
}
extension SubtitleAttributes: Decodable {}

private struct SubtitleFile: Sendable {
    let fileId: Int
    let fileName: String

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileName = "file_name"
    }
}
extension SubtitleFile: Decodable {}

private struct DownloadResponse: Sendable {
    let link: String
}
extension DownloadResponse: Decodable {}

// MARK: - Errors

enum SubtitleError: LocalizedError, Equatable {
    case invalidURL
    case httpError(Int)
    case unauthorized
    case decodingFailed
    case invalidDownloadURL
    case subtitleDownloadTooLarge
    case noSubtitlesFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid subtitle API URL"
        case .httpError(let code): return "Subtitle API error: HTTP \(code)"
        case .unauthorized: return "OpenSubtitles authorization expired"
        case .decodingFailed: return "Failed to decode subtitle content"
        case .invalidDownloadURL: return "Invalid subtitle download URL"
        case .subtitleDownloadTooLarge: return "Subtitle download is too large"
        case .noSubtitlesFound: return "No subtitles found"
        }
    }
}

private extension String {
    func trimmingLeadingBOM() -> String {
        guard let first = unicodeScalars.first,
              first == UnicodeScalar(0xFEFF) else {
            return self
        }
        return String(dropFirst())
    }
}

private extension OpenSubtitlesService {
    static func nanoseconds(for interval: TimeInterval) -> UInt64 {
        // Cap before converting — an unbounded server `Retry-After` would overflow UInt64 and trap.
        let capped = min(max(interval, 0), 60)
        return UInt64((capped * 1_000_000_000).rounded())
    }
}
