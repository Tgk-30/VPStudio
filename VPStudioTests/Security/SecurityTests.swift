import Foundation
import Testing
@testable import VPStudio

@Suite("Security Tests")
struct SecurityTests {

    // MARK: - API Key Logging Prevention

    @Suite("API Key Logging Prevention")
    struct APIKeyLoggingTests {

        @Test func sensitiveQueryParametersAreRedacted() {
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
            #expect(!redacted.contains("token1234567890"))
        }

        @Test func authorizationHeadersAreRedacted() {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "example.com"
            components.user = "user"
            components.password = "supersecret"
            components.path = "/api"

            let url = components.url!
            let redacted = IndexerLogSanitizer.redactedURL(url)

            #expect(!redacted.contains("supersecret"))
            #expect(redacted.contains("REDACTED"))
            #expect(redacted.contains("example.com"))
        }

        @Test func tokenLikePathSegmentsAreRedacted() {
            let url = URL(string: "https://indexer.example.com/api/v1/abcdef1234567890abcdef/search")!
            let redacted = IndexerLogSanitizer.redactedURL(url)

            #expect(redacted.contains("REDACTED"))
            #expect(!redacted.contains("abcdef1234567890abcdef"))
        }

        @Test func tokenLikeQueryValuesAreRedacted() {
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

        @Test func shortQueryValuesArePreserved() {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "example.com"
            components.path = "/search"
            components.queryItems = [
                URLQueryItem(name: "q", value: "abc"),
            ]

            let url = components.url!
            let redacted = IndexerLogSanitizer.redactedURL(url)

            #expect(redacted.contains("q=abc"))
            #expect(!redacted.contains("REDACTED"))
        }

        @Test func apiKeyTransportHeaderValuesAreRedacted() {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.example.com"
            components.path = "/v3/search"
            components.queryItems = [
                URLQueryItem(name: "apikey", value: "MySecretAPIKey12345"),
            ]

            let url = components.url!
            let redacted = IndexerLogSanitizer.redactedURL(url)

            #expect(redacted.contains("apikey=REDACTED"))
            #expect(!redacted.contains("MySecretAPIKey12345"))
        }

        @Test func jwtTokensInURLAreRedacted() {
            let jwtURL = "https://api.example.com/auth?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4ifQ.abcdefghijklmnopqrstuvwxyz"
            let redacted = IndexerLogSanitizer.redactedURLString(jwtURL)

            #expect(redacted.contains("REDACTED"))
            #expect(!redacted.contains("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"))
        }

        @Test func refreshTokenInURLIsRedacted() {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "example.com"
            components.path = "/oauth/token"
            components.queryItems = [
                URLQueryItem(name: "refresh_token", value: "refresh_token_value_12345"),
            ]

            let url = components.url!
            let redacted = IndexerLogSanitizer.redactedURL(url)

            #expect(redacted.contains("refresh_token=REDACTED"))
        }
    }

    // MARK: - URL Sanitization

    @Suite("URL Sanitization")
    struct URLSanitizationTests {

        @Test func nilURLStringReturnsNil() {
            let result = IndexerLogSanitizer.redactedURLString(nil)
            #expect(result == "nil")
        }

        @Test func emptyURLStringReturnsNil() {
            let result = IndexerLogSanitizer.redactedURLString("")
            #expect(result == "nil")
        }

        @Test func invalidURLStringReturnsRedacted() {
            let result = IndexerLogSanitizer.redactedURLString("not-a-valid-url")
            #expect(result == "REDACTED")
        }

        @Test func magnetURIsArePartiallyRedacted() {
            let magnet = "magnet:?xt=urn:btih:abc123def456&dn=Movie+Name"
            let result = IndexerLogSanitizer.redactedURLString(magnet)

            #expect(result.contains("magnet"))
            #expect(result.contains("abc123def456"))
            #expect(result.contains("Movie"))
        }

        @Test func normalURLsAreNotRedacted() {
            let url = URL(string: "https://example.com/movie/tt1234567")!
            let redacted = IndexerLogSanitizer.redactedURL(url)

            #expect(redacted.contains("example.com"))
            #expect(redacted.contains("tt1234567"))
            #expect(!redacted.contains("REDACTED"))
        }

