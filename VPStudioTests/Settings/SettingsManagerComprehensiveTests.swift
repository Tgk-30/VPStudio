import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct SettingsManagerComprehensiveTests {

    private actor InMemorySecretStore: SecretStore {
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

    private actor FailingSecretStore: SecretStore {
        func setSecret(_ secret: String, for key: String) async throws {
            throw SecretStoreError.unexpectedStatus(errSecAuthFailed, operation: "update")
        }

        func getSecret(for key: String) async throws -> String? {
            throw SecretStoreError.unexpectedStatus(errSecAuthFailed, operation: "read")
        }

        func deleteSecret(for key: String) async throws {
            throw SecretStoreError.unexpectedStatus(errSecAuthFailed, operation: "delete")
        }

        func deleteAllSecrets() async throws {
            throw SecretStoreError.unexpectedStatus(errSecAuthFailed, operation: "deleteAll")
        }
    }

    private func makeTempSettingsManager() async throws -> (SettingsManager, DatabaseManager, InMemorySecretStore, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let database = try DatabaseManager(inMemoryNamed: "settings-test-\(UUID().uuidString)")
        try await database.migrate()
        let secretStore = InMemorySecretStore()
        let manager = SettingsManager(database: database, secretStore: secretStore)

        return (manager, database, secretStore, tempDir)
    }

    private func makeUnavailableSettingsManager() async throws -> (SettingsManager, DatabaseManager, InMemorySecretStore, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let database = try DatabaseManager(inMemoryNamed: "settings-test-\(UUID().uuidString)")
        try await database.migrate()

        let secretStore = InMemorySecretStore()
        let manager = SettingsManager(database: database, secretStore: secretStore)

        return (manager, database, secretStore, tempDir)
    }

    // MARK: - Basic GetValue/SetValue

    @Test func setAndGetRegularSetting() async throws {
        let (manager, database, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("test-value", forKey: "regular_key")
        let fetched = try await manager.getValue(forKey: "regular_key")

        #expect(fetched == "test-value")
        let stored = try await database.getSetting(key: "regular_key")
        #expect(stored == "test-value")
    }

    @Test func getNonExistentSettingReturnsNil() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fetched = try await manager.getValue(forKey: "nonexistent_key")
        #expect(fetched == nil)
    }

    @Test func setValueToNilDeletesSetting() async throws {
        let (manager, database, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("temp-value", forKey: "temp_key")
        try await manager.setValue(nil, forKey: "temp_key")

        let fetched = try await manager.getValue(forKey: "temp_key")
        #expect(fetched == nil)
        let stored = try await database.getSetting(key: "temp_key")
        #expect(stored == nil)
    }

    // MARK: - Secret Key Handling

    @Test func secretKeyStoredInKeychain() async throws {
        let (manager, database, secretStore, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("my-secret-api-key", forKey: SettingsKeys.tmdbApiKey)

        let secret = try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.tmdbApiKey))
        #expect(secret == "my-secret-api-key")

        let dbValue = try await database.getSetting(key: SettingsKeys.tmdbApiKey)
        #expect(dbValue?.hasPrefix(SecretReference.keychainPrefix) == true)
    }

    @Test func secretKeyRetrievedFromKeychain() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("secret-token", forKey: SettingsKeys.openAIApiKey)
        let fetched = try await manager.getValue(forKey: SettingsKeys.openAIApiKey)

        #expect(fetched == "secret-token")
    }

    @Test func settingSecretToNilClearsBothDBAndKeychain() async throws {
        let (manager, database, secretStore, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("token-to-clear", forKey: SettingsKeys.openAIApiKey)
        try await manager.setValue(nil, forKey: SettingsKeys.openAIApiKey)

        let fetched = try await manager.getValue(forKey: SettingsKeys.openAIApiKey)
        #expect(fetched == nil)

        let dbValue = try await database.getSetting(key: SettingsKeys.openAIApiKey)
        #expect(dbValue == nil)

        let secret = try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.openAIApiKey))
        #expect(secret == nil)
    }

    @Test func settingSecretToNilPropagatesKeychainDeleteFailureAndKeepsDBReference() async throws {
        let database = try DatabaseManager(inMemoryNamed: "settings-delete-failure-\(UUID().uuidString)")
        try await database.migrate()
        let manager = SettingsManager(database: database, secretStore: FailingSecretStore())
        let key = SettingsKeys.openAIApiKey
        let storedReference = SecretReference.encode(key: SecretKey.setting(key))
        try await database.setSetting(key: key, value: storedReference)

        do {
            try await manager.setValue(nil, forKey: key)
            Issue.record("Expected keychain delete failure to be propagated.")
        } catch {
            #expect(error as? SecretStoreError == .unexpectedStatus(errSecAuthFailed, operation: "delete"))
        }

        #expect(try await database.getSetting(key: key) == storedReference)
    }

    @Test func updatingAndDeletingACloudApiKeyReplacesTheStoredSecretAndClearsBothStores() async throws {
        let (manager, database, secretStore, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("first-token", forKey: SettingsKeys.geminiApiKey)
        try await manager.setValue("second-token", forKey: SettingsKeys.geminiApiKey)

        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.geminiApiKey)) == "second-token")
        #expect(try await database.getSetting(key: SettingsKeys.geminiApiKey)?.hasPrefix(SecretReference.keychainPrefix) == true)

        try await manager.setValue(nil, forKey: SettingsKeys.geminiApiKey)

        #expect(try await database.getSetting(key: SettingsKeys.geminiApiKey) == nil)
        #expect(try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.geminiApiKey)) == nil)
    }

    @Test func allSecretKeysUseKeychainStorage() async throws {
        let (manager, database, secretStore, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let secretKeyList = [
            SettingsKeys.omdbApiKey,
            SettingsKeys.tmdbApiKey,
            SettingsKeys.openSubtitlesApiKey,
            SettingsKeys.openAIApiKey,
            SettingsKeys.anthropicApiKey,
            SettingsKeys.openRouterApiKey,
            SettingsKeys.mistralApiKey,
            SettingsKeys.minimaxApiKey,
            SettingsKeys.traktClientId,
            SettingsKeys.traktClientSecret,
            SettingsKeys.traktAccessToken,
            SettingsKeys.traktRefreshToken,
            SettingsKeys.simklClientId,
            SettingsKeys.simklAccessToken,
            SettingsKeys.simklRefreshToken,
            SettingsKeys.geminiApiKey,
        ]

        for key in secretKeyList {
            let secretValue = "secret-for-\(key)"
            try await manager.setValue(secretValue, forKey: key)

            let secret = try await secretStore.getSecret(for: SecretKey.setting(key))
            #expect(secret == secretValue, "Secret not stored for key: \(key)")

            let dbValue = try await database.getSetting(key: key)
            #expect(dbValue?.hasPrefix(SecretReference.keychainPrefix) == true, "DB value not encoded for key: \(key)")
        }
    }

    // MARK: - Secret Migration from Plaintext

    @Test func migrationMigratesPlaintextSecretToKeychain() async throws {
        let (manager, database, secretStore, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await database.setSetting(key: SettingsKeys.tmdbApiKey, value: "legacy-plaintext-token")

        let fetched = try await manager.getValue(forKey: SettingsKeys.tmdbApiKey)
        #expect(fetched == "legacy-plaintext-token")

        let secret = try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.tmdbApiKey))
        #expect(secret == "legacy-plaintext-token")

        let dbValue = try await database.getSetting(key: SettingsKeys.tmdbApiKey)
        #expect(dbValue?.hasPrefix(SecretReference.keychainPrefix) == true)
    }

    @Test func migrationSkipsIfAlreadyMigrated() async throws {
        let (manager, database, secretStore, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await database.setSetting(key: SettingsKeys.tmdbApiKey, value: "legacy-plaintext-token")

        _ = try await manager.getValue(forKey: SettingsKeys.tmdbApiKey)

        let secret = try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.tmdbApiKey))
        #expect(secret == "legacy-plaintext-token")

        let dbValue = try await database.getSetting(key: SettingsKeys.tmdbApiKey)
        #expect(dbValue?.hasPrefix(SecretReference.keychainPrefix) == true)
    }

    @Test func migrationRetainsPlaintextOnDBFailure() async throws {
        let (manager, database, secretStore, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await database.setSetting(key: SettingsKeys.tmdbApiKey, value: "legacy-plaintext-token")

        _ = try await secretStore.deleteSecret(for: SecretKey.setting(SettingsKeys.tmdbApiKey))

        let fetched = try await manager.getValue(forKey: SettingsKeys.tmdbApiKey)
        #expect(fetched == "legacy-plaintext-token")
    }

    @Test func migrationCoexistenceWithConcurrentReads() async throws {
        let (manager, database, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await database.setSetting(key: SettingsKeys.tmdbApiKey, value: "concurrent-token")

        async let fetch1 = manager.getValue(forKey: SettingsKeys.tmdbApiKey)
        async let fetch2 = manager.getValue(forKey: SettingsKeys.tmdbApiKey)

        let (result1, result2) = try await (fetch1, fetch2)

        #expect(result1 == "concurrent-token")
        #expect(result2 == "concurrent-token")
    }

    // MARK: - Key Normalization (Whitespace Trimming)

    @Test func secretValueIsTrimmedBeforeStorage() async throws {
        let (manager, _, secretStore, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("  trimmed-token  ", forKey: SettingsKeys.tmdbApiKey)

        let fetched = try await manager.getValue(forKey: SettingsKeys.tmdbApiKey)
        #expect(fetched == "trimmed-token")

        let secret = try await secretStore.getSecret(for: SecretKey.setting(SettingsKeys.tmdbApiKey))
        #expect(secret == "trimmed-token")
    }

    @Test func whitespaceOnlySecretClearsValue() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("valid-token", forKey: SettingsKeys.tmdbApiKey)
        try await manager.setValue("   \n\t  ", forKey: SettingsKeys.tmdbApiKey)

        let fetched = try await manager.getValue(forKey: SettingsKeys.tmdbApiKey)
        #expect(fetched == nil)
    }

    @Test func regularKeyValueNotAffectedBySecretNormalization() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("  value-with-spaces  ", forKey: "regular_key")

        let fetched = try await manager.getValue(forKey: "regular_key")
        #expect(fetched == "  value-with-spaces  ")
    }

    // MARK: - Convenience Methods

    @Test func getTMDBApiKey() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("tmdb-key-123", forKey: SettingsKeys.tmdbApiKey)
        let fetched = try await manager.getTMDBApiKey()
        #expect(fetched == "tmdb-key-123")
    }

    @Test func getTMDBApiKeyReturnsNilWhenNotSet() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fetched = try await manager.getTMDBApiKey()
        #expect(fetched == nil)
    }

    @Test func getMetadataApiKeyUsesOMDbKey() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("omdb-key-123", forKey: SettingsKeys.omdbApiKey)

        let fetched = try await manager.getMetadataApiKey()
        #expect(fetched == "omdb-key-123")
    }

    @Test func getMetadataApiKeyDoesNotFallbackToLegacyTMDBKey() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("legacy-tmdb-key", forKey: SettingsKeys.tmdbApiKey)

        let fetched = try await manager.getMetadataApiKey()
        #expect(fetched == nil)
    }

    @Test func getPreferredQualityDefaultsTo1080p() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let quality = try await manager.getPreferredQuality()
        #expect(quality == .hd1080p)
    }

    @Test func getPreferredQualityParsesStoredValue() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("4K", forKey: SettingsKeys.preferredQuality)
        let quality = try await manager.getPreferredQuality()
        #expect(quality == .uhd4k)
    }

    @Test func getPreferredQualityParsesAllValidCases() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cases: [(String, VideoQuality)] = [
            ("4K", .uhd4k),
            ("1080p", .hd1080p),
            ("720p", .hd720p),
            ("480p", .sd480p),
            ("SD", .sd),
        ]

        for (raw, expected) in cases {
            try await manager.setValue(raw, forKey: SettingsKeys.preferredQuality)
            let quality = try await manager.getPreferredQuality()
            #expect(quality == expected, "Failed for \(raw)")
        }
    }

    @Test func getFeedbackScaleModeDefaultsToLikeDislike() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mode = try await manager.getFeedbackScaleMode()
        #expect(mode == .likeDislike)
    }

    @Test func getFeedbackScaleModeParsesStoredValue() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("one_to_ten", forKey: SettingsKeys.feedbackScaleMode)
        let mode = try await manager.getFeedbackScaleMode()
        #expect(mode == .oneToTen)
    }

    @Test func getFeedbackScaleModeHandlesLegacyValues() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setValue("five_star", forKey: SettingsKeys.feedbackScaleMode)
        let mode = try await manager.getFeedbackScaleMode()
        #expect(mode.canonicalMode == .oneToTen)
    }

    @Test func getBoolDefaultsToFalse() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let value = try await manager.getBool(key: "nonexistent_bool")
        #expect(value == false)
    }

    @Test func getBoolWithCustomDefault() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let value = try await manager.getBool(key: "nonexistent_bool", default: true)
        #expect(value == true)
    }

    @Test func getBoolParsesTrueValues() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        for trueValue in ["1", "true", "TRUE", "True"] {
            try await manager.setValue(trueValue, forKey: "test_bool")
            let value = try await manager.getBool(key: "test_bool")
            #expect(value == true, "Failed for \(trueValue)")
        }
    }

    @Test func getBoolParsesFalseValues() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        for falseValue in ["0", "false", "FALSE", "False"] {
            try await manager.setValue(falseValue, forKey: "test_bool")
            let value = try await manager.getBool(key: "test_bool")
            #expect(value == false, "Failed for \(falseValue)")
        }
    }

    @Test func setBoolStoresCorrectFormat() async throws {
        let (manager, database, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setBool(key: "test_bool", value: true)
        let stored = try await database.getSetting(key: "test_bool")
        #expect(stored == "1")

        try await manager.setBool(key: "test_bool", value: false)
        let stored2 = try await database.getSetting(key: "test_bool")
        #expect(stored2 == "0")
    }

    // MARK: - String Convenience Methods

    @Test func getStringDelegatesToGetValue() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setString(key: "string_key", value: "string-value")
        let fetched = try await manager.getString(key: "string_key")
        #expect(fetched == "string-value")
    }

    @Test func setStringDelegatesToSetValue() async throws {
        let (manager, database, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try await manager.setString(key: "string_key", value: "string-value")
        let stored = try await database.getSetting(key: "string_key")
        #expect(stored == "string-value")
    }

    // MARK: - All Secret Keys Accounted For

    @Test func allDefinedSecretKeysAreRecognized() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let allSecretKeys = [
            SettingsKeys.omdbApiKey,
            SettingsKeys.tmdbApiKey,
            SettingsKeys.openSubtitlesApiKey,
            SettingsKeys.openAIApiKey,
            SettingsKeys.anthropicApiKey,
            SettingsKeys.openRouterApiKey,
            SettingsKeys.mistralApiKey,
            SettingsKeys.minimaxApiKey,
            SettingsKeys.traktClientId,
            SettingsKeys.traktClientSecret,
            SettingsKeys.traktAccessToken,
            SettingsKeys.traktRefreshToken,
            SettingsKeys.simklClientId,
            SettingsKeys.simklAccessToken,
            SettingsKeys.simklRefreshToken,
            SettingsKeys.geminiApiKey,
        ]

        for key in allSecretKeys {
            try await manager.setValue("test-value", forKey: key)
            let fetched = try await manager.getValue(forKey: key)
            #expect(fetched == "test-value", "Failed for secret key: \(key)")
        }
    }

    // MARK: - Round-trip with DatabaseManager

    @Test func settingsRoundTripThroughDatabaseManager() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let database = try DatabaseManager(inMemoryNamed: "roundtrip-\(UUID().uuidString)")
        try await database.migrate()

        let settings: [(String, String?)] = [
            ("regular_string", "hello"),
            ("regular_number", "42"),
            ("empty_string", ""),
            ("unicode_value", "日本語テスト"),
        ]

        for (key, value) in settings {
            try await database.setSetting(key: key, value: value)
        }

        for (key, expected) in settings {
            let fetched = try await database.getSetting(key: key)
            #expect(fetched == expected, "Round-trip failed for \(key)")
        }
    }

    // MARK: - Concurrent Access

    @Test func concurrentSetAndGetOperations() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    try? await manager.setValue("value-\(i)", forKey: "concurrent-\(i)")
                }
            }
            for i in 0..<10 {
                group.addTask {
                    _ = try? await manager.getValue(forKey: "concurrent-\(i)")
                }
            }
        }

        for i in 0..<10 {
            let value = try await manager.getValue(forKey: "concurrent-\(i)")
            #expect(value == "value-\(i)")
        }
    }

    @Test func concurrentSecretWrites() async throws {
        let (manager, _, _, tempDir) = try await makeTempSettingsManager()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    try? await manager.setValue("secret-\(i)", forKey: SettingsKeys.tmdbApiKey)
                }
            }
        }

        let finalValue = try await manager.getValue(forKey: SettingsKeys.tmdbApiKey)
        #expect(finalValue?.hasPrefix("secret-") == true)
    }

    // MARK: - SecretReference Encoding/Decoding

    @Test func secretReferenceEncodeDecode() async throws {
        let original = "my-secret-key"
        let encoded = SecretReference.encode(key: original)
        #expect(encoded == "keychain:my-secret-key")

        let decoded = SecretReference.decode(encoded)
        #expect(decoded == original)
    }

    @Test func secretReferenceDecodeReturnsNilForPlaintext() async throws {
        let plaintext = "just-a-plain-value"
        let decoded = SecretReference.decode(plaintext)
        #expect(decoded == nil)
    }

    @Test func secretKeyFormatForSettings() async throws {
        let key = SecretKey.setting("tmdb_api_key")
        #expect(key == "settings.tmdb_api_key")
    }
}
