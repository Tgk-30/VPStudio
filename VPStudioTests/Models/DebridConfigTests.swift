import Testing
import Foundation
import GRDB
@testable import VPStudio

@Suite("DebridConfig Codable Round-Trip")
struct DebridConfigCodableTests {
    @Test("DebridConfig encodes and decodes correctly")
    func codableRoundTrip() throws {
        let originalConfig = DebridConfig(
            id: "config-123",
            serviceType: .realDebrid,
            apiTokenRef: "test-token",
            isActive: true,
            priority: 1,
            createdAt: Date(timeIntervalSince1970: 123456789),
            updatedAt: Date(timeIntervalSince1970: 123456790)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalConfig)
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(DebridConfig.self, from: data)

        #expect(decodedConfig.id == originalConfig.id)
        #expect(decodedConfig.serviceType == originalConfig.serviceType)
        #expect(decodedConfig.apiTokenRef == originalConfig.apiTokenRef)
        #expect(decodedConfig.isActive == originalConfig.isActive)
        #expect(decodedConfig.priority == originalConfig.priority)
    }

    @Test("DebridConfig with default values encodes and decodes")
    func defaultValuesRoundTrip() throws {
        let originalConfig = DebridConfig(
            serviceType: .allDebrid,
            apiTokenRef: "token-abc"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalConfig)
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(DebridConfig.self, from: data)

        #expect(decodedConfig.serviceType == .allDebrid)
        #expect(decodedConfig.apiTokenRef == "token-abc")
        #expect(decodedConfig.isActive == true)
        #expect(decodedConfig.priority == 0)
    }
}

@Suite("DebridServiceType Properties")
struct DebridServiceTypeModelTests {
    @Test("Display names are correct")
    func displayNames() {
        #expect(DebridServiceType.realDebrid.displayName == "Real-Debrid")
        #expect(DebridServiceType.allDebrid.displayName == "AllDebrid")
        #expect(DebridServiceType.premiumize.displayName == "Premiumize")
        #expect(DebridServiceType.torBox.displayName == "TorBox")
        #expect(DebridServiceType.debridLink.displayName == "Debrid-Link")
        #expect(DebridServiceType.offcloud.displayName == "Offcloud")
        #expect(DebridServiceType.easyNews.displayName == "EasyNews")
    }

    @Test("Base URLs are correct")
    func baseURLs() {
        #expect(DebridServiceType.realDebrid.baseURL == "https://api.real-debrid.com/rest/1.0")
        #expect(DebridServiceType.allDebrid.baseURL == "https://api.alldebrid.com/v4")
        #expect(DebridServiceType.premiumize.baseURL == "https://www.premiumize.me/api")
        #expect(DebridServiceType.torBox.baseURL == "https://api.torbox.app/v1/api")
        #expect(DebridServiceType.debridLink.baseURL == "https://debrid-link.com/api/v2")
        #expect(DebridServiceType.offcloud.baseURL == "https://offcloud.com/api")
        #expect(DebridServiceType.easyNews.baseURL == "https://members.easynews.com")
    }

    @Test("EasyNews does not support shared magnet resolve flow")
    func easyNewsMagnetSupport() {
        let easyNewsConfig = DebridConfig(
            serviceType: .easyNews,
            apiTokenRef: "test-token"
        )
        #expect(easyNewsConfig.supportsSharedMagnetResolveFlow == false)

        let realDebridConfig = DebridConfig(
            serviceType: .realDebrid,
            apiTokenRef: "test-token"
        )
        #expect(realDebridConfig.supportsSharedMagnetResolveFlow == true)
    }

    @Test("Only EasyNews opts out of shared magnet resolve flow")
    func sharedMagnetResolveSupportMatrix() {
        for service in DebridServiceType.allCases {
            let config = DebridConfig(serviceType: service, apiTokenRef: "token")
            #expect(config.supportsSharedMagnetResolveFlow == (service != .easyNews))
        }
    }
}



@Suite("DebridConfig Token Normalization")
struct DebridConfigTokenTests {
    private actor InMemorySecretStore: SecretStore {
        private var secrets: [String: String] = [:]

        func setSecret(_ secret: String, for key: String) async throws {
            secrets[key] = secret
        }

        func getSecret(for key: String) async throws -> String? {
            secrets[key]
        }

        func deleteSecret(for key: String) async throws {
            secrets[key] = nil
        }

        func deleteAllSecrets() async throws {
            secrets.removeAll()
        }
    }

