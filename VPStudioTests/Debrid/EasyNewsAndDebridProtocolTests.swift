import Foundation
import Testing
@testable import VPStudio

private final class NonHTTPResponseProtocolHarness: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandlers: [String: (URLRequest) throws -> (URLResponse, Data)] = [:]
    static let lock = NSLock()
    static let handlerHeader = "X-VPStudio-NonHTTP-Harness"

    static func register(_ handler: @escaping (URLRequest) throws -> (URLResponse, Data)) -> String {
        let id = UUID().uuidString
        lock.lock()
        requestHandlers[id] = handler
        lock.unlock()
        return id
    }

    static func handler(for id: String) -> ((URLRequest) throws -> (URLResponse, Data))? {
        lock.lock()
        let handler = requestHandlers[id]
        lock.unlock()
        return handler
    }

    static func clear(_ id: String) {
        lock.lock()
        requestHandlers[id] = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: handlerHeader) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handlerID = request.value(forHTTPHeaderField: Self.handlerHeader),
              let handler = Self.handler(for: handlerID) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        var sanitizedRequest = request
        sanitizedRequest.setValue(nil, forHTTPHeaderField: Self.handlerHeader)

        do {
            let (response, data) = try handler(sanitizedRequest)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeSession(handler: @escaping (URLRequest) throws -> (URLResponse, Data)) -> URLSession {
        let handlerID = register(handler)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NonHTTPResponseProtocolHarness.self]
        config.httpAdditionalHeaders = [handlerHeader: handlerID]
        return URLSession(configuration: config)
    }
}

@Suite("EasyNewsService")
struct EasyNewsServiceTests {
    @Test
    func validateTokenReturnsTrueOn200() async throws {
        let session = URLProtocolHarness.makeSession { request in
            #expect(request.httpMethod == "HEAD")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic test-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = EasyNewsService(apiToken: "test-token", session: session)
        let result = try await service.validateToken()

        #expect(result == true)
    }

    @Test
    func validateTokenReturnsFalseOn401() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = EasyNewsService(apiToken: "bad-token", session: session)
        let result = try await service.validateToken()

        #expect(result == false)
    }

    @Test
    func validateTokenReturnsFalseOn403() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = EasyNewsService(apiToken: "forbidden-token", session: session)
        let result = try await service.validateToken()

        #expect(result == false)
    }

    @Test
    func validateTokenThrowsOnOtherStatusCodes() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = EasyNewsService(apiToken: "test-token", session: session)

        await #expect(throws: DebridError.self) {
            _ = try await service.validateToken()
        }
    }

    @Test
    func getAccountInfoReturnsDefaultInfo() async throws {
        let service = EasyNewsService(apiToken: "test-token")

        let info = try await service.getAccountInfo()

        #expect(info.username == "EasyNews")
        #expect(info.email == nil)
        #expect(info.premiumExpiry == nil)
        #expect(info.isPremium == nil)
    }

    @Test
    func checkCacheReturnsUnknownForAllHashes() async throws {
        let service = EasyNewsService(apiToken: "test-token")

        let result = try await service.checkCache(hashes: ["hash1", "HASH2", "abc123"])

        #expect(result.count == 3)
        #expect(result["hash1"] == .unknown)
        #expect(result["hash2"] == .unknown)
        #expect(result["abc123"] == .unknown)
    }

    @Test
    func checkCacheHandlesLowercaseNormalization() async throws {
        let service = EasyNewsService(apiToken: "test-token")

        let result = try await service.checkCache(hashes: ["ABC123"])

        #expect(result["abc123"] == .unknown)
    }

    @Test
    func addMagnetThrowsNotSupportedError() async throws {
        let service = EasyNewsService(apiToken: "test-token")

        await #expect(throws: DebridError.networkError("EasyNews uses Usenet search, not magnet links")) {
            _ = try await service.addMagnet(hash: "somehash")
        }
    }

    @Test
    func selectFilesCompletesSuccessfully() async throws {
        let service = EasyNewsService(apiToken: "test-token")

        try await service.selectFiles(torrentId: "123", fileIds: [1, 2, 3])
    }

    @Test
    func getStreamURLThrowsNotReadyError() async throws {
        let service = EasyNewsService(apiToken: "test-token")

        await #expect(throws: DebridError.fileNotReady("EasyNews stream resolution requires search-based flow")) {
            _ = try await service.getStreamURL(torrentId: "123")
        }
    }

    @Test
    func unrestrictReturnsURLIfValid() async throws {
        let service = EasyNewsService(apiToken: "test-token")

        let url = try await service.unrestrict(link: "https://example.com/file")

        #expect(url == URL(string: "https://example.com/file"))
    }

    @Test
    func unrestrictThrowsForInvalidURL() async throws {
        let service = EasyNewsService(apiToken: "test-token")

        await #expect(throws: DebridError.networkError("Invalid URL")) {
            _ = try await service.unrestrict(link: "file:///Users/example/private.mkv")
        }
        await #expect(throws: DebridError.networkError("Invalid URL")) {
            _ = try await service.unrestrict(link: "http://127.0.0.1:8080/private.mkv")
        }
        await #expect(throws: DebridError.networkError("Invalid URL")) {
            _ = try await service.unrestrict(link: "http://169.254.169.254/latest/meta-data")
        }
    }

    @Test
    func serviceTypeIsEasyNews() async throws {
        let service = EasyNewsService(apiToken: "test-token")

        #expect(await service.serviceType == .easyNews)
    }
}

