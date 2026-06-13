import Testing
import Foundation
import GRDB
@testable import VPStudio

// MARK: - URLProtocol Stub

private enum StubError: Error { case missingHandler }

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]
    static let lock = NSLock()
    static let handlerHeader = "X-VPStudio-Stub-ID"

    fileprivate static func register(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> String {
        let id = UUID().uuidString
        lock.lock()
        requestHandlers[id] = handler
        lock.unlock()
        return id
    }

    fileprivate static func handler(for id: String) -> ((URLRequest) throws -> (HTTPURLResponse, Data))? {
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
            client?.urlProtocol(self, didFailWithError: StubError.missingHandler); return
        }
        var sanitizedRequest = request
        sanitizedRequest.setValue(nil, forHTTPHeaderField: Self.handlerHeader)
        let requestForHandler = Self.materializeBodyIfNeeded(from: sanitizedRequest)
        do {
            let (response, data) = try handler(requestForHandler)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    override func stopLoading() {}

    private static func materializeBodyIfNeeded(from request: URLRequest) -> URLRequest {
        guard request.httpBody == nil, let bodyStream = request.httpBodyStream else {
            return request
        }
        var copy = request
        copy.httpBody = readAllBytes(from: bodyStream)
        return copy
    }

    private static func readAllBytes(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var output = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            output.append(buffer, count: read)
        }
        return output
    }
}

private func makeStubSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
    let handlerID = URLProtocolStub.register(handler)
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolStub.self]
    config.httpAdditionalHeaders = [URLProtocolStub.handlerHeader: handlerID]
    return URLSession(configuration: config)
}

private func makeNoNetworkSession() -> URLSession {
    makeStubSession { request in
        Issue.record("Unexpected network request: \(request.url?.absoluteString ?? "nil")")
        let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        return (response, Data())
    }
}

private let validInfoHash40 = "0123456789abcdef0123456789abcdef01234567"

// MARK: - Mock SecretStore

private actor MemorySecretStore: SecretStore {
    var secrets: [String: String] = [:]
    func setSecret(_ secret: String, for key: String) async throws {
        secrets[key] = secret
    }
    func getSecret(for key: String) async throws -> String? {
        secrets[key]
    }
    func deleteSecret(for key: String) async throws {
        secrets.removeValue(forKey: key)
    }
    func deleteAllSecrets() async throws {
        secrets.removeAll()
    }
}

// MARK: - Mock Debrid Service

private actor MockDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    var shouldFailAddMagnet: Bool
    var addMagnetError: DebridError?
    var simulateInvalidHash: Bool
    var selectFilesError: DebridError?
    var simulateFileNotReady: Bool
    var addMagnetCalls = 0
    var selectFilesCalled = false
    var streamURL: URL
    var fileName: String
    var addedMagnetId: String
    var selectedFiles: [Int] = []
    var cleanupCalled = false
    var cacheResult: [String: CacheStatus]

    init(
        serviceType: DebridServiceType,
        shouldFailAddMagnet: Bool = false,
        addMagnetError: DebridError? = nil,
        simulateInvalidHash: Bool = false,
        selectFilesError: DebridError? = nil,
        simulateFileNotReady: Bool = false,
        streamURL: URL = URL(string: "https://cdn.example.com/stream.mkv")!,
        fileName: String = "Movie.2025.1080p.mkv",
        addedMagnetId: String = "mock-torrent-id",
        cacheResult: [String: CacheStatus] = [:]
    ) {
        self.serviceType = serviceType
        self.shouldFailAddMagnet = shouldFailAddMagnet
        self.addMagnetError = addMagnetError
        self.simulateInvalidHash = simulateInvalidHash
        self.selectFilesError = selectFilesError
        self.simulateFileNotReady = simulateFileNotReady
        self.streamURL = streamURL
        self.fileName = fileName
        self.addedMagnetId = addedMagnetId
        self.cacheResult = cacheResult
    }

    func validateToken() async throws -> Bool { true }
    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "mock-\(serviceType.rawValue)", email: nil, premiumExpiry: nil, isPremium: true)
    }
    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        if shouldFailAddMagnet { throw DebridError.networkError("cache failed") }
        return cacheResult.isEmpty ? hashes.reduce(into: [:]) { $0[$1.lowercased()] = .notCached } : cacheResult
    }
    func addMagnet(hash: String) async throws -> String {
        addMagnetCalls += 1
        if let addMagnetError { throw addMagnetError }
        if simulateInvalidHash { throw DebridError.invalidHash(hash) }
        if shouldFailAddMagnet { throw DebridError.networkError("addMagnet failed") }
        return addedMagnetId
    }
    func selectFiles(torrentId: String, fileIds: [Int]) async throws {
        selectFilesCalled = true
        selectedFiles = fileIds
        if let selectFilesError { throw selectFilesError }
    }
    func selectMatchingEpisodeFile(torrentId: String, seasonNumber: Int, episodeNumber: Int, resolvedFileNameHint: String?, resolvedFileSizeHint: Int64?) async throws -> Bool {
        true
    }
    func cleanupRemoteTransfer(torrentId: String) async throws {
        cleanupCalled = true
    }
    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        if simulateFileNotReady { throw DebridError.fileNotReady("downloading") }
        return StreamInfo(
            streamURL: streamURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: fileName,
            sizeBytes: 1_000_000,
            debridService: serviceType.rawValue
        )
    }
    func unrestrict(link: String) async throws -> URL {
        streamURL
    }
}

private actor FlakyDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    let streamURL: URL
    let fileName: String
    let addedMagnetId: String
    var getStreamCalls = 0
    var cleanupCalled = false
    var failFileNotReadyCount: Int

    init(
        serviceType: DebridServiceType,
        failFileNotReadyCount: Int,
        streamURL: URL = URL(string: "https://cdn.example.com/stream.mkv")!,
        fileName: String = "Movie.2025.1080p.mkv",
        addedMagnetId: String = "flaky-torrent"
    ) {
        self.serviceType = serviceType
        self.failFileNotReadyCount = failFileNotReadyCount
        self.streamURL = streamURL
        self.fileName = fileName
        self.addedMagnetId = addedMagnetId
    }

    func validateToken() async throws -> Bool { true }
    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "flaky-\(serviceType.rawValue)", email: nil, premiumExpiry: nil, isPremium: true)
    }
    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] { [:] }
    func addMagnet(hash: String) async throws -> String {
        return addedMagnetId
    }
    func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
    func selectMatchingEpisodeFile(
        torrentId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> Bool {
        true
    }
    func cleanupRemoteTransfer(torrentId: String) async throws {
        cleanupCalled = true
    }
    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        getStreamCalls += 1
        if failFileNotReadyCount > 0 {
            failFileNotReadyCount -= 1
            throw DebridError.fileNotReady("not ready")
        }

        return StreamInfo(
            streamURL: streamURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: fileName,
            sizeBytes: 1_250_000,
            debridService: serviceType.rawValue
        )
    }
    func unrestrict(link: String) async throws -> URL {
        streamURL
    }
}

private actor EpisodeAwareMockDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    let shouldSelectEpisode: Bool
    let streamURL: URL
    let fileName: String
    var addedMagnetId: String
    var calls: [String] = []

    init(
        serviceType: DebridServiceType,
        shouldSelectEpisode: Bool,
        streamURL: URL = URL(string: "https://cdn.example.com/stream.mkv")!,
        fileName: String = "Show.S01E02.mkv",
        addedMagnetId: String = "episode-mock-torrent"
    ) {
        self.serviceType = serviceType
        self.shouldSelectEpisode = shouldSelectEpisode
        self.streamURL = streamURL
        self.fileName = fileName
        self.addedMagnetId = addedMagnetId
    }

    func validateToken() async throws -> Bool { true }
    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "episode-mock", email: nil, premiumExpiry: nil, isPremium: true)
    }
    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        hashes.reduce(into: [String: CacheStatus]()) { result, hash in
            result[hash] = .notCached
        }
    }
    func addMagnet(hash: String) async throws -> String {
        calls.append("add:\(hash)")
        return addedMagnetId
    }
    func addMagnet(hash: String, magnetURI: String?) async throws -> String {
        calls.append("add:\(hash)|magnet:\(magnetURI ?? "")")
        return addedMagnetId
    }
    func selectFiles(torrentId: String, fileIds: [Int]) async throws {
        calls.append("select:\(torrentId)")
    }
    func selectMatchingEpisodeFile(
        torrentId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> Bool {
        calls.append("match:\(torrentId):\(seasonNumber):\(episodeNumber)")
        return shouldSelectEpisode
    }
    func cleanupRemoteTransfer(torrentId: String) async throws {
        calls.append("cleanup:\(torrentId)")
    }
    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        calls.append("stream:\(torrentId)")
        return StreamInfo(
            streamURL: streamURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: fileName,
            sizeBytes: 1_500_000,
            debridService: serviceType.rawValue
        )
    }
    func unrestrict(link: String) async throws -> URL {
        streamURL
    }

    func callSequence() -> [String] {
        calls
    }
}

private enum ErrorInjectingDebridStreamError: Error {
    case upstreamFailure
}

private actor ErrorInjectingDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    let getStreamError: Error
    let cleanupError: Error?
    var addMagnetCalls = 0
    var cleanupCalls = 0
    var selectFilesCalled = false

    init(
        serviceType: DebridServiceType,
        getStreamError: Error,
        cleanupError: Error? = nil
    ) {
        self.serviceType = serviceType
        self.getStreamError = getStreamError
        self.cleanupError = cleanupError
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(
            username: "error-injecting-\(serviceType.rawValue)",
            email: nil,
            premiumExpiry: nil,
            isPremium: true
        )
    }

    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        hashes.reduce(into: [String: CacheStatus]()) { result, hash in
            result[hash] = .notCached
        }
    }

    func addMagnet(hash: String) async throws -> String {
        addMagnetCalls += 1
        return "\(serviceType.rawValue)-\(hash)"
    }

    func selectFiles(torrentId: String, fileIds: [Int]) async throws {
        selectFilesCalled = true
    }

    func selectMatchingEpisodeFile(
        torrentId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> Bool {
        true
    }

    func cleanupRemoteTransfer(torrentId: String) async throws {
        cleanupCalls += 1
        if let cleanupError {
            throw cleanupError
        }
    }

    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        throw getStreamError
    }

    func unrestrict(link: String) async throws -> URL {
        URL(string: "https://cdn.example.com/error-injecting.mkv")!
    }

    func observedAddMagnetCalls() async -> Int {
        addMagnetCalls
    }

    func observedCleanupCalls() async -> Int {
        cleanupCalls
    }

    func observedSelectFilesCalled() async -> Bool {
        selectFilesCalled
    }
}