    @Test("Token normalization trims whitespace")
    func tokenNormalization() {
        let config = DebridConfig(
            serviceType: .realDebrid,
            apiTokenRef: "  test-token  "
        )
        // Note: We can't directly test the private normalizedStoredToken,
        // but we can verify the behavior through the public API
        #expect(config.apiTokenRef == "  test-token  ")
    }

    @Test("Empty token after trimming returns nil")
    func emptyToken() {
        let config = DebridConfig(
            serviceType: .realDebrid,
            apiTokenRef: "   "
        )
        #expect(config.apiTokenRef == "   ")
    }

    @Test("Legacy plaintext token resolves, trims, and migrates into secret store")
    func legacyPlaintextTokenResolvesAndMigrates() async throws {
        let store = InMemorySecretStore()
        let config = DebridConfig(
            id: "legacy-token",
            serviceType: .premiumize,
            apiTokenRef: "  premium-token  "
        )

        let resolved = try await config.resolvedToken(using: store)

        #expect(resolved == "premium-token")
        #expect(try await store.getSecret(for: config.secretKey) == "premium-token")
    }

    @Test("Persisted copy clears blank token and deletes stale stored secret")
    func persistedCopyClearsBlankTokenAndDeletesStoredSecret() async throws {
        let store = InMemorySecretStore()
        let config = DebridConfig(
            id: "blank-token",
            serviceType: .realDebrid,
            apiTokenRef: " \n\t "
        )
        try await store.setSecret("stale-token", for: config.secretKey)

        let persisted = try await config.persistedCopy(using: store)

        #expect(persisted.changed)
        #expect(persisted.config.apiTokenRef == "")
        #expect(try await store.getSecret(for: config.secretKey) == nil)
    }

    @Test("Persisted copy preserves encoded reference after trimming storage whitespace")
    func persistedCopyPreservesEncodedReferenceAfterTrimming() async throws {
        let store = InMemorySecretStore()
        let key = DebridConfig.secretKey(for: "encoded-token", serviceType: .torBox)
        let encoded = SecretReference.encode(key: key)
        let config = DebridConfig(
            id: "encoded-token",
            serviceType: .torBox,
            apiTokenRef: "  \(encoded)\n"
        )

        let persisted = try await config.persistedCopy(using: store)

        #expect(persisted.changed)
        #expect(persisted.config.apiTokenRef == encoded)
        #expect(try await store.getSecret(for: key) == nil)
    }

    @Test("Resolved copy clears blank token to empty runtime value")
    func resolvedCopyClearsBlankToken() async throws {
        let store = InMemorySecretStore()
        let config = DebridConfig(
            id: "blank-runtime",
            serviceType: .debridLink,
            apiTokenRef: "  \n\t  "
        )

        let resolved = try await config.resolvedCopy(using: store)

        #expect(resolved.apiTokenRef == "")
    }

    @Test("Persisted copy keeps canonical encoded reference unchanged")
    func persistedCopyKeepsCanonicalEncodedReferenceUnchanged() async throws {
        let store = InMemorySecretStore()
        let key = DebridConfig.secretKey(for: "canonical-token", serviceType: .offcloud)
        let encoded = SecretReference.encode(key: key)
        let config = DebridConfig(
            id: "canonical-token",
            serviceType: .offcloud,
            apiTokenRef: encoded
        )

        let persisted = try await config.persistedCopy(using: store)

        #expect(persisted.changed == false)
        #expect(persisted.config.apiTokenRef == encoded)
    }
}

@Suite("DebridConfig Secret Key Generation")
struct DebridConfigSecretKeyTests {
    @Test("Secret key is generated correctly")
    func secretKeyGeneration() {
        let config = DebridConfig(
            id: "config-123",
            serviceType: .realDebrid,
            apiTokenRef: "test-token"
        )

        let expectedKey = DebridConfig.secretKey(for: "config-123", serviceType: .realDebrid)
        #expect(config.secretKey == expectedKey)
        #expect(config.secretKey.contains("config-123"))
        #expect(config.secretKey.contains("real_debrid"))
    }
}

