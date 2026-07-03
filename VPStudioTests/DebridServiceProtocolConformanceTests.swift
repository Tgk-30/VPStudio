import Foundation
import Testing
@testable import VPStudio

// MARK: - DebridServiceProtocol Conformance Tests

private final class TrackingDebridService: DebridServiceProtocol, @unchecked Sendable {
    var addMagnetCallCount: Int = 0
    var serviceType: DebridServiceType { .realDebrid }

    func validateToken() async throws -> Bool { true }
    func getAccountInfo() async throws -> DebridAccountInfo { DebridAccountInfo(username: "test") }
    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] { [:] }

    func addMagnet(hash: String) async throws -> String {
        addMagnetCallCount += 1
        return "https://example.com/magnet/\(hash)"
    }

    func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://example.com")!,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            fileName: "test.mkv",
            sizeBytes: 1000,
            debridService: "test"
        )
    }

    func unrestrict(link: String) async throws -> URL { URL(string: "https://example.com")! }
}

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

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: handlerHeader) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handlerID = request.value(forHTTPHeaderField: Self.handlerHeader),
              let handler = Self.handler(for: handlerID) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
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

private func acceptsDebridServiceProtocol<T: DebridServiceProtocol>(_ value: T) -> Bool {
    _ = value
    return true
}

@Suite("DebridServiceProtocol Conformance")
struct DebridServiceProtocolConformanceTests {

    @Test func realDebridServiceConformsToDebridServiceProtocol() async throws {
        let service = RealDebridService(apiToken: "test-token")
        #expect(acceptsDebridServiceProtocol(service))
    }

    @Test func torBoxServiceConformsToDebridServiceProtocol() async throws {
        let service = TorBoxService(apiToken: "test-token")
        #expect(acceptsDebridServiceProtocol(service))
    }

    @Test func allDebridServiceConformsToDebridServiceProtocol() async throws {
        let service = AllDebridService(apiToken: "test-token")
        #expect(acceptsDebridServiceProtocol(service))
    }

    @Test func premiumizeServiceConformsToDebridServiceProtocol() async throws {
        let service = PremiumizeService(apiToken: "test-token")
        #expect(acceptsDebridServiceProtocol(service))
    }

    @Test func offcloudServiceConformsToDebridServiceProtocol() async throws {
        let service = OffcloudService(apiToken: "test-token")
        #expect(acceptsDebridServiceProtocol(service))
    }

    @Test func easyNewsServiceConformsToDebridServiceProtocol() async throws {
        let service = EasyNewsService(apiToken: "test-token")
        #expect(acceptsDebridServiceProtocol(service))
    }

    @Test func debridLinkServiceConformsToDebridServiceProtocol() async throws {
        let service = DebridLinkService(apiToken: "test-token")
        #expect(acceptsDebridServiceProtocol(service))
    }
}

// MARK: - DebridServiceProtocol Default Implementation Tests

@Suite("DebridServiceProtocol Default Implementations")
struct DebridServiceProtocolDefaultImplTests {

    private struct MinimalTestService: DebridServiceProtocol {
        var serviceType: DebridServiceType { .realDebrid }

        func validateToken() async throws -> Bool { true }
        func getAccountInfo() async throws -> DebridAccountInfo { DebridAccountInfo(username: "test") }
        func checkCache(hashes: [String]) async throws -> [String: CacheStatus] { [:] }
        func addMagnet(hash: String) async throws -> String { "" }
        func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
        func getStreamURL(torrentId: String) async throws -> StreamInfo {
            StreamInfo(streamURL: URL(string: "https://example.com")!, quality: .unknown, codec: .unknown, audio: .unknown, source: .unknown, hdr: .sdr, fileName: "test.mkv", sizeBytes: 1000, debridService: "test")
        }
        func unrestrict(link: String) async throws -> URL { URL(string: "https://example.com")! }
    }

    @Test func selectMatchingEpisodeFileDefaultReturnsFalse() async throws {
        let service = MinimalTestService()
        let result = try await service.selectMatchingEpisodeFile(
            torrentId: "test-torrent",
            seasonNumber: 1,
            episodeNumber: 5,
            resolvedFileNameHint: nil,
            resolvedFileSizeHint: nil
        )
        #expect(result == false)
    }

