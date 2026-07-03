import SwiftUI
import Testing
@testable import VPStudio

@MainActor
@Suite("Search State Render Coverage")
struct SearchStateRenderCoverageTests {
    @Test
    func searchViewRendersLoadingEmptyErrorAndRefreshingStatesWithoutAutomaticTasks() {
        let appState = AppState(testHooks: .init())
        let genre = Genre(id: 53, name: "Thriller")
        let retainedResult = Fixtures.mediaPreview(
            id: "search-retained",
            type: .movie,
            title: "Heat",
            year: 1995,
            tmdbId: 949
        )

        let variants: [(String, SearchViewModel)] = [
            ("blocking skeleton", makeSearchViewModel { model in
                model.isSearching = true
            }),
            ("refreshing retained results", makeSearchViewModel { model in
                model.results = [retainedResult]
                model.aiRecommendations = [
                    makeRecommendation(title: "Collateral", year: 2004, type: .movie, tmdbId: 1538, score: 0.87)
                ]
                model.isSearching = true
            }),
            ("empty genre lane", makeSearchViewModel { model in
                model.selectedGenre = genre
            }),
            ("setup error", makeSearchViewModel { model in
                model.error = .metadataSetupRequired(feature: "Search")
            }),
        ]

        for (name, viewModel) in variants {
            let view = NavigationStack {
                SearchView(
                    initialViewModel: viewModel,
                    initialSearchDraft: "",
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)

            SwiftUIViewDiagnosticHost.render(view, width: 980, height: 820)
            #expect(viewModel.explorePhase != .idle, "\(name) should drive a non-idle SearchView branch")
        }
    }

    @Test
    func searchViewRendersResultsFiltersAndAIChromeWithoutAutomaticTasks() async throws {
        let appState = AppState(testHooks: .init())
        let metadataProvider = StubMetadataProvider()
        let seededResults = [
            Fixtures.mediaPreview(id: "search-arrival", type: .movie, title: "Arrival", year: 2016, tmdbId: 329865),
            Fixtures.mediaPreview(id: "search-severance", type: .series, title: "Severance", year: 2022, tmdbId: 95396),
        ]
        await metadataProvider.setSearchResult(MetadataSearchResult(
            items: seededResults,
            page: 1,
            totalPages: 1,
            totalResults: seededResults.count
        ))
        let viewModel = SearchViewModel(metadataService: metadataProvider)
        viewModel.results = seededResults
        viewModel.selectedType = .movie
        viewModel.selectedGenre = Genre(id: 878, name: "Science Fiction")
        viewModel.genres = [
            Genre(id: 878, name: "Science Fiction"),
            Genre(id: 18, name: "Drama"),
        ]
        viewModel.sortOption = .ratingDesc
        viewModel.yearFilter = 2016
        viewModel.yearRangePreset = .tens
        viewModel.languageFilters = ["en-US", "fr-FR"]
        viewModel.isLoadingAI = true
        viewModel.aiError = "AI provider unavailable in render coverage."
        viewModel.aiRecommendations = [
            makeRecommendation(title: "Moon", year: 2009, type: .movie, tmdbId: 17431, score: 0.91),
            makeRecommendation(title: "Devs", year: 2020, type: .series, tmdbId: 81349, score: nil),
        ]

        try await Task.sleep(nanoseconds: 120_000_000)

        let view = NavigationStack {
            SearchView(
                initialViewModel: viewModel,
                initialSearchDraft: "space",
                disablesAutomaticTasks: true
            )
        }
        .environment(appState)
        .frame(width: 980, height: 820)

        SwiftUIViewDiagnosticHost.render(view, width: 980, height: 820)

        #expect(viewModel.explorePhase == .results)
        #expect(viewModel.activeFilterCount == 4)
        #expect(viewModel.hasActiveFilters)
    }

    @Test
    func inlineFilterChipsRenderActiveInactiveAndSymbolBranches() {
        let view = HStack(spacing: 10) {
            InlineFilterChip(
                text: "Movies",
                symbol: "film",
                isActive: true,
                tint: .red
            )
            InlineFilterChip(
                text: "English",
                symbol: nil,
                isActive: false
            )
            InlineFilterChip(
                text: "2020s",
                symbol: "calendar",
                isActive: false,
                tint: .blue
            )
        }
        .frame(width: 420, height: 80)

        SwiftUIViewDiagnosticHost.render(view, width: 460, height: 120)
    }

    private func makeSearchViewModel(
        configure: (SearchViewModel) -> Void
    ) -> SearchViewModel {
        let model = SearchViewModel()
        configure(model)
        return model
    }

    private func makeRecommendation(
        title: String,
        year: Int?,
        type: MediaType,
        tmdbId: Int?,
        score: Double?
    ) -> AIMovieRecommendation {
        AIMovieRecommendation(
            title: title,
            year: year,
            type: type,
            reason: "Render coverage recommendation for the current search lane.",
            tmdbId: tmdbId,
            score: score
        )
    }
}
