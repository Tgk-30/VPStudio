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
    var tmdbId: Int?
    var episodeId: String?
    var nextEpisode: NextEpisodeCandidate?

    init(
        id: UUID = UUID(),
        stream: StreamInfo,
        availableStreams: [StreamInfo] = [],
        mediaTitle: String,
        mediaId: String,
        tmdbId: Int? = nil,
        episodeId: String? = nil,
        nextEpisode: NextEpisodeCandidate? = nil
    ) {
        self.id = id
        self.stream = stream
        self.availableStreams = availableStreams
        self.mediaTitle = mediaTitle
        self.mediaId = mediaId
        self.tmdbId = tmdbId
        self.episodeId = episodeId
        self.nextEpisode = nextEpisode
    }
}
