import Foundation
import Testing
@testable import VPStudio

@Suite("Library Folder Move Source Contracts")
struct LibraryFolderMoveSourceContractTests {
    @Test
    func libraryViewSourceKeepsFolderMoveContextMenuGuardedAndDeterministic() throws {
        let source = try Self.libraryViewSource()

        #expect(
            Self.containsOrderedSnippets(
                in: source,
                [
                    ".contextMenu {",
                    "if selectedList.supportsFolders {",
                    "ForEach(allFolderOptions, id: \\.id) { folder in",
                    "if folder.id != entry.folderId {",
                    "\"Move to \\(LibraryFolderLabelPolicy.fullPath(for: folder, in: allFolderOptions))\"",
                    "move(entry: entry, to: folder)",
                    "Divider()",
                    "Button(role: .destructive) {",
                    "remove(entry: entry)",
                ]
            )
        )
    }

    private static func libraryViewSource() throws -> String {
        try sourceText(
            relativePath: "VPStudio/Views/Windows/Library/LibraryView.swift"
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
