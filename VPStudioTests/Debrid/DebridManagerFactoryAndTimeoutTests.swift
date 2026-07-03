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

private actor FileNotReadyDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType = .realDebrid

    private var getStreamCallCount = 0
    private var cleanupCallCount = 0

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "ready-fail", email: nil, premiumExpiry: nil, isPremium: true)
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
        try await addMagnet(hash: hash)
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
        cleanupCallCount += 1
    }

    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        getStreamCallCount += 1
        throw DebridError.fileNotReady("waiting for stream")
    }

    func unrestrict(link: String) async throws -> URL {
        URL(string: "https://fallback.example/stream.mp4")!
    }

    func getStreamCallCountValue() async -> Int {
        getStreamCallCount
    }

    func cleanupCallCountValue() async -> Int {
        cleanupCallCount
    }
}

private actor EpisodeAwareDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType

    private var addMagnetCalls = 0
    private var selectMatchingEpisodeFileCalls = 0
    private var getStreamCalls = 0
    private var lastResolvedFileNameHint: String?
    private var lastResolvedFileSizeHint: Int64?
    private var lastSeasonNumber: Int?
    private var lastEpisodeNumber: Int?

    init(serviceType: DebridServiceType) {
        self.serviceType = serviceType
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "test-\(serviceType.rawValue)", email: nil, premiumExpiry: nil, isPremium: true)
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

    func addMagnet(hash: String, magnetURI: String?) async throws -> String {
        try await addMagnet(hash: hash)
    }

    func selectFiles(torrentId: String, fileIds: [Int]) async throws {}

    func selectMatchingEpisodeFile(
        torrentId: String,
        seasonNumber: Int,
        episodeNumber: Int,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> Bool {
        selectMatchingEpisodeFileCalls += 1
        lastSeasonNumber = seasonNumber
        lastEpisodeNumber = episodeNumber
        lastResolvedFileNameHint = resolvedFileNameHint
        lastResolvedFileSizeHint = resolvedFileSizeHint
        return true
    }

    func cleanupRemoteTransfer(torrentId: String) async throws {}

    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        getStreamCalls += 1
        return StreamInfo(
            streamURL: URL(string: "https://fixtures.example/\(serviceType.rawValue)/stream.mkv")!,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            fileName: "Episode S01E01.mkv",
            sizeBytes: nil,
            debridService: serviceType.rawValue
        )
    }

    func unrestrict(link: String) async throws -> URL {
        URL(string: "https://fixtures.example/\(serviceType.rawValue)/unrestrict.mkv")!
    }

    func addMagnetCallCount() async -> Int { addMagnetCalls }
    func selectMatchingEpisodeFileCallCount() async -> Int { selectMatchingEpisodeFileCalls }
    func getStreamCallCount() async -> Int { getStreamCalls }
    func lastEpisodeSelection() async -> (Int?, Int?, String?, Int64?) {
        (lastSeasonNumber, lastEpisodeNumber, lastResolvedFileNameHint, lastResolvedFileSizeHint)
    }
}

