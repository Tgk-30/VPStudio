import Testing
@testable import VPStudio

@Suite("Search Shell Copy Policy")
struct SearchShellCopyPolicyTests {
    @Test
    func titleUsesCatalogCopyForResultsPhaseOrSubmittedQuery() {
        #expect(
            SearchShellCopyPolicy.title(
                explorePhase: .results,
                submittedQuery: "",
                hasSelectedGenre: false,
                hasActiveMoodCard: false
            ) == "Search the catalog"
        )

        #expect(
            SearchShellCopyPolicy.title(
                explorePhase: .idle,
                submittedQuery: "dune",
                hasSelectedGenre: false,
                hasActiveMoodCard: false
            ) == "Search the catalog"
        )
    }

    @Test
    func titleUsesLaneCopyForGenreOrMoodBrowseContext() {
        #expect(
            SearchShellCopyPolicy.title(
                explorePhase: .idle,
                submittedQuery: "",
                hasSelectedGenre: true,
                hasActiveMoodCard: false
            ) == "Hold the lane"
        )

        #expect(
            SearchShellCopyPolicy.title(
                explorePhase: .idle,
                submittedQuery: "",
                hasSelectedGenre: false,
                hasActiveMoodCard: true
            ) == "Hold the lane"
        )
    }

    @Test
    func titleUsesIdleCopyWhenNoSearchOrBrowseContextExists() {
        #expect(
            SearchShellCopyPolicy.title(
                explorePhase: .idle,
                submittedQuery: "",
                hasSelectedGenre: false,
                hasActiveMoodCard: false
            ) == "Find the next frame"
        )
    }

    @Test
    func subtitlePrefersMoodCardThenGenreThenSubmittedQueryThenDefault() {
        #expect(
            SearchShellCopyPolicy.subtitle(
                activeMoodCardTitle: "Comfort",
                selectedGenreName: "Horror",
                submittedQuery: "alien"
            ) == "You are already inside comfort picks. Tighten the lane with search and filters without losing the browse context."
        )

        #expect(
            SearchShellCopyPolicy.subtitle(
                activeMoodCardTitle: nil,
                selectedGenreName: "Science Fiction",
                submittedQuery: "alien"
            ) == "You are browsing science fiction picks. Search can get precise while the editorial browse lane stays open."
        )

        #expect(
            SearchShellCopyPolicy.subtitle(
                activeMoodCardTitle: nil,
                selectedGenreName: nil,
                submittedQuery: "alien"
            ) == "Tighten the query, switch type, or add filters."
        )

        #expect(
            SearchShellCopyPolicy.subtitle(
                activeMoodCardTitle: nil,
                selectedGenreName: nil,
                submittedQuery: ""
            ) == "Search a title, actor, or keyword — or let AI pick for you."
        )
    }
}

