import Testing
@testable import VPStudio

@Suite(.serialized)
struct SearchViewModelBranchCoverageTests {
    @Test
    @MainActor
    func activeFilterCountTracksOnlyNonDefaultDimensions() {
        let viewModel = SearchViewModel()

        #expect(viewModel.activeFilterCount == 0)
        #expect(viewModel.hasActiveFilters == false)

        viewModel.sortOption = .ratingDesc
        viewModel.yearFilter = 2010
        viewModel.yearRangePreset = .tens
        viewModel.languageFilters = ["fr-FR"]
        viewModel.selectedGenre = Genre(id: 18, name: "Drama")

        #expect(viewModel.activeFilterCount == 4)
        #expect(viewModel.hasActiveFilters)

        viewModel.languageFilters = ["en-US"]
        #expect(viewModel.activeFilterCount == 3)
    }

    @Test
    @MainActor
    func emptyStateQueryPrefersSubmittedTextOverGenreAndMoodCard() {
        let viewModel = SearchViewModel()
        let moodCard = ExploreGenreCatalog.cards.first(where: { $0.id == "new" })!

        viewModel.selectMoodCard(moodCard)
        viewModel.selectedGenre = Genre(id: 28, name: "Action")
        viewModel.query = "  Dune Part Two  "
        viewModel.search()

        #expect(viewModel.submittedQuery == "Dune Part Two")
        #expect(viewModel.emptyStateQuery == "Dune Part Two")
    }

    @Test
    @MainActor
    func applyYearRangePresetSetsLowerBoundAndTogglesOffWhenRepeated() {
        let viewModel = SearchViewModel()

        viewModel.applyYearRangePreset(.classic)
        #expect(viewModel.yearRangePreset == .classic)
        #expect(viewModel.yearFilter == 1900)

        viewModel.applyYearRangePreset(.classic)
        #expect(viewModel.yearRangePreset == nil)
        #expect(viewModel.yearFilter == nil)
    }

    @Test
    @MainActor
    func remapGenreMatchesByIdFirst() {
        let candidates = [
            Genre(id: 28, name: "Action"),
            Genre(id: 35, name: "Comedy"),
        ]

        let remapped = SearchViewModel.remapGenre(Genre(id: 28, name: "Drama"), in: candidates)

        #expect(remapped?.id == 28)
        #expect(remapped?.name == "Action")
    }

    @Test
    @MainActor
    func remapGenreFallsBackToCaseInsensitiveNameMatch() {
        let candidates = [
            Genre(id: 28, name: "Action"),
            Genre(id: 35, name: "Comedy"),
        ]

        let remapped = SearchViewModel.remapGenre(Genre(id: 99, name: "comedy"), in: candidates)

        #expect(remapped?.id == 35)
        #expect(remapped?.name == "Comedy")
    }

    @Test
    @MainActor
    func remapGenreReturnsNilWhenNoMatch() {
        let candidates = [Genre(id: 28, name: "Action")]

        let remapped = SearchViewModel.remapGenre(Genre(id: 99, name: "Sci-Fi"), in: candidates)

        #expect(remapped == nil)
    }

    @Test
    @MainActor
    func yearRangePresetMetadataReflectsRangeDefinitions() {
        let recent = YearRangePreset.recent
        #expect(recent.displayName == "2024-2026")
        #expect(recent.yearRange == 2024...2026)
        #expect(recent.filterYear == nil)
        #expect(recent.contains(year: 2024))
        #expect(!recent.contains(year: 2023))

        let twenties = YearRangePreset.twenties
        #expect(twenties.displayName == "2020s")
        #expect(twenties.yearRange == 2020...2029)
        #expect(twenties.filterYear == 2020)

        let tens = YearRangePreset.tens
        #expect(tens.displayName == "2010s")
        #expect(tens.yearRange == 2010...2019)
        #expect(tens.filterYear == 2010)

        let classic = YearRangePreset.classic
        #expect(classic.displayName == "Classic")
        #expect(classic.yearRange == 1900...1999)
        #expect(classic.filterYear == 1900)
    }

