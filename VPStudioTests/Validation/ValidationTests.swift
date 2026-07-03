import Foundation
import Testing
@testable import VPStudio

// MARK: - DebridHashValidator Tests

@Suite("DebridHashValidator")
struct DebridHashValidatorValidationTests {

    @Test func normalizedInfoHashAccepts40CharLowercaseHex() {
        let hash = "0123456789abcdef0123456789abcdef01234567"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == hash)
    }

    @Test func normalizedInfoHashAccepts40CharUppercaseHex() {
        let hash = "0123456789ABCDEF0123456789ABCDEF01234567"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test func normalizedInfoHashAccepts64CharLowercaseHex() {
        let hash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == hash)
    }

    @Test func normalizedInfoHashAccepts64CharUppercaseHex() {
        let hash = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == hash.lowercased())
    }

    @Test func normalizedInfoHashTrimsLeadingWhitespace() {
        let hash = "   0123456789abcdef0123456789abcdef01234567"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test func normalizedInfoHashTrimsTrailingWhitespace() {
        let hash = "0123456789abcdef0123456789abcdef01234567   "
        #expect(DebridHashValidator.normalizedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test func normalizedInfoHashTrimsBothSides() {
        let hash = "  \t  0123456789abcdef0123456789abcdef01234567  \n  "
        #expect(DebridHashValidator.normalizedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test func normalizedInfoHashTrimsNewlines() {
        let hash = "0123456789abcdef0123456789abcdef01234567\n"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test func normalizedInfoHashRejects39CharHash() {
        #expect(DebridHashValidator.normalizedInfoHash("0123456789abcdef0123456789abcdef0123456") == nil)
    }

    @Test func normalizedInfoHashRejects41CharHash() {
        #expect(DebridHashValidator.normalizedInfoHash("0123456789abcdef0123456789abcdef012345678") == nil)
    }

    @Test func normalizedInfoHashRejects63CharHash() {
        #expect(DebridHashValidator.normalizedInfoHash("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcde") == nil)
    }

    @Test func normalizedInfoHashRejects65CharHash() {
        #expect(DebridHashValidator.normalizedInfoHash("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0") == nil)
    }

    @Test func normalizedInfoHashRejectsEmptyString() {
        #expect(DebridHashValidator.normalizedInfoHash("") == nil)
    }

    @Test func normalizedInfoHashRejectsWhitespaceOnly() {
        #expect(DebridHashValidator.normalizedInfoHash("   \t\n   ") == nil)
    }

    @Test func normalizedInfoHashRejectsNonHexCharacters() {
        #expect(DebridHashValidator.normalizedInfoHash("ghijklmnopghijklmnopghijklmnopghijklmnop") == nil)
    }

    @Test func normalizedInfoHashRejectsMixedInvalidCharacters() {
        #expect(DebridHashValidator.normalizedInfoHash("0123456789abcdef0123456789abcdef0123456z") == nil)
    }

    @Test func normalizedInfoHashRejectsHashWithSpaces() {
        #expect(DebridHashValidator.normalizedInfoHash("01234567 89abcdef 01234567 89abcdef 01234567") == nil)
    }

    @Test func validatedInfoHashReturnsNormalizedHash() throws {
        let hash = "  0123456789abcdef0123456789abcdef01234567  "
        #expect(try DebridHashValidator.validatedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test func validatedInfoHashThrowsOnEmpty() throws(DebridError) {
        do {
            _ = try DebridHashValidator.validatedInfoHash("")
        } catch DebridError.invalidHash(let hash) {
            #expect(hash == "")
        } catch {
            // Unexpected error
        }
    }

    @Test func validatedInfoHashThrowsOnInvalid() throws(DebridError) {
        do {
            _ = try DebridHashValidator.validatedInfoHash("not-a-valid-hash")
        } catch DebridError.invalidHash {
            // Expected
        } catch {
            // Unexpected error
        }
    }

    @Test func normalizedInfoHashWithMixedCaseValidHex() {
        let hash = "0123456789AbCdEf0123456789AbCdEf01234567"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }
}

// MARK: - IndexerLogSanitizer URL Redaction Tests

@Suite("IndexerLogSanitizer - URL Redaction")
struct IndexerLogSanitizerURLRedactionTests {

    @Test func redactedURLStringReturnsNilForNil() {
        #expect(IndexerLogSanitizer.redactedURLString(nil) == "nil")
    }

    @Test func redactedURLStringReturnsNilForEmpty() {
        #expect(IndexerLogSanitizer.redactedURLString("") == "nil")
    }

    @Test func redactedURLStringRedactsInvalidURL() {
        #expect(IndexerLogSanitizer.redactedURLString("not-a-valid-url") == "REDACTED")
    }

    @Test func redactedURLRedactsUserInfo() {
        let url = URL(string: "https://user:password@example.com/path")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(!redacted.contains("password"))
        #expect(!redacted.contains("user"))
        #expect(redacted.contains("REDACTED"))
    }

    @Test func redactedURLPreservesHost() {
        let url = URL(string: "https://user:secret@example.com/path")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("example.com"))
    }

    @Test func redactedURLRedactsSensitiveQueryParams() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.example.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: "movie"),
            URLQueryItem(name: "api_key", value: "secret123"),
            URLQueryItem(name: "access_token", value: "token1234567890"),
        ]
        let url = components.url!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("q=movie"))
        #expect(redacted.contains("api_key=REDACTED"))
        #expect(redacted.contains("access_token=REDACTED"))
        #expect(!redacted.contains("secret123"))
    }

    @Test func redactedURLRedactsAllSensitiveQueryNames() {
        let sensitiveNames = ["access_token", "api_key", "apikey", "auth", "authorization",
                              "jwt", "key", "pass", "password", "refresh_token", "sig",
                              "signature", "token"]
        for name in sensitiveNames {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "example.com"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: name, value: "secret-value-12345")]
            let url = components.url!
            let redacted = IndexerLogSanitizer.redactedURL(url)
            #expect(redacted.contains("\(name)=REDACTED"), "Failed for \(name)")
        }
    }

    @Test func redactedURLPreservesNonSensitiveQueryParams() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: "movie"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "limit", value: "50"),
        ]
        let url = components.url!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("q=movie"))
        #expect(redacted.contains("page=1"))
        #expect(redacted.contains("limit=50"))
    }

    @Test func redactedURLRemovesFragment() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.path = "/search"
        components.fragment = "section"
        let url = components.url!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(!redacted.contains("#"))
    }

    @Test func redactedURLHandlesMagnetURIs() {
        let magnet = "magnet:?xt=urn:btih:abc123def456&dn=Movie+Name"
        let result = IndexerLogSanitizer.redactedURLString(magnet)
        #expect(result.contains("magnet"))
        #expect(result.contains("abc123def456"))
    }

    @Test func redactedURLHandlesHTTPUrl() {
        let url = URL(string: "http://example.com/path")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("example.com"))
        #expect(redacted.contains("http://"))
    }

    @Test func redactedURLWithPercentEncodedPath() {
        let url = URL(string: "https://example.com/search/Movie%20Name%202023")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("Movie"))
        #expect(redacted.contains("Name"))
        #expect(redacted.contains("2023"))
    }

    @Test func redactedURLWithEmptyUser() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.user = ""
        components.path = "/api"
        let url = components.url!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(!redacted.contains("user"))
    }

    @Test func redactedURLWithEmptyPassword() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.password = ""
        components.path = "/api"
        let url = components.url!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(!redacted.contains("password"))
    }

    @Test func redactedURLWithNoComponentsReturnsUnknown() {
        let url = URL(string: "invalid-url-without-scheme")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted == "<redacted-url>")
    }
}

