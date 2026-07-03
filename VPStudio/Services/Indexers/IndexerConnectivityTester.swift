import Foundation

enum IndexerConnectivityError: LocalizedError {
    case invalidBaseURL
    case missingAPIKey
    case invalidResponse
    case badStatusCode(Int)
    case incompatibleManifest

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid indexer base URL."
        case .missingAPIKey:
            return "API key is required for this indexer."
        case .invalidResponse:
            return "Indexer did not return a valid HTTP response."
        case .badStatusCode(let code):
            return "Indexer returned HTTP \(code)."
        case .incompatibleManifest:
            return "Indexer manifest is not compatible with VPStudio search."
        }
    }
}

enum IndexerRequestError: LocalizedError, Equatable {
    case blockedRedirect(URL?)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .blockedRedirect:
            return "Indexer redirect was blocked."
        case .rateLimited:
            return "Indexer rate limit was exceeded."
        }
    }
}

private final class IndexerRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
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
        guard IndexerRedirectPolicy.allowsRedirect(from: originalRequest, to: request) else {
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

enum IndexerRedirectPolicy {
    static func permitsInitialRequest(_ request: URLRequest) -> Bool {
        guard let url = request.url,
              IndexerURLSecurityPolicy.permits(url: url),
              normalizedHost(url) != nil else {
            return false
        }
        if containsSensitiveCredential(request),
           !IndexerURLSecurityPolicy.permitsCredentialedTransport(url: url) {
            return false
        }
        // The initial destination is the user-typed indexer base URL — trusted
        // configuration, not attacker-supplied data. Do not pre-resolve it against
        // the private-address blocklist: split-horizon DNS, Tailscale, and VPN
        // setups legitimately resolve a user's own HTTPS hostname to a private
        // address, and the synchronous getaddrinfo would block the shared limiter
        // actor. Resolver screening still applies to redirected (cross-host)
        // destinations via `permitsFinalResponse`.
        return true
    }

    /// Gate for routine search traffic to an already-persisted indexer config.
    /// Enforces the scheme/host base-URL policy but not the API-key
    /// cleartext-transport rule: configs saved before that rule existed must keep
    /// returning results, while Settings validation and the connectivity tester
    /// (`permitsInitialRequest`) steer users toward compliant base URLs.
    static func permitsSearchTraffic(_ request: URLRequest) -> Bool {
        guard let url = request.url,
              IndexerURLSecurityPolicy.permits(url: url),
              normalizedHost(url) != nil else {
            return false
        }
        return true
    }

    static func allowsRedirect(from originalRequest: URLRequest, to redirectRequest: URLRequest) -> Bool {
        guard let redirectURL = redirectRequest.url,
              permitsFinalResponse(for: originalRequest, responseURL: redirectURL) else {
            return false
        }
        return true
    }

    static func permitsFinalResponse(for originalRequest: URLRequest, responseURL: URL?) -> Bool {
        guard let responseURL,
              IndexerURLSecurityPolicy.permits(url: responseURL) else {
            return false
        }

        let originalHost = normalizedHost(originalRequest.url)
        guard let responseHost = normalizedHost(responseURL) else {
            return false
        }

        // Whether the response landed somewhere other than the user-configured
        // destination (i.e. a redirect changed host or scheme). The transport and
        // resolver screens below exist to stop hostile redirects; the original
        // destination was already vetted before the request went out, and
        // re-resolving the user's own hostname breaks split-horizon DNS /
        // Tailscale setups that legitimately resolve to private addresses.
        // Port is part of the origin: a same-host redirect onto a different
        // port is a different service (e.g. Prowlarr on :9696 redirecting to
        // another daemon on :8080) and must re-pass the credential and
        // resolver screens rather than riding the original vetting.
        let destinationChanged = originalHost != responseHost
            || originalRequest.url?.scheme?.lowercased() != responseURL.scheme?.lowercased()
            || originalRequest.url?.port != responseURL.port

        let carriesSensitiveCredential = containsSensitiveCredential(originalRequest)
        if carriesSensitiveCredential,
           destinationChanged,
           !IndexerURLSecurityPolicy.permitsCredentialedTransport(url: responseURL) {
            return false
        }

        guard PrivateNetworkHostPolicy.isPrivateOrReserved(host: responseHost) else {
            if destinationChanged,
               PublicNetworkHostResolver.resolvesToPrivateOrReservedAddress(host: responseHost) {
                return false
            }
            if carriesSensitiveCredential {
                guard let originalHost else {
                    return false
                }
                guard sameHost(originalHost, responseHost) else {
                    return false
                }
            }
            return true
        }

        guard let originalHost else {
            return false
        }

        return sameHost(originalHost, responseHost) && IndexerURLSecurityPolicy.isLocalOrPrivateHost(originalHost)
    }

    private static func containsSensitiveCredential(_ request: URLRequest) -> Bool {
        if request.value(forHTTPHeaderField: "X-Api-Key")?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return true
        }

        guard let url = request.url,
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return false
        }

        return queryItems.contains { item in
            item.name.caseInsensitiveCompare("apikey") == .orderedSame
                && item.value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    private static func sameHost(_ lhs: URL?, _ rhs: URL) -> Bool {
        guard let lhsHost = normalizedHost(lhs),
              let rhsHost = normalizedHost(rhs) else {
            return false
        }
        return sameHost(lhsHost, rhsHost)
    }

    private static func sameHost(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs
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

/// Outcome of a successful connectivity test, carrying any metadata that the
/// caller can use to enrich the stored indexer configuration.
struct IndexerConnectivityResult: Equatable {
    /// The human-readable addon name discovered from a Stremio manifest, when
    /// present. `nil` for indexer types that do not expose a name.
    var discoveredName: String?
}

enum IndexerConnectivityTester {
    @discardableResult
    static func testConnection(for config: IndexerConfig, session: URLSession = .shared) async throws -> IndexerConnectivityResult {
        let request = try makeRequest(for: config)
        let limiter = IndexerRequestLimiter()
        let (data, response) = try await limiter.data(for: request, session: session)
        guard let http = response as? HTTPURLResponse else {
            throw IndexerConnectivityError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw IndexerConnectivityError.badStatusCode(http.statusCode)
        }
        return try validatePayload(data, for: config)
    }

    static func makeRequest(for config: IndexerConfig) throws -> URLRequest {
        let url: URL

        switch config.indexerType {
        case .apiBay:
            let baseURL = config.baseURL ?? "https://apibay.org"
            url = try buildURL(baseURL: baseURL, path: "/q.php", queryItems: [
                URLQueryItem(name: "q", value: "test"),
                URLQueryItem(name: "cat", value: "0"),
            ])

        case .yts:
            let baseURL = config.baseURL ?? "https://yts.torrentbay.st"
            url = try buildURL(baseURL: baseURL, path: "/api/v2/list_movies.json", queryItems: [
                URLQueryItem(name: "limit", value: "1"),
            ])

        case .eztv:
            let baseURL = config.baseURL ?? "https://eztvx.to"
            url = try buildURL(baseURL: baseURL, path: "/api/get-torrents", queryItems: [
                URLQueryItem(name: "limit", value: "1"),
            ])

        case .jackett, .torznab:
            guard let baseURL = config.baseURL else {
                throw IndexerConnectivityError.invalidBaseURL
            }
            let endpointPath = config.endpointPath.isEmpty ? "/api" : config.endpointPath
            let apiKey = (config.apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiKey.isEmpty else {
                throw IndexerConnectivityError.missingAPIKey
            }
            var queryItems = [
                URLQueryItem(name: "t", value: "caps"),
            ]
            if config.apiKeyTransport == .query {
                queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
            }
            url = try buildURL(baseURL: baseURL, path: endpointPath, queryItems: queryItems)

        case .prowlarr:
            guard let baseURL = config.baseURL else {
                throw IndexerConnectivityError.invalidBaseURL
            }
            let endpointPath = config.endpointPath.isEmpty ? "/api/v1/search" : config.endpointPath
            let apiKey = (config.apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiKey.isEmpty else {
                throw IndexerConnectivityError.missingAPIKey
            }
            var queryItems = [
                URLQueryItem(name: "query", value: "test"),
            ]
            if config.apiKeyTransport == .query {
                queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
            }
            url = try buildURL(baseURL: baseURL, path: endpointPath, queryItems: queryItems)

        case .zilean:
            guard let baseURL = config.baseURL else {
                throw IndexerConnectivityError.invalidBaseURL
            }
            let endpointPath: String
            if config.endpointPath.isEmpty {
                endpointPath = "/dmm/search"
            } else if config.endpointPath.hasSuffix("/dmm/search") {
                endpointPath = config.endpointPath
            } else {
                endpointPath = "\(config.endpointPath)/dmm/search"
            }
            url = try buildURL(baseURL: baseURL, path: endpointPath, queryItems: [
                URLQueryItem(name: "query", value: "test"),
            ])

        case .stremio:
            guard let baseURL = config.baseURL else {
                throw IndexerConnectivityError.invalidBaseURL
            }
            let manifestPath = config.endpointPath.isEmpty ? "/manifest.json" : config.endpointPath
            do {
                url = try StremioAddonURLBuilder.manifestURL(baseURL: baseURL, endpointPath: manifestPath)
            } catch {
                throw IndexerConnectivityError.invalidBaseURL
            }
            guard IndexerURLSecurityPolicy.permits(url: url) else {
                throw IndexerConnectivityError.invalidBaseURL
            }
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.httpMethod = "GET"

        if config.apiKeyTransport == .header,
           let key = config.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "X-Api-Key")
        }

        if !IndexerRedirectPolicy.permitsInitialRequest(request) {
            throw IndexerConnectivityError.invalidBaseURL
        }

        return request
    }

    private static func buildURL(baseURL: String, path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: baseURL) else {
            throw IndexerConnectivityError.invalidBaseURL
        }

        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let appendPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch (normalizedPath.isEmpty, appendPath.isEmpty) {
        case (true, false):
            components.path = "/\(appendPath)"
        case (false, true):
            components.path = "/\(normalizedPath)"
        case (false, false):
            components.path = "/\(normalizedPath)/\(appendPath)"
        default:
            components.path = ""
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url,
              IndexerURLSecurityPolicy.permits(url: url) else {
            throw IndexerConnectivityError.invalidBaseURL
        }
        return url
    }

    @discardableResult
    private static func validatePayload(_ data: Data, for config: IndexerConfig) throws -> IndexerConnectivityResult {
        switch config.indexerType {
        case .stremio:
            let manifest = try JSONDecoder().decode(StremioManifestResponse.self, from: data)
            // An addon is compatible if it can serve streams directly (declares
            // the `stream` resource) OR exposes searchable movie/series
            // catalogs. A stream-only addon with empty catalogs still passes.
            let capability = manifest.capability
            let isCompatible = StremioManifestCapabilityPolicy.supportsStreamResource(capability)
                || StremioManifestCapabilityPolicy.hasSearchableCatalogs(capability)
            guard isCompatible else {
                throw IndexerConnectivityError.incompatibleManifest
            }
            let discoveredName = manifest.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            return IndexerConnectivityResult(
                discoveredName: (discoveredName?.isEmpty == false) ? discoveredName : nil
            )

        case .jackett, .torznab:
            try validateTorznabCapsPayload(data)
            return IndexerConnectivityResult()

        case .prowlarr, .apiBay, .yts, .eztv, .zilean:
            guard let object = try? JSONSerialization.jsonObject(with: data),
                  object is [String: Any] || object is [[String: Any]] || object is [Any] else {
                throw IndexerConnectivityError.invalidResponse
            }
            return IndexerConnectivityResult()
        }
    }

    private static func validateTorznabCapsPayload(_ data: Data) throws {
        let parser = XMLParser(data: data)
        let delegate = ConnectivityTorznabCapsParserDelegate()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw IndexerConnectivityError.invalidResponse
        }

        guard let root = delegate.rootElement?.lowercased(),
              root == "caps" || root == "error" else {
            throw IndexerConnectivityError.invalidResponse
        }
    }
}

actor IndexerRequestLimiter {
    private let minimumRequestInterval: TimeInterval
    private let maximumBackoffInterval: TimeInterval
    private let maximumAttempts: Int
    private let maximumResponseBytes: Int
    private var lastRequestDate: Date?
    private var nextAllowedRequestDate: Date?
    private let retryableStatusCodes: Set<Int> = [408, 425, 429, 500, 502, 503, 504]
    private let retryableTransportErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .networkConnectionLost,
        .notConnectedToInternet,
        .resourceUnavailable
    ]

    init(
        minimumRequestInterval: TimeInterval = 0.15,
        maximumBackoffInterval: TimeInterval = 5,
        maximumAttempts: Int = 3,
        maximumResponseBytes: Int = HTTPResponseBudget.indexer
    ) {
        self.minimumRequestInterval = minimumRequestInterval
        self.maximumBackoffInterval = maximumBackoffInterval
        self.maximumAttempts = max(1, maximumAttempts)
        self.maximumResponseBytes = max(1, maximumResponseBytes)
    }

    func data(from url: URL, session: URLSession) async throws -> (Data, URLResponse) {
        try await execute(request: URLRequest(url: url), session: session)
    }

    func data(for request: URLRequest, session: URLSession) async throws -> (Data, URLResponse) {
        try await execute(request: request, session: session)
    }

    private func execute(request: URLRequest, session: URLSession) async throws -> (Data, URLResponse) {
        var attempt = 0
        while true {
            attempt += 1
            try await waitForRequestSlot()

            let data: Data
            let response: URLResponse
            let redirectGuard = IndexerRedirectGuard(originalRequest: request)
            do {
                guard IndexerRedirectPolicy.permitsSearchTraffic(request) else {
                    throw IndexerRequestError.blockedRedirect(request.url)
                }
                (data, response) = try await BoundedHTTPResponseLoader.data(
                    for: request,
                    session: session,
                    delegate: redirectGuard,
                    maximumBytes: maximumResponseBytes
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch let urlError as URLError where urlError.code == .cancelled && redirectGuard.blockedRedirectURL != nil {
                throw IndexerRequestError.blockedRedirect(redirectGuard.blockedRedirectURL)
            } catch let urlError as URLError where retryableTransportErrorCodes.contains(urlError.code) && attempt < maximumAttempts {
                let delay = exponentialBackoffDelay(for: attempt)
                nextAllowedRequestDate = Date().addingTimeInterval(max(delay, minimumRequestInterval))
                continue
            }
            defer { lastRequestDate = Date() }

            guard let http = response as? HTTPURLResponse else {
                return (data, response)
            }

            guard IndexerRedirectPolicy.permitsFinalResponse(for: request, responseURL: http.url) else {
                throw IndexerRequestError.blockedRedirect(http.url)
            }

            guard retryableStatusCodes.contains(http.statusCode) else {
                return (data, response)
            }

            guard attempt < maximumAttempts else {
                if http.statusCode == 429 {
                    throw IndexerRequestError.rateLimited
                }
                return (data, response)
            }

            let delay = max(
                retryDelay(from: http) ?? 0,
                exponentialBackoffDelay(for: attempt)
            )
            nextAllowedRequestDate = Date().addingTimeInterval(max(delay, minimumRequestInterval))
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
        try Task.checkCancellation()
    }

    private func retryDelay(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        if let seconds = TimeInterval(value), seconds > 0 {
            return min(maximumBackoffInterval, seconds)
        }

        guard let date = IndexerRetryHeaderDateParser.date(from: value) else {
            return nil
        }

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else {
            return nil
        }

        return min(maximumBackoffInterval, interval)
    }

    private func exponentialBackoffDelay(for attempt: Int) -> TimeInterval {
        let exponent = max(0, attempt - 1)
        let multiplier = pow(2.0, Double(min(exponent, 5)))
        return min(maximumBackoffInterval, minimumRequestInterval * multiplier)
    }

    private static func nanoseconds(for interval: TimeInterval) -> UInt64 {
        UInt64((max(interval, 0) * 1_000_000_000).rounded())
    }
}

private final class ConnectivityTorznabCapsParserDelegate: NSObject, XMLParserDelegate {
    private(set) var rootElement: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        if rootElement == nil {
            rootElement = elementName
        }
    }
}

private enum IndexerRetryHeaderDateParser {
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

private struct StremioManifestResponse: Decodable {
    let name: String?
    let catalogs: [StremioManifestCatalog]?
    let resources: [StremioManifestResource]?
    let idPrefixes: [String]?

    var capability: StremioManifestCapability {
        StremioManifestCapability(
            resources: resources ?? [],
            catalogs: (catalogs ?? []).map {
                StremioManifestCapability.Catalog(type: $0.type, supportsSearch: $0.isCompatible)
            },
            idPrefixes: idPrefixes ?? []
        )
    }
}

private struct StremioManifestCatalog: Decodable {
    let type: String
    let extra: [StremioManifestExtra]?

    var isCompatible: Bool {
        let supportedType = type.caseInsensitiveCompare("movie") == .orderedSame
            || type.caseInsensitiveCompare("series") == .orderedSame
        return supportedType && (extra?.contains(where: { $0.name.caseInsensitiveCompare("search") == .orderedSame }) == true)
    }
}

private struct StremioManifestExtra: Decodable {
    let name: String
}
