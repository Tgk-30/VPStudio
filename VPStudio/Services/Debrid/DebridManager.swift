import Foundation
import os

typealias DebridServiceFactory = @Sendable (DebridServiceType, String) -> any DebridServiceProtocol

private final class QADebridFixtureProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var provider: @Sendable () -> QADebridFixture? = QADebridFixtureProvider.defaultFixtureProvider

    func currentFixture() -> QADebridFixture? {
        lock.lock()
        defer { lock.unlock() }
        return provider()
    }

    func setFixtureProvider(_ next: @escaping @Sendable () -> QADebridFixture?) {
        lock.lock()
        provider = next
        lock.unlock()
    }

    func resetFixtureProvider() {
        lock.lock()
        provider = QADebridFixtureProvider.defaultFixtureProvider
        lock.unlock()
    }

    private static func defaultFixtureProvider() -> QADebridFixture? {
        QARuntimeOptions.debridFixture
    }
}

actor QADebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType

    private let fixture: QADebridFixture
    private var torrentHashesByID: [String: String] = [:]
    private var streamRequestCountsByHash: [String: Int] = [:]

    init(fixture: QADebridFixture) {
        self.serviceType = fixture.serviceType
        self.fixture = fixture
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "qa-fixture", email: nil, premiumExpiry: nil, isPremium: true)
    }

    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        hashes.reduce(into: [String: CacheStatus]()) { result, hash in
            let normalizedHash = DebridHashValidator.normalizedInfoHash(hash)
            let lookupKey = normalizedHash ?? hash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalizedHash == fixture.hash {
                result[lookupKey] = .cached(fileId: nil, fileName: fixture.fileName, fileSize: nil)
            } else {
                result[lookupKey] = .notCached
            }
        }
    }

    func addMagnet(hash: String) async throws -> String {
        let normalizedHash = try DebridHashValidator.validatedInfoHash(hash)
        guard normalizedHash == fixture.hash else { throw DebridError.invalidHash(hash) }

        let torrentId = "qa-\(normalizedHash)"
        torrentHashesByID[torrentId] = normalizedHash
        return torrentId
    }

    func selectFiles(torrentId: String, fileIds: [Int]) async throws {}

    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        guard let hash = torrentHashesByID[torrentId], hash == fixture.hash else {
            throw DebridError.torrentNotFound(torrentId)
        }

        let requestCount = streamRequestCountsByHash[hash, default: 0]
        streamRequestCountsByHash[hash] = requestCount + 1
        let streamURL = fixture.streamURLs[min(requestCount, fixture.streamURLs.count - 1)]
        let fileName = fixture.fileName

        return StreamInfo(
            streamURL: streamURL,
            quality: VideoQuality.parse(from: fileName),
            codec: VideoCodec.parse(from: fileName),
            audio: AudioFormat.parse(from: fileName),
            source: SourceType.parse(from: fileName),
            hdr: HDRFormat.parse(from: fileName),
            fileName: fileName,
            sizeBytes: nil,
            debridService: serviceType.rawValue
        )
    }

    func unrestrict(link: String) async throws -> URL {
        guard let url = URL(string: link) else {
            throw DebridError.networkError("Invalid QA fixture URL")
        }
        return url
    }
}

