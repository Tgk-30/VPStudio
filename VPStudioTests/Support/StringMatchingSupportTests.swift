import Foundation
import Testing
@testable import VPStudio

@Suite("StringMatching")
struct StringMatchingTests {
    @Test func containsStandaloneTokenFindsTokenAtStart() {
        #expect("sbs movie".containsStandaloneToken("sbs") == true)
        #expect("movie sbs".containsStandaloneToken("sbs") == true)
    }

    @Test func containsStandaloneTokenFindsTokenInMiddle() {
        #expect("movie.sbs.1080p".containsStandaloneToken("sbs") == true)
        #expect("movie-sbs-720p".containsStandaloneToken("sbs") == true)
        #expect("movie_sbs_1080p".containsStandaloneToken("sbs") == true)
    }

    @Test func containsStandaloneTokenFindsTokenAtEnd() {
        #expect("movie.sbs".containsStandaloneToken("sbs") == true)
        #expect("movie-sbs".containsStandaloneToken("sbs") == true)
    }

    @Test func containsStandaloneTokenRequiresWordBoundary() {
        #expect("movie.absurdly".containsStandaloneToken("sbs") == false)
        #expect("absurdlymovie".containsStandaloneToken("sbs") == false)
        #expect("sbsolute".containsStandaloneToken("sbs") == false)
    }

    @Test func containsStandaloneTokenHandlesNumericBoundaries() {
        #expect("movie.sbs2".containsStandaloneToken("sbs") == true)
        #expect("2sbs.movie".containsStandaloneToken("sbs") == true)
        #expect("movie2sbs".containsStandaloneToken("sbs") == false)
    }

    @Test func containsStandaloneTokenIsCaseInsensitive() {
        #expect("movie.SBS.1080p".containsStandaloneToken("sbs") == true)
        #expect("movie.Sbs.1080p".containsStandaloneToken("sbs") == true)
        #expect("movie.sBs.1080p".containsStandaloneToken("SBS") == true)
    }

    @Test func containsStandaloneTokenHandlesEmptyToken() {
        #expect("movie.sbs.1080p".containsStandaloneToken("") == false)
    }

    @Test func containsStandaloneTokenHandlesSpecialCharacters() {
        #expect("movie!sbs?1080p".containsStandaloneToken("sbs") == true)
        #expect("movie(sbs)1080p".containsStandaloneToken("sbs") == true)
        #expect("movie\"sbs\"1080p".containsStandaloneToken("sbs") == true)
    }

    @Test func containsStandaloneTokenHandlesMultipleOccurrences() {
        #expect("sbs movie sbs".containsStandaloneToken("sbs") == true)
        #expect("sbsmovie".containsStandaloneToken("sbs") == false)
    }

    @Test func containsStandaloneTokenHandlesExactMatch() {
        #expect("sbs".containsStandaloneToken("sbs") == true)
        #expect("SBS".containsStandaloneToken("sbs") == true)
    }

    @Test func containsStandaloneTokenRequiresNumericTokenIsolation() {
        #expect("movie_12_1080p".containsStandaloneToken("12") == true)
        #expect("movie_121080p".containsStandaloneToken("12") == false)
        #expect("x12".containsStandaloneToken("12") == true)
        #expect("x12y".containsStandaloneToken("12") == false)
    }

    @Test func containsStandaloneTokenRejectsNumericPrefixAndSuffixForNumericTokens() {
        #expect("a12".containsStandaloneToken("2") == false)
        #expect("12a".containsStandaloneToken("2") == false)
        #expect("1 2".containsStandaloneToken("2") == true)
    }

    @Test func containsStandaloneTokenChecksLetterBoundaryBeforeMatch() {
        #expect("abcsbs".containsStandaloneToken("sbs") == false)
        #expect("ab1sbs".containsStandaloneToken("sbs") == false)
    }

    @Test func containsStandaloneTokenChecksNumberBoundaryAfterMatch() {
        #expect("sbs2x".containsStandaloneToken("sbs") == false)
        #expect("sbs2!".containsStandaloneToken("sbs") == true)
        #expect("foo.sbs2".containsStandaloneToken("sbs") == true)
        #expect("a_1sbs".containsStandaloneToken("sbs") == true)
        #expect("ab1sbs".containsStandaloneToken("sbs") == false)
    }

    @Test func containsStandaloneTokenAdvancesThroughOverlappingMatches() {
        #expect("sbs2sbs".containsStandaloneToken("sbs") == true)
        #expect("xmovie.sbs2,1080p".containsStandaloneToken("sbs") == true)
    }

    @Test func containsStandaloneTokenFindsNumericTokenWithBoundedNeighbors() {
        #expect("1080p".containsStandaloneToken("1080") == false)
        #expect("movie1080p".containsStandaloneToken("1080") == false)
        #expect("1080.p".containsStandaloneToken("1080") == true)
    }
}
