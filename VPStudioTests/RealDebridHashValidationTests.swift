import Foundation
import Testing
@testable import VPStudio

/// Tests for shared debrid info-hash validation, ensuring malformed hashes
/// are rejected before they can be embedded in provider requests.
@Suite("Debrid Hash Validation")
struct RealDebridHashValidationTests {

    // MARK: - DebridHashValidator coverage

    @Test("Valid 40-char lowercase hex hash is accepted")
    func validLowercaseHash40() async throws {
        let hash = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == hash)
    }

    @Test("Valid 40-char uppercase hex hash is accepted")
    func validUppercaseHash40() async throws {
        let hash = "A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == hash.lowercased())
    }

    @Test("Valid 64-char hex hash (SHA-256) is accepted")
    func validHash64() async throws {
        let hash = String(repeating: "ab", count: 32)
        #expect(hash.count == 64)
        #expect(DebridHashValidator.normalizedInfoHash(hash) == hash)
    }

    @Test("Hash with slash is rejected")
    func hashWithSlash() async throws {
        let hash = "a1b2c3d4e5f6a1b2c3d4e5f6/../../etc/passwd"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == nil)
    }

    @Test("Hash with question mark is rejected")
    func hashWithQuestionMark() async throws {
        let hash = "a1b2c3d4e5f6a1b2c3d4?extra=param"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == nil)
    }

    @Test("Empty string is rejected")
    func emptyHash() async throws {
        #expect(DebridHashValidator.normalizedInfoHash("") == nil)
    }

    @Test("Hash with spaces is rejected")
    func hashWithSpaces() async throws {
        let hash = "a1b2c3d4 e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == nil)
    }

    @Test("Hash too short (39 chars) is rejected")
    func hashTooShort() async throws {
        let hash = String(repeating: "a", count: 39)
        #expect(DebridHashValidator.normalizedInfoHash(hash) == nil)
    }

    @Test("Hash too long (65 chars) is rejected")
    func hashTooLong() async throws {
        let hash = String(repeating: "a", count: 65)
        #expect(DebridHashValidator.normalizedInfoHash(hash) == nil)
    }

    @Test("Hash with non-hex characters is rejected")
    func hashWithNonHex() async throws {
        let hash = "g1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" // 'g' is not hex
        #expect(DebridHashValidator.normalizedInfoHash(hash) == nil)
    }

    @Test("41-char hex string is rejected")
    func hash41Chars() async throws {
        let hash = String(repeating: "a", count: 41)
        #expect(DebridHashValidator.normalizedInfoHash(hash) == nil)
    }

    // MARK: - base32 info-hashes (some indexers/trackers publish `urn:btih:` this way)

    @Test("32-char base32 of all-zero bytes decodes to 40 hex zeros")
    func base32AllZeroBytes() async throws {
        let hash = String(repeating: "A", count: 32) // 160 zero bits
        #expect(DebridHashValidator.normalizedInfoHash(hash) == String(repeating: "0", count: 40))
    }

    @Test("32-char base32 of all-one bytes decodes to 40 hex f's")
    func base32AllOneBytes() async throws {
        let hash = String(repeating: "7", count: 32) // value 31 == 0b11111, 160 one bits
        #expect(DebridHashValidator.normalizedInfoHash(hash) == String(repeating: "f", count: 40))
    }

    @Test("32-char base32 decodes asymmetrically (trailing 0x01)")
    func base32TrailingOne() async throws {
        let hash = String(repeating: "A", count: 31) + "B" // last 5 bits == 00001
        #expect(DebridHashValidator.normalizedInfoHash(hash) == String(repeating: "0", count: 38) + "01")
    }

    @Test("Lowercase base32 is accepted (case-insensitive)")
    func base32LowercaseAccepted() async throws {
        let hash = String(repeating: "a", count: 32)
        #expect(DebridHashValidator.normalizedInfoHash(hash) == String(repeating: "0", count: 40))
    }

    @Test("32-char string with non-base32 character is rejected")
    func base32InvalidCharacterRejected() async throws {
        // '0', '1', '8', '9' are not in the RFC 4648 base32 alphabet.
        let hash = "0" + String(repeating: "A", count: 31)
        #expect(DebridHashValidator.normalizedInfoHash(hash) == nil)
    }

    @Test("31-char base32 string is rejected (wrong length)")
    func base32WrongLengthRejected() async throws {
        let hash = String(repeating: "A", count: 31)
        #expect(DebridHashValidator.normalizedInfoHash(hash) == nil)
    }
}
