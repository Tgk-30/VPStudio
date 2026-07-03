import Testing
@testable import VPStudio

@Suite("IMDb CSV Import Policy Coverage")
struct IMDbCSVImportPolicyCoverageTests {
    @Test
    func importButtonTitleCoversPreviewChangeAndImportingStates() {
        #expect(
            IMDbCSVImportPolicy.importButtonTitle(
                hasSelectedFile: false,
                previewDetected: false,
                importInFlight: false
            ) == "Preview CSV Before Importing"
        )
        #expect(
            IMDbCSVImportPolicy.importButtonTitle(
                hasSelectedFile: false,
                previewDetected: true,
                importInFlight: false
            ) == "Change CSV File"
        )
        #expect(
            IMDbCSVImportPolicy.importButtonTitle(
                hasSelectedFile: true,
                previewDetected: true,
                importInFlight: false
            ) == "Import Selected CSV"
        )
        #expect(
            IMDbCSVImportPolicy.importButtonTitle(
                hasSelectedFile: true,
                previewDetected: true,
                importInFlight: true
            ) == "Importing..."
        )
    }

    @Test
    func targetFolderNameReturnsTrimmedNameOnlyWhenEnabled() {
        #expect(IMDbCSVImportPolicy.targetFolderName(importToFolder: false, folderName: " Watchlist ") == nil)
        #expect(IMDbCSVImportPolicy.targetFolderName(importToFolder: true, folderName: "   ") == nil)
        #expect(IMDbCSVImportPolicy.targetFolderName(importToFolder: true, folderName: " Watchlist ") == "Watchlist")
    }

    @Test
    func normalizedHeadersAndAliasesMapIMDbExportNames() {
        #expect(IMDbCSVImportPolicy.knownFieldAliases.isEmpty == false)
        #expect(IMDbCSVImportPolicy.normalizedHeaders(from: ["Your Rating", "IMDb URL"]) == ["yourrating", "imdburl"])
        #expect(IMDbCSVImportPolicy.normalizedFieldName("Your Rating") == "userRating")
        #expect(IMDbCSVImportPolicy.normalizedFieldName("IMDb URL") == "url")
        #expect(IMDbCSVImportPolicy.normalizedFieldName("Unknown Header") == nil)
    }

    @Test
    func normalizedAISuggestedMappingsDropsUnknownAndNilFields() {
        let suggestions = IMDbCSVImportPolicy.normalizedAISuggestedMappings([
            "Title": "movie",
            "Vote": "Your Rating",
            "Ignored": nil,
            "Unknown": "made-up-field",
        ])

        #expect(suggestions == [
            "Title": "title",
            "Vote": "userRating",
        ])
    }

    @Test
    func previewRowsSkipsBlankLinesAndHonorsLimit() {
        let lines = [
            "",
            " Dune,2021 ",
            "\"Everything, Everywhere\",2022",
            "Ignored,2030",
        ]

        let rows = IMDbCSVImportPolicy.previewRows(from: lines[...], limit: 2)

        #expect(rows == [
            ["Dune", "2021"],
            ["Everything, Everywhere", "2022"],
        ])
    }

    @Test
    func csvLineParserHandlesQuotedCommasAndEscapedQuotes() {
        let row = IMDbCSVImportSheet.parseCSVLine(#""Dune, Part Two","A ""large"" sequel",2024"#)

        #expect(row == ["Dune, Part Two", #"A "large" sequel"#, "2024"])
    }

    @Test
    func detectColumnMappingsKeepsOriginalHeadersAsKeys() {
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: [
            "Title",
            "Your Rating",
            "IMDb Rating",
            "Not Imported",
        ])

        #expect(mappings["Title"] == "title")
        #expect(mappings["Your Rating"] == "userRating")
        #expect(mappings["IMDb Rating"] == "imdbRating")
        #expect(mappings["Not Imported"] == nil)
    }
}
