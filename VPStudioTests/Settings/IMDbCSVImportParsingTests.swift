import Foundation
import Testing
@testable import VPStudio

// MARK: - CSV Line Parsing

@Suite("IMDb CSV Line Parsing")
struct IMDbCSVLineParsingTests {

    @Test func simpleFieldsSplitOnCommas() {
        #expect(IMDbCSVImportSheet.parseCSVLine("a,b,c") == ["a", "b", "c"])
    }

    @Test func embeddedCommasInsideQuotes() {
        #expect(IMDbCSVImportSheet.parseCSVLine(#""Movie, The",2024,Action"#) == ["Movie, The", "2024", "Action"])
    }

    @Test func escapedQuotesBecomeSingleQuote() {
        #expect(IMDbCSVImportSheet.parseCSVLine(#""Movie ""The One""",2024"#) == ["Movie \"The One\"", "2024"])
    }

    @Test func emptyStringReturnsSingleEmptyField() {
        #expect(IMDbCSVImportSheet.parseCSVLine("") == [""])
    }

    @Test func emptyFieldsBetweenCommas() {
        #expect(IMDbCSVImportSheet.parseCSVLine("a,,c") == ["a", "", "c"])
    }

    @Test func leadingCommaProducesEmptyFirstField() {
        #expect(IMDbCSVImportSheet.parseCSVLine(",b,c") == ["", "b", "c"])
    }

    @Test func trailingCommaProducesEmptyLastField() {
        #expect(IMDbCSVImportSheet.parseCSVLine("a,b,") == ["a", "b", ""])
    }

    @Test func whitespaceTrimmedOnUnquotedFields() {
        #expect(IMDbCSVImportSheet.parseCSVLine("  a  , b ,c") == ["a", "b", "c"])
    }

    @Test func whitespaceTrimmedInsideQuotedFieldsToo() {
        #expect(IMDbCSVImportSheet.parseCSVLine(#""  Movie  ",2024"#) == ["Movie", "2024"])
    }

    @Test func singleQuotedFieldWithNoCommas() {
        #expect(IMDbCSVImportSheet.parseCSVLine(#""Hello World""#) == ["Hello World"])
    }

    @Test func multipleQuotedFieldsInOneLine() {
        #expect(IMDbCSVImportSheet.parseCSVLine(#""A","B","C""#) == ["A", "B", "C"])
    }

    @Test func mixedQuotedAndUnquotedFields() {
        #expect(IMDbCSVImportSheet.parseCSVLine(#"tt123,"Movie, The",2024,8"#) == ["tt123", "Movie, The", "2024", "8"])
    }

    @Test func consecutiveEscapedQuotes() {
        #expect(IMDbCSVImportSheet.parseCSVLine(#""a""""b""#) == ["a\"\"b"])
    }

    @Test func quotedFieldWithEmbeddedCommaAndEscapedQuote() {
        let line = #""""Great"" Movie, The",2024"#
        #expect(IMDbCSVImportSheet.parseCSVLine(line) == ["\"Great\" Movie, The", "2024"])
    }

    @Test func whitespaceOnlyLineAfterParsingYieldsEmptyField() {
        #expect(IMDbCSVImportSheet.parseCSVLine("   ") == [""])
    }
}

// MARK: - Header Normalization

@Suite("IMDb CSV Header Normalization")
struct IMDbCSVHeaderNormalizationTests {

    @Test func stripsSpecialCharactersAndLowercases() {
        let headers = ["Your Rating", "IMDb ID", "Date-Added", "Original_Title"]
        #expect(IMDbCSVImportPolicy.normalizedHeaders(from: headers) == [
            "yourrating",
            "imdbid",
            "dateadded",
            "originaltitle",
        ])
    }

    @Test func preservesAlphanumericCharacters() {
        #expect(IMDbCSVImportPolicy.normalizedHeaders(from: ["Title123"]) == ["title123"])
    }

    @Test func emptyHeaderBecomesEmptyString() {
        #expect(IMDbCSVImportPolicy.normalizedHeaders(from: [""]) == [""])
    }

    @Test func headerWithOnlySpecialCharactersBecomesEmpty() {
        #expect(IMDbCSVImportPolicy.normalizedHeaders(from: ["!@#$%"]) == [""])
    }

    @Test func alreadyLowercaseAlphanumericPassesThrough() {
        #expect(IMDbCSVImportPolicy.normalizedHeaders(from: ["title", "year2024"]) == ["title", "year2024"])
    }

    @Test func spacesUnderscoresAndHyphensRemoved() {
        #expect(IMDbCSVImportPolicy.normalizedHeaders(from: ["Your_Rating", "my-score", "Date Rated"]) == [
            "yourrating",
            "myscore",
            "daterated",
        ])
    }
}

