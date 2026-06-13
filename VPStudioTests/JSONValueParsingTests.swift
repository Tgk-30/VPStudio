import Foundation
import Testing
@testable import VPStudio

@Suite("JSONValueParsing")
struct JSONValueParsingTests {
    // MARK: - parseInt

    @Test
    func parseIntFromInt() {
        let value: Any = 42
        #expect(JSONValueParsing.parseInt(value) == 42)
    }

    @Test
    func parseIntFromString() {
        let value: Any = "123"
        #expect(JSONValueParsing.parseInt(value) == 123)
    }

    @Test
    func parseIntFromDouble() {
        let value: Any = 99.7
        #expect(JSONValueParsing.parseInt(value) == 99)
    }

    @Test
    func parseIntFromNilReturnsNil() {
        #expect(JSONValueParsing.parseInt(nil) == nil)
    }

    // MARK: - parseInt64

    @Test
    func parseInt64FromInt64() {
        let value: Any = Int64(5_000_000_000)
        #expect(JSONValueParsing.parseInt64(value) == 5_000_000_000)
    }

    @Test
    func parseInt64FromString() {
        let value: Any = "9876543210"
        #expect(JSONValueParsing.parseInt64(value) == 9_876_543_210)
    }

    @Test
    func parseInt64FromNilReturnsNil() {
        #expect(JSONValueParsing.parseInt64(nil) == nil)
    }

    // MARK: - extractInfoHash

    @Test
    func extractInfoHashFromValidMagnetURI() {
        let magnet = "magnet:?xt=urn:btih:ABCDEF1234567890ABCDEF1234567890ABCDEF12&dn=Test"
        let hash = JSONValueParsing.extractInfoHash(from: magnet)
        #expect(hash == "abcdef1234567890abcdef1234567890abcdef12")
    }

    @Test
    func extractInfoHashFromMagnetURIPicksBTIHxtWhenMultipleXTValues() {
        let normalizedHash = "abcdef1234567890abcdef1234567890abcdef12"
        let sha1Hash = String(repeating: "b", count: 40)
        let magnet = "magnet:?xt=urn:sha1:\(sha1Hash)&xt=urn:btih:\(normalizedHash.uppercased())&dn=movie"
        let hash = JSONValueParsing.extractInfoHash(from: magnet)
        #expect(hash == normalizedHash)
    }

    @Test
    func extractInfoHashFromMagnetURISelectsFirstValidBTIHWhenInvalidsAppearFirst() {
        let normalizedHash = "abcdef1234567890abcdef1234567890abcdef12"
        let invalidHash = String(repeating: "b", count: 16)
        let magnet = "magnet:?xt=urn:btih:\(invalidHash)&xt=urn:btih:\(normalizedHash.uppercased())"
        let hash = JSONValueParsing.extractInfoHash(from: magnet)
        #expect(hash == normalizedHash)
    }

    @Test
    func extractInfoHashFromInvalidStringReturnsNil() {
        #expect(JSONValueParsing.extractInfoHash(from: "not a magnet link") == nil)
        #expect(JSONValueParsing.extractInfoHash(from: nil) == nil)
        #expect(JSONValueParsing.extractInfoHash(from: "") == nil)
    }

    @Test
    func extractInfoHashFromMagnetURIHandlesUppercaseXtQueryNameAndPrefix() {
        let hash = String(repeating: "c", count: 40)
        let magnet = "magnet:?XT=urn:BTIH:\(hash.uppercased())"
        let extracted = JSONValueParsing.extractInfoHash(from: magnet)
        #expect(extracted == hash)
    }

