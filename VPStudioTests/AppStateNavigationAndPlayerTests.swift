import Foundation
import AVFoundation
import Testing
@testable import VPStudio

private func makeAppStatePlayerTestDatabase(named name: String) async throws -> DatabaseManager {
    let database = try DatabaseManager(inMemoryNamed: "\(name)-\(UUID().uuidString)")
    try await database.migrate()
    return database
}

private func makeAppStateManagedEnvironmentFile(
    directoryName: String,
    fileName: String,
    contents: Data = Data("hdr".utf8)
) throws -> (rootDir: URL, envDir: URL, fileURL: URL) {
    let rootDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(directoryName)-\(UUID().uuidString)", isDirectory: true)
    let envDir = rootDir.appendingPathComponent("env", isDirectory: true)
    try FileManager.default.createDirectory(at: envDir, withIntermediateDirectories: true)
    let fileURL = envDir.appendingPathComponent(fileName)
    try contents.write(to: fileURL)
    return (rootDir, envDir, fileURL)
}

private actor AppStateResumeDebridService: DebridServiceProtocol {
    let serviceType: DebridServiceType = .realDebrid

    private let stream: StreamInfo

    init(stream: StreamInfo) {
        self.stream = stream
    }

    func validateToken() async throws -> Bool { true }

    func getAccountInfo() async throws -> DebridAccountInfo {
        DebridAccountInfo(username: "resume-test", email: nil, premiumExpiry: nil, isPremium: true)
    }

    func checkCache(hashes: [String]) async throws -> [String: CacheStatus] {
        hashes.reduce(into: [String: CacheStatus]()) { result, hash in
            result[hash] = .cached(fileId: nil, fileName: stream.fileName, fileSize: stream.sizeBytes)
        }
    }

    func addMagnet(hash: String) async throws -> String {
        "torrent-\(hash)"
    }

    func selectFiles(torrentId: String, fileIds: [Int]) async throws {
        _ = torrentId
        _ = fileIds
    }

    func getStreamURL(torrentId: String) async throws -> StreamInfo {
        _ = torrentId
        return stream
    }

    func unrestrict(link: String) async throws -> URL {
        _ = link
        return stream.streamURL
    }
}

// MARK: - AppState Navigation State

@Suite("AppState - Navigation State", .serialized)
struct AppStateNavigationStateTests {

    @Test @MainActor
    func defaultTabIsDiscover() {
        let appState = AppState()
        #expect(appState.selectedTab == .discover)
    }

    @Test @MainActor
    func tabSelectionRoundTrips() {
        let appState = AppState()
        for tab in SidebarTab.allCases {
            appState.selectedTab = tab
            #expect(appState.selectedTab == tab)
        }
    }

    @Test @MainActor
    func isShowingSetupDefaultsFalse() {
        let appState = AppState()
        #expect(appState.isShowingSetup == false)
        #expect(appState.setupRecommendationNeeded == false)
    }
}

// MARK: - AppState Player Session State

@Suite("AppState - Player Session State", .serialized)
struct AppStatePlayerSessionStateTests {

    @Test @MainActor
    func activePlayerSessionIsNilByDefault() {
        let appState = AppState()
        #expect(appState.activePlayerSession == nil)
    }

    @Test @MainActor
    func activePlayerSessionCanBeSet() {
        let appState = AppState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        let preview = Fixtures.mediaPreview()
        let viewModel = DetailViewModel(appState: appState)
        let request = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)

        appState.activePlayerSession = request
        #expect(appState.activePlayerSession?.mediaId == request.mediaId)

