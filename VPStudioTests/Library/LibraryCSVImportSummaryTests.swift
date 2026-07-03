import Foundation
import Testing
@testable import VPStudio

@Suite("Library CSV Import Summary Aggregation")
struct LibraryCSVImportSummaryAggregationTests {

    @Test
    func aggregatedSummaryWithEmptyArrayReturnsZeroedSummary() {
        let result = LibraryCSVImportSheet.aggregatedSummary([])

        #expect(result.detectedFormat == .generic)
        #expect(result.rowsRead == 0)
        #expect(result.rowsImported == 0)
        #expect(result.rowsSkipped == 0)
        #expect(result.mediaItemsCreated == 0)
        #expect(result.mediaItemsUpdated == 0)
        #expect(result.watchlistImported == 0)
        #expect(result.favoritesImported == 0)
        #expect(result.historyImported == 0)
        #expect(result.ratingsImported == 0)
        #expect(result.targetFolderID == nil)
        #expect(result.targetFolderName == nil)
    }

    @Test
    func aggregatedSummaryWithSingleSummaryReturnsSameValues() {
        let summary = makeSummary(
            format: .imdbWatchlist,
            rowsRead: 10,
            rowsImported: 8,
            rowsSkipped: 2,
            created: 5,
            updated: 3,
            watchlist: 8,
            favorites: 0,
            history: 0,
            ratings: 1
        )

        let result = LibraryCSVImportSheet.aggregatedSummary([summary])

        #expect(result.rowsRead == 10)
        #expect(result.rowsImported == 8)
        #expect(result.rowsSkipped == 2)
        #expect(result.mediaItemsCreated == 5)
        #expect(result.mediaItemsUpdated == 3)
        #expect(result.watchlistImported == 8)
        #expect(result.favoritesImported == 0)
        #expect(result.historyImported == 0)
        #expect(result.ratingsImported == 1)
    }

    @Test
    func aggregatedSummarySumsCountersAcrossManySummaries() {
        let summaries = (1...5).map { i in
            makeSummary(
                rowsRead: i,
                rowsImported: i,
                rowsSkipped: i,
                created: i,
                updated: i,
                watchlist: i,
                favorites: i,
                history: i,
                ratings: i
            )
        }

        let result = LibraryCSVImportSheet.aggregatedSummary(summaries)

        #expect(result.rowsRead == 15)
        #expect(result.rowsImported == 15)
        #expect(result.rowsSkipped == 15)
        #expect(result.mediaItemsCreated == 15)
        #expect(result.mediaItemsUpdated == 15)
        #expect(result.watchlistImported == 15)
        #expect(result.favoritesImported == 15)
        #expect(result.historyImported == 15)
        #expect(result.ratingsImported == 15)
    }

    @Test
    func aggregatedSummarySetsDetectedFormatToGenericRegardlessOfInputs() {
        let s1 = makeSummary(format: .imdbWatchlist)
        let s2 = makeSummary(format: .imdbRatings)
        let result = LibraryCSVImportSheet.aggregatedSummary([s1, s2])
        #expect(result.detectedFormat == .generic)
    }

    @Test
    func aggregatedSummaryStripsFolderMetadata() {
        var s1 = makeSummary()
        s1.targetFolderID = "folder-1"
        s1.targetFolderName = "Folder One"

        var s2 = makeSummary()
        s2.targetFolderID = "folder-2"
        s2.targetFolderName = "Folder Two"

        let result = LibraryCSVImportSheet.aggregatedSummary([s1, s2])
        #expect(result.targetFolderID == nil)
        #expect(result.targetFolderName == nil)
    }
}

@Suite("Library CSV Import Has-Library-Changes Detection")
struct LibraryCSVImportHasLibraryChangesTests {

    @Test
    func hasLibraryChangesTrueWhenWatchlistImported() {
        let summary = makeSummary(watchlist: 1)
        #expect(LibraryCSVImportSheet.hasLibraryChanges(in: summary))
    }

    @Test
    func hasLibraryChangesTrueWhenFavoritesImported() {
        let summary = makeSummary(favorites: 1)
        #expect(LibraryCSVImportSheet.hasLibraryChanges(in: summary))
    }