    @Test
    func extractInfoHashFromURLPathFallback() {
        let torrentURL = "https://torrentio.strem.fun/resolve/realdebrid/0123456789ABCDEF0123456789ABCDEF01234567/magic.mkv"
        let hash = JSONValueParsing.extractInfoHash(from: torrentURL)
        #expect(hash == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test
    func extractInfoHashFrom64BitURLPathFallback() {
        let hash64 = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"
        let torrentURL = "https://torrentio.strem.fun/resolve/realdebrid/\(hash64)/magic.mkv"
        let hash = JSONValueParsing.extractInfoHash(from: torrentURL)
        #expect(hash == "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
    }

    @Test
    func extractInfoHashFromQueryFallback() {
        let torrentURL = "https://cdn.example.com/stream?source=rd&hash=ABCDEF1234567890ABCDEF1234567890ABCDEF12&quality=1080p"
        let hash = JSONValueParsing.extractInfoHash(from: torrentURL)
        #expect(hash == "abcdef1234567890abcdef1234567890abcdef12")
    }

    @Test
    func extractInfoHashFrom64CharacterString() {
        let hash64 = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"
        let torrentURL = "https://cdn.example.com/stream?source=rd&hash=\(hash64)&quality=1080p"
        let hash = JSONValueParsing.extractInfoHash(from: torrentURL)
        #expect(hash == hash64.lowercased())
    }

    @Test
    func extractInfoHashFromQueryHashKey() {
        let torrentURL = "https://cdn.example.com/stream?source=rd&infoHash=ABCDEF1234567890ABCDEF1234567890ABCDEF12&quality=1080p"
        let hash = JSONValueParsing.extractInfoHash(from: torrentURL)
        #expect(hash == "abcdef1234567890abcdef1234567890abcdef12")
    }

    @Test
    func extractInfoHashFromQueryFallbackSkipsInvalidCandidatesBeforeValidOne() {
        let validHash = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
        let torrentURL = "https://cdn.example.com/stream?hash=not-a-hash&info_hash=\(validHash)"
        let hash = JSONValueParsing.extractInfoHash(from: torrentURL)
        #expect(hash == validHash.lowercased())
    }

    @Test
    func extractInfoHashFromQueryFallbackSkipsMissingValueBeforeValidOne() {
        let validHash = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
        let torrentURL = "https://cdn.example.com/stream?hash&source=rd&infohash=\(validHash)"
        let hash = JSONValueParsing.extractInfoHash(from: torrentURL)
        #expect(hash == validHash.lowercased())
    }

    @Test
    func extractInfoHashFromMagnetWithoutQueryItemsReturnsNil() {
        #expect(JSONValueParsing.extractInfoHash(from: "magnet:") == nil)
        #expect(JSONValueParsing.extractInfoHash(from: "magnet:?dn=Movie.Name") == nil)
    }

    @Test
    func extractInfoHashFromRawXTQueryValueFallback() {
        let rawHash = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
        let torrentURL = "https://cdn.example.com/stream?xt=\(rawHash)"
        let hash = JSONValueParsing.extractInfoHash(from: torrentURL)
        #expect(hash == rawHash.lowercased())
    }

    @Test
    func extractInfoHashFromBareHashString() {
        let rawHash = String(repeating: "A", count: 64)
        let hash = JSONValueParsing.extractInfoHash(from: rawHash)
        #expect(hash == rawHash.lowercased())
    }

    @Test
    func extractInfoHashFromTorrentPathWithDotSuffix() {
        let hash = String(repeating: "b", count: 40)
        let torrentURL = "https://cdn.example.com/\(hash).torrent"
        #expect(JSONValueParsing.extractInfoHash(from: torrentURL) == hash.lowercased())
    }

    @Test
    func extractInfoHashFromTorrentPathWithInvalidBoundary() {
        let hash = String(repeating: "f", count: 40)
        let torrentURL = "https://cdn.example.com/\(hash)-release"
        #expect(JSONValueParsing.extractInfoHash(from: torrentURL) == nil)
    }

    @Test
    func extractInfoHashFromPathBoundaryOnlyHash() {
        let torrentURL = "https://cdn.example.com/stream_ABCDEF1234567890ABCDEF1234567890ABCDEF12_end?x=1"
        let hash = JSONValueParsing.extractInfoHash(from: torrentURL)
        #expect(hash == nil)
    }

    @Test
    func parseIntFromWhitespaceStringReturnsNil() {
        #expect(JSONValueParsing.parseInt(" 123 ") == nil)
    }

    @Test
    func parseIntFromBooleanReturnsNil() {
        #expect(JSONValueParsing.parseInt(true as Any) == nil)
    }

    @Test
    func parseIntFromEmptyStringReturnsNil() {
        #expect(JSONValueParsing.parseInt("") == nil)
    }

    @Test
    func parseIntFromInt64ReturnsIntValue() {
        #expect(JSONValueParsing.parseInt(Int64(123)) == 123)
    }

    @Test
    func parseIntFromNegativeString() {
        #expect(JSONValueParsing.parseInt("-12") == -12)
    }

    @Test
    func parseInt64FromIntReturnsValue() {
        #expect(JSONValueParsing.parseInt64(12 as Any) == 12)
    }

    @Test
    func parseInt64FromNegativeIntReturnsValue() {
        #expect(JSONValueParsing.parseInt64(-9 as Any) == -9)
    }

    @Test
    func parseInt64FromNegativeDoubleRoundsTowardZero() {
        #expect(JSONValueParsing.parseInt64(-12.9 as Any) == -12)
    }

    @Test
    func parseInt64FromPositiveDoubleRoundsTowardZero() {
        #expect(JSONValueParsing.parseInt64(42.8 as Any) == 42)
    }

    @Test
    func parseInt64FromFloatingStringReturnsNil() {
        #expect(JSONValueParsing.parseInt64("12.34") == nil)
    }

    @Test
    func parseInt64FromHexStringReturnsNil() {
        #expect(JSONValueParsing.parseInt64("abcdef0123456789") == nil)
    }

    @Test
    func parseInt64FromBooleanReturnsNil() {
        #expect(JSONValueParsing.parseInt64(false as Any) == nil)
    }

    @Test
    func extractInfoHashFromQueryFallbackMatchesKeyCaseInsensitively() {
        let rawHash = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
        let torrentURL = "https://cdn.example.com/stream?source=rd&INFO_HASH=\(rawHash)"
        #expect(JSONValueParsing.extractInfoHash(from: torrentURL) == rawHash.lowercased())
    }

    @Test
    func extractInfoHashRejectsInvalidBTIHHexCandidate() {
        let invalidHash = String(repeating: "a", count: 39) + "g"
        let magnet = "magnet:?xt=urn:btih:\(invalidHash)"
        #expect(JSONValueParsing.extractInfoHash(from: magnet) == nil)
    }

    @Test(arguments: [
        "https://cdn.example.com/stream?q=ABCDEF1234567890ABCDEF1234567890ABCDEF12&x=1",
        "https://cdn.example.com/stream#ABCDEF1234567890ABCDEF1234567890ABCDEF12",
        "https://cdn.example.com/a?x=1#ABCDEF1234567890ABCDEF1234567890ABCDEF12?next",
    ])
    func extractInfoHashFromRegexFallbackWithValidDelimiters(url: String) {
        #expect(JSONValueParsing.extractInfoHash(from: url) == "abcdef1234567890abcdef1234567890abcdef12")
    }

    @Test
    func extractInfoHashRejectsOverlongHexRunWithoutBoundary() {
        let overlongHash = String(repeating: "a", count: 65)
        #expect(JSONValueParsing.extractInfoHash(from: overlongHash) == nil)
    }

    @Test
    func extractInfoHashFromTorrentPathWithInvalidSuffixBoundary() {
        let hash = String(repeating: "e", count: 40)
        let torrentURL = "https://cdn.example.com/archive_\(hash).mkv"
        #expect(JSONValueParsing.extractInfoHash(from: torrentURL) == nil)
    }

    @Test
    func extractInfoHashFromTorrentPathWithUppercaseDotTorrentSuffix() {
        let hash = String(repeating: "F", count: 40)
        let torrentURL = "https://cdn.example.com/\(hash).TORRENT"
        #expect(JSONValueParsing.extractInfoHash(from: torrentURL) == hash.lowercased())
    }
}