        @Test func hostIsPreservedInRedactedURL() {
            let url = URL(string: "https://api.tmdb.org/v3/movie/popular?api_key=secret")!
            let redacted = IndexerLogSanitizer.redactedURL(url)

            #expect(redacted.contains("api.tmdb.org"))
            #expect(!redacted.contains("secret"))
        }

        @Test func errorMessageSanitization() {
            struct SampleError: LocalizedError {
                var errorDescription: String? {
                    "Failed to fetch https://api.example.com?api_key=secret&token=token123 from server"
                }
            }

            let sanitized = IndexerLogSanitizer.redactedErrorMessage(SampleError())

            #expect(!sanitized.contains("secret"))
            #expect(!sanitized.contains("token123"))
            #expect(sanitized.contains("api.example.com"))
        }

        @Test func errorMessageSanitizationForStandaloneTokens() {
            struct SampleError: LocalizedError {
                var errorDescription: String? {
                    "failed with key apikey-abcdefghijklmnop"
                }
            }

            let sanitized = IndexerLogSanitizer.redactedErrorMessage(SampleError())

            #expect(sanitized.contains("REDACTED"))
            #expect(!sanitized.contains("apikey-abcdefghijklmnop"))
            #expect(!sanitized.contains("abcdefghijklmnop"))
        }

        @Test func errorMessageWithCredentials() {
            struct SampleError: Error {
                var localizedDescription: String {
                    "Auth failed for https://user:password@api.example.com/path"
                }
            }

            let sanitized = IndexerLogSanitizer.redactedErrorMessage(SampleError())

            #expect(!sanitized.contains("password"))
            #expect(!sanitized.contains("user"))
        }

        @Test func fragmentIsRemoved() {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "example.com"
            components.path = "/search"
            components.fragment = "section"

            let url = components.url!
            let redacted = IndexerLogSanitizer.redactedURL(url)

            #expect(!redacted.contains("#"))
        }

        @Test func percentEncodedPathsAreHandled() {
            let url = URL(string: "https://example.com/search/Movie%20Name%202023")!
            let redacted = IndexerLogSanitizer.redactedURL(url)

            #expect(redacted.contains("Movie"))
            #expect(redacted.contains("Name"))
            #expect(redacted.contains("2023"))
        }
    }

    // MARK: - Data Redaction on Completion

    @Suite("Data Redaction on Completion")
    struct DataRedactionTests {

        @Test func downloadTaskRedactsStreamURLOnCompletion() {
            var task = DownloadTask(
                id: "task-redact-test",
                mediaId: "tt123",
                episodeId: nil,
                fileName: "test.mkv",
                status: .completed,
                expectedBytes: 1024,
                createdAt: Date(),
                updatedAt: Date()
            )
            task.streamURL = "https://cdn.example.com/stream?token=secret123"

            let redacted = task.redactedForRecoveryBackedPersistence

            #expect(redacted.persistedStreamURL == nil)
        }

        @Test func downloadTaskRedactsResumeDataOnCompletion() {
            var task = DownloadTask(
                id: "task-redact-resume",
                mediaId: "tt123",
                episodeId: nil,
                fileName: "test.mkv",
                status: .completed,
                expectedBytes: 1024,
                createdAt: Date(),
                updatedAt: Date()
            )
            task.resumeDataBase64 = "base64encodedresumedatawithsecrets"

            let redacted = task.redactedForRecoveryBackedPersistence

            #expect(redacted.resumeDataBase64 == nil)
        }

        @Test func downloadTaskPreservesRecoveryContext() {
            let recoveryContext = StreamRecoveryContext(
                infoHash: "abc123def456",
                preferredService: .realDebrid,
                seasonNumber: 1,
                episodeNumber: 5
            )

            var task = DownloadTask(
                id: "task-recovery-test",
                mediaId: "tt123",
                episodeId: "ep55",
                fileName: "test.mkv",
                status: .completed,
                expectedBytes: 1024,
                createdAt: Date(),
                updatedAt: Date()
            )
            task.streamURL = "https://cdn.example.com/stream?token=secret"
            task.recoveryContext = recoveryContext

            let redacted = task.redactedForRecoveryBackedPersistence

            #expect(redacted.recoveryContext?.infoHash == "abc123def456")
            #expect(redacted.recoveryContext?.preferredService == .realDebrid)
            #expect(redacted.persistedStreamURL == nil)
        }