// MARK: - IndexerLogSanitizer Path Sanitization Tests

@Suite("IndexerLogSanitizer - Path Sanitization")
struct IndexerLogSanitizerPathSanitizationTests {

    @Test func redactedURLPreservesNormalPathSegments() {
        let url = URL(string: "https://example.com/api/v3/movie/popular")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("/api/v3/movie/popular"))
    }

    @Test func redactedURLRedactsLongTokenLikePathSegments() {
        let url = URL(string: "https://indexer.example.com/api/v1/abcdef1234567890abcdef/search")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("REDACTED"))
        #expect(!redacted.contains("abcdef1234567890abcdef"))
    }

    @Test func redactedURLPreservesShortPathSegments() {
        let url = URL(string: "https://example.com/api/v3/movie")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("/movie"))
        #expect(!redacted.contains("REDACTED"))
    }

    @Test func redactedURLRedactsAllLongSegmentsInPath() {
        let url = URL(string: "https://example.com/api/v3/abcdefghijklmnopqrstuvwxyz/zyxwvutsrqponmlkjihgfedcba")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("REDACTED"))
    }

    @Test func redactedURLEncodesPercentInPathSegments() {
        let url = URL(string: "https://example.com/path/with%20spaces/file")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("path"))
    }
}

// MARK: - IndexerLogSanitizer Query Value Sanitization Tests