        appState.activePlayerSession = nil
        #expect(appState.activePlayerSession == nil)
    }

    @Test @MainActor
    func fullscreenBySessionIDStartsEmpty() {
        let appState = AppState()
        #expect(appState.fullscreenBySessionID.isEmpty)
    }

    @Test @MainActor
    func fullscreenBySessionIDTracksMultipleSessions() {
        let appState = AppState()
        let id1 = UUID()
        let id2 = UUID()

        appState.fullscreenBySessionID[id1] = true
        appState.fullscreenBySessionID[id2] = false

        #expect(appState.fullscreenBySessionID[id1] == true)
        #expect(appState.fullscreenBySessionID[id2] == false)
        #expect(appState.fullscreenBySessionID.count == 2)
    }

    @Test @MainActor
    func isMainWindowSuppressedForPlayerDefaultsFalse() {
        let appState = AppState()
        #expect(appState.isMainWindowSuppressedForPlayer == false)
    }

    @Test @MainActor
    func isMainWindowSuppressedForPlayerCanBeToggled() {
        let appState = AppState()
        appState.isMainWindowSuppressedForPlayer = true
        #expect(appState.isMainWindowSuppressedForPlayer)
        appState.isMainWindowSuppressedForPlayer = false
        #expect(appState.isMainWindowSuppressedForPlayer == false)
    }

    @Test @MainActor
    func terminateActivePlayerSessionClearsMainWindowSuppression() {
        let appState = AppState()
        appState.isMainWindowSuppressedForPlayer = true

        appState.terminateActivePlayerSession()

        #expect(appState.isMainWindowSuppressedForPlayer == false)
    }

    @Test @MainActor
    func releasePlayerResourcesClearsSuppressedStateWhenActiveSessionAlreadyNil() {
        let appState = AppState()
        appState.isMainWindowSuppressedForPlayer = true
        appState.isImmersiveTransitionInFlight = true
        appState.shouldRestoreImmersiveAfterSuspension = true

        appState.releasePlayerResources(clearSession: true)

        #expect(appState.activePlayerSession == nil)
        #expect(appState.isMainWindowSuppressedForPlayer == false)
        #expect(!appState.isImmersiveTransitionInFlight)
        #expect(!appState.shouldRestoreImmersiveAfterSuspension)
    }

    @Test @MainActor
    func releasePlayerResourcesClearsPlaybackBridgeOnlyWhenRequested() {
        let appState = AppState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        let preview = Fixtures.mediaPreview()
        let viewModel = DetailViewModel(appState: appState)
        let request = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)
        let player = AVPlayer()
        let renderer = AVSampleBufferVideoRenderer()
        appState.activePlayerSession = request
        appState.fullscreenBySessionID[request.id] = true
        appState.activeAVPlayer = player
        appState.activeVideoRenderer = renderer

        appState.releasePlayerResources(clearSession: false, sessionID: request.id)

        #expect(appState.activeAVPlayer == nil)
        #expect(appState.activeVideoRenderer == nil)
        #expect(appState.activePlayerSession?.id == request.id)
        #expect(appState.fullscreenBySessionID[request.id] == true)
    }

    @Test @MainActor
    func releasePlayerResourcesClearsSessionAndFullscreenState() {
        let appState = AppState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        let preview = Fixtures.mediaPreview()
        let viewModel = DetailViewModel(appState: appState)
        let request = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)
        let player = AVPlayer()
        let renderer = AVSampleBufferVideoRenderer()
        appState.activePlayerSession = request
        appState.fullscreenBySessionID[request.id] = true
        appState.activeAVPlayer = player
        appState.activeVideoRenderer = renderer

        appState.releasePlayerResources(clearSession: true, sessionID: request.id)

        #expect(appState.activeAVPlayer == nil)
        #expect(appState.activeVideoRenderer == nil)
        #expect(appState.activePlayerSession == nil)
        #expect(appState.fullscreenBySessionID[request.id] == nil)
    }

    @Test @MainActor
    func releasePlayerResourcesForActivePlayerSessionPreservesSuppressionUntilWindowDisappears() {
        let appState = AppState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        let preview = Fixtures.mediaPreview()
        let viewModel = DetailViewModel(appState: appState)
        let request = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)

        appState.activePlayerSession = request
        appState.isMainWindowSuppressedForPlayer = true

        appState.releasePlayerResources(clearSession: true, sessionID: request.id)

        #expect(appState.activePlayerSession == nil)
        #expect(appState.isMainWindowSuppressedForPlayer)
    }

    @Test @MainActor
    func releasePlayerResourcesPreservesActiveSessionWhenSessionIDMismatches() {
        let appState = AppState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        let preview = Fixtures.mediaPreview()
        let viewModel = DetailViewModel(appState: appState)
        let activeSession = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)
        let staleSessionID = UUID()
        let activePlayer = AVPlayer()
        let activeRenderer = AVSampleBufferVideoRenderer()

        appState.activePlayerSession = activeSession
        appState.activeAVPlayer = activePlayer
        appState.activeVideoRenderer = activeRenderer
        appState.fullscreenBySessionID[activeSession.id] = true
        appState.fullscreenBySessionID[staleSessionID] = true
        appState.isMainWindowSuppressedForPlayer = true

        appState.releasePlayerResources(clearSession: true, sessionID: staleSessionID)

        #expect(appState.activePlayerSession?.id == activeSession.id)
        #expect(appState.activeAVPlayer === activePlayer)
        #expect(appState.activeVideoRenderer === activeRenderer)
        #expect(appState.fullscreenBySessionID[activeSession.id] == true)
        #expect(appState.fullscreenBySessionID[staleSessionID] == nil)
        #expect(appState.isMainWindowSuppressedForPlayer)
    }

    @Test @MainActor
    func beginEmbeddedPlayerSessionClearsStaleBridgeAndSuppressionBeforeOpening() {
        let appState = AppState()
        let stream = Fixtures.stream(fileName: "movie.mkv")
        let preview = Fixtures.mediaPreview()
        let viewModel = DetailViewModel(appState: appState)
        let request = viewModel.makePlayerSessionRequest(stream: stream, preview: preview)
        let stalePlayer = AVPlayer()
        let staleRenderer = AVSampleBufferVideoRenderer()

        appState.activeAVPlayer = stalePlayer
        appState.activeVideoRenderer = staleRenderer
        appState.isImmersiveTransitionInFlight = true
        appState.shouldRestoreImmersiveAfterSuspension = true
        appState.isMainWindowSuppressedForPlayer = true
        appState.didMainWindowDisappearForPlayer = true
        appState.didMainWindowReappearForPlayer = true

        appState.beginEmbeddedPlayerSession(request)

        #expect(appState.activePlayerSession?.id == request.id)
        #expect(appState.activeAVPlayer == nil)
        #expect(appState.activeVideoRenderer == nil)
        #expect(!appState.isImmersiveTransitionInFlight)
        #expect(!appState.shouldRestoreImmersiveAfterSuspension)
        #expect(!appState.isMainWindowSuppressedForPlayer)
        #expect(!appState.didMainWindowDisappearForPlayer)
        #expect(!appState.didMainWindowReappearForPlayer)
    }

    @Test @MainActor
    func mainWindowSuppressionOnlyTerminatesAfterMainWindowActuallyReappears() {
        let appState = AppState()
        let sessionID = UUID()

        appState.beginMainWindowSuppressionForPlayer(sessionID: sessionID)

        #expect(appState.isMainWindowSuppressedForPlayer)
        #expect(appState.mainWindowSuppressedPlayerSessionID == sessionID)
        #expect(!appState.didMainWindowDisappearForPlayer)
        #expect(!appState.didMainWindowReappearForPlayer)
        #expect(!appState.shouldTerminatePlayerForMainWindowActivation())

        appState.markMainWindowDidDisappearForPlayer()

        #expect(appState.didMainWindowDisappearForPlayer)
        #expect(!appState.didMainWindowReappearForPlayer)
        #expect(!appState.shouldTerminatePlayerForMainWindowActivation())

        appState.markMainWindowDidReappearForPlayer()

        #expect(appState.didMainWindowReappearForPlayer)
        #expect(appState.shouldTerminatePlayerForMainWindowActivation())
    }

    @Test @MainActor
    func mainWindowSuppressionClearIsScopedToOwningPlayerSession() {
        let appState = AppState()
        let ownerSessionID = UUID()

        appState.beginMainWindowSuppressionForPlayer(sessionID: ownerSessionID)
        appState.markMainWindowDidDisappearForPlayer()
        appState.markMainWindowDidReappearForPlayer()
        appState.clearMainWindowSuppressionForPlayer(sessionID: UUID())

        #expect(appState.isMainWindowSuppressedForPlayer)
        #expect(appState.didMainWindowDisappearForPlayer)
        #expect(appState.didMainWindowReappearForPlayer)
        #expect(appState.mainWindowSuppressedPlayerSessionID == ownerSessionID)

        appState.clearMainWindowSuppressionForPlayer(sessionID: ownerSessionID)

        #expect(!appState.isMainWindowSuppressedForPlayer)
        #expect(!appState.didMainWindowDisappearForPlayer)
        #expect(!appState.didMainWindowReappearForPlayer)
        #expect(appState.mainWindowSuppressedPlayerSessionID == nil)
    }

    @Test @MainActor
    func metadataEpisodeLookupIDPrefersStableProviderIdentifiersBeforeTitleFallback() {
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "series-imdb-tt0944947",
                previewId: "series-tmdb-1399",
                tmdbId: 1399
            ) == "tt0944947"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "tmdb-1399",
                previewId: "tt0944947",
                tmdbId: 1399
            ) == "tt0944947"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "legacy-local-id",
                previewId: nil,
                mediaTitle: " Legacy Show ",
                mediaYear: 2024,
                tmdbId: 1399
            ) == "tmdb-1399"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "legacy-local-id",
                previewId: nil,
                mediaTitle: " Legacy Show (2024) ",
                mediaYear: 2024,
                tmdbId: 1399
            ) == "tmdb-1399"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "legacy-local-id",
                previewId: nil,
                mediaTitle: " Doctor Who (2005) ",
                mediaYear: 1963,
                tmdbId: 1399
            ) == "tmdb-1399"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "legacy-local-id",
                previewId: nil,
                mediaTitle: " Legacy Show ",
                mediaYear: 999,
                tmdbId: 1399
            ) == "tmdb-1399"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "legacy-local-id",
                previewId: nil,
                mediaTitle: " Legacy Show ",
                mediaYear: nil,
                tmdbId: 1399
            ) == "tmdb-1399"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "legacy-local-id",
                previewId: nil,
                tmdbId: 1399
            ) == "tmdb-1399"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "legacy-local-id",
                previewId: nil,
                mediaTitle: " Legacy Show ",
                tmdbId: nil
            ) == "Legacy Show"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "legacy-local-id",
                previewId: nil,
                tmdbId: nil
            ) == "legacy-local-id"
        )
    }

    @Test @MainActor
    func metadataEpisodeLookupIDUsesOMDbCompatibleFallbackWhenTMDbIsUnavailable() {
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "series-imdb-tt0944947",
                previewId: "series-tmdb-1399",
                mediaTitle: "Game of Thrones",
                mediaYear: 2011,
                tmdbId: 1399,
                allowsTMDbIdentifier: false
            ) == "tt0944947"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "legacy-local-id",
                previewId: nil,
                mediaTitle: " Legacy Show ",
                mediaYear: 2024,
                tmdbId: 1399,
                allowsTMDbIdentifier: false
            ) == "Legacy Show (2024)"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "tmdb-1399",
                previewId: "legacy-local-id",
                mediaTitle: nil,
                mediaYear: nil,
                tmdbId: 1399,
                allowsTMDbIdentifier: false
            ) == "legacy-local-id"
        )
        #expect(
            AppState.metadataEpisodeLookupID(
                mediaId: "tmdb-1399",
                previewId: nil,
                mediaTitle: nil,
                mediaYear: nil,
                tmdbId: 1399,
                allowsTMDbIdentifier: false
            ) == nil
        )
    }

    @Test @MainActor
    func resolveContinueWatchingSessionCanonicalizesLegacyTMDBMediaIDThroughCachedOMDbAlias() async throws {
        let database = try await makeAppStatePlayerTestDatabase(named: "continue-watch-omdb-alias")
        let secretStore = TestSecretStore()
        let secretKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-resume")
        try await secretStore.setSecret("token", for: secretKey)
        try await database.saveDebridConfig(DebridConfig(
            id: "rd-resume",
            serviceType: .realDebrid,
            apiTokenRef: SecretReference.encode(key: secretKey),
            isActive: true,
            priority: 0,
            createdAt: Date(),
            updatedAt: Date()
        ))
        try await database.saveMediaItem(MediaItem(
            id: "tt1160419",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: "https://img.omdbapi.com/dune.jpg",
            backdropPath: nil,
            overview: nil,
            genres: [],
            imdbRating: 8.0,
            runtime: 155,
            status: nil,
            tmdbId: 438_631
        ))

        let stream = Fixtures.stream(
            url: "https://cdn.example.com/dune.mkv",
            fileName: "Dune.2021.2160p.mkv"
        )
        let debridManager = DebridManager(
            database: database,
            secretStore: secretStore,
            serviceFactory: { _, _ in AppStateResumeDebridService(stream: stream) }
        )
        let appState = AppState(
            database: database,
            secretStore: secretStore,
            debridManager: debridManager
        )
        let context = try #require(StreamRecoveryContext(
            infoHash: "abcdef1234567890abcdef1234567890abcdef12",
            preferredService: .realDebrid,
            resolvedDebridService: DebridServiceType.realDebrid.rawValue
        ))
        let contextJSON = String(data: try JSONEncoder().encode(context), encoding: .utf8)
        let history = WatchHistory(
            id: "history-1",
            mediaId: "movie-tmdb-438631",
            title: "Dune",
            progress: 120,
            duration: 9_300,
            recoveryContextJSON: contextJSON,
            watchedAt: Date(),
            isCompleted: false
        )
        let preview = MediaPreview(
            id: "movie-tmdb-438631",
            type: .movie,
            title: "Dune",
            year: 2021,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: 438_631
        )

        let request = try #require(await appState.resolveContinueWatchingSession(
            history: history,
            preview: preview
        ))

        #expect(request.mediaId == "movie-omdb-tt1160419")
        #expect(request.imdbId == "tt1160419")
        #expect(request.tmdbId == 438_631)
        #expect(request.stream.streamURL.absoluteString == "https://cdn.example.com/dune.mkv")
    }

    @Test @MainActor
    func resolveContinueWatchingSessionRejectsMissingLocalResolvedStream() async throws {
        let database = try await makeAppStatePlayerTestDatabase(named: "continue-watch-missing-local")
        let secretStore = TestSecretStore()
        let secretKey = SecretKey.debridToken(service: .realDebrid, configId: "rd-missing-local")
        try await secretStore.setSecret("token", for: secretKey)
        try await database.saveDebridConfig(DebridConfig(
            id: "rd-missing-local",
            serviceType: .realDebrid,
            apiTokenRef: SecretReference.encode(key: secretKey),
            isActive: true,
            priority: 0,
            createdAt: Date(),
            updatedAt: Date()
        ))

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("continue-watch-missing-local-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let missingFile = tempDir.appendingPathComponent("missing.mp4")
        let stream = Fixtures.stream(
            url: missingFile.absoluteString,
            fileName: "missing.mp4"
        )
        let debridManager = DebridManager(
            database: database,
            secretStore: secretStore,
            serviceFactory: { _, _ in AppStateResumeDebridService(stream: stream) }
        )
        let appState = AppState(
            database: database,
            secretStore: secretStore,
            debridManager: debridManager
        )
        let context = try #require(StreamRecoveryContext(
            infoHash: "1234567890abcdef1234567890abcdef12345678",
            preferredService: .realDebrid,
            resolvedDebridService: DebridServiceType.realDebrid.rawValue
        ))
        let history = WatchHistory(
            id: "missing-local-history",
            mediaId: "tt7654321",
            title: "Missing Local",
            progress: 120,
            duration: 7_200,
            recoveryContextJSON: String(data: try JSONEncoder().encode(context), encoding: .utf8),
            watchedAt: Date(),
            isCompleted: false
        )
        let preview = MediaPreview(
            id: "tt7654321",
            type: .movie,
            title: "Missing Local",
            year: 2026,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: nil
        )

        let request = await appState.resolveContinueWatchingSession(
            history: history,
            preview: preview
        )

        #expect(request == nil)
    }
}