private actor ExtraneousCacheResultService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    var checkCacheCalls = 0

    init(serviceType: DebridServiceType) {
        self.serviceType = serviceType
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "extraneous-\(serviceType.rawValue)", email: nil, premiumExpiry: nil, isPremium: true)
    }

    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        checkCacheCalls += 1
        return hashes.reduce(into: [String: CacheStatus]()) { result, hash in
            result[hash] = .notCached
        }.merging(["unexpected-cache-entry": .cached(fileId: nil, fileName: "bonus.mkv", fileSize: 11_111)], uniquingKeysWith: { current, _ in current })
    }

    func addMagnet(hash: String) async throws -> String {
        "\(serviceType.rawValue)-\(hash)"
    }

    func selectFiles(torrentId: String, fileIds: [Int]) async throws {}

    func selectMatchingEpisodeFile(
        torrentId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> Bool {
        true
    }

    func cleanupRemoteTransfer(torrentId: String) async throws {}

    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/extraneous.mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "extraneous.mkv",
            sizeBytes: 100,
            debridService: serviceType.rawValue
        )
    }

    func unrestrict(link: String) async throws -> URL {
        URL(string: "https://cdn.example.com/extraneous-unrestrict.mkv")!
    }

    func observedCheckCacheCalls() async -> Int {
        checkCacheCalls
    }
}

private actor CapturingCacheDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    let streamURL: URL
    let fileName: String
    var cacheCalls: [[String]] = []
    var cacheResult: [String: CacheStatus]

    init(
        serviceType: DebridServiceType,
        cacheResult: [String: CacheStatus] = [:],
        streamURL: URL = URL(string: "https://cdn.example.com/stream.mkv")!,
        fileName: String = "Movie.2025.1080p.mkv"
    ) {
        self.serviceType = serviceType
        self.cacheResult = cacheResult
        self.streamURL = streamURL
        self.fileName = fileName
    }

    func validateToken() async throws -> Bool { true }
    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "capturing-\(serviceType.rawValue)", email: nil, premiumExpiry: nil, isPremium: true)
    }
    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        cacheCalls.append(hashes)
        return cacheResult.isEmpty
            ? hashes.reduce(into: [:]) { $0[$1] = .notCached }
            : cacheResult
    }
    func addMagnet(hash: String) async throws -> String {
        "\(serviceType.rawValue)-\(hash)"
    }
    func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
    func selectMatchingEpisodeFile(
        torrentId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> Bool { false }
    func cleanupRemoteTransfer(torrentId: String) async throws {}
    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        StreamInfo(
            streamURL: streamURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: fileName,
            sizeBytes: 1_000_000,
            debridService: serviceType.rawValue
        )
    }
    func unrestrict(link: String) async throws -> URL {
        streamURL
    }

    func capturedCacheCalls() async -> [[String]] {
        cacheCalls
    }
}

// MARK: - Test Helpers

private func makeInMemoryDB() throws -> DatabaseManager {
    try DatabaseManager(inMemoryNamed: "test-\(UUID().uuidString)")
}

private func makeDebridConfig(id: String, type: DebridServiceType, priority: Int = 0, tokenRef: String) -> DebridConfig {
    DebridConfig(
        id: id,
        serviceType: type,
        apiTokenRef: tokenRef,
        isActive: true,
        priority: priority,
        createdAt: Date(),
        updatedAt: Date()
    )
}

// MARK: - DebridManager Tests

