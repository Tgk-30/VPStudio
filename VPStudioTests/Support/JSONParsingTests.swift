import Foundation
import Testing
@testable import VPStudio

@Suite("JSONParsing")
struct JSONParsingTests {
    @Suite("parseInt")
    struct ParseIntTests {
        @Test func parseIntHandlesInt() {
            #expect(JSONValueParsing.parseInt(42) == 42)
            #expect(JSONValueParsing.parseInt(0) == 0)
            #expect(JSONValueParsing.parseInt(-10) == -10)
        }

        @Test func parseIntHandlesInt64() {
            #expect(JSONValueParsing.parseInt(Int64(42)) == 42)
            #expect(JSONValueParsing.parseInt(Int64(0)) == 0)
            #expect(JSONValueParsing.parseInt(Int64(-10)) == -10)
        }

        @Test func parseIntHandlesDouble() {
            #expect(JSONValueParsing.parseInt(42.0) == 42)
            #expect(JSONValueParsing.parseInt(42.7) == 42)
            #expect(JSONValueParsing.parseInt(0.0) == 0)
        }

        @Test func parseIntHandlesNumericString() {
            #expect(JSONValueParsing.parseInt("42") == 42)
            #expect(JSONValueParsing.parseInt("0") == 0)
            #expect(JSONValueParsing.parseInt("-10") == -10)
        }

        @Test func parseIntHandlesNonNumericString() {
            #expect(JSONValueParsing.parseInt("abc") == nil)
            #expect(JSONValueParsing.parseInt("") == nil)
            #expect(JSONValueParsing.parseInt("42.5") == nil)
        }

        @Test func parseIntHandlesNil() {
            #expect(JSONValueParsing.parseInt(nil) == nil)
        }

        @Test func parseIntHandlesBool() {
            #expect(JSONValueParsing.parseInt(true as Any?) == nil)
            #expect(JSONValueParsing.parseInt(false as Any?) == nil)
        }

        @Test func parseIntReturnsNilForUnsupportedType() {
            #expect(JSONValueParsing.parseInt([1, 2, 3] as Any) == nil)
            #expect(JSONValueParsing.parseInt(["key": "value"] as Any) == nil)
        }
    }

    @Suite("parseInt64")
    struct ParseInt64Tests {
        @Test func parseInt64HandlesInt64() {
            #expect(JSONValueParsing.parseInt64(Int64(42)) == 42)
            #expect(JSONValueParsing.parseInt64(Int64(0)) == 0)
            #expect(JSONValueParsing.parseInt64(Int64(-10)) == -10)
        }

        @Test func parseInt64HandlesInt() {
            #expect(JSONValueParsing.parseInt64(42) == 42)
            #expect(JSONValueParsing.parseInt64(0) == 0)
        }

        @Test func parseInt64HandlesDouble() {
            #expect(JSONValueParsing.parseInt64(42.0) == 42)
            #expect(JSONValueParsing.parseInt64(42.7) == 42)
        }

        @Test func parseInt64HandlesNumericString() {
            #expect(JSONValueParsing.parseInt64("42") == 42)
            #expect(JSONValueParsing.parseInt64("0") == 0)
            #expect(JSONValueParsing.parseInt64("-10") == -10)
        }

        @Test func parseInt64HandlesNonNumericString() {
            #expect(JSONValueParsing.parseInt64("abc") == nil)
            #expect(JSONValueParsing.parseInt64("") == nil)
        }

        @Test func parseInt64HandlesNil() {
            #expect(JSONValueParsing.parseInt64(nil) == nil)
        }

        @Test func parseInt64ReturnsNilForUnsupportedType() {
            #expect(JSONValueParsing.parseInt64([1, 2, 3] as Any) == nil)
            #expect(JSONValueParsing.parseInt64(["key": "value"] as Any) == nil)
        }
    }

    @Suite("extractInfoHash")
    struct ExtractInfoHashTests {
        @Test func extractInfoHashHandlesMagnetURI() {
            let hash = JSONValueParsing.extractInfoHash(from: "magnet:?xt=urn:btih:ABC123DEF4567890ABCDEF1234567890ABCDEF12")?.lowercased()
            #expect(hash == "abc123def4567890abcdef1234567890abcdef12")
        }

        @Test func extractInfoHashHandlesMagnetURICaseInsensitive() {
            let hash1 = JSONValueParsing.extractInfoHash(from: "magnet:?xt=urn:btih:ABC123DEF4567890ABCDEF1234567890ABCDEF12")?.lowercased()
            let hash2 = JSONValueParsing.extractInfoHash(from: "magnet:?xt=urn:BTIH:abc123def4567890abcdef1234567890abcdef12")?.lowercased()
            #expect(hash1 == hash2)
        }

        @Test func extractInfoHashHandlesUppercaseXTQueryParameter() {
            let rawHash = String(repeating: "A", count: 40)
            let hash = JSONValueParsing.extractInfoHash(from: "magnet:?XT=urn:btih:\(rawHash)")
            #expect(hash == rawHash.lowercased())
        }

