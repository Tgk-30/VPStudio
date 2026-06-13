import Testing
@testable import VPStudio

@Suite("Indexer Default Ranking")
struct IndexerDefaultRankingTests {
    @Test
    func defaultConfigsAreOrderedBestToWorst() {
        let configs = IndexerDefaultRanking.defaultConfigs()

        #expect(configs.map(\.id) == [
            "builtin-torrentio",
            "builtin-mediafusion",
            "builtin-yts",
            "builtin-apibay",
            "builtin-eztv",
            "builtin-torrentgalaxy",
        ])
        #expect(configs.map(\.name) == [
            "Stremio Torrentio",
            "Stremio MediaFusion",
            "YTS",
            "APiBay",
            "EZTV",
            "TorrentGalaxy",
        ])

        let defaultMediaFusion = configs.first(where: { $0.id == "builtin-mediafusion" })
        #expect(defaultMediaFusion?.indexerType == .stremio)
        #expect(defaultMediaFusion?.baseURL == "https://mediafusion.elfhosted.com")
        #expect(defaultMediaFusion?.endpointPath == "/manifest.json")

        let defaultTorrentGalaxy = configs.first(where: { $0.id == "builtin-torrentgalaxy" })
        #expect(defaultTorrentGalaxy?.indexerType == .stremio)
        #expect(defaultTorrentGalaxy?.baseURL == "https://torrentio.strem.fun/providers=torrentgalaxy")
        #expect(defaultTorrentGalaxy?.endpointPath == "/manifest.json")
    }

    @Test
    func defaultConfigsHaveCorrectActiveStatesAndSequentialPriorities() {
        let configs = IndexerDefaultRanking.defaultConfigs()

        let activeIDs = configs.filter(\.isActive).map(\.id)
        #expect(activeIDs == ["builtin-torrentio", "builtin-yts", "builtin-apibay"])

        let inactiveIDs = configs.filter { !$0.isActive }.map(\.id)
        #expect(inactiveIDs == ["builtin-mediafusion", "builtin-eztv", "builtin-torrentgalaxy"])

        #expect(configs.map(\.priority) == Array(0..<configs.count))
    }

    @Test
    func isKnownDefaultConfigRecognizesBuiltInsAndLegacyEquivalents() {
        let torrentio = IndexerDefaultRanking.rankedDefinitions[0].makeConfig(priority: 0)
        let legacyTorrentio = IndexerConfig(
            id: "legacy-torrentio",
            name: "Torrentio Legacy",
            indexerType: .stremio,
            baseURL: "https://torrentio.strem.fun",
            apiKey: nil,
            isActive: true,
            priority: 10,
            providerSubtype: .stremioAddon,
            endpointPath: "/manifest.json",
            categoryFilter: nil,
            apiKeyTransport: .query
        )
        let nearbyCustom = IndexerConfig(
            id: "custom-torrentio",
            name: "Custom Torrentio",
            indexerType: .stremio,
            baseURL: "https://torrentio.strem.fun/providers=custom",
            apiKey: nil,
            isActive: true,
            priority: 11,
            providerSubtype: .stremioAddon,
            endpointPath: "/manifest.json",
            categoryFilter: nil,
            apiKeyTransport: .query
        )

        #expect(IndexerDefaultRanking.isKnownDefaultConfig(torrentio))
        #expect(IndexerDefaultRanking.isKnownDefaultConfig(legacyTorrentio))
        #expect(!IndexerDefaultRanking.isKnownDefaultConfig(nearbyCustom))
    }

    @Test
    func addingMissingDefaultsAvoidsDuplicatesForEquivalentConfigs() {
        let custom = IndexerConfig(
            id: "custom-jackett",
            name: "Custom Jackett",
            indexerType: .jackett,
            baseURL: "https://jackett.example",
            apiKey: "key",
            isActive: true,
            priority: 9
        )
        let existingTorrentGalaxy = IndexerConfig(
            id: "builtin-torrentgalaxy",
            name: "TorrentGalaxy Legacy",
            indexerType: .torznab,
            baseURL: "https://torrentgalaxy.to",
            apiKey: nil,
            isActive: true,
            priority: 99,
            providerSubtype: .customTorznab,
            endpointPath: "/api",
            categoryFilter: nil,
            apiKeyTransport: .query
        )

        let merged = IndexerDefaultRanking.addingMissingDefaults(to: [custom, existingTorrentGalaxy])

        #expect(merged.map(\.priority) == Array(0..<merged.count))
        #expect(merged.first?.id == "custom-jackett")
        #expect(merged.dropFirst().contains(where: { $0.id == "builtin-torrentio" }))
        #expect(merged.filter { $0.id == "builtin-torrentgalaxy" }.count == 1)
        #expect(merged.contains(where: { $0.id == "builtin-mediafusion" }))
        #expect(merged.contains(where: { $0.id == "builtin-yts" }))
        #expect(merged.contains(where: { $0.id == "builtin-eztv" }))
        #expect(merged.contains(where: { $0.id == "builtin-apibay" }))
    }

    @Test
    func addingMissingDefaultsTreatsEndpointEquivalentConfigAsPresent() {
        let legacyMediaFusion = IndexerConfig(
            id: "legacy-mediafusion",
            name: "MediaFusion Legacy",
            indexerType: .stremio,
            baseURL: "https://mediafusion.elfhosted.com",
            apiKey: "legacy-key",
            isActive: true,
            priority: 20,
            providerSubtype: .stremioAddon,
            endpointPath: "/manifest.json",
            categoryFilter: "movie",
            apiKeyTransport: .header
        )

        let merged = IndexerDefaultRanking.addingMissingDefaults(to: [legacyMediaFusion])

        #expect(merged.first?.id == "legacy-mediafusion")
        #expect(merged.first?.apiKey == "legacy-key")
        #expect(merged.first?.categoryFilter == "movie")
        #expect(merged.first?.apiKeyTransport == .header)
        #expect(!merged.contains(where: { $0.id == "builtin-mediafusion" }))
        #expect(merged.map(\.priority) == Array(0..<merged.count))
    }

    @Test
    func canonicalizingKnownDefaultsRewritesLegacyBuiltInDefinitionsByID() {
        let legacyEZTV = IndexerConfig(
            id: "builtin-eztv",
            name: "EZTV Legacy",
            indexerType: .torznab,
            baseURL: "https://eztv.re",
            apiKey: nil,
            isActive: false,
            priority: 3,
            providerSubtype: .customTorznab,
            endpointPath: "/api",
            categoryFilter: nil,
            apiKeyTransport: .query
        )
        let custom = IndexerConfig(
            id: "custom",
            name: "Custom",
            indexerType: .torznab,
            baseURL: "https://custom.example",
            apiKey: "abc",
            isActive: true,
            priority: 0
        )

        let output = IndexerDefaultRanking.canonicalizingKnownDefaults(in: [custom, legacyEZTV])
        let rewrittenEZTV = output.first(where: { $0.id == "builtin-eztv" })
        let unchangedCustom = output.first(where: { $0.id == "custom" })

        #expect(rewrittenEZTV?.indexerType == .eztv)
        #expect(rewrittenEZTV?.baseURL == nil)
        #expect(rewrittenEZTV?.endpointPath == "")
        #expect(rewrittenEZTV?.providerSubtype == .builtIn)
        #expect(rewrittenEZTV?.isActive == false)
        #expect(rewrittenEZTV?.priority == 3)

        #expect(unchangedCustom == custom)
    }

    @Test
    func prioritizeKnownDefaultsReordersBuiltInsToCanonicalRanking() {
        let apibay = IndexerConfig(
            id: "legacy-apibay",
            name: "APiBay",
            indexerType: .apiBay,
            baseURL: nil,
            apiKey: nil,
            isActive: true,
            priority: 0
        )
        let yts = IndexerConfig(
            id: "legacy-yts",
            name: "YTS",
            indexerType: .yts,
            baseURL: nil,
            apiKey: nil,
            isActive: true,
            priority: 1
        )
        let reordered = IndexerDefaultRanking.prioritizeKnownDefaults(in: [apibay, yts])

        #expect(reordered.map(\.name) == ["YTS", "APiBay"])
        #expect(reordered.map(\.priority) == [0, 1])
    }

    @Test
    func prioritizeKnownDefaultsKeepsUnknownConfigsAfterRankedMatches() {
        let customJackett = IndexerConfig(
            id: "custom-jackett",
            name: "Custom Jackett",
            indexerType: .jackett,
            baseURL: "https://jackett.example",
            apiKey: "key",
            isActive: true,
            priority: 99
        )
        let yts = IndexerConfig(
            id: "legacy-yts",
            name: "YTS Mirror",
            indexerType: .yts,
            baseURL: nil,
            apiKey: nil,
            isActive: true,
            priority: 4
        )
        let customStremio = IndexerConfig(
            id: "custom-stremio",
            name: "Custom Stremio",
            indexerType: .stremio,
            baseURL: "https://stremio.example",
            apiKey: nil,
            isActive: true,
            priority: 3,
            providerSubtype: .stremioAddon,
            endpointPath: "/manifest.json",
            categoryFilter: nil,
            apiKeyTransport: .query
        )
        let torrentio = IndexerConfig(
            id: "legacy-torrentio",
            name: "Torrentio Mirror",
            indexerType: .stremio,
            baseURL: "https://torrentio.strem.fun",
            apiKey: nil,
            isActive: false,
            priority: 2,
            providerSubtype: .stremioAddon,
            endpointPath: "/manifest.json",
            categoryFilter: nil,
            apiKeyTransport: .query
        )

        let reordered = IndexerDefaultRanking.prioritizeKnownDefaults(
            in: [customJackett, yts, customStremio, torrentio]
        )

        #expect(reordered.map(\.id) == [
            "legacy-torrentio",
            "legacy-yts",
            "custom-jackett",
            "custom-stremio",
        ])
        #expect(reordered.map(\.priority) == [0, 1, 2, 3])
        #expect(reordered[0].isActive == false)
    }

    @Test
    func deletedBuiltInsReturnsDefinitionsNotInExistingConfigs() {
        let torrentioConfig = IndexerDefaultRanking.rankedDefinitions[0].makeConfig(priority: 0)
        let ytsConfig = IndexerDefaultRanking.rankedDefinitions.first(where: { $0.id == "builtin-yts" })!.makeConfig(priority: 1)

        let missing = IndexerDefaultRanking.deletedBuiltIns(from: [torrentioConfig, ytsConfig])

        #expect(missing.map(\.id) == ["builtin-mediafusion", "builtin-apibay", "builtin-eztv", "builtin-torrentgalaxy"])
    }

    @Test
    func deletedBuiltInsTreatsEndpointEquivalentConfigsAsPresent() {
        let legacyMediaFusion = IndexerConfig(
            id: "legacy-mediafusion",
            name: "MediaFusion Legacy",
            indexerType: .stremio,
            baseURL: "https://mediafusion.elfhosted.com",
            apiKey: nil,
            isActive: true,
            priority: 9,
            providerSubtype: .stremioAddon,
            endpointPath: "/manifest.json",
            categoryFilter: nil,
            apiKeyTransport: .query
        )

        let missing = IndexerDefaultRanking.deletedBuiltIns(from: [legacyMediaFusion])

        #expect(!missing.map(\.id).contains("builtin-mediafusion"))
    }

    @Test
    func canonicalizingKnownDefaultsOnlyRewritesMatchingIDs() {
        let legacyTorrentioByEndpoint = IndexerConfig(
            id: "legacy-torrentio",
            name: "Torrentio Legacy",
            indexerType: .stremio,
            baseURL: "https://torrentio.strem.fun",
            apiKey: "kept",
            isActive: false,
            priority: 12,
            providerSubtype: .stremioAddon,
            endpointPath: "/manifest.json",
            categoryFilter: "movie",
            apiKeyTransport: .header
        )

        let output = IndexerDefaultRanking.canonicalizingKnownDefaults(in: [legacyTorrentioByEndpoint])

        #expect(output == [legacyTorrentioByEndpoint])
    }

    @Test
    func definitionMatchesByIDOrExactEndpointSignature() {
        let definition = IndexerDefaultRanking.rankedDefinitions[0]
        let matchingByID = IndexerConfig(
            id: definition.id,
            name: "Different Built-In Name",
            indexerType: .torznab,
            baseURL: "https://different.example",
            apiKey: nil,
            isActive: true,
            priority: 1,
            providerSubtype: .customTorznab,
            endpointPath: "/api",
            categoryFilter: nil,
            apiKeyTransport: .header
        )
        let matchingByEndpoint = IndexerConfig(
            id: "legacy-torrentio",
            name: "Torrentio Legacy",
            indexerType: definition.type,
            baseURL: definition.baseURL,
            apiKey: nil,
            isActive: false,
            priority: 2,
            providerSubtype: definition.providerSubtype,
            endpointPath: definition.endpointPath,
            categoryFilter: nil,
            apiKeyTransport: definition.apiKeyTransport
        )
        let wrongType = IndexerConfig(
            id: "wrong-type",
            name: "Wrong Type",
            indexerType: .torznab,
            baseURL: definition.baseURL,
            apiKey: nil,
            isActive: true,
            priority: 3,
            providerSubtype: .customTorznab,
            endpointPath: definition.endpointPath,
            categoryFilter: nil,
            apiKeyTransport: .query
        )
        let wrongBaseURL = IndexerConfig(
            id: "wrong-base",
            name: "Wrong Base",
            indexerType: definition.type,
            baseURL: "https://torrentio.example",
            apiKey: nil,
            isActive: true,
            priority: 4,
            providerSubtype: definition.providerSubtype,
            endpointPath: definition.endpointPath,
            categoryFilter: nil,
            apiKeyTransport: definition.apiKeyTransport
        )
        let wrongEndpoint = IndexerConfig(
            id: "wrong-endpoint",
            name: "Wrong Endpoint",
            indexerType: definition.type,
            baseURL: definition.baseURL,
            apiKey: nil,
            isActive: true,
            priority: 5,
            providerSubtype: definition.providerSubtype,
            endpointPath: "/different.json",
            categoryFilter: nil,
            apiKeyTransport: definition.apiKeyTransport
        )

        #expect(definition.matches(matchingByID))
        #expect(definition.matches(matchingByEndpoint))
        #expect(!definition.matches(wrongType))
        #expect(!definition.matches(wrongBaseURL))
        #expect(!definition.matches(wrongEndpoint))
    }

    @Test
    func deletedBuiltInsReturnsAllWhenNoConfigsExist() {
        let missing = IndexerDefaultRanking.deletedBuiltIns(from: [])
        #expect(missing.count == 6)
        #expect(missing.map(\.id) == IndexerDefaultRanking.rankedDefinitions.map(\.id))
    }

    @Test
    func deletedBuiltInsReturnsEmptyWhenAllPresent() {
        let allConfigs = IndexerDefaultRanking.defaultConfigs()
        let missing = IndexerDefaultRanking.deletedBuiltIns(from: allConfigs)
        #expect(missing.isEmpty)
    }
}