@Suite("IndexerLogSanitizer - Query Value Sanitization")
struct IndexerLogSanitizerQueryValueSanitizationTests {

    @Test func redactedURLRedactsLongQueryValues() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "token", value: "abcdefghijklmnopqrstuvwxyz"),
        ]
        let url = components.url!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("token=REDACTED"))
        #expect(!redacted.contains("abcdefghijklmnopqrstuvwxyz"))
    }

    @Test func redactedURLPreservesShortQueryValues() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: "abc"),
            URLQueryItem(name: "page", value: "1"),
        ]
        let url = components.url!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("q=abc"))
        #expect(redacted.contains("page=1"))
        #expect(!redacted.contains("REDACTED"))
    }

    @Test func redactedURLRedactsJWTInQuery() {
        let jwtURL = "https://api.example.com/auth?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4ifQ.abcdefghijklmnopqrstuvwxyz"
        let redacted = IndexerLogSanitizer.redactedURLString(jwtURL)
        #expect(redacted.contains("REDACTED"))
        #expect(!redacted.contains("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"))
    }

    @Test func redactedURLRedactsMultipleSensitiveParams() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.example.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "api_key", value: "key1"),
            URLQueryItem(name: "sig", value: "signature1234567890"),
            URLQueryItem(name: "pass", value: "password123"),
        ]
        let url = components.url!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("api_key=REDACTED"))
        #expect(redacted.contains("sig=REDACTED"))
        #expect(redacted.contains("pass=REDACTED"))
        #expect(!redacted.contains("key1"))
        #expect(!redacted.contains("signature1234567890"))
        #expect(!redacted.contains("password123"))
    }

    @Test func redactedURLWithNilQueryValue() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "key", value: nil),
        ]
        let url = components.url!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("key"))
    }
}

// MARK: - IndexerLogSanitizer Error Message Sanitization Tests

@Suite("IndexerLogSanitizer - Error Message Sanitization")
struct IndexerLogSanitizerErrorMessageTests {

    @Test func redactedErrorMessageRemovesURLs() {
        struct SampleError: LocalizedError {
            var errorDescription: String? {
                "Failed to fetch https://api.example.com?api_key=secret from server"
            }
        }
        let sanitized = IndexerLogSanitizer.redactedErrorMessage(SampleError())
        #expect(!sanitized.contains("secret"))
        #expect(sanitized.contains("api.example.com"))
    }

    @Test func redactedErrorMessageRemovesCredentials() {
        struct SampleError: LocalizedError {
            var errorDescription: String? {
                "Auth failed for https://user:password@api.example.com/path"
            }
        }
        let sanitized = IndexerLogSanitizer.redactedErrorMessage(SampleError())
        #expect(!sanitized.contains("password"))
        #expect(!sanitized.contains("user"))
    }

    @Test func redactedErrorMessageWithMultipleURLs() {
        struct SampleError: LocalizedError {
            var errorDescription: String? {
                "Failed https://api1.example.com?token=secret1 and https://api2.example.com?token=secret2"
            }
        }
        let sanitized = IndexerLogSanitizer.redactedErrorMessage(SampleError())
        #expect(!sanitized.contains("secret1"))
        #expect(!sanitized.contains("secret2"))
        #expect(sanitized.contains("api1.example.com"))
        #expect(sanitized.contains("api2.example.com"))
    }

