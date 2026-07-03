import Foundation
import Testing
@testable import VPStudio

// MARK: - Test Helpers

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

private actor ThrowingSecretStore: SecretStore {
    func setSecret(_ secret: String, for key: String) async throws {
        throw DebridError.networkError("store unavailable")
    }

    func getSecret(for key: String) async throws -> String? {
        throw DebridError.networkError("store unavailable")
    }

    func deleteSecret(for key: String) async throws {
        throw DebridError.networkError("store unavailable")
    }

    func deleteAllSecrets() async throws {
        throw DebridError.networkError("store unavailable")
    }
}

private actor SelectiveThrowingSecretStore: SecretStore {
    private let throwingKeys: Set<String>
    private var secrets: [String: String] = [:]

    init(throwingKeys: [String] = []) {
        self.throwingKeys = Set(throwingKeys)
    }

    func setSecret(_ secret: String, for key: String) async throws {
        if throwingKeys.contains(key) {
            throw DebridError.networkError("secret store unavailable for set")
        }
        secrets[key] = secret
    }

    func getSecret(for key: String) async throws -> String? {
        if throwingKeys.contains(key) {
            throw DebridError.networkError("secret store unavailable for get")
        }
        return secrets[key]
    }

    func deleteSecret(for key: String) async throws {
        if throwingKeys.contains(key) {
            throw DebridError.networkError("secret store unavailable for delete")
        }
        secrets.removeValue(forKey: key)
    }

    func deleteAllSecrets() async throws {
        if !throwingKeys.isEmpty {
            throw DebridError.networkError("secret store unavailable for deleteAll")
        }
        secrets.removeAll()
    }
}

private actor CancellationAwareService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    let throwCancellationOnAdd: Bool
    let throwCancellationOnSelectFiles: Bool
    let throwCancellationOnGetStream: Bool
    let streamURL: URL

    private(set) var addMagnetCalls: Int = 0
    private(set) var selectFilesCalls: Int = 0
    private(set) var getStreamCalls: Int = 0

    init(
        serviceType: DebridServiceType,
        throwCancellationOnAdd: Bool = false,
        throwCancellationOnSelectFiles: Bool = false,
        throwCancellationOnGetStream: Bool = false,
        streamURL: URL = URL(string: "https://cdn.example.com/stream.mkv")!
    ) {
        self.serviceType = serviceType
        self.throwCancellationOnAdd = throwCancellationOnAdd
        self.throwCancellationOnSelectFiles = throwCancellationOnSelectFiles
        self.throwCancellationOnGetStream = throwCancellationOnGetStream
        self.streamURL = streamURL
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "cancel-\(serviceType.rawValue)")
    }

    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        hashes.reduce(into: [String: CacheStatus]()) { result, hash in
            result[hash] = .notCached
        }
    }

    func addMagnet(hash: String) async throws -> String {
        addMagnetCalls += 1
        if throwCancellationOnAdd {
            throw CancellationError()
        }
        return "\(serviceType.rawValue)-\(hash)"
    }

    func addMagnet(hash: String, magnetURI: String?) async throws -> String {
        try await addMagnet(hash: hash)
    }

    func selectFiles(torrentId: String, fileIds: [Int]) async throws {
        selectFilesCalls += 1
        if throwCancellationOnSelectFiles {
            throw CancellationError()
        }
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

    func cleanupRemoteTransfer(torrentId: String) async throws {}

    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        getStreamCalls += 1
        if throwCancellationOnGetStream {
            throw CancellationError()
        }
        return StreamInfo(
            streamURL: streamURL,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            fileName: "stream.mkv",
            sizeBytes: nil,
            debridService: serviceType.rawValue
        )
    }

    func unrestrict(link: String) async throws -> URL {
        streamURL
    }

    func callCountAddMagnet() async -> Int {
        addMagnetCalls
    }

    func callCountGetStream() async -> Int {
        getStreamCalls
    }

    func callCountSelectFiles() async -> Int {
        selectFilesCalls
    }
}

