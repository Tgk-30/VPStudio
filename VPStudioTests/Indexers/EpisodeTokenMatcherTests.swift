import Testing
import Foundation
@testable import VPStudio

@Suite("EpisodeTokenMatcher")
struct EpisodeTokenMatcherTests {

    @Test func contextFromQueryParsesSEFormat() {
        let context = EpisodeTokenMatcher.context(fromQuery: "The.Show.S02E05.1080p")
        #expect(context?.season == 2)
        #expect(context?.episode == 5)
    }

    @Test func contextFromQueryParsesLowercaseSE() {
        let context = EpisodeTokenMatcher.context(fromQuery: "the.show.s12e99.webdl")
        #expect(context?.season == 12)
        #expect(context?.episode == 99)
    }

    @Test func contextFromQueryParsesXFormat() {
        let context = EpisodeTokenMatcher.context(fromQuery: "Show.Name.3x04.HDTV")
        #expect(context?.season == 3)
        #expect(context?.episode == 4)
    }

    @Test func contextFromQueryParsesWordFormat() {
        let context = EpisodeTokenMatcher.context(fromQuery: "Show Name Season 1 Episode 7")
        #expect(context?.season == 1)
        #expect(context?.episode == 7)
    }

    @Test func contextFromQueryReturnsNilForNoMatch() {
        let context = EpisodeTokenMatcher.context(fromQuery: "A.Movie.2024.1080p")
        #expect(context == nil)
    }

    @Test func contextFromQueryReturnsNilForEmptyString() {
        let context = EpisodeTokenMatcher.context(fromQuery: "")
        #expect(context == nil)
    }

    @Test func matchesReturnsTrueForExactMatch() {
        #expect(EpisodeTokenMatcher.matches(title: "Show.S01E05", season: 1, episode: 5))
    }

    @Test func matchesReturnsFalseForWrongSeason() {
        #expect(!EpisodeTokenMatcher.matches(title: "Show.S01E05", season: 2, episode: 5))
    }

    @Test func matchesReturnsFalseForWrongEpisode() {
        #expect(!EpisodeTokenMatcher.matches(title: "Show.S01E05", season: 1, episode: 6))
    }

    @Test func matchesReturnsFalseForNoTokens() {
        #expect(!EpisodeTokenMatcher.matches(title: "A.Movie.2024", season: 1, episode: 1))
    }

    @Test func matchesIfPresentReturnsTrueWhenNoTokens() {
        #expect(EpisodeTokenMatcher.matchesIfPresent(title: "A.Movie.2024", season: 1, episode: 1))
    }

    @Test func matchesIfPresentReturnsTrueForExactMatch() {
        #expect(EpisodeTokenMatcher.matchesIfPresent(title: "Show.S01E05", season: 1, episode: 5))
    }

    @Test func matchesIfPresentReturnsFalseForMismatch() {
        #expect(!EpisodeTokenMatcher.matchesIfPresent(title: "Show.S01E05", season: 2, episode: 5))
    }

    @Test func handlesSingleDigitSeason() {
        let context = EpisodeTokenMatcher.context(fromQuery: "S1E1")
        #expect(context?.season == 1)
        #expect(context?.episode == 1)
    }

    @Test func handlesDoubleDigitSeason() {
        let context = EpisodeTokenMatcher.context(fromQuery: "S99E123")
        #expect(context?.season == 99)
        #expect(context?.episode == 123)
    }

    @Test func doesNotMatchStandaloneNumbersAsSeasonEpisode() {
        // "1080p" should not be parsed as season 10 episode 80
        let context = EpisodeTokenMatcher.context(fromQuery: "Movie.1080p.BluRay")
        #expect(context == nil)
    }
}
