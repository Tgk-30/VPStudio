#if os(visionOS)
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("Library CSV Import Sheet runtime coverage", .serialized)
struct LibraryCSVImportSheetRuntimeTests {
    @Test
    func runtimeControlImportsMultipleCSVFilesIntoAutoSubfolders() async throws {
        let database = try DatabaseManager(inMemoryNamed: "csv-sheet-multi-\(UUID().uuidString)")
        try await database.migrate()
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let first = try writeCSV(
            """
            Const,Created,Title,Type,Year
            tt0111161,2024-01-01,The Shawshank Redemption,movie,1994
            """,
            name: "queue-one.csv",
            in: tempDir
        )
        let second = try writeCSV(
            """
            Const,Created,Title,Type,Year
            tt0944947,2024-01-02,Game of Thrones,tvSeries,2011
            """,
            name: "queue-two.csv",
            in: tempDir
        )

        let recorder = LibraryCSVImportRuntimeRecorder()
        let readiness = LibraryCSVImportRuntimeReadiness()
        let hosted = try hostInVisibleCSVRuntimeWindow(
            LibraryCSVImportSheet(
                initialDestination: .watchlist,
                initialImportRatings: false,
                initialImportToFolder: true,
                initialAutoSubfolderPerFile: true,
                disablesAutomaticTasks: true,
                enablesRuntimeImportControls: true,
                onRuntimeImportControlsReady: { readiness.isReady = true },
                onImportComplete: { summary in
                    Task { await recorder.record(summary) }
                }
            )
            .environment(AppState(database: database, testHooks: .init()))
            .frame(width: 620, height: 720)
        )
        defer { tearDownCSVRuntimeWindow(hosted.window) }
        try await waitForRuntimeImportControlsReady(readiness)

        NotificationCenter.default.post(
            name: .libraryCSVImportControlImportFiles,
            object: [first, second]
        )

        let summary = try await waitForImportSummary(from: recorder)
        #expect(summary.rowsImported == 2)
        #expect(summary.watchlistImported == 2)

        let folders = try await database.fetchAllLibraryFolders(listType: .watchlist)
        let manualFolderNames = Set(folders.filter { !$0.isSystem }.map(\.name))
        #expect(manualFolderNames.contains("queue-one"))
        #expect(manualFolderNames.contains("queue-two"))
    }

    @Test
    func runtimeControlRejectsMultiFileImportWhenManualFolderNameIsMissing() async throws {
        let database = try DatabaseManager(inMemoryNamed: "csv-sheet-validation-\(UUID().uuidString)")
        try await database.migrate()
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let first = try writeCSV(
            """
            Const,Created,Title,Type,Year
            tt0133093,2024-01-01,The Matrix,movie,1999
            """,
            name: "matrix.csv",
            in: tempDir
        )
        let second = try writeCSV(
            """
            Const,Created,Title,Type,Year
            tt0088763,2024-01-02,Back to the Future,movie,1985
            """,
            name: "future.csv",
            in: tempDir
        )

        let recorder = LibraryCSVImportRuntimeRecorder()
        let readiness = LibraryCSVImportRuntimeReadiness()
        let hosted = try hostInVisibleCSVRuntimeWindow(
            LibraryCSVImportSheet(
                initialDestination: .watchlist,
                initialImportRatings: false,
                initialFolderName: "",
                initialImportToFolder: true,
                initialAutoSubfolderPerFile: false,
                disablesAutomaticTasks: true,
                enablesRuntimeImportControls: true,
                onRuntimeImportControlsReady: { readiness.isReady = true },
                onImportComplete: { summary in
                    Task { await recorder.record(summary) }
                }
            )
            .environment(AppState(database: database, testHooks: .init()))
            .frame(width: 620, height: 720)
        )
        defer { tearDownCSVRuntimeWindow(hosted.window) }
        try await waitForRuntimeImportControlsReady(readiness)

        NotificationCenter.default.post(
            name: .libraryCSVImportControlImportFiles,
            object: [first, second]
        )
        try await assertNoCompletion(from: recorder, timeout: 1.2)

        #expect(await recorder.latest() == nil)
        #expect(try await database.fetchLibraryEntries(listType: .watchlist).isEmpty)
    }

