import Foundation
import Testing
@testable import VPStudio

@Suite("Library Empty And Loading Policies")
struct LibraryEmptyAndLoadingPolicyTests {
    @Test
    func emptyLoadedWatchlistShowsEmptyState() {
        #expect(
            LibraryLayoutPolicy.showsEmptyState(
                for: .watchlist,
                entryCount: 0,
                historyCount: 3
            )
        )

        #expect(
            !LibraryLayoutPolicy.showsEmptyState(
                for: .watchlist,
                entryCount: 1,
                historyCount: 0
            )
        )
    }

    @Test
    func loadingSurfaceStopsMaskingContentOnceSelectionLoadCompletes() {
        #expect(LibraryLoadingSurfacePolicy.shouldShowLoadingSurface(isLoadingSelection: true))
        #expect(!LibraryLoadingSurfacePolicy.shouldShowLoadingSurface(isLoadingSelection: false))
    }

    @Test
    func emptyStateLibraryCTAsRouteToDiscover() {
        let discoverLists: [LibraryEmptyStateCTAPolicy.ListType] = [
            .favorites,
            .watchlist,
            .history,
        ]

        for listType in discoverLists {
            #expect(
                LibraryEmptyStateCTAPolicy.ctaAction(for: listType) == .switchToDiscover,
                "\(listType) should route empty-state CTA to Discover"
            )
        }
    }
}

@Suite("Library Empty And Loading Contracts")
struct LibraryEmptyAndLoadingContractTests {
    @Test
    func libraryViewChecksEmptyStateImmediatelyAfterLoadingBranch() throws {
        let source = try Self.libraryViewSource()

        guard let loadingRange = source.range(of: "if LibraryLoadingSurfacePolicy.shouldShowLoadingSurface(isLoadingSelection: isLoadingSelection) {"),
              let emptyBranchRange = source.range(of: "} else if isEmptyStateVisible {", range: loadingRange.upperBound..<source.endIndex),
              let emptyViewRange = source.range(of: "LibraryEmptyStateView(", range: emptyBranchRange.upperBound..<source.endIndex) else {
            Issue.record("LibraryView empty/loading branch structure no longer matches the source contract")
            return
        }

        #expect(loadingRange.lowerBound < emptyBranchRange.lowerBound)
        #expect(emptyBranchRange.lowerBound < emptyViewRange.lowerBound)
    }

    @Test
    func libraryViewClearsSelectionLoadingStateInLoadSelectionDefer() throws {
        let source = try Self.libraryViewSource()

        #expect(source.contains("defer {"))
        #expect(source.contains("if selectionLoadToken == resolvedLoadToken {"))
        #expect(source.contains("isLoadingSelection = false"))
    }

    private static func libraryViewSource() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot.appendingPathComponent(
            "VPStudio/Views/Windows/Library/LibraryView.swift"
        )
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