actor DebridManager {
    private static let logger = Logger(subsystem: "com.vpstudio", category: "debrid-manager")
    private static let qaDebridFixtureProvider = QADebridFixtureProvider()
    private let database: DatabaseManager
    private let secretStore: any SecretStore
    private let serviceFactory: DebridServiceFactory
    private let resolveStreamMaxAttempts: Int
    private let resolveStreamInitialDelayNanoseconds: UInt64
    private let resolveStreamMaxDelayNanoseconds: UInt64
    private var services: [DebridServiceType: any DebridServiceProtocol] = [:]
    private var servicePriority: [DebridServiceType: Int] = [:]
    private var hasInitialized = false

    init(
        database: DatabaseManager,
        secretStore: any SecretStore,
        serviceFactory: @escaping DebridServiceFactory = DebridManager.liveServiceFactory,
        resolveStreamMaxAttempts: Int = 30,
        resolveStreamInitialDelayNanoseconds: UInt64 = 500_000_000,
        resolveStreamMaxDelayNanoseconds: UInt64 = 5_000_000_000
    ) {
        self.database = database
        self.secretStore = secretStore
        self.serviceFactory = serviceFactory
        self.resolveStreamMaxAttempts = max(1, resolveStreamMaxAttempts)
        self.resolveStreamInitialDelayNanoseconds = resolveStreamInitialDelayNanoseconds
        self.resolveStreamMaxDelayNanoseconds = resolveStreamMaxDelayNanoseconds
    }

    func initialize() async throws {
        var newServices: [DebridServiceType: any DebridServiceProtocol] = [:]
        var newPriority: [DebridServiceType: Int] = [:]

        let configs = try await database.fetchDebridConfigs()
        for config in configs {
            guard config.supportsSharedMagnetResolveFlow else { continue }
            do {
                guard let token = try await resolveToken(for: config) else { continue }
                let service = serviceFactory(config.serviceType, token)
                newServices[config.serviceType] = service
                newPriority[config.serviceType] = config.priority
            } catch {
                Self.logger.error("Failed to initialize \(config.serviceType.rawValue, privacy: .public) debrid service: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Swap atomically after all configs are resolved successfully.
        services = newServices
        servicePriority = newPriority
        hasInitialized = true
    }

    func getService(_ type: DebridServiceType) -> (any DebridServiceProtocol)? {
        services[type]
    }

    func availableServices() -> [DebridServiceType] {
        Array(services.keys).sorted { $0.rawValue < $1.rawValue }
    }

    func checkCacheAcrossServices(hashes: [String]) async throws -> [String: (CacheStatus, DebridServiceType)] {
        try await ensureServicesInitializedIfNeeded()

        let normalizedHashes = Self.normalizedCacheHashes(
            hashes.compactMap(DebridHashValidator.normalizedInfoHash)
        )
        let orderedServices = orderedServiceTypes()
        guard !orderedServices.isEmpty else { return [:] }
        let cacheBatchSize = 48

        var results: [String: (CacheStatus, DebridServiceType)] = [:]
        var pendingHashes = Set(normalizedHashes)
        var successfulChecks = 0
        var firstFailure: Error?
        var firstSuccessfulService: DebridServiceType?

        for serviceType in orderedServices {
            guard let service = services[serviceType] else { continue }
            guard !pendingHashes.isEmpty else { break }

            let hashesToCheck = normalizedHashes.filter { pendingHashes.contains($0) }
            for batch in Self.chunked(hashesToCheck, size: cacheBatchSize) {
                do {
                    let cacheResult = try await service.checkCache(hashes: batch)
                    successfulChecks += 1
                    firstSuccessfulService = firstSuccessfulService ?? serviceType

                    for (hash, status) in cacheResult {
                        let normalizedResultHash = DebridHashValidator.normalizedInfoHash(hash)
                            ?? hash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                        guard pendingHashes.contains(normalizedResultHash) else {
                            continue
                        }

                        if case .cached = status {
                            results[normalizedResultHash] = (status, serviceType)
                            pendingHashes.remove(normalizedResultHash)
                        }
                    }
                } catch {
                    firstFailure = firstFailure ?? error
                    Self.logger.error("Cache check failed for \(serviceType.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        if successfulChecks == 0, let firstFailure {
            throw firstFailure
        }

        let fallback = cacheFallbackService(
            firstSuccessfulService: firstSuccessfulService,
            orderedServices: orderedServices,
            firstFailure: firstFailure
        )
        let fallbackService = fallback.service
        let unresolvedStatus = fallback.status
        for hash in normalizedHashes where results[hash] == nil {
            results[hash] = (unresolvedStatus, fallbackService)
        }

        return results
    }

    func resolveStream(
        hash: String,
        preferredService: DebridServiceType? = nil,
        magnetURI: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil
    ) async throws -> StreamInfo {
        return try await resolveStream(
            hash: hash,
            preferredService: preferredService,
            magnetURI: magnetURI,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            resolvedFileNameHint: nil,
            resolvedFileSizeHint: nil
        )
    }

    func resolveStream(from context: StreamRecoveryContext) async throws -> StreamInfo {
        try await ensureServicesInitializedIfNeeded()
        await cleanupRemoteTransfer(using: context)
        let preferredService = context.resolvedDebridService
            .flatMap(DebridServiceType.init(rawValue:))
            ?? context.preferredService
        return try await resolveStream(
            hash: context.infoHash,
            preferredService: preferredService,
            magnetURI: context.magnetURI,
            seasonNumber: context.seasonNumber,
            episodeNumber: context.episodeNumber,
            resolvedFileNameHint: context.resolvedFileName,
            resolvedFileSizeHint: context.resolvedFileSizeBytes
        )
    }

    func unrestrict(link: String, serviceType: DebridServiceType) async throws -> StreamInfo {
        try await ensureServicesInitializedIfNeeded()
        guard let service = services[serviceType] else {
            throw DebridError.networkError("\(serviceType.displayName) is not configured. Add it in Settings > Debrid Services.")
        }

        let streamURL = try DebridRemoteStreamURLPolicy.validatedURL(
            try await service.unrestrict(link: link),
            errorMessage: "Invalid unrestrict URL"
        )
        let fileName = Self.fileName(for: streamURL, fallbackLink: link)
        return StreamInfo(
            streamURL: streamURL,
            quality: VideoQuality.parse(from: fileName),
            codec: VideoCodec.parse(from: fileName),
            audio: AudioFormat.parse(from: fileName),
            source: SourceType.parse(from: fileName),
            hdr: HDRFormat.parse(from: fileName),
            fileName: fileName,
            sizeBytes: nil,
            debridService: serviceType.rawValue
        )
    }

    func cacheFallbackService(
        firstSuccessfulService: DebridServiceType?,
        orderedServices: [DebridServiceType],
        firstFailure: Error?
    ) -> (service: DebridServiceType, status: CacheStatus) {
        let fallbackService: DebridServiceType
        if let firstSuccessfulService {
            fallbackService = firstSuccessfulService
        } else if let firstOrderedService = orderedServices.first {
            fallbackService = firstOrderedService
        } else {
            fallbackService = .realDebrid
        }
        let unresolvedStatus: CacheStatus = firstFailure == nil ? .notCached : .unknown
        return (service: fallbackService, status: unresolvedStatus)
    }

    private func resolveStream(
        hash: String,
        preferredService: DebridServiceType? = nil,
        magnetURI: String?,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> StreamInfo {
        try await ensureServicesInitializedIfNeeded()

        let candidateServices = orderedServiceTypes(preferredService: preferredService)
        guard !candidateServices.isEmpty else {
            throw DebridError.networkError("No debrid services configured. Add one in Settings > Debrid Services.")
        }

        return try await resolveStreamForServices(
            hash: hash,
            candidateServices: candidateServices,
            magnetURI: magnetURI,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            resolvedFileNameHint: resolvedFileNameHint,
            resolvedFileSizeHint: resolvedFileSizeHint
        )
    }

    private func resolveStreamForServices(
        hash: String,
        candidateServices: [DebridServiceType],
        magnetURI: String?,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        resolvedFileNameHint: String? = nil,
        resolvedFileSizeHint: Int64? = nil
    ) async throws -> StreamInfo {
        guard !candidateServices.isEmpty else {
            throw DebridError.networkError("No debrid services configured. Add one in Settings > Debrid Services.")
        }

        var firstFailure: Error?
        for serviceType in candidateServices {
            guard let service = services[serviceType] else { continue }

            do {
                return try await resolveStream(
                    using: service,
                    hash: hash,
                    magnetURI: magnetURI,
                    seasonNumber: seasonNumber,
                    episodeNumber: episodeNumber,
                    resolvedFileNameHint: resolvedFileNameHint,
                    resolvedFileSizeHint: resolvedFileSizeHint
                )
            } catch {
                if !shouldFailover(from: error) {
                    throw error
                }

                firstFailure = firstFailure ?? error
                Self.logger.error("Stream resolve failed for \(serviceType.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        if let firstFailure {
            throw firstFailure
        }

        throw DebridError.networkError("No debrid services configured. Add one in Settings > Debrid Services.")
    }

#if DEBUG
    func _testCacheFallbackService(
        firstSuccessfulService: DebridServiceType? = nil,
        orderedServices: [DebridServiceType],
        hasFirstFailure: Bool = false
    ) -> (service: DebridServiceType, status: CacheStatus) {
        cacheFallbackService(
            firstSuccessfulService: firstSuccessfulService,
            orderedServices: orderedServices,
            firstFailure: hasFirstFailure ? DebridError.networkError("test") : nil
        )
    }

    func _testResolveStreamForServices(
        hash: String,
        candidateServices: [DebridServiceType],
        magnetURI: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        resolvedFileNameHint: String? = nil,
        resolvedFileSizeHint: Int64? = nil
    ) async throws -> StreamInfo {
        try await resolveStreamForServices(
            hash: hash,
            candidateServices: candidateServices,
            magnetURI: magnetURI,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            resolvedFileNameHint: resolvedFileNameHint,
            resolvedFileSizeHint: resolvedFileSizeHint
        )
    }
#endif

    private func resolveStream(
        using service: any DebridServiceProtocol,
        hash: String,
        magnetURI: String?,
        seasonNumber: Int?,
        episodeNumber: Int?,
        resolvedFileNameHint: String?,
        resolvedFileSizeHint: Int64?
    ) async throws -> StreamInfo {
        let sanitizedMagnetURI = try DebridManager.sanitizedMagnetURI(hash: hash, magnetURI: magnetURI)
        let torrentId = try await service.addMagnet(hash: hash, magnetURI: sanitizedMagnetURI)
        do {
            if let seasonNumber, let episodeNumber {
                let selectedEpisodeFile = try await service.selectMatchingEpisodeFile(
                    torrentId: torrentId,
                    seasonNumber: seasonNumber,
                    episodeNumber: episodeNumber,
                    resolvedFileNameHint: resolvedFileNameHint,
                    resolvedFileSizeHint: resolvedFileSizeHint
                )

                if !selectedEpisodeFile {
                    throw DebridError.networkError("Could not deterministically select the requested episode file.")
                }
            } else {
                try await service.selectFiles(torrentId: torrentId, fileIds: [])
            }

            // Poll for completion with exponential backoff
            var delay = resolveStreamInitialDelayNanoseconds
            let maxAttempts = resolveStreamMaxAttempts
            let maxDelay = resolveStreamMaxDelayNanoseconds
            for attempt in 0..<maxAttempts {
                try Task.checkCancellation()
                do {
                    let stream = try Self.validatedRemoteStream(
                        try await service.getStreamURL(torrentId: torrentId),
                        errorMessage: "Invalid stream URL"
                    )
                    return stream.withRecoveryContext(
                        StreamRecoveryContext(
                            infoHash: hash,
                            preferredService: service.serviceType,
                            magnetURI: magnetURI,
                            seasonNumber: seasonNumber,
                            episodeNumber: episodeNumber,
                            torrentId: torrentId,
                            resolvedDebridService: service.serviceType.rawValue,
                            resolvedFileName: stream.fileName,
                            resolvedFileSizeBytes: stream.sizeBytes
                        )
                    )
                } catch DebridError.fileNotReady {
                    if attempt < maxAttempts - 1 {
                        try await Task.sleep(nanoseconds: delay)
                        delay = min(delay * 2, maxDelay)
                    }
                }
            }

            throw DebridError.timeout
        } catch {
            await cleanupRemoteTransfer(
                torrentId: torrentId,
                on: service,
                serviceType: service.serviceType,
                reason: error
            )
            throw error
        }
    }

    func cleanupRemoteTransfer(from context: StreamRecoveryContext) async {
        do {
            try await ensureServicesInitializedIfNeeded()
        } catch {
            return
        }
        await cleanupRemoteTransfer(using: context)
    }

    private func resolveToken(for config: DebridConfig) async throws -> String? {
        let storedRef = config.apiTokenRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !storedRef.isEmpty else {
            return nil
        }

        if let secretKey = SecretReference.decode(storedRef) {
            return try await secretStore.getSecret(for: secretKey)
        }

        let migratedSecretKey = SecretKey.debridToken(service: config.serviceType, configId: config.id)
        try await secretStore.setSecret(storedRef, for: migratedSecretKey)

        let migratedConfig = DebridConfig(
            id: config.id,
            serviceType: config.serviceType,
            apiTokenRef: SecretReference.encode(key: migratedSecretKey),
            isActive: config.isActive,
            priority: config.priority,
            createdAt: config.createdAt,
            updatedAt: Date()
        )
        try await database.saveDebridConfig(migratedConfig)
        return storedRef
    }

    private func ensureServicesInitializedIfNeeded() async throws {
        if !hasInitialized {
            try await initialize()
        }
    }

    private func cleanupRemoteTransfer(using context: StreamRecoveryContext) async {
        guard let torrentId = context.torrentId else { return }

        let resolvedServiceType = context.resolvedDebridService
            .flatMap(DebridServiceType.init(rawValue:))
        let preferredServiceType = context.preferredService

        let serviceType = if let resolvedServiceType, services[resolvedServiceType] != nil {
            resolvedServiceType
        } else if let preferredServiceType, services[preferredServiceType] != nil {
            preferredServiceType
        } else {
            orderedServiceTypes().first
        }

        guard let serviceType else { return }
        guard let service = services[serviceType] else { return }
        await cleanupRemoteTransfer(torrentId: torrentId, on: service, serviceType: serviceType, reason: nil)
    }

    private func cleanupRemoteTransfer(
        torrentId: String,
        on service: any DebridServiceProtocol,
        serviceType: DebridServiceType,
        reason: Error?
    ) async {
        do {
            try await service.cleanupRemoteTransfer(torrentId: torrentId)
        } catch {
            if let reason {
                Self.logger.error("Remote cleanup failed for \(serviceType.rawValue, privacy: .public) after \(reason.localizedDescription, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                Self.logger.error("Remote cleanup failed for \(serviceType.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func orderedServiceTypes(preferredService: DebridServiceType? = nil) -> [DebridServiceType] {
        var ordered: [DebridServiceType] = []
        for serviceType in services.keys {
            let serviceTypePriority = servicePriority[serviceType] ?? Int.max
            var insertionIndex = ordered.count
            var index = 0

            while index < ordered.count {
                let other = ordered[index]
                let otherPriority = servicePriority[other] ?? Int.max

                if serviceTypePriority < otherPriority {
                    insertionIndex = index
                    break
                }

                if serviceTypePriority == otherPriority && serviceType.rawValue < other.rawValue {
                    insertionIndex = index
                    break
                }

                index += 1
            }

            ordered.insert(serviceType, at: insertionIndex)
        }

        if let preferredService, let preferredIndex = ordered.firstIndex(of: preferredService) {
            ordered.remove(at: preferredIndex)
            ordered.insert(preferredService, at: 0)
        }

        return ordered
    }

    internal static func normalizedCacheHashes(_ hashes: [String]) -> [String] {
        var orderedHashes: [String] = []
        var seen: Set<String> = []

        for hash in hashes {
            let normalized = hash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            orderedHashes.append(normalized)
        }

        return orderedHashes
    }

    internal static func chunked(_ hashes: [String], size: Int) -> [[String]] {
        guard size > 0, !hashes.isEmpty else { return [] }

        var batches: [[String]] = []
        batches.reserveCapacity((hashes.count + size - 1) / size)

        var start = 0
        while start < hashes.count {
            let end = min(start + size, hashes.count)
            batches.append(Array(hashes[start..<end]))
            start = end
        }

        return batches
    }

    private static func fileName(for url: URL, fallbackLink: String) -> String {
        let streamPathName = url.lastPathComponent
        if let decodedStreamPathName = streamPathName.removingPercentEncoding,
           !decodedStreamPathName.isEmpty,
           decodedStreamPathName != "/" {
            return decodedStreamPathName
        }
        if !streamPathName.isEmpty, streamPathName != "/" {
            return streamPathName
        }

        if let fallbackURL = URL(string: fallbackLink) {
            let fallbackPathName = fallbackURL.lastPathComponent
            if let decodedFallbackPathName = fallbackPathName.removingPercentEncoding,
               !decodedFallbackPathName.isEmpty,
               decodedFallbackPathName != "/" {
                return decodedFallbackPathName
            }
            if !fallbackPathName.isEmpty, fallbackPathName != "/" {
                return fallbackPathName
            }
        }

        return "Unknown"
    }

    private static func sanitizedMagnetURI(hash: String, magnetURI: String?) throws -> String? {
        guard let magnetURI else { return nil }
        return try DebridMagnetInput.preferredMagnetURI(hash: hash, suppliedMagnetURI: magnetURI)
    }

    private static func validatedRemoteStream(_ stream: StreamInfo, errorMessage: String) throws -> StreamInfo {
        let url = try DebridRemoteStreamURLPolicy.validatedURL(stream.streamURL, errorMessage: errorMessage)
        return stream.withStreamURL(url)
    }

    private func shouldFailover(from error: Error) -> Bool {
        if error is CancellationError {
            return false
        }

        if let debridError = error as? DebridError {
            switch debridError {
            case .invalidHash:
                return false
            default:
                return true
            }
        }
        return true
    }

    internal static func setQAFixtureProvider(_ provider: @escaping @Sendable () -> QADebridFixture?) {
        qaDebridFixtureProvider.setFixtureProvider(provider)
    }

    internal static func resetQAFixtureProvider() {
        qaDebridFixtureProvider.resetFixtureProvider()
    }

    static func liveServiceFactory(type: DebridServiceType, token: String) -> any DebridServiceProtocol {
        if let fixture = qaDebridFixtureProvider.currentFixture(),
           fixture.serviceType == type {
            return QADebridService(fixture: fixture)
        }

        switch type {
        case .realDebrid:
            return RealDebridService(apiToken: token)
        case .allDebrid:
            return AllDebridService(apiToken: token)
        case .premiumize:
            return PremiumizeService(apiToken: token)
        case .torBox:
            return TorBoxService(apiToken: token)
        case .debridLink:
            return DebridLinkService(apiToken: token)
        case .offcloud:
            return OffcloudService(apiToken: token)
        case .easyNews:
            return EasyNewsService(apiToken: token)
        }
    }
}