@Suite("DebridManager")
struct DebridManagerTests {
    @Test func initializeWithNoConfigsCreatesEmptyServices() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let manager = DebridManager(database: db, secretStore: secretStore)
        try await manager.initialize()
        let services = await manager.availableServices()
        #expect(services.isEmpty)
    }

    @Test func initializeFiltersOutEasyNewsAndMissingTokens() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let rdConfig = makeDebridConfig(id: "rd-1", type: .realDebrid, tokenRef: "")
        let enConfig = makeDebridConfig(id: "en-1", type: .easyNews, tokenRef: SecretReference.encode(key: "key"))
        try await db.saveDebridConfig(rdConfig)
        try await db.saveDebridConfig(enConfig)

        let manager = DebridManager(database: db, secretStore: secretStore)
        try await manager.initialize()
        let services = await manager.availableServices()
        #expect(services.isEmpty)
    }

    @Test func initializeSkipsMissingTokenConfigsButKeepsValidServices() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let validKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-valid")
        let missingKey = SecretKey.debridToken(service: .torBox, configId: "tb-missing")
        try await secretStore.setSecret("rd-token", for: validKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-valid",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: validKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-missing",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: missingKey)
            )
        )

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()

        let services = await manager.availableServices()
        #expect(services == [.realDebrid])
        #expect(await manager.getService(.realDebrid) != nil)
        #expect(await manager.getService(.torBox) == nil)
    }

    @Test func initializeSkipsEasyNewsEvenWithValidToken() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let rdKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-easynews")
        let easyNewsKey = SecretKey.debridToken(service: .easyNews, configId: "en-easynews")
        try await secretStore.setSecret("rd-token", for: rdKey)
        try await secretStore.setSecret("easynews-token", for: easyNewsKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-easynews",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: rdKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "en-easynews",
                type: .easyNews,
                tokenRef: SecretReference.encode(key: easyNewsKey)
            )
        )

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()

        let services = await manager.availableServices()
        #expect(services == [.realDebrid])
        #expect(await manager.getService(.realDebrid) != nil)
        #expect(await manager.getService(.easyNews) == nil)
    }

    @Test func initializeResolvesSecretReferenceTokens() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .allDebrid, configId: "ad-1")
        try await secretStore.setSecret("ad-token", for: key)

        let config = makeDebridConfig(id: "ad-1", type: .allDebrid, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let manager = DebridManager(database: db, secretStore: secretStore)
        try await manager.initialize()
        let services = await manager.availableServices()
        #expect(services == [.allDebrid])
    }

    @Test func initializeSkipsConfigWhenSecretReferenceTokenMissing() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let missingKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-missing-secret")
        let config = makeDebridConfig(
            id: "rd-missing-secret",
            type: .realDebrid,
            tokenRef: SecretReference.encode(key: missingKey)
        )
        try await db.saveDebridConfig(config)

        let manager = DebridManager(database: db, secretStore: secretStore)
        try await manager.initialize()
        let services = await manager.availableServices()
        #expect(services.isEmpty)
    }

    @Test func initializeMigratesLegacyPlaintextTokenRefToSecretReference() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let configId = "rd-legacy"
        let plaintextToken = "legacy-token"

        let config = makeDebridConfig(
            id: configId,
            type: .realDebrid,
            tokenRef: plaintextToken
        )
        try await db.saveDebridConfig(config)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                #expect(token == plaintextToken)
                return MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()

        let configs = try await db.fetchAllDebridConfigs()
        let persisted = try #require(configs.first(where: { $0.id == configId }))
        let secretKey = SecretKey.debridToken(service: .realDebrid, configId: configId)
        #expect(persisted.apiTokenRef == SecretReference.encode(key: secretKey))
        let storedSecret = try await secretStore.getSecret(for: secretKey)
        #expect(storedSecret == plaintextToken)
    }

    @Test func initializeSkipsConfigWhenLegacyPlaintextTokenRefIsOnlyWhitespace() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let config = makeDebridConfig(id: "rd-whitespace", type: .realDebrid, tokenRef: "   \t\n")
        try await db.saveDebridConfig(config)

        let manager = DebridManager(database: db, secretStore: secretStore)
        try await manager.initialize()
        #expect(await manager.availableServices().isEmpty)
    }

    @Test func initializeMigratesLegacyPlaintextTokenRefWithWhitespaceTrimmed() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let configId = "rd-legacy-whitespace"
        let plaintextToken = "legacy-token-whitespace"

        let config = makeDebridConfig(
            id: configId,
            type: .realDebrid,
            tokenRef: "  \(plaintextToken)  "
        )
        try await db.saveDebridConfig(config)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                #expect(token == plaintextToken)
                return MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()

        let configs = try await db.fetchAllDebridConfigs()
        let persisted = try #require(configs.first(where: { $0.id == configId }))
        let secretKey = SecretKey.debridToken(service: .realDebrid, configId: configId)
        #expect(persisted.apiTokenRef == SecretReference.encode(key: secretKey))
        let storedSecret = try await secretStore.getSecret(for: secretKey)
        #expect(storedSecret == plaintextToken)
    }

    @Test func initializeTrimsWhitespaceAroundSecretReferenceBeforeLookup() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let configId = "rd-trim-secret-ref"
        let tokenKey = SecretKey.debridToken(service: .realDebrid, configId: configId)
        let token = "trimmed-secret-token"
        try await secretStore.setSecret(token, for: tokenKey)

        let encodedRef = SecretReference.encode(key: tokenKey)
        let config = makeDebridConfig(
            id: configId,
            type: .realDebrid,
            tokenRef: "  \(encodedRef)  "
        )
        try await db.saveDebridConfig(config)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, lookupToken in
                #expect(lookupToken == token)
                return MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()
    }

    @Test func availableServicesReturnsSortedByRawValue() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let types: [DebridServiceType] = [.torBox, .realDebrid, .premiumize]
        for type in types {
            let key = SecretKey.debridToken(service: type, configId: "\(type.rawValue)-1")
            try await secretStore.setSecret("token", for: key)
            let config = makeDebridConfig(id: "\(type.rawValue)-1", type: type, tokenRef: SecretReference.encode(key: key))
            try await db.saveDebridConfig(config)
        }

        let manager = DebridManager(database: db, secretStore: secretStore)
        try await manager.initialize()
        let services = await manager.availableServices()
        #expect(services == [.premiumize, .realDebrid, .torBox])
    }

    @Test func getServiceReturnsConfiguredService() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .debridLink, configId: "dl-1")
        try await secretStore.setSecret("dl-token", for: key)

        let config = makeDebridConfig(id: "dl-1", type: .debridLink, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let manager = DebridManager(database: db, secretStore: secretStore)
        try await manager.initialize()
        let dlService = await manager.getService(.debridLink)
        let rdService = await manager.getService(.realDebrid)
        #expect(dlService != nil)
        #expect(rdService == nil)
    }

    @Test func checkCacheAcrossServicesReturnsEmptyWhenNoServices() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let manager = DebridManager(database: db, secretStore: MemorySecretStore())
        let result = try await manager.checkCacheAcrossServices(hashes: [validInfoHash40])
        #expect(result.isEmpty)
    }

    @Test func checkCacheAcrossServicesReturnsEmptyForNoHashesWithoutQueryingServices() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-empty-cache")
        try await secretStore.setSecret("rd-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-empty-cache",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let service = CapturingCacheDebridService(serviceType: .realDebrid)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { _, _ in
                service
            }
        )
        try await manager.initialize()
        let result = try await manager.checkCacheAcrossServices(hashes: [])
        let calls = await service.capturedCacheCalls()

        #expect(result.isEmpty)
        #expect(calls.isEmpty)
    }

    @Test func checkCacheAcrossServicesIgnoresInvalidInputHashes() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-invalid-input")
        try await secretStore.setSecret("rd-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-invalid-input",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let service = CapturingCacheDebridService(serviceType: .realDebrid)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { _, _ in service }
        )
        try await manager.initialize()

        let invalidHashInput = "not-a-valid-hash"
        let tooShort = "12345"
        let validCopy = validInfoHash40.uppercased()

        let result = try await manager.checkCacheAcrossServices(hashes: [
            "   ",
            "",
            invalidHashInput,
            tooShort,
            validCopy,
            validCopy
        ])
        let calls = await service.capturedCacheCalls()

        #expect(calls == [[validInfoHash40]])
        #expect(result.count == 1)
        #expect(result[validInfoHash40] != nil)
        #expect(result[invalidHashInput] == nil)
        #expect(result[tooShort] == nil)
    }

    @Test func checkCacheAcrossServicesIgnoresMalformedHashesEvenIfServiceReturnsValues() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-cache-validated")
        try await secretStore.setSecret("cache-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-cache-validated",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let service = CapturingCacheDebridService(
            serviceType: .realDebrid,
            cacheResult: [
                validInfoHash40: .cached(fileId: "cached-id", fileName: "Movie.mkv", fileSize: 1_000_000)
            ]
        )
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                service
            }
        )
        try await manager.initialize()

        let result = try await manager.checkCacheAcrossServices(hashes: [
            "12345",
            "not-a-valid-hash",
            validInfoHash40
        ])
        let calls = await service.capturedCacheCalls()

        #expect(calls == [[validInfoHash40]])
        #expect(result.count == 1)
        #expect(result[validInfoHash40]?.0 == .cached(fileId: "cached-id", fileName: "Movie.mkv", fileSize: 1_000_000))
        #expect(result["12345"] == nil)
        #expect(result["not-a-valid-hash"] == nil)
    }

    @Test func checkCacheAcrossServicesAcceptsValidSha256Hashes() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-cache-sha256")
        try await secretStore.setSecret("sha256-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-cache-sha256",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let sha256Hash = String(repeating: "f", count: 64)
        let service = CapturingCacheDebridService(
            serviceType: .realDebrid,
            cacheResult: [
                sha256Hash: .cached(fileId: "sha256-id", fileName: "SHA256Movie.mkv", fileSize: 2_000_000)
            ]
        )
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                service
            }
        )
        try await manager.initialize()

        let result = try await manager.checkCacheAcrossServices(hashes: [
            sha256Hash.uppercased()
        ])
        let calls = await service.capturedCacheCalls()

        #expect(calls == [[sha256Hash]])
        #expect(result.count == 1)
        #expect(result[sha256Hash]?.0 == .cached(fileId: "sha256-id", fileName: "SHA256Movie.mkv", fileSize: 2_000_000))
    }

    @Test func checkCacheAcrossServicesQueriesSingleService() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-1")
        try await secretStore.setSecret("rd-token", for: key)
        let config = makeDebridConfig(id: "rd-1", type: .realDebrid, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(
                    serviceType: type,
                    cacheResult: [validInfoHash40: .cached(fileId: nil, fileName: nil, fileSize: nil)]
                )
            }
        )
        try await manager.initialize()
        let result = try await manager.checkCacheAcrossServices(hashes: [validInfoHash40])
        #expect(result[validInfoHash40]?.0 == .cached(fileId: nil, fileName: nil, fileSize: nil))
        #expect(result[validInfoHash40]?.1 == .realDebrid)
    }

    @Test func checkCacheAcrossServicesNormalizesReturnedHashKeys() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-case-1")
        try await secretStore.setSecret("rd-token", for: key)
        let config = makeDebridConfig(id: "rd-case-1", type: .realDebrid, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let cacheResult: [String: CacheStatus] = [
            validInfoHash40.uppercased(): .cached(fileId: nil, fileName: "Movie.mkv", fileSize: 1_048_576)
        ]

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(
                    serviceType: type,
                    cacheResult: cacheResult
                )
            }
        )
        try await manager.initialize()
        let result = try await manager.checkCacheAcrossServices(hashes: [validInfoHash40])

        #expect(result[validInfoHash40]?.0 == .cached(fileId: nil, fileName: "Movie.mkv", fileSize: 1_048_576))
        #expect(result[validInfoHash40]?.1 == .realDebrid)
    }

    @Test func checkCacheAcrossServicesNormalizesWhitespaceInReturnedHashKeys() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-case-whitespace")
        try await secretStore.setSecret("rd-token", for: key)
        let config = makeDebridConfig(id: "rd-case-whitespace", type: .realDebrid, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let serviceReturnedHash = "  \(validInfoHash40.uppercased())  "
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(
                    serviceType: type,
                    cacheResult: [serviceReturnedHash: .cached(fileId: nil, fileName: "Movie.mkv", fileSize: 1_000_000)]
                )
            }
        )
        try await manager.initialize()

        let result = try await manager.checkCacheAcrossServices(hashes: [validInfoHash40])

        #expect(result[validInfoHash40]?.0 == .cached(fileId: nil, fileName: "Movie.mkv", fileSize: 1_000_000))
        #expect(result[serviceReturnedHash] == nil)
    }

    @Test func checkCacheAcrossServicesNormalizesAndDeduplicatesInputHashesBeforeServiceQueries() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-normalize-input")
        try await secretStore.setSecret("rd-token", for: key)
        let config = makeDebridConfig(id: "rd-normalize-input", type: .realDebrid, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let secondaryHash = String(repeating: "b", count: 40)
        let cacheResult: [String: CacheStatus] = [
            validInfoHash40: .cached(fileId: nil, fileName: "Movie.mkv", fileSize: 2_097_152),
            secondaryHash: .notCached
        ]
        let service = CapturingCacheDebridService(
            serviceType: .realDebrid,
            cacheResult: cacheResult
        )

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                service
            }
        )
        try await manager.initialize()

        let result = try await manager.checkCacheAcrossServices(
            hashes: [
                "  \(validInfoHash40.uppercased()) ",
                validInfoHash40.uppercased(),
                secondaryHash,
                secondaryHash.uppercased(),
            ]
        )
        let captured = await service.capturedCacheCalls()

        #expect(captured == [[validInfoHash40, secondaryHash]])
        #expect(result[validInfoHash40]?.0 == .cached(fileId: nil, fileName: "Movie.mkv", fileSize: 2_097_152))
        #expect(result[secondaryHash]?.0 == .notCached)
    }

    @Test func checkCacheAcrossServicesPropagatesFirstFailureWhenAllFail() async {
        let db = try? makeInMemoryDB()
        try? await db?.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .allDebrid, configId: "ad-1")
        try? await secretStore.setSecret("token", for: key)
        let config = makeDebridConfig(id: "ad-1", type: .allDebrid, tokenRef: SecretReference.encode(key: key))
        try? await db?.saveDebridConfig(config)

        let manager = DebridManager(
            database: db!,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(serviceType: type, shouldFailAddMagnet: true)
            }
        )
        try? await manager.initialize()
        await #expect(throws: DebridError.networkError("cache failed")) {
            _ = try await manager.checkCacheAcrossServices(hashes: [validInfoHash40])
        }
    }

    @Test func checkCacheAcrossServicesMarksUnresolvedAsNotCachedWhenSomeSucceed() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .torBox, configId: "tb-1")
        try await secretStore.setSecret("token", for: key)
        let config = makeDebridConfig(id: "tb-1", type: .torBox, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()
        let result = try await manager.checkCacheAcrossServices(hashes: [validInfoHash40])
        #expect(result[validInfoHash40]?.0 == .notCached)
        #expect(result[validInfoHash40]?.1 == .torBox)
    }

    @Test func checkCacheAcrossServicesFallsBackToUnknownWhenAllServicesFailThenSomeCachedLater() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        try await secretStore.setSecret("rd-token", for: SecretKey.debridToken(service: .realDebrid, configId: "rd-fail-then-cached"))
        try await secretStore.setSecret("tb-token", for: SecretKey.debridToken(service: .torBox, configId: "tb-fail-then-cached"))

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-fail-then-cached",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: SecretKey.debridToken(service: .realDebrid, configId: "rd-fail-then-cached"))
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-fail-then-cached",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: SecretKey.debridToken(service: .torBox, configId: "tb-fail-then-cached"))
            )
        )

        let cachedHash = validInfoHash40
        let unresolvedHash = String(repeating: "f", count: 40)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                switch type {
                case .realDebrid:
                    MockDebridService(serviceType: type, shouldFailAddMagnet: true)
                case .torBox:
                    MockDebridService(
                        serviceType: type,
                        cacheResult: [
                            cachedHash: .cached(fileId: "cached", fileName: "Cached.mkv", fileSize: 1_111_111)
                        ]
                    )
                default:
                    MockDebridService(serviceType: type)
                }
            }
        )
        try await manager.initialize()

        let result = try await manager.checkCacheAcrossServices(hashes: [cachedHash, unresolvedHash])

        #expect(result[cachedHash]?.0 == .cached(fileId: "cached", fileName: "Cached.mkv", fileSize: 1_111_111))
        #expect(result[cachedHash]?.1 == .torBox)
        #expect(result[unresolvedHash]?.0 == .unknown)
        #expect(result[unresolvedHash]?.1 == .torBox)
    }

    @Test func checkCacheAcrossServicesAvoidsRecheckingKnownCachedHashesInLaterServices() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let secondaryHash = String(repeating: "b", count: 40)

        let realDebridKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-cache-first")
        let torBoxKey = SecretKey.debridToken(service: .torBox, configId: "tb-cache-second")
        try await secretStore.setSecret("rd-token", for: realDebridKey)
        try await secretStore.setSecret("tb-token", for: torBoxKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-cache-first",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: realDebridKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-cache-second",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: torBoxKey)
            )
        )

        let firstService = CapturingCacheDebridService(
            serviceType: .realDebrid,
            cacheResult: [
                validInfoHash40: .cached(fileId: "rd-file", fileName: "RealCached.mkv", fileSize: 1_000_000)
            ]
        )
        let secondService = CapturingCacheDebridService(
            serviceType: .torBox,
            cacheResult: [
                secondaryHash: .cached(fileId: "tb-file", fileName: "TorBoxCached.mkv", fileSize: 2_000_000)
            ]
        )

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                switch type {
                case .realDebrid: firstService
                case .torBox: secondService
                default: firstService
                }
            }
        )
        try await manager.initialize()

        let result = try await manager.checkCacheAcrossServices(hashes: [validInfoHash40, secondaryHash])
        let firstCalls = await firstService.capturedCacheCalls()
        let secondCalls = await secondService.capturedCacheCalls()

        #expect(firstCalls == [[validInfoHash40, secondaryHash]])
        #expect(secondCalls == [[secondaryHash]])
        #expect(result[validInfoHash40]?.0 == .cached(fileId: "rd-file", fileName: "RealCached.mkv", fileSize: 1_000_000))
        #expect(result[validInfoHash40]?.1 == .realDebrid)
        #expect(result[secondaryHash]?.0 == .cached(fileId: "tb-file", fileName: "TorBoxCached.mkv", fileSize: 2_000_000))
        #expect(result[secondaryHash]?.1 == .torBox)
    }

    @Test func resolveStreamThrowsWhenNoServicesConfigured() async {
        let db = try? makeInMemoryDB()
        try? await db?.migrate()
        let manager = DebridManager(database: db!, secretStore: MemorySecretStore())
        await #expect(throws: DebridError.networkError("No debrid services configured. Add one in Settings > Debrid Services.")) {
            _ = try await manager.resolveStream(hash: validInfoHash40)
        }
    }

    @Test func resolveStreamReturnsStreamFromFirstSuccessfulService() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .premiumize, configId: "pm-1")
        try await secretStore.setSecret("token", for: key)
        let config = makeDebridConfig(id: "pm-1", type: .premiumize, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()
        let stream = try await manager.resolveStream(hash: validInfoHash40)
        #expect(stream.debridService == DebridServiceType.premiumize.rawValue)
    }

    @Test func resolveStreamFallsBackWhenNonEpisodeFileSelectionFailsOnPreferredService() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let rdKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-select-fail")
        let tbKey = SecretKey.debridToken(service: .torBox, configId: "tb-select-fallback")
        try await secretStore.setSecret("rd-token", for: rdKey)
        try await secretStore.setSecret("tb-token", for: tbKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-select-fail",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: rdKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-select-fallback",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: tbKey)
            )
        )

        let failingService = MockDebridService(
            serviceType: .realDebrid,
            selectFilesError: .networkError("file selection failed")
        )
        let fallbackService = MockDebridService(serviceType: .torBox)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                switch type {
                case .realDebrid:
                    return failingService
                case .torBox:
                    return fallbackService
                default:
                    return fallbackService
                }
            }
        )
        try await manager.initialize()

        let stream = try await manager.resolveStream(hash: validInfoHash40)

        let failingSelectCalled = await failingService.selectFilesCalled
        let fallbackSelectCalled = await fallbackService.selectFilesCalled
        let primaryCleanupCalled = await failingService.cleanupCalled

        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
        #expect(failingSelectCalled)
        #expect(fallbackSelectCalled)
        #expect(primaryCleanupCalled)
    }

    @Test func resolveStreamPrefersConfiguredPreferredService() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        for type in [DebridServiceType.realDebrid, .allDebrid] {
            let key = SecretKey.debridToken(service: type, configId: "\(type.rawValue)-1")
            try await secretStore.setSecret("token", for: key)
            let config = makeDebridConfig(id: "\(type.rawValue)-1", type: type, priority: type == .realDebrid ? 1 : 2, tokenRef: SecretReference.encode(key: key))
            try await db.saveDebridConfig(config)
        }

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()
        let stream = try await manager.resolveStream(hash: validInfoHash40, preferredService: .allDebrid)
        #expect(stream.debridService == DebridServiceType.allDebrid.rawValue)
    }

    @Test func resolveStreamFromContextFallsBackAfterPrimarySelectFilesFailure() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let rdKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-context-select-fail")
        let tbKey = SecretKey.debridToken(service: .torBox, configId: "tb-context-select-fail")
        try await secretStore.setSecret("rd-token", for: rdKey)
        try await secretStore.setSecret("tb-token", for: tbKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-context-select-fail",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: rdKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-context-select-fail",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: tbKey)
            )
        )

        let primaryService = MockDebridService(
            serviceType: .realDebrid,
            selectFilesError: .networkError("select failed")
        )
        let fallbackService = MockDebridService(serviceType: .torBox)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                switch type {
                case .realDebrid: primaryService
                case .torBox: fallbackService
                default: primaryService
                }
            }
        )
        try await manager.initialize()

        let context = StreamRecoveryContext(
            infoHash: validInfoHash40,
            torrentId: "context-select-fail-torrent",
            resolvedDebridService: DebridServiceType.realDebrid.rawValue
        )!
        let stream = try await manager.resolveStream(from: context)

        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
        #expect(await primaryService.cleanupCalled)
        #expect(await primaryService.selectFilesCalled)
        #expect(await fallbackService.addMagnetCalls == 1)
        #expect(await primaryService.addMagnetCalls == 1)
    }

    @Test func resolveStreamFallsBackToNextServiceWhenEpisodeMatchFails() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let realDebridKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-fallback")
        let torBoxKey = SecretKey.debridToken(service: .torBox, configId: "tb-fallback")
        try await secretStore.setSecret("rd-token", for: realDebridKey)
        try await secretStore.setSecret("tb-token", for: torBoxKey)

        try await db.saveDebridConfig(
            makeDebridConfig(id: "rd-fallback", type: .realDebrid, priority: 0, tokenRef: SecretReference.encode(key: realDebridKey))
        )
        try await db.saveDebridConfig(
            makeDebridConfig(id: "tb-fallback", type: .torBox, priority: 1, tokenRef: SecretReference.encode(key: torBoxKey))
        )

        let failingService = EpisodeAwareMockDebridService(
            serviceType: .realDebrid,
            shouldSelectEpisode: false,
            streamURL: URL(string: "https://cdn.example.com/real-fallback.mkv")!,
            addedMagnetId: "rd-fallback-torrent"
        )
        let successService = EpisodeAwareMockDebridService(
            serviceType: .torBox,
            shouldSelectEpisode: true,
            streamURL: URL(string: "https://cdn.example.com/torbox-fallback.mkv")!,
            addedMagnetId: "tb-fallback-torrent"
        )

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                switch type {
                case .realDebrid: failingService
                case .torBox: successService
                default: MockDebridService(serviceType: type)
                }
            }
        )
        try await manager.initialize()

        let stream = try await manager.resolveStream(
            hash: validInfoHash40,
            seasonNumber: 2,
            episodeNumber: 9
        )
        let failingCalls = await failingService.callSequence()
        let successCalls = await successService.callSequence()

        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
        #expect(failingCalls == [
            "add:\(validInfoHash40)|magnet:",
            "match:rd-fallback-torrent:2:9",
            "cleanup:rd-fallback-torrent",
        ])
        #expect(successCalls == [
            "add:\(validInfoHash40)|magnet:",
            "match:tb-fallback-torrent:2:9",
            "stream:tb-fallback-torrent",
        ])
    }

    @Test func resolveStreamUsesFallbackFileSelectionWhenOnlyEpisodeHintProvided() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-partial-episode-hint")
        try await secretStore.setSecret("token", for: key)
        let config = makeDebridConfig(
            id: "rd-partial-episode-hint",
            type: .realDebrid,
            tokenRef: SecretReference.encode(key: key)
        )
        try await db.saveDebridConfig(config)

        let service = MockDebridService(serviceType: .realDebrid)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                service
            }
        )
        try await manager.initialize()

        let stream = try await manager.resolveStream(
            hash: validInfoHash40,
            seasonNumber: 2,
            episodeNumber: nil
        )

        #expect(await service.selectFilesCalled)
        #expect(await service.addMagnetCalls == 1)
        #expect(stream.debridService == DebridServiceType.realDebrid.rawValue)
        #expect(await service.selectedFiles == [])
    }

    @Test func resolveStreamFallsBackToNextServiceOnRecoverableError() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        for type in [DebridServiceType.realDebrid, .torBox] {
            let key = SecretKey.debridToken(service: type, configId: "\(type.rawValue)-1")
            try await secretStore.setSecret("token", for: key)
            let config = makeDebridConfig(id: "\(type.rawValue)-1", type: type, tokenRef: SecretReference.encode(key: key))
            try await db.saveDebridConfig(config)
        }

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(
                    serviceType: type,
                    shouldFailAddMagnet: type == .realDebrid
                )
            }
        )
        try await manager.initialize()
        let stream = try await manager.resolveStream(hash: validInfoHash40)
        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
    }

    @Test func resolveStreamFallsBackToNextServiceOnTimeoutFromPrimary() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        for type in [DebridServiceType.realDebrid, .torBox] {
            let key = SecretKey.debridToken(service: type, configId: "\(type.rawValue)-timeout")
            try await secretStore.setSecret("token", for: key)
            let config = makeDebridConfig(id: "\(type.rawValue)-timeout", type: type, tokenRef: SecretReference.encode(key: key))
            try await db.saveDebridConfig(config)
        }

        let primary = MockDebridService(serviceType: .realDebrid, addMagnetError: .timeout)
        let fallback = MockDebridService(serviceType: .torBox)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                switch type {
                case .realDebrid:
                    primary
                case .torBox:
                    fallback
                default:
                    fallback
                }
            }
        )
        try await manager.initialize()

        let stream = try await manager.resolveStream(hash: validInfoHash40)
        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
        #expect(await primary.addMagnetCalls == 1)
        #expect(await fallback.addMagnetCalls == 1)
    }

    @Test func resolveStreamFallsBackToConfiguredServiceWhenPreferredServiceNotConfigured() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let torBoxKey = SecretKey.debridToken(service: .torBox, configId: "tb-unconfigured-preferred")
        let realDebridKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-unconfigured-preferred")
        try await secretStore.setSecret("tb-token", for: torBoxKey)
        try await secretStore.setSecret("rd-token", for: realDebridKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-unconfigured-preferred",
                type: .torBox,
                priority: 0,
                tokenRef: SecretReference.encode(key: torBoxKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-unconfigured-preferred",
                type: .realDebrid,
                priority: 1,
                tokenRef: SecretReference.encode(key: realDebridKey)
            )
        )

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()
        let stream = try await manager.resolveStream(
            hash: validInfoHash40,
            preferredService: .allDebrid
        )
        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
    }

    @Test func resolveStreamFailsOverFromRealDebrid451ToTorBox() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        for type in [DebridServiceType.realDebrid, .torBox] {
            let key = SecretKey.debridToken(service: type, configId: "\(type.rawValue)-451")
            try await secretStore.setSecret("token", for: key)
            let config = makeDebridConfig(id: "\(type.rawValue)-451", type: type, tokenRef: SecretReference.encode(key: key))
            try await db.saveDebridConfig(config)
        }

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                MockDebridService(
                    serviceType: type,
                    addMagnetError: type == .realDebrid ? .unavailableForLegalReasons("HTTP 451") : nil
                )
            }
        )
        try await manager.initialize()

        let stream = try await manager.resolveStream(hash: validInfoHash40)
        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
    }

    @Test func resolveStreamDoesNotFallbackOnInvalidHash() async {
        let db = try? makeInMemoryDB()
        try? await db?.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .offcloud, configId: "oc-1")
        try? await secretStore.setSecret("token", for: key)
        let config = makeDebridConfig(id: "oc-1", type: .offcloud, tokenRef: SecretReference.encode(key: key))
        try? await db?.saveDebridConfig(config)

        let manager = DebridManager(
            database: db!,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(serviceType: type, simulateInvalidHash: true)
            }
        )
        try? await manager.initialize()
        await #expect(throws: DebridError.invalidHash(validInfoHash40)) {
            _ = try await manager.resolveStream(hash: validInfoHash40)
        }
    }

    @Test func resolveStreamDoesNotFallbackToNextServiceOnInvalidHashFromPrimary() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let rdKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-invalid-hash-primary")
        let tbKey = SecretKey.debridToken(service: .torBox, configId: "tb-invalid-hash-fallback")
        try await secretStore.setSecret("rd-token", for: rdKey)
        try await secretStore.setSecret("tb-token", for: tbKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-invalid-hash-primary",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: rdKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-invalid-hash-fallback",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: tbKey)
            )
        )

        let primary = MockDebridService(serviceType: .realDebrid, simulateInvalidHash: true)
        let fallback = MockDebridService(serviceType: .torBox)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                switch type {
                case .realDebrid:
                    primary
                case .torBox:
                    fallback
                default:
                    fallback
                }
            }
        )
        try await manager.initialize()

        await #expect(throws: DebridError.invalidHash(validInfoHash40)) {
            _ = try await manager.resolveStream(hash: validInfoHash40)
        }

        #expect(await primary.addMagnetCalls == 1)
        #expect(await fallback.addMagnetCalls == 0)
    }

    @Test func resolveStreamFromContextDoesNotFailoverOnInvalidHashFromPrimary() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let rdKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-context-invalid-hash-primary")
        let tbKey = SecretKey.debridToken(service: .torBox, configId: "tb-context-invalid-hash-fallback")
        try await secretStore.setSecret("rd-token", for: rdKey)
        try await secretStore.setSecret("tb-token", for: tbKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-context-invalid-hash-primary",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: rdKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-context-invalid-hash-fallback",
                type: .torBox,
                tokenRef: SecretReference.encode(key: tbKey)
            )
        )

        let primary = MockDebridService(serviceType: .realDebrid, simulateInvalidHash: true)
        let fallback = MockDebridService(serviceType: .torBox)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                switch type {
                case .realDebrid:
                    primary
                case .torBox:
                    fallback
                default:
                    fallback
                }
            }
        )
        try await manager.initialize()

        let context = StreamRecoveryContext(
            infoHash: validInfoHash40,
            preferredService: .realDebrid,
            torrentId: "context-invalid-hash-primary-torrent",
            resolvedDebridService: DebridServiceType.realDebrid.rawValue
        )!

        await #expect(throws: DebridError.invalidHash(validInfoHash40)) {
            _ = try await manager.resolveStream(from: context)
        }

        #expect(await primary.addMagnetCalls == 1)
        #expect(await fallback.addMagnetCalls == 0)
    }

    @Test func resolveStreamFromContextUsesResolvedServiceAndCleanup() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .debridLink, configId: "dl-1")
        try await secretStore.setSecret("token", for: key)
        let config = makeDebridConfig(id: "dl-1", type: .debridLink, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()

        let context = StreamRecoveryContext(
            infoHash: validInfoHash40,
            preferredService: .debridLink,
            seasonNumber: 1,
            episodeNumber: 2,
            torrentId: "dl-torrent-1",
            resolvedDebridService: DebridServiceType.debridLink.rawValue,
            resolvedFileName: "Show.S01E02.mkv",
            resolvedFileSizeBytes: 2000
        )!
        let stream = try await manager.resolveStream(from: context)
        #expect(stream.debridService == DebridServiceType.debridLink.rawValue)
    }

    @Test func resolveStreamFromContextUsesEpisodeMatchingWhenHintsProvided() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-episode")
        try await secretStore.setSecret("token", for: key)
        let config = makeDebridConfig(id: "rd-episode", type: .realDebrid, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let service = EpisodeAwareMockDebridService(
            serviceType: .realDebrid,
            shouldSelectEpisode: true,
            streamURL: URL(string: "https://cdn.example.com/episode.mkv")!
        )
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                service
            }
        )
        try await manager.initialize()

        let expectedTorrentID = "episode-mock-torrent"
        let context = StreamRecoveryContext(
            infoHash: validInfoHash40,
            preferredService: .realDebrid,
            seasonNumber: 2,
            episodeNumber: 7,
            torrentId: "stale-episode-torrent",
            resolvedDebridService: DebridServiceType.realDebrid.rawValue,
            resolvedFileName: "Show.S02E07.mkv",
            resolvedFileSizeBytes: 1234
        )!
        let stream = try await manager.resolveStream(from: context)
        let calls = await service.callSequence()

        #expect(stream.debridService == DebridServiceType.realDebrid.rawValue)
        #expect(stream.recoveryContext?.resolvedDebridService == DebridServiceType.realDebrid.rawValue)
        #expect(calls == [
            "cleanup:stale-episode-torrent",
            "add:\(validInfoHash40)|magnet:\(stream.recoveryContext?.magnetURI ?? "")",
            "match:\(expectedTorrentID):2:7",
            "stream:\(expectedTorrentID)",
        ])
    }

    @Test func resolveStreamPassesSanitizedMagnetToService() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .torBox, configId: "tb-magnet-normalization")
        try await secretStore.setSecret("tb-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-magnet-normalization",
                type: .torBox,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let badMagnet = "magnet:?dn=Movie&xt=urn:sha1:\(validInfoHash40)"
        let service = EpisodeAwareMockDebridService(
            serviceType: .torBox,
            shouldSelectEpisode: true,
            streamURL: URL(string: "https://cdn.example.com/magnet-test.mkv")!,
            addedMagnetId: "tb-magnet-torrent"
        )
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                service
            }
        )
        try await manager.initialize()

        let stream = try await manager.resolveStream(
            hash: validInfoHash40,
            magnetURI: badMagnet
        )
        let calls = await service.callSequence()
        let expectedMagnet = DebridMagnetInput.bareMagnetURI(for: validInfoHash40)

        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
        #expect(calls == [
            "add:\(validInfoHash40)|magnet:\(expectedMagnet)",
            "select:tb-magnet-torrent",
            "stream:tb-magnet-torrent",
        ])
    }

    @Test func resolveStreamRejectsMagnetMissingXTQueryAndFallsBackToBareURI() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-magnet-missing-xt")
        try await secretStore.setSecret("rd-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-magnet-missing-xt",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let missingXTMagnet = "magnet:?dn=Movie"
        let service = EpisodeAwareMockDebridService(
            serviceType: .realDebrid,
            shouldSelectEpisode: true,
            streamURL: URL(string: "https://cdn.example.com/no-xt.mkv")!,
            addedMagnetId: "rd-magnet-torrent"
        )
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                service
            }
        )
        try await manager.initialize()

        _ = try await manager.resolveStream(
            hash: validInfoHash40,
            magnetURI: missingXTMagnet
        )
        let calls = await service.callSequence()
        let expectedMagnet = DebridMagnetInput.bareMagnetURI(for: validInfoHash40)

        #expect(calls == [
            "add:\(validInfoHash40)|magnet:\(expectedMagnet)",
            "select:rd-magnet-torrent",
            "stream:rd-magnet-torrent",
        ])
    }

    @Test func resolveStreamFromContextFallsBackToPreferredServiceWhenResolvedServiceIsInvalid() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .torBox, configId: "tb-context-preferred")
        try await secretStore.setSecret("tb-token", for: key)
        let config = makeDebridConfig(id: "tb-context-preferred", type: .torBox, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let service = EpisodeAwareMockDebridService(
            serviceType: .torBox,
            shouldSelectEpisode: true,
            streamURL: URL(string: "https://cdn.example.com/context-fallback.mkv")!,
            addedMagnetId: "context-fallback-torrent"
        )
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { _, _ in
                service
            }
        )
        try await manager.initialize()

        let context = StreamRecoveryContext(
            infoHash: validInfoHash40,
            preferredService: .torBox,
            torrentId: "stale-context-torrent",
            resolvedDebridService: "invalid-service"
        )!
        let stream = try await manager.resolveStream(from: context)
        let calls = await service.callSequence()

        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
        #expect(calls == [
            "cleanup:stale-context-torrent",
            "add:\(validInfoHash40)|magnet:",
            "select:context-fallback-torrent",
            "stream:context-fallback-torrent",
        ])
    }

    @Test func resolveStreamFromContextFallsBackToConfiguredPriorityWhenResolvedServiceIsInvalidAndNoPreferredService() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let tbKey = SecretKey.debridToken(service: .torBox, configId: "tb-context-priority")
        let rdKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-context-priority")
        try await secretStore.setSecret("tb-token", for: tbKey)
        try await secretStore.setSecret("rd-token", for: rdKey)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-context-priority",
                type: .torBox,
                priority: 0,
                tokenRef: SecretReference.encode(key: tbKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-context-priority",
                type: .realDebrid,
                priority: 1,
                tokenRef: SecretReference.encode(key: rdKey)
            )
        )

        let torBoxService = MockDebridService(serviceType: .torBox)
        let realDebridService = MockDebridService(serviceType: .realDebrid)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                switch type {
                case .torBox: torBoxService
                case .realDebrid: realDebridService
                default: torBoxService
                }
            }
        )
        try await manager.initialize()

        let context = StreamRecoveryContext(
            infoHash: validInfoHash40,
            torrentId: "context-priority-stale-torrent",
            resolvedDebridService: "invalid-service"
        )!
        let stream = try await manager.resolveStream(from: context)

        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
    }

    @Test func resolveStreamRetriesAfterTransientFileNotReadyErrors() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .allDebrid, configId: "ad-file-not-ready")
        try await secretStore.setSecret("ad-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "ad-file-not-ready",
                type: .allDebrid,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let service = FlakyDebridService(
            serviceType: .allDebrid,
            failFileNotReadyCount: 1
        )
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { _, _ in
                service
            }
        )
        try await manager.initialize()

        let stream = try await manager.resolveStream(hash: validInfoHash40)
        let calls = await service.getStreamCalls

        #expect(stream.debridService == DebridServiceType.allDebrid.rawValue)
        #expect(calls == 2)
    }

    @Test func resolveStreamFromContextCleansUpWhenEpisodeMatchingFails() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .allDebrid, configId: "ad-episode-fail")
        try await secretStore.setSecret("token", for: key)
        let config = makeDebridConfig(id: "ad-episode-fail", type: .allDebrid, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let service = EpisodeAwareMockDebridService(
            serviceType: .allDebrid,
            shouldSelectEpisode: false,
            streamURL: URL(string: "https://cdn.example.com/episode-fail.mkv")!
        )
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                service
            }
        )
        try await manager.initialize()
        let expectedTorrentID = "episode-mock-torrent"

        let context = StreamRecoveryContext(
            infoHash: validInfoHash40,
            preferredService: .allDebrid,
            seasonNumber: 3,
            episodeNumber: 1,
            torrentId: "stale-episode-fail",
            resolvedDebridService: DebridServiceType.allDebrid.rawValue
        )!

        await #expect(throws: DebridError.networkError("Could not deterministically select the requested episode file.")) {
            _ = try await manager.resolveStream(from: context)
        }

        let calls = await service.callSequence()
        #expect(calls == [
            "cleanup:stale-episode-fail",
            "add:\(validInfoHash40)|magnet:",
            "match:\(expectedTorrentID):3:1",
            "cleanup:\(expectedTorrentID)",
        ])
    }

    @Test func resolveStreamAttachesRecoveryContextToStreamInfo() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .allDebrid, configId: "ad-1")
        try await secretStore.setSecret("token", for: key)
        let config = makeDebridConfig(id: "ad-1", type: .allDebrid, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()
        let stream = try await manager.resolveStream(hash: validInfoHash40, seasonNumber: 1, episodeNumber: 2)
        #expect(stream.recoveryContext != nil)
        #expect(stream.recoveryContext?.infoHash == validInfoHash40)
        #expect(stream.recoveryContext?.preferredService == .allDebrid)
    }

    @Test func unrestrictUsesConfiguredServiceAndParsesFileName() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-unrestrict")
        try await secretStore.setSecret("rd-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(id: "rd-unrestrict", type: .realDebrid, tokenRef: SecretReference.encode(key: key))
        )

        let encodedStreamURL = URL(string: "https://cdn.example.com/stream%20name.mkv")!
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(
                    serviceType: type,
                    streamURL: encodedStreamURL
                )
            }
        )
        try await manager.initialize()

        let stream = try await manager.unrestrict(link: "https://origin.example/stream?source=abc", serviceType: .realDebrid)
        #expect(stream.debridService == DebridServiceType.realDebrid.rawValue)
        #expect(stream.fileName == "stream name.mkv")
        #expect(stream.streamURL == encodedStreamURL)
    }

    @Test func unrestrictThrowsWhenServiceNotConfigured() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let manager = DebridManager(database: db, secretStore: MemorySecretStore())
        await #expect(throws: DebridError.networkError("Real-Debrid is not configured. Add it in Settings > Debrid Services.")) {
            _ = try await manager.unrestrict(link: "https://origin.example/stream.mkv", serviceType: .realDebrid)
        }
    }

    @Test func unrestrictFallsBackToFallbackLinkWhenStreamURLHasNoFileName() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .torBox, configId: "rd-unrestrict-fallback")
        try await secretStore.setSecret("token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(id: "rd-unrestrict-fallback", type: .torBox, tokenRef: SecretReference.encode(key: key))
        )

        let fallbackURL = "https://origin.example/stream%20name.mkv"
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(
                    serviceType: type,
                    streamURL: URL(string: "https://cdn.example.com/")!
                )
            }
        )
        try await manager.initialize()

        let stream = try await manager.unrestrict(link: fallbackURL, serviceType: .torBox)
        #expect(stream.fileName == "stream name.mkv")
    }

    @Test func unrestrictFallsBackToUnknownWhenNoFileNameInBothStreamURLAndLink() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-unrestrict-unknown")
        try await secretStore.setSecret("token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(id: "rd-unrestrict-unknown", type: .realDebrid, tokenRef: SecretReference.encode(key: key))
        )

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(
                    serviceType: type,
                    streamURL: URL(string: "https://cdn.example.com/")!
                )
            }
        )
        try await manager.initialize()

        let stream = try await manager.unrestrict(link: "https://origin.example", serviceType: .realDebrid)
        #expect(stream.fileName == "Unknown")
    }

    @Test func cleanupRemoteTransferFromContextCallsServiceCleanup() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let key = SecretKey.debridToken(service: .torBox, configId: "tb-1")
        try await secretStore.setSecret("token", for: key)
        let config = makeDebridConfig(id: "tb-1", type: .torBox, tokenRef: SecretReference.encode(key: key))
        try await db.saveDebridConfig(config)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, token in
                MockDebridService(serviceType: type)
            }
        )
        try await manager.initialize()

        let context = StreamRecoveryContext(
            infoHash: validInfoHash40,
            preferredService: .torBox,
            torrentId: "tb-torrent-1",
            resolvedDebridService: DebridServiceType.torBox.rawValue
        )!
        await manager.cleanupRemoteTransfer(from: context)
    }

    @Test func cleanupRemoteTransferFromContextFallsBackToPreferredWhenResolvedServiceInvalid() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let resolvedKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-cleanup-invalid")
        let preferredKey = SecretKey.debridToken(service: .torBox, configId: "tb-cleanup-invalid")
        try await secretStore.setSecret("rd-token", for: resolvedKey)
        try await secretStore.setSecret("tb-token", for: preferredKey)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-cleanup-invalid",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: resolvedKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "tb-cleanup-invalid",
                type: .torBox,
                tokenRef: SecretReference.encode(key: preferredKey)
            )
        )

        let resolvedService = MockDebridService(serviceType: .realDebrid)
        let preferredService = MockDebridService(serviceType: .torBox)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                switch type {
                case .realDebrid:
                    resolvedService
                case .torBox:
                    preferredService
                default:
                    preferredService
                }
            }
        )
        try await manager.initialize()

        let context = StreamRecoveryContext(
            infoHash: validInfoHash40,
            preferredService: .torBox,
            torrentId: "stale-torrent",
            resolvedDebridService: "not-a-real-service"
        )!
        await manager.cleanupRemoteTransfer(from: context)

        #expect(await resolvedService.cleanupCalled == false)
        #expect(await preferredService.cleanupCalled == true)
    }

    @Test func resolveStreamFallsBackWhenPrimaryEmitsNonDebridError() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        for type in [DebridServiceType.realDebrid, .torBox] {
            let key = SecretKey.debridToken(service: type, configId: "\(type.rawValue)-non-debrid")
            try await secretStore.setSecret("token", for: key)
            let config = makeDebridConfig(
                id: "\(type.rawValue)-non-debrid",
                type: type,
                tokenRef: SecretReference.encode(key: key)
            )
            try await db.saveDebridConfig(config)
        }

        let primary = ErrorInjectingDebridService(
            serviceType: .realDebrid,
            getStreamError: ErrorInjectingDebridStreamError.upstreamFailure
        )
        let fallback = MockDebridService(serviceType: .torBox)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                switch type {
                case .realDebrid:
                    return primary
                case .torBox:
                    return fallback
                default:
                    return fallback
                }
            }
        )
        try await manager.initialize()

        let stream = try await manager.resolveStream(hash: validInfoHash40)

        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
        #expect(await primary.observedAddMagnetCalls() == 1)
        #expect(await primary.observedCleanupCalls() == 1)
        #expect(await primary.observedSelectFilesCalled() == true)
        #expect(await fallback.addMagnetCalls == 1)
    }

    @Test func resolveStreamFallsBackWhenPrimaryCleanupThrowsWithFailureReason() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        for type in [DebridServiceType.realDebrid, .torBox] {
            let key = SecretKey.debridToken(service: type, configId: "\(type.rawValue)-cleanup-reason")
            try await secretStore.setSecret("token", for: key)
            let config = makeDebridConfig(
                id: "\(type.rawValue)-cleanup-reason",
                type: type,
                tokenRef: SecretReference.encode(key: key)
            )
            try await db.saveDebridConfig(config)
        }

        let primary = ErrorInjectingDebridService(
            serviceType: .realDebrid,
            getStreamError: DebridError.networkError("upstream fail"),
            cleanupError: DebridError.networkError("remote cleanup failed")
        )
        let fallback = MockDebridService(serviceType: .torBox)

        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                switch type {
                case .realDebrid:
                    return primary
                case .torBox:
                    return fallback
                default:
                    return fallback
                }
            }
        )
        try await manager.initialize()

        let stream = try await manager.resolveStream(hash: validInfoHash40)

        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
        #expect(await primary.observedCleanupCalls() == 1)
    }

    @Test func cleanupRemoteTransferFromContextReturnsWhenInitializationFails() async {
        let db = try! makeInMemoryDB()
        let secretStore = MemorySecretStore()

        let manager = DebridManager(database: db, secretStore: secretStore)
        let context = StreamRecoveryContext(
            infoHash: validInfoHash40,
            torrentId: "uninitialized-db-torrent",
            resolvedDebridService: DebridServiceType.realDebrid.rawValue
        )!
        await manager.cleanupRemoteTransfer(from: context)
    }

    @Test func checkCacheAcrossServicesIgnoresUnexpectedResultHashes() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let key = SecretKey.debridToken(service: .realDebrid, configId: "rd-cache-extraneous")
        try await secretStore.setSecret("token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-cache-extraneous",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let cacheService = ExtraneousCacheResultService(serviceType: .realDebrid)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { type, _ in
                cacheService
            }
        )
        try await manager.initialize()

        let result = try await manager.checkCacheAcrossServices(hashes: [validInfoHash40])
        #expect(result.count == 1)
        #expect(result[validInfoHash40]?.0 == .notCached)
        #expect(await cacheService.observedCheckCacheCalls() == 1)
    }

    @Test func initializeUsesDefaultServiceFactoryForOffcloud() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let key = SecretKey.debridToken(service: .offcloud, configId: "offcloud-factory")
        try await secretStore.setSecret("offcloud-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "offcloud-factory",
                type: .offcloud,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let manager = DebridManager(database: db, secretStore: secretStore)
        try await manager.initialize()

        let services = await manager.availableServices()
        let service = await manager.getService(.offcloud)

        #expect(services == [.offcloud])
        #expect(service != nil)
        #expect(service is OffcloudService)
    }
}

