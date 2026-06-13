import Foundation
import Testing
@testable import VPStudio

@Suite("Player Watch Progress Policy")
struct PlayerWatchProgressPolicyTests {
    @Test func makeSnapshotReturnsNilWithoutMediaOrDuration() {
        let stream = Self.stream()

        #expect(
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: nil,
                episodeId: nil,
                mediaTitle: "Movie",
                stream: stream,
                currentTime: 10,
                duration: 100
            ) == nil
        )
        #expect(
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: "tt123",
                episodeId: nil,
                mediaTitle: "Movie",
                stream: stream,
                currentTime: 10,
                duration: 0
            ) == nil
        )
        #expect(
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: "tt123",
                episodeId: nil,
                mediaTitle: "Movie",
                stream: stream,
                currentTime: 10,
                duration: .nan
            ) == nil
        )
        #expect(
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: "tt123",
                episodeId: nil,
                mediaTitle: "Movie",
                stream: stream,
                currentTime: 10,
                duration: .infinity
            ) == nil
        )
        #expect(
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: "tt123",
                episodeId: nil,
                mediaTitle: "Movie",
                stream: stream,
                currentTime: 10,
                duration: -1
            ) == nil
        )
    }

    @Test func makeSnapshotBuildsMovieProgressFromStreamMetadata() throws {
        let watchedAt = Date(timeIntervalSince1970: 1_771_000_000)
        let stream = Self.stream(fileName: "Movie.File.mkv", quality: .uhd4k, debridService: "realdebrid")

        let snapshot = try #require(PlayerWatchProgressPolicy.makeSnapshot(
            mediaId: "tt1234567",
            episodeId: nil,
            mediaTitle: nil,
            stream: stream,
            currentTime: 899,
            duration: 1_000,
            watchedAt: watchedAt
        ))

        #expect(snapshot.id == "tt1234567-progress")
        #expect(snapshot.mediaId == "tt1234567")
        #expect(snapshot.episodeId == nil)
        #expect(snapshot.title == "Movie.File.mkv")
        #expect(snapshot.progress == 899)
        #expect(snapshot.duration == 1_000)
        #expect(snapshot.quality == VideoQuality.uhd4k.rawValue)
        #expect(snapshot.debridService == "realdebrid")
        #expect(snapshot.streamURL == "https://example.com/movie.mkv")
        #expect(snapshot.watchedAt == watchedAt)
        #expect(snapshot.isCompleted == false)
    }

    @Test func makeSnapshotBuildsEpisodeProgressAndCompletionThreshold() throws {
        let stream = Self.stream(fileName: "Show.S01E02.mkv")

        let almostComplete = try #require(PlayerWatchProgressPolicy.makeSnapshot(
            mediaId: "tt7654321",
            episodeId: "s1e2",
            mediaTitle: "Episode 2",
            stream: stream,
            currentTime: 900,
            duration: 1_000
        ))
        let complete = try #require(PlayerWatchProgressPolicy.makeSnapshot(
            mediaId: "tt7654321",
            episodeId: "s1e2",
            mediaTitle: "Episode 2",
            stream: stream,
            currentTime: 901,
            duration: 1_000
        ))

        #expect(almostComplete.id == "tt7654321-s1e2-progress")
        #expect(almostComplete.episodeId == "s1e2")
        #expect(almostComplete.title == "Episode 2")
        #expect(almostComplete.isCompleted == true)
        #expect(complete.isCompleted == true)
    }

    @Test func makeSnapshotUsesActualDurationForCompletionForShortClips() throws {
        let stream = Self.stream(fileName: "Short.mkv")

        let justBelowThreshold = try #require(
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: "short",
                episodeId: nil,
                mediaTitle: "Short clip",
                stream: stream,
                currentTime: 0.44,
                duration: 0.5
            )
        )
        let threshold = try #require(
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: "short",
                episodeId: nil,
                mediaTitle: "Short clip",
                stream: stream,
                currentTime: 0.45,
                duration: 0.5
            )
        )
        let completed = try #require(
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: "short",
                episodeId: nil,
                mediaTitle: "Short clip",
                stream: stream,
                currentTime: 10,
                duration: 0.5
            )
        )

        #expect(justBelowThreshold.isCompleted == false)
        #expect(threshold.isCompleted == true)
        #expect(completed.isCompleted == true)
        #expect(justBelowThreshold.progress == 0.44)
        #expect(justBelowThreshold.duration == 0.5)
        #expect(completed.progress == 0.5)
        #expect(completed.duration == 0.5)
    }

    @Test func makeSnapshotClampsNegativeCurrentTimeToZeroWithoutDroppingRecord() {
        let stream = Self.stream(fileName: "Short.mkv")

        let snapshot = PlayerWatchProgressPolicy.makeSnapshot(
            mediaId: "short",
            episodeId: nil,
            mediaTitle: "Short clip",
            stream: stream,
            currentTime: -12,
            duration: 100
        )

        #expect(snapshot?.progress == 0)
    }

    @Test func makeSnapshotClampsNonFiniteCurrentTimeToZero() {
        let stream = Self.stream(fileName: "Short.mkv")

        let snapshots = [
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: "short",
                episodeId: nil,
                mediaTitle: "Short clip",
                stream: stream,
                currentTime: .nan,
                duration: 100
            ),
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: "short",
                episodeId: nil,
                mediaTitle: "Short clip",
                stream: stream,
                currentTime: .infinity,
                duration: 100
            ),
            PlayerWatchProgressPolicy.makeSnapshot(
                mediaId: "short",
                episodeId: nil,
                mediaTitle: "Short clip",
                stream: stream,
                currentTime: -.infinity,
                duration: 100
            ),
        ]

        for snapshot in snapshots {
            #expect(snapshot?.progress == 0)
            #expect(snapshot?.isCompleted == false)
        }
    }

    @Test func makeSnapshotClampsOverDurationCurrentTimeToDuration() {
        let stream = Self.stream(fileName: "clip.mkv")

        let snapshot = PlayerWatchProgressPolicy.makeSnapshot(
            mediaId: "short",
            episodeId: nil,
            mediaTitle: "Short clip",
            stream: stream,
            currentTime: 250,
            duration: 100
        )

        #expect(snapshot?.progress == 100)
        #expect(snapshot?.isCompleted == true)
    }

    private static func stream(
        fileName: String = "movie.mkv",
        quality: VideoQuality = .hd1080p,
        debridService: String = "premiumize"
    ) -> StreamInfo {
        StreamInfo(
            streamURL: URL(string: "https://example.com/movie.mkv")!,
            quality: quality,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: fileName,
            sizeBytes: 100,
            debridService: debridService
        )
    }
}