@Suite("Search Results Presentation Policy")
struct SearchResultsPresentationPolicyTests {
    @Test
    func typeFilterSectionAppearsForCommittedSearchBrowseContextResultsOrFilters() {
        #expect(!SearchResultsPresentationPolicy.shouldShowTypeFilterSection(
            submittedQuery: "",
            hasSelectedGenre: false,
            hasActiveMoodCard: false,
            explorePhase: .idle,
            hasActiveFilters: false
        ))

        #expect(SearchResultsPresentationPolicy.shouldShowTypeFilterSection(
            submittedQuery: "dune",
            hasSelectedGenre: false,
            hasActiveMoodCard: false,
            explorePhase: .idle,
            hasActiveFilters: false
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowTypeFilterSection(
            submittedQuery: "",
            hasSelectedGenre: true,
            hasActiveMoodCard: false,
            explorePhase: .idle,
            hasActiveFilters: false
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowTypeFilterSection(
            submittedQuery: "",
            hasSelectedGenre: false,
            hasActiveMoodCard: true,
            explorePhase: .idle,
            hasActiveFilters: false
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowTypeFilterSection(
            submittedQuery: "",
            hasSelectedGenre: false,
            hasActiveMoodCard: false,
            explorePhase: .results,
            hasActiveFilters: false
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowTypeFilterSection(
            submittedQuery: "",
            hasSelectedGenre: false,
            hasActiveMoodCard: false,
            explorePhase: .idle,
            hasActiveFilters: true
        ))
    }

    @Test
    func compactAndResultsFilterSummariesUseNonDefaultFilters() {
        #expect(!SearchResultsPresentationPolicy.shouldShowFilterSummary(
            hasActiveMoodCard: false,
            hasSelectedGenre: false,
            sortOption: .popularityDesc,
            languageFilters: ["en-US"],
            yearFilter: nil,
            yearRangePreset: nil
        ))

        #expect(SearchResultsPresentationPolicy.shouldShowFilterSummary(
            hasActiveMoodCard: true,
            hasSelectedGenre: false,
            sortOption: .popularityDesc,
            languageFilters: ["en-US"],
            yearFilter: nil,
            yearRangePreset: nil
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowFilterSummary(
            hasActiveMoodCard: false,
            hasSelectedGenre: true,
            sortOption: .popularityDesc,
            languageFilters: ["en-US"],
            yearFilter: nil,
            yearRangePreset: nil
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowFilterSummary(
            hasActiveMoodCard: false,
            hasSelectedGenre: false,
            sortOption: .ratingDesc,
            languageFilters: ["en-US"],
            yearFilter: nil,
            yearRangePreset: nil
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowFilterSummary(
            hasActiveMoodCard: false,
            hasSelectedGenre: false,
            sortOption: .popularityDesc,
            languageFilters: ["ja-JP"],
            yearFilter: nil,
            yearRangePreset: nil
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowFilterSummary(
            hasActiveMoodCard: false,
            hasSelectedGenre: false,
            sortOption: .popularityDesc,
            languageFilters: ["en-US"],
            yearFilter: 1999,
            yearRangePreset: nil
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowFilterSummary(
            hasActiveMoodCard: false,
            hasSelectedGenre: false,
            sortOption: .popularityDesc,
            languageFilters: ["en-US"],
            yearFilter: nil,
            yearRangePreset: .classic
        ))

        #expect(!SearchResultsPresentationPolicy.shouldShowResultsFilterSummary(
            hasSelectedGenre: false,
            sortOption: .popularityDesc,
            languageFilters: [],
            yearFilter: nil,
            yearRangePreset: nil
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowResultsFilterSummary(
            hasSelectedGenre: true,
            sortOption: .popularityDesc,
            languageFilters: ["en-US"],
            yearFilter: nil,
            yearRangePreset: nil
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowResultsFilterSummary(
            hasSelectedGenre: false,
            sortOption: .ratingDesc,
            languageFilters: ["en-US"],
            yearFilter: nil,
            yearRangePreset: nil
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowResultsFilterSummary(
            hasSelectedGenre: false,
            sortOption: .popularityDesc,
            languageFilters: ["fr-FR"],
            yearFilter: nil,
            yearRangePreset: nil
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowResultsFilterSummary(
            hasSelectedGenre: false,
            sortOption: .popularityDesc,
            languageFilters: ["en-US"],
            yearFilter: 1982,
            yearRangePreset: nil
        ))
        #expect(SearchResultsPresentationPolicy.shouldShowResultsFilterSummary(
            hasSelectedGenre: false,
            sortOption: .popularityDesc,
            languageFilters: ["en-US"],
            yearFilter: nil,
            yearRangePreset: .classic
        ))
    }

    @Test
    func resultContextTitleUsesMoodGenreQueryThenBrowseFallback() {
        #expect(SearchResultsPresentationPolicy.resultsContextTitle(
            activeMoodCardTitle: "Comfort",
            selectedGenreName: "Horror",
            submittedQuery: "alien"
        ) == "Comfort")
        #expect(SearchResultsPresentationPolicy.resultsContextTitle(
            activeMoodCardTitle: nil,
            selectedGenreName: "Horror",
            submittedQuery: "alien"
        ) == "Horror")
        #expect(SearchResultsPresentationPolicy.resultsContextTitle(
            activeMoodCardTitle: nil,
            selectedGenreName: nil,
            submittedQuery: "alien"
        ) == "Results for \"alien\"")
        #expect(SearchResultsPresentationPolicy.resultsContextTitle(
            activeMoodCardTitle: nil,
            selectedGenreName: nil,
            submittedQuery: ""
        ) == "Browse Results")
    }

    @Test
    func resultContextSubtitleDistinguishesMoodSpecialsGenreQueryAndBrowse() {
        #expect(SearchResultsPresentationPolicy.resultsContextSubtitle(
            activeMoodCardTitle: "New Releases",
            activeMoodCardIsNewReleases: true,
            activeMoodCardIsFutureReleases: false,
            selectedGenreName: nil,
            submittedQuery: "",
            selectedType: .movie
        ) == "Fresh movies sorted to surface what just landed.")

        #expect(SearchResultsPresentationPolicy.resultsContextSubtitle(
            activeMoodCardTitle: "Coming Soon",
            activeMoodCardIsNewReleases: false,
            activeMoodCardIsFutureReleases: true,
            selectedGenreName: nil,
            submittedQuery: "",
            selectedType: .series
        ) == "Upcoming TV shows worth tracking before release.")

        #expect(SearchResultsPresentationPolicy.resultsContextSubtitle(
            activeMoodCardTitle: "Deep",
            activeMoodCardIsNewReleases: false,
            activeMoodCardIsFutureReleases: false,
            selectedGenreName: nil,
            submittedQuery: "",
            selectedType: nil
        ) == "Mood-led movies and TV shows you can tighten with filters or a direct search.")

        #expect(SearchResultsPresentationPolicy.resultsContextSubtitle(
            activeMoodCardTitle: nil,
            activeMoodCardIsNewReleases: false,
            activeMoodCardIsFutureReleases: false,
            selectedGenreName: "Science Fiction",
            submittedQuery: "",
            selectedType: .movie
        ) == "Popular movies in Science Fiction, ready for deeper filtering.")

        #expect(SearchResultsPresentationPolicy.resultsContextSubtitle(
            activeMoodCardTitle: nil,
            activeMoodCardIsNewReleases: false,
            activeMoodCardIsFutureReleases: false,
            selectedGenreName: nil,
            submittedQuery: "alien",
            selectedType: nil
        ) == "0 results for movies and TV shows.")

        #expect(SearchResultsPresentationPolicy.resultsContextSubtitle(
            activeMoodCardTitle: nil,
            activeMoodCardIsNewReleases: false,
            activeMoodCardIsFutureReleases: false,
            selectedGenreName: nil,
            submittedQuery: "",
            selectedType: nil
        ) == "Browse rails and direct search stay in the same place so you can pivot quickly.")
    }

    @Test
    func emptyStateQueryAndDisplayedSortOptionsStayStable() {
        #expect(SearchResultsPresentationPolicy.emptyStateQuery(from: "  alien  ") == "alien")
        #expect(SearchResultsPresentationPolicy.emptyStateQuery(from: " \n ") == "this selection")
        #expect(SearchResultsPresentationPolicy.displayedSortOptions() == [
            .popularityDesc,
            .ratingDesc,
            .releaseDateDesc,
            .titleAsc,
        ])
    }

    @Test
    func selectedContentDescriptorUsesStableSearchLabels() {
        #expect(SearchResultsPresentationPolicy.selectedContentDescriptor(selectedType: .movie) == "movies")
        #expect(SearchResultsPresentationPolicy.selectedContentDescriptor(selectedType: .series) == "TV shows")
        #expect(SearchResultsPresentationPolicy.selectedContentDescriptor(selectedType: nil) == "movies and TV shows")
    }
}

