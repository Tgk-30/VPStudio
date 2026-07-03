import Foundation
import Testing
@testable import VPStudio

// MARK: - SecretStore Protocol Conformance Tests

private func acceptsSecretStore<T: SecretStore>(_ value: T) -> Bool {
    _ = value
    return true
}

@Suite("SecretStore Conformance")
struct SecretStoreConformanceTests {

    @Test func keychainSecretStoreConformsToSecretStore() async throws {
        let store = KeychainSecretStore(serviceName: "com.vpstudio.test.\(UUID().uuidString)")
        #expect(acceptsSecretStore(store))
    }

    @Test func setAndGetSecretRoundTrip() async throws {
        let store = KeychainSecretStore(serviceName: "com.vpstudio.test.\(UUID().uuidString)")
        let key = "test-key"
        let value = "test-value"

        try await store.setSecret(value, for: key)
        let retrieved = try await store.getSecret(for: key)

        #expect(retrieved == value)
    }

    @Test func getSecretReturnsNilForNonexistentKey() async throws {
        let store = KeychainSecretStore(serviceName: "com.vpstudio.test.\(UUID().uuidString)")
        let retrieved = try await store.getSecret(for: "nonexistent-key")
        #expect(retrieved == nil)
    }

    @Test func deleteSecretRemovesValue() async throws {
        let store = KeychainSecretStore(serviceName: "com.vpstudio.test.\(UUID().uuidString)")
        let key = "delete-test-key"
        try await store.setSecret("value", for: key)

        try await store.deleteSecret(for: key)
        let retrieved = try await store.getSecret(for: key)

        #expect(retrieved == nil)
    }

    @Test func deleteAllSecretsRemovesAll() async throws {
        let store = KeychainSecretStore(serviceName: "com.vpstudio.test.\(UUID().uuidString)")
        try await store.setSecret("value1", for: "key1")
        try await store.setSecret("value2", for: "key2")

        try await store.deleteAllSecrets()

        #expect(try await store.getSecret(for: "key1") == nil)
        #expect(try await store.getSecret(for: "key2") == nil)
    }

    @Test func setSecretOverwritesExisting() async throws {
        let store = KeychainSecretStore(serviceName: "com.vpstudio.test.\(UUID().uuidString)")
        let key = "overwrite-key"
        try await store.setSecret("first-value", for: key)
        try await store.setSecret("second-value", for: key)

        let retrieved = try await store.getSecret(for: key)
        #expect(retrieved == "second-value")
    }
}

// MARK: - SecretStoreError Tests

@Suite("SecretStoreError")
struct SecretStoreErrorTestsSecretstoreprotocolconformancetests {

    @Test func unexpectedStatusHasDescription() {
        let error = SecretStoreError.unexpectedStatus(errSecAuthFailed, operation: "read")
        #expect(error.errorDescription == "Keychain read failed with status -25293")
    }

    @Test func invalidSecretDataHasDescription() {
        let error = SecretStoreError.invalidSecretData
        #expect(error.errorDescription == "Stored secret data is invalid")
    }

    @Test func recoverySuggestionsDescribeAuthenticationAndResetPaths() {
        let authError = SecretStoreError.unexpectedStatus(errSecAuthFailed, operation: "read")
        let genericError = SecretStoreError.unexpectedStatus(errSecParam, operation: "update")
        let invalidData = SecretStoreError.invalidSecretData

        #expect(authError.recoverySuggestion?.contains("authentication failed during read") == true)
        #expect(genericError.recoverySuggestion == "Keychain update failed. Check keychain access permissions and try again.")
        #expect(invalidData.recoverySuggestion == "Reset the stored credential and re-enter it.")
    }

    @Test func errorsAreEquatable() {
        #expect(SecretStoreError.invalidSecretData == .invalidSecretData)
        #expect(SecretStoreError.unexpectedStatus(errSecAuthFailed, operation: "read") == .unexpectedStatus(errSecAuthFailed, operation: "read"))
        #expect(SecretStoreError.unexpectedStatus(errSecAuthFailed, operation: "read") != .unexpectedStatus(errSecParam, operation: "read"))
    }
}

// MARK: - SecretReference Tests

@Suite("SecretReference")
struct SecretReferenceTestsSecretstoreprotocolconformancetests {

    @Test func keychainPrefixIsKeychain() {
        #expect(SecretReference.keychainPrefix == "keychain:")
    }

    @Test func encodeAddsPrefix() {
        let encoded = SecretReference.encode(key: "my-key")
        #expect(encoded == "keychain:my-key")
    }

    @Test func decodeRemovesPrefix() {
        let decoded = SecretReference.decode("keychain:my-key")
        #expect(decoded == "my-key")
    }

    @Test func decodeReturnsNilForWrongPrefix() {
        #expect(SecretReference.decode("other:my-key") == nil)
        #expect(SecretReference.decode("my-key") == nil)
    }

    @Test func decodeHandlesEmptyAfterPrefix() {
        #expect(SecretReference.decode("keychain:") == "")
    }
}

// MARK: - SecretKey Tests

@Suite("SecretKey")
struct SecretKeyTestsSecretstoreprotocolconformancetests {

    @Test func settingCreatesSettingsPrefix() {
        #expect(SecretKey.setting("tmdb") == "settings.tmdb")
        #expect(SecretKey.setting("openai-key") == "settings.openai-key")
    }

    @Test func debridTokenCreatesCorrectFormat() {
        #expect(SecretKey.debridToken(service: .realDebrid) == "debrid.real_debrid")
        #expect(SecretKey.debridToken(service: .premiumize) == "debrid.premiumize")
        #expect(SecretKey.debridToken(service: .torBox) == "debrid.torbox")
    }

    @Test func debridTokenWithConfigIdIncludesConfig() {
        #expect(SecretKey.debridToken(service: .realDebrid, configId: "config-1") == "debrid.real_debrid.config-1")
        #expect(SecretKey.debridToken(service: .allDebrid, configId: "secondary") == "debrid.all_debrid.secondary")
    }
}
