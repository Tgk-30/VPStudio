import Foundation
import Testing
@testable import VPStudio

// MARK: - EnvironmentSuggestion value type

@Suite("EnvironmentSuggestion")
struct EnvironmentSuggestionTests {
    @Test func propertiesAndEquatable() {
        let a = EnvironmentSuggestion(matchKey: "horror", displayName: "Horror", fallbackPresetID: "p")
        let b = EnvironmentSuggestion(matchKey: "horror", displayName: "Horror", fallbackPresetID: "p")
        let c = EnvironmentSuggestion(matchKey: "scifi", displayName: "Sci-Fi")
        #expect(a == b)
        #expect(a != c)
        #expect(a.matchKey == "horror")
        #expect(c.fallbackPresetID == nil)
    }
}

// MARK: - TMDB id lookups

@Suite("GenreEnvironmentSuggestionPolicy id lookups")
struct GenreEnvironmentSuggestionPolicyIdTests {

    @Test func movieGenreIdsMapToExpectedMoods() {
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreId: 27) == GenreEnvironmentSuggestionPolicy.horror)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreId: 878) == GenreEnvironmentSuggestionPolicy.scifi)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreId: 16) == GenreEnvironmentSuggestionPolicy.animation)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreId: 99) == GenreEnvironmentSuggestionPolicy.docs)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreId: 10749) == GenreEnvironmentSuggestionPolicy.chill)
    }

    @Test func tvGenreIdsMapToExpectedMoods() {
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forTVGenreId: 10765) == GenreEnvironmentSuggestionPolicy.scifi)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forTVGenreId: 16) == GenreEnvironmentSuggestionPolicy.animation)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forTVGenreId: 99) == GenreEnvironmentSuggestionPolicy.docs)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forTVGenreId: 10759) == GenreEnvironmentSuggestionPolicy.action)
    }

    @Test func unknownGenreIdReturnsNil() {
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreId: 999_999) == nil)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forTVGenreId: 999_999) == nil)
    }

    @Test func specialNegativeGenreIdsReturnNil() {
        // -1 (New Releases) and -2 (Coming Soon) are special cards, not real genres.
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreId: -1) == nil)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreId: -2) == nil)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forTVGenreId: -1) == nil)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forTVGenreId: -2) == nil)
    }

    @Test func firstMatchingIdInListWins() {
        // Unknown id, then horror.
        let match = GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreIds: [999_999, 27, 878])
        #expect(match == GenreEnvironmentSuggestionPolicy.horror)
    }

    @Test func listOfUnknownIdsReturnsNil() {
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreIds: [111_111, 222_222]) == nil)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forTVGenreIds: []) == nil)
    }
}

// MARK: - Human name lookups

@Suite("GenreEnvironmentSuggestionPolicy name lookups")
struct GenreEnvironmentSuggestionPolicyNameTests {

    @Test func canonicalNamesMapToMoods() {
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["Science Fiction"]) == GenreEnvironmentSuggestionPolicy.scifi)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["Horror"]) == GenreEnvironmentSuggestionPolicy.horror)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["Documentary"]) == GenreEnvironmentSuggestionPolicy.docs)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["Animation"]) == GenreEnvironmentSuggestionPolicy.animation)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["Romance"]) == GenreEnvironmentSuggestionPolicy.chill)
    }

    @Test func nameLookupIsCaseAndWhitespaceInsensitive() {
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["SCIENCE FICTION"]) == GenreEnvironmentSuggestionPolicy.scifi)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["  science   fiction "]) == GenreEnvironmentSuggestionPolicy.scifi)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["hOrRoR"]) == GenreEnvironmentSuggestionPolicy.horror)
    }

    @Test func firstRecognizedNameInListWins() {
        // "Deep" is not a real genre name -> skipped; "Horror" is recognized.
        let match = GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["Deep", "Horror"])
        #expect(match == GenreEnvironmentSuggestionPolicy.horror)
    }

    @Test func unrecognizedButPresentNamesYieldNeutralDefault() {
        let match = GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["Western"])
        #expect(match == GenreEnvironmentSuggestionPolicy.neutralDefault)
        #expect(match?.matchKey == "cinema")
    }

    @Test func emptyOrBlankNameListReturnsNil() {
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: []) == nil)
        #expect(GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: ["   ", ""]) == nil)
    }

    @Test func normalizeCollapsesWhitespaceAndLowercases() {
        #expect(GenreEnvironmentSuggestionPolicy.normalize("  Science   Fiction ") == "science fiction")
        #expect(GenreEnvironmentSuggestionPolicy.normalize("HORROR") == "horror")
    }
}

// MARK: - ExploreGenreCatalog coverage

@Suite("GenreEnvironmentSuggestionPolicy catalog coverage")
struct GenreEnvironmentSuggestionPolicyCatalogTests {

    @Test func everyNonSpecialCatalogCardYieldsNonNilSuggestion() {
        for card in ExploreGenreCatalog.cards where !card.isSpecialCard {
            let byName = GenreEnvironmentSuggestionPolicy.suggestion(forGenreNames: [card.title])
            #expect(byName != nil, "Card \(card.id) (\(card.title)) should yield a non-nil suggestion")
        }
    }

    @Test func specialCatalogCardIdsYieldNilByGenreId() {
        for card in ExploreGenreCatalog.cards where card.isSpecialCard {
            #expect(GenreEnvironmentSuggestionPolicy.suggestion(forMovieGenreId: card.movieGenreId) == nil)
            #expect(GenreEnvironmentSuggestionPolicy.suggestion(forTVGenreId: card.tvGenreId) == nil)
        }
    }

    @Test func neutralDefaultIsStableAndCarriesFallback() {
        let neutral = GenreEnvironmentSuggestionPolicy.neutralDefault
        #expect(neutral.matchKey == "cinema")
        #expect(neutral.fallbackPresetID != nil)
    }
}