// MARK: - AllDebridService Request Tests

@Suite("AllDebridService Requests")
struct AllDebridServiceRequestTests {
    @Test func requestInjectsAgentAndAuthorizationHeader() async throws {
        final class State: @unchecked Sendable {
            var auth: String?
            var agent: String?
        }
        let state = State()
        let session = makeStubSession { request in
            state.auth = request.value(forHTTPHeaderField: "Authorization")
            let url = request.url!
            state.agent = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "agent" })?.value
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"success","data":{"user":{"username":"u"}}}"#.utf8))
        }
        let service = AllDebridService(apiToken: "ad-token", session: session)
        _ = try await service.getAccountInfo()
        #expect(state.auth == "Bearer ad-token")
        #expect(state.agent == "VPStudio")
    }

    @Test func getQueryEncodesParametersInURL() async throws {
        final class State: @unchecked Sendable { var url: URL? }
        let state = State()
        let session = makeStubSession { request in
            state.url = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"success","data":{"magnets":[]}}"#.utf8))
        }
        let service = AllDebridService(apiToken: "token", session: session)
        _ = try await service.checkCache(hashes: ["abc123"])
        let query = state.url?.query ?? ""
        #expect(query.contains("magnets"))
        #expect(query.contains("agent=VPStudio"))
    }

    @Test func postBodyUsesFormEncodingWithoutAmpersands() async throws {
        final class State: @unchecked Sendable { var body: String? }
        let state = State()
        let session = makeStubSession { request in
            state.body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"success","data":{"magnets":[{"id":7}]}}"#.utf8))
        }
        let service = AllDebridService(apiToken: "token", session: session)
        _ = try await service.addMagnet(hash: validInfoHash40)
        let body = try #require(state.body)
        #expect(!body.contains("&xt="))
        #expect(body.contains("magnets"))
    }

    @Test func errorMappingConverts401And403ToUnauthorized() async {
        for code in [401, 403] {
            let session = makeStubSession { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let service = AllDebridService(apiToken: "bad", session: session)
            await #expect(throws: DebridError.unauthorized) {
                _ = try await service.validateToken()
            }
        }
    }

    @Test func errorMappingConverts429ToRateLimited() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = AllDebridService(apiToken: "token", session: session)
        await #expect(throws: DebridError.rateLimited) {
            _ = try await service.validateToken()
        }
    }

    @Test func responseParsingHandlesNestedADResponse() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"status":"success","data":{"user":{"username":"nested-user","email":"nested@example.test","isPremium":false}}}"#
            return (response, Data(body.utf8))
        }
        let service = AllDebridService(apiToken: "token", session: session)
        let info = try await service.getAccountInfo()
        #expect(info.username == "nested-user")
        #expect(info.email == "nested@example.test")
        #expect(info.isPremium == false)
    }
}