        @Test func redactedTaskInProgressRetainsURL() {
            var task = DownloadTask(
                id: "task-active",
                mediaId: "tt123",
                episodeId: nil,
                fileName: "test.mkv",
                status: .downloading,
                expectedBytes: 1024,
                createdAt: Date(),
                updatedAt: Date()
            )
            task.streamURL = "https://cdn.example.com/stream?token=secret123"

            let redacted = task.redactedForRecoveryBackedPersistence

            // redactedForRecoveryBackedPersistence always clears streamURL for security
            #expect(redacted.persistedStreamURL == nil)
        }

        @Test func redactedTaskFailedRetainsURL() {
            var task = DownloadTask(
                id: "task-failed",
                mediaId: "tt123",
                episodeId: nil,
                fileName: "test.mkv",
                status: .failed,
                expectedBytes: 1024,
                createdAt: Date(),
                updatedAt: Date()
            )
            task.streamURL = "https://cdn.example.com/stream?token=secret123"

            let redacted = task.redactedForRecoveryBackedPersistence

            // redactedForRecoveryBackedPersistence always clears streamURL for security
            #expect(redacted.persistedStreamURL == nil)
        }
    }

    // MARK: - User Data Protection

    @Suite("User Data Protection")
    struct UserDataProtectionTests {

        @Test func secretKeyFormatIsCorrect() {
            let settingKey = SecretKey.setting("tmdbApiKey")
            #expect(settingKey == "settings.tmdbApiKey")
        }

        @Test func debridTokenKeyFormatWithoutConfigId() {
            let tokenKey = SecretKey.debridToken(service: .realDebrid)
            #expect(tokenKey == "debrid.real_debrid")
        }

        @Test func debridTokenKeyFormatWithConfigId() {
            let tokenKey = SecretKey.debridToken(service: .allDebrid, configId: "config-1")
            #expect(tokenKey == "debrid.all_debrid.config-1")
        }

        @Test func secretReferenceEncodeDecode() {
            let key = "my-secret-key"
            let encoded = SecretReference.encode(key: key)
            let decoded = SecretReference.decode(encoded)

            #expect(encoded == "keychain:my-secret-key")
            #expect(decoded == key)
        }

        @Test func secretReferenceDecodeInvalidPrefixReturnsNil() {
            let decoded = SecretReference.decode("https://example.com/secret")
            #expect(decoded == nil)
        }

        @Test func secretReferenceDecodeEmptyStringReturnsNil() {
            let decoded = SecretReference.decode("")
            #expect(decoded == nil)
        }

        @Test func secretReferencePreservesSpecialCharacters() {
            let key = "api_key-with-special.chars"
            let encoded = SecretReference.encode(key: key)
            let decoded = SecretReference.decode(encoded)

            #expect(decoded == key)
        }
    }

    // MARK: - Keychain Security

    @Suite("Keychain Security")
    struct KeychainSecurityTests {

        @Test func keychainSecretStoredWithCorrectAccessibility() async throws {
            let serviceName = "com.vpstudio.tests.security.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            try await store.setSecret("test-value", for: "test-key")
            let retrieved = try await store.getSecret(for: "test-key")

            #expect(retrieved == "test-value")
        }

        @Test func keychainSecretsAreIsolatedByService() async throws {
            let serviceA = "com.vpstudio.tests.security.isolation.\(UUID().uuidString)"
            let serviceB = "com.vpstudio.tests.security.isolation.\(UUID().uuidString)"

            let storeA = KeychainSecretStore(serviceName: serviceA)
            let storeB = KeychainSecretStore(serviceName: serviceB)
            defer {
                Task {
                    try? await storeA.deleteAllSecrets()
                    try? await storeB.deleteAllSecrets()
                }
            }

            try await storeA.setSecret("secret-a", for: "shared-key")
            try await storeB.setSecret("secret-b", for: "shared-key")

            #expect(try await storeA.getSecret(for: "shared-key") == "secret-a")
            #expect(try await storeB.getSecret(for: "shared-key") == "secret-b")
        }