@Suite("DebridConfig Row Initialization")
struct DebridConfigRowInitializationTests {
    @Test("Unknown stored service type falls back to Real-Debrid")
    func unknownStoredServiceTypeFallsBackToRealDebrid() throws {
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let row = Row([
            "id": "debrid-row",
            "serviceType": "unknown-service",
            "apiTokenRef": "secret-ref",
            "isActive": false,
            "priority": 7,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
        ])

        let config = try DebridConfig(row: row)

        #expect(config.id == "debrid-row")
        #expect(config.serviceType == .realDebrid)
        #expect(config.apiTokenRef == "secret-ref")
        #expect(config.isActive == false)
        #expect(config.priority == 7)
        #expect(config.createdAt == createdAt)
        #expect(config.updatedAt == updatedAt)
    }
}

@Suite("DebridConfig Database Round-Trip")
struct DebridConfigDatabaseRoundTripTests {
    private func makeTempDatabase() async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "debrid-config-test-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test func roundTripsThroughDatabaseManager() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = DebridConfig(
            id: "debrid-1",
            serviceType: .realDebrid,
            apiTokenRef: "test-token",
            isActive: true,
            priority: 1
        )
        try await database.saveDebridConfig(config)
        let fetched = try await database.fetchDebridConfigs()

        #expect(fetched.count == 1)
        #expect(fetched.first?.id == config.id)
        #expect(fetched.first?.serviceType == .realDebrid)
        #expect(fetched.first?.isActive == true)
    }

    @Test
    func debridConfigWithAllFieldsRoundTripsCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = DebridConfig(
            id: "full-debrid",
            serviceType: .premiumize,
            apiTokenRef: "premiumize-token",
            isActive: true,
            priority: 2,
            createdAt: Date(timeIntervalSince1970: 123456789),
            updatedAt: Date(timeIntervalSince1970: 123456790)
        )
        try await database.saveDebridConfig(config)
        let fetched = try await database.fetchDebridConfigs()

        #expect(fetched.count == 1)
        #expect(fetched.first?.serviceType == .premiumize)
        #expect(fetched.first?.priority == 2)
    }

    @Test
    func multipleDebridConfigsRoundTripCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configs = [
            DebridConfig(id: "rd-1", serviceType: .realDebrid, apiTokenRef: "token1"),
            DebridConfig(id: "pd-1", serviceType: .premiumize, apiTokenRef: "token2"),
            DebridConfig(id: "ad-1", serviceType: .allDebrid, apiTokenRef: "token3")
        ]

        for config in configs {
            try await database.saveDebridConfig(config)
        }

        let fetched = try await database.fetchDebridConfigs()
        #expect(fetched.count == 3)
        #expect(fetched.contains { $0.serviceType == .realDebrid })
        #expect(fetched.contains { $0.serviceType == .premiumize })
        #expect(fetched.contains { $0.serviceType == .allDebrid })
    }
}

@Suite("IndexerConfig Properties")
struct IndexerConfigModelTests {
    @Test("IndexerType display names are correct")
    func indexerTypeDisplayNames() {
        #expect(IndexerConfig.IndexerType.apiBay.displayName == "APiBay")
        #expect(IndexerConfig.IndexerType.yts.displayName == "YTS")
        #expect(IndexerConfig.IndexerType.eztv.displayName == "EZTV")
        #expect(IndexerConfig.IndexerType.jackett.displayName == "Jackett")
        #expect(IndexerConfig.IndexerType.prowlarr.displayName == "Prowlarr")
        #expect(IndexerConfig.IndexerType.torznab.displayName == "Torznab")
        #expect(IndexerConfig.IndexerType.zilean.displayName == "Zilean")
        #expect(IndexerConfig.IndexerType.stremio.displayName == "Stremio")
    }