// MARK: - AppState Immersive Dismiss Reason Coverage

@Suite("AppState - Immersive Dismiss Reasons", .serialized)
struct AppStateImmersiveDismissReasonTests {

    @Test @MainActor
    func userInitiatedDismissDoesNotQueueRestore() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .userInitiated)
        appState.immersiveSpaceDidDisappear()

        #expect(appState.consumeSuspendedImmersiveRestoreRequest() == false)
    }

    @Test @MainActor
    func switchingEnvironmentDismissDoesNotQueueRestore() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .switchingEnvironment)
        appState.immersiveSpaceDidDisappear()

        #expect(appState.consumeSuspendedImmersiveRestoreRequest() == false)
    }

    @Test @MainActor
    func playerClosedDismissDoesNotQueueRestore() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.customEnvironment)
        appState.stageImmersiveDismiss(reason: .playerClosed)
        appState.immersiveSpaceDidDisappear()

        #expect(appState.consumeSuspendedImmersiveRestoreRequest() == false)
    }

    @Test @MainActor
    func suspensionWhenSpaceNotOpenDoesNotQueueRestore() {
        let appState = AppState()
        // Space was never opened, so shouldRestore should remain false
        appState.stageImmersiveDismiss(reason: .suspension)
        appState.immersiveSpaceDidDisappear()

        #expect(appState.consumeSuspendedImmersiveRestoreRequest() == false)
    }

    @Test @MainActor
    func suspensionWhenTransitionInFlightQueuesRestore() {
        let appState = AppState()
        // Transition started but space not fully open yet
        #expect(appState.beginImmersiveTransition())
        appState.stageImmersiveDismiss(reason: .suspension)
        appState.immersiveSpaceDidDisappear()

        #expect(appState.consumeSuspendedImmersiveRestoreRequest())
    }

    @Test @MainActor
    func stageImmersiveDismissPreservesEnvironmentBeforeDisappear() {
        let appState = AppState()
        appState.immersiveSpaceDidAppear(.hdriSkybox)
        appState.stageImmersiveDismiss(reason: .suspension)

        // Before disappear, space should still be open
        #expect(appState.isImmersiveSpaceOpen)
        #expect(appState.activeEnvironment == .hdriSkybox)
    }
}

