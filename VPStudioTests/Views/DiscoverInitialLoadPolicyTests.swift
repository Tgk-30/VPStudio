import Foundation
import Testing
@testable import VPStudio

@Suite("Discover Initial Load Policy")
struct DiscoverInitialLoadPolicyTests {
    @Test
    func startsOnlyWhenInitialLoadHasNotCompleted() {
        #expect(DiscoverInitialLoadPolicy.shouldStart(hasPerformedInitialLoad: false))
        #expect(!DiscoverInitialLoadPolicy.shouldStart(hasPerformedInitialLoad: true))
    }

    @Test
    func marksCompletedOnlyWhenTaskWasNotCancelled() {
        #expect(DiscoverInitialLoadPolicy.shouldMarkCompleted(isCancelled: false))
        #expect(!DiscoverInitialLoadPolicy.shouldMarkCompleted(isCancelled: true))
    }

    @Test
    func discoverTaskLatchesInitialLoadBeforeReload() throws {
        let source = try Self.discoverViewSource()
        guard let taskRange = source.range(of: ".task {\n            guard DiscoverInitialLoadPolicy.shouldStart"),
              let markRange = source.range(of: "viewModel.hasPerformedInitialLoad = true", range: taskRange.upperBound..<source.endIndex),
              let reloadRange = source.range(of: "await reloadDiscoverForLatestMetadataKey()", range: taskRange.upperBound..<source.endIndex) else {
            Issue.record("Discover initial load task no longer matches the cancellation-safe contract")
            return
        }

        // The latch must be set BEFORE the await: leaving the Discover tab cancels this `.task`,
        // and latching first means a mid-flight cancellation cannot undo it and re-fire the load.
        #expect(taskRange.lowerBound < markRange.lowerBound)
        #expect(markRange.lowerBound < reloadRange.lowerBound)
    }

    @Test
    func setupSurfaceKeepsActionsFocusedAndPreviewClearlyLocked() throws {
        let source = try Self.discoverViewSource()

        #expect(source.contains("if !presentation.isSetupError"))
        #expect(!source.contains(#"text: "Go to Library""#))
        #expect(!source.contains(#"text: "Open Downloads""#))
        #expect(source.contains(#"text: row == 0 ? "Preview locked" : "Popular preview""#))
        #expect(!source.contains(#"text: row == 0 ? "Trending preview" : "Popular preview""#))
    }

    private static func discoverViewSource() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot.appendingPathComponent(
            "VPStudio/Views/Windows/Discover/DiscoverView.swift"
        )
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

@Suite("Discover Error Presentation Policy")
struct DiscoverErrorPresentationPolicyTests {
    @Test
    func setupRequiredErrorUsesSetupCopyAndActions() {
        let presentation = DiscoverErrorPresentationPolicy.presentation(
            for: .metadataSetupRequired(feature: "Discover")
        )

        #expect(presentation.isSetupError)
        #expect(presentation.artworkName == "genre-art-new")
        #expect(presentation.tagText == "Setup needed")
        #expect(presentation.tagSymbol == "sparkles")
        #expect(presentation.headline == "Finish setup to unlock Discover")
        #expect(presentation.message == DiscoverErrorPresentationPolicy.setupInlineMessage)
        #expect(presentation.retryTitle == "Retry Later")
        #expect(DiscoverErrorActionPolicy.retryBehavior(isSetupError: presentation.isSetupError) == .dismissOnly)
    }

    @Test
    func regularErrorUsesDescriptionAndRecoverySuggestion() {
        let presentation = DiscoverErrorPresentationPolicy.presentation(
            for: .network(.offline)
        )

        #expect(presentation.isSetupError == false)
        #expect(presentation.artworkName == "genre-art-deep")
        #expect(presentation.tagText == "Discover needs attention")
        #expect(presentation.tagSymbol == "arrow.clockwise")
        #expect(presentation.headline == "No internet connection.")
        #expect(presentation.message == "Check your connection and retry.")
        #expect(presentation.retryTitle == "Retry")
        #expect(DiscoverErrorActionPolicy.retryBehavior(isSetupError: presentation.isSetupError) == .refreshAndDismiss)
    }

    @Test
    func unknownErrorUsesFallbackRecoveryMessage() {
        let presentation = DiscoverErrorPresentationPolicy.presentation(
            for: .unknown("Catalog unavailable")
        )

        #expect(presentation.isSetupError == false)
        #expect(presentation.headline == "Catalog unavailable")
        #expect(presentation.message == "Try again. If the issue continues, review app configuration.")
        #expect(presentation.retryTitle == "Retry")
    }
}