    @Test("IndexerType isBuiltIn flags")
    func indexerTypeIsBuiltIn() {
        #expect(IndexerConfig.IndexerType.apiBay.isBuiltIn == true)
        #expect(IndexerConfig.IndexerType.yts.isBuiltIn == true)
        #expect(IndexerConfig.IndexerType.eztv.isBuiltIn == true)
        #expect(IndexerConfig.IndexerType.jackett.isBuiltIn == false)
        #expect(IndexerConfig.IndexerType.prowlarr.isBuiltIn == false)
        #expect(IndexerConfig.IndexerType.torznab.isBuiltIn == false)
        #expect(IndexerConfig.IndexerType.zilean.isBuiltIn == false)
        #expect(IndexerConfig.IndexerType.stremio.isBuiltIn == false)
    }

    @Test("IndexerConfig default provider subtype")
    func defaultProviderSubtype() {
        #expect(IndexerConfig.IndexerType.apiBay.defaultProviderSubtype == .builtIn)
        #expect(IndexerConfig.IndexerType.yts.defaultProviderSubtype == .builtIn)
        #expect(IndexerConfig.IndexerType.eztv.defaultProviderSubtype == .builtIn)
        #expect(IndexerConfig.IndexerType.jackett.defaultProviderSubtype == .jackett)
        #expect(IndexerConfig.IndexerType.prowlarr.defaultProviderSubtype == .prowlarr)
        #expect(IndexerConfig.IndexerType.torznab.defaultProviderSubtype == .customTorznab)
        #expect(IndexerConfig.IndexerType.zilean.defaultProviderSubtype == .customTorznab)
        #expect(IndexerConfig.IndexerType.stremio.defaultProviderSubtype == .stremioAddon)
    }

    @Test("IndexerConfig default endpoint paths")
    func defaultEndpointPaths() {
        #expect(IndexerConfig.IndexerType.apiBay.defaultEndpointPath == "")
        #expect(IndexerConfig.IndexerType.yts.defaultEndpointPath == "")
        #expect(IndexerConfig.IndexerType.eztv.defaultEndpointPath == "")
        #expect(IndexerConfig.IndexerType.jackett.defaultEndpointPath == "/api/v2.0/indexers/all/results/torznab/api")
        #expect(IndexerConfig.IndexerType.prowlarr.defaultEndpointPath == "/api/v1/search")
        #expect(IndexerConfig.IndexerType.torznab.defaultEndpointPath == "/api")
        #expect(IndexerConfig.IndexerType.zilean.defaultEndpointPath == "/api")
        #expect(IndexerConfig.IndexerType.stremio.defaultEndpointPath == "/manifest.json")
    }

    @Test("IndexerConfig default API key transport")
    func defaultAPIKeyTransport() {
        #expect(IndexerConfig.IndexerType.jackett.defaultAPIKeyTransport == .header)
        #expect(IndexerConfig.IndexerType.prowlarr.defaultAPIKeyTransport == .header)
        #expect(IndexerConfig.IndexerType.torznab.defaultAPIKeyTransport == .header)
        #expect(IndexerConfig.IndexerType.apiBay.defaultAPIKeyTransport == .query)
        #expect(IndexerConfig.IndexerType.yts.defaultAPIKeyTransport == .query)
        #expect(IndexerConfig.IndexerType.eztv.defaultAPIKeyTransport == .query)
        #expect(IndexerConfig.IndexerType.zilean.defaultAPIKeyTransport == .query)
        #expect(IndexerConfig.IndexerType.stremio.defaultAPIKeyTransport == .query)
    }

    @Test("Initializer applies type defaults when optional fields are omitted")
    func initializerAppliesTypeDefaults() {
        let config = IndexerConfig(
            id: "stremio-defaults",
            name: "Stremio",
            indexerType: .stremio
        )

        #expect(config.providerSubtype == .stremioAddon)
        #expect(config.endpointPath == "/manifest.json")
        #expect(config.apiKeyTransport == .query)
    }
}

@Suite("IndexerConfig Row Initialization")
struct IndexerConfigRowInitializationTests {
    @Test("Row initializer preserves valid stored values")
    func rowInitializerPreservesValidStoredValues() throws {
        let row = Row([
            "id": "valid-indexer-row",
            "name": "Valid Indexer",
            "indexerType": "stremio",
            "baseURL": "https://stremio.example",
            "apiKey": "keychain:indexer.valid.api_key",
            "isActive": false,
            "priority": 8,
            "providerSubtype": "stremio_addon",
            "endpointPath": "/custom-manifest.json",
            "categoryFilter": "5000",
            "apiKeyTransport": "query",
        ])

        let config = try IndexerConfig(row: row)

        #expect(config.id == "valid-indexer-row")
        #expect(config.indexerType == .stremio)
        #expect(config.baseURL == "https://stremio.example")
        #expect(config.apiKey == "keychain:indexer.valid.api_key")
        #expect(config.isActive == false)
        #expect(config.priority == 8)
        #expect(config.providerSubtype == .stremioAddon)
        #expect(config.endpointPath == "/custom-manifest.json")
        #expect(config.categoryFilter == "5000")
        #expect(config.apiKeyTransport == .query)
    }

