import SwiftUI
import Testing
@testable import VPStudio

@Suite("Artwork Fallback Style")
struct ArtworkFallbackStyleTests {

    // MARK: - Initials

    @Test
    func initialsEmptyStringReturnsVP() {
        #expect(ArtworkFallbackStyle.initials(for: "") == "VP")
    }

    @Test
    func initialsWhitespaceOnlyReturnsVP() {
        #expect(ArtworkFallbackStyle.initials(for: "   ") == "VP")
    }

    @Test
    func initialsSkipsLeadingFillerWords() {
        #expect(ArtworkFallbackStyle.initials(for: "The Lord of the Rings") == "LR")
    }

    @Test
    func initialsSingleWordReturnsFirstTwoLetters() {
        #expect(ArtworkFallbackStyle.initials(for: "Dune") == "DU")
    }

    @Test
    func initialsSingleLetterFallsBackToUnicode() {
        #expect(ArtworkFallbackStyle.initials(for: "A") == "A")
    }

    @Test
    func initialsAllFillerWordsFallsBackToUnicodeLetters() {
        #expect(ArtworkFallbackStyle.initials(for: "The Of A") == "TH")
    }

    @Test
    func initialsIgnoresPunctuation() {
        #expect(ArtworkFallbackStyle.initials(for: "Dune: Part Two") == "DP")
    }

    @Test
    func initialsForPunctuationOnlyTitleReturnsVP() {
        #expect(ArtworkFallbackStyle.initials(for: "...") == "VP")
    }

    @Test
    func initialsHandlesMultipleFillerWords() {
        #expect(ArtworkFallbackStyle.initials(for: "An American in Paris") == "AP")
    }

    @Test
    func initialsHandlesLeadingAndTrailingWhitespace() {
        #expect(ArtworkFallbackStyle.initials(for: "  Inception  ") == "IN")
    }

    @Test
    func initialsNumericTitleReturnsFirstTwoDigits() {
        #expect(ArtworkFallbackStyle.initials(for: "1984") == "19")
    }

    @Test
    func initialsMixedFillerAndContent() {
        #expect(ArtworkFallbackStyle.initials(for: "The Silence of the Lambs") == "SL")
    }

    @Test
    func initialsLowercaseFillerWordsAreSkipped() {
        #expect(ArtworkFallbackStyle.initials(for: "the godfather") == "GO")
    }

    // MARK: - Palette

    @Test
    func paletteReturnsTwoColors() {
        #expect(ArtworkFallbackStyle.palette(for: "Dune", type: nil).count == 2)
    }

    @Test
    func paletteIsDeterministicForSameTitleAndType() {
        let first = ArtworkFallbackStyle.palette(for: "Deterministic", type: nil)
        let second = ArtworkFallbackStyle.palette(for: "Deterministic", type: nil)
        #expect(first == second)
    }

    @Test
    func paletteForSeriesReturnsFixedBlueColors() {
        let expected: [Color] = [
            Color(red: 0.10, green: 0.23, blue: 0.48),
            Color(red: 0.31, green: 0.61, blue: 0.93),
        ]
        #expect(ArtworkFallbackStyle.palette(for: "Any Title", type: .series) == expected)
    }

    @Test
    func paletteForMovieReturnsTwoColors() {
        #expect(ArtworkFallbackStyle.palette(for: "Dune", type: .movie).count == 2)
    }

    @Test
    func paletteForNilTypeReturnsTwoColors() {
        #expect(ArtworkFallbackStyle.palette(for: "Unknown", type: nil).count == 2)
    }

    // MARK: - Metadata

    @Test
    func metadataMovieWithYear() {
        #expect(ArtworkFallbackStyle.metadata(for: .movie, year: 2024) == "MOVIE • 2024")
    }

    @Test
    func metadataSeriesWithYear() {
        #expect(ArtworkFallbackStyle.metadata(for: .series, year: 2024) == "TV SHOW • 2024")
    }

    @Test
    func metadataNilTypeWithYear() {
        #expect(ArtworkFallbackStyle.metadata(for: nil, year: 2024) == "FEATURE • 2024")
    }

    @Test
    func metadataMovieWithoutYear() {
        #expect(ArtworkFallbackStyle.metadata(for: .movie, year: nil) == "MOVIE")
    }

    @Test
    func metadataSeriesWithoutYear() {
        #expect(ArtworkFallbackStyle.metadata(for: .series, year: nil) == "TV SHOW")
    }

    @Test
    func metadataNilTypeWithoutYear() {
        #expect(ArtworkFallbackStyle.metadata(for: nil, year: nil) == "FEATURE")
    }

    // MARK: - Accent Symbols

    @Test
    func accentSymbolForMovie() {
        #expect(ArtworkFallbackStyle.accentSymbol(for: .movie) == "film.stack.fill")
    }

    @Test
    func accentSymbolForSeries() {
        #expect(ArtworkFallbackStyle.accentSymbol(for: .series) == "tv.fill")
    }

    @Test
    func accentSymbolForNilType() {
        #expect(ArtworkFallbackStyle.accentSymbol(for: nil) == "film.stack.fill")
    }
}