        @Test func deleteAllSecretsOnlyDeletesForOwnService() async throws {
            let serviceA = "com.vpstudio.tests.security.isolation.delete.\(UUID().uuidString)"
            let serviceB = "com.vpstudio.tests.security.isolation.delete.\(UUID().uuidString)"

            let storeA = KeychainSecretStore(serviceName: serviceA)
            let storeB = KeychainSecretStore(serviceName: serviceB)
            defer {
                Task {
                    try? await storeA.deleteAllSecrets()
                    try? await storeB.deleteAllSecrets()
                }
            }

            try await storeA.setSecret("secret-a", for: "key-a")
            try await storeB.setSecret("secret-b", for: "key-b")

            try await storeA.deleteAllSecrets()

            #expect(try await storeA.getSecret(for: "key-a") == nil)
            #expect(try await storeB.getSecret(for: "key-b") == "secret-b")
        }

        @Test func unicodeSecretsAreStoredAndRetrieved() async throws {
            let serviceName = "com.vpstudio.tests.security.unicode.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            let unicodeSecret = "🔐 Clé秘密Ключ"
            try await store.setSecret(unicodeSecret, for: "unicode-key")
            let retrieved = try await store.getSecret(for: "unicode-key")

            #expect(retrieved == unicodeSecret)
        }

        @Test func largeSecretIsStoredAndRetrieved() async throws {
            let serviceName = "com.vpstudio.tests.security.large.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            let largeSecret = String(repeating: "A", count: 10_000)
            try await store.setSecret(largeSecret, for: "large-key")
            let retrieved = try await store.getSecret(for: "large-key")

            #expect(retrieved == largeSecret)
        }

        @Test func keychainUpdateOverwritesExisting() async throws {
            let serviceName = "com.vpstudio.tests.security.update.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            try await store.setSecret("original", for: "update-key")
            try await store.setSecret("updated", for: "update-key")
            let retrieved = try await store.getSecret(for: "update-key")

            #expect(retrieved == "updated")
        }

        @Test func getNonExistentKeyReturnsNil() async throws {
            let serviceName = "com.vpstudio.tests.security.missing.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            let retrieved = try await store.getSecret(for: "never-existent-key")

            #expect(retrieved == nil)
        }

        @Test func deleteNonExistentKeyDoesNotThrow() async throws {
            let serviceName = "com.vpstudio.tests.security.deletemissing.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            try await store.deleteSecret(for: "never-existent-key")
        }

        @Test func emptySecretCanBeStored() async throws {
            let serviceName = "com.vpstudio.tests.security.empty.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            try await store.setSecret("", for: "empty-key")
            let retrieved = try await store.getSecret(for: "empty-key")

            #expect(retrieved == "")
        }
    }

    // MARK: - Sensitive Data Memory Protection

    @Suite("Sensitive Data Memory Protection")
    struct MemoryProtectionTests {

        @Test func secretValueNotRetainedInMemoryAfterDeletion() async throws {
            let serviceName = "com.vpstudio.tests.memory.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)

            try await store.setSecret("sensitive-data-\(UUID().uuidString)", for: "memory-test-key")
            try await store.deleteSecret(for: "memory-test-key")
            let retrieved = try await store.getSecret(for: "memory-test-key")

            #expect(retrieved == nil)
        }

        @Test func multipleSecretsCanBeIndependentlyDeleted() async throws {
            let serviceName = "com.vpstudio.tests.memory.multi.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            try await store.setSecret("secret-one", for: "key-one")
            try await store.setSecret("secret-two", for: "key-two")
            try await store.setSecret("secret-three", for: "key-three")

            try await store.deleteSecret(for: "key-two")

            #expect(try await store.getSecret(for: "key-one") == "secret-one")
            #expect(try await store.getSecret(for: "key-two") == nil)
            #expect(try await store.getSecret(for: "key-three") == "secret-three")
        }