    @Test func redactedErrorMessageWithEmptyDescription() {
        struct NilError: LocalizedError {
            var errorDescription: String? { "" }
        }
        let sanitized = IndexerLogSanitizer.redactedErrorMessage(NilError())
        #expect(sanitized == "")
    }

    @Test func redactedErrorMessagePreservesNonURLText() {
        struct SampleError: LocalizedError {
            var errorDescription: String? {
                "Connection failed: server unreachable"
            }
        }
        let sanitized = IndexerLogSanitizer.redactedErrorMessage(SampleError())
        #expect(sanitized.contains("Connection failed"))
        #expect(sanitized.contains("server unreachable"))
    }

    @Test func redactedErrorMessageWithMagnetURI() {
        struct SampleError: LocalizedError {
            var errorDescription: String? {
                "Invalid magnet: magnet:?xt=urn:btih:secretinfo&dn=Movie"
            }
        }
        let sanitized = IndexerLogSanitizer.redactedErrorMessage(SampleError())
        #expect(sanitized.contains("magnet"))
        #expect(sanitized.contains("Movie"))
    }

    @Test func redactedErrorMessageWithLongTokens() {
        struct SampleError: Error {
            var localizedDescription: String {
                "Error at https://api.example.com/path?token=verylongtoken1234567890abcdefghijklmnop"
            }
        }
        let sanitized = IndexerLogSanitizer.redactedErrorMessage(SampleError())
        #expect(!sanitized.contains("verylongtoken1234567890abcdefghijklmnop"))
    }
}

// MARK: - IndexerLogSanitizer Token Pattern Tests

@Suite("IndexerLogSanitizer - Token Pattern Detection")
struct IndexerLogSanitizerTokenPatternTests {

    @Test func looksSensitiveReturnsFalseForShortString() {
        let short = "abc123"
        #expect(IndexerLogSanitizer.redactedURLString(short) == short)
    }

    @Test func looksSensitiveReturnsTrueForVeryLongString() {
        let longToken = String(repeating: "X", count: 100)
        #expect(IndexerLogSanitizer.redactedURLString(longToken) == "REDACTED")
    }

    @Test func looksSensitiveReturnsTrueForLongAlphanumericString() {
        let token = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-_~"
        #expect(IndexerLogSanitizer.redactedURLString(token) == "REDACTED")
    }

    @Test func looksSensitivePreservesUrlsWithinNormalLength() {
        let url = "https://example.com/path/abc"
        #expect(IndexerLogSanitizer.redactedURLString(url).contains("example.com"))
    }
}

// MARK: - RetryHeaderDateParser Tests

@Suite("RetryHeaderDateParser")
struct RetryHeaderDateParserValidationTests {

    private struct ExposedRetryHeaderDateParser {
        static let formatters: [DateFormatter] = {
            let formatter1 = DateFormatter()
            formatter1.locale = Locale(identifier: "en_US_POSIX")
            formatter1.timeZone = TimeZone(secondsFromGMT: 0)
            formatter1.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"

            let formatter2 = DateFormatter()
            formatter2.locale = Locale(identifier: "en_US_POSIX")
            formatter2.timeZone = TimeZone(secondsFromGMT: 0)
            formatter2.dateFormat = "EEEE',' dd-MMM-yy HH':'mm':'ss zzz"

            let formatter3 = DateFormatter()
            formatter3.locale = Locale(identifier: "en_US_POSIX")
            formatter3.timeZone = TimeZone(secondsFromGMT: 0)
            formatter3.dateFormat = "EEE MMM d HH':'mm':'ss yyyy"

            return [formatter1, formatter2, formatter3]
        }()

        func date(from value: String) -> Date? {
            for formatter in Self.formatters {
                if let date = formatter.date(from: value) {
                    return date
                }
            }
            return nil
        }
    }

    private func makeParser() -> ExposedRetryHeaderDateParser {
        ExposedRetryHeaderDateParser()
    }

