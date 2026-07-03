import Foundation
import Testing
@testable import VPStudio

@Suite("PlaybackStreamURLResolver")
struct PlaybackStreamURLResolverTests {
    @Test func redirectPolicyRejectsPrivateDestinations() throws {
        let publicRequest = URLRequest(url: try #require(URL(string: "https://cdn.example.com/movie.mp4")))
        let privateRequest = URLRequest(url: try #require(URL(string: "http://127.0.0.1:8080/movie.mp4")))

        #expect(PlayerStreamURLPolicy.allowsRedirect(to: publicRequest))
        #expect(PlayerStreamURLPolicy.allowsRedirect(to: privateRequest) == false)
    }

    @Test func resolveSendsTinyRangeProbeAndPreservesAllowedHeaders() async throws {
        var stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            fileName: "movie.mp4"
        ).withRequestHeaders([
            "Accept": "video/*",
            "Accept-Language": "en-US",
            "User-Agent": "Stremio",
            "Referer": "https://app.strem.io/",
        ])
        stream.requestHeaders = stream.requestHeaders?.merging([
            "Authorization": "Bearer secret",
            "Cookie": "session=secret",
            "Host": "evil.example",
            "Origin": "http://127.0.0.1/private",
            "Range": "bytes=0-999999",
            "X-Api-Key": "secret",
        ], uniquingKeysWith: { _, new in new })

        let configuration = makeHarnessConfiguration { request in
            #expect(request.value(forHTTPHeaderField: "Range") == "bytes=0-0")
            #expect(request.value(forHTTPHeaderField: "Accept") == "video/*")
            #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en-US")
            #expect(request.value(forHTTPHeaderField: "User-Agent") == "Stremio")
            #expect(request.value(forHTTPHeaderField: "Referer") == "https://app.strem.io/")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
            #expect(request.value(forHTTPHeaderField: "Host") == nil)
            #expect(request.value(forHTTPHeaderField: "Origin") == nil)
            #expect(request.value(forHTTPHeaderField: "X-Api-Key") == nil)
            let response = try httpResponse(url: try #require(request.url), statusCode: 206)
            return (response, Data("x".utf8))
        }

        let resolved = try await PlaybackStreamURLResolver.resolve(stream, configuration: configuration)

        #expect(resolved.streamURL == stream.streamURL)
        #expect(resolved.requestHeaders == stream.requestHeaders)
    }

    @Test func resolveRejectsPrivateFinalResponseURL() async throws {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            fileName: "movie.mp4"
        )
        let blockedURL = try #require(URL(string: "http://127.0.0.1:8080/movie.mp4"))
        let configuration = makeHarnessConfiguration { _ in
            let response = try httpResponse(url: blockedURL, statusCode: 200)
            return (response, Data())
        }

        await #expect(throws: PlaybackStreamURLResolverError.blockedFinalURL(blockedURL)) {
            try await PlaybackStreamURLResolver.resolve(stream, configuration: configuration)
        }
    }

    @Test func blockedURLDescriptionsRedactSensitiveValues() throws {
        let blockedURL = try #require(URL(string: "http://user:pass@127.0.0.1:8080/movie.mp4?access_token=secret-token&quality=1080p"))
        let redirectDescription = PlaybackStreamURLResolverError.blockedRedirect(blockedURL).errorDescription ?? ""
        let finalDescription = PlaybackStreamURLResolverError.blockedFinalURL(blockedURL).errorDescription ?? ""

        for description in [redirectDescription, finalDescription] {
            #expect(description.contains("127.0.0.1"))
            #expect(description.contains("quality=1080p"))
            #expect(description.contains("access_token=REDACTED"))
            #expect(description.contains("user:pass") == false)
            #expect(description.contains("secret-token") == false)
        }
    }

    @Test func resolveFallsBackToOriginalPublicStreamWhenProbeStatusFails() async throws {
        let stream = Fixtures.stream(
            url: "https://cdn.example.com/movie.mp4",
            fileName: "movie.mp4"
        )
        let configuration = makeHarnessConfiguration { request in
            let response = try httpResponse(url: try #require(request.url), statusCode: 403)
            return (response, Data())
        }

        let resolved = try await PlaybackStreamURLResolver.resolve(stream, configuration: configuration)

        #expect(resolved.streamURL == stream.streamURL)
        #expect(resolved.requestHeaders == stream.requestHeaders)
    }

    private func makeHarnessConfiguration(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSessionConfiguration {
        let handlerID = URLProtocolHarness.register(handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolHarness.self]
        configuration.httpAdditionalHeaders = [URLProtocolHarness.handlerHeader: handlerID]
        return configuration
    }

    private func httpResponse(url: URL, statusCode: Int) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ))
    }
}