        @Test func deleteAllClearsAllSecrets() async throws {
            let serviceName = "com.vpstudio.tests.memory.clearall.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            try await store.setSecret("secret-one", for: "key-one")
            try await store.setSecret("secret-two", for: "key-two")

            try await store.deleteAllSecrets()

            #expect(try await store.getSecret(for: "key-one") == nil)
            #expect(try await store.getSecret(for: "key-two") == nil)
        }

        @Test func deleteAllHandlesSingleStoredKey() async throws {
            let serviceName = "com.vpstudio.tests.security.clearallsingular.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            try await store.setSecret("only-secret", for: "single-key")
            try await store.deleteAllSecrets()

            #expect(try await store.getSecret(for: "single-key") == nil)
        }

        @Test func specialCharactersInSecretsAreHandled() async throws {
            let serviceName = "com.vpstudio.tests.memory.special.\(UUID().uuidString)"
            let store = KeychainSecretStore(serviceName: serviceName)
            defer { Task { try? await store.deleteAllSecrets() } }

            let specialValue = "<>&\"'\n\t\r\\/:"
            try await store.setSecret(specialValue, for: "special-key")
            let retrieved = try await store.getSecret(for: "special-key")

            #expect(retrieved == specialValue)
        }
    }

    // MARK: - Stream URL Redaction on Completion

    @Suite("Stream URL Redaction on Completion")
    struct StreamURLRedactionTests {

        @Test func completedDownloadHasNoPersistedStreamURL() {
            var task = DownloadTask(
                id: "completed-stream-test",
                mediaId: "tt123",
                episodeId: nil,
                fileName: "movie.mkv",
                status: .completed,
                expectedBytes: 1024,
                createdAt: Date(),
                updatedAt: Date()
            )
            task.streamURL = "https://real-debrid.cloud/randomtokenhere/file.mkv?auth=secret"

            let redacted = task.redactedForRecoveryBackedPersistence

            #expect(redacted.persistedStreamURL == nil)
            #expect(redacted.resumeDataBase64 == nil)
        }

        @Test func activeDownloadRetainsStreamURL() {
            var task = DownloadTask(
                id: "active-stream-test",
                mediaId: "tt123",
                episodeId: nil,
                fileName: "movie.mkv",
                status: .downloading,
                expectedBytes: 1024,
                createdAt: Date(),
                updatedAt: Date()
            )
            task.streamURL = "https://real-debrid.cloud/randomtokenhere/file.mkv?auth=secret"

            let redacted = task.redactedForRecoveryBackedPersistence

            // redactedForRecoveryBackedPersistence always clears streamURL for security
            #expect(redacted.persistedStreamURL == nil)
        }

        @Test func pausedDownloadRetainsStreamURL() {
            var task = DownloadTask(
                id: "paused-stream-test",
                mediaId: "tt123",
                episodeId: nil,
                fileName: "movie.mkv",
                status: .downloading,
                expectedBytes: 1024,
                createdAt: Date(),
                updatedAt: Date()
            )
            task.streamURL = "https://example.com/stream?token=secrettoken123456789"

            let redacted = task.redactedForRecoveryBackedPersistence

            // redactedForRecoveryBackedPersistence always clears streamURL for security
            #expect(redacted.persistedStreamURL == nil)
        }

        @Test func failedDownloadRetainsStreamURLForRetry() {
            var task = DownloadTask(
                id: "failed-stream-test",
                mediaId: "tt123",
                episodeId: nil,
                fileName: "movie.mkv",
                status: .failed,
                expectedBytes: 1024,
                createdAt: Date(),
                updatedAt: Date()
            )
            task.streamURL = "https://torbox.cloud/token/file.mkv"

            let redacted = task.redactedForRecoveryBackedPersistence

            // redactedForRecoveryBackedPersistence always clears streamURL for security
            #expect(redacted.persistedStreamURL == nil)
        }

