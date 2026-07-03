import Foundation
import Testing
import AVFoundation
import CoreGraphics
@testable import VPStudio

// MARK: - videoStartSucceeded (BUG 3: audio-only / black-screen failover)

@Suite("AVPlayerEngine - videoStartSucceeded")
struct AVPlayerEngineVideoStartSucceededTests {

    @Test("Succeeds only when playing AND has video tracks AND non-zero presentation size")
    func succeedsWhenPlayingWithVideoAndSize() {
        #expect(AVPlayerEngine.videoStartSucceeded(
            hasVideoTracks: true,
            presentationSize: CGSize(width: 1920, height: 1080),
            isPlaying: true
        ))
    }

    @Test("Fails when playing but no video tracks (audio-only black screen)")
    func failsWhenAudioOnly() {
        #expect(AVPlayerEngine.videoStartSucceeded(
            hasVideoTracks: false,
            presentationSize: CGSize(width: 1920, height: 1080),
            isPlaying: true
        ) == false)
    }

    @Test("Fails when playing with video track but zero presentation size (no frame yet)")
    func failsWhenZeroPresentationSize() {
        #expect(AVPlayerEngine.videoStartSucceeded(
            hasVideoTracks: true,
            presentationSize: .zero,
            isPlaying: true
        ) == false)
    }

    @Test("Fails when a single presentation dimension is zero")
    func failsWhenOnePresentationDimensionZero() {
        #expect(AVPlayerEngine.videoStartSucceeded(
            hasVideoTracks: true,
            presentationSize: CGSize(width: 1920, height: 0),
            isPlaying: true
        ) == false)
        #expect(AVPlayerEngine.videoStartSucceeded(
            hasVideoTracks: true,
            presentationSize: CGSize(width: 0, height: 1080),
            isPlaying: true
        ) == false)
    }

    @Test("Fails when not playing regardless of video presence")
    func failsWhenNotPlaying() {
        #expect(AVPlayerEngine.videoStartSucceeded(
            hasVideoTracks: true,
            presentationSize: CGSize(width: 1920, height: 1080),
            isPlaying: false
        ) == false)
    }

    @Test("Fails when nothing is true (degenerate)")
    func failsWhenAllFalse() {
        #expect(AVPlayerEngine.videoStartSucceeded(
            hasVideoTracks: false,
            presentationSize: .zero,
            isPlaying: false
        ) == false)
    }
}

// MARK: - Engine order (BUG 3: KSPlayer must come after AVPlayer on visionOS)

@Suite("AVPlayerEngine - failover engine order")
struct AVPlayerEngineFailoverOrderTests {

    @Test("On visionOS, AVPlayer is tried before KSPlayer in every strategy")
    func ksPlayerComesAfterAVPlayerOnVisionOS() throws {
        #if os(visionOS)
        let selector = PlayerEngineSelector()
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            codec: .h264,
            fileName: "movie.mp4"
        )
        for strategy in PlayerEngineStrategy.allCases {
            let order = selector.engineOrder(for: stream, strategy: strategy)
            let avIndex = try #require(order.firstIndex(of: .avPlayer))
            let ksIndex = try #require(order.firstIndex(of: .ksPlayer))
            #expect(avIndex < ksIndex)
        }
        #endif
    }

    @Test("Performance strategy always tries AVPlayer before KSPlayer")
    func performanceStrategyAVPlayerFirst() {
        let selector = PlayerEngineSelector()
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            codec: .h264,
            fileName: "movie.mp4"
        )
        let order = selector.engineOrder(for: stream, strategy: .performance)
        #expect(order == [.avPlayer, .ksPlayer])
    }
}

// MARK: - failureDescription

@Suite("AVPlayerEngine - failureDescription")
struct AVPlayerEngineFailureDescriptionTests {

