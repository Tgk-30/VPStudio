import Foundation
import Testing
@testable import VPStudio

@Suite("SecretStore Protocol Conformance")
struct SecretStoreProtocolConformanceTests {

    @Test
    func testSecretStoreSetAndGet() async throws {
        let store = TestSecretStore()

        try await store.setSecret("value1", for: "key1")
        let retrieved = try await store.getSecret(for: "key1")
        #expect(retrieved == "value1")
    }

    @Test
    func testSecretStoreDelete() async throws {
        let store = TestSecretStore()

        try await store.setSecret("value1", for: "key1")
        try await store.deleteSecret(for: "key1")
        let retrieved = try await store.getSecret(for: "key1")
        #expect(retrieved == nil)
    }

    @Test
    func testSecretStoreDeleteAll() async throws {
        let store = TestSecretStore()

        try await store.setSecret("value1", for: "key1")
        try await store.setSecret("value2", for: "key2")
        try await store.deleteAllSecrets()

        #expect(try await store.getSecret(for: "key1") == nil)
        #expect(try await store.getSecret(for: "key2") == nil)
    }

    @Test
    func testSecretStoreMultipleKeys() async throws {
        let store = TestSecretStore()

        let keys = ["a", "b", "c", "d"]
        let values = ["1", "2", "3", "4"]

        for (key, value) in zip(keys, values) {
            try await store.setSecret(value, for: key)
        }

        for (key, value) in zip(keys, values) {
            #expect(try await store.getSecret(for: key) == value)
        }
    }

    @Test
    func testSecretStoreOverwriteExistingKey() async throws {
        let store = TestSecretStore()

        try await store.setSecret("original", for: "overwrite-key")
        try await store.setSecret("updated", for: "overwrite-key")

        #expect(try await store.getSecret(for: "overwrite-key") == "updated")
    }

    @Test
    func testSecretStoreEmptyStringValue() async throws {
        let store = TestSecretStore()

        try await store.setSecret("", for: "empty-key")
        #expect(try await store.getSecret(for: "empty-key") == "")
    }

    @Test
    func testSecretStoreEmptyKeyWithValue() async throws {
        let store = TestSecretStore()

        try await store.setSecret("value", for: "")
        #expect(try await store.getSecret(for: "") == "value")
    }

    @Test
    func testSecretStoreBothEmpty() async throws {
        let store = TestSecretStore()

        try await store.setSecret("", for: "")
        #expect(try await store.getSecret(for: "") == "")
    }

    @Test
    func testSecretStoreNonExistentKeyReturnsNil() async throws {
        let store = TestSecretStore()

        #expect(try await store.getSecret(for: "nonexistent") == nil)
    }

    @Test
    func testSecretStoreDeleteNonExistentKeyDoesNotThrow() async throws {
        let store = TestSecretStore()

        try await store.deleteSecret(for: "nonexistent")
    }

    @Test
    func testSecretStoreDeleteAllMultipleTimesIsIdempotent() async throws {
        let store = TestSecretStore()

        try await store.deleteAllSecrets()
        try await store.deleteAllSecrets()
        try await store.deleteAllSecrets()

        #expect(try await store.getSecret(for: "any-key") == nil)
    }
}