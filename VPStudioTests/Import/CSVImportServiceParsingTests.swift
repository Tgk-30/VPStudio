import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct CSVImportServiceParsingTests {
    @Test func parseCSVRecordsHandlesEmptyFields() {
        let csv = "title,year,rating\n\"Film With Empty Rating\",2020,\n,2019,8\n\"Another Film\",,7"
        let records = parseCSVRecords(csv)
        // Parser includes header row
        #expect(records.count == 4)
        #expect(records[1].count == 3)
        #expect(records[1][2].isEmpty)
    }

    @Test func parseCSVRecordsHandlesQuotedCommas() {
        let csv = "title,year\n\"The Good, the Bad and the Ugly\",1966\n\"Film, With Commas\",2021"
        let records = parseCSVRecords(csv)
        // Parser includes header row
        #expect(records.count == 3)
        #expect(records[1][0] == "The Good, the Bad and the Ugly")
        #expect(records[2][0] == "Film, With Commas")
    }

    @Test func parseCSVRecordsHandlesEscapedQuotes() {
        let csv = "title,year\n\"He said \"\"Hello\"\"\",2020\n\"Film \"\"Nominated\"\"\",2021"
        let records = parseCSVRecords(csv)
        // Parser includes header row
        #expect(records.count == 3)
        #expect(records[1][0] == "He said \"Hello\"")
        #expect(records[2][0] == "Film \"Nominated\"")
    }

    @Test func parseCSVRecordsHandlesMixedNewlines() {
        let csv = "title,year\r\nFilm One,2020\r\nFilm Two,2021\r"
        let records = parseCSVRecords(csv)
        // Parser includes header row
        #expect(records.count == 3)
    }

    @Test func parseCSVRecordsSkipsEmptyRows() {
        let csv = "title,year\n\nFilm One,2020\n\nFilm Two,2021\n\n"
        let records = parseCSVRecords(csv)
        // Parser includes header row
        #expect(records.count == 3)
    }

    @Test func parseCSVRecordsHandlesTrailingCommas() {
        let csv = "title,year,rating\nFilm One,2020,8,\nFilm Two,2021,,"
        let records = parseCSVRecords(csv)
        // Parser includes header row
        #expect(records.count == 3)
        #expect(records[1].count >= 3)
    }

    @Test func parseDoubleHandlesSlashNotation() {
        #expect(parseDouble("8/10") == 8.0)
        #expect(parseDouble("10/10") == 10.0)
        #expect(parseDouble("5/5") == 5.0)
    }

    @Test func parseDoubleHandlesCommaDecimal() {
        #expect(parseDouble("8,5") == 8.5)
        #expect(parseDouble("7,5") == 7.5)
        #expect(parseDouble("10,0") == 10.0)
    }

    @Test func parseDoubleHandlesPlainNumbers() {
        #expect(parseDouble("8") == 8.0)
        #expect(parseDouble("8.5") == 8.5)
        #expect(parseDouble("10") == 10.0)
    }

    @Test func parseDoubleReturnsNilForInvalid() {
        #expect(parseDouble("") == nil)
        #expect(parseDouble("abc") == nil)
        #expect(parseDouble("ten") == nil)
    }

    @Test func parseBoolHandlesVariousFormats() {
        #expect(parseBool("true") == true)
        #expect(parseBool("True") == true)
        #expect(parseBool("TRUE") == true)
        #expect(parseBool("yes") == true)
        #expect(parseBool("Yes") == true)
        #expect(parseBool("Y") == true)
        #expect(parseBool("1") == true)
        #expect(parseBool("liked") == true)
        #expect(parseBool("favorite") == true)
        #expect(parseBool("favourite") == true)

        #expect(parseBool("false") == false)
        #expect(parseBool("False") == false)
        #expect(parseBool("no") == false)
        #expect(parseBool("N") == false)
        #expect(parseBool("0") == false)
        #expect(parseBool("disliked") == false)

        #expect(parseBool("maybe") == nil)
        #expect(parseBool("2") == nil)
        #expect(parseBool("") == nil)
    }

    @Test func parseYearExtractsFromVariousFormats() {
        #expect(parseYear("2020") == 2020)
        #expect(parseYear("(2020)") == 2020)
        #expect(parseYear("2020年") == 2020)
        #expect(parseYear("Year: 2020") == 2020)
        #expect(parseYear("1999-2020") == 1999)
    }

    @Test func parseYearRejectsInvalidYears() {
        #expect(parseYear("") == nil)
        #expect(parseYear("abc") == nil)
        #expect(parseYear("100") == nil)
        #expect(parseYear("5000") == nil)
    }

    @Test func parseIMDbIDExtractsFromVariousFormats() {
        #expect(parseIMDbID("tt1234567") == "tt1234567")
        #expect(parseIMDbID("TT1234567") == "tt1234567")
        #expect(parseIMDbID("https://www.imdb.com/title/tt1234567/") == "tt1234567")
        #expect(parseIMDbID("https://www.imdb.com/title/tt1234567/?ref_=tt_st") == "tt1234567")
        #expect(parseIMDbID("Title (tt1234567)") == nil)
        #expect(parseIMDbID("tt1234567?ref_=tt_st") == nil)
        #expect(parseIMDbID("movie-imdb-tt1234567") == "tt1234567")
        #expect(parseIMDbID("series-omdb-TT7654321") == "tt7654321")
        #expect(parseIMDbID("omdb-TT7654321") == "tt7654321")
        #expect(parseIMDbID("https://example.com/title/tt1234567") == nil)
    }

    @Test func appScopedIMDbIDAcceptsOnlyKnownCompositePrefixes() {
        #expect(IMDbIdentifierPolicy.appScopedID(in: "https://www.imdb.com/title/TT1160419/") == "tt1160419")
        #expect(IMDbIdentifierPolicy.appScopedID(in: "imdb-TT1160419") == "tt1160419")
        #expect(IMDbIdentifierPolicy.appScopedID(in: "omdb-TT1160419") == "tt1160419")
        #expect(IMDbIdentifierPolicy.appScopedID(in: "movie-imdb-tt1234567") == "tt1234567")
        #expect(IMDbIdentifierPolicy.appScopedID(in: "series-omdb-TT7654321") == "tt7654321")
        #expect(IMDbIdentifierPolicy.appScopedID(in: "episode-imdb-TT1234567") == nil)
        #expect(IMDbIdentifierPolicy.appScopedID(in: "episode-omdb-TT7654321") == nil)
        #expect(IMDbIdentifierPolicy.appScopedID(in: "polluted-prefix-tt1234567") == nil)
        #expect(IMDbIdentifierPolicy.appScopedID(in: "omdb-tt1234567-extra") == nil)
        #expect(IMDbIdentifierPolicy.appScopedID(in: "movie-imdb-tt1234567-extra") == nil)
    }

    @Test func episodeScopedIMDbIDAcceptsOnlyEpisodeCompositePrefixes() {
        #expect(IMDbIdentifierPolicy.episodeScopedID(in: "https://www.imdb.com/title/TT1234567/") == "tt1234567")
        #expect(IMDbIdentifierPolicy.episodeScopedID(in: "episode-imdb-TT1234567") == "tt1234567")
        #expect(IMDbIdentifierPolicy.episodeScopedID(in: "episode-omdb-TT7654321") == "tt7654321")
        #expect(IMDbIdentifierPolicy.episodeScopedID(in: "movie-imdb-tt1234567") == nil)
        #expect(IMDbIdentifierPolicy.episodeScopedID(in: "series-omdb-TT7654321") == nil)
    }

    @Test func parseIMDbIDReturnsNilForInvalid() {
        #expect(parseIMDbID("") == nil)
        #expect(parseIMDbID("1234567") == nil)
        #expect(parseIMDbID("tt") == nil)
        #expect(parseIMDbID("ttabc") == nil)
    }

    @Test func parseMediaTypeRecognizesSeries() {
        #expect(parseMediaType("tv") == .series)
        #expect(parseMediaType("tvSeries") == .series)
        #expect(parseMediaType("TV Series") == .series)
        #expect(parseMediaType("series") == .series)
        #expect(parseMediaType("show") == .series)
        #expect(parseMediaType("episode") == .series)
    }

    @Test func parseMediaTypeDefaultsToMovie() {
        #expect(parseMediaType("movie") == .movie)
        #expect(parseMediaType("film") == .movie)
        #expect(parseMediaType("") == .movie)
        #expect(parseMediaType(nil) == .movie)
    }

    @Test func parseDateHandlesVariousFormats() {
        let date2020 = parseDate("2020-01-15")
        #expect(date2020 != nil)

        let dateAlt = parseDate("2020/01/15")
        #expect(dateAlt != nil)

        let dateUS = parseDate("01/15/2020")
        #expect(dateUS != nil)

        let dateISO = parseDate("2020-01-15T10:30:00")
        #expect(dateISO != nil)

        let dateISOZ = parseDate("2020-01-15T10:30:00Z")
        #expect(dateISOZ != nil)
    }

    @Test func parseDateReturnsNilForInvalid() {
        #expect(parseDate("") == nil)
        #expect(parseDate("not-a-date") == nil)
        #expect(parseDate("2020-13-45") == nil)
    }

    @Test func detectedFormatRecognizesIMDbWatchlist() {
        let headers1 = ["const", "created", "title"]
        #expect(detectedFormat(from: headers1) == .imdbWatchlist)

        let headers2 = ["tconst", "created", "title"]
        #expect(detectedFormat(from: headers2) == .imdbWatchlist)
    }

    @Test func detectedFormatRecognizesIMDbRatings() {
        let headers1 = ["const", "title", "daterated"]
        #expect(detectedFormat(from: headers1) == .imdbRatings)

        let headers2 = ["tconst", "title", "yourrating"]
        #expect(detectedFormat(from: headers2) == .imdbRatings)
    }

    @Test func detectedFormatReturnsGenericForUnknown() {
        let headers = ["name", "year", "score"]
        #expect(detectedFormat(from: headers) == .generic)
    }

    @Test func normalizeHeaderRemovesBOMAndLowercases() {
        #expect(normalizeHeader("Title") == "title")
        #expect(normalizeHeader("TITLE") == "title")
        #expect(normalizeHeader("Title123") == "title123")
        #expect(normalizeHeader("\u{FEFF}Title") == "title")
        #expect(normalizeHeader("Title Type") == "titletype")
    }

    @Test func normalizedTextTrimsWhitespace() {
        #expect(normalizedText("  hello  ") == "hello")
        #expect(normalizedText("\thello\n") == "hello")
        #expect(normalizedText("") == nil)
        #expect(normalizedText("   ") == nil)
    }

    @Test func inferredScaleForRatings() {
        #expect(inferredScale(for: 0) == .likeDislike)
        #expect(inferredScale(for: -1) == .likeDislike)
        // 0.5 is > 0 and <= 10, so it maps to oneToTen
        #expect(inferredScale(for: 0.5) == .oneToTen)
        #expect(inferredScale(for: 1) == .oneToTen)
        #expect(inferredScale(for: 5) == .oneToTen)
        #expect(inferredScale(for: 10) == .oneToTen)
        #expect(inferredScale(for: 50) == .oneToHundred)
        #expect(inferredScale(for: 100) == .oneToHundred)
    }

    @Test func fallbackMediaIDGeneration() {
        let id1 = fallbackMediaID(title: "The Matrix", year: 1999)
        #expect(id1.hasPrefix("csv-"))
        #expect(id1.contains("matrix"))
        #expect(id1.contains("1999"))

        let id2 = fallbackMediaID(title: "Film", year: nil)
        #expect(id2.contains("film"))
        #expect(id2.contains("0"))

        let id3 = fallbackMediaID(title: "A", year: 2000)
        #expect(id3.hasPrefix("csv-a-2000"))

        let longTitle = fallbackMediaID(title: String(repeating: "A", count: 100), year: 2020)
        #expect(longTitle.count <= 60)
    }

    @Test func resolvedFolderNameRespectsExplicitName() {
        let result1 = resolvedFolderName(from: "My Folder", fileURL: URL(fileURLWithPath: "/tmp/test.csv"))
        #expect(result1 == "My Folder")

        let result2 = resolvedFolderName(from: "  trimmed  ", fileURL: URL(fileURLWithPath: "/tmp/test.csv"))
        #expect(result2 == "trimmed")

        let result3 = resolvedFolderName(from: "", fileURL: URL(fileURLWithPath: "/tmp/test.csv"))
        #expect(result3 == nil)

        let result4 = resolvedFolderName(from: "   ", fileURL: URL(fileURLWithPath: "/tmp/test.csv"))
        #expect(result4 == nil)
    }

    @Test func defaultFolderNameDerivesFromFilename() {
        let url1 = URL(fileURLWithPath: "/tmp/My Watchlist.csv")
        #expect(defaultFolderName(from: url1) == "My Watchlist")

        let url2 = URL(fileURLWithPath: "/tmp/Favorites.csv")
        #expect(defaultFolderName(from: url2) == "Favorites")

        let url3 = URL(fileURLWithPath: "/tmp/path/to/History.csv")
        #expect(defaultFolderName(from: url3) == "History")
    }

    @Test func inferredDestinationFromVariousFilenames() {
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/Watchlist.csv")) == .watchlist)
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/To Watch.csv")) == .watchlist)
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/Currently Watching.csv")) == .watchlist)
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/Plan to Watch.csv")) == .watchlist)
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/Release Wait.csv")) == .watchlist)

        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/Favorites.csv")) == .favorites)
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/Favourites.csv")) == .favorites)
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/Ratings.csv")) == .favorites)

        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/History.csv")) == .history)
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/Watched.csv")) == .history)
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/Completed.csv")) == .history)
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/WatchHistory.csv")) == .history)

        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/random.csv")) == nil)
        #expect(inferredDestination(from: URL(fileURLWithPath: "/tmp/data.csv")) == nil)
    }

    @Test func destinationPlanForWatchlist() {
        let plan = destinationPlan(
            format: .generic,
            destination: .watchlist,
            sentiment: nil,
            promoteLikedRatingsToFavorites: true
        )
        #expect(plan.importWatchlist == true)
        #expect(plan.importFavorites == false)
        #expect(plan.importHistory == false)
    }

    @Test func destinationPlanForFavorites() {
        let plan = destinationPlan(
            format: .generic,
            destination: .favorites,
            sentiment: nil,
            promoteLikedRatingsToFavorites: true
        )
        #expect(plan.importWatchlist == false)
        #expect(plan.importFavorites == true)
        #expect(plan.importHistory == false)
    }

    @Test func destinationPlanForHistory() {
        let plan = destinationPlan(
            format: .generic,
            destination: .history,
            sentiment: nil,
            promoteLikedRatingsToFavorites: true
        )
        #expect(plan.importWatchlist == true)
        #expect(plan.importFavorites == false)
        #expect(plan.importHistory == true)
    }

    @Test func destinationPlanForAutoWithLikedAndPromotion() {
        let plan = destinationPlan(
            format: .generic,
            destination: .auto,
            sentiment: .liked,
            promoteLikedRatingsToFavorites: true
        )
        #expect(plan.importWatchlist == false)
        #expect(plan.importFavorites == true)
        #expect(plan.importHistory == false)
    }

    @Test func destinationPlanForAutoWithoutLiked() {
        let plan = destinationPlan(
            format: .generic,
            destination: .auto,
            sentiment: nil,
            promoteLikedRatingsToFavorites: true
        )
        #expect(plan.importWatchlist == true)
        #expect(plan.importFavorites == false)
        #expect(plan.importHistory == false)
    }

    @Test func destinationPlanForAutoWithDisliked() {
        let plan = destinationPlan(
            format: .generic,
            destination: .auto,
            sentiment: .disliked,
            promoteLikedRatingsToFavorites: true
        )
        #expect(plan.importWatchlist == true)
        #expect(plan.importFavorites == false)
        #expect(plan.importHistory == false)
    }

    @Test func destinationPlanForAutoWithNoPromotion() {
        let plan = destinationPlan(
            format: .generic,
            destination: .auto,
            sentiment: .liked,
            promoteLikedRatingsToFavorites: false
        )
        #expect(plan.importWatchlist == true)
        #expect(plan.importFavorites == false)
        #expect(plan.importHistory == false)
    }

    @Test func looksLikeUTF16DetectsBOM() {
        let utf16LE = Data([0xFF, 0xFE, 0x48, 0x00, 0x49, 0x00])
        #expect(looksLikeUTF16(utf16LE) == true)

        let utf16BE = Data([0xFE, 0xFF, 0x00, 0x48, 0x00, 0x49])
        #expect(looksLikeUTF16(utf16BE) == true)

        let utf8 = Data("Hello".utf8)
        #expect(looksLikeUTF16(utf8) == false)
    }

    @Test func looksLikeUTF16DetectsNullDensity() {
        let withNulls = Data([0x48, 0x00, 0x49, 0x00, 0x00, 0x00])
        #expect(looksLikeUTF16(withNulls) == true)

        let withoutNulls = Data("Hi!".utf8)
        #expect(looksLikeUTF16(withoutNulls) == false)
    }

    @Test func readCSVTextHandlesUTF8() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let csvURL = tempDir.appendingPathComponent("utf8-test.csv")
        try "title,year\nTest,2020".write(to: csvURL, atomically: true, encoding: .utf8)

        let text = try readCSVText(from: csvURL)
        #expect(text.contains("title"))
        #expect(text.contains("Test"))
    }

    @Test func readCSVTextHandlesLatin1() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let csvURL = tempDir.appendingPathComponent("latin1-test.csv")
        let content = "title,year\nCafe,2020"
        try content.data(using: .isoLatin1)!.write(to: csvURL)

        let text = try readCSVText(from: csvURL)
        #expect(text.contains("Caf"))
    }

    @Test func readCSVTextThrowsOnUnreadableFile() {
        let badURL = URL(fileURLWithPath: "/nonexistent/path/file.csv")
        do {
            _ = try readCSVText(from: badURL)
            Issue.record("Should have thrown for unreadable file")
        } catch let error as LibraryCSVImportError {
            #expect(error == .unreadableFile)
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test func mappedRowsFiltersEmptyRows() {
        let headers = ["title", "year"]
        let values: [[String]] = [
            ["Film 1", "2020"],
            ["", ""],
            ["Film 2", "2021"]
        ]

        let mapped = mappedRows(headers: headers, values: values)
        #expect(mapped.count == 2)
        #expect(mapped[0]["title"] == "Film 1")
        #expect(mapped[1]["title"] == "Film 2")
    }

    @Test func mappedRowsHandlesIndexOutOfBounds() {
        let headers = ["title", "year", "rating"]
        let values: [[String]] = [
            ["Film 1", "2020"]
        ]

        let mapped = mappedRows(headers: headers, values: values)
        #expect(mapped.count == 1)
        #expect(mapped[0]["title"] == "Film 1")
        #expect(mapped[0]["year"] == "2020")
        #expect(mapped[0]["rating"] == "")
    }

    private func parseCSVRecords(_ text: String) -> [[String]] {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var records: [[String]] = []
        var currentRecord: [String] = []
        var currentField = ""
        var isInsideQuotes = false

        var index = normalizedText.startIndex
        while index < normalizedText.endIndex {
            let character = normalizedText[index]

            if character == "\"" {
                let next = normalizedText.index(after: index)
                if isInsideQuotes, next < normalizedText.endIndex, normalizedText[next] == "\"" {
                    currentField.append("\"")
                    index = next
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == ",", !isInsideQuotes {
                currentRecord.append(currentField)
                currentField = ""
            } else if character == "\n", !isInsideQuotes {
                currentRecord.append(currentField)
                if !currentRecord.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    records.append(currentRecord)
                }
                currentRecord = []
                currentField = ""
            } else {
                currentField.append(character)
            }

            index = normalizedText.index(after: index)
        }

        currentRecord.append(currentField)
        if !currentRecord.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            records.append(currentRecord)
        }

        return records
    }

    private func parseDouble(_ raw: String?) -> Double? {
        guard let raw = normalizedText(raw) else { return nil }
        if raw.contains("/"), let numerator = raw.split(separator: "/").first {
            return Double(String(String(numerator).trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        let sanitized = raw.replacingOccurrences(of: ",", with: ".")
        return Double(sanitized)
    }

    private func parseBool(_ raw: String?) -> Bool? {
        guard let raw = normalizedText(raw)?.lowercased() else { return nil }
        switch raw {
        case "1", "true", "yes", "y", "liked", "favorite", "favourite":
            return true
        case "0", "false", "no", "n", "disliked":
            return false
        default:
            return nil
        }
    }

    private func parseYear(_ raw: String?) -> Int? {
        guard let raw = normalizedText(raw) else { return nil }
        if let parsed = Int(raw), parsed >= 1800, parsed <= 3000 {
            return parsed
        }
        let digits = raw.filter(\.isNumber)
        if digits.count >= 4 {
            let candidate = String(digits.prefix(4))
            if let parsed = Int(candidate), parsed >= 1800, parsed <= 3000 {
                return parsed
            }
        }
        return nil
    }

    private func parseIMDbID(_ raw: String?) -> String? {
        IMDbIdentifierPolicy.appScopedID(in: raw)
    }

    private func parseMediaType(_ raw: String?) -> MediaType {
        guard let raw = normalizedText(raw)?.lowercased() else { return .movie }
        if raw.contains("tv") || raw.contains("series") || raw.contains("show") || raw.contains("episode") {
            return .series
        }
        return .movie
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw = normalizedText(raw), !raw.isEmpty else { return nil }
        let dateFormats = [
            "yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy", "M/d/yyyy",
            "dd/MM/yyyy", "dd-MM-yyyy", "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in dateFormats {
            formatter.dateFormat = format
            formatter.timeZone = format.contains("H") ? TimeZone(secondsFromGMT: 0) : .current
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: raw) {
            return date
        }
        return nil
    }

    private func detectedFormat(from headers: [String]) -> LibraryCSVDetectedFormat {
        let hasConst = headers.contains("const") || headers.contains("tconst")
        let hasTitle = headers.contains("title")
        let hasCreated = headers.contains("created")
        let hasYourRating = headers.contains("yourrating") || headers.contains("yourated")
        let hasDateRated = headers.contains("daterated")

        if hasConst, hasTitle {
            if hasDateRated {
                return .imdbRatings
            }
            if hasCreated {
                return .imdbWatchlist
            }
            if hasYourRating {
                return .imdbRatings
            }
        }
        return .generic
    }

    private func normalizeHeader(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func normalizedText(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func inferredScale(for rawRating: Double) -> FeedbackScaleMode {
        if rawRating <= 0 {
            return .likeDislike
        }
        if rawRating <= 10 {
            return .oneToTen
        }
        return .oneToHundred
    }

    private func fallbackMediaID(title: String, year: Int?) -> String {
        let slug = title
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let trimmedSlug = String(slug.prefix(48))
        let yearPart = year.map(String.init) ?? "0"
        return "csv-\(trimmedSlug)-\(yearPart)"
    }

    private func looksLikeUTF16(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        let prefix = Array(data.prefix(64))
        if prefix.starts(with: [0xFF, 0xFE]) || prefix.starts(with: [0xFE, 0xFF]) {
            return true
        }
        let nullCount = prefix.filter { $0 == 0 }.count
        return nullCount >= max(2, prefix.count / 4)
    }

    private func readCSVText(from fileURL: URL) throws -> String {
        guard let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]) else {
            throw LibraryCSVImportError.unreadableFile
        }
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if looksLikeUTF16(data), let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }
        if let latin = String(data: data, encoding: .isoLatin1) {
            return latin
        }
        throw LibraryCSVImportError.unsupportedEncoding
    }

    private func mappedRows(headers: [String], values: [[String]]) -> [[String: String]] {
        values.compactMap { row in
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                return nil
            }
            var mapped: [String: String] = [:]
            for (index, header) in headers.enumerated() where !header.isEmpty {
                let value = index < row.count ? row[index] : ""
                mapped[header] = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return mapped
        }
    }

    private struct DestinationPlan {
        var importWatchlist: Bool
        var importFavorites: Bool
        var importHistory: Bool
    }

    private func destinationPlan(
        format: LibraryCSVDetectedFormat,
        destination: LibraryCSVImportDestination,
        sentiment: FeedbackSentiment?,
        promoteLikedRatingsToFavorites: Bool
    ) -> DestinationPlan {
        switch destination {
        case .watchlist:
            return DestinationPlan(importWatchlist: true, importFavorites: false, importHistory: false)
        case .favorites:
            return DestinationPlan(importWatchlist: false, importFavorites: true, importHistory: false)
        case .history:
            return DestinationPlan(importWatchlist: true, importFavorites: false, importHistory: true)
        case .auto:
            if let sentiment, promoteLikedRatingsToFavorites, sentiment == .liked {
                return DestinationPlan(importWatchlist: false, importFavorites: true, importHistory: false)
            }
            return DestinationPlan(importWatchlist: true, importFavorites: false, importHistory: false)
        }
    }

    private func resolvedFolderName(from explicitName: String?, fileURL: URL) -> String? {
        if let explicitName {
            let trimmed = explicitName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private func defaultFolderName(from fileURL: URL) -> String {
        fileURL.deletingPathExtension().lastPathComponent
    }

    private func inferredDestination(from fileURL: URL) -> LibraryCSVImportDestination? {
        let name = fileURL.deletingPathExtension().lastPathComponent.lowercased()
        if name.contains("watchlist") || name.contains("to watch") || name.contains("currently watching")
            || name.contains("plan") || name.contains("release") || name.contains("break") {
            return .watchlist
        }
        if name.contains("favorite") || name.contains("favourite") || name.contains("ratings") {
            return .favorites
        }
        if name.contains("watchhistory") || name.contains("watch history") || name == "history"
            || name.contains("completed") || name == "watched" {
            return .history
        }
        return nil
    }
}