    @Test
    func hasLibraryChangesTrueWhenHistoryImported() {
        let summary = makeSummary(history: 1)
        #expect(LibraryCSVImportSheet.hasLibraryChanges(in: summary))
    }

    @Test
    func hasLibraryChangesTrueWhenMultipleLibraryCountersPresent() {
        let summary = makeSummary(watchlist: 2, favorites: 3, history: 1)
        #expect(LibraryCSVImportSheet.hasLibraryChanges(in: summary))
    }

    @Test
    func hasLibraryChangesFalseWhenOnlyRatingsImported() {
        let summary = makeSummary(ratings: 5)
        #expect(LibraryCSVImportSheet.hasLibraryChanges(in: summary) == false)
    }

    @Test
    func hasLibraryChangesFalseWhenOnlyMediaItemsCreatedOrUpdated() {
        let summary = makeSummary(created: 3, updated: 2)
        #expect(LibraryCSVImportSheet.hasLibraryChanges(in: summary) == false)
    }

    @Test
    func hasLibraryChangesFalseForCompletelyEmptySummary() {
        let summary = makeSummary()
        #expect(LibraryCSVImportSheet.hasLibraryChanges(in: summary) == false)
    }

    @Test
    func hasLibraryChangesFalseWhenRowsReadButNothingImported() {
        let summary = makeSummary(rowsRead: 10, rowsSkipped: 10)
        #expect(LibraryCSVImportSheet.hasLibraryChanges(in: summary) == false)
    }
}

@Suite("Library CSV Import Notice Messages")
struct LibraryCSVImportNoticeTests {

    @Test
    func noLibraryChangesNoticeReturnsRatingsMessageWhenTrue() {
        let notice = LibraryCSVImportSheet.noLibraryChangesNotice(anyRatingsImported: true)
        #expect(notice == "Import finished, but no new library items were added. Ratings were imported.")
    }

    @Test
    func noLibraryChangesNoticeReturnsExistingMessageWhenFalse() {
        let notice = LibraryCSVImportSheet.noLibraryChangesNotice(anyRatingsImported: false)
        #expect(notice == "Import finished, but no new library items were added. The imported titles may already exist.")
    }
}

@Suite("Library CSV Import Summary Log Line")
struct LibraryCSVImportLogLineTests {

    @Test
    func summaryLogLineWithAllZeros() {
        let summary = makeSummary()
        let line = LibraryCSVImportSheet.summaryLogLine(summary)
        #expect(line == "rows=0/0 skipped=0 W=0 F=0 H=0 R=0")
    }

    @Test
    func summaryLogLineWithMixedValues() {
        let summary = makeSummary(
            rowsRead: 100,
            rowsImported: 95,
            rowsSkipped: 5,
            watchlist: 40,
            favorites: 30,
            history: 20,
            ratings: 10
        )
        let line = LibraryCSVImportSheet.summaryLogLine(summary)
        #expect(line == "rows=95/100 skipped=5 W=40 F=30 H=20 R=10")
    }

    @Test
    func summaryLogLineOmitsMediaItemCounters() {
        let summary = makeSummary(
            rowsRead: 10,
            rowsImported: 10,
            created: 99,
            updated: 88
        )
        let line = LibraryCSVImportSheet.summaryLogLine(summary)
        #expect(line == "rows=10/10 skipped=0 W=0 F=0 H=0 R=0")
    }

    @Test
    func summaryLogLineWithLargeNumbers() {
        let summary = makeSummary(
            rowsRead: 1_000_000,
            rowsImported: 999_999,
            rowsSkipped: 1,
            watchlist: 500_000,
            favorites: 250_000,
            history: 125_000,
            ratings: 124_999
        )
        let line = LibraryCSVImportSheet.summaryLogLine(summary)
        #expect(line == "rows=999999/1000000 skipped=1 W=500000 F=250000 H=125000 R=124999")
    }
}

