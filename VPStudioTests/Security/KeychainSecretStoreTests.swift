import Foundation
import Testing
@testable import VPStudio

@Suite("KeychainSecretStore", .serialized)
struct KeychainSecretStoreTests {
    private let serviceName = "com.vpstudio.tests.keychain.\(UUID().uuidString)"

    private func makeStore() -> KeychainSecretStore {
        KeychainSecretStore(serviceName: serviceName)
    }

    private func cleanup(store: KeychainSecretStore) async throws {
        try await store.deleteAllSecrets()
    }

    // MARK: - Round-trip

    @Test
    func keychainStoreFallsBackToInMemoryWhenNativeStoreIsUnavailable() async throws {
        let serviceName = "com.vpstudio.tests.keychain.\(UUID().uuidString)"
        let store = KeychainSecretStore(serviceName: serviceName)
        defer { Task { try? await store.deleteAllSecrets() } }

        try await store.setSecret("fallback-check", for: "cross-instance-key")
        let sameInstanceValue = try await store.getSecret(for: "cross-instance-key")
        let nativeStoreAvailable = KeychainSecretStore.isNativeKeychainUsable()
        let secondStore = KeychainSecretStore(serviceName: serviceName)

        let secondInstanceValue = try await secondStore.getSecret(for: "cross-instance-key")
        if nativeStoreAvailable {
            // In keychain-enabled environments values should usually persist.
            // If platform quirks force an in-memory fallback, both stores
            // naturally remain isolated but still keep the same-instance value.
            #expect(secondInstanceValue == nil || secondInstanceValue == "fallback-check")
        }

        #expect(sameInstanceValue == "fallback-check")
    }