    @Test
    @MainActor
    func toggleLanguageTransitionsBetweenDefaultExplicitAndEmptySelections() {
        let viewModel = SearchViewModel()

        viewModel.toggleLanguage("fr-FR")
        #expect(viewModel.languageFilters == ["fr-FR"])
        #expect(viewModel.primaryLanguage == "fr-FR")

        viewModel.toggleLanguage("de-DE")
        #expect(viewModel.languageFilters == ["de-DE", "fr-FR"])

        viewModel.toggleLanguage("fr-FR")
        #expect(viewModel.languageFilters == ["de-DE"])
        #expect(viewModel.primaryLanguage == "de-DE")

        viewModel.toggleLanguage("de-DE")
        #expect(viewModel.languageFilters == ["en-US"])
        #expect(viewModel.primaryLanguage == nil)

        viewModel.toggleLanguage("en-US")
        #expect(viewModel.languageFilters.isEmpty)

        viewModel.toggleLanguage("en-US")
        #expect(viewModel.languageFilters == ["en-US"])
    }

    @Test
    @MainActor
    func shouldTriggerPaginationOnlyForTrailingResultsWhenMorePagesRemain() {
        let viewModel = SearchViewModel()
        viewModel.results = (0..<7).map { index in
            MediaPreview(id: "item-\(index)", type: .movie, title: "Item \(index)")
        }
        viewModel.currentPage = 1
        viewModel.totalPages = 3

        #expect(viewModel.shouldTriggerPagination(for: "item-1") == false)
        #expect(viewModel.shouldTriggerPagination(for: "item-2"))
        #expect(viewModel.shouldTriggerPagination(for: "item-6"))

        viewModel.currentPage = 3
        #expect(viewModel.shouldTriggerPagination(for: "item-6") == false)
    }

    @Test
    @MainActor
    func shouldTriggerPaginationReturnsFalseWhenNoFurtherPagesExist() {
        let viewModel = SearchViewModel()
        viewModel.results = (0..<7).map { index in
            MediaPreview(id: "item-\(index)", type: .movie, title: "Item \(index)")
        }
        viewModel.currentPage = 3
        viewModel.totalPages = 3

        #expect(viewModel.shouldTriggerPagination(for: "item-6") == false)
        #expect(viewModel.shouldTriggerPagination(for: "item-3") == false)
    }

    @Test
    @MainActor
    func shouldTriggerPaginationReturnsFalseForMissingItemID() {
        let viewModel = SearchViewModel()
        viewModel.results = (0..<7).map { index in
            MediaPreview(id: "item-\(index)", type: .movie, title: "Item \(index)")
        }
        viewModel.currentPage = 1
        viewModel.totalPages = 4

        #expect(viewModel.shouldTriggerPagination(for: "item-999") == false)
    }

    @Test
    @MainActor
    func shouldTriggerPaginationReturnsFalseForEmptyResultList() {
        let viewModel = SearchViewModel()
        viewModel.currentPage = 1
        viewModel.totalPages = 4

        #expect(viewModel.shouldTriggerPagination(for: "item-0") == false)
    }

    @Test
    @MainActor
    func searchFilterDraftInfersRecentPresetForInRangeYears() {
        let draft = SearchFilterDraft(
            sortOption: .popularityDesc,
            selectedYear: 2025,
            selectedLanguages: ["en-US"],
            selectedGenre: nil
        )

        #expect(draft.inferredYearRangePreset == .recent)

        let boundaryInside = SearchFilterDraft(
            sortOption: .popularityDesc,
            selectedYear: 2024,
            selectedLanguages: ["en-US"],
            selectedGenre: nil
        )
        #expect(boundaryInside.inferredYearRangePreset == .recent)

        let boundaryOutside = SearchFilterDraft(
            sortOption: .popularityDesc,
            selectedYear: 2027,
            selectedLanguages: ["en-US"],
            selectedGenre: nil
        )
        #expect(boundaryOutside.inferredYearRangePreset == nil)
    }

    @Test
    @MainActor
    func yearRangePresetRecentCanBeToggledOffByRepeatedApply() {
        let viewModel = SearchViewModel()

        viewModel.applyYearRangePreset(.recent)
        #expect(viewModel.yearRangePreset == .recent)
        #expect(viewModel.yearFilter == nil)

        viewModel.applyYearRangePreset(.recent)
        #expect(viewModel.yearRangePreset == nil)
        #expect(viewModel.yearFilter == nil)
    }
}
