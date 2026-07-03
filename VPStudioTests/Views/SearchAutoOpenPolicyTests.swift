import Testing
@testable import VPStudio

@Suite("Search Auto Open Policy")
struct SearchAutoOpenPolicyTests {
    @Test func selectsPreferredTitleMatchCaseInsensitively() {
        let results = [
            Self.preview(id: "movie-1", title: "Arrival"),
            Self.preview(id: "movie-2", title: "Dune Part Two"),
            Self.preview(id: "movie-3", title: "Blade Runner 2049"),
        ]

        let selected = SearchAutoOpenPolicy.selectedResult(
            from: results,
            preferredTitle: "  dune  "
        )

        #expect(selected?.id == "movie-2")
    }

    @Test func fallsBackToFirstResultWhenPreferredTitleIsMissingBlankOrUnmatched() {
        let results = [
            Self.preview(id: "movie-1", title: "Arrival"),
            Self.preview(id: "movie-2", title: "Dune Part Two"),
        ]

        #expect(SearchAutoOpenPolicy.selectedResult(from: results, preferredTitle: nil)?.id == "movie-1")
        #expect(SearchAutoOpenPolicy.selectedResult(from: results, preferredTitle: " \n ")?.id == "movie-1")
        #expect(SearchAutoOpenPolicy.selectedResult(from: results, preferredTitle: "Interstellar")?.id == "movie-1")
    }

    @Test func returnsNilWhenThereAreNoResults() {
        #expect(SearchAutoOpenPolicy.selectedResult(from: [], preferredTitle: "Dune") == nil)
    }

    private static func preview(id: String, title: String) -> MediaPreview {
        MediaPreview(
            id: id,
            type: .movie,
            title: title,
            year: 2024,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: nil,
            tmdbId: nil
        )
    }
}