    @Test func cleanupRemoteTransferDefaultIsNoOp() async throws {
        let service = MinimalTestService()
        try await service.cleanupRemoteTransfer(torrentId: "test-torrent")
    }

    @Test func defaultAddMagnetUsesRequiredAddMagnetImplementation() async throws {
        let service = TrackingDebridService()
        let result = try await service.addMagnet(
            hash: "0123456789abcdef0123456789abcdef01234567",
            magnetURI: "https://example.com/magnet"
        )

        #expect(result == "https://example.com/magnet/0123456789abcdef0123456789abcdef01234567")
        #expect(service.addMagnetCallCount == 1)
    }
}

// MARK: - CacheStatus Tests

@Suite("CacheStatus")
struct CacheStatusTestsDebridserviceprotocolconformancetests {

    @Test func cachedCaseContainsFileInfo() {
        let status = CacheStatus.cached(fileId: "file-123", fileName: "movie.mkv", fileSize: 1_500_000_000)
        #expect(status == CacheStatus.cached(fileId: "file-123", fileName: "movie.mkv", fileSize: 1_500_000_000))
    }

    @Test func notCachedCaseIsEquatable() {
        let status1 = CacheStatus.notCached
        let status2 = CacheStatus.notCached
        #expect(status1 == status2)
    }

    @Test func unknownCaseIsEquatable() {
        let status1 = CacheStatus.unknown
        let status2 = CacheStatus.unknown
        #expect(status1 == status2)
    }

    @Test func differentCasesAreNotEqual() {
        #expect(CacheStatus.cached(fileId: "1", fileName: nil, fileSize: nil) != .notCached)
        #expect(CacheStatus.notCached != .unknown)
        #expect(CacheStatus.unknown != .cached(fileId: nil, fileName: nil, fileSize: nil))
    }
}

// MARK: - DebridAccountInfo Tests

@Suite("DebridAccountInfo")
struct DebridAccountInfoTestsDebridserviceprotocolconformancetests {

    @Test func accountInfoStoresUsername() {
        let info = DebridAccountInfo(username: "testuser", email: "test@example.com", premiumExpiry: nil, isPremium: true)
        #expect(info.username == "testuser")
    }

    @Test func accountInfoStoresOptionalEmail() {
        let info = DebridAccountInfo(username: "testuser", email: "test@example.com")
        #expect(info.email == "test@example.com")
    }

    @Test func accountInfoWithNilEmail() {
        let info = DebridAccountInfo(username: "testuser", email: nil)
        #expect(info.email == nil)
    }

    @Test func accountInfoStoresOptionalPremiumExpiry() {
        let expiry = Date()
        let info = DebridAccountInfo(username: "testuser", premiumExpiry: expiry)
        #expect(info.premiumExpiry == expiry)
    }

    @Test func accountInfoStoresOptionalIsPremium() {
        let info = DebridAccountInfo(username: "testuser", isPremium: true)
        #expect(info.isPremium == true)
    }
}

// MARK: - DebridServiceType Tests

@Suite("DebridServiceType")
struct DebridServiceTypeTests {

    @Test func allServiceTypesHaveRawValues() {
        for serviceType in DebridServiceType.allCases {
            #expect(!serviceType.rawValue.isEmpty)
        }
    }

    @Test func realDebridRawValue() {
        #expect(DebridServiceType.realDebrid.rawValue == "real_debrid")
    }

    @Test func torBoxRawValue() {
        #expect(DebridServiceType.torBox.rawValue == "torbox")
    }

    @Test func allDebridRawValue() {
        #expect(DebridServiceType.allDebrid.rawValue == "all_debrid")
    }

    @Test func premiumizeRawValue() {
        #expect(DebridServiceType.premiumize.rawValue == "premiumize")
    }

    @Test func offcloudRawValue() {
        #expect(DebridServiceType.offcloud.rawValue == "offcloud")
    }

    @Test func easyNewsRawValue() {
        #expect(DebridServiceType.easyNews.rawValue == "easynews")
    }
}

// MARK: - DebridHashValidator Tests

@Suite("DebridHashValidator")
struct DebridHashValidatorTestsDebridserviceprotocolconformancetests {

