import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit

@MainActor
@Suite("Library CSV Sheet macOS Render Coverage", .serialized)
struct LibraryCSVSheetMacRenderCoverageTests {
    @Test
    func importSheetHostsSeededResultWarningAndDiagnosticsStatesOnMacOS() throws {
        let appState = AppState(testHooks: .init())
        let createNew = LibraryCSVImportSheetPolicy.createNewFolderOption
        let singleSummary = makeImportSummary(
            rowsRead: 12,
            rowsImported: 10,
            rowsSkipped: 2,
            watchlist: 6,
            favorites: 2,
            history: 0,
            ratings: 8,
            targetFolderName: "Sci-Fi"
        )
        let historySummary = makeImportSummary(
            rowsRead: 6,
            rowsImported: 5,
            rowsSkipped: 1,
            watchlist: 0,
            favorites: 0,
            history: 5,
            ratings: 0,
            targetFolderName: nil
        )

        let variants: [(String, LibraryCSVImportSheet)] = [
            ("Create folder field", LibraryCSVImportSheet(
                initialFolderName: "Movie Night",
                initialAutoSubfolderPerFile: false,
                initialExistingFolderOptions: ["Queued", "Sci-Fi"],
                initialSelectedExistingFolderName: createNew,
                disablesAutomaticTasks: true,
                onImportComplete: { _ in }
            )),
            ("Existing folder summary", LibraryCSVImportSheet(
                initialDestination: .watchlist,
                initialAutoSubfolderPerFile: false,
                initialExistingFolderOptions: ["Sci-Fi", "Watch Later"],
                initialSelectedExistingFolderName: "Sci-Fi",
                initialImportSummary: singleSummary,
                disablesAutomaticTasks: true,
                onImportComplete: { _ in }
            )),
            ("History warning", LibraryCSVImportSheet(
                initialDestination: .history,
                initialImportToFolder: true,
                initialImportError: "No CSV files found in the selected folder.",
                initialImportNotice: "Import finished: ratings were imported, but no library rows changed.",
                disablesAutomaticTasks: true,
                onImportComplete: { _ in }
            )),
            ("Multi result diagnostics", LibraryCSVImportSheet(
                initialImportInFlight: true,
                initialMultiImportSummaries: [singleSummary, historySummary],
                initialImportDiagnostics: [
                    "file=watchlist.csv rows=10/12 skipped=2 W=6 F=2 H=0 R=8",
                    "file=history.csv rows=5/6 skipped=1 W=0 F=0 H=5 R=0",
                ],
                disablesAutomaticTasks: true,
                onImportComplete: { _ in }
            )),
        ]

        for (name, view) in variants {
            let size = host(
                view
                    .environment(appState)
                    .frame(width: 760, height: 880),
                width: 760,
                height: 880
            )
            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }
    }

    @Test
    func exportSheetHostsSeededProgressErrorAndResultStatesOnMacOS() throws {
        let appState = AppState(testHooks: .init())
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vpstudio-export-sheet-macos-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: exportDirectory) }

        try "const,Title\n".write(
            to: exportDirectory.appendingPathComponent("Watchlist.csv"),
            atomically: true,
            encoding: .utf8
        )
        try "const,Title\n".write(
            to: exportDirectory.appendingPathComponent("History.csv"),
            atomically: true,
            encoding: .utf8
        )

        let summary = LibraryCSVExportSummary(
            filesWritten: 2,
            totalItemsExported: 14,
            folderNames: ["Watchlist", "History", "Sci-Fi"]
        )
        let variants: [(String, LibraryCSVExportSheet)] = [
            ("Options", LibraryCSVExportSheet()),
            ("In flight error", LibraryCSVExportSheet(
                initialIsExporting: true,
                initialErrorMessage: "Export failed because the destination is unavailable."
            )),
            ("Result", LibraryCSVExportSheet(
                initialExportSummary: summary,
                initialExportDirectoryURL: exportDirectory
            )),
        ]

        for (name, view) in variants {
            let size = host(
                view
                    .environment(appState)
                    .frame(width: 760, height: 520),
                width: 760,
                height: 520
            )
            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }
    }

    private func host<Content: View>(
        _ view: Content,
        width: CGFloat,
        height: CGFloat
    ) -> CGSize {
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        window.orderOut(nil)
        Self.retainedWindows.append(window)
        if Self.retainedWindows.count > 8 {
            Self.retainedWindows.removeFirst(Self.retainedWindows.count - 8)
        }
        return size
    }

    private func makeImportSummary(
        rowsRead: Int,
        rowsImported: Int,
        rowsSkipped: Int,
        watchlist: Int,
        favorites: Int,
        history: Int,
        ratings: Int,
        targetFolderName: String?
    ) -> LibraryCSVImportSummary {
        LibraryCSVImportSummary(
            detectedFormat: .generic,
            rowsRead: rowsRead,
            rowsImported: rowsImported,
            rowsSkipped: rowsSkipped,
            mediaItemsCreated: max(watchlist + favorites + history, 0),
            mediaItemsUpdated: 1,
            watchlistImported: watchlist,
            favoritesImported: favorites,
            historyImported: history,
            ratingsImported: ratings,
            targetFolderID: targetFolderName.map { "folder-\($0.lowercased().replacingOccurrences(of: " ", with: "-"))" },
            targetFolderName: targetFolderName
        )
    }

    private static var retainedWindows: [NSWindow] = []
}
#endif