// MARK: - AppState Activate Environment Asset

@Suite("AppState - Activate Environment Asset", .serialized)
struct AppStateActivateEnvironmentAssetTests {

    @Test @MainActor
    func activateEnvironmentAssetUpdatesSelectedAssetAfterCatalogActivation() async throws {
        let database = try DatabaseManager(inMemoryNamed: "activate-environment-\(UUID().uuidString)")
        try await database.migrate()
        let settings = SettingsManager(database: database, secretStore: TestSecretStore())
        let environmentFile = try makeAppStateManagedEnvironmentFile(
            directoryName: "activate-environment",
            fileName: "test.hdr"
        )
        defer { try? FileManager.default.removeItem(at: environmentFile.rootDir) }
        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: environmentFile.envDir)
        let asset = EnvironmentAsset(
            id: "env-test",
            name: "Test Environment",
            sourceType: .imported,
            assetPath: environmentFile.fileURL.path,
            isActive: false
        )
        try await database.saveEnvironmentAsset(asset)

        let appState = AppState(
            database: database,
            settingsManager: settings,
            environmentCatalogManager: manager
        )
        let didActivate = await appState.activateEnvironmentAsset(asset)

        #expect(didActivate)
        #expect(appState.selectedEnvironmentAsset?.id == "env-test")
        #expect(appState.selectedEnvironmentAsset?.isActive == true)
        #expect(try await manager.activeAsset()?.id == "env-test")
        #expect(try await manager.activeAsset()?.isActive == true)
        #expect(try await database.getSetting(key: SettingsKeys.preferredEnvironment) == "env-test")
    }

    @Test @MainActor
    func activateEnvironmentAssetDoesNotDisplayStaleAssetWhenCatalogActivationFails() async throws {
        let database = try DatabaseManager(inMemoryNamed: "activate-stale-environment-\(UUID().uuidString)")
        try await database.migrate()
        let settings = SettingsManager(database: database, secretStore: TestSecretStore())
        let environmentFile = try makeAppStateManagedEnvironmentFile(
            directoryName: "activate-stale-environment",
            fileName: "active.hdr"
        )
        defer { try? FileManager.default.removeItem(at: environmentFile.rootDir) }
        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: environmentFile.envDir)
        let active = EnvironmentAsset(
            id: "active-env",
            name: "Active Environment",
            sourceType: .imported,
            assetPath: environmentFile.fileURL.path,
            isActive: false
        )
        let stale = EnvironmentAsset(
            id: "stale-env",
            name: "Deleted Environment",
            sourceType: .imported,
            assetPath: environmentFile.envDir.appendingPathComponent("stale.hdr").path,
            isActive: false
        )
        try await database.saveEnvironmentAsset(active)

        let appState = AppState(
            database: database,
            settingsManager: settings,
            environmentCatalogManager: manager
        )
        let didActivateCurrent = await appState.activateEnvironmentAsset(active)
        let didActivateStale = await appState.activateEnvironmentAsset(stale)

        #expect(didActivateCurrent)
        #expect(!didActivateStale)
        #expect(appState.selectedEnvironmentAsset?.id == "active-env")
        #expect(try await manager.activeAsset()?.id == "active-env")
        #expect(try await database.getSetting(key: SettingsKeys.preferredEnvironment) == "active-env")
    }

    @Test @MainActor
    func selectSuggestedEnvironmentAssetPersistsOnlyAfterCatalogActivation() async throws {
        let database = try DatabaseManager(inMemoryNamed: "suggested-environment-\(UUID().uuidString)")
        try await database.migrate()
        let settings = SettingsManager(database: database, secretStore: TestSecretStore())
        let environmentFiles = try makeAppStateManagedEnvironmentFile(
            directoryName: "suggested-environment",
            fileName: "active.hdr"
        )
        defer { try? FileManager.default.removeItem(at: environmentFiles.rootDir) }
        let suggestionFileURL = environmentFiles.envDir.appendingPathComponent("suggested.hdr")
        try Data("hdr".utf8).write(to: suggestionFileURL)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: environmentFiles.envDir
        )
        try await database.setSetting(key: SettingsKeys.preferredEnvironment, value: "manual-env")
        try await database.setSetting(key: SettingsKeys.activeEnvironmentSelectionCleared, value: "1")

        let active = EnvironmentAsset(
            id: "active-env",
            name: "Active Environment",
            sourceType: .imported,
            assetPath: environmentFiles.fileURL.path,
            isActive: false
        )
        let suggestion = EnvironmentAsset(
            id: "suggested-env",
            name: "Suggested Environment",
            sourceType: .imported,
            assetPath: suggestionFileURL.path,
            environmentTag: "horror",
            isActive: false
        )
        // Never persisted to the catalog: a suggestion the user has since removed
        // must not activate, leaving the current selection intact.
        let staleSuggestion = EnvironmentAsset(
            id: "missing-suggested-env",
            name: "Missing Suggested Environment",
            sourceType: .imported,
            assetPath: environmentFiles.envDir.appendingPathComponent("missing.hdr").path,
            environmentTag: "scifi",
            isActive: false
        )
        try await database.saveEnvironmentAsset(active)
        try await database.saveEnvironmentAsset(suggestion)

        let appState = AppState(
            database: database,
            settingsManager: settings,
            environmentCatalogManager: manager
        )
        let didActivateCurrent = await appState.activateEnvironmentAsset(active)
        let didActivateSuggestion = await appState.selectSuggestedEnvironmentAsset(suggestion)
        let didActivateStaleSuggestion = await appState.selectSuggestedEnvironmentAsset(staleSuggestion)

        #expect(didActivateCurrent)
        #expect(didActivateSuggestion)
        #expect(!didActivateStaleSuggestion)
        #expect(appState.selectedEnvironmentAsset?.id == "suggested-env")
        #expect(try await manager.activeAsset()?.id == "suggested-env")
        #expect(try await database.getSetting(key: SettingsKeys.preferredEnvironment) == "suggested-env")
        #expect(try await database.getSetting(key: SettingsKeys.activeEnvironmentSelectionCleared) == nil)
    }

    @Test @MainActor
    func reconcileEnvironmentSelectionRefreshesSelectedAssetFromLoadedCatalog() {
        let appState = AppState()
        appState.selectedEnvironmentAsset = EnvironmentAsset(
            id: "env-test",
            name: "Stale Name",
            sourceType: .imported,
            assetPath: "stale.hdr",
            isActive: true
        )

        appState.reconcileEnvironmentSelection(withLoadedAssets: [
            EnvironmentAsset(
                id: "env-test",
                name: "Loaded Name",
                sourceType: .imported,
                assetPath: "loaded.hdr",
                isActive: true
            ),
        ])

        #expect(appState.selectedEnvironmentAsset?.id == "env-test")
        #expect(appState.selectedEnvironmentAsset?.name == "Loaded Name")
        #expect(appState.selectedEnvironmentAsset?.assetPath == "loaded.hdr")
    }

    @Test @MainActor
    func reconcileEnvironmentSelectionDropsDeletedSelectionWithoutClearingActiveEnvironment() {
        let appState = AppState()
        appState.activeEnvironment = .customEnvironment
        appState.selectedEnvironmentAsset = EnvironmentAsset(
            id: "deleted-env",
            name: "Deleted Environment",
            sourceType: .imported,
            assetPath: "deleted.hdr",
            isActive: true
        )

        appState.reconcileEnvironmentSelection(withLoadedAssets: [
            EnvironmentAsset(
                id: "active-env",
                name: "Active Environment",
                sourceType: .imported,
                assetPath: "active.hdr",
                isActive: true
            ),
        ])

        #expect(appState.activeEnvironment == .customEnvironment)
        #expect(appState.selectedEnvironmentAsset?.id == "active-env")
    }

    @Test @MainActor
    func clearEnvironmentSelectionClearsSelectedAndActiveEnvironment() async {
        let appState = AppState()
        appState.activeEnvironment = .customEnvironment
        appState.selectedEnvironmentAsset = EnvironmentAsset(
            id: "env-test",
            name: "Test Environment",
            sourceType: .imported,
            assetPath: "test.hdr",
            isActive: true
        )

        await appState.clearEnvironmentSelection()

        #expect(appState.activeEnvironment == nil)
        #expect(appState.selectedEnvironmentAsset == nil)
    }

    @Test @MainActor
    func clearEnvironmentSelectionIfCurrentDoesNotWipeNewerSelection() async {
        let appState = AppState()
        appState.activeEnvironment = .customEnvironment
        appState.selectedEnvironmentAsset = EnvironmentAsset(
            id: "newer-env",
            name: "Newer Environment",
            sourceType: .imported,
            assetPath: "newer.hdr",
            isActive: true
        )

        await appState.clearEnvironmentSelectionIfCurrent(assetID: "stale-env")

        #expect(appState.activeEnvironment == .customEnvironment)
        #expect(appState.selectedEnvironmentAsset?.id == "newer-env")
    }

    @Test @MainActor
    func clearEnvironmentSelectionIfCurrentFallsBackToCatalogActiveAsset() async throws {
        let database = try DatabaseManager(inMemoryNamed: "clear-catalog-active-environment-\(UUID().uuidString)")
        try await database.migrate()
        let settings = SettingsManager(database: database, secretStore: TestSecretStore())
        let environmentFile = try makeAppStateManagedEnvironmentFile(
            directoryName: "clear-catalog-active-environment",
            fileName: "active.hdr"
        )
        defer { try? FileManager.default.removeItem(at: environmentFile.rootDir) }
        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: environmentFile.envDir)
        let asset = EnvironmentAsset(
            id: "catalog-active-env",
            name: "Catalog Active Environment",
            sourceType: .imported,
            assetPath: environmentFile.fileURL.path,
            isActive: false
        )
        try await database.saveEnvironmentAsset(asset)
        try await manager.activateAsset(id: asset.id)

        let appState = AppState(
            database: database,
            settingsManager: settings,
            environmentCatalogManager: manager
        )
        appState.activeEnvironment = .customEnvironment
        appState.selectedEnvironmentAsset = nil

        await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)

        #expect(appState.activeEnvironment == nil)
        #expect(appState.selectedEnvironmentAsset == nil)
        #expect(try await manager.activeAsset() == nil)
        #expect(try await database.getSetting(key: SettingsKeys.activeEnvironmentSelectionCleared) == "1")
    }
}

