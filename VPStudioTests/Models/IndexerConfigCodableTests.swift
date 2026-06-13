import Testing
import Foundation
@testable import VPStudio

@Suite("IndexerConfig Codable Round-Trip")
struct IndexerConfigCodableTests {
    @Test("IndexerConfig encodes and decodes correctly")
    func indexerConfigCodableRoundTrip() throws {
        let original = IndexerConfig(
            id: "indexer-123",
            name: "My Indexer",
            indexerType: .jackett,
            baseURL: "https://jackett.example.com",
            apiKey: "secret-api-key",
            isActive: true,
            priority: 1,
            providerSubtype: .jackett,
            endpointPath: "/api/v2.0/indexers/all/results/torznab/api",
            categoryFilter: "2000,5000",
            apiKeyTransport: .header
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IndexerConfig.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.indexerType == original.indexerType)
        #expect(decoded.baseURL == original.baseURL)
        #expect(decoded.apiKey == original.apiKey)
        #expect(decoded.isActive == original.isActive)
        #expect(decoded.priority == original.priority)
        #expect(decoded.providerSubtype == original.providerSubtype)
        #expect(decoded.endpointPath == original.endpointPath)
        #expect(decoded.categoryFilter == original.categoryFilter)
        #expect(decoded.apiKeyTransport == original.apiKeyTransport)
    }

    @Test("IndexerConfig with nil optionals encodes and decodes correctly")
    func indexerConfigNilOptionalsCodableRoundTrip() throws {
        let original = IndexerConfig(
            id: "indexer-minimal",
            name: "Minimal Indexer",
            indexerType: .torznab,
            baseURL: nil,
            apiKey: nil,
            isActive: false,
            priority: 0,
            providerSubtype: nil,
            endpointPath: nil,
            categoryFilter: nil,
            apiKeyTransport: nil
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IndexerConfig.self, from: encoded)

        #expect(decoded.baseURL == nil)
        #expect(decoded.apiKey == nil)
        #expect(decoded.categoryFilter == nil)
        #expect(decoded.providerSubtype == .customTorznab)
        #expect(decoded.endpointPath == "/api")
        #expect(decoded.apiKeyTransport == .header)
    }

    @Test("IndexerConfig all IndexerType cases encode and decode correctly")
    func indexerConfigAllIndexerTypes() throws {
        let types: [IndexerConfig.IndexerType] = [.apiBay, .yts, .eztv, .jackett, .prowlarr, .torznab, .zilean, .stremio]

        for indexerType in types {
            let config = IndexerConfig(
                id: "indexer-\(indexerType.rawValue)",
                name: "Test \(indexerType.rawValue)",
                indexerType: indexerType
            )

            let encoded = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(IndexerConfig.self, from: encoded)

            #expect(decoded.indexerType == indexerType)
        }
    }

    @Test("IndexerConfig all ProviderSubtype cases encode and decode correctly")
    func indexerConfigAllProviderSubtypes() throws {
        let subtypes: [IndexerConfig.ProviderSubtype] = [.jackett, .prowlarr, .customTorznab, .stremioAddon, .builtIn]

        for subtype in subtypes {
            let config = IndexerConfig(
                id: "indexer-subtype",
                name: "Test",
                indexerType: .torznab,
                providerSubtype: subtype
            )

            let encoded = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(IndexerConfig.self, from: encoded)

            #expect(decoded.providerSubtype == subtype)
        }
    }

    @Test("IndexerConfig all APIKeyTransport cases encode and decode correctly")
    func indexerConfigAllAPIKeyTransports() throws {
        let transports: [IndexerConfig.APIKeyTransport] = [.query, .header]

        for transport in transports {
            let config = IndexerConfig(
                id: "indexer-transport",
                name: "Test",
                indexerType: .jackett,
                apiKeyTransport: transport
            )

            let encoded = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(IndexerConfig.self, from: encoded)

            #expect(decoded.apiKeyTransport == transport)
        }
    }

    @Test("IndexerConfig built-in types have correct defaults")
    func indexerConfigBuiltInDefaults() throws {
        let builtInTypes: [IndexerConfig.IndexerType] = [.apiBay, .yts, .eztv]

        for indexerType in builtInTypes {
            let config = IndexerConfig(
                id: "indexer-builtin",
                name: "Built-In",
                indexerType: indexerType
            )

            let encoded = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(IndexerConfig.self, from: encoded)

            #expect(decoded.providerSubtype == .builtIn)
            #expect(decoded.endpointPath == "")
            #expect(decoded.apiKeyTransport == .query)
        }
    }
}
