import Testing
import Foundation
@testable import VPStudio

private actor MagnetCallTracker {
    private var hashes: [String] = []

    func record(_ hash: String) {
        hashes.append(hash)
    }

    func recordedHashes() -> [String] {
        hashes
    }
}

@Suite("DebridServiceProtocol Extension")
struct DebridServiceProtocolExtensionTests {

    @Test("selectMatchingEpisodeFile default implementation returns false")
    func selectMatchingEpisodeFileDefaultReturnsFalse() async throws {
        struct MockDebridService: DebridServiceProtocol {
            var serviceType: DebridServiceType { .realDebrid }

            func validateToken() async throws -> Bool { true }
            func getAccountInfo() async throws -> DebridAccountInfo {
                DebridAccountInfo(username: "test")
            }
            func checkCache(hashes: [String]) async throws -> [String: CacheStatus] { [:] }
            func addMagnet(hash: String) async throws -> String { "" }
            func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
            func getStreamURL(torrentId: String) async throws -> StreamInfo {
                StreamInfo(
                    streamURL: URL(string: "https://example.com")!,
                    quality: .hd1080p,
                    codec: .h264,
                    audio: .aac,
                    source: .webDL,
                    hdr: .sdr,
                    fileName: "test.mkv",
                    sizeBytes: nil,
                    debridService: "test"
                )
            }
            func unrestrict(link: String) async throws -> URL { URL(string: "https://example.com")! }
        }

        let service = MockDebridService()
        let result = try await service.selectMatchingEpisodeFile(
            torrentId: "abc123",
            seasonNumber: 1,
            episodeNumber: 5,
            resolvedFileNameHint: "S01E05.mkv",
            resolvedFileSizeHint: 1_000_000
        )
        #expect(result == false)
    }

    @Test("cleanupRemoteTransfer default implementation does not throw")
    func cleanupRemoteTransferDefaultDoesNotThrow() async throws {
        struct MockDebridService: DebridServiceProtocol {
            var serviceType: DebridServiceType { .realDebrid }

            func validateToken() async throws -> Bool { true }
            func getAccountInfo() async throws -> DebridAccountInfo {
                DebridAccountInfo(username: "test")
            }
            func checkCache(hashes: [String]) async throws -> [String: CacheStatus] { [:] }
            func addMagnet(hash: String) async throws -> String { "" }
            func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
            func selectMatchingEpisodeFile(torrentId: String, seasonNumber: Int, episodeNumber: Int, resolvedFileNameHint: String?, resolvedFileSizeHint: Int64?) async throws -> Bool { false }
            func getStreamURL(torrentId: String) async throws -> StreamInfo {
                StreamInfo(
                    streamURL: URL(string: "https://example.com")!,
                    quality: .hd1080p,
                    codec: .h264,
                    audio: .aac,
                    source: .webDL,
                    hdr: .sdr,
                    fileName: "test.mkv",
                    sizeBytes: nil,
                    debridService: "test"
                )
            }
            func unrestrict(link: String) async throws -> URL { URL(string: "https://example.com")! }
        }

        let service = MockDebridService()
        try await service.cleanupRemoteTransfer(torrentId: "abc123")
    }

