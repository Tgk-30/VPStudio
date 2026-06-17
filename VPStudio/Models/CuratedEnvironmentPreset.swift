import Foundation

enum CuratedEnvironmentProvider: String, Codable, Sendable, CaseIterable {
    case official
    case github
    case polyHaven

    var displayName: String {
        switch self {
        case .official:
            return "Official"
        case .github:
            return "GitHub"
        case .polyHaven:
            return "Poly Haven"
        }
    }
}

struct CuratedEnvironmentPreset: Identifiable, Sendable, Equatable {
    var id: String
    var name: String
    var description: String
    var provider: CuratedEnvironmentProvider
    var downloadURL: URL
    var sourceAttributionURL: String
    var licenseName: String
    var defaultHdriYawOffset: Float?
    /// Genre/mood tag (e.g. "cinema", "scifi") persisted onto the imported
    /// `EnvironmentAsset.environmentTag` so genre-based auto-suggestion can resolve
    /// this preset once installed. Matches `GenreEnvironmentSuggestionPolicy` match keys.
    /// Nil means the preset participates in no auto-match.
    var defaultEnvironmentTag: String?

    init(
        id: String,
        name: String,
        description: String,
        provider: CuratedEnvironmentProvider,
        downloadURL: URL,
        sourceAttributionURL: String,
        licenseName: String,
        defaultHdriYawOffset: Float? = nil,
        defaultEnvironmentTag: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.provider = provider
        self.downloadURL = downloadURL
        self.sourceAttributionURL = sourceAttributionURL
        self.licenseName = licenseName
        self.defaultHdriYawOffset = defaultHdriYawOffset
        self.defaultEnvironmentTag = defaultEnvironmentTag
    }
}
