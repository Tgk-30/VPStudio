import Testing
import Foundation
@testable import VPStudio

@Suite("ReleaseNameParser")
struct ReleaseNameParserTests {

    // MARK: - Happy path

    @Test func extractsTrailingGroupFromDottedName() {
        #expect(
            ReleaseNameParser.releaseGroup(from: "Movie.2024.1080p.BluRay.x265-RARBG") == "RARBG"
        )
    }

    @Test func extractsGroupFromSpacedName() {
        #expect(
            ReleaseNameParser.releaseGroup(from: "Some Movie 2021 2160p WEB-DL DDP5 1 Atmos-NTb") == "NTb"
        )
    }

    @Test func extractsGroupWithDigitsInName() {
        #expect(
            ReleaseNameParser.releaseGroup(from: "Show.S01E01.1080p.WEB.h264-TGx") == "TGx"
        )
    }

    // MARK: - Robustness: extensions and bracket junk

    @Test func stripsTrailingFileExtensionBeforeGroup() {
        #expect(
            ReleaseNameParser.releaseGroup(from: "Movie.2024.1080p.BluRay.x265-RARBG.mkv") == "RARBG"
        )
    }

    @Test func stripsTrailingBracketTagBeforeGroup() {
        #expect(
            ReleaseNameParser.releaseGroup(from: "Movie.2024.1080p.WEB-DL.x264-FLUX [eztv]") == "FLUX"
        )
    }

    @Test func stripsTrailingParenTagBeforeGroup() {
        #expect(
            ReleaseNameParser.releaseGroup(from: "Movie.2024.1080p.x265-PSA (1.2GB)") == "PSA"
        )
    }

    @Test func stripsBothBracketTagAndExtension() {
        #expect(
            ReleaseNameParser.releaseGroup(from: "Movie.2024.1080p.x265-RARBG.mkv [eztv]") == "RARBG"
        )
    }

    @Test func trimsSurroundingWhitespaceAndUsesFirstLine() {
        #expect(
            ReleaseNameParser.releaseGroup(from: "  Movie.2024.1080p.x265-GROUP  \n1080p mirror") == "GROUP"
        )
    }

    // MARK: - No-group / negative cases

    @Test func returnsNilWhenNoTrailingGroup() {
        #expect(ReleaseNameParser.releaseGroup(from: "Movie.2024.1080p.BluRay.x265") == nil)
    }

    @Test func returnsNilForDottedNameWithoutDash() {
        #expect(ReleaseNameParser.releaseGroup(from: "Some.Movie.Title.2024") == nil)
    }

    @Test func returnsNilForEmptyOrWhitespaceTitle() {
        #expect(ReleaseNameParser.releaseGroup(from: "") == nil)
        #expect(ReleaseNameParser.releaseGroup(from: "   \n  ") == nil)
    }

    @Test func returnsNilWhenTrailingTokenIsPurelyNumeric() {
        // A trailing "-2024" (or similar) is metadata, not a group.
        #expect(ReleaseNameParser.releaseGroup(from: "Movie.Title.WEB-2024") == nil)
    }

    @Test func returnsNilWhenTrailingTokenContainsSpaces() {
        // Trailing fragment after a hyphenated word is not a single-token group.
        #expect(ReleaseNameParser.releaseGroup(from: "Movie Title - The Sequel") == nil)
    }

    @Test func returnsNilForTrailingDashWithNothingAfter() {
        #expect(ReleaseNameParser.releaseGroup(from: "Movie.2024.1080p-") == nil)
    }

    // MARK: - Hyphenated source tokens

    @Test func usesLastDashSoHyphenatedSourceDoesNotMaskGroup() {
        // "WEB-DL" contains a dash, but the real group follows the final dash.
        #expect(
            ReleaseNameParser.releaseGroup(from: "Movie.2024.2160p.WEB-DL.DV.HDR-CMRG") == "CMRG"
        )
    }
}