@Suite("CacheStatus")
struct CacheStatusTests {
    @Test
    func cachedCaseContainsFileInfo() {
        let status = CacheStatus.cached(fileId: "file123", fileName: "video.mkv", fileSize: 1_000_000)

        #expect(status == .cached(fileId: "file123", fileName: "video.mkv", fileSize: 1_000_000))
    }

    @Test
    func cachedCaseAllowsNilFields() {
        let status = CacheStatus.cached(fileId: nil, fileName: nil, fileSize: nil)

        if case .cached = status {
        } else {
            Issue.record("Expected cached case")
        }
    }

    @Test
    func notCachedCaseIsEquatable() {
        let status1 = CacheStatus.notCached
        let status2 = CacheStatus.notCached

        #expect(status1 == status2)
    }

    @Test
    func unknownCaseIsEquatable() {
        let status1 = CacheStatus.unknown
        let status2 = CacheStatus.unknown

        #expect(status1 == status2)
    }

    @Test
    func cachedCasesWithDifferentValuesAreNotEqual() {
        let status1 = CacheStatus.cached(fileId: "id1", fileName: nil, fileSize: nil)
        let status2 = CacheStatus.cached(fileId: "id2", fileName: nil, fileSize: nil)

        #expect(status1 != status2)
    }
}

@Suite("DebridAccountInfo")
struct DebridAccountInfoTests {
    @Test
    func defaultValuesAreNilOrEmpty() {
        let info = DebridAccountInfo(username: "test")

        #expect(info.username == "test")
        #expect(info.email == nil)
        #expect(info.premiumExpiry == nil)
        #expect(info.isPremium == nil)
    }

    @Test
    func allFieldsCanBeSet() {
        let expiry = Date()
        let info = DebridAccountInfo(
            username: "user",
            email: "user@example.com",
            premiumExpiry: expiry,
            isPremium: true
        )

        #expect(info.username == "user")
        #expect(info.email == "user@example.com")
        #expect(info.premiumExpiry == expiry)
        #expect(info.isPremium == true)
    }
}

@Suite("DebridHashValidator")
struct DebridHashValidatorTestsDebridEasynewsanddebridprotocoltests {
    @Test
    func normalizedInfoHashReturnsLowercaseForValid40CharHex() {
        let result = DebridHashValidator.normalizedInfoHash("a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")

        #expect(result == "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
    }

    @Test
    func normalizedInfoHashReturnsLowercaseForValid64CharHex() {
        let result = DebridHashValidator.normalizedInfoHash("ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789")

        #expect(result == "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789")
    }

    @Test
    func normalizedInfoHashStripsWhitespace() {
        let result = DebridHashValidator.normalizedInfoHash("  a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2  ")

        #expect(result == "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
    }

    @Test
    func normalizedInfoHashReturnsNilForTooShort() {
        #expect(DebridHashValidator.normalizedInfoHash("abc123") == nil)
    }

    @Test
    func normalizedInfoHashReturnsNilForTooLong() {
        #expect(DebridHashValidator.normalizedInfoHash(String(repeating: "a", count: 65)) == nil)
    }

    @Test
    func normalizedInfoHashReturnsNilForNonHexCharacters() {
        #expect(DebridHashValidator.normalizedInfoHash("ghijklmnopghijklmnopghijklmnopghijklmnop") == nil)
    }

    @Test
    func normalizedInfoHashReturnsNilForEmpty() {
        #expect(DebridHashValidator.normalizedInfoHash("") == nil)
    }

    @Test
    func validatedInfoHashReturnsHashForValidInput() throws {
        let result = try DebridHashValidator.validatedInfoHash("a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")

        #expect(result == "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
    }

    @Test
    func validatedInfoHashThrowsForInvalidInput() {
        do {
            _ = try DebridHashValidator.validatedInfoHash("invalid")
            Issue.record("Expected throw")
        } catch let error as DebridError {
            if case .invalidHash(let hash) = error {
                #expect(hash == "invalid")
            } else {
                Issue.record("Expected invalidHash error")
            }
        } catch {
            Issue.record("Expected DebridError")
        }
    }
}

