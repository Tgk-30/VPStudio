import Foundation
import Testing
@testable import VPStudio

@Suite("MediaCardView Poster Loading")
struct MediaCardViewPosterLoadingTests {
    @Test func noPosterURLDoesNotShowLoadingIndicator() {
        let preview = MediaPreview(
            id: "movie-1",
            type: .movie,
            title: "No Poster",
            year: 2024,
            posterPath: nil,
            imdbRating: nil,
            tmdbId: nil
        )

        #expect(MediaCardView.shouldShowPosterLoadingIndicator(for: preview) == false)
    }

    @Test func posterURLShowsLoadingIndicator() {
        let preview = MediaPreview(
            id: "movie-1",
            type: .movie,
            title: "Has Poster",
            year: 2024,
            posterPath: "/poster.jpg",
            imdbRating: nil,
            tmdbId: 1
        )

        #expect(MediaCardView.shouldShowPosterLoadingIndicator(for: preview) == true)
    }

    @Test func fullyAnimatedInteractionKeepsCustomHoverChromeOnVisionOS() {
        #expect(MediaCardView.InteractionMode.fullyAnimated.allowsCustomHoverChrome(onVisionOS: true) == true)
    }

    @Test func systemHoverOnlyDisablesCustomHoverChromeOnVisionOS() {
        #expect(MediaCardView.InteractionMode.systemHoverOnly.allowsCustomHoverChrome(onVisionOS: true) == false)
    }

    @Test func systemHoverOnlyStillAllowsLegacyHoverChromeOffVisionOS() {
        #expect(MediaCardView.InteractionMode.systemHoverOnly.allowsCustomHoverChrome(onVisionOS: false) == true)
    }

    @Test func cachedLastFrameFileURLsBypassAsyncImage() throws {
        // Resolve the repo root from this file's location — the test process's
        // working directory is not the repo root under `xcodebuild test`.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Views
            .deletingLastPathComponent() // VPStudioTests
            .deletingLastPathComponent() // repo root
        let sourceURL = repoRoot
            .appendingPathComponent("VPStudio/Views/Components/MediaCardView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("if lastFrameURL.isFileURL"))
        #expect(source.contains("localLastFrameArtwork(url: lastFrameURL)"))
        #expect(source.contains("remoteLastFrameArtwork(url: lastFrameURL)"))
        #expect(source.contains("NSImage(contentsOf: url)") || source.contains("UIImage(contentsOfFile: url.path)"))
        #expect(!source.contains("AsyncImage(url: lastFrameURL"))
        #expect(source.contains("AsyncImage(url: url"))
    }
}
