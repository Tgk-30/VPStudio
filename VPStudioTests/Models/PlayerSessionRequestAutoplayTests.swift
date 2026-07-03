import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerSessionRequest Auto-Play")
struct PlayerSessionRequestAutoplayTests {
    @Test func nextEpisodeCandidateRoundTripsThroughCodableSession() throws {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/video.mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "show.s01e01.mkv",
            sizeBytes: 100,
            debridService: "realdebrid"
        )
        let request = PlayerSessionRequest(
            stream: stream,
            mediaTitle: "Episode 1",
            mediaId: "tt123",
            episodeId: "s1e1",
            nextEpisode: .init(
                episodeId: "s1e2",
                seasonNumber: 1,
                episodeNumber: 2,
                title: "S01E02 - Next"
            )
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(PlayerSessionRequest.self, from: data)

        #expect(decoded.nextEpisode?.episodeId == "s1e2")
        #expect(decoded.nextEpisode?.seasonNumber == 1)
        #expect(decoded.nextEpisode?.episodeNumber == 2)
        #expect(decoded.nextEpisode?.title == "S01E02 - Next")
    }
}
