import Testing
import Foundation
@testable import VPStudio

@Suite("PlayerSessionRequest Properties")
struct PlayerSessionRequestModelTests {
    @Test("Request properties are set correctly")
    func requestProperties() {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let availableStreams = [
            StreamInfo(
                streamURL: URL(string: "https://example.com/stream2.mp4")!,
                quality: .hd720p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: "stream2.mp4",
                sizeBytes: 512,
                debridService: "debrid-id"
            )
        ]

        let request = PlayerSessionRequest(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
            stream: stream,
            availableStreams: availableStreams,
            mediaTitle: "Test Movie",
            mediaId: "media-123",
            tmdbId: 42_424,
            episodeId: "episode-456"
        )

        #expect(request.id == UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!)
        #expect(request.stream == stream)
        #expect(request.availableStreams == availableStreams)
        #expect(request.mediaTitle == "Test Movie")
        #expect(request.mediaId == "media-123")
        #expect(request.tmdbId == 42_424)
        #expect(request.episodeId == "episode-456")
    }

    @Test("Request with default ID generates UUID")
    func defaultIDGeneration() {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let request = PlayerSessionRequest(
            stream: stream,
            mediaTitle: "Test Movie",
            mediaId: "media-123"
        )

        #expect(request.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        #expect(request.availableStreams.isEmpty)
        #expect(request.tmdbId == nil)
        #expect(request.episodeId == nil)
        #expect(request.nextEpisode == nil)
    }

    @Test("Request with nil episode ID")
    func nilEpisodeID() {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let request = PlayerSessionRequest(
            stream: stream,
            mediaTitle: "Test Movie",
            mediaId: "media-123",
            episodeId: nil
        )

        #expect(request.episodeId == nil)
    }
}

@Suite("PlayerSessionRequest Init Validation")
struct PlayerSessionRequestModelInitValidationTests {
    @Test("Request requires stream")
    func requiresStream() {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let request = PlayerSessionRequest(
            stream: stream,
            mediaTitle: "Test Movie",
            mediaId: "media-123"
        )

        #expect(request.stream.id == "debrid-id-stream.mp4-1080p-H.264-https://example.com/stream.mp4")
        #expect(request.stream.streamURL == URL(string: "https://example.com/stream.mp4")!)
    }

    @Test("Request requires media title")
    func requiresMediaTitle() {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let request = PlayerSessionRequest(
            stream: stream,
            mediaTitle: "Test Movie",
            mediaId: "media-123"
        )

        #expect(request.mediaTitle == "Test Movie")
    }

    @Test("Request requires media ID")
    func requiresMediaID() {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let request = PlayerSessionRequest(
            stream: stream,
            mediaTitle: "Test Movie",
            mediaId: "media-123"
        )

        #expect(request.mediaId == "media-123")
    }
}

@Suite("PlayerSessionRequest Stream Pool Construction")
struct PlayerSessionRequestModelStreamPoolTests {
    @Test("Available streams include the main stream")
    func availableStreamsIncludeMain() {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let request = PlayerSessionRequest(
            stream: stream,
            availableStreams: [stream],
            mediaTitle: "Test Movie",
            mediaId: "media-123"
        )

        #expect(request.availableStreams.contains(stream))
    }

    @Test("Available streams can be empty")
    func emptyAvailableStreams() {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let request = PlayerSessionRequest(
            stream: stream,
            availableStreams: [],
            mediaTitle: "Test Movie",
            mediaId: "media-123"
        )

        #expect(request.availableStreams.isEmpty)
    }

    @Test("Available streams can contain multiple streams")
    func multipleAvailableStreams() {
        let stream1 = StreamInfo(
            streamURL: URL(string: "https://example.com/stream1.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream1.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let stream2 = StreamInfo(
            streamURL: URL(string: "https://example.com/stream2.mp4")!,
            quality: .hd720p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream2.mp4",
            sizeBytes: 512,
            debridService: "debrid-id"
        )

        let stream3 = StreamInfo(
            streamURL: URL(string: "https://example.com/stream3.mp4")!,
            quality: .sd480p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream3.mp4",
            sizeBytes: 256,
            debridService: "debrid-id"
        )

        let request = PlayerSessionRequest(
            stream: stream1,
            availableStreams: [stream2, stream3],
            mediaTitle: "Test Movie",
            mediaId: "media-123"
        )

        #expect(request.availableStreams.count == 2)
        #expect(request.availableStreams.contains(stream2))
        #expect(request.availableStreams.contains(stream3))
        #expect(!request.availableStreams.contains(stream1))
    }
}

@Suite("PlayerSessionRequest Codable Round-Trip")
struct PlayerSessionRequestModelCodableTests {
    @Test("PlayerSessionRequest encodes and decodes correctly")
    func codableRoundTrip() throws {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let availableStreams = [
            StreamInfo(
                streamURL: URL(string: "https://example.com/stream2.mp4")!,
                quality: .hd720p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: "stream2.mp4",
                sizeBytes: 512,
                debridService: "debrid-id"
            )
        ]

        let originalRequest = PlayerSessionRequest(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
            stream: stream,
            availableStreams: availableStreams,
            mediaTitle: "Test Movie",
            mediaId: "media-123",
            tmdbId: 42_424,
            episodeId: "episode-456"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalRequest)
        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(PlayerSessionRequest.self, from: data)

        #expect(decodedRequest.id == originalRequest.id)
        #expect(decodedRequest.stream == originalRequest.stream)
        #expect(decodedRequest.availableStreams == originalRequest.availableStreams)
        #expect(decodedRequest.mediaTitle == originalRequest.mediaTitle)
        #expect(decodedRequest.mediaId == originalRequest.mediaId)
        #expect(decodedRequest.tmdbId == originalRequest.tmdbId)
        #expect(decodedRequest.episodeId == originalRequest.episodeId)
    }

    @Test("PlayerSessionRequest with minimal data encodes and decodes")
    func minimalCodableRoundTrip() throws {
        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/stream.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "stream.mp4",
            sizeBytes: 1024,
            debridService: "debrid-id"
        )

        let originalRequest = PlayerSessionRequest(
            stream: stream,
            mediaTitle: "Test Movie",
            mediaId: "media-123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalRequest)
        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(PlayerSessionRequest.self, from: data)

        #expect(decodedRequest.stream == originalRequest.stream)
        #expect(decodedRequest.mediaTitle == originalRequest.mediaTitle)
        #expect(decodedRequest.mediaId == originalRequest.mediaId)
        #expect(decodedRequest.episodeId == nil)
    }
}
