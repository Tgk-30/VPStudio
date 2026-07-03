import Foundation
import Testing
@testable import VPStudio

@Suite("Library View Deep Contracts")
struct LibraryViewDeepContractTests {
    @Test
    func emptyStateAndLayoutPoliciesStayStable() {
        #expect(LibraryLayoutPolicy.rootPinsContentToTop)
        #expect(LibraryLayoutPolicy.emptyStatePinsContentToTop)
        #expect(LibraryLayoutPolicy.emptyStateTopPadding == 20)
        #expect(LibraryLayoutPolicy.topTabMaxWidth == 720)
        #expect(LibraryGridPolicy.topContentPadding == 8)
        #expect(LibraryGridPolicy.bottomContentPadding == 132)

        #expect(
            LibraryLayoutPolicy.showsEmptyState(
                for: .watchlist,
                entryCount: 0,
                historyCount: 7
            )
        )
        #expect(
            LibraryLayoutPolicy.showsEmptyState(
                for: .favorites,
                entryCount: 0,
                historyCount: 1
            )
        )
        #expect(
            LibraryLayoutPolicy.showsEmptyState(
                for: .history,
                entryCount: 0,
                historyCount: 0
            )
        )
        #expect(
            !LibraryLayoutPolicy.showsEmptyState(
                for: .history,
                entryCount: 5,
                historyCount: 1
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
    func gridColumnsRemainPredictableAtBreakpoints() {
        let oneColumnWidth = LibraryGridPolicy.cardMinWidth + (2 * LibraryGridPolicy.horizontalPadding)
        let twoColumnWidth = oneColumnWidth + LibraryGridPolicy.cardMinWidth + LibraryGridPolicy.gridSpacing

        #expect(LibraryGridPolicy.columns(containerWidth: 0) == 1)
        #expect(LibraryGridPolicy.columns(containerWidth: oneColumnWidth) == 1)
        #expect(LibraryGridPolicy.columns(containerWidth: twoColumnWidth) == 2)
    }

    @Test
    func libraryViewSourceKeepsPrimaryBranchOrderAndRenderingModes() throws {
        let source = try Self.libraryViewSource()

        #expect(
            Self.containsOrderedSnippets(
                in: source,
                [
                    "if LibraryLoadingSurfacePolicy.shouldShowLoadingSurface(isLoadingSelection: isLoadingSelection) {",
                    "} else if isEmptyStateVisible {",
                    "ScrollView {",
                    "if selectedList == .history {",
                    "ForEach(displayedHistoryMediaIDs, id: \\.self)",
                    "} else {",
                    "ForEach(entries, id: \\.id)",
                ]
            )
        )
        #expect(source.contains("LibraryEmptyStateView("))
        #expect(source.contains("listType: emptyStateCTAListType"))
        #expect(source.contains("if selectedList.supportsFolders {"))
        #expect(source.contains("folderControls"))
    }

    @Test
    func libraryViewSourceKeepsSortMenuPolicyStable() throws {
        let source = try Self.libraryViewSource()

        #expect(
            Self.containsOrderedSnippets(
                in: source,
                [
                    "private var sortMenu: some View {",
                    "Menu {",
                    "Picker(\"Sort By\", selection: $sortOption) {",
                    "ForEach(LibrarySortOption.allCases, id: \\.self)",
                    "Label(option.displayName, systemImage: option.symbolName)",
                    "actionCapsuleLabel(",
                    "title: \"Sort\"",
                    "systemImage: \"arrow.up.arrow.down\"",
                    "tint: .teal",
                ]
            )
        )
        #expect(source.contains("LibrarySortOption.allCases"))
        #expect(source.contains("Sort By"))
    }

    @Test
    func libraryViewSourceKeepsCTANavigationMappedToLibraryTabs() throws {
        let source = try Self.libraryViewSource()

        #expect(source.contains("private func handleCTAAction(_ action: LibraryEmptyStateCTAPolicy.CTAAction)"))
        #expect(source.contains("appState.selectedTab = .discover"))
        #expect(source.contains("appState.selectedTab = .settings"))
        #expect(source.contains("case .watchlist: return .watchlist"))
        #expect(source.contains("case .favorites: return .favorites"))
        #expect(source.contains("case .history: return .history"))
    }

    @Test
    func libraryViewSourceKeepsLayoutStabilityContractsVisible() throws {
        let source = try Self.libraryViewSource()

        #expect(source.contains("alignment: LibraryLayoutPolicy.rootPinsContentToTop ? .top : .center"))
        #expect(source.contains("alignment: LibraryLayoutPolicy.emptyStatePinsContentToTop ? .top : .center"))
        #expect(source.contains(".padding(.top, LibraryLayoutPolicy.emptyStateTopPadding)"))
        #expect(source.contains(".frame(maxWidth: LibraryLayoutPolicy.topTabMaxWidth, alignment: .leading)"))
        #expect(source.contains(".adaptive(minimum: LibraryGridPolicy.cardMinWidth)"))
        #expect(source.contains("spacing: LibraryGridPolicy.gridSpacing"))
        #expect(source.contains(".padding(.horizontal, LibraryGridPolicy.horizontalPadding)"))
        #expect(source.contains(".padding(.top, LibraryGridPolicy.topContentPadding)"))
        #expect(source.contains(".padding(.bottom, LibraryGridPolicy.bottomContentPadding)"))
    }

    @Test
    func libraryCSVImportSheetSourceKeepsErrorAndSuccessFlowWired() throws {
        let source = try Self.libraryCSVImportSheetSource()

        #expect(
            Self.containsOrderedSnippets(
                in: source,
                [
                    "csvImportError = nil",
                    "csvImportNotice = nil",
                    "importSummary = nil",
                    "multiImportSummaries = []",
                    "csvImportInFlight = true",
                    "if LibraryCSVImportSheetPolicy.requiresManualSubfolderName(",
                    "let summary = try await importSingleCSV(",
                    "importSummary = summary",
                    "if !Self.hasLibraryChanges(in: summary) {",
                    "csvImportNotice = Self.noLibraryChangesNotice(anyRatingsImported: summary.ratingsImported > 0)",
                    "onImportComplete(summary)",
                    "csvImportError = (csvImportError ?? \"\") + \"\\(url.lastPathComponent): \\(error.localizedDescription)\\n\"",
                    "multiImportSummaries = summaries",
                    "importSummary = nil",
                    "if !summaries.isEmpty && !anyLibraryChange {",
                    "csvImportNotice = Self.noLibraryChangesNotice(anyRatingsImported: anyRatingChange)",
                    "onImportComplete(aggregate)",
                    "csvImportError = error.localizedDescription",
                ]
            )
        )
        #expect(source.contains("csvImportError = \"Enter a subfolder name, or enable auto subfolder by filename.\""))
        #expect(source.contains("csvImportError = nil"))
        #expect(source.contains("csvImportNotice = nil"))
    }

    @Test
    func libraryCSVImportSheetCoalescesMultiFileNotifications() throws {
        let source = try Self.libraryCSVImportSheetSource()

        #expect(source.contains("postNotifications: Bool = true"))
        #expect(source.contains("postNotifications: false"))
        #expect(source.contains("if postNotifications && Self.hasLibraryChanges(in: summary)"))
        #expect(source.contains("if postNotifications && summary.ratingsImported > 0"))
        #expect(
            Self.containsOrderedSnippets(
                in: source,
                [
                    "for url in urls {",
                    "let summary = try await importSingleCSV(",
                    "postNotifications: false",
                    "summaries.append(summary)",
                    "if anyLibraryChange {",
                    "NotificationCenter.default.post(name: .libraryDidChange, object: nil)",
                    "if anyRatingChange {",
                    "NotificationCenter.default.post(name: .tasteProfileDidChange, object: nil)",
                ]
            )
        )
    }

    private static func libraryViewSource() throws -> String {
        try sourceText(
            relativePath: "VPStudio/Views/Windows/Library/LibraryView.swift"
        )
    }

    private static func libraryCSVImportSheetSource() throws -> String {
        try sourceText(
            relativePath: "VPStudio/Views/Windows/Library/LibraryCSVImportSheet.swift"
        )
    }

    private static func sourceText(relativePath: String) throws -> String {
        let testURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let sourceURL = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private static func containsOrderedSnippets(in source: String, _ snippets: [String]) -> Bool {
        var searchStart = source.startIndex

        for snippet in snippets {
            guard let range = source.range(of: snippet, range: searchStart..<source.endIndex) else {
                Issue.record("Missing source snippet: \(snippet)")
                return false
            }
            searchStart = range.upperBound
        }

        return true
    }
}