    @Test func parsesRFC1123Format() {
        let dateString = "Wed, 01 Jan 2025 12:30:00 GMT"
        let result = makeParser().date(from: dateString)
        #expect(result != nil)
    }

    @Test func parsesAlternateRFC1123Format() {
        let dateString = "Wednesday, 01-Jan-25 12:30:00 GMT"
        let result = makeParser().date(from: dateString)
        #expect(result != nil)
    }

    @Test func parsesASCIICtimeFormat() {
        let dateString = "Wed Jan  1 12:30:00 2025"
        let result = makeParser().date(from: dateString)
        #expect(result != nil)
    }

    @Test func returnsNilForInvalidDateString() {
        let invalidDate = "not a valid date"
        let result = makeParser().date(from: invalidDate)
        #expect(result == nil)
    }

    @Test func returnsNilForEmptyString() {
        let result = makeParser().date(from: "")
        #expect(result == nil)
    }

    @Test func parsesDateStringWithSingleDigitDay() {
        let dateString = "Wed, 1 Jan 2025 12:30:00 GMT"
        let result = makeParser().date(from: dateString)
        #expect(result != nil)
    }
}

// MARK: - SubtitleParser Newline Normalization Tests

@Suite("SubtitleParser - Newline Normalization")
struct SubtitleParserNewlineNormalizationTests {

    @Test func normalizesCRLFToLF() {
        let content = "Line 1\r\nLine 2\r\nLine 3"
        let normalized = normalizeNewlines(content)
        #expect(!normalized.contains("\r"))
    }

    @Test func normalizesCRToLF() {
        let content = "Line 1\rLine 2\rLine 3"
        let normalized = normalizeNewlines(content)
        #expect(normalized.contains("\n"))
        #expect(!normalized.contains("\r\n"))
    }

    @Test func preservesExistingLF() {
        let content = "Line 1\nLine 2\nLine 3"
        let normalized = normalizeNewlines(content)
        #expect(normalized == content)
    }

    @Test func handlesMixedNewlines() {
        let content = "Line 1\r\nLine 2\rLine 3\nLine 4"
        let normalized = normalizeNewlines(content)
        #expect(!normalized.contains("\r"))
    }

    @Test func trimsBOMFromStart() {
        let content = "\u{feff}WEBVTT\n\n00:00:01.000 --> 00:00:03.000\nTest"
        let normalized = normalizeNewlines(content)
        #expect(!normalized.hasPrefix("\u{feff}"))
    }

    @Test func doesNotTrimBOMFromMiddle() {
        let content = "Text\u{feff}Middle\u{feff}End"
        let normalized = normalizeNewlines(content)
        #expect(normalized == content)
    }

    @Test func handlesEmptyString() {
        let normalized = normalizeNewlines("")
        #expect(normalized == "")
    }

    @Test func handlesStringWithOnlyWhitespace() {
        let content = "   \t\n\r  "
        let normalized = normalizeNewlines(content)
        #expect(normalized.contains(" "))
        #expect(normalized.contains("\t"))
    }
}

// MARK: - SubtitleParser Time Parsing Tests

@Suite("SubtitleParser - Time Parsing")
struct SubtitleParserTimeParsingTests {

    @Test func parseSRTTimeHandlesCommaDecimal() {
        let timeString = "01:23:45,678"
        let result = parseSRTTime(timeString)
        #expect(result != nil)
        #expect(abs(result! - (1*3600 + 23*60 + 45.678)) < 0.001)
    }

    @Test func parseSRTTimeHandlesDotDecimal() {
        let timeString = "01:23:45.678"
        let result = parseSRTTime(timeString)
        #expect(result != nil)
        #expect(abs(result! - (1*3600 + 23*60 + 45.678)) < 0.001)
    }

    @Test func parseSRTTimeHandlesZeroHours() {
        let timeString = "00:05:30,000"
        let result = parseSRTTime(timeString)
        #expect(result != nil)
        #expect(abs(result! - 330.0) < 0.001)
    }

    @Test func parseSRTTimeReturnsNilForInvalidFormat() {
        #expect(parseSRTTime("invalid") == nil)
    }