@Suite("DebridError")
struct DebridErrorTests {
    @Test
    func unauthorizedDescription() {
        #expect(DebridError.unauthorized.errorDescription == "Invalid or expired API token")
    }

    @Test
    func notPremiumDescription() {
        #expect(DebridError.notPremium.errorDescription == "Premium account required")
    }

    @Test
    func invalidHashDescription() {
        #expect(DebridError.invalidHash("abc123").errorDescription == "Invalid torrent hash: abc123")
    }

    @Test
    func torrentNotFoundDescription() {
        #expect(DebridError.torrentNotFound("xyz").errorDescription == "Torrent not found: xyz")
    }

    @Test
    func fileNotReadyDescription() {
        #expect(DebridError.fileNotReady("test").errorDescription == "File not ready: test")
    }

    @Test
    func rateLimitedDescription() {
        #expect(DebridError.rateLimited.errorDescription == "Rate limited. Try again shortly.")
    }

    @Test
    func httpErrorDescription() {
        #expect(DebridError.httpError(500, "Server Error").errorDescription == "HTTP 500: Server Error")
    }

    @Test
    func networkErrorDescription() {
        #expect(DebridError.networkError("Connection failed").errorDescription == "Network error: Connection failed")
    }

    @Test
    func timeoutDescription() {
        #expect(DebridError.timeout.errorDescription == "Request timed out")
    }

    @Test
    func errorsAreEquatable() {
        #expect(DebridError.unauthorized == DebridError.unauthorized)
        #expect(DebridError.unauthorized != DebridError.rateLimited)
    }
}

