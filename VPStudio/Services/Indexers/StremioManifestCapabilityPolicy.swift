import Foundation

/// A Stremio addon manifest `resources` entry.
///
/// Per the Stremio addon protocol, `resources` may be expressed as either a
/// shorthand array of resource name strings (e.g. `["stream", "catalog"]`) or
/// as an array of objects (e.g. `[{"name": "stream", "types": ["movie"],
/// "idPrefixes": ["tt"]}]`). This enum decodes both shapes and exposes the
/// resource name uniformly.
enum StremioManifestResource: Decodable, Equatable {
    case shorthand(String)
    case detailed(name: String, types: [String]?, idPrefixes: [String]?)

    var name: String {
        switch self {
        case .shorthand(let name):
            return name
        case .detailed(let name, _, _):
            return name
        }
    }

    private struct DetailedResource: Decodable {
        let name: String
        let types: [String]?
        let idPrefixes: [String]?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let name = try? container.decode(String.self) {
            self = .shorthand(name)
            return
        }
        let detailed = try container.decode(DetailedResource.self)
        self = .detailed(name: detailed.name, types: detailed.types, idPrefixes: detailed.idPrefixes)
    }
}

/// The capability-relevant slice of a Stremio addon manifest.
///
/// Concrete manifest response types (the indexer's and the connectivity
/// tester's) map themselves into this value so that capability decisions live
/// in one pure, testable place.
struct StremioManifestCapability: Equatable {
    /// Declared catalogs reduced to whether each is searchable and which media
    /// type it serves.
    struct Catalog: Equatable {
        let type: String
        let supportsSearch: Bool
    }

    let resources: [StremioManifestResource]
    let catalogs: [Catalog]
    let idPrefixes: [String]
}

/// Pure policy for interpreting a Stremio addon manifest's capabilities.
///
/// Kept free of networking and decoding so it can be unit-tested in isolation
/// and shared between `StremioIndexer` and `IndexerConnectivityTester`.
enum StremioManifestCapabilityPolicy {
    /// `true` when the manifest declares the `stream` resource in either the
    /// shorthand (`["stream"]`) or detailed (`[{"name": "stream"}]`) form.
    static func supportsStreamResource(_ manifest: StremioManifestCapability) -> Bool {
        manifest.resources.contains { resource in
            resource.name.caseInsensitiveCompare("stream") == .orderedSame
        }
    }

    /// `true` when the manifest declares at least one catalog that supports the
    /// `search` extra.
    static func hasSearchableCatalogs(_ manifest: StremioManifestCapability) -> Bool {
        manifest.catalogs.contains { $0.supportsSearch }
    }
}