    @Test
    func runtimeControlImportsCSVFilesFromFolderAndIgnoresOtherFiles() async throws {
        let database = try DatabaseManager(inMemoryNamed: "csv-sheet-folder-\(UUID().uuidString)")
        try await database.migrate()
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        _ = try writeCSV(
            """
            Const,Created,Title,Type,Year
            tt0109830,2024-01-01,Forrest Gump,movie,1994
            """,
            name: "favorites-one.csv",
            in: tempDir
        )
        _ = try writeCSV(
            """
            Const,Created,Title,Type,Year
            tt0110912,2024-01-02,Pulp Fiction,movie,1994
            """,
            name: "favorites-two.csv",
            in: tempDir
        )
        try "not,csv".write(
            to: tempDir.appendingPathComponent("notes.txt"),
            atomically: true,
            encoding: .utf8
        )

        let recorder = LibraryCSVImportRuntimeRecorder()
        let readiness = LibraryCSVImportRuntimeReadiness()
        let hosted = try hostInVisibleCSVRuntimeWindow(
            LibraryCSVImportSheet(
                initialDestination: .favorites,
                initialImportRatings: false,
                initialImportToFolder: true,
                initialAutoSubfolderPerFile: true,
                disablesAutomaticTasks: true,
                enablesRuntimeImportControls: true,
                onRuntimeImportControlsReady: { readiness.isReady = true },
                onImportComplete: { summary in
                    Task { await recorder.record(summary) }
                }
            )
            .environment(AppState(database: database, testHooks: .init()))
            .frame(width: 620, height: 720)
        )
        defer { tearDownCSVRuntimeWindow(hosted.window) }
        try await waitForRuntimeImportControlsReady(readiness)

        NotificationCenter.default.post(
            name: .libraryCSVImportControlImportFolder,
            object: tempDir
        )

        let summary = try await waitForImportSummary(from: recorder)
        #expect(summary.rowsImported == 2)
        #expect(summary.favoritesImported == 2)
        #expect(try await database.fetchLibraryEntries(listType: .favorites).count == 2)
    }

    @Test
    func runtimeControlReportsNoCompletionWhenFolderContainsNoCSVFiles() async throws {
        let database = try DatabaseManager(inMemoryNamed: "csv-sheet-empty-folder-\(UUID().uuidString)")
        try await database.migrate()
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try "nothing to import".write(
            to: tempDir.appendingPathComponent("notes.txt"),
            atomically: true,
            encoding: .utf8
        )

        let recorder = LibraryCSVImportRuntimeRecorder()
        let readiness = LibraryCSVImportRuntimeReadiness()
        let hosted = try hostInVisibleCSVRuntimeWindow(
            LibraryCSVImportSheet(
                initialDestination: .favorites,
                initialImportRatings: false,
                disablesAutomaticTasks: true,
                enablesRuntimeImportControls: true,
                onRuntimeImportControlsReady: { readiness.isReady = true },
                onImportComplete: { summary in
                    Task { await recorder.record(summary) }
                }
            )
            .environment(AppState(database: database, testHooks: .init()))
            .frame(width: 620, height: 720)
        )
        defer { tearDownCSVRuntimeWindow(hosted.window) }
        try await waitForRuntimeImportControlsReady(readiness)

        NotificationCenter.default.post(
            name: .libraryCSVImportControlImportFolder,
            object: tempDir
        )
        try await assertNoCompletion(from: recorder, timeout: 1.2)

        #expect(await recorder.latest() == nil)
        #expect(try await database.fetchLibraryEntries(listType: .favorites).isEmpty)
    }
}

@MainActor
private final class LibraryCSVImportRuntimeReadiness {
    var isReady = false
}

private actor LibraryCSVImportRuntimeRecorder {
    private var summaries: [LibraryCSVImportSummary] = []

    func record(_ summary: LibraryCSVImportSummary) {
        summaries.append(summary)
    }

    func latest() -> LibraryCSVImportSummary? {
        summaries.last
    }
}

private enum LibraryCSVImportRuntimeTestError: Error {
    case timedOut
    case unexpectedCompletion
}

@MainActor
private func waitForRuntimeImportControlsReady(
    _ readiness: LibraryCSVImportRuntimeReadiness,
    timeout: TimeInterval = 2
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if readiness.isReady {
            return
        }
        try await Task.sleep(for: .milliseconds(20))
    }
    throw LibraryCSVImportRuntimeTestError.timedOut
}

@MainActor
private func waitForImportSummary(
    from recorder: LibraryCSVImportRuntimeRecorder,
    timeout: TimeInterval = 3
) async throws -> LibraryCSVImportSummary {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let summary = await recorder.latest() {
            return summary
        }
        try await Task.sleep(for: .milliseconds(25))
    }
    throw LibraryCSVImportRuntimeTestError.timedOut
}

private func assertNoCompletion(
    from recorder: LibraryCSVImportRuntimeRecorder,
    timeout: TimeInterval
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await recorder.latest() != nil {
            throw LibraryCSVImportRuntimeTestError.unexpectedCompletion
        }
        try await Task.sleep(for: .milliseconds(25))
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("vpstudio-csv-sheet-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeCSV(_ content: String, name: String, in directory: URL) throws -> URL {
    let url = directory.appendingPathComponent(name)
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
}

@MainActor
private func hostInVisibleCSVRuntimeWindow<Content: View>(
    _ rootView: Content
) throws -> (host: UIHostingController<AnyView>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )

    let host = UIHostingController(rootView: AnyView(rootView))
    host.view.backgroundColor = .clear
    let window = UIWindow(windowScene: scene)
    window.rootViewController = host
    window.frame = CGRect(x: 0, y: 0, width: 700, height: 760)
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return (host, window)
}

@MainActor
private func tearDownCSVRuntimeWindow(_ window: UIWindow) {
    window.rootViewController?.dismiss(animated: false)
    RunLoop.main.run(until: Date().addingTimeInterval(0.20))
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
    window.isHidden = true
    window.rootViewController = nil
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
}
#endif
