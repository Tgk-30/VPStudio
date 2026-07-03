import Foundation
import Testing
@testable import VPStudio

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

private func makeInMemoryDB() throws -> DatabaseManager {
    try DatabaseManager(inMemoryNamed: "test-\(UUID().uuidString)")
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

private actor BatchCapturingCacheService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    private var checkCacheCalls: [[String]] = []

    init(serviceType: DebridServiceType) {
        self.serviceType = serviceType
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(
            username: "batch-\(serviceType.rawValue)",
            email: nil,
            premiumExpiry: nil,
            isPremium: true
        )
    }

    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        checkCacheCalls.append(hashes)
        return hashes.reduce(into: [String: CacheStatus]()) { result, hash in
            result[hash] = .notCached
        }
    }

    func addMagnet(hash: String) async throws -> String { "torrent-\(hash)" }

    func addMagnet(hash: String, magnetURI: String?) async throws -> String {
        "torrent-\(hash)"
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

    func checkCacheCallCount() async -> Int {
        checkCacheCalls.count
    }

    func checkCacheCallBatches() async -> [[String]] {
        checkCacheCalls
    }
}

private actor ThrowingCacheService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    let error: Error

    init(serviceType: DebridServiceType, error: Error = DebridError.networkError("cache service unavailable")) {
        self.serviceType = serviceType
        self.error = error
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(
            username: "throwing-\(serviceType.rawValue)",
            email: nil,
            premiumExpiry: nil,
            isPremium: true
        )
    }

    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        throw error
    }

    func addMagnet(hash: String) async throws -> String { "" }

    func addMagnet(hash: String, magnetURI: String?) async throws -> String { "" }

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
            streamURL: URL(string: "https://cache-fail.example/\(serviceType.rawValue)/stream.mkv")!,
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
        URL(string: "https://cache-fail.example/\(serviceType.rawValue).mkv")!
    }
}

private func makeValidInfoHash(_ index: Int) -> String {
    let tail = String(format: "%08x", index)
    return "0123456789abcdef0123456789abcdef\(tail)"
}

@Suite("DebridManager cache batch edge cases")
struct DebridManagerCheckCacheEdgeCaseTests {
    @Test func checkCacheAcrossServicesBatchesLargeInputByConfiguredSize() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let service = BatchCapturingCacheService(serviceType: .realDebrid)
        let factory: DebridServiceFactory = { serviceType, _ in
            serviceType == .realDebrid ? service : BatchCapturingCacheService(serviceType: serviceType)
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let tokenKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-cache-batches")
        try await secretStore.setSecret("rd-token", for: tokenKey)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-cache-batches",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: tokenKey)
            )
        )

        let hashes = (0..<49).map(makeValidInfoHash)
        let result = try await manager.checkCacheAcrossServices(hashes: hashes)

        let calls = await service.checkCacheCallBatches()
        #expect(calls.count == 2)
        #expect(calls[0].count == 48)
        #expect(calls[1].count == 1)
        #expect(await service.checkCacheCallCount() == 2)
        #expect(result.count == hashes.count)

        for hash in hashes {
            #expect(result[hash]?.0 == .notCached)
            #expect(result[hash]?.1 == .realDebrid)
        }
    }

    @Test func checkCacheAcrossServicesSkipsServiceWhenNoHashesRemainAfterNormalization() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let service = BatchCapturingCacheService(serviceType: .realDebrid)
        let factory: DebridServiceFactory = { serviceType, _ in
            serviceType == .realDebrid ? service : BatchCapturingCacheService(serviceType: serviceType)
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let tokenKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-cache-empty")
        try await secretStore.setSecret("rd-token", for: tokenKey)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-cache-empty",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: tokenKey)
            )
        )

        let result = try await manager.checkCacheAcrossServices(
            hashes: ["not-a-hash", "   ", "\t\n", "!!!"]
        )

        #expect(result.isEmpty)
        #expect(await service.checkCacheCallCount() == 0)
    }

    @Test func checkCacheAcrossServicesReturnsUnknownWhenLaterServiceFailsAfterSuccesses() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let successService = BatchCapturingCacheService(serviceType: .allDebrid)
        let failureService = ThrowingCacheService(serviceType: .realDebrid, error: DebridError.networkError("simulated cache failure"))
        let factory: DebridServiceFactory = { serviceType, _ in
            switch serviceType {
            case .allDebrid:
                successService
            case .realDebrid:
                failureService
            default:
                BatchCapturingCacheService(serviceType: serviceType)
            }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let allDebridKey = SecretKey.debridToken(service: .allDebrid, configId: "cfg-cache-all-success")
        let realDebridKey = SecretKey.debridToken(service: .realDebrid, configId: "cfg-cache-real-fail")
        try await secretStore.setSecret("cache-success", for: allDebridKey)
        try await secretStore.setSecret("cache-fail", for: realDebridKey)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-cache-all-success",
                type: .allDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: allDebridKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-cache-real-fail",
                type: .realDebrid,
                priority: 1,
                tokenRef: SecretReference.encode(key: realDebridKey)
            )
        )

        let hashes = [
            "0123456789abcdef0123456789abcdef01234567",
            "89abcdef0123456789abcdef0123456789abcdef"
        ]
        let result = try await manager.checkCacheAcrossServices(hashes: hashes)

        #expect(await successService.checkCacheCallCount() == 1)
        #expect(result.count == hashes.count)
        for hash in hashes {
            let entry = result[hash.lowercased()]
            #expect(entry != nil)
            if let entry {
                #expect(entry == (.unknown, .allDebrid))
            }
        }
    }
}