// MARK: - DebridLinkService Request Tests

@Suite("DebridLinkService Requests")
struct DebridLinkServiceRequestTests {
    @Test func requestAppendsPathWithQueryStringDirectly() async throws {
        final class State: @unchecked Sendable { var urlString: String? }
        let state = State()
        let session = makeStubSession { request in
            state.urlString = request.url?.absoluteString
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"success":true,"value":{}}"#.utf8))
        }
        let service = DebridLinkService(apiToken: "token", session: session)
        _ = try await service.checkCache(hashes: ["abc"])
        let url = try #require(state.urlString)
        #expect(url.contains("/seedbox/cached?"))
    }

    @Test func postFormBodyEncodesMagnetAndAsyncFlag() async throws {
        final class State: @unchecked Sendable { var body: String? }
        let state = State()
        let session = makeStubSession { request in
            state.body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"success":true,"value":{"id":"dl-1"}}"#.utf8))
        }
        let service = DebridLinkService(apiToken: "token", session: session)
        _ = try await service.addMagnet(hash: validInfoHash40)
        let body = try #require(state.body)
        #expect(body.contains("async=true"))
        #expect(body.contains("url=magnet"))
        #expect(!body.contains("&xt="))
    }

    @Test func authorizationHeaderUsedOnEveryRequest() async throws {
        final class State: @unchecked Sendable { var auth: String? }
        let state = State()
        let session = makeStubSession { request in
            state.auth = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"success":true,"value":{"pseudo":"u"}}"#.utf8))
        }
        let service = DebridLinkService(apiToken: "dl-secret", session: session)
        _ = try await service.validateToken()
        #expect(state.auth == "Bearer dl-secret")
    }

    @Test func snakeCaseDecodingForPremiumLeft() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"success":true,"value":{"pseudo":"u","email":"e@t","premium_left":1700000000}}"#
            return (response, Data(body.utf8))
        }
        let service = DebridLinkService(apiToken: "token", session: session)
        let info = try await service.getAccountInfo()
        #expect(info.isPremium == true)
        #expect(info.premiumExpiry == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func errorMappingConverts401ToUnauthorized() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = DebridLinkService(apiToken: "bad", session: session)
        await #expect(throws: DebridError.unauthorized) {
            _ = try await service.validateToken()
        }
    }

    @Test func errorMappingConverts429ToRateLimited() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = DebridLinkService(apiToken: "token", session: session)
        await #expect(throws: DebridError.rateLimited) {
            _ = try await service.validateToken()
        }
    }
}