        @Test func extractInfoHashHandlesMagnetURIWithOtherParams() {
            let hash = JSONValueParsing.extractInfoHash(from: "magnet:?xt=urn:btih:ABC123DEF4567890ABCDEF1234567890ABCDEFFF&dn=some+name&tr=udp://tracker")?.lowercased()
            #expect(hash == "abc123def4567890abcdef1234567890abcdefff")
        }

        @Test func extractInfoHashHandlesNil() {
            #expect(JSONValueParsing.extractInfoHash(from: nil) == nil)
        }

        @Test func extractInfoHashHandlesInvalidMagnet() {
            #expect(JSONValueParsing.extractInfoHash(from: "magnet:?xt=urn:sha1:ABC123DEF4567890ABCDEF1234567890ABCDEFFF") == nil)
            #expect(JSONValueParsing.extractInfoHash(from: "magnet:?xt=urn:btih:") == nil)
            #expect(JSONValueParsing.extractInfoHash(from: "magnet:?xt=urn:btih:abc123def4567890abcdef1234567890") == nil)
        }

        @Test func extractInfoHashHandlesBase32BtihMagnet() {
            // Some Torznab/indexer feeds emit the btih as 32-char RFC 4648 base32;
            // it must decode to canonical 40-hex rather than being dropped.
            let base32AllA = String(repeating: "A", count: 32) // 160 zero bits
            let hash = JSONValueParsing.extractInfoHash(from: "magnet:?xt=urn:btih:\(base32AllA)&dn=name")
            #expect(hash == String(repeating: "0", count: 40))
        }

        @Test func extractInfoHashHandlesTorrentURL() {
            let hash40 = "abc123def456abc123def456abc123def456abcd"
            let hash = JSONValueParsing.extractInfoHash(from: "https://torrent.example/download?hash=\(hash40)&name=test")
            #expect(hash == hash40)
        }

        @Test func extractInfoHashHandlesTorrentURLWithoutQuery() {
            let hash40 = "abc123def456abc123def456abc123def456abcd"
            let hash = JSONValueParsing.extractInfoHash(from: "https://torrent.example/\(hash40)/download")
            #expect(hash == hash40)
        }

        @Test func extractInfoHashFromUppercaseTorrentURLIsLowercased() {
            let hash40 = String(repeating: "A", count: 40)
            let hash = JSONValueParsing.extractInfoHash(from: "https://torrent.example/\(hash40)/download")
            #expect(hash == hash40.lowercased())
        }

        @Test func extractInfoHashHandles64CharacterTorrentURL() {
            let hash64 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
            let hash = JSONValueParsing.extractInfoHash(from: "https://torrent.example/\(hash64)/download")
            #expect(hash == hash64.lowercased())
        }

        @Test func extractInfoHashHandles64CharacterTorrentQueryHashParam() {
            let hash64 = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
            let hash = JSONValueParsing.extractInfoHash(from: "https://torrent.example?info_hash=\(hash64)")
            #expect(hash == hash64)
        }

        @Test func extractInfoHashHandlesUppercaseInfoHashQueryParamKey() {
            let hash40 = "abcdef0123456789abcdef0123456789abcdef01"
            let hash = JSONValueParsing.extractInfoHash(from: "https://torrent.example?INFO_HASH=\(hash40)")
            #expect(hash == hash40)
        }

        @Test func extractInfoHashReturnsNilForInvalidHexCharacters() {
            let invalidHash = "0123456789abcdeg0123456789abcdef0123456789abcdef0123456789abcdef"
            let hash = JSONValueParsing.extractInfoHash(from: "https://torrent.example/\(invalidHash)/download")
            #expect(hash == nil)
        }

        @Test func extractInfoHashReturnsNilForInvalidHexCharactersInQueryValue() {
            let invalidHash = "0123456789abcdgf0123456789abcdef0123456789abcdef0123456789abcdef"
            #expect(JSONValueParsing.extractInfoHash(from: "https://torrent.example?hash=\(invalidHash)") == nil)
            #expect(JSONValueParsing.extractInfoHash(from: "https://torrent.example?info_hash=\(invalidHash)") == nil)
            #expect(JSONValueParsing.extractInfoHash(from: "https://torrent.example?INFO_HASH=\(invalidHash)") == nil)
        }

        @Test func extractInfoHashDoesNotMatchEmbeddedShortHashes() {
            let hash = JSONValueParsing.extractInfoHash(from: "stream_\(String(repeating: "a", count: 40))_ended")
            #expect(hash == nil)
        }

        @Test func extractInfoHashRejectsHashWithInvalidBoundaryCharacters() {
            let hash40 = String(repeating: "a", count: 40)
            let trailing = "https://torrent.example/\(hash40)next"
            #expect(JSONValueParsing.extractInfoHash(from: trailing) == nil)
        }

        @Test func extractInfoHashHandlesInvalidURL() {
            #expect(JSONValueParsing.extractInfoHash(from: "not a magnet or url") == nil)
            #expect(JSONValueParsing.extractInfoHash(from: "") == nil)
        }

        @Test func extractInfoHashReturnsLowercase() {
            let hash = JSONValueParsing.extractInfoHash(from: "magnet:?xt=urn:btih:ABC123DEF4567890ABCDEF1234567890ABCDEFFF")
            #expect(hash == hash?.lowercased())
        }
    }
}