@Suite("Library CSV Import Debug File Stats")
struct LibraryCSVImportDebugFileStatsTests {

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test
    func debugFileStatsForMissingFileReturnsReadFailed() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stats = LibraryCSVImportSheet.debugFileStats(at: missing)
        #expect(stats.hasPrefix("read=failed path="))
    }

    @Test
    func debugFileStatsForEmptyFile() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("empty.csv")
        try Data().write(to: url)

        let stats = LibraryCSVImportSheet.debugFileStats(at: url)
        #expect(stats == "bytes=0 lines=0 header=\"\"")
    }

    @Test
    func debugFileStatsForUTF8FileReturnsBytesLinesAndHeader() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("utf8.csv")
        let content = "Const,Title,Your Rating\ntt001,Movie,8\n"
        try content.write(to: url, atomically: true, encoding: .utf8)

        let stats = LibraryCSVImportSheet.debugFileStats(at: url)
        #expect(stats.contains("bytes="))
        #expect(stats.contains("lines=2"))
        #expect(stats.contains("header=\"Const,Title,Your Rating\""))
    }

    @Test
    func debugFileStatsForUTF16FileReturnsBytesLinesAndHeader() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("utf16.csv")
        let content = "ID,Name\n1,Alpha\n"
        try content.write(to: url, atomically: true, encoding: .utf16)

        let stats = LibraryCSVImportSheet.debugFileStats(at: url)
        #expect(stats.contains("bytes="))
        #expect(stats.contains("lines=2"))
        #expect(stats.contains("header=\"ID,Name\""))
    }

    @Test
    func debugFileStatsTrimsHeaderWhitespace() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("whitespace.csv")
        try "  Const , Title   \ntt001,Movie\n".write(to: url, atomically: true, encoding: .utf8)

        let stats = LibraryCSVImportSheet.debugFileStats(at: url)
        #expect(stats.contains("header=\"Const , Title\""))
    }

    @Test
    func debugFileStatsTruncatesHeaderToEightyCharacters() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("longheader.csv")
        let longHeader = String(repeating: "A", count: 200)
        try "\(longHeader)\nline2\n".write(to: url, atomically: true, encoding: .utf8)

        let stats = LibraryCSVImportSheet.debugFileStats(at: url)
        #expect(stats.contains("header=\""))
        // The header in the output should be at most 80 characters inside the quotes
        let prefix = "header=\""
        guard let range = stats.range(of: prefix) else {
            Issue.record("Missing header prefix")
            return
        }
        let headerStart = stats.index(range.upperBound, offsetBy: 0)
        let headerEnd = stats[headerStart...].firstIndex(of: "\"") ?? stats.endIndex
        let headerValue = String(stats[headerStart..<headerEnd])
        #expect(headerValue.count == 80)
    }

    @Test
    func debugFileStatsCountsWindowsLineEndingsCorrectly() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("windows.csv")
        let content = "Header1,Header2\r\nValue1,Value2\r\nValue3,Value4\r\n"
        try content.write(to: url, atomically: true, encoding: .utf8)

        let stats = LibraryCSVImportSheet.debugFileStats(at: url)
        #expect(stats.contains("lines=3"))
        #expect(stats.contains("header=\"Header1,Header2\""))
    }

    @Test
    func debugFileStatsHandlesBinaryDataViaIsoLatin1() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("binary.csv")
        // Avoid 0xFF 0xFE because it's a UTF-16LE BOM and would be decoded as UTF-16 instead of ISO-8859-1
        var data = Data([0x00, 0x01, 0x02, 0x03])
        data.append(Data("\nSecond\n".utf8))
        try data.write(to: url)

        let stats = LibraryCSVImportSheet.debugFileStats(at: url)
        #expect(stats.contains("bytes="))
        #expect(stats.contains("lines=2"))
        // ISO-8859-1 can decode any byte sequence, so it should never report undecodable
        #expect(!stats.contains("text=undecodable"))
    }
}

// MARK: - Helpers

private func makeSummary(
    format: LibraryCSVDetectedFormat = .generic,
    rowsRead: Int = 0,
    rowsImported: Int = 0,
    rowsSkipped: Int = 0,
    created: Int = 0,
    updated: Int = 0,
    watchlist: Int = 0,
    favorites: Int = 0,
    history: Int = 0,
    ratings: Int = 0
) -> LibraryCSVImportSummary {
    LibraryCSVImportSummary(
        detectedFormat: format,
        rowsRead: rowsRead,
        rowsImported: rowsImported,
        rowsSkipped: rowsSkipped,
        mediaItemsCreated: created,
        mediaItemsUpdated: updated,
        watchlistImported: watchlist,
        favoritesImported: favorites,
        historyImported: history,
        ratingsImported: ratings
    )
}