    @Test("addMagnet overload forwards to base addMagnet implementation")
    func addMagnetOverloadForwardsToBaseImplementation() async throws {
        struct MockDebridService: DebridServiceProtocol {
            var serviceType: DebridServiceType { .realDebrid }
            let tracker: MagnetCallTracker

            func validateToken() async throws -> Bool { true }
            func getAccountInfo() async throws -> DebridAccountInfo {
                DebridAccountInfo(username: "test")
            }
            func checkCache(hashes: [String]) async throws -> [String: CacheStatus] { [:] }
            func addMagnet(hash: String) async throws -> String {
                await tracker.record(hash)
                return "mock-\(hash)"
            }
            func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
            func selectMatchingEpisodeFile(
                torrentId: String,
                seasonNumber: Int,
                episodeNumber: Int,
                resolvedFileNameHint: String?,
                resolvedFileSizeHint: Int64?
            ) async throws -> Bool { false }
            func getStreamURL(torrentId: String) async throws -> StreamInfo {
                StreamInfo(
                    streamURL: URL(string: "https://example.com")!,
                    quality: .hd1080p,
                    codec: .h264,
                    audio: .aac,
                    source: .webDL,
                    hdr: .sdr,
                    fileName: "test.mkv",
                    sizeBytes: nil,
                    debridService: "test"
                )
            }
            func unrestrict(link: String) async throws -> URL { URL(string: "https://example.com")! }
        }

        let tracker = MagnetCallTracker()
        let service = MockDebridService(tracker: tracker)
        let baseHash = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"

        let result = try await service.addMagnet(hash: baseHash, magnetURI: "https://example.com")

        #expect(result == "mock-\(baseHash)")
        #expect(await tracker.recordedHashes() == [baseHash])
    }

    @Test("addMagnet overload forwards nil magnetURI to base addMagnet implementation")
    func addMagnetOverloadForwardsNilMagnetURIToBaseImplementation() async throws {
        struct MockDebridService: DebridServiceProtocol {
            var serviceType: DebridServiceType { .realDebrid }
            let tracker: MagnetCallTracker

            func validateToken() async throws -> Bool { true }
            func getAccountInfo() async throws -> DebridAccountInfo {
                DebridAccountInfo(username: "test")
            }
            func checkCache(hashes: [String]) async throws -> [String: CacheStatus] { [:] }
            func addMagnet(hash: String) async throws -> String {
                await tracker.record(hash)
                return "mock-\(hash)"
            }
            func selectFiles(torrentId: String, fileIds: [Int]) async throws {}
            func selectMatchingEpisodeFile(
                torrentId: String,
                seasonNumber: Int,
                episodeNumber: Int,
                resolvedFileNameHint: String?,
                resolvedFileSizeHint: Int64?
            ) async throws -> Bool { false }
            func getStreamURL(torrentId: String) async throws -> StreamInfo {
                StreamInfo(
                    streamURL: URL(string: "https://example.com")!,
                    quality: .hd1080p,
                    codec: .h264,
                    audio: .aac,
                    source: .webDL,
                    hdr: .sdr,
                    fileName: "test.mkv",
                    sizeBytes: nil,
                    debridService: "test"
                )
            }
            func unrestrict(link: String) async throws -> URL { URL(string: "https://example.com")! }
        }

        let tracker = MagnetCallTracker()
        let service = MockDebridService(tracker: tracker)
        let baseHash = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"

        let result = try await service.addMagnet(hash: baseHash, magnetURI: nil)

        #expect(result == "mock-\(baseHash)")
        #expect(await tracker.recordedHashes() == [baseHash])
    }
}

@Suite("DebridHashValidator")
struct DebridHashValidatorTests {

    @Test("normalizedInfoHash accepts valid 40 character hash")
    func normalizedInfoHashValid40Char() {
        let hash40 = "abc123def456abc123def456abc123def456abcd"
        let result = DebridHashValidator.normalizedInfoHash(hash40)
        #expect(result == hash40.lowercased())
    }

    @Test("normalizedInfoHash accepts valid 64 character hash")
    func normalizedInfoHashValid64Char() {
        let hash64 = "ABC123DEF456abc123def456abc123def456abc123def456abc123def456abcd"
        let result = DebridHashValidator.normalizedInfoHash(hash64)
        #expect(result == hash64.lowercased())
    }

    @Test("normalizedInfoHash returns nil for hash with wrong length")
    func normalizedInfoHashWrongLength() {
        #expect(DebridHashValidator.normalizedInfoHash("abc123") == nil)
        #expect(DebridHashValidator.normalizedInfoHash("") == nil)
        #expect(DebridHashValidator.normalizedInfoHash(String(repeating: "a", count: 39)) == nil)
        #expect(DebridHashValidator.normalizedInfoHash(String(repeating: "a", count: 63)) == nil)
    }

