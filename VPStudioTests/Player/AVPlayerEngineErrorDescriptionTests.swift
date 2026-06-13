import Foundation
import Testing
import AVFoundation
@testable import VPStudio

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
        #expect(desc == "Error: token=abc123&expired")
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
    private let engine = AVPlayerEngine()

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