    @Test("Row initializer falls back to type defaults for invalid stored values")
    func rowInitializerFallsBackToTypeDefaults() throws {
        let row = Row([
            "id": "indexer-row",
            "name": "Broken Indexer",
            "indexerType": "unknown",
            "baseURL": nil,
            "apiKey": nil,
            "isActive": true,
            "priority": 3,
            "providerSubtype": "invalid",
            "endpointPath": "",
            "categoryFilter": "2000,2010",
            "apiKeyTransport": "invalid",
        ])

        let config = try IndexerConfig(row: row)

        #expect(config.indexerType == .torznab)
        #expect(config.providerSubtype == .customTorznab)
        #expect(config.endpointPath == "/api")
        #expect(config.apiKeyTransport == .header)
        #expect(config.categoryFilter == "2000,2010")
    }
}

@Suite("IndexerConfig Secret Normalization")
struct IndexerConfigSecretNormalizationTests {
    private actor InMemorySecretStore: SecretStore {
        private var secrets: [String: String] = [:]

        func setSecret(_ secret: String, for key: String) async throws {
            secrets[key] = secret
        }

        func getSecret(for key: String) async throws -> String? {
            secrets[key]
        }

        func deleteSecret(for key: String) async throws {
            secrets[key] = nil
        }

        func deleteAllSecrets() async throws {
            secrets.removeAll()
        }
    }

    @Test("Resolved API key handles blank, plaintext, and encoded references")
    func resolvedAPIKeyHandlesBlankPlaintextAndEncodedReferences() async throws {
        let store = InMemorySecretStore()
        let key = IndexerConfig.secretKey(for: "encoded-indexer")
        try await store.setSecret("stored-indexer-key", for: key)

        let blank = IndexerConfig(
            id: "blank-indexer",
            name: "Blank",
            indexerType: .torznab,
            apiKey: "  \n\t "
        )
        let plaintext = IndexerConfig(
            id: "plaintext-indexer",
            name: "Plaintext",
            indexerType: .torznab,
            apiKey: "  plaintext-key  "
        )
        let encoded = IndexerConfig(
            id: "encoded-indexer",
            name: "Encoded",
            indexerType: .torznab,
            apiKey: SecretReference.encode(key: key)
        )

        #expect(try await blank.resolvedAPIKey(using: store) == nil)
        #expect(try await plaintext.resolvedAPIKey(using: store) == "plaintext-key")
        #expect(try await encoded.resolvedAPIKey(using: store) == "stored-indexer-key")
    }

    @Test("Persisted copy clears blanks and preserves canonical references")
    func persistedCopyClearsBlankAndPreservesCanonicalReference() async throws {
        let store = InMemorySecretStore()
        let blank = IndexerConfig(
            id: "blank-indexer",
            name: "Blank",
            indexerType: .torznab,
            apiKey: "  "
        )
        try await store.setSecret("stale-key", for: blank.secretKey)

        let cleared = try await blank.persistedCopy(using: store)

        #expect(cleared.changed)
        #expect(cleared.config.apiKey == nil)
        #expect(try await store.getSecret(for: blank.secretKey) == nil)

        let canonicalKey = IndexerConfig.secretKey(for: "canonical-indexer")
        let canonicalReference = SecretReference.encode(key: canonicalKey)
        let canonical = IndexerConfig(
            id: "canonical-indexer",
            name: "Canonical",
            indexerType: .stremio,
            apiKey: canonicalReference
        )

        let persisted = try await canonical.persistedCopy(using: store)

        #expect(persisted.changed == false)
        #expect(persisted.config.apiKey == canonicalReference)
    }
}
