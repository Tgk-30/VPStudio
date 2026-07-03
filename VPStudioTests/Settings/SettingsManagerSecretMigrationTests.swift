import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct SettingsManagerSecretMigrationTests {
    enum FailingSecretDeletionError: Error, Equatable {
        case deleteFailed
    }

    private actor FailingDeleteSecretStore: SecretStore {
        private var values: [String: String] = [:]

        func setSecret(_ secret: String, for key: String) async throws {
            values[key] = secret
        }

        func getSecret(for key: String) async throws -> String? {
            values[key]
        }

        func deleteSecret(for key: String) async throws {
            throw FailingSecretDeletionError.deleteFailed
        }

        func deleteAllSecrets() async throws {
            values.removeAll()
        }
    }

    struct CaseData: Sendable {
        let key: String
        let value: String
        let shouldStoreAsSecret: Bool
    }

    private static let knownSecretKeys: [String] = [
        SettingsKeys.omdbApiKey,
        SettingsKeys.tmdbApiKey,
        SettingsKeys.openSubtitlesApiKey,
        SettingsKeys.openAIApiKey,
        SettingsKeys.anthropicApiKey,
        SettingsKeys.openRouterApiKey,
        SettingsKeys.geminiApiKey,
        SettingsKeys.mistralApiKey,
        SettingsKeys.minimaxApiKey,
        SettingsKeys.traktClientId,
        SettingsKeys.traktClientSecret,
        SettingsKeys.traktAccessToken,
        SettingsKeys.traktRefreshToken,
        SettingsKeys.simklClientId,
        SettingsKeys.simklAccessToken,
        SettingsKeys.simklRefreshToken,
    ]

    private static let nonSecretKeys: [String] = [
        SettingsKeys.preferredQuality,
        SettingsKeys.subtitleLanguage,
        SettingsKeys.subtitleFontSize,
        SettingsKeys.subtitleAutoSearch,
        SettingsKeys.autoPlayNext,
        SettingsKeys.hardwareDecoding,
        SettingsKeys.playerEngineStrategy,
        SettingsKeys.externalPlayerApp,
        SettingsKeys.externalPlayerURLTemplate,
        SettingsKeys.preferCachedStreams,
        SettingsKeys.preferAtmosAudio,
        SettingsKeys.preferredHDRFormat,
        SettingsKeys.defaultDebridService,
        SettingsKeys.defaultAIProvider,
        SettingsKeys.aiCompareMode,
        SettingsKeys.ollamaEndpoint,
        SettingsKeys.ollamaModelPreset,
        SettingsKeys.personalizationEnabled,
        SettingsKeys.preferredEnvironment,
        SettingsKeys.feedbackScaleMode,
        SettingsKeys.runtimeDiagnosticsEnabled,
        SettingsKeys.traktAutoScrobble,
        SettingsKeys.traktSyncWatchlist,
        SettingsKeys.traktSyncHistory,
    ]

    private static let migrationCases: [CaseData] = {
        let secretCases = knownSecretKeys.prefix(32).enumerated().map { idx, key in
            CaseData(key: key, value: "legacy-secret-\(idx)", shouldStoreAsSecret: true)
        }
        let nonSecretCases = nonSecretKeys.prefix(32).enumerated().map { idx, key in
            CaseData(key: key, value: "plain-\(idx)", shouldStoreAsSecret: false)
        }
        return Array(secretCases + nonSecretCases)
    }()

    struct BoolCase: Sendable {
        let storedValue: String?
        let defaultValue: Bool
        let expected: Bool
    }

    private static let boolCases: [BoolCase] = [
        BoolCase(storedValue: nil, defaultValue: true, expected: true),
        BoolCase(storedValue: nil, defaultValue: false, expected: false),
        BoolCase(storedValue: "1", defaultValue: false, expected: true),
        BoolCase(storedValue: "0", defaultValue: true, expected: false),
        BoolCase(storedValue: "true", defaultValue: false, expected: true),
        BoolCase(storedValue: "TRUE", defaultValue: false, expected: true),
        BoolCase(storedValue: "false", defaultValue: true, expected: false),
        BoolCase(storedValue: "FaLsE", defaultValue: true, expected: false),
        BoolCase(storedValue: "yes", defaultValue: true, expected: false),
        BoolCase(storedValue: "no", defaultValue: true, expected: false),
        BoolCase(storedValue: " 1 ", defaultValue: false, expected: false),
        BoolCase(storedValue: "", defaultValue: true, expected: false),
        BoolCase(storedValue: "random", defaultValue: true, expected: false),
        BoolCase(storedValue: "TRUE ", defaultValue: false, expected: false),
        BoolCase(storedValue: " false", defaultValue: true, expected: false),
        BoolCase(storedValue: "tRuE", defaultValue: false, expected: true),
        BoolCase(storedValue: "2", defaultValue: false, expected: false),
        BoolCase(storedValue: "-1", defaultValue: true, expected: false),
        BoolCase(storedValue: "on", defaultValue: false, expected: false),
        BoolCase(storedValue: "off", defaultValue: true, expected: false),
    ]

    private func withTempSettingsEnvironment<T>(
        databaseName: String,
        _ body: (DatabaseManager, TestSecretStore, SettingsManager) async throws -> T
    ) async throws -> T {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let result: T = try await {
            let database = try DatabaseManager(inMemoryNamed: "\(databaseName)-\(UUID().uuidString)")
            try await database.migrate()
            let secretStore = TestSecretStore()
            let manager = SettingsManager(database: database, secretStore: secretStore)
            return try await body(database, secretStore, manager)
        }()

        try? FileManager.default.removeItem(at: tempDir)
        return result
    }

    @Test(arguments: ExhaustiveMode.choose(fast: Array(migrationCases.prefix(20)), full: migrationCases))
    func secretMigrationAndRetrieval(data: CaseData) async throws {
        try await withTempSettingsEnvironment(databaseName: "settings.sqlite") { database, secretStore, manager in
            try await database.setSetting(key: data.key, value: data.value)

            let fetched = try await manager.getString(key: data.key)
            #expect(fetched == data.value)

            let stored = try await database.getSetting(key: data.key)
            if data.shouldStoreAsSecret {
                #expect(stored?.hasPrefix(SecretReference.keychainPrefix) == true)
                let secret = try await secretStore.getSecret(for: SecretKey.setting(data.key))
                #expect(secret == data.value)
            } else {
                #expect(stored == data.value)
            }
        }
    }

    @Test(arguments: boolCases)
    func boolParsingBoundaries(data: BoolCase) async throws {
        try await withTempSettingsEnvironment(databaseName: "settings-bool.sqlite") { database, _, manager in
            try await database.setSetting(key: SettingsKeys.personalizationEnabled, value: data.storedValue)
            let parsed = try await manager.getBool(key: SettingsKeys.personalizationEnabled, default: data.defaultValue)
            #expect(parsed == data.expected)
        }
    }

    @Test
    func settingSecretTrimsWhitespaceBeforePersisting() async throws {
        try await withTempSettingsEnvironment(databaseName: "settings-trim.sqlite") { _, secretStore, manager in
            try await manager.setString(key: SettingsKeys.omdbApiKey, value: "  token-value  ")

            let persisted = try await manager.getString(key: SettingsKeys.omdbApiKey)
            let storedSecret = try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.omdbApiKey))
            #expect(persisted == "token-value")
            #expect(storedSecret == "token-value")
        }
    }

    @Test
    func settingSecretWhitespaceOnlyClearsStoredSecret() async throws {
        try await withTempSettingsEnvironment(databaseName: "settings-trim-clear.sqlite") { database, secretStore, manager in
            try await manager.setString(key: SettingsKeys.omdbApiKey, value: "token")
            try await manager.setString(key: SettingsKeys.omdbApiKey, value: "   ")

            let persisted = try await manager.getString(key: SettingsKeys.omdbApiKey)
            let raw = try await database.getSetting(key: SettingsKeys.omdbApiKey)
            let storedSecret = try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.omdbApiKey))

            #expect(persisted == nil)
            #expect(raw == nil)
            #expect(storedSecret == nil)
        }
    }

    @Test
    func clearingSecretDoesNotDeleteKeychainValueWhenDatabaseClearFails() async throws {
        let secretStore = TestSecretStore()
        let manager = SettingsManager(
            database: DatabaseManager.unavailable(message: "settings database unavailable"),
            secretStore: secretStore
        )
        let secretKey = SecretKey.setting(SettingsKeys.omdbApiKey)

        try await secretStore.setSecret("token", for: secretKey)

        do {
            try await manager.setString(key: SettingsKeys.omdbApiKey, value: nil)
            Issue.record("Expected clearing a secret to fail while the settings database is unavailable")
        } catch {
            #expect(error.localizedDescription.contains("settings database unavailable"))
        }

        let storedSecret = try await secretStore.getSecret(for: secretKey)
        #expect(storedSecret == "token")
    }

    @Test
    func clearingSecretRestoresDatabaseReferenceWhenSecretDeleteFails() async throws {
        let database = try DatabaseManager(inMemoryNamed: "settings-delete-rollback.sqlite-\(UUID().uuidString)")
        try await database.migrate()
        let secretStore = FailingDeleteSecretStore()
        let manager = SettingsManager(database: database, secretStore: secretStore)
        let secretKey = SecretKey.setting(SettingsKeys.omdbApiKey)
        let encodedReference = SecretReference.encode(key: secretKey)

        try await secretStore.setSecret("token", for: secretKey)
        try await database.setSetting(key: SettingsKeys.omdbApiKey, value: encodedReference)

        do {
            try await manager.setString(key: SettingsKeys.omdbApiKey, value: nil)
            Issue.record("Expected clearing a secret to fail when the keychain delete fails")
        } catch {
            guard error is FailingSecretDeletionError else {
                Issue.record("Expected keychain delete failure, got \(error)")
                return
            }
        }

        let raw = try await database.getSetting(key: SettingsKeys.omdbApiKey)
        let storedSecret = try await secretStore.getSecret(for: secretKey)
        #expect(raw == encodedReference)
        #expect(storedSecret == "token")
    }

    @Test
    func aiProviderSecretKeysClearStoredSecretsWhenDeleted() async throws {
        try await withTempSettingsEnvironment(databaseName: "ai-settings-clear.sqlite") { database, secretStore, manager in
            for key in [SettingsKeys.mistralApiKey, SettingsKeys.minimaxApiKey] {
                let value = "token-\(key)"
                let secretKey = SecretKey.setting(key)

                try await manager.setString(key: key, value: value)

                let rawReference = try await database.getSetting(key: key)
                let storedSecret = try await secretStore.getSecret(for: secretKey)
                #expect(rawReference == SecretReference.encode(key: secretKey))
                #expect(storedSecret == value)

                try await manager.setString(key: key, value: nil)

                let persisted = try await manager.getString(key: key)
                let rawAfterDelete = try await database.getSetting(key: key)
                let secretAfterDelete = try await secretStore.getSecret(for: secretKey)
                #expect(persisted == nil)
                #expect(rawAfterDelete == nil)
                #expect(secretAfterDelete == nil)
            }
        }
    }
}