    @Test func failureDescriptionWithHTTPStatusAndComment() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 404, comment: "Not Found", itemError: nil)
        #expect(desc == "HTTP 404: Not Found")
    }

    @Test func failureDescriptionWithHTTPStatusOnlyNilComment() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 500, comment: nil, itemError: nil)
        #expect(desc == "HTTP 500 while loading stream.")
    }

    @Test func failureDescriptionWithHTTPStatusOnlyEmptyComment() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 503, comment: "", itemError: nil)
        #expect(desc == "HTTP 503 while loading stream.")
    }

    @Test func failureDescriptionWithCommentOnlyNoStatus() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 0, comment: "Network unreachable", itemError: nil)
        #expect(desc == "Network unreachable")
    }

    @Test func failureDescriptionWithUnknownError() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 0, comment: nil, itemError: nil)
        #expect(desc == "Unknown AVPlayer item error")
    }

    @Test func failureDescriptionFallsBackToItemErrorLocalizedDescription() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Custom error"])
        let desc = AVPlayerEngine.failureDescription(statusCode: 0, comment: nil, itemError: error)
        #expect(desc == "Custom error")
    }

    @Test func failureDescriptionPrefersStatusAndCommentOverItemError() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ignored"])
        let desc = AVPlayerEngine.failureDescription(statusCode: 403, comment: "Forbidden", itemError: error)
        #expect(desc == "HTTP 403: Forbidden")
    }

    @Test func failureDescriptionWithNegativeStatusCodeFallsBackToComment() {
        let desc = AVPlayerEngine.failureDescription(statusCode: -1, comment: "Negative status", itemError: nil)
        #expect(desc == "Negative status")
    }

    @Test func failureDescriptionWithNegativeStatusCodeAndNoCommentFallsBackToError() {
        let error = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Fallback error"])
        let desc = AVPlayerEngine.failureDescription(statusCode: -1, comment: nil, itemError: error)
        #expect(desc == "Fallback error")
    }

    @Test func failureDescriptionWithLargeStatusCode() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 999, comment: "Rate limited", itemError: nil)
        #expect(desc == "HTTP 999: Rate limited")
    }

    @Test func failureDescriptionTrimsWhitespaceFromComment() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 401, comment: "  Unauthorized  ", itemError: nil)
        #expect(desc == "HTTP 401: Unauthorized")
    }

    @Test func failureDescriptionTreatsWhitespaceOnlyCommentAsEmpty() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 502, comment: "   ", itemError: nil)
        #expect(desc == "HTTP 502 while loading stream.")
    }

    @Test func failureDescriptionWhitespaceOnlyCommentNoStatusFallsBackToUnknown() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 0, comment: "   ", itemError: nil)
        #expect(desc == "Unknown AVPlayer item error")
    }

    @Test func failureDescriptionWhitespaceOnlyCommentNoStatusFallsBackToError() {
        let error = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Item failure"])
        let desc = AVPlayerEngine.failureDescription(statusCode: 0, comment: "   ", itemError: error)
        #expect(desc == "Item failure")
    }

    @Test func failureDescriptionWithSpecialCharactersInComment() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 0, comment: "Error: token=abc123&expired", itemError: nil)
        #expect(desc == "Error: token=REDACTED&expired")
    }

    @Test func failureDescriptionRedactsSignedURLAndBearerTokenInComment() {
        let desc = AVPlayerEngine.failureDescription(
            statusCode: 403,
            comment: "Forbidden https://cdn.example.com/movie.mkv?sig=signature123&quality=1080p Bearer sk_test_secret",
            itemError: nil
        )
        #expect(desc.contains("HTTP 403: Forbidden"))
        #expect(desc.contains("sig=REDACTED"))
        #expect(desc.contains("quality=1080p"))
        #expect(desc.contains("Bearer REDACTED"))
        #expect(desc.contains("signature123") == false)
        #expect(desc.contains("sk_test_secret") == false)
    }

    @Test func failureDescriptionRedactsItemErrorDescription() {
        let error = NSError(
            domain: "AVFoundation",
            code: -11800,
            userInfo: [
                NSLocalizedDescriptionKey: "Failed for https://cdn.example.com/movie.mkv?access_token=secret-token"
            ]
        )
        let desc = AVPlayerEngine.failureDescription(statusCode: 0, comment: nil, itemError: error)
        #expect(desc.contains("access_token=REDACTED"))
        #expect(desc.contains("secret-token") == false)
    }

    @Test func failureDescriptionWithUnicodeComment() {
        let desc = AVPlayerEngine.failureDescription(statusCode: 0, comment: "ネットワークエラー", itemError: nil)
        #expect(desc == "ネットワークエラー")
    }

    @Test func failureDescriptionWithZeroStatusEmptyCommentAndError() {
        let error = NSError(domain: "AVFoundation", code: -11800, userInfo: [NSLocalizedDescriptionKey: "Operation stopped"])
        let desc = AVPlayerEngine.failureDescription(statusCode: 0, comment: "", itemError: error)
        #expect(desc == "Operation stopped")
    }

    @Test func failureDescriptionItemErrorWithoutLocalizedDescriptionKey() {
        let error = NSError(domain: "test", code: 4)
        let desc = AVPlayerEngine.failureDescription(statusCode: 0, comment: nil, itemError: error)
        #expect(!desc.isEmpty)
    }
}