@Suite("DebridManager Factory and Timeout Coverage", .serialized)
struct DebridManagerFactoryAndTimeoutCoverageTests {
    @Test func liveServiceFactoryRejectsInvalidHashThroughQAFixtureService() async throws {
        let fixture = QADebridFixture(
            hash: "0123456789abcdef0123456789abcdef01234567",
            serviceType: .realDebrid,
            streamURLs: [
                URL(string: "https://fixtures.example/stream-1.mkv")!
            ],
            fileName: "Fixture.Release.mkv"
        )

        DebridManager.setQAFixtureProvider { fixture }
        defer { DebridManager.resetQAFixtureProvider() }

        let service = DebridManager.liveServiceFactory(type: .realDebrid, token: "ignored")
        await #expect(throws: DebridError.invalidHash("not-a-valid-hash")) {
            _ = try await service.addMagnet(hash: "not-a-valid-hash")
        }
    }

    @Test func liveServiceFactoryRejectsMismatchedValidHashThroughQAFixtureService() async throws {
        let fixtureHash = "0123456789abcdef0123456789abcdef01234567"
        let mismatchedHash = "ffffffffffffffffffffffffffffffffffffffff"

        DebridManager.setQAFixtureProvider {
            QADebridFixture(
                hash: fixtureHash,
                serviceType: .realDebrid,
                streamURLs: [URL(string: "https://fixtures.example/stream-1.mkv")!],
                fileName: "Fixture.Release.mkv"
            )
        }
        defer { DebridManager.resetQAFixtureProvider() }

        let service = DebridManager.liveServiceFactory(type: .realDebrid, token: "ignored")
        await #expect(throws: DebridError.invalidHash(mismatchedHash)) {
            _ = try await service.addMagnet(hash: mismatchedHash)
        }
    }

    @Test func liveServiceFactoryCanReturnQAFixtureService() async throws {
        let fixture = QADebridFixture(
            hash: "0123456789abcdef0123456789abcdef01234567",
            serviceType: .realDebrid,
            streamURLs: [
                URL(string: "https://fixtures.example/stream-1.mkv")!,
                URL(string: "https://fixtures.example/stream-2.mkv")!,
            ],
            fileName: "Fixture.Release.mkv"
        )

        DebridManager.setQAFixtureProvider { fixture }
        defer { DebridManager.resetQAFixtureProvider() }

        let service = DebridManager.liveServiceFactory(type: .realDebrid, token: "ignored")
        #expect(service.serviceType == .realDebrid)

        let info = try await service.getAccountInfo()
        #expect(info.username == "qa-fixture")

        let torrentId = try await service.addMagnet(hash: fixture.hash)
        #expect(torrentId == "qa-\(fixture.hash)")

        try await service.selectFiles(torrentId: torrentId, fileIds: [])

        let firstStream = try await service.getStreamURL(torrentId: torrentId)
        let secondStream = try await service.getStreamURL(torrentId: torrentId)
        #expect(firstStream.streamURL.absoluteString == fixture.streamURLs[0].absoluteString)
        #expect(secondStream.streamURL.absoluteString == fixture.streamURLs[1].absoluteString)

        let caches = try await service.checkCache(hashes: [fixture.hash, "deadbeef"])
        if case .cached(_, let cachedFileName, _) = caches[fixture.hash] {
            #expect(cachedFileName == fixture.fileName)
        } else {
            Issue.record("Expected fixture hash to be cached")
        }
        #expect(caches["deadbeef"] == .notCached)

        let unrestricted = try await service.unrestrict(link: fixture.streamURLs[0].absoluteString)
        #expect(unrestricted == fixture.streamURLs[0])
    }

    @Test func resolveStreamUsesConfiguredServicePathWithEpisodeHints() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let tokenKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-episodes")
        try await secretStore.setSecret("episode-token", for: tokenKey)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-episodes",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: tokenKey)
            )
        )

        let service = EpisodeAwareDebridService(serviceType: .realDebrid)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { _, _ in service }
        )
        try await manager.initialize()

        let context = StreamRecoveryContext(
            infoHash: "0123456789abcdef0123456789abcdef01234567",
            preferredService: .realDebrid,
            seasonNumber: 2,
            episodeNumber: 5,
            resolvedFileName: "Fixture S02E05.mkv",
            resolvedFileSizeBytes: 12_345
        )!
        let stream = try await manager.resolveStream(from: context)

        let lastEpisodeSelection = await service.lastEpisodeSelection()
        #expect(lastEpisodeSelection.0 == 2)
        #expect(lastEpisodeSelection.1 == 5)
        #expect(lastEpisodeSelection.2 == "Fixture S02E05.mkv")
        #expect(lastEpisodeSelection.3 == 12_345)
        #expect(await service.addMagnetCallCount() == 1)
        #expect(await service.selectMatchingEpisodeFileCallCount() == 1)
        #expect(await service.getStreamCallCount() == 1)
        #expect(stream.debridService == DebridServiceType.realDebrid.rawValue)
    }

    @Test func resolveStreamRespectsAlphabeticalTieBreakWhenPriorityMatches() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()

        let allDebridKey = SecretKey.debridToken(service: .allDebrid, configId: "all-debrid")
        let realDebridKey = SecretKey.debridToken(service: .realDebrid, configId: "real-debrid")
        try await secretStore.setSecret("all-debrid-token", for: allDebridKey)
        try await secretStore.setSecret("real-debrid-token", for: realDebridKey)

        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "all-debrid",
                type: .allDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: allDebridKey)
            )
        )
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "real-debrid",
                type: .realDebrid,
                priority: 0,
                tokenRef: SecretReference.encode(key: realDebridKey)
            )
        )

        let allService = EpisodeAwareDebridService(serviceType: .allDebrid)
        let realService = EpisodeAwareDebridService(serviceType: .realDebrid)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { serviceType, _ in
                serviceType == .allDebrid ? allService : realService
            }
        )
        try await manager.initialize()

        let stream = try await manager.resolveStream(hash: "0123456789abcdef0123456789abcdef01234567")
        #expect(stream.debridService == DebridServiceType.allDebrid.rawValue)
        #expect(await allService.getStreamCallCount() == 1)
        #expect(await realService.getStreamCallCount() == 0)
    }

    @Test func liveServiceFactoryFallsBackToEasyNewsService() async {
        DebridManager.setQAFixtureProvider { nil }
        defer { DebridManager.resetQAFixtureProvider() }

        let service = DebridManager.liveServiceFactory(type: .easyNews, token: "easy-token")
        #expect(service.serviceType == .easyNews)
    }

    @Test func liveServiceFactoryFallsBackToDefaultFixtureProviderWhenUnset() {
        DebridManager.resetQAFixtureProvider()
        let service = DebridManager.liveServiceFactory(type: .realDebrid, token: "unset-fixture-token")
        if let fixture = QARuntimeOptions.debridFixture {
            #expect(service.serviceType == fixture.serviceType)
            #expect(service is QADebridService)
        } else {
            #expect(service.serviceType == .realDebrid)
            #expect(service is RealDebridService)
        }
    }

    @Test func resolveStreamForwardsEpisodeHintsThroughPublicAPI() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let tokenKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-public-episodes")
        try await secretStore.setSecret("public-episode-token", for: tokenKey)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-public-episodes",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: tokenKey)
            )
        )

        let service = EpisodeAwareDebridService(serviceType: .realDebrid)
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { _, _ in service }
        )
        try await manager.initialize()

        let context = StreamRecoveryContext(
            infoHash: "0123456789abcdef0123456789abcdef01234567",
            preferredService: .realDebrid,
            seasonNumber: 3,
            episodeNumber: 7,
            resolvedFileName: "Episode S03E07.mkv",
            resolvedFileSizeBytes: 7_500
        )!
        let stream = try await manager.resolveStream(from: context)

        let lastEpisodeSelection = await service.lastEpisodeSelection()
        #expect(lastEpisodeSelection.0 == 3)
        #expect(lastEpisodeSelection.1 == 7)
        #expect(lastEpisodeSelection.2 == "Episode S03E07.mkv")
        #expect(lastEpisodeSelection.3 == 7_500)
        #expect(await service.selectMatchingEpisodeFileCallCount() == 1)
        #expect(await service.getStreamCallCount() == 1)
        #expect(stream.debridService == DebridServiceType.realDebrid.rawValue)
    }

    @Test func resolveStreamRaisesTimeoutAfterConfiguredAttemptLimitIsReached() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let tokenKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-timeout")
        try await secretStore.setSecret("timeout-token", for: tokenKey)
        try await db.saveDebridConfig(
            makeDebridConfig(
                id: "rd-timeout",
                type: .realDebrid,
                tokenRef: SecretReference.encode(key: tokenKey)
            )
        )

        let service = FileNotReadyDebridService()
        let manager = DebridManager(
            database: db,
            secretStore: secretStore,
            serviceFactory: { _, _ in service },
            resolveStreamMaxAttempts: 3,
            resolveStreamInitialDelayNanoseconds: 1_000_000,
            resolveStreamMaxDelayNanoseconds: 1_000_000
        )
        try await manager.initialize()

        await #expect(throws: DebridError.timeout) {
            _ = try await manager.resolveStream(hash: "0123456789abcdef0123456789abcdef01234567")
        }

        #expect(await service.getStreamCallCountValue() == 3)
        #expect(await service.cleanupCallCountValue() == 1)
    }

    @Test func resolveStreamFallsBackToNoDebridErrorWhenNoServicesConfigured() async throws {
        let db = try makeInMemoryDB()
        try await db.migrate()
        let secretStore = MemorySecretStore()
        let manager = DebridManager(database: db, secretStore: secretStore)

        await #expect(
            throws: DebridError.networkError("No debrid services configured. Add one in Settings > Debrid Services.")
        ) {
            _ = try await manager.resolveStream(
                hash: "0123456789abcdef0123456789abcdef01234567",
                magnetURI: nil,
                seasonNumber: nil,
                episodeNumber: nil
            )
        }
    }

    @Test func cacheFallbackServiceDefaultsToRealDebridForEmptyOrderedServices() async {
        let db = try! makeInMemoryDB()
        let manager = DebridManager(database: db, secretStore: MemorySecretStore())

        let fallback = await manager._testCacheFallbackService(
            firstSuccessfulService: nil,
            orderedServices: [],
            hasFirstFailure: false
        )
        #expect(fallback.service == .realDebrid)
        #expect(fallback.status == .notCached)

        let fallbackWithFailure = await manager._testCacheFallbackService(
            firstSuccessfulService: nil,
            orderedServices: [],
            hasFirstFailure: true
        )
        #expect(fallbackWithFailure.service == .realDebrid)
        #expect(fallbackWithFailure.status == .unknown)
    }

    @Test func resolveStreamForServicesThrowsForEmptyCandidateServices() async {
        let db = try! makeInMemoryDB()
        let manager = DebridManager(database: db, secretStore: MemorySecretStore())

        await #expect(
            throws: DebridError.networkError("No debrid services configured. Add one in Settings > Debrid Services.")
        ) {
            _ = try await manager._testResolveStreamForServices(
                hash: "0123456789abcdef0123456789abcdef01234567",
                candidateServices: []
            )
        }
    }

    @Test func resolveStreamForServicesThrowsWhenCandidateServicesAreUnavailable() async {
        let db = try! makeInMemoryDB()
        let manager = DebridManager(database: db, secretStore: MemorySecretStore())

        await #expect(
            throws: DebridError.networkError("No debrid services configured. Add one in Settings > Debrid Services.")
        ) {
            _ = try await manager._testResolveStreamForServices(
                hash: "0123456789abcdef0123456789abcdef01234567",
                candidateServices: [.realDebrid]
            )
        }
    }

    @Test func qaFixtureValidateTokenIsReachable() async throws {
        DebridManager.setQAFixtureProvider {
            QADebridFixture(
                hash: "0123456789abcdef0123456789abcdef01234567",
                serviceType: .realDebrid,
                streamURLs: [URL(string: "https://fixtures.example/stream.mkv")!],
                fileName: "Fixture.Stream.mkv"
            )
        }
        defer { DebridManager.resetQAFixtureProvider() }

        let service = DebridManager.liveServiceFactory(type: .realDebrid, token: "ignored")
        let result = try await service.validateToken()
        #expect(result == true)
    }

    @Test func qaFixtureGetStreamURLThrowsWhenTorrentIdUnknown() async {
        DebridManager.setQAFixtureProvider {
            QADebridFixture(
                hash: "0123456789abcdef0123456789abcdef01234567",
                serviceType: .realDebrid,
                streamURLs: [URL(string: "https://fixtures.example/stream.mkv")!],
                fileName: "Fixture.Stream.mkv"
            )
        }
        defer { DebridManager.resetQAFixtureProvider() }

        let service = DebridManager.liveServiceFactory(type: .realDebrid, token: "ignored")
        await #expect(
            throws: DebridError.torrentNotFound("missing-torrent-id")
        ) {
            _ = try await service.getStreamURL(torrentId: "missing-torrent-id")
        }
    }

    @Test func qaFixtureUnrestrictThrowsForInvalidURL() async {
        DebridManager.setQAFixtureProvider {
            QADebridFixture(
                hash: "0123456789abcdef0123456789abcdef01234567",
                serviceType: .realDebrid,
                streamURLs: [URL(string: "https://fixtures.example/stream.mkv")!],
                fileName: "Fixture.Stream.mkv"
            )
        }
        defer { DebridManager.resetQAFixtureProvider() }

        let service = DebridManager.liveServiceFactory(type: .realDebrid, token: "ignored")
        await #expect(
            throws: DebridError.networkError("Invalid QA fixture URL")
        ) {
            _ = try await service.unrestrict(link: "")
        }
    }
}