// MARK: - AppState Reload Indexers Failure

@Suite("AppState - Reload Indexers Failure", .serialized)
struct AppStateReloadIndexersFailureTests {

    @Test @MainActor
    func reloadIndexersSwallowsErrorSilently() async {
        struct HookError: Error {}
        let appState = AppState(
            testHooks: .init(
                initializeIndexers: { throw HookError() }
            )
        )

        // Should not throw — errors are swallowed
        await appState.reloadIndexers()
        // If we reach here, the error was handled silently
        #expect(Bool(true))
    }

    @Test @MainActor
    func reloadIndexersDoesNotPostNotificationOnFailure() async {
        struct HookError: Error {}
        final class NotificationFlag: @unchecked Sendable {
            private let lock = NSLock()
            private var value = false

            func markPosted() {
                lock.lock()
                value = true
                lock.unlock()
            }

            func wasPosted() -> Bool {
                lock.lock()
                defer { lock.unlock() }
                return value
            }
        }

        let didPost = NotificationFlag()
        let token = NotificationCenter.default.addObserver(
            forName: .indexersDidChange,
            object: nil,
            queue: nil
        ) { _ in
            didPost.markPosted()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let appState = AppState(
            testHooks: .init(
                initializeIndexers: { throw HookError() }
            )
        )

        await appState.reloadIndexers()
        #expect(didPost.wasPosted() == false)
    }
}
