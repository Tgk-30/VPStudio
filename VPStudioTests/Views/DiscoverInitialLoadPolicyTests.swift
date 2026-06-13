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
    func discoverTaskMarksInitialLoadAfterReloadCompletes() throws {
        let source = try Self.discoverViewSource()
        guard let taskRange = source.range(of: ".task {\n            guard DiscoverInitialLoadPolicy.shouldStart"),
              let reloadRange = source.range(of: "await reloadDiscoverForLatestTMDBKey()", range: taskRange.lowerBound..<source.endIndex),
              let cancellationRange = source.range(of: "guard DiscoverInitialLoadPolicy.shouldMarkCompleted(isCancelled: Task.isCancelled) else { return }", range: reloadRange.upperBound..<source.endIndex),
              let markRange = source.range(of: "viewModel.hasPerformedInitialLoad = true", range: cancellationRange.upperBound..<source.endIndex) else {
            Issue.record("Discover initial load task no longer matches the cancellation-safe contract")
            return
        }

        #expect(taskRange.lowerBound < reloadRange.lowerBound)
        #expect(reloadRange.lowerBound < cancellationRange.lowerBound)
        #expect(cancellationRange.lowerBound < markRange.lowerBound)
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
            for: .tmdbSetupRequired(feature: "Discover")
        )

        #expect(presentation.isSetupError)
        #expect(presentation.artworkName == "genre-art-new")
        #expect(presentation.tagText == "Setup needed")
        #expect(presentation.tagSymbol == "sparkles")
        #expect(presentation.headline == "Finish setup to unlock Discover")
        #expect(presentation.message == DiscoverErrorPresentationPolicy.setupInlineMessage)
        #expect(presentation.retryTitle == "Retry Later")
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