    @Test func normalizedInfoHashAccepts40CharHex() {
        let hash = "0123456789abcdef0123456789abcdef01234567"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == hash)
    }

    @Test func normalizedInfoHashAccepts64CharHex() {
        let hash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == hash)
    }

    @Test func normalizedInfoHashLowercasesUppercaseChars() {
        let hash = "0123456789ABCDEF0123456789ABCDEF01234567"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == hash.lowercased())
    }

    @Test func normalizedInfoHashTrimsWhitespace() {
        let hash = "  0123456789abcdef0123456789abcdef01234567  "
        #expect(DebridHashValidator.normalizedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test func normalizedInfoHashRejectsInvalidLength() {
        #expect(DebridHashValidator.normalizedInfoHash("abc") == nil)
        #expect(DebridHashValidator.normalizedInfoHash("0123456789abcdef0123456789abcdef0123456") == nil)
    }

    @Test func normalizedInfoHashRejectsNonHex() {
        #expect(DebridHashValidator.normalizedInfoHash("ghijklmnopghijklmnopghijklmnopghijklmnop") == nil)
    }

    @Test func validatedInfoHashReturnsNormalizedHash() throws {
        let hash = "0123456789abcdef0123456789abcdef01234567"
        let result = try DebridHashValidator.validatedInfoHash(hash)
        #expect(result == hash)
    }

    @Test func validatedInfoHashThrowsOnInvalid() {
        do {
            _ = try DebridHashValidator.validatedInfoHash("invalid")
            Issue.record("Expected DebridError.invalidHash")
        } catch DebridError.invalidHash(let hash) {
            #expect(hash == "invalid")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("DebridMagnetInput")
struct DebridMagnetInputTestsDebridserviceprotocolconformancetests {

    @Test func preferredMagnetURIFallsBackToBareURIWhenMagnetMissingOrBlank() throws {
        let hash = "0123456789abcdef0123456789abcdef01234567"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: hash, suppliedMagnetURI: nil)
            == "magnet:?xt=urn:btih:\(hash)"
        )
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: hash, suppliedMagnetURI: "   ")
            == "magnet:?xt=urn:btih:\(hash)"
        )
    }

    @Test func preferredMagnetURIUsesSuppliedURIWhenItContainsMatchingHash() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "magnet:?xt=urn:btih:\(normalized.uppercased())&dn=movie"
        #expect(try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied) == supplied)
    }

    @Test func preferredMagnetURIRejectsNonMagnetURLEvenWhenItContainsTheHash() throws {
        // A compromised indexer must not be able to smuggle an arbitrary http(s)
        // URL into a debrid provider's add-magnet endpoint just because the hash
        // appears in the path. Such a value carries no tracker list, so it is
        // always rebuilt as a safe bare magnet from the validated hash.
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let httpURL = "https://attacker.example/t/\(normalized)?apikey=secret"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: httpURL)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
        // A raw hash string (no magnet: scheme) is likewise normalized to a bare magnet.
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: normalized)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test func preferredMagnetURIFallsBackToBareURIWhenUppercaseSuppliedHashMismatches() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let other = String(repeating: "1", count: 40)
        let supplied = "magnet:?XT=urn:BTIH:\(other)&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test func preferredMagnetURIFallsBackToBareURIOnHashMismatch() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let otherHash = String(repeating: "1", count: 40)
        let supplied = "magnet:?xt=urn:btih:\(otherHash)&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test func preferredMagnetURIFallsBackToBareURIForNonBTIHMagnetInput() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "magnet:?xt=urn:sha1:\(normalized)&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test func preferredMagnetURIPreservesUppercaseMagnetParamsWhenHashMatches() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "magnet:?XT=URN:BTIH:\(normalized.uppercased())&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == supplied
        )
    }

    @Test func preferredMagnetURIRejectsNonMagnetHTTPURLEvenWhenItContainsMatchingHash() throws {
        // Security: a non-magnet http(s) URL must never be forwarded to a debrid
        // provider's add-magnet endpoint (server-side SSRF). It carries no tracker
        // list, so it is always rebuilt as a safe bare magnet from the hash.
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "https://cdn.example.com/\(normalized)/file.mkv"
        let result = try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
        #expect(result == "magnet:?xt=urn:btih:\(normalized)")
    }

    @Test func preferredMagnetURIReturnsSuppliedURIWhenAnyXTTagMatchesHash() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let mismatch = String(repeating: "1", count: 40)
        let supplied = "magnet:?xt=urn:btih:\(mismatch)&xt=urn:btih:\(normalized)&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == supplied
        )
    }

    @Test func preferredMagnetURIUsesSuppliedMagnetWhenAnyBTIHXTTagMatchesEvenIfDifferentTypesPresent() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "magnet:?xt=urn:sha1:\(String(repeating: "2", count: 40))&xt=urn:btih:\(normalized.uppercased())&dn=movie"
        let result = try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
        #expect(result == supplied)
    }

    @Test func preferredMagnetURIFallsBackToBareURIWhenNoProvidedBTIHMatches() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "magnet:?xt=urn:sha1:\(String(repeating: "2", count: 40))&xt=urn:btih:\(String(repeating: "3", count: 40))&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test func preferredMagnetURIRejectsNonMagnetSchemeURLEvenWhenItContainsMatchingHash() throws {
        // Security: any non-`magnet:` scheme (even an exotic one) that merely
        // contains the hash is rebuilt as a bare magnet rather than forwarded.
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "not://a-real.url/contains/\(normalized)/segment"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test func preferredMagnetURIFallsBackToBareURIWhenMagnetLacksXT() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "magnet:?dn=\(normalized)&xl=100"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test func preferredMagnetURIReturnsBareURIForNonnMagnetInput() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: "https://example.com/file.torrent")
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }
}

