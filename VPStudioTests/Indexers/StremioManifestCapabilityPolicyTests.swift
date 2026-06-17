import Foundation
import Testing
@testable import VPStudio

@Suite("Stremio Manifest Capability Policy")
struct StremioManifestCapabilityPolicyTests {

    // MARK: - resources decoding (shorthand vs. detailed)

    @Test func decodesShorthandStringResources() throws {
        let resources = try decodeResources(#"["catalog","stream","meta"]"#)

        #expect(resources == [
            .shorthand("catalog"),
            .shorthand("stream"),
            .shorthand("meta"),
        ])
        #expect(resources.map(\.name) == ["catalog", "stream", "meta"])
    }

    @Test func decodesDetailedObjectResources() throws {
        let json = #"""
        [
          {"name":"stream","types":["movie","series"],"idPrefixes":["tt"]},
          {"name":"catalog","types":["movie"]}
        ]
        """#
        let resources = try decodeResources(json)

        #expect(resources == [
            .detailed(name: "stream", types: ["movie", "series"], idPrefixes: ["tt"]),
            .detailed(name: "catalog", types: ["movie"], idPrefixes: nil),
        ])
        #expect(resources.map(\.name) == ["stream", "catalog"])
    }

    @Test func decodesMixedShorthandAndDetailedResources() throws {
        let json = #"""
        ["catalog",{"name":"stream","types":["movie"],"idPrefixes":["tt"]}]
        """#
        let resources = try decodeResources(json)

        #expect(resources == [
            .shorthand("catalog"),
            .detailed(name: "stream", types: ["movie"], idPrefixes: ["tt"]),
        ])
    }

    // MARK: - supportsStreamResource

    @Test func supportsStreamResourceTrueForShorthandForm() throws {
        let capability = makeCapability(resourcesJSON: #"["catalog","stream"]"#)
        #expect(StremioManifestCapabilityPolicy.supportsStreamResource(capability))
    }

    @Test func supportsStreamResourceTrueForDetailedObjectForm() throws {
        let capability = makeCapability(
            resourcesJSON: #"[{"name":"stream","types":["movie"],"idPrefixes":["tt"]}]"#
        )
        #expect(StremioManifestCapabilityPolicy.supportsStreamResource(capability))
    }

    @Test func supportsStreamResourceIsCaseInsensitive() throws {
        let capability = makeCapability(resourcesJSON: #"["Stream"]"#)
        #expect(StremioManifestCapabilityPolicy.supportsStreamResource(capability))
    }

    @Test func supportsStreamResourceFalseWhenNoStreamDeclared() throws {
        let capability = makeCapability(
            resourcesJSON: #"["catalog",{"name":"meta","types":["movie"]}]"#
        )
        #expect(!StremioManifestCapabilityPolicy.supportsStreamResource(capability))
    }

    @Test func supportsStreamResourceFalseWhenResourcesEmpty() {
        let capability = StremioManifestCapability(resources: [], catalogs: [], idPrefixes: [])
        #expect(!StremioManifestCapabilityPolicy.supportsStreamResource(capability))
    }

    // MARK: - hasSearchableCatalogs

    @Test func hasSearchableCatalogsTrueWhenAnyCatalogSupportsSearch() {
        let capability = StremioManifestCapability(
            resources: [],
            catalogs: [
                .init(type: "movie", supportsSearch: false),
                .init(type: "series", supportsSearch: true),
            ],
            idPrefixes: []
        )
        #expect(StremioManifestCapabilityPolicy.hasSearchableCatalogs(capability))
    }

    @Test func hasSearchableCatalogsFalseWhenNoCatalogSupportsSearch() {
        let capability = StremioManifestCapability(
            resources: [],
            catalogs: [
                .init(type: "movie", supportsSearch: false),
                .init(type: "series", supportsSearch: false),
            ],
            idPrefixes: []
        )
        #expect(!StremioManifestCapabilityPolicy.hasSearchableCatalogs(capability))
    }

    @Test func hasSearchableCatalogsFalseWhenCatalogsEmpty() {
        let capability = StremioManifestCapability(resources: [], catalogs: [], idPrefixes: [])
        #expect(!StremioManifestCapabilityPolicy.hasSearchableCatalogs(capability))
    }

    @Test func streamOnlyAddonSupportsStreamButHasNoSearchableCatalogs() throws {
        let capability = makeCapability(resourcesJSON: #"["stream"]"#)
        #expect(StremioManifestCapabilityPolicy.supportsStreamResource(capability))
        #expect(!StremioManifestCapabilityPolicy.hasSearchableCatalogs(capability))
    }

    // MARK: - Helpers

    private func decodeResources(_ json: String) throws -> [StremioManifestResource] {
        try JSONDecoder().decode([StremioManifestResource].self, from: Data(json.utf8))
    }

    private func makeCapability(
        resourcesJSON: String,
        catalogs: [StremioManifestCapability.Catalog] = [],
        idPrefixes: [String] = []
    ) -> StremioManifestCapability {
        let resources = (try? decodeResources(resourcesJSON)) ?? []
        return StremioManifestCapability(
            resources: resources,
            catalogs: catalogs,
            idPrefixes: idPrefixes
        )
    }
}