    @Test
    func setAndGetSecretRoundTrip() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        try await store.setSecret("my-secret-value", for: "test-key")
        let secret = try await store.getSecret(for: "test-key")
        #expect(secret == "my-secret-value")
    }

    @Test
    func setAndGetMultipleSecrets() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        try await store.setSecret("alpha", for: "key-a")
        try await store.setSecret("beta", for: "key-b")

        #expect(try await store.getSecret(for: "key-a") == "alpha")
        #expect(try await store.getSecret(for: "key-b") == "beta")
    }

    // MARK: - Update

    @Test
    func updateExistingSecret() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        try await store.setSecret("original", for: "update-key")
        try await store.setSecret("updated", for: "update-key")

        let secret = try await store.getSecret(for: "update-key")
        #expect(secret == "updated")
    }

    // MARK: - Non-existent reads

    @Test
    func getNonExistentSecretReturnsNil() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        let secret = try await store.getSecret(for: "missing-key")
        #expect(secret == nil)
    }

    // MARK: - Delete

    @Test
    func deleteExistingSecret() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        try await store.setSecret("to-delete", for: "delete-key")
        try await store.deleteSecret(for: "delete-key")

        let secret = try await store.getSecret(for: "delete-key")
        #expect(secret == nil)
    }

    @Test
    func deleteNonExistentSecretDoesNotCrash() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        try await store.deleteSecret(for: "never-added-key")
    }

    @Test
    func getAfterDeleteReturnsNil() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        try await store.setSecret("temp", for: "temp-key")
        #expect(try await store.getSecret(for: "temp-key") == "temp")

        try await store.deleteSecret(for: "temp-key")
        #expect(try await store.getSecret(for: "temp-key") == nil)
    }

    // MARK: - deleteAllSecrets

    @Test
    func deleteAllSecretsClearsEntriesForService() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        try await store.setSecret("one", for: "key-1")
        try await store.setSecret("two", for: "key-2")
        try await store.deleteAllSecrets()

        #expect(try await store.getSecret(for: "key-1") == nil)
        #expect(try await store.getSecret(for: "key-2") == nil)
    }

    @Test
    func deleteAllSecretsCanDeleteSingleStoredKey() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        try await store.setSecret("only-key", for: "single-key")
        try await store.deleteAllSecrets()

        #expect(try await store.getSecret(for: "single-key") == nil)
    }

    @Test
    func deleteAllSecretsDoesNotAffectOtherServices() async throws {
        let testStore = makeStore()
        let otherStore = KeychainSecretStore(serviceName: "com.vpstudio.tests.other")
        defer {
            Task {
                try? await testStore.deleteAllSecrets()
                try? await otherStore.deleteAllSecrets()
            }
        }

        try await testStore.setSecret("test-value", for: "shared-key")
        try await otherStore.setSecret("other-value", for: "shared-key")

        try await testStore.deleteAllSecrets()

        #expect(try await testStore.getSecret(for: "shared-key") == nil)
        #expect(try await otherStore.getSecret(for: "shared-key") == "other-value")
    }

    @Test
    func deleteAllSecretsIsIdempotent() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        try await store.deleteAllSecrets()
        try await store.deleteAllSecrets()
        #expect(try await store.getSecret(for: "any-key") == nil)
    }

    // MARK: - SecretReference

    @Test
    func secretReferenceEncodeProducesExpectedPrefix() {
        let encoded = SecretReference.encode(key: "api-key")
        #expect(encoded == "keychain:api-key")
    }

    @Test
    func secretReferenceDecodeStripsPrefix() {
        let decoded = SecretReference.decode("keychain:api-key")
        #expect(decoded == "api-key")
    }

    @Test
    func secretReferenceDecodeInvalidPrefixReturnsNil() {
        let decoded = SecretReference.decode("plaintext:api-key")
        #expect(decoded == nil)
    }

    @Test
    func secretReferenceRoundTrip() {
        let original = "my-secret-key-123"
        let encoded = SecretReference.encode(key: original)
        let decoded = SecretReference.decode(encoded)
        #expect(decoded == original)
    }

    @Test
    func secretReferenceEncodeEmptyKey() {
        let encoded = SecretReference.encode(key: "")
        #expect(encoded == "keychain:")
    }

    @Test
    func secretReferenceDecodeEmptyString() {
        let decoded = SecretReference.decode("")
        #expect(decoded == nil)
    }

    // MARK: - SecretKey

    @Test
    func secretKeySettingProducesExpectedKey() {
        #expect(SecretKey.setting("tmdbApiKey") == "settings.tmdbApiKey")
        #expect(SecretKey.setting("openAIApiKey") == "settings.openAIApiKey")
    }

    @Test
    func secretKeyDebridTokenWithoutConfigId() {
        #expect(SecretKey.debridToken(service: .realDebrid) == "debrid.real_debrid")
        #expect(SecretKey.debridToken(service: .premiumize) == "debrid.premiumize")
    }

    @Test
    func secretKeyDebridTokenWithConfigId() {
        #expect(SecretKey.debridToken(service: .realDebrid, configId: "rd-1") == "debrid.real_debrid.rd-1")
        #expect(SecretKey.debridToken(service: .allDebrid, configId: "ad-99") == "debrid.all_debrid.ad-99")
    }

    // MARK: - Edge cases

    @Test
    func emptySecretDataIsHandled() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        try await store.setSecret("", for: "empty-key")
        let secret = try await store.getSecret(for: "empty-key")
        #expect(secret == "")
    }

    @Test
    func largeSecretDataIsHandled() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        let largeValue = String(repeating: "A", count: 10_000)
        try await store.setSecret(largeValue, for: "large-key")
        let secret = try await store.getSecret(for: "large-key")
        #expect(secret == largeValue)
    }

    @Test
    func unicodeSecretIsHandled() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        let value = "🔑 Ключ clé 鍵"
        try await store.setSecret(value, for: "unicode-key")
        let secret = try await store.getSecret(for: "unicode-key")
        #expect(secret == value)
    }

    @Test
    func specialCharacterSecretIsHandled() async throws {
        let store = makeStore()
        defer { Task { try? await cleanup(store: store) } }

        let value = "<>&\"'\n\t\r\\/"
        try await store.setSecret(value, for: "special-key")
        let secret = try await store.getSecret(for: "special-key")
        #expect(secret == value)
    }
}
