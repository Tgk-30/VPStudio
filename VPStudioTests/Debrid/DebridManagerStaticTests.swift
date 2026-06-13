import Foundation
import Testing
@testable import VPStudio

// MARK: - normalizedCacheHashes

@Suite("DebridManagerNormalizedCacheHashes")
struct DebridManagerNormalizedCacheHashesTests {

    @Test func normalizesToLowercase() {
        let input = ["ABC123", "DEF456"]
        let result = DebridManager.normalizedCacheHashes(input)
        #expect(result == ["abc123", "def456"])
    }

    @Test func trimsWhitespace() {
        let input = ["  abc123  ", "def456"]
        let result = DebridManager.normalizedCacheHashes(input)
        #expect(result == ["abc123", "def456"])
    }

    @Test func removesEmptyStrings() {
        let input = ["abc123", "", "   ", "def456"]
        let result = DebridManager.normalizedCacheHashes(input)
        #expect(result == ["abc123", "def456"])
    }

    @Test func deduplicatesKeepingFirstOccurrence() {
        let input = ["abc123", "def456", "abc123", "ghi789"]
        let result = DebridManager.normalizedCacheHashes(input)
        #expect(result == ["abc123", "def456", "ghi789"])
    }

    @Test func preservesOriginalOrder() {
        let input = ["zzz", "aaa", "bbb"]
        let result = DebridManager.normalizedCacheHashes(input)
        #expect(result == ["zzz", "aaa", "bbb"])
    }

    @Test func deduplicatesAfterNormalization() {
        let input = ["  ABC123 ", "abc123", "AbCdEf", "abcdef", "  123456", "123456"]
        let result = DebridManager.normalizedCacheHashes(input)
        #expect(result == ["abc123", "abcdef", "123456"])
    }

    @Test func emptyInputReturnsEmpty() {
        let result = DebridManager.normalizedCacheHashes([])
        #expect(result.isEmpty)
    }

    @Test func allInvalidInputReturnsEmpty() {
        let input = ["", "   ", "\t\n"]
        let result = DebridManager.normalizedCacheHashes(input)
        #expect(result.isEmpty)
    }
}

// MARK: - chunked

@Suite("DebridManagerChunked")
struct DebridManagerChunkedTests {

    @Test func chunksArrayToSpecifiedSize() {
        let input = Array(1...10)
        let result = DebridManager.chunked(input.map(String.init), size: 3)
        #expect(result.count == 4)
        #expect(result[0] == ["1", "2", "3"])
        #expect(result[1] == ["4", "5", "6"])
        #expect(result[2] == ["7", "8", "9"])
        #expect(result[3] == ["10"])
    }

    @Test func exactMultipleHasNoRemainder() {
        let input = Array(1...9)
        let result = DebridManager.chunked(input.map(String.init), size: 3)
        #expect(result.count == 3)
        #expect(result[2] == ["7", "8", "9"])
    }

    @Test func chunkSizeLargerThanArray() {
        let input = ["a", "b"]
        let result = DebridManager.chunked(input, size: 10)
        #expect(result.count == 1)
        #expect(result[0] == ["a", "b"])
    }

    @Test func emptyArrayReturnsEmpty() {
        let result = DebridManager.chunked([], size: 5)
        #expect(result.isEmpty)
    }

    @Test func zeroSizeReturnsEmpty() {
        let result = DebridManager.chunked(["a", "b"], size: 0)
        #expect(result.isEmpty)
    }

    @Test func negativeSizeReturnsEmpty() {
        let result = DebridManager.chunked(["a", "b"], size: -1)
        #expect(result.isEmpty)
    }

    @Test func singleElementArray() {
        let result = DebridManager.chunked(["solo"], size: 5)
        #expect(result.count == 1)
        #expect(result[0] == ["solo"])
    }
}
