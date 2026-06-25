import Foundation

struct PlayerSessionRequest: Codable, Sendable, Identifiable, Hashable {
    struct NextEpisodeCandidate: Codable, Sendable, Equatable, Hashable {
        var episodeId: String
        var seasonNumber: Int
        var episodeNumber: Int
        var title: String

        init(
            episodeId: String,
            seasonNumber: Int,
            episodeNumber: Int,
            title: String
        ) {
            self.episodeId = episodeId
            self.seasonNumber = seasonNumber
            self.episodeNumber = episodeNumber
            self.title = title
        }
    }

    var id: UUID
    var stream: StreamInfo
    var availableStreams: [StreamInfo]
    var mediaTitle: String
    var mediaId: String
    var imdbId: String?
    var tmdbId: Int?
    var posterPath: String?
    var backdropPath: String?
    var episodeId: String?
    var nextEpisode: NextEpisodeCandidate?

    init(
        id: UUID = UUID(),
        stream: StreamInfo,
        availableStreams: [StreamInfo] = [],
        mediaTitle: String,
        mediaId: String,
        imdbId: String? = nil,
        tmdbId: Int? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        episodeId: String? = nil,
        nextEpisode: NextEpisodeCandidate? = nil
    ) {
        self.id = id
        self.stream = stream
        self.availableStreams = availableStreams
        self.mediaTitle = mediaTitle
        self.mediaId = mediaId
        self.imdbId = IMDbIdentifierPolicy.firstID(in: imdbId) ?? IMDbIdentifierPolicy.firstID(in: mediaId)
        self.tmdbId = tmdbId
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.episodeId = episodeId
        self.nextEpisode = nextEpisode
    }

    // Identity is keyed solely on the stable `id` (a UUID assigned once when the
    // session is opened and carried through `CodingKeys`). SwiftUI's
    // `WindowGroup(id:"player", for:)` serializes the value into the scene and
    // hands a *round-tripped* copy back to `dismissWindow(id:value:)`. Synthesized
    // Equatable/Hashable would compare every field — including `StreamInfo`'s
    // runtime-only `requestHeaders`, which is excluded from `CodingKeys` and so
    // comes back `nil` after the round-trip. That mismatch made `dismissWindow`
    // fail to find the window for KSPlayer-path streams (Stremio/direct), leaving a
    // dead player window open. Comparing only `id` makes the round-tripped value
    // match the in-memory request regardless of any non-encoded fields.
    static func == (lhs: PlayerSessionRequest, rhs: PlayerSessionRequest) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