    @Test("normalizedInfoHash returns nil for hash with invalid characters")
    func normalizedInfoHashInvalidCharacters() {
        #expect(DebridHashValidator.normalizedInfoHash("abc123def456abc123def456abc123def456xyz") == nil)
        #expect(DebridHashValidator.normalizedInfoHash("ghijklmnop") == nil)
    }

    @Test("normalizedInfoHash trims whitespace")
    func normalizedInfoHashTrimsWhitespace() {
        let hash40 = "abc123def456abc123def456abc123def456abcd"
        let result = DebridHashValidator.normalizedInfoHash("  \(hash40)  ")
        #expect(result == hash40.lowercased())
    }

    @Test("validatedInfoHash returns normalized hash for valid input")
    func validatedInfoHashReturnsNormalized() throws {
        let hash40 = "ABC123DEF456abc123def456abc123def456abcd"
        let result = try DebridHashValidator.validatedInfoHash(hash40)
        #expect(result == hash40.lowercased())
    }

    @Test("validatedInfoHash accepts 64-character hash")
    func validatedInfoHashAccepts64CharacterHash() throws {
        let hash64 = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"
        let result = try DebridHashValidator.validatedInfoHash(hash64)
        #expect(result == hash64.lowercased())
    }

    @Test("validatedInfoHash rejects too-short hash")
    func validatedInfoHashRejectsTooShortHash() {
        do {
            _ = try DebridHashValidator.validatedInfoHash("abc123")
            Issue.record("Expected DebridError.invalidHash")
        } catch DebridError.invalidHash(let hash) {
            #expect(hash == "abc123")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("validatedInfoHash throws for invalid hash")
    func validatedInfoHashThrowsForInvalid() {
        do {
            _ = try DebridHashValidator.validatedInfoHash("invalid")
            Issue.record("Expected DebridError.invalidHash")
        } catch DebridError.invalidHash(let hash) {
            #expect(hash == "invalid")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("DebridStreamMetadata")
struct DebridStreamMetadataTestsDebridserviceprotocolextensiontests {

    @Test("metadata trims candidate values and uses first usable value")
    func metadataTrimsValuesAndUsesFirstUsable() {
        let quality = DebridStreamMetadata.quality(from: [" ", "", " 1080p ", "4k"])
        #expect(quality == .hd1080p)
    }

    @Test("codec parsing ignores empty candidates before valid candidate")
    func codecParsingSkipsEmptyValues() {
        let codec = DebridStreamMetadata.codec(from: ["", nil, "   h265 "])
        #expect(codec == .h265)
    }

    @Test("source parsing falls back to unknown when no usable candidates")
    func sourceParsingDefaultsToUnknown() {
        let source = DebridStreamMetadata.source(from: ["  ", nil, "", "unknown-source"])
        #expect(source == .unknown)
    }

    @Test("hdr parsing uses first valid candidate")
    func hdrParsingUsesFirstValid() {
        let hdr = DebridStreamMetadata.hdr(from: ["", "HDR10+", "HDR"])
        #expect(hdr == .hdr10Plus)
    }

    @Test("audio parsing uses first valid candidate")
    func audioParsingUsesFirstValid() {
        let audio = DebridStreamMetadata.audio(from: [nil, "", "AAC", "FLAC"])
        #expect(audio == .aac)
    }

    @Test("audio parsing defaults to unknown when no usable candidates")
    func audioParsingDefaultsToUnknown() {
        let audio = DebridStreamMetadata.audio(from: [nil, "", "   ", "unknown"])
        #expect(audio == .unknown)
    }

    @Test("hdr defaults to SDR when no candidates are valid")
    func hdrParsingDefaultsToSDR() {
        let hdr = DebridStreamMetadata.hdr(from: ["", nil, "unsupported-format"])
        #expect(hdr == .sdr)
    }
}

@Suite("DebridMagnetInput")
struct DebridMagnetInputTestsDebridserviceprotocolextensiontests {

    @Test("preferredMagnetURI trims whitespace and accepts matching magnet")
    func preferredMagnetURITrimsWhitespaceAndAcceptsMatchingMagnet() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "  magnet:?xt=urn:btih:\(normalized.uppercased())&dn=movie  "
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized.uppercased())&dn=movie"
        )
    }

    @Test("preferredMagnetURI accepts non-magnet URL with embedded matching hash")
    func preferredMagnetURIAcceptsNonMagnetURLWithEmbeddedMatchingHash() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "https://tracker.example/t/\(normalized.uppercased())/download"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == supplied
        )
    }