    @Test func parseSRTTimeReturnsNilForMissingColons() {
        #expect(parseSRTTime("12345") == nil)
    }

    @Test func parseVTTTimeHandlesHourFormat() {
        let timeString = "01:23:45.678"
        let result = parseVTTTime(timeString)
        #expect(result != nil)
        #expect(abs(result! - (1*3600 + 23*60 + 45.678)) < 0.001)
    }

    @Test func parseVTTTimeHandlesMinuteFormat() {
        let timeString = "01:23.456"
        let result = parseVTTTime(timeString)
        #expect(result != nil)
        #expect(abs(result! - (1*60 + 23.456)) < 0.001)
    }

    @Test func parseASSTimeHandlesStandardFormat() {
        let timeString = "1:23:45.67"
        let result = parseASSTime(timeString)
        #expect(result != nil)
        #expect(abs(result! - (1*3600 + 23*60 + 45.67)) < 0.01)
    }

    @Test func parseColonTimeHandles3Parts() {
        let result = parseColonTime("1:30:45.5")
        #expect(result != nil)
        #expect(abs(result! - (1*3600 + 30*60 + 45.5)) < 0.001)
    }

    @Test func parseColonTimeHandles2Parts() {
        let result = parseColonTime("5:30.5")
        #expect(result != nil)
        #expect(abs(result! - (5*60 + 30.5)) < 0.001)
    }

    @Test func parseColonTimeReturnsNilForSinglePart() {
        #expect(parseColonTime("123") == nil)
    }

    @Test func parseColonTimeReturnsNilForNonNumeric() {
        #expect(parseColonTime("a:b:c") == nil)
    }
}

// MARK: - CSV Parsing Tests

@Suite("CSV Parsing")
struct CSVLineParsingTests {

    @Test func parseCSVLineHandlesEmptyLine() {
        let result = parseCSVLine("")
        #expect(result == [""])
    }

    @Test func parseCSVLineHandlesSimpleFields() {
        let result = parseCSVLine("field1,field2,field3")
        #expect(result.count == 3)
        #expect(result[0] == "field1")
        #expect(result[1] == "field2")
        #expect(result[2] == "field3")
    }

    @Test func parseCSVLineHandlesQuotedFields() {
        let result = parseCSVLine("\"field1\",\"field2\",\"field3\"")
        #expect(result.count == 3)
        #expect(result[0] == "field1")
        #expect(result[1] == "field2")
        #expect(result[2] == "field3")
    }

    @Test func parseCSVLineHandlesMixedQuotedAndUnquoted() {
        let result = parseCSVLine("field1,\"field,with,commas\",field3")
        #expect(result.count == 3)
        #expect(result[0] == "field1")
        #expect(result[1] == "field,with,commas")
        #expect(result[2] == "field3")
    }

    @Test func parseCSVLineHandlesEmptyQuotedField() {
        let result = parseCSVLine("field1,\"\",field3")
        #expect(result.count == 3)
        #expect(result[1] == "")
    }

    @Test func parseCSVLineHandlesFieldsWithQuotes() {
        let result = parseCSVLine("\"He said \"\"hello\"\"\",\"world\"")
        #expect(result.count == 2)
        #expect(result[0] == "He said \"hello\"")
        #expect(result[1] == "world")
    }

    @Test func parseCSVLineHandlesLeadingTrailingSpaces() {
        let result = parseCSVLine("  field1  ,  field2  ")
        #expect(result.count == 2)
        #expect(result[0] == "  field1  ")
        #expect(result[1] == "  field2  ")
    }

    @Test func parseCSVLineHandlesSingleField() {
        let result = parseCSVLine("singlefield")
        #expect(result.count == 1)
        #expect(result[0] == "singlefield")
    }

    @Test func parseCSVLineHandlesTrailingComma() {
        let result = parseCSVLine("field1,field2,")
        #expect(result.count == 3)
        #expect(result[2] == "")
    }

    @Test func parseCSVLineHandlesLeadingComma() {
        let result = parseCSVLine(",field1,field2")
        #expect(result.count == 3)
        #expect(result[0] == "")
    }
}

// MARK: - Validation Boundary Tests