        @Test func recoveryContextPreservedAfterRedaction() {
            let recoveryContext = StreamRecoveryContext(
                infoHash: "ABC123DEF456",
                preferredService: .premiumize,
                seasonNumber: nil,
                episodeNumber: nil
            )

            var task = DownloadTask(
                id: "recovery-context-test",
                mediaId: "tt456",
                episodeId: nil,
                fileName: "show.mkv",
                status: .completed,
                expectedBytes: 2048,
                createdAt: Date(),
                updatedAt: Date()
            )
            task.streamURL = "https://premiumize.me/stream?token=supasecret"
            task.recoveryContext = recoveryContext

            let redacted = task.redactedForRecoveryBackedPersistence

            // StreamRecoveryContext normalizes infoHash to lowercase
            #expect(redacted.recoveryContext?.infoHash == "abc123def456")
            #expect(redacted.recoveryContext?.preferredService == .premiumize)
            #expect(redacted.persistedStreamURL == nil)
        }
    }

    // MARK: - Log Sanitization Edge Cases

    @Suite("Log Sanitization Edge Cases")
    struct LogSanitizationEdgeCases {

        @Test func veryLongSensitiveTokenIsRedacted() {
            let longToken = String(repeating: "X", count: 100)
            let redacted = IndexerLogSanitizer.redactedURLString(longToken)
            #expect(redacted == "REDACTED")
        }

        @Test func shortNonSensitiveStringIsPreserved() {
            let short = "abc123"
            let redacted = IndexerLogSanitizer.redactedURLString(short)
            #expect(redacted == short)
        }

        @Test func looseMessagesRedactAssignmentsBearerTokensAndURLs() {
            let message = "Failed token=abc123 Bearer sk_test_secret at https://cdn.example.com/movie.mkv?sig=signature123&quality=1080p"
            let redacted = IndexerLogSanitizer.redactedMessage(message)

            #expect(redacted.contains("token=REDACTED"))
            #expect(redacted.contains("Bearer REDACTED"))
            #expect(redacted.contains("sig=REDACTED"))
            #expect(redacted.contains("quality=1080p"))
            #expect(redacted.contains("abc123") == false)
            #expect(redacted.contains("sk_test_secret") == false)
            #expect(redacted.contains("signature123") == false)
        }

        @Test func urlWithMultipleSensitiveParams() {
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

        @Test func nilErrorMessageHandled() {
            struct NilError: LocalizedError {
                var errorDescription: String? { "" }
            }

            let sanitized = IndexerLogSanitizer.redactedErrorMessage(NilError())
            #expect(sanitized == "")
        }

        @Test func urlWithoutSchemeReturnsRedacted() {
            let url = URL(string: "example.com/path?token=secret")!
            let redacted = IndexerLogSanitizer.redactedURL(url)
            // URLComponents can parse scheme-less URLs; sensitive query values are redacted
            #expect(redacted.contains("example.com"))
            #expect(redacted.contains("token=REDACTED"))
        }

        @Test func runtimeErrorLogsSanitizeLocalizedDescriptionsBeforeLogging() throws {
            let sourcePaths = [
                "VPStudio/Services/Player/Immersive/HeadTracker.swift",
                "VPStudio/Services/Player/Rendering/HDRMetadataExtractor.swift",
                "VPStudio/Services/AI/Local/LocalDownloadService.swift",
                "VPStudio/Services/AI/Local/LocalModelCatalogStore.swift",
            ]

            for path in sourcePaths {
                let source = try Self.sourceFile(path)
                #expect(source.contains("IndexerLogSanitizer.redactedErrorMessage(error)"))
                #expect(!source.contains("\\(error.localizedDescription)"))
            }
        }

        private static func sourceFile(_ relativePath: String) throws -> String {
            try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
        }

        private static func repositoryRoot() -> URL {
            var url = URL(fileURLWithPath: #filePath)
            while url.lastPathComponent != "VPStudioTests", url.pathComponents.count > 1 {
                url.deleteLastPathComponent()
            }
            return url.deletingLastPathComponent()
        }
    }
}