    @Test("preferredMagnetURI accepts non-magnet URL with matching hash in query string")
    func preferredMagnetURIAcceptsNonMagnetURLWithMatchingHashInQuery() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "https://tracker.example/resolve?hash=\(normalized.uppercased())&source=debrid"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == supplied
        )
    }

    @Test("preferredMagnetURI accepts non-magnet URL with matching 64-char hash")
    func preferredMagnetURIAccepts64BitHashInNonMagnetURL() throws {
        let normalized = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        let supplied = "https://tracker.example/resolve/\(normalized)/download"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == supplied
        )
    }

    @Test("preferredMagnetURI accepts uppercase MAGNET scheme")
    func preferredMagnetURIAcceptsUppercaseScheme() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "MAGNET:?xt=urn:btih:\(normalized.uppercased())&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == supplied
        )
    }

    @Test("preferredMagnetURI accepts uppercase XT query key")
    func preferredMagnetURIAcceptsUppercaseXTQueryKey() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "  magnet:?XT=urn:BTIH:\(normalized.uppercased())&dn=movie  "
        let expected = "magnet:?XT=urn:BTIH:\(normalized.uppercased())&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == expected
        )
    }

    @Test("preferredMagnetURI uses BTIH xt value when other xt values are present")
    func preferredMagnetURIPrefersBTIHXT() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let sha1 = String(repeating: "1", count: 40)
        let supplied = "magnet:?xt=urn:sha1:\(sha1)&xt=urn:btih:\(normalized.uppercased())&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == supplied
        )
    }

    @Test("preferredMagnetURI falls back when supplied hash has invalid length")
    func preferredMagnetURIFallsBackForInvalidLengthHashInMagnetInput() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "magnet:?xt=urn:btih:\(String(repeating: "1", count: 32))&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test("preferredMagnetURI falls back when supplied xt has malformed prefix")
    func preferredMagnetURIFallsBackForMalformedXT() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "magnet:?xt=urn:btihx:\(normalized)&dn=movie"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test("preferredMagnetURI falls back when embedded hash does not match")
    func preferredMagnetURIFallsBackForMismatchedEmbeddedHash() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "https://tracker.example/resolve?hash=\("fedcba0987654321fedcba0987654321fedcba09")&source=debrid"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test("preferredMagnetURI falls back for nil or blank supplied URI")
    func preferredMagnetURIFallsBackForMissingSuppliedURI() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let expected = "magnet:?xt=urn:btih:\(normalized)"

        #expect(try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: nil) == expected)
        #expect(try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: "  \n\t  ") == expected)
    }

    @Test("preferredMagnetURI falls back for magnet without xt query item")
    func preferredMagnetURIFallsBackForMagnetWithoutXT() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "magnet:?dn=Movie.Name&tr=udp://tracker.example"

        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }

    @Test("preferredMagnetURI accepts non-magnet text containing matching hash")
    func preferredMagnetURIAcceptsPlainTextContainingMatchingHash() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        let supplied = "mirror hash \(normalized.uppercased()) from provider notes"

        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: supplied)
            == supplied
        )
    }

    @Test("preferredMagnetURI ignores non-magnet garbage input and returns bare hash URI")
    func preferredMagnetURIFallsBackForNonMagnetInput() throws {
        let normalized = "0123456789abcdef0123456789abcdef01234567"
        #expect(
            try DebridMagnetInput.preferredMagnetURI(hash: normalized, suppliedMagnetURI: "not-a-magnet-or-url")
            == "magnet:?xt=urn:btih:\(normalized)"
        )
    }
}