@Suite("DebridStreamMetadata")
struct DebridStreamMetadataTestsDebridserviceprotocolconformancetests {
    @Test func firstUsableCandidateWins() {
        let quality = DebridStreamMetadata.quality(
            from: [".", "1080p", "4k"]
        )
        #expect(quality == .hd1080p)
    }

    @Test func firstUsableCandidateFallbackToDefault() {
        let codec = DebridStreamMetadata.codec(
            from: ["", "??", "av1"]
        )
        #expect(codec == .av1)
    }

    @Test func metadataDefaultsToUnknownWhenNoParsableCandidates() {
        let audio = DebridStreamMetadata.audio(from: ["", "??", nil])
        let source = DebridStreamMetadata.source(from: [nil, "   ", ""])
        let hdr = DebridStreamMetadata.hdr(from: ["", nil, " "])
        #expect(audio == .unknown)
        #expect(source == .unknown)
        #expect(hdr == .sdr)
    }
}

// MARK: - DebridError Tests

@Suite("DebridError")
struct DebridErrorTestsDebridserviceprotocolconformancetests {

    @Test func unauthorizedHasDescription() {
        #expect(DebridError.unauthorized.errorDescription == "Invalid or expired API token")
    }

    @Test func notPremiumHasDescription() {
        #expect(DebridError.notPremium.errorDescription == "Premium account required")
    }

    @Test func invalidHashHasDescription() {
        #expect(DebridError.invalidHash("abc123").errorDescription == "Invalid torrent hash: abc123")
    }

    @Test func torrentNotFoundHasDescription() {
        #expect(DebridError.torrentNotFound("torrent-123").errorDescription == "Torrent not found: torrent-123")
    }

    @Test func fileNotReadyHasDescription() {
        #expect(DebridError.fileNotReady("file missing").errorDescription == "File not ready: file missing")
    }

    @Test func rateLimitedHasDescription() {
        #expect(DebridError.rateLimited.errorDescription == "Rate limited. Try again shortly.")
    }

    @Test func httpErrorHasDescription() {
        #expect(DebridError.httpError(404, "Not Found").errorDescription == "HTTP 404: Not Found")
    }

    @Test func networkErrorHasDescription() {
        #expect(DebridError.networkError("connection lost").errorDescription == "Network error: connection lost")
    }

    @Test func timeoutHasDescription() {
        #expect(DebridError.timeout.errorDescription == "Request timed out")
    }

    @Test func allErrorsAreEquatable() {
        #expect(DebridError.unauthorized == .unauthorized)
        #expect(DebridError.unauthorized != .notPremium)
        #expect(DebridError.invalidHash("a") == .invalidHash("a"))
        #expect(DebridError.invalidHash("a") != .invalidHash("b"))
    }
}

@Suite("DebridHTTPExecutor")
struct DebridHTTPExecutorTestsDebridserviceprotocolconformancetests {