// MARK: - Column Mapping Detection

@Suite("IMDb CSV Column Mapping Detection")
struct IMDbCSVColumnMappingTests {

    @Test func titleVariantsMapToTitle() {
        let headers = ["title", "name", "primarytitle", "originaltitle", "movie", "show"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: headers)
        for header in headers {
            #expect(mappings[header] == "title", "Expected \(header) to map to title")
        }
    }

    @Test func yearVariantsMapToYear() {
        let headers = ["year", "releaseyear", "startyear"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: headers)
        for header in headers {
            #expect(mappings[header] == "year", "Expected \(header) to map to year")
        }
    }

    @Test func mediaTypeVariantsMapToMediaType() {
        let headers = ["type", "titletype", "mediatype", "kind"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: headers)
        for header in headers {
            #expect(mappings[header] == "mediaType", "Expected \(header) to map to mediaType")
        }
    }

    @Test func imdbIDVariantsMapToImdbID() {
        let headers = ["const", "tconst", "imdbid", "imdbconst", "titleconst", "id"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: headers)
        for header in headers {
            #expect(mappings[header] == "imdbID", "Expected \(header) to map to imdbID")
        }
    }

    @Test func userRatingVariantsMapToUserRating() {
        let headers = ["yourrating", "userrating", "rating", "myscore", "myrating", "score", "yourscore", "yourated"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: headers)
        for header in headers {
            #expect(mappings[header] == "userRating", "Expected \(header) to map to userRating")
        }
    }

    @Test func imdbRatingVariantsMapToImdbRating() {
        let headers = ["imdbrating", "imdbscore"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: headers)
        for header in headers {
            #expect(mappings[header] == "imdbRating", "Expected \(header) to map to imdbRating")
        }
    }

    @Test func likedVariantsMapToLiked() {
        let headers = ["liked", "favorite", "favourite", "isliked"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: headers)
        for header in headers {
            #expect(mappings[header] == "liked", "Expected \(header) to map to liked")
        }
    }

    @Test func dateVariantsMapToDate() {
        let headers = ["created", "daterated", "dateadded", "watcheddate", "watchedat", "added", "date"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: headers)
        for header in headers {
            #expect(mappings[header] == "date", "Expected \(header) to map to date")
        }
    }

    @Test func unknownHeadersProduceNoMapping() {
        let headers = ["unknown", "foobar", "customcolumn"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: headers)
        for header in headers {
            #expect(mappings[header] == nil, "Expected \(header) to have no mapping")
        }
    }

    @Test func mixedKnownAndUnknownHeadersMapCorrectly() {
        let headers = ["primarytitle", "startyear", "unknowncolumn", "yourrating", "notamapping"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: headers)
        #expect(mappings["primarytitle"] == "title")
        #expect(mappings["startyear"] == "year")
        #expect(mappings["yourrating"] == "userRating")
        #expect(mappings["unknowncolumn"] == nil)
        #expect(mappings["notamapping"] == nil)
    }

    @Test func endToEndNormalizationAndMapping() {
        let rawHeaders = ["Const", "Primary Title", "Start Year", "Your Rating", "IMDb Rating", "Date Added", "Custom Field"]
        let normalized = IMDbCSVImportPolicy.normalizedHeaders(from: rawHeaders)
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: normalized)
        #expect(mappings["const"] == "imdbID")
        #expect(mappings["primarytitle"] == "title")
        #expect(mappings["startyear"] == "year")
        #expect(mappings["yourrating"] == "userRating")
        #expect(mappings["imdbrating"] == "imdbRating")
        #expect(mappings["dateadded"] == "date")
        #expect(mappings["customfield"] == nil)
    }

    @Test func rawHeadersMapUsingRawHeaderKeysForPreviewLookup() {
        let rawHeaders = ["Const", "Primary Title", "Start Year", "Your Rating", "IMDb Rating", "Date Added", "Custom Field"]
        let mappings = IMDbCSVImportSheet.detectColumnMappings(from: rawHeaders)

        #expect(mappings["Const"] == "imdbID")
        #expect(mappings["Primary Title"] == "title")
        #expect(mappings["Start Year"] == "year")
        #expect(mappings["Your Rating"] == "userRating")
        #expect(mappings["IMDb Rating"] == "imdbRating")
        #expect(mappings["Date Added"] == "date")
        #expect(mappings["Custom Field"] == nil)
        #expect(mappings["yourrating"] == nil)
    }
}