@Suite("DebridHTTPExecutor Retry Logic")
struct DebridHTTPExecutorRetryTests {
    @Test
    func dataReturnsDataOnNonRetryableStatus() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("ok".utf8))
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, _) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataRetriesOn429WithRetryAfterHeader() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 3 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: ["Retry-After": "0"]
                )!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("ok".utf8))
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        _ = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 3)
    }

    @Test
    func dataRetriesOn502Status() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 502,
                        httpVersion: nil,
                        headerFields: nil
                    )!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataRetriesOn408Status() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 408,
                        httpVersion: nil,
                        headerFields: ["Retry-After": "0"]
                    )!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataRetriesOn425Status() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 425,
                        httpVersion: nil,
                        headerFields: ["Retry-After": "0"]
                    )!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataDoesNotRetryOnNonRetryableStatusEvenWithRetryAfter() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 418,
                httpVersion: nil,
                headerFields: ["Retry-After": "1"]
            )!
            return (response, Data("blocked".utf8))
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 1)
        #expect(response.statusCode == 418)
        #expect(String(data: data, encoding: .utf8) == "blocked")
    }

    @Test
    func dataDoesNotRetryOnNonRetryable501Status() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 501,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data("not implemented".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 1)
        #expect(response.statusCode == 501)
        #expect(String(data: data, encoding: .utf8) == "not implemented")
    }

    @Test
    func dataRetriesWhenRetryAfterDateIsInThePast() async throws {
        var attempts = 0
        let pastDate = DateFormatter()
        pastDate.locale = Locale(identifier: "en_US_POSIX")
        pastDate.timeZone = TimeZone(secondsFromGMT: 0)
        pastDate.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let headerValue = pastDate.string(from: Date().addingTimeInterval(-120))

        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 503,
                        httpVersion: nil,
                        headerFields: ["Retry-After": headerValue]
                    )!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataThrowsRateLimitedAfterMaxRetriesOn429() async throws {
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        await #expect(throws: DebridError.rateLimited) {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
        }
    }

    @Test
    func dataRetriesOn500Status() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("ok".utf8))
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        _ = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
    }

    @Test
    func dataRetriesOnTransportErrors() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                throw URLError(.timedOut)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("ok".utf8))
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        _ = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
    }

    @Test
    func dataThrowsOnNonRetryableTransportError() async throws {
        let session = URLProtocolHarness.makeSession { request in
            throw URLError(.badServerResponse)
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected error")
        } catch let error as DebridError {
            if case .networkError = error {
            } else {
                Issue.record("Expected networkError, got \(error)")
            }
        }
    }

    @Test
    func dataThrowsTimeoutAfterRetryLimitOnTimedOutTransportError() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            throw URLError(.timedOut)
        }

        let request = URLRequest(url: URL(string: "https://example.com")!)
        await #expect(throws: DebridError.timeout) {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
        }
        #expect(attempts == 4)
    }

    @Test
    func dataReturnsFinalResponseForExhaustedRetryableStatus() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data("still failing".utf8))
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 4)
        #expect(response.statusCode == 500)
        #expect(String(data: data, encoding: .utf8) == "still failing")
    }

    @Test
    func dataReturnsResponseForNonRetryableStatus() async throws {
        let session = URLProtocolHarness.makeSession { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!, Data("bad request".utf8))
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (_, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(response.statusCode == 400)
    }

    @Test
    func dataRetriesOnCannotFindHostTransportError() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            throw URLError(.cannotFindHost)
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError")
        } catch let error as DebridError {
            if case .networkError = error {
                #expect(attempts == 4)
            } else {
                Issue.record("Expected networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected DebridError.networkError, got \(error)")
        }
    }

    @Test
    func dataPropagatesCancellationError() async throws {
        let session = URLProtocolHarness.makeSession { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("ok".utf8))
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let task = Task {
            try await DebridHTTPExecutor.data(for: request, session: session)
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    @Test
    func dataRetriesOn503Status() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataRetriesOn504Status() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 504, httpVersion: nil, headerFields: nil)!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataRetriesOnDNSLookupFailedTransportError() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            throw URLError(.dnsLookupFailed)
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError")
        } catch let error as DebridError {
            if case .networkError(let message) = error {
                #expect(!message.isEmpty)
            } else {
                Issue.record("Expected networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected DebridError.networkError, got \(error)")
        }

        #expect(attempts == 4)
    }

    @Test
    func dataRetriesWhenRetryAfterHeaderIsInvalid() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 3 {
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 429,
                        httpVersion: nil,
                        headerFields: ["Retry-After": "n/a"]
                    )!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 3)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataReturnsNetworkErrorForNonRetryableTransportError() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            throw URLError(.badURL)
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError")
        } catch let error as DebridError {
            if case .networkError = error {
                #expect(attempts == 1)
            } else {
                Issue.record("Expected networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected DebridError.networkError, got \(error)")
        }
    }

    @Test
    func dataRetriesOnCannotConnectToHostTransportError() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            throw URLError(.cannotConnectToHost)
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError")
        } catch let error as DebridError {
            if case .networkError = error {
                #expect(attempts == 4)
            } else {
                Issue.record("Expected networkError, got \(error)")
            }
        }
    }

    @Test
    func dataRetriesOnResourceUnavailableTransportError() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                throw URLError(.resourceUnavailable)
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataRetriesOnNotConnectedToInternetTransportError() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            throw URLError(.notConnectedToInternet)
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError")
        } catch let error as DebridError {
            if case .networkError(let message) = error {
                #expect(!message.isEmpty)
            } else {
                Issue.record("Expected networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected DebridError.networkError, got \(error)")
        }

        #expect(attempts == 4)
    }

    @Test
    func dataRetriesWhenRetryAfterSecondsContainsWhitespace() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 429,
                        httpVersion: nil,
                        headerFields: ["Retry-After": " 0 "]
                    )!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataRetriesOnNetworkConnectionLostTransportError() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            throw URLError(.networkConnectionLost)
        }

        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError")
        } catch let error as DebridError {
            if case .networkError(let message) = error {
                #expect(message.contains("network connection was lost"))
            } else {
                Issue.record("Expected networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected DebridError.networkError, got \(error)")
        }

        #expect(attempts == 4)
    }

    @Test
    func dataRetriesOn503WithRetryAfterDate() async throws {
        var attempts = 0
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let retryAfter = formatter.string(from: Date().addingTimeInterval(1))

        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            if attempts < 2 {
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 503,
                        httpVersion: nil,
                        headerFields: ["Retry-After": retryAfter]
                    )!,
                    Data()
                )
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("ok".utf8)
            )
        }

        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 2)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test
    func dataReturnsFinalResponseForExhaustedRetryableStatusWhenNotRateLimited() async throws {
        var attempts = 0
        let session = URLProtocolHarness.makeSession { request in
            attempts += 1
            return (
                HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!,
                Data("still unavailable".utf8)
            )
        }
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)

        #expect(attempts == 4)
        #expect(response.statusCode == 503)
        #expect(String(data: data, encoding: .utf8) == "still unavailable")
    }

    @Test
    func dataThrowsNetworkErrorWhenResponseIsNotHTTPURLResponse() async throws {
        let handlerID = NonHTTPResponseProtocolHarness.register { request in
            let response = URLResponse(
                url: request.url!,
                mimeType: "text/plain",
                expectedContentLength: 0,
                textEncodingName: "utf-8"
            )
            return (response, Data("ok".utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NonHTTPResponseProtocolHarness.self]
        config.httpAdditionalHeaders = [NonHTTPResponseProtocolHarness.handlerHeader: handlerID]
        let session = URLSession(configuration: config)

        defer {
            NonHTTPResponseProtocolHarness.clear(handlerID)
        }

        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError")
        } catch let error as DebridError {
            if case .networkError(let message) = error {
                #expect(message == "Invalid response")
            } else {
                Issue.record("Expected .networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected DebridError.networkError, got \(error)")
        }
    }

}