// MARK: - EasyNewsService Request Tests

@Suite("EasyNewsService Requests")
struct EasyNewsServiceRequestTests {
    @Test func validateTokenSendsHEADRequestWithBasicAuth() async throws {
        final class State: @unchecked Sendable {
            var method: String?
            var auth: String?
        }
        let state = State()
        let session = makeStubSession { request in
            state.method = request.httpMethod
            state.auth = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = EasyNewsService(apiToken: "dXNlcjpwYXNz", session: session)
        _ = try await service.validateToken()
        #expect(state.method == "HEAD")
        #expect(state.auth == "Basic dXNlcjpwYXNz")
    }

    @Test func validateTokenReturnsFalseOn401() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = EasyNewsService(apiToken: "token", session: session)
        #expect(try await service.validateToken() == false)
    }

    @Test func validateTokenThrowsHTTPErrorOnUnexpectedStatus() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data("maintenance".utf8))
        }
        let service = EasyNewsService(apiToken: "token", session: session)
        await #expect(throws: DebridError.httpError(503, "EasyNews validation failed")) {
            _ = try await service.validateToken()
        }
    }

    @Test func serviceTypeIsEasyNews() async {
        let service = EasyNewsService(apiToken: "token")
        #expect(await service.serviceType == .easyNews)
    }
}