@Suite("Search Query Bar Policy")
struct SearchQueryBarPolicyTests {
    @Test
    func draftNormalizationDrivesSubmitAndClearState() {
        #expect(SearchQueryBarPolicy.trimmedDraft("  dune \n") == "dune")
        #expect(SearchQueryBarPolicy.canSubmit(localDraft: "  dune "))
        #expect(!SearchQueryBarPolicy.canSubmit(localDraft: " \n "))

        #expect(SearchQueryBarPolicy.showsClearButton(localDraft: " arrival ", submittedQuery: ""))
        #expect(SearchQueryBarPolicy.showsClearButton(localDraft: "", submittedQuery: "arrival"))
        #expect(!SearchQueryBarPolicy.showsClearButton(localDraft: " \n ", submittedQuery: ""))
    }
}

@Suite("Search Language Option Policy")
struct SearchLanguageOptionPolicyTests {
    @Test
    func activeOptionsIgnoreDefaultOnlyAndUnknownOnlySelections() {
        #expect(SearchLanguageOption.activeOptions(for: ["en-US"]).isEmpty)
        #expect(SearchLanguageOption.activeOptions(for: ["xx-ZZ"]).isEmpty)
    }

    @Test
    func activeOptionsFollowCommonOrderAfterNormalization() {
        let activeOptions = SearchLanguageOption.activeOptions(for: ["xx-ZZ", "fr-FR", "en-US", "ja-JP"])
        #expect(activeOptions.map(\.code) == ["en-US", "fr-FR", "ja-JP"])
    }
}