// MARK: - prepare

@Suite("AVPlayerEngine - Prepare")
@MainActor
struct AVPlayerEnginePrepareTests {
    private let engine = AVPlayerEngine(resolveStream: { $0 })

    @Test func prepareThrowsInvalidStreamURLForMalformedURL() async {
        final class MalformedURL: NSURL, @unchecked Sendable {
            override var absoluteString: String { "bad://url with space" }
        }

        let url = MalformedURL(string: "https://example.com")! as URL
        let stream = StreamInfo(
            streamURL: url,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "movie.mp4",
            sizeBytes: 1_000,
            debridService: DebridServiceType.realDebrid.rawValue
        )

        await #expect(throws: PlayerEngineError.invalidStreamURL("bad://url with space")) {
            try await engine.prepare(stream: stream)
        }
    }

    @Test func prepareThrowsInvalidStreamURLForEmptyString() async {
        final class EmptyURL: NSURL, @unchecked Sendable {
            override var absoluteString: String { "" }
        }

        let url = EmptyURL(string: "https://example.com")! as URL
        let stream = StreamInfo(
            streamURL: url,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "movie.mp4",
            sizeBytes: 1_000,
            debridService: DebridServiceType.realDebrid.rawValue
        )

        await #expect(throws: PlayerEngineError.invalidStreamURL("")) {
            try await engine.prepare(stream: stream)
        }
    }

    @Test func prepareAcceptsValidURL() async throws {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            fileName: "movie.mp4"
        )

        let prepared = try await engine.prepare(stream: stream)
        #expect(prepared.engineKind == .avPlayer)
        #expect(prepared.streamURL == stream.streamURL)
        #expect(prepared.avPlayer != nil)
    }

    @Test func prepareRejectsResolvedMissingLocalFile() async {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("avplayer-resolved-missing-\(UUID().uuidString).mp4")
        let engine = AVPlayerEngine(resolveStream: { stream in
            Fixtures.stream(
                url: missingURL.absoluteString,
                quality: stream.quality,
                codec: stream.codec,
                audio: stream.audio,
                source: stream.source,
                hdr: stream.hdr,
                fileName: "missing.mp4"
            )
        })
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            fileName: "movie.mp4"
        )

        await #expect(throws: PlayerEngineError.invalidStreamURL(missingURL.absoluteString)) {
            try await engine.prepare(stream: stream)
        }
    }

    @Test func assetOptionsCarryDirectStreamRequestHeaders() throws {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            fileName: "movie.mp4"
        ).withRequestHeaders([
            "User-Agent": "Stremio",
            "Referer": "https://app.strem.io/",
            "Bad\nHeader": "ignored"
        ])

        let options = try #require(AVPlayerEngine.assetOptions(for: stream))
        let headers = try #require(options["AVURLAssetHTTPHeaderFieldsKey"] as? [String: String])

        #expect(headers["User-Agent"] == "Stremio")
        #expect(headers["Referer"] == "https://app.strem.io/")
        #expect(headers["Bad\nHeader"] == nil)
    }

    @Test func assetOptionsReturnNilWhenNoValidHeadersRemain() {
        let withoutHeaders = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            fileName: "movie.mp4"
        )
        #expect(AVPlayerEngine.assetOptions(for: withoutHeaders) == nil)

        let invalidOnly = withoutHeaders.withRequestHeaders([
            "Bad\nHeader": "ignored",
            "Also-Bad": "line\rbreak",
            "Blank": " \n "
        ])
        #expect(AVPlayerEngine.assetOptions(for: invalidOnly) == nil)
    }

    @Test func canHandleReturnsTrueForValidURL() {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            fileName: "movie.mp4"
        )

        #expect(engine.canHandle(stream: stream))
    }

    @Test func canHandleAllowsExistingDownloadedFileURLs() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("avplayer-existing-download-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let fileURL = tempDir.appendingPathComponent("movie.mp4")
        try Data([0]).write(to: fileURL)
        let stream = Fixtures.stream(
            url: fileURL.absoluteString,
            fileName: "movie.mp4"
        )

        #expect(PlayerStreamURLPolicy.isPlayable(stream))
        #expect(PlayerStreamURLPolicy.isLaunchable(stream))
        #expect(engine.canHandle(stream: stream))
    }

    @Test func canHandleRejectsMissingDownloadedFileURLs() {
        let stream = Fixtures.stream(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("missing-\(UUID().uuidString).mp4")
                .absoluteString,
            fileName: "missing.mp4"
        )

        #expect(PlayerStreamURLPolicy.isPlayable(stream))
        #expect(PlayerStreamURLPolicy.isLaunchable(stream) == false)
        #expect(engine.canHandle(stream: stream) == false)
    }

    @Test func launchabilityRequiresExistingLocalFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("player-launchability-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let existingFile = tempDir.appendingPathComponent("movie.mp4")
        try Data([0]).write(to: existingFile)

        let existingFileStream = Fixtures.stream(
            url: existingFile.absoluteString,
            fileName: "movie.mp4"
        )
        let missingFileStream = Fixtures.stream(
            url: tempDir.appendingPathComponent("missing.mp4").absoluteString,
            fileName: "missing.mp4"
        )
        let directoryStream = Fixtures.stream(
            url: tempDir.absoluteString,
            fileName: "directory"
        )
        let symlink = tempDir.appendingPathComponent("linked-movie.mp4")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: existingFile)
        let symlinkStream = Fixtures.stream(
            url: symlink.absoluteString,
            fileName: "linked-movie.mp4"
        )

        #expect(PlayerStreamURLPolicy.isPlayable(missingFileStream))
        #expect(PlayerStreamURLPolicy.isLaunchable(existingFileStream))
        #expect(PlayerStreamURLPolicy.isLaunchable(missingFileStream) == false)
        #expect(PlayerStreamURLPolicy.isLaunchable(directoryStream) == false)
        #expect(PlayerStreamURLPolicy.isLaunchable(symlinkStream) == false)
    }

    @Test func launchabilityAllowsPublicRemoteStreams() {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            fileName: "movie.mp4"
        )

        #expect(PlayerStreamURLPolicy.isLaunchable(stream))
    }

    @Test func canHandleRejectsPrivateRemoteURLs() {
        let stream = Fixtures.stream(
            url: "http://127.0.0.1:8080/movie.mp4",
            fileName: "movie.mp4"
        )

        #expect(PlayerStreamURLPolicy.isPlayable(stream) == false)
        #expect(engine.canHandle(stream: stream) == false)
    }

    @Test func canHandleReturnsFalseForInvalidURL() {
        final class EmptyURL: NSURL, @unchecked Sendable {
            override var absoluteString: String { "" }
        }

        let url = EmptyURL(string: "https://example.com")! as URL
        let stream = StreamInfo(
            streamURL: url,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "movie.mp4",
            sizeBytes: 1_000,
            debridService: DebridServiceType.realDebrid.rawValue
        )

        #expect(engine.canHandle(stream: stream) == false)
    }
}