// MARK: - OffcloudService Request Tests

@Suite("OffcloudService Requests")
struct OffcloudServiceRequestTests {
    @Test func requestSendsJSONBodyWithCorrectContentType() async throws {
        final class State: @unchecked Sendable {
            var contentType: String?
            var bodyDict: [String: Any]?
        }
        let state = State()
        let session = makeStubSession { request in
            state.contentType = request.value(forHTTPHeaderField: "Content-Type")
            if let body = request.httpBody {
                state.bodyDict = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"cached_items":[]}"#.utf8))
        }
        let service = OffcloudService(apiToken: "token", session: session)
        _ = try await service.checkCache(hashes: ["abc"])
        #expect(state.contentType == "application/json")
        let hashes = state.bodyDict?["hashes"] as? [String]
        #expect(hashes == ["abc"])
    }

    @Test func requestFallsBackToBaseURLWithoutApiPrefixOn404() async throws {
        final class State: @unchecked Sendable { var paths: [String] = [] }
        let state = State()
        let session = makeStubSession { request in
            let path = request.url?.path ?? ""
            state.paths.append(path)
            if path == "/api/cloud/history" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }
        let service = OffcloudService(apiToken: "token", session: session)
        _ = try await service.validateToken()
        #expect(state.paths == ["/api/cloud/history", "/cloud/history"])
    }

    @Test func authorizationHeaderOnEveryRequest() async throws {
        final class State: @unchecked Sendable { var auths: [String?] = [] }
        let state = State()
        let session = makeStubSession { request in
            state.auths.append(request.value(forHTTPHeaderField: "Authorization"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"cached_items":[]}"#.utf8))
        }
        let service = OffcloudService(apiToken: "oc-token", session: session)
        _ = try await service.checkCache(hashes: ["abc"])
        #expect(state.auths.allSatisfy { $0 == "Bearer oc-token" })
    }

    @Test func snakeCaseDecodingForCachedItems() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"cached_items":["hash1","hash2"]}"#.utf8))
        }
        let service = OffcloudService(apiToken: "token", session: session)
        let result = try await service.checkCache(hashes: ["HASH1", "hash2"])
        #expect(result["hash1"] == .cached(fileId: nil, fileName: nil, fileSize: nil))
        #expect(result["hash2"] == .cached(fileId: nil, fileName: nil, fileSize: nil))
    }

    @Test func validateTokenReturnsFalseOn401() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = OffcloudService(apiToken: "bad", session: session)
        #expect(try await service.validateToken() == false)
    }

    @Test func errorMappingConverts429ToRateLimited() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = OffcloudService(apiToken: "token", session: session)
        await #expect(throws: DebridError.rateLimited) {
            _ = try await service.validateToken()
        }
    }
}

// MARK: - PremiumizeService Request Tests

