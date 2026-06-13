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

private actor NamedUnrestrictService: DebridServiceProtocol {
    let serviceType: DebridServiceType
    let streamURL: URL

    init(serviceType: DebridServiceType, streamURL: URL) {
        self.serviceType = serviceType
        self.streamURL = streamURL
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(
            username: "unrestrict-\(serviceType.rawValue)",
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
        "torrent-\(hash)"
    }

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

    func unrestrict(link: String) async throws -> URL {
        streamURL
    }
}

@Suite("DebridManager unrestrict filename edge cases")
struct DebridManagerUnrestrictFilenameEdgeCaseTests {
    @Test func unrestrictUsesPercentDecodedFilenameFromStreamURL() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let streamURL = URL(string: "https://cdn.example.com/encoded%20name.mkv")!

        let service = NamedUnrestrictService(serviceType: .realDebrid, streamURL: streamURL)
        let factory: DebridServiceFactory = { serviceType, _ in
            if serviceType == .realDebrid { service } else { service }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let key = SecretKey.debridToken(service: .realDebrid, configId: "cfg-unrestrict-encoded")
        try await secretStore.setSecret("rd-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-unrestrict-encoded",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let stream = try await manager.unrestrict(link: "https://origin.example/encoded%20fallback.mkv", serviceType: .realDebrid)
        #expect(stream.fileName == "encoded name.mkv")
    }

    @Test func unrestrictFallsBackToDecodedFilenameFromFallbackLinkWhenStreamPathIsMissing() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let streamURL = URL(string: "https://cdn.example.com")!
        let fallbackLink = "https://origin.example/videos/Fallback%20Video.mkv?token=abc"

        let service = NamedUnrestrictService(serviceType: .realDebrid, streamURL: streamURL)
        let factory: DebridServiceFactory = { serviceType, _ in
            if serviceType == .realDebrid { service } else { service }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let key = SecretKey.debridToken(service: .realDebrid, configId: "cfg-unrestrict-fallback")
        try await secretStore.setSecret("rd-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-unrestrict-fallback",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let stream = try await manager.unrestrict(link: fallbackLink, serviceType: .realDebrid)
        #expect(stream.fileName == "Fallback Video.mkv")
    }

    @Test func unrestrictFallsBackWhenStreamPathIsRootedAndFallbackIsPathless() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let streamURL = URL(string: "https://cdn.example.com/")!
        let fallbackLink = "Fallback%20Video.mkv"

        let service = NamedUnrestrictService(serviceType: .realDebrid, streamURL: streamURL)
        let factory: DebridServiceFactory = { serviceType, _ in
            if serviceType == .realDebrid { service } else { service }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let key = SecretKey.debridToken(service: .realDebrid, configId: "cfg-unrestrict-root-fallback")
        try await secretStore.setSecret("rd-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-unrestrict-root-fallback",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let stream = try await manager.unrestrict(link: fallbackLink, serviceType: .realDebrid)
        #expect(stream.fileName == "Fallback Video.mkv")
    }

    @Test func unrestrictUsesRawFilenameWhenStreamPathPercentDecodingFails() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let streamURL = URL(string: "https://cdn.example.com/%ZZ%bad%20fallback.mkv")!

        let service = NamedUnrestrictService(serviceType: .realDebrid, streamURL: streamURL)
        let factory: DebridServiceFactory = { serviceType, _ in
            if serviceType == .realDebrid { service } else { service }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let key = SecretKey.debridToken(service: .realDebrid, configId: "cfg-unrestrict-malformed-stream")
        try await secretStore.setSecret("rd-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-unrestrict-malformed-stream",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let stream = try await manager.unrestrict(
            link: "https://origin.example/ignored.mkv",
            serviceType: .realDebrid
        )
        #expect(stream.fileName == "%ZZ%bad%20fallback.mkv")
    }

    @Test func unrestrictUsesRawFallbackFilenameWhenFallbackPercentDecodingFails() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let streamURL = URL(string: "https://cdn.example.com/")!
        let fallbackLink = "https://origin.example/%ZZ%bad%20fallback.mkv?token=abc"

        let service = NamedUnrestrictService(serviceType: .realDebrid, streamURL: streamURL)
        let factory: DebridServiceFactory = { serviceType, _ in
            if serviceType == .realDebrid { service } else { service }
        }

        let manager = DebridManager(database: db, secretStore: secretStore, serviceFactory: factory)
        let key = SecretKey.debridToken(service: .realDebrid, configId: "cfg-unrestrict-malformed-fallback")
        try await secretStore.setSecret("rd-token", for: key)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "cfg-unrestrict-malformed-fallback",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: key)
            )
        )

        let stream = try await manager.unrestrict(link: fallbackLink, serviceType: .realDebrid)
        #expect(stream.fileName == "%ZZ%bad%20fallback.mkv")
    }
}