@Suite("Validation Boundary Tests")
struct ValidationBoundaryTests {

    @Test func hashValidatorBoundary39Chars() {
        let hash39 = String(repeating: "a", count: 39)
        #expect(DebridHashValidator.normalizedInfoHash(hash39) == nil)
    }

    @Test func hashValidatorBoundary40Chars() {
        let hash40 = String(repeating: "a", count: 40)
        #expect(DebridHashValidator.normalizedInfoHash(hash40) != nil)
    }

    @Test func hashValidatorBoundary41Chars() {
        let hash41 = String(repeating: "a", count: 41)
        #expect(DebridHashValidator.normalizedInfoHash(hash41) == nil)
    }

    @Test func hashValidatorBoundary63Chars() {
        let hash63 = String(repeating: "a", count: 63)
        #expect(DebridHashValidator.normalizedInfoHash(hash63) == nil)
    }

    @Test func hashValidatorBoundary64Chars() {
        let hash64 = String(repeating: "a", count: 64)
        #expect(DebridHashValidator.normalizedInfoHash(hash64) != nil)
    }

    @Test func hashValidatorBoundary65Chars() {
        let hash65 = String(repeating: "a", count: 65)
        #expect(DebridHashValidator.normalizedInfoHash(hash65) == nil)
    }

    @Test func urlRedactionBoundary15CharToken() {
        let token15 = String(repeating: "a", count: 15)
        let result = IndexerLogSanitizer.redactedURLString(token15)
        #expect(result == token15)
    }

    @Test func urlRedactionBoundary16CharToken() {
        let token16 = String(repeating: "a", count: 16)
        let result = IndexerLogSanitizer.redactedURLString(token16)
        #expect(result == "REDACTED")
    }
}

// MARK: - Unicode Handling Tests

@Suite("Unicode Handling Tests")
struct UnicodeHandlingTests {