@Suite("PremiumizeService Requests")
struct PremiumizeServiceRequestTests {
    @Test func checkCacheEncodesItemsArrayInQuery() async throws {
        final class State: @unchecked Sendable { var url: URL? }
        let state = State()
        let session = makeStubSession { request in
            state.url = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"success","response":[true,false]}"#.utf8))
        }
        let service = PremiumizeService(apiToken: "token", session: session)
        _ = try await service.checkCache(hashes: ["abc", "def"])
        let components = URLComponents(url: try #require(state.url), resolvingAgainstBaseURL: false)
        let items = components?.queryItems?.filter { $0.name == "items[]" } ?? []
        #expect(items.count == 2)
        #expect(items[0].value == "abc")
        #expect(items[1].value == "def")
    }

    @Test func postBodyUsesFormEncodingForSrcAndId() async throws {
        final class State: @unchecked Sendable { var body: String? }
        let state = State()
        let session = makeStubSession { request in
            state.body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"success","id":"pm-123"}"#.utf8))
        }
        let service = PremiumizeService(apiToken: "token", session: session)
        _ = try await service.addMagnet(hash: validInfoHash40)
        let body = try #require(state.body)
        #expect(body.hasPrefix("src=magnet"))
        #expect(!body.contains("&xt="))
    }

    @Test func authorizationHeaderOnEveryRequest() async throws {
        final class State: @unchecked Sendable { var auth: String? }
        let state = State()
        let session = makeStubSession { request in
            state.auth = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"status":"success","customer_id":"1"}"#.utf8))
        }
        let service = PremiumizeService(apiToken: "pm-secret", session: session)
        _ = try await service.validateToken()
        #expect(state.auth == "Bearer pm-secret")
    }

    @Test func customCodingKeysDecodeCustomerIdAndPremiumUntil() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"status":"success","customer_id":"cust-42","premium_until":1700000000}"#
            return (response, Data(body.utf8))
        }
        let service = PremiumizeService(apiToken: "token", session: session)
        let info = try await service.getAccountInfo()
        #expect(info.username == "cust-42")
        #expect(info.isPremium == true)
    }

    @Test func errorMappingConverts401ToUnauthorized() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = PremiumizeService(apiToken: "bad", session: session)
        await #expect(throws: DebridError.unauthorized) {
            _ = try await service.validateToken()
        }
    }

    @Test func errorMappingConverts429ToRateLimited() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = PremiumizeService(apiToken: "token", session: session)
        await #expect(throws: DebridError.rateLimited) {
            _ = try await service.validateToken()
        }
    }
}

// MARK: - TorBoxService Request Tests

@Suite("TorBoxService Requests")
struct TorBoxServiceRequestTests {
    @Test func checkCacheEncodesHashAndFormatQueryItems() async throws {
        final class State: @unchecked Sendable { var url: URL? }
        let state = State()
        let session = makeStubSession { request in
            state.url = request.url
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"success":true,"data":[]}"#.utf8))
        }
        let service = TorBoxService(apiToken: "token", session: session)
        _ = try await service.checkCache(hashes: ["abc", "def"])
        let components = URLComponents(url: try #require(state.url), resolvingAgainstBaseURL: false)
        let hashParam = components?.queryItems?.first(where: { $0.name == "hash" })
        let formatParam = components?.queryItems?.first(where: { $0.name == "format" })
        #expect(hashParam?.value == "abc,def")
        #expect(formatParam?.value == "list")
    }

    @Test func postBodyUsesMultipartFormDataForMagnet() async throws {
        final class State: @unchecked Sendable {
            var contentType: String?
            var body: String?
        }
        let state = State()
        let session = makeStubSession { request in
            state.contentType = request.value(forHTTPHeaderField: "Content-Type")
            state.body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"success":true,"data":{"torrent_id":99}}"#.utf8))
        }
        let service = TorBoxService(apiToken: "token", session: session)
        _ = try await service.addMagnet(hash: validInfoHash40)
        let body = try #require(state.body)
        #expect(state.contentType?.hasPrefix("multipart/form-data; boundary=") == true)
        #expect(body.contains("Content-Disposition: form-data; name=\"magnet\""))
        #expect(body.contains("magnet:?xt=urn:btih:\(validInfoHash40)"))
    }

    @Test func authorizationHeaderOnEveryRequest() async throws {
        final class State: @unchecked Sendable { var auth: String? }
        let state = State()
        let session = makeStubSession { request in
            state.auth = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"success":true,"data":{"email":"u@t"}}"#.utf8))
        }
        let service = TorBoxService(apiToken: "tb-secret", session: session)
        _ = try await service.validateToken()
        #expect(state.auth == "Bearer tb-secret")
    }

    @Test func snakeCaseDecodingForTorrentIdAndDownloadFinished() async throws {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = #"{"success":true,"data":{"torrent_id":42}}"#
            return (response, Data(body.utf8))
        }
        let service = TorBoxService(apiToken: "token", session: session)
        let id = try await service.addMagnet(hash: validInfoHash40)
        #expect(id == "42")
    }

    @Test func errorMappingConverts401ToUnauthorized() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = TorBoxService(apiToken: "bad", session: session)
        await #expect(throws: DebridError.unauthorized) {
            _ = try await service.validateToken()
        }
    }

    @Test func errorMappingConverts429ToRateLimited() async {
        let session = makeStubSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let service = TorBoxService(apiToken: "token", session: session)
        await #expect(throws: DebridError.rateLimited) {
            _ = try await service.validateToken()
        }
    }
}

// MARK: - DebridError Tests

@Suite("DebridError Extended")
struct DebridErrorExtendedTestsDebridservicestests {
    @Test func allErrorCasesHaveLocalizedDescriptions() {
        let errors: [DebridError] = [
            .unauthorized,
            .notPremium,
            .invalidHash("abc"),
            .torrentNotFound("xyz"),
            .fileNotReady("pending"),
            .rateLimited,
            .unavailableForLegalReasons("blocked"),
            .httpError(500, "Server Error"),
            .networkError("timeout"),
            .timeout,
        ]
        for error in errors {
            let desc = error.errorDescription
            #expect(desc != nil)
            #expect(!desc!.isEmpty)
        }
    }

    @Test func equatableReturnsTrueForSameCases() {
        #expect(DebridError.unauthorized == DebridError.unauthorized)
        #expect(DebridError.rateLimited == DebridError.rateLimited)
        #expect(DebridError.timeout == DebridError.timeout)
        #expect(DebridError.invalidHash("a") == DebridError.invalidHash("a"))
    }

    @Test func equatableReturnsFalseForDifferentCases() {
        #expect(DebridError.unauthorized != DebridError.rateLimited)
        #expect(DebridError.invalidHash("a") != DebridError.invalidHash("b"))
        #expect(DebridError.httpError(500, "a") != DebridError.httpError(501, "a"))
    }

    @Test func httpErrorIncludesStatusCodeAndMessage() {
        let error = DebridError.httpError(418, "I'm a teapot")
        #expect(error.errorDescription?.contains("418") == true)
        #expect(error.errorDescription?.contains("teapot") == true)
    }

    @Test func invalidHashIncludesOriginalInput() {
        let error = DebridError.invalidHash("bad-hash")
        #expect(error.errorDescription?.contains("bad-hash") == true)
    }
}

// MARK: - DebridServiceProtocol Default Tests

@Suite("DebridServiceProtocol Defaults")
struct DebridServiceProtocolDefaultTests {
    @Test func defaultSelectMatchingEpisodeFileReturnsFalse() async throws {
        actor MinimalService: DebridServiceProtocol {
            let serviceType: DebridServiceType = .realDebrid
            func validateToken() async throws -> Bool { true }
            func getAccountInfo() async throws -> DebridAccountInfo { DebridAccountInfo(username: "", email: nil, premiumExpiry: nil, isPremium: nil) }
            func checkCache(hashes: [String]) async throws -> [String: CacheStatus] { [:] }
            func addMagnet(hash: String) async throws -> String { "" }
            func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
            func getStreamURL(torrentId: String) async throws -> StreamInfo {
                StreamInfo(streamURL: URL(string: "https://x.com")!, quality: .unknown, codec: .unknown, audio: .unknown, source: .unknown, hdr: .sdr, fileName: "", sizeBytes: nil, debridService: "")
            }
            func unrestrict(link: String) async throws -> URL { URL(string: "https://x.com")! }
        }
        let service = MinimalService()
        let result = try await service.selectMatchingEpisodeFile(torrentId: "t", seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(result == false)
    }

    @Test func defaultCleanupRemoteTransferIsNoOp() async throws {
        actor MinimalService: DebridServiceProtocol {
            let serviceType: DebridServiceType = .realDebrid
            func validateToken() async throws -> Bool { true }
            func getAccountInfo() async throws -> DebridAccountInfo { DebridAccountInfo(username: "", email: nil, premiumExpiry: nil, isPremium: nil) }
            func checkCache(hashes: [String]) async throws -> [String: CacheStatus] { [:] }
            func addMagnet(hash: String) async throws -> String { "" }
            func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
            func getStreamURL(torrentId: String) async throws -> StreamInfo {
                StreamInfo(streamURL: URL(string: "https://x.com")!, quality: .unknown, codec: .unknown, audio: .unknown, source: .unknown, hdr: .sdr, fileName: "", sizeBytes: nil, debridService: "")
            }
            func unrestrict(link: String) async throws -> URL { URL(string: "https://x.com")! }
        }
        let service = MinimalService()
        try await service.cleanupRemoteTransfer(torrentId: "t")
    }

    @Test func defaultEpisodeSelectionIgnoresHints() async throws {
        actor MinimalService: DebridServiceProtocol {
            let serviceType: DebridServiceType = .realDebrid
            func validateToken() async throws -> Bool { true }
            func getAccountInfo() async throws -> DebridAccountInfo { DebridAccountInfo(username: "", email: nil, premiumExpiry: nil, isPremium: nil) }
            func checkCache(hashes: [String]) async throws -> [String: CacheStatus] { [:] }
            func addMagnet(hash: String) async throws -> String { "" }
            func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
            func getStreamURL(torrentId: String) async throws -> StreamInfo {
                StreamInfo(streamURL: URL(string: "https://x.com")!, quality: .unknown, codec: .unknown, audio: .unknown, source: .unknown, hdr: .sdr, fileName: "", sizeBytes: nil, debridService: "")
            }
            func unrestrict(link: String) async throws -> URL { URL(string: "https://x.com")! }
        }
        let service = MinimalService()
        let result = try await service.selectMatchingEpisodeFile(torrentId: "t", seasonNumber: 1, episodeNumber: 1, resolvedFileNameHint: nil, resolvedFileSizeHint: nil)
        #expect(result == false)
    }
}