    @Test func dataReturnsDataOnSuccessfulHTTPResponse() async throws {
        let request = URLRequest(url: URL(string: "https://example.invalid/success")!)
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, "success".data(using: .utf8)!)
        }

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "success")
    }

    @Test func retryableTransportErrorRetriesAndThenSucceeds() async throws {
        let request = URLRequest(url: URL(string: "https://example.invalid/retryable")!)
        let lock = NSLock()
        var callCount = 0

        let session = URLProtocolHarness.makeSession { request in
            lock.lock()
            callCount += 1
            let current = callCount
            lock.unlock()

            if current == 1 {
                throw URLError(.cannotConnectToHost)
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        _ = try await DebridHTTPExecutor.data(for: request, session: session)
        #expect(callCount == 2)
    }

    @Test func retryableHTTPStatusRetriesThenSucceedsWithNoRetryAfter() async throws {
        let request = URLRequest(url: URL(string: "https://example.invalid/retryable-http-status")!)
        let lock = NSLock()
        var callCount = 0

        let session = URLProtocolHarness.makeSession { request in
            lock.lock()
            callCount += 1
            let current = callCount
            lock.unlock()

            if current == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, "ok".data(using: .utf8)!)
        }

        let (data, response) = try await DebridHTTPExecutor.data(for: request, session: session)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test func retryableHTTPStatusRespectsNumericRetryAfterHeader() async throws {
        let request = URLRequest(url: URL(string: "https://example.invalid/retry-after-numeric")!)
        let lock = NSLock()
        var callCount = 0

        let session = URLProtocolHarness.makeSession { request in
            lock.lock()
            callCount += 1
            let current = callCount
            lock.unlock()

            if current == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: ["Retry-After": "0"]
                )!
                return (response, Data())
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        _ = try await DebridHTTPExecutor.data(for: request, session: session)
        #expect(callCount == 2)
    }

    @Test func retryableHTTPStatusRespectsInvalidRetryAfterDateByFallingBackToBackoff() async throws {
        let request = URLRequest(url: URL(string: "https://example.invalid/retry-after-invalid-date")!)
        let lock = NSLock()
        var callCount = 0

        let session = URLProtocolHarness.makeSession { request in
            lock.lock()
            callCount += 1
            let current = callCount
            lock.unlock()

            if current == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: ["Retry-After": "not-a-date"]
                )!
                return (response, Data())
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        _ = try await DebridHTTPExecutor.data(for: request, session: session)
        #expect(callCount == 2)
    }

    @Test func retryableHTTPStatusRespectsValidRetryAfterDateAndFallsBackWhenPastDate() async throws {
        let request = URLRequest(url: URL(string: "https://example.invalid/retry-after-valid-date")!)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        let futureDate = formatter.string(from: Date().addingTimeInterval(1.0))

        let lock = NSLock()
        var callCount = 0

        let session = URLProtocolHarness.makeSession { request in
            lock.lock()
            callCount += 1
            let current = callCount
            lock.unlock()

            if current == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: ["Retry-After": futureDate]
                )!
                return (response, Data())
            }

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        _ = try await DebridHTTPExecutor.data(for: request, session: session)
        #expect(callCount == 2)
    }

    @Test func nonRetryableURLErrorIsMappedToNetworkError() async {
        let request = URLRequest(url: URL(string: "https://example.invalid/non-retryable")!)
        let session = URLProtocolHarness.makeSession { _ in
            throw URLError(.fileDoesNotExist)
        }

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError")
        } catch let error as DebridError {
            if case .networkError = error {
                // expected
            } else {
                Issue.record("Expected DebridError.networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected DebridError, got \(error)")
        }
    }

    @Test func retryableURLErrorTimesOutAfterMaxAttempts() async {
        let request = URLRequest(url: URL(string: "https://example.invalid/retryable-timeout")!)
        let session = URLProtocolHarness.makeSession { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.timeout")
        } catch let error as DebridError {
            #expect(error == .timeout)
        } catch {
            Issue.record("Expected DebridError.timeout, got \(error)")
        }
    }

    @Test func networkConnectionLostIsMappedToNetworkErrorMessage() async {
        let request = URLRequest(url: URL(string: "https://example.invalid/connection-lost")!)
        let session = URLProtocolHarness.makeSession { _ in
            throw URLError(.networkConnectionLost)
        }

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError")
        } catch let error as DebridError {
            #expect(error == .networkError("network connection was lost"))
        } catch {
            Issue.record("Expected DebridError.networkError, got \(error)")
        }
    }

    @Test func nonHTTPResponseThrowsInvalidResponseError() async {
        let request = URLRequest(url: URL(string: "https://example.invalid/non-http-response")!)
        let session = NonHTTPResponseProtocolHarness.makeSession { request in
            let response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            return (response, Data())
        }

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError for non-HTTP response")
        } catch let error as DebridError {
            if case .networkError(let message) = error {
                #expect(!message.isEmpty)
            } else {
                Issue.record("Expected DebridError.networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected DebridError, got \(error)")
        }
    }

    @Test func cancellationErrorIsRethrown() async {
        let request = URLRequest(url: URL(string: "https://example.invalid/cancelled")!)
        let session = URLProtocolHarness.makeSession { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        let task = Task {
            try await DebridHTTPExecutor.data(for: request, session: session)
        }

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test func generalErrorFallsBackToDebridErrorNetworkFailure() async {
        struct TestFailure: Error {}

        let request = URLRequest(url: URL(string: "https://example.invalid/generic-error")!)
        let session = URLProtocolHarness.makeSession { _ in
            throw TestFailure()
        }

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.networkError")
        } catch let error as DebridError {
            if case .networkError(let message) = error {
                #expect(!message.isEmpty)
            } else {
                Issue.record("Expected DebridError.networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected DebridError.networkError, got \(error)")
        }
    }

    @Test func status429RetriesUntilExhaustionThenThrowsRateLimited() async {
        let request = URLRequest(url: URL(string: "https://example.invalid/rate-limit")!)
        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            _ = try await DebridHTTPExecutor.data(for: request, session: session)
            Issue.record("Expected DebridError.rateLimited")
        } catch let error as DebridError {
            #expect(error == .rateLimited)
        } catch {
            Issue.record("Expected DebridError.rateLimited, got \(error)")
        }
    }
}

