import Foundation

enum PlaybackStreamURLResolverError: LocalizedError, Equatable {
    case blockedRedirect(URL?)
    case blockedFinalURL(URL?)
    case badHTTPStatus(Int)
    case missingHTTPResponse

    var errorDescription: String? {
        switch self {
        case .blockedRedirect(let url):
            return "Playback redirect was blocked because the destination is not a public HTTP(S) stream URL: \(Self.redactedURLDescription(url))."
        case .blockedFinalURL(let url):
            return "Playback response was blocked because the final destination is not a public HTTP(S) stream URL: \(Self.redactedURLDescription(url))."
        case .badHTTPStatus(let statusCode):
            return "Playback URL preflight failed with HTTP \(statusCode)."
        case .missingHTTPResponse:
            return "Playback URL preflight did not return a valid HTTP response."
        }
    }

    private static func redactedURLDescription(_ url: URL?) -> String {
        guard let url else { return "unknown" }
        return IndexerLogSanitizer.redactedURL(url)
    }
}

enum PlaybackStreamURLResolver {
    private static let requestTimeout: TimeInterval = 3
    private static let resourceTimeout: TimeInterval = 5

    static func resolve(_ stream: StreamInfo) async throws -> StreamInfo {
        try await resolve(stream, configuration: defaultConfiguration())
    }

    static func resolve(
        _ stream: StreamInfo,
        configuration: URLSessionConfiguration
    ) async throws -> StreamInfo {
        guard PlayerStreamURLPolicy.isPlayable(stream),
              PlayerStreamURLPolicy.permitsResolvedDestination(stream.streamURL) else {
            throw PlayerEngineError.invalidStreamURL(stream.streamURL.absoluteString)
        }

        guard !stream.streamURL.isFileURL else {
            return stream
        }

        let delegate = PlaybackStreamURLResolutionDelegate()
        let session = URLSession(
            configuration: configured(configuration),
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: stream.streamURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = requestTimeout
        for (name, value) in PlayerStreamURLPolicy.sanitizedPlaybackRequestHeaders(stream.requestHeaders) {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")

        let resolvedURL: URL
        do {
            resolvedURL = try await delegate.resolve(session: session, request: request)
        } catch {
            guard canFallBackToOriginalStream(after: error) else {
                throw error
            }
            return stream
        }
        guard PlayerStreamURLPolicy.permitsFinalResponseURL(resolvedURL) else {
            throw PlaybackStreamURLResolverError.blockedFinalURL(resolvedURL)
        }

        return stream.withStreamURL(resolvedURL)
    }

    static func defaultConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        return configuration
    }

    private static func configured(_ configuration: URLSessionConfiguration) -> URLSessionConfiguration {
        let copy = configuration.copy() as? URLSessionConfiguration ?? configuration
        copy.urlCache = nil
        copy.urlCredentialStorage = nil
        copy.httpCookieStorage = nil
        copy.httpShouldSetCookies = false
        copy.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        copy.waitsForConnectivity = false
        copy.timeoutIntervalForRequest = minPositive(copy.timeoutIntervalForRequest, requestTimeout)
        copy.timeoutIntervalForResource = minPositive(copy.timeoutIntervalForResource, resourceTimeout)
        return copy
    }

    private static func minPositive(_ current: TimeInterval, _ fallback: TimeInterval) -> TimeInterval {
        guard current > 0 else { return fallback }
        return min(current, fallback)
    }

    private static func canFallBackToOriginalStream(after error: any Error) -> Bool {
        guard let resolverError = error as? PlaybackStreamURLResolverError else {
            return true
        }
        switch resolverError {
        case .blockedRedirect, .blockedFinalURL:
            return false
        case .badHTTPStatus, .missingHTTPResponse:
            return true
        }
    }
}

private final class PlaybackStreamURLResolutionDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, any Error>?
    private var didFinish = false
    private var blockedRedirectURL: URL?

    func resolve(session: URLSession, request: URLRequest) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            setContinuation(continuation)
            session.dataTask(with: request).resume()
        }
    }

    private func setContinuation(_ continuation: CheckedContinuation<URL, any Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    private func finish(returning url: URL, session: URLSession) {
        let continuation = takeContinuation()
        continuation?.resume(returning: url)
        session.invalidateAndCancel()
    }

    private func finish(throwing error: any Error, session: URLSession) {
        let continuation = takeContinuation()
        continuation?.resume(throwing: error)
        session.invalidateAndCancel()
    }

    private func takeContinuation() -> CheckedContinuation<URL, any Error>? {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else {
            return nil
        }
        didFinish = true
        let continuation = continuation
        self.continuation = nil
        return continuation
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard PlayerStreamURLPolicy.allowsRedirect(to: request) else {
            lock.lock()
            blockedRedirectURL = request.url
            lock.unlock()
            completionHandler(nil)
            task.cancel()
            finish(throwing: PlaybackStreamURLResolverError.blockedRedirect(request.url), session: session)
            return
        }

        completionHandler(request)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(throwing: PlaybackStreamURLResolverError.missingHTTPResponse, session: session)
            return
        }

        guard PlayerStreamURLPolicy.permitsFinalResponseURL(http.url) else {
            completionHandler(.cancel)
            finish(throwing: PlaybackStreamURLResolverError.blockedFinalURL(http.url), session: session)
            return
        }

        guard (200...299).contains(http.statusCode) else {
            completionHandler(.cancel)
            finish(throwing: PlaybackStreamURLResolverError.badHTTPStatus(http.statusCode), session: session)
            return
        }

        completionHandler(.cancel)
        finish(returning: http.url!, session: session)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else {
            return
        }

        lock.lock()
        let blockedRedirectURL = blockedRedirectURL
        lock.unlock()

        if let urlError = error as? URLError,
           urlError.code == .cancelled,
           blockedRedirectURL == nil {
            return
        }

        if let blockedRedirectURL {
            finish(throwing: PlaybackStreamURLResolverError.blockedRedirect(blockedRedirectURL), session: session)
        } else {
            finish(throwing: error, session: session)
        }
    }
}