    @Test func hashValidatorHandlesUnicodeInInvalidHash() {
        let hash = "abc123def456\u{4e2d}\u{6587}abc123def456abc"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == nil)
    }

    @Test func subtitleParserHandlesUnicodeText() {
        let content = """
        1
        00:00:01,000 --> 00:00:03,000
        日本語テスト
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "日本語テスト")
    }

    @Test func subtitleParserHandlesEmoji() {
        let content = """
        1
        00:00:01,000 --> 00:00:03,000
        Hello 👋 world 🌍
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Hello 👋 world 🌍")
    }

    @Test func subtitleParserHandlesMixedUnicode() {
        let content = """
        1
        00:00:01,000 --> 00:00:03,000
        English 中文 日本語 한국어 😀🎬
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text.contains("English"))
        #expect(cues[0].text.contains("中文"))
    }

    @Test func URLRedactionHandlesUnicodeInPath() {
        let url = URL(string: "https://example.com/path/日本語")!
        let redacted = IndexerLogSanitizer.redactedURL(url)
        #expect(redacted.contains("example.com"))
    }

    @Test func subtitleParserHandlesRightToLeftText() {
        let content = """
        1
        00:00:01,000 --> 00:00:03,000
        مرحبا بالعالم
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text == "مرحبا بالعالم")
    }

    @Test func subtitleParserHandlesCombiningCharacters() {
        let content = """
        1
        00:00:01,000 --> 00:00:03,000
        ÅÅÅÅÅ
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text.contains("Å"))
    }
}

// MARK: - Whitespace Handling Tests

@Suite("Whitespace Handling Tests")
struct WhitespaceHandlingTests {

    @Test func hashValidatorTrimsTabs() {
        let hash = "\t0123456789abcdef0123456789abcdef01234567\t"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test func hashValidatorTrimsNewlines() {
        let hash = "0123456789abcdef0123456789abcdef01234567\n"
        #expect(DebridHashValidator.normalizedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test func hashValidatorTrimsMixedWhitespace() {
        let hash = " \t\n  0123456789abcdef0123456789abcdef01234567  \n\t "
        #expect(DebridHashValidator.normalizedInfoHash(hash) == "0123456789abcdef0123456789abcdef01234567")
    }

    @Test func subtitleParserTrimsWhitespaceInCueText() {
        let content = """
        1
        00:00:01,000 --> 00:00:03,000
           Leading and trailing spaces
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text.contains("Leading"))
    }

    @Test func subtitleParserHandlesMultipleSpacesInText() {
        let content = """
        1
        00:00:01,000 --> 00:00:03,000
        Multiple   spaces   here
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].text.contains("Multiple"))
    }
}

// MARK: - Invalid Input Handling Tests

@Suite("Invalid Input Handling Tests")
struct InvalidInputHandlingTests {

    @Test func subtitleParserHandlesEmptySRT() {
        let cues = SubtitleParser.parseSRT("")
        #expect(cues.isEmpty)
    }

    @Test func subtitleParserHandlesGarbageContent() {
        let cues = SubtitleParser.parseSRT("This is not a subtitle file at all")
        #expect(cues.isEmpty)
    }

    @Test func subtitleParserHandlesMissingTimestampSeparator() {
        let content = """
        1
        00:00:01,000 -> 00:00:03,000
        Invalid separator
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.isEmpty)
    }

    @Test func subtitleParserHandlesNonNumericTimestamp() {
        let content = """
        1
        aa:bb:cc,ddd --> ee:ff:gg,hhh
        Invalid timestamps
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.isEmpty)
    }

    @Test func subtitleParserHandlesEndBeforeStart() {
        let content = """
        1
        00:00:05,000 --> 00:00:01,000
        Invalid range
        """
        let cues = SubtitleParser.parseSRT(content)
        #expect(cues.count == 1)
        #expect(cues[0].startTime < cues[0].endTime)
    }

    @Test func subtitleParserHandlesVTTWithoutHeader() {
        let content = """
        00:00:01.000 --> 00:00:03.000
        No WEBVTT header
        """
        let cues = SubtitleParser.parseVTT(content)
        #expect(cues.count == 1)
    }

    @Test func subtitleParserHandlesASSWithoutDialogue() {
        let content = """
        [Script Info]
        Title: Test
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        """
        let cues = SubtitleParser.parseASS(content)
        #expect(cues.isEmpty)
    }
}

// MARK: - Helper Functions

private func parseCSVLine(_ line: String) -> [String] {
    var result: [String] = []
    var current = ""
    var inQuotes = false
    var i = line.startIndex

    while i < line.endIndex {
        let char = line[i]

        if char == "\"" && !inQuotes {
            inQuotes = true
        } else if char == "\"" && inQuotes {
            if line.index(after: i) < line.endIndex && line[line.index(after: i)] == "\"" {
                current.append("\"")
                i = line.index(after: i)
            } else {
                inQuotes = false
            }
        } else if char == "," && !inQuotes {
            result.append(current)
            current = ""
        } else {
            current.append(char)
        }

        if i != line.endIndex {
            i = line.index(after: i)
        }
    }

    result.append(current)
    return result
}

private func normalizeNewlines(_ value: String) -> String {
    value
        .trimmingPrefixBOM()
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
}

private func parseSRTTime(_ str: String) -> TimeInterval? {
    let clean = str.replacingOccurrences(of: ",", with: ".")
    return parseColonTime(clean)
}

private func parseVTTTime(_ str: String) -> TimeInterval? {
    parseColonTime(str)
}

private func parseASSTime(_ str: String) -> TimeInterval? {
    parseColonTime(str)
}

private func parseColonTime(_ str: String) -> TimeInterval? {
    let parts = str.components(separatedBy: ":")
    guard parts.count >= 2 else { return nil }

    if parts.count == 3 {
        guard let h = Double(parts[0]),
              let m = Double(parts[1]),
              let s = Double(parts[2]) else { return nil }
        return h * 3600 + m * 60 + s
    } else {
        guard let m = Double(parts[0]),
              let s = Double(parts[1]) else { return nil }
        return m * 60 + s
    }
}

private extension String {
    func trimmingPrefixBOM() -> String {
        guard let first = unicodeScalars.first, first == UnicodeScalar(0xFEFF) else { return self }
        return String(dropFirst())
    }
}