@Suite("StreamRecoveryContext")
struct StreamRecoveryContextTestsDebridserviceprotocolconformancetests {

    @Test func streamRecoveryContextNormalizesHashAndPrunesBlankFields() throws {
        let context = StreamRecoveryContext(
            infoHash: "  ABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCD  ",
            magnetURI: "   ",
            torrentId: "   ",
            resolvedDebridService: "  real_debrid  ",
            resolvedFileName: "  Movie.mkv  ",
            resolvedFileSizeBytes: 0
        )
        let recovered = try #require(context)
        #expect(recovered.infoHash == "abcdefabcdefabcdefabcdefabcdefabcdefabcd")
        #expect(recovered.magnetURI == nil)
        #expect(recovered.torrentId == nil)
        #expect(recovered.resolvedDebridService == "real_debrid")
        #expect(recovered.resolvedFileName == "Movie.mkv")
        #expect(recovered.resolvedFileSizeBytes == nil)
    }
}

@Suite("StreamInfo")
struct StreamInfoTestsDebridserviceprotocolconformancetests {

    @Test func streamInfoNormalizesRequestHeadersAndDropsInvalidEntries() {
        let normalized = StreamInfo.normalizedRequestHeaders([
            " Host ": " example.com ",
            " Referer ": " https://app.example.com/ ",
            "X-Empty": "   ",
            "Bad\nHeader": "value",
            "BadValue": "line\r\nbreak",
            "User-Agent": " VPStudio/1.0 "
        ])
        #expect(normalized?["Host"] == nil)
        #expect(normalized?["Referer"] == "https://app.example.com/")
        #expect(normalized?["User-Agent"] == "VPStudio/1.0")
        #expect(normalized?["X-Empty"] == nil)
        #expect(normalized?["Bad\nHeader"] == nil)
        #expect(normalized?["BadValue"] == nil)
        #expect(normalized?.count == 2)
    }

    @Test func streamInfoRequestHeadersReturnNilWhenAllInvalid() {
        let normalized = StreamInfo.normalizedRequestHeaders([
            "": "value",
            "X-Bad": " \t ",
            "X-CRLF\r": "good",
            "Bad\nName": "good"
        ])
        #expect(normalized == nil)
    }
}
