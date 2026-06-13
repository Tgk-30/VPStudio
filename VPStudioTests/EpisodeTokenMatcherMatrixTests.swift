import Foundation
import Testing
@testable import VPStudio

@Suite("Episode Token Matcher Matrix")
struct EpisodeTokenMatcherMatrixTests {
    struct ContextCase: Sendable {
        let query: String
        let expected: EpisodeTokenMatcher.Context?
    }

    struct MatchCase: Sendable {
        let title: String
        let season: Int
        let episode: Int
        let expected: Bool
    }

    private static let contextCases: [ContextCase] = {
        var cases: [ContextCase] = []
        for season in 1...10 {
            for episode in 1...7 {
                cases.append(ContextCase(query: "Show S\(season)E\(episode)", expected: .init(season: season, episode: episode)))
            }
        }
        while cases.count < 70 {
            let idx = cases.count
            let query = idx % 2 == 0 ? "Show \(idx)x\(idx + 1)" : "No episode token \(idx)"
            let expected: EpisodeTokenMatcher.Context? = idx % 2 == 0 ? .init(season: idx, episode: idx + 1) : nil
            cases.append(ContextCase(query: query, expected: expected))
        }
        return Array(cases.prefix(70))
    }()

    private static let matchCases: [MatchCase] = {
        var cases: [MatchCase] = []
        for season in 1...10 {
            for episode in 1...7 {
                cases.append(MatchCase(title: "Series.Name.S\(String(format: "%02d", season))E\(String(format: "%02d", episode)).1080p", season: season, episode: episode, expected: true))
            }
        }
        return Array(cases.prefix(70))
    }()

    @Test(arguments: ExhaustiveMode.choose(fast: Array(contextCases.prefix(20)), full: contextCases))
    func contextExtractionMatrix(data: ContextCase) {
        let context = EpisodeTokenMatcher.context(fromQuery: data.query)
        #expect(context == data.expected)
    }

    @Test(arguments: ExhaustiveMode.choose(fast: Array(matchCases.prefix(20)), full: matchCases))
    func matchMatrix(data: MatchCase) {
        let result = EpisodeTokenMatcher.matches(
            title: data.title,
            season: data.season,
            episode: data.episode
        )
        #expect(result == data.expected)

        let mismatch = EpisodeTokenMatcher.matches(
            title: data.title,
            season: data.season,
            episode: data.episode + 1
        )
        #expect(mismatch == false)
    }

    @Test func matchesIfPresentAllowsUntokenizedTitle() {
        #expect(EpisodeTokenMatcher.matches(title: "Series Name 1080p", season: 1, episode: 2) == false)
        #expect(EpisodeTokenMatcher.matchesIfPresent(title: "Series Name 1080p", season: 1, episode: 2))
    }

    @Test func matchesIfPresentRejectsMismatchedTokenizedTitle() {
        #expect(EpisodeTokenMatcher.matchesIfPresent(title: "Series.Name.S01E03.1080p", season: 1, episode: 2) == false)
    }

    @Test func nxnResolutionStringDoesNotParseAsEpisodeContext() {
        #expect(EpisodeTokenMatcher.context(fromQuery: "Some.Show.1920x1080.REMUX") == nil)
        #expect(EpisodeTokenMatcher.matches(title: "Some.Show.1920x1080.REMUX", season: 19, episode: 20) == false)
    }

    @Test func nxnEpisodeStringStillParses() {
        #expect(EpisodeTokenMatcher.context(fromQuery: "Some.Show.1x02.WEBRip") == .init(season: 1, episode: 2))
        #expect(EpisodeTokenMatcher.matches(title: "Some.Show.1x02.WEBRip", season: 1, episode: 2))
    }

    @Test func episodeWordsPatternParsesSeasonAndEpisodeContext() {
        #expect(EpisodeTokenMatcher.context(fromQuery: "Some Show Season 2 Episode 11") == .init(season: 2, episode: 11))
        #expect(EpisodeTokenMatcher.matches(title: "Some Show Season 2 Episode 11", season: 2, episode: 11))
    }

    @Test func episodeWordsPatternRejectsInvalidEpisodeLength() {
        #expect(EpisodeTokenMatcher.context(fromQuery: "Some Show Season 2 Episode 1234") == nil)
        #expect(EpisodeTokenMatcher.matches(title: "Some Show Season 2 Episode 1234", season: 2, episode: 1234) == false)
    }

    @Test func seasonEpisodePatternRejectsInvalidEpisodeLength() {
        #expect(EpisodeTokenMatcher.context(fromQuery: "Show S02E1234") == nil)
        #expect(EpisodeTokenMatcher.matches(title: "Show S02E1234", season: 2, episode: 1234) == false)
    }

    @Test func episodeWordsPatternIsCaseInsensitive() {
        #expect(EpisodeTokenMatcher.context(fromQuery: "some show season 03 episode 05") == .init(season: 3, episode: 5))
        #expect(EpisodeTokenMatcher.matches(title: "some show SEASON 03 EPISODE 05", season: 3, episode: 5))
    }

    @Test func seasonEpisodePatternRejectsInvalidSeasonLength() {
        #expect(EpisodeTokenMatcher.context(fromQuery: "Show S123E05") == nil)
        #expect(EpisodeTokenMatcher.matches(title: "Show S123E05", season: 123, episode: 5) == false)
    }

    @Test func episodeWordsPatternRejectsInvalidSeasonLength() {
        #expect(EpisodeTokenMatcher.context(fromQuery: "Some Show Season 123 Episode 05") == nil)
        #expect(EpisodeTokenMatcher.matches(title: "Some Show Season 123 Episode 05", season: 123, episode: 5) == false)
    }

    @Test func episodeWordsPatternRespectsGapBoundary() {
        let withinLimit = "Show Season 02" + String(repeating: "x", count: 20) + "Episode 08"
        #expect(EpisodeTokenMatcher.context(fromQuery: withinLimit) == .init(season: 2, episode: 8))

        let overLimit = "Show Season 02" + String(repeating: "x", count: 21) + "Episode 08"
        #expect(EpisodeTokenMatcher.context(fromQuery: overLimit) == nil)
    }

    @Test func episodeWordsPatternRejectsReversedWordOrder() {
        #expect(EpisodeTokenMatcher.context(fromQuery: "Show Episode 08 Season 02") == nil)
        #expect(EpisodeTokenMatcher.matches(title: "Show Episode 08 Season 02", season: 2, episode: 8) == false)
    }

    @Test func seasonEpisodePatternParsesUnpaddedValuesAndExtraWhitespace() {
        #expect(EpisodeTokenMatcher.context(fromQuery: "Show s 1 e 2") == .init(season: 1, episode: 2))
        #expect(EpisodeTokenMatcher.matches(title: "Show s 1 e 2", season: 1, episode: 2))
    }
}
