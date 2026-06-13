import Testing
@testable import VPStudio

struct SecretStoreReferenceTests {

    // MARK: - SecretReference

    @Test
    func test_keychainPrefix() {
        #expect(SecretReference.keychainPrefix == "keychain:")
    }

    @Test
    func test_encode() {
        let encoded = SecretReference.encode(key: "my-key")
        #expect(encoded == "keychain:my-key")
    }

    @Test
    func test_decode_validPrefix() {
        let decoded = SecretReference.decode("keychain:my-key")
        #expect(decoded == "my-key")
    }

    @Test
    func test_decode_invalidPrefix() {
        #expect(SecretReference.decode("other:my-key") == nil)
        #expect(SecretReference.decode("my-key") == nil)
    }

    @Test
    func test_decode_emptyAfterPrefix() {
        let decoded = SecretReference.decode("keychain:")
        #expect(decoded == "")
    }

    // MARK: - SecretKey

    @Test
    func test_setting() {
        #expect(SecretKey.setting("tmdb") == "settings.tmdb")
    }

    @Test
    func test_debridToken_withoutConfigId() {
        let key = SecretKey.debridToken(service: .realDebrid)
        #expect(key == "debrid.real_debrid")
    }

    @Test
    func test_debridToken_withConfigId() {
        let key = SecretKey.debridToken(service: .premiumize, configId: "config-1")
        #expect(key == "debrid.premiumize.config-1")
    }
}