private actor CleanupProbeDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    let shouldThrowOnCleanup: Bool

    private(set) var cleanupCalls: [String] = []

    init(serviceType: DebridServiceType, shouldThrowOnCleanup: Bool = false) {
        self.serviceType = serviceType
        self.shouldThrowOnCleanup = shouldThrowOnCleanup
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "probe-\(serviceType.rawValue)")
    }

    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        hashes.reduce(into: [String: CacheStatus]()) { result, hash in
            result[hash.lowercased()] = .notCached
        }
    }

    func addMagnet(hash: String) async throws -> String { "\(serviceType.rawValue)-\(hash)" }

    func selectFiles(torrentId: String, fileIds: [Int]) async throws {}

    func selectMatchingEpisodeFile(
        torrentId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> Bool {
        false
    }

    func cleanupRemoteTransfer(torrentId: String) async throws {
        cleanupCalls.append(torrentId)
        if shouldThrowOnCleanup {
            throw DebridError.networkError("cleanup failed")
        }
    }

    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/\(serviceType.rawValue).mkv")!,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            fileName: "\(torrentId).mkv",
            sizeBytes: nil,
            debridService: serviceType.rawValue
        )
    }

    func unrestrict(link: String) async throws -> URL {
        URL(string: "https://cdn.example.com/unrestrict.mkv")!
    }

    func tookCleanupCall(for torrentId: String) async -> Bool {
        cleanupCalls.contains(torrentId)
    }

    func cleanupCallCount() async -> Int {
        cleanupCalls.count
    }
}

private actor CountingDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    let streamURL: URL

    private(set) var addMagnetCalls: Int = 0
    private(set) var selectFilesCalls: Int = 0
    private(set) var getStreamCalls: Int = 0

    init(serviceType: DebridServiceType, streamURL: URL = URL(string: "https://cdn.example.com/stream.mkv")!) {
        self.serviceType = serviceType
        self.streamURL = streamURL
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "counting-\(serviceType.rawValue)")
    }

    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        hashes.reduce(into: [String: CacheStatus]()) { result, hash in
            result[hash.lowercased()] = .notCached
        }
    }

    func addMagnet(hash: String) async throws -> String {
        addMagnetCalls += 1
        return "\(serviceType.rawValue)-\(hash)"
    }

    func addMagnet(hash: String, magnetURI: String?) async throws -> String {
        try await addMagnet(hash: hash)
    }

    func selectFiles(torrentId: String, fileIds: [Int]) async throws {
        selectFilesCalls += 1
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

    func cleanupRemoteTransfer(torrentId: String) async throws {}

    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        getStreamCalls += 1
        return StreamInfo(
            streamURL: streamURL,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            fileName: "\(torrentId).mkv",
            sizeBytes: nil,
            debridService: serviceType.rawValue
        )
    }

    func unrestrict(link: String) async throws -> URL { streamURL }

    func addMagnetCallCount() async -> Int { addMagnetCalls }
    func selectFilesCallCount() async -> Int { selectFilesCalls }
    func getStreamCallCount() async -> Int { getStreamCalls }
}

private func makeInMemoryDB() async throws -> DatabaseManager {
    let db = try DatabaseManager(inMemoryNamed: "test-\(UUID().uuidString)")
    try await db.migrate()
    return db
}

private func makeDebridConfig(
    id: String,
    type: DebridServiceType,
    priority: Int = 0,
    tokenRef: String = "token"
) -> DebridConfig {
    DebridConfig(
        id: id,
        serviceType: type,
        apiTokenRef: tokenRef,
        isActive: true,
        priority: priority
    )
}

// MARK: - Tests

@Suite("DebridManager Cleanup Recovery Edge Cases")
struct DebridManagerCleanupEdgeCaseTests {
    private let validInfoHash = "0123456789abcdef0123456789abcdef01234567"

    @Test func cleanupFromContextWithMissingTorrentIdSkipsCleanupCalls() async throws {
        let db = try await makeInMemoryDB()
        let secretStore = MemorySecretStore()

        let probe = CleanupProbeDebridService(serviceType: .realDebrid)
        let factory: DebridServiceFactory = { serviceType, _ in
            serviceType == .realDebrid ? probe : CleanupProbeDebridService(serviceType: serviceType)
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        try await db.saveDebridConfig(makeDebridConfig(id: "cfg-real", type: .realDebrid, priority: 0))

        try await manager.initialize()

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            torrentId: "   "
        ))
        await manager.cleanupRemoteTransfer(from: context)

        #expect(await probe.cleanupCallCount() == 0)
    }

    @Test func cleanupFromContextWithNoConfiguredServicesIsNoOp() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let manager = DebridManager(database: db, secretStore: secretStore)

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            preferredService: .realDebrid,
            torrentId: "orphaned-torrent"
        ))

        await manager.cleanupRemoteTransfer(from: context)
    }

    @Test func cleanupFromContextFallsBackToPreferredWhenResolvedServiceNoLongerConfigured() async throws {
        let db = try await makeInMemoryDB()
        let secretStore = MemorySecretStore()

        let realProbe = CleanupProbeDebridService(serviceType: .realDebrid)
        let torProbe = CleanupProbeDebridService(serviceType: .torBox)

        let factory: DebridServiceFactory = { serviceType, _ in
            switch serviceType {
            case .torBox: torProbe
            case .realDebrid: realProbe
            default: CleanupProbeDebridService(serviceType: serviceType)
            }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        try await db.saveDebridConfig(makeDebridConfig(id: "cfg-tb", type: .torBox, priority: 0))

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            preferredService: .torBox,
            torrentId: "stale-torrent",
            resolvedDebridService: "real_debrid"
        ))

        await manager.cleanupRemoteTransfer(from: context)

        #expect(await torProbe.tookCleanupCall(for: "stale-torrent"))
        #expect(await !realProbe.tookCleanupCall(for: "stale-torrent"))
    }

    @Test func cleanupFromContextUsesResolvedServiceWhenConfiguredEvenIfPreferredIsDifferent() async throws {
        let db = try await makeInMemoryDB()
        let secretStore = MemorySecretStore()

        let resolvedProbe = CleanupProbeDebridService(serviceType: .realDebrid)
        let preferredProbe = CleanupProbeDebridService(serviceType: .torBox)

        let factory: DebridServiceFactory = { serviceType, _ in
            switch serviceType {
            case .realDebrid: resolvedProbe
            case .torBox: preferredProbe
            default: CleanupProbeDebridService(serviceType: serviceType)
            }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-rd",
                type: .realDebrid,
                priority: 0,
                tokenRef: "token-rd"
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-tb",
                type: .torBox,
                priority: 1,
                tokenRef: "token-tb"
            )
        )

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            preferredService: .torBox,
            torrentId: "resolved-torrent",
            resolvedDebridService: "real_debrid"
        ))

        await manager.cleanupRemoteTransfer(from: context)

        #expect(await resolvedProbe.tookCleanupCall(for: "resolved-torrent"))
        #expect(await !preferredProbe.tookCleanupCall(for: "resolved-torrent"))
    }

    @Test func cleanupFromContextFallsBackToFirstConfiguredServiceByPriority() async throws {
        let db = try await makeInMemoryDB()
        let secretStore = MemorySecretStore()

        let probeRD = CleanupProbeDebridService(serviceType: .realDebrid)
        let probeTB = CleanupProbeDebridService(serviceType: .torBox)

        let factory: DebridServiceFactory = { serviceType, _ in
            switch serviceType {
            case .realDebrid: probeRD
            case .torBox: probeTB
            default: CleanupProbeDebridService(serviceType: serviceType)
            }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        try await db.saveDebridConfig(makeDebridConfig(id: "cfg-rd", type: .realDebrid, priority: 0))
        try await db.saveDebridConfig(makeDebridConfig(id: "cfg-tb", type: .torBox, priority: 10))

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            torrentId: "cleanup-by-priority"
        ))

        await manager.cleanupRemoteTransfer(from: context)

        #expect(await probeRD.tookCleanupCall(for: "cleanup-by-priority"))
        #expect(await !probeTB.tookCleanupCall(for: "cleanup-by-priority"))
    }

    @Test func cleanupFromContextStillSwallowsCleanupFailure() async throws {
        let db = try await makeInMemoryDB()
        let secretStore = MemorySecretStore()

        let failingProbe = CleanupProbeDebridService(
            serviceType: .realDebrid,
            shouldThrowOnCleanup: true
        )

        let factory: DebridServiceFactory = { serviceType, _ in
            serviceType == .realDebrid ? failingProbe : CleanupProbeDebridService(serviceType: serviceType)
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        try await db.saveDebridConfig(makeDebridConfig(id: "cfg-failure", type: .realDebrid, priority: 0))

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            torrentId: "cleanup-failure"
        ))

        await manager.cleanupRemoteTransfer(from: context)
        #expect(await failingProbe.tookCleanupCall(for: "cleanup-failure"))
    }

    @Test func cleanupFromContextInitializesServicesLazilyWhenNeeded() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let torProbe = CleanupProbeDebridService(serviceType: .torBox)
        let factory: DebridServiceFactory = { serviceType, _ in
            serviceType == .torBox ? torProbe : CleanupProbeDebridService(serviceType: serviceType)
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let key = SecretKey.debridToken(service: .torBox, configId: "cfg-lazy")
        try await secretStore.setSecret("token", for: key)
        try await db.saveDebridConfig(makeDebridConfig(id: "cfg-lazy", type: .torBox, tokenRef: SecretReference.encode(key: key)))

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            preferredService: .torBox,
            torrentId: "lazy-init-torrent"
        ))

        await manager.cleanupRemoteTransfer(from: context)
        #expect(await torProbe.tookCleanupCall(for: "lazy-init-torrent"))
    }

    @Test func cleanupFromContextFallsBackToPreferredWhenResolvedServiceValueIsInvalid() async throws {
        let db = try await makeInMemoryDB()
        let secretStore = MemorySecretStore()

        let preferredProbe = CleanupProbeDebridService(serviceType: .torBox)
        let fallbackProbe = CleanupProbeDebridService(serviceType: .realDebrid)
        let factory: DebridServiceFactory = { serviceType, _ in
            switch serviceType {
            case .torBox:
                preferredProbe
            case .realDebrid:
                fallbackProbe
            default:
                CleanupProbeDebridService(serviceType: serviceType)
            }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let preferredKey = SecretKey.debridToken(service: .torBox, configId: "cfg-tb-invalid-resolved")
        try await secretStore.setSecret("token", for: preferredKey)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-tb-invalid-resolved",
                type: .torBox,
                priority: 0,
                tokenRef: SecretReference.encode(key: preferredKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-rd-invalid-resolved",
                type: .realDebrid,
                priority: 1,
                tokenRef: SecretReference.encode(key: SecretKey.debridToken(service: .realDebrid, configId: "cfg-rd-invalid"))
            )
        )

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            preferredService: .torBox,
            torrentId: "invalid-resolved-service",
            resolvedDebridService: "not-a-service"
        ))

        await manager.cleanupRemoteTransfer(from: context)
        #expect(await preferredProbe.tookCleanupCall(for: "invalid-resolved-service"))
        #expect(await !fallbackProbe.tookCleanupCall(for: "invalid-resolved-service"))
    }

    @Test func cleanupFromContextDoesNothingWhenConfiguredServiceCannotBeResolvedFromToken() async throws {
        let db = try await makeInMemoryDB()
        let secretStore = MemorySecretStore()

        let probe = CleanupProbeDebridService(serviceType: .realDebrid)
        let factory: DebridServiceFactory = { serviceType, _ in
            switch serviceType {
            case .realDebrid:
                probe
            default:
                CleanupProbeDebridService(serviceType: serviceType)
            }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let tokenKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-token-missing")
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-token-missing",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: tokenKey)
            )
        )

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            preferredService: .realDebrid,
            torrentId: "missing-token-torrent"
        ))

        await manager.cleanupRemoteTransfer(from: context)
        #expect(await probe.cleanupCallCount() == 0)
    }

    @Test func cleanupFromContextIgnoresInitializationFailureDuringSecretLookup() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let secretStore = ThrowingSecretStore()
        let tokenKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-secret-fail")
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-secret-fail",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: tokenKey)
            )
        )
        let manager = DebridManager(
            database: db,
            secretStore: secretStore
        )
        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            torrentId: "secret-store-fail-torrent"
        ))

        await manager.cleanupRemoteTransfer(from: context)
    }

    @Test func initializeSkipsServicesWithSecretLookupErrors() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let badKey = SecretKey.debridToken(service: .torBox, configId: "cfg-bad")
        let goodKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-good")
        let secretStore = SelectiveThrowingSecretStore(throwingKeys: [badKey])
        try await secretStore.setSecret("good-token", for: goodKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-good",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: goodKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-bad",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: badKey)
            )
        )

        let factory: DebridServiceFactory = { serviceType, _ in
            switch serviceType {
            case .realDebrid:
                return CleanupProbeDebridService(serviceType: .realDebrid)
            default:
                return CleanupProbeDebridService(serviceType: serviceType)
            }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        try await manager.initialize()
        #expect(await manager.availableServices() == [.realDebrid])
    }

    @Test func initializeSkipsLegacyConfigWhenTokenMigrationFails() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let badMigrationKey = DebridConfig.secretKey(for: "cfg-legacy-fail", serviceType: .realDebrid)
        let goodKey = SecretKey.debridToken(service: .allDebrid, configId: "cfg-good")
        let secretStore = SelectiveThrowingSecretStore(throwingKeys: [badMigrationKey])

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-legacy-fail",
                type: .realDebrid,
                priority: 0,
                tokenRef: "legacy-token-value"
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-good",
                type: .allDebrid,
                priority: 1,
                tokenRef: SecretReference.encode(key: goodKey)
            )
        )
        try await secretStore.setSecret("good-token", for: goodKey)

        let factory: DebridServiceFactory = { serviceType, _ in
            switch serviceType {
            case .allDebrid:
                CountingDebridService(serviceType: .allDebrid)
            default:
                CountingDebridService(serviceType: serviceType)
            }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        try await manager.initialize()
        #expect(await manager.availableServices() == [.allDebrid])
    }

    @Test func resolveStreamFromContextDoesNotFailoverOnCancellationErrorDuringAddMagnet() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let primaryKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-cancel-context-add")
        let fallbackKey = SecretKey.debridToken(service: .torBox, configId: "cfg-fallback-context-add")
        try await secretStore.setSecret("rd-token", for: primaryKey)
        try await secretStore.setSecret("tb-token", for: fallbackKey)

        let primaryService = CancellationAwareService(
            serviceType: .realDebrid,
            throwCancellationOnAdd: true
        )
        let fallbackService = CancellationAwareService(serviceType: .torBox)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { serviceType, _ in
                serviceType == .realDebrid ? primaryService : fallbackService
            }
        )

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-cancel-context-add",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: primaryKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-fallback-context-add",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: fallbackKey)
            )
        )

        try await manager.initialize()

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            torrentId: "context-cancel-add",
            resolvedDebridService: DebridServiceType.realDebrid.rawValue
        ))

        await #expect(throws: CancellationError.self) {
            _ = try await manager.resolveStream(from: context)
        }

        #expect(await primaryService.callCountAddMagnet() == 1)
        #expect(await fallbackService.callCountAddMagnet() == 0)
    }

    @Test func resolveStreamFromContextDoesNotFailoverOnCancellationErrorDuringGetStream() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let primaryKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-cancel-context-stream")
        let fallbackKey = SecretKey.debridToken(service: .torBox, configId: "cfg-fallback-context-stream")
        try await secretStore.setSecret("rd-token", for: primaryKey)
        try await secretStore.setSecret("tb-token", for: fallbackKey)

        let primaryService = CancellationAwareService(
            serviceType: .realDebrid,
            throwCancellationOnGetStream: true
        )
        let fallbackService = CancellationAwareService(serviceType: .torBox)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { serviceType, _ in
                serviceType == .realDebrid ? primaryService : fallbackService
            }
        )

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-cancel-context-stream",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: primaryKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-fallback-context-stream",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: fallbackKey)
            )
        )

        try await manager.initialize()

        let context = try #require(StreamRecoveryContext(
            infoHash: validInfoHash,
            torrentId: "context-cancel-stream",
            resolvedDebridService: DebridServiceType.realDebrid.rawValue
        ))

        await #expect(throws: CancellationError.self) {
            _ = try await manager.resolveStream(from: context)
        }

        #expect(await primaryService.callCountAddMagnet() == 1)
        #expect(await primaryService.callCountSelectFiles() == 1)
        #expect(await primaryService.callCountGetStream() == 1)
        #expect(await fallbackService.callCountAddMagnet() == 0)
    }

    @Test func resolveStreamFallsBackWhenPreferredServiceIsUnavailableAfterInitErrors() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let preferredBadKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-bad")
        let preferredGoodKey = SecretKey.debridToken(service: .torBox, configId: "cfg-good")
        let secretStore = SelectiveThrowingSecretStore(throwingKeys: [preferredBadKey])
        try await secretStore.setSecret("good-token", for: preferredGoodKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-bad",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: preferredBadKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-good",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: preferredGoodKey)
            )
        )

        let badService = CountingDebridService(serviceType: .realDebrid)
        let fallbackService = CountingDebridService(serviceType: .torBox)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { serviceType, _ in
                switch serviceType {
                case .realDebrid:
                    badService
                case .torBox:
                    fallbackService
                default:
                    CountingDebridService(serviceType: serviceType)
                }
            }
        )

        try await manager.initialize()
        let stream = try await manager.resolveStream(
            hash: validInfoHash,
            preferredService: .realDebrid
        )

        #expect(stream.debridService == DebridServiceType.torBox.rawValue)
        #expect(await badService.addMagnetCallCount() == 0)
        #expect(await fallbackService.addMagnetCallCount() == 1)
    }

    @Test func resolveStreamDoesNotFailoverOnCancellationError() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let primaryKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-cancel")
        let fallbackKey = SecretKey.debridToken(service: .torBox, configId: "cfg-fallback")
        try await secretStore.setSecret("rd-token", for: primaryKey)
        try await secretStore.setSecret("tb-token", for: fallbackKey)

        let primaryService = CancellationAwareService(serviceType: .realDebrid, throwCancellationOnAdd: true)
        let fallbackService = CancellationAwareService(serviceType: .torBox)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { serviceType, _ in
                serviceType == .realDebrid ? primaryService : fallbackService
            }
        )

        try await db.saveDebridConfig(
            makeDebridConfig(id: "cfg-cancel", type: .realDebrid, priority: 0, tokenRef: SecretReference.encode(key: primaryKey))
        )
        try await db.saveDebridConfig(
            makeDebridConfig(id: "cfg-fallback", type: .torBox, priority: 1, tokenRef: SecretReference.encode(key: fallbackKey))
        )

        try await manager.initialize()

        await #expect(throws: CancellationError.self) {
            _ = try await manager.resolveStream(hash: "0123456789abcdef0123456789abcdef01234567")
        }

        #expect(await primaryService.callCountAddMagnet() == 1)
        #expect(await fallbackService.callCountAddMagnet() == 0)
    }

    @Test func resolveStreamDoesNotFailoverOnCancellationErrorDuringSelectFiles() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let primaryKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-cancel-select")
        let fallbackKey = SecretKey.debridToken(service: .torBox, configId: "cfg-fallback-select")
        try await secretStore.setSecret("rd-token", for: primaryKey)
        try await secretStore.setSecret("tb-token", for: fallbackKey)

        let primaryService = CancellationAwareService(
            serviceType: .realDebrid,
            throwCancellationOnSelectFiles: true
        )
        let fallbackService = CancellationAwareService(serviceType: .torBox)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { serviceType, _ in
                serviceType == .realDebrid ? primaryService : fallbackService
            }
        )

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-cancel-select",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: primaryKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-fallback-select",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: fallbackKey)
            )
        )

        try await manager.initialize()

        await #expect(throws: CancellationError.self) {
            _ = try await manager.resolveStream(hash: "0123456789abcdef0123456789abcdef01234567")
        }

        #expect(await primaryService.callCountAddMagnet() == 1)
        #expect(await primaryService.callCountSelectFiles() == 1)
        #expect(await fallbackService.callCountAddMagnet() == 0)
    }

    @Test func resolveStreamDoesNotFailoverOnCancellationErrorDuringGetStream() async throws {
        let db = try await makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let primaryKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-cancel-stream")
        let fallbackKey = SecretKey.debridToken(service: .torBox, configId: "cfg-fallback-stream")
        try await secretStore.setSecret("rd-token", for: primaryKey)
        try await secretStore.setSecret("tb-token", for: fallbackKey)

        let primaryService = CancellationAwareService(
            serviceType: .realDebrid,
            throwCancellationOnGetStream: true
        )
        let fallbackService = CancellationAwareService(serviceType: .torBox)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { serviceType, _ in
                serviceType == .realDebrid ? primaryService : fallbackService
            }
        )

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-cancel-stream",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: primaryKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-fallback-stream",
                type: .torBox,
                priority: 1,
                tokenRef: SecretReference.encode(key: fallbackKey)
            )
        )

        try await manager.initialize()

        await #expect(throws: CancellationError.self) {
            _ = try await manager.resolveStream(hash: "0123456789abcdef0123456789abcdef01234567")
        }

        #expect(await primaryService.callCountAddMagnet() == 1)
        #expect(await primaryService.callCountSelectFiles() == 1)
        #expect(await primaryService.callCountGetStream() == 1)
        #expect(await fallbackService.callCountAddMagnet() == 0)
    }
}
