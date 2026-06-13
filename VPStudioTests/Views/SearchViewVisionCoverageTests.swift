#if os(visionOS)
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("SearchView visionOS coverage", .serialized)
struct SearchViewVisionCoverageTests {
    @Test
    func taskHydratesRecentSearchesFromSettingsWithoutRequeryingWhenIdle() async throws {
        let database = try DatabaseManager(inMemoryNamed: "search-view-vision-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, testHooks: .init())
        try await appState.settingsManager.setString(
            key: SettingsKeys.recentSearches,
            value: #"["Arrival","Severance"]"#
        )

        let freshViewModel = SearchViewModel()
        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                SearchView(
                    initialViewModel: freshViewModel,
                    initialSearchDraft: "",
                    disablesAutomaticTasks: false
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 250_000_000)

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
        #expect(freshViewModel.recentSearches == ["Arrival", "Severance"])
    }

    @Test
    func resultsAndScrollChangesDriveVisibleBranches() async throws {
        let appState = AppState(testHooks: .init())
        let viewModel = SearchViewModel()
        let genre = Genre(id: 878, name: "Science Fiction")
        let firstResult = Fixtures.mediaPreview(
            id: "movie-1",
            type: .movie,
            title: "Arrival",
            year: 2016,
            tmdbId: 1
        )
        let secondResult = Fixtures.mediaPreview(
            id: "movie-2",
            type: .movie,
            title: "Dune Part Two",
            year: 2024,
            tmdbId: 2
        )

        let hosted = try hostInVisibleVisionWindow(
            NavigationStack {
                SearchView(
                    initialViewModel: viewModel,
                    initialSearchDraft: "",
                    disablesAutomaticTasks: true
                )
            }
            .environment(appState)
            .frame(width: 980, height: 820)
        )
        defer { tearDownVisionWindow(hosted.window) }

        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 120_000_000)

        viewModel.results = [firstResult]
        try await Task.sleep(nanoseconds: 80_000_000)

        viewModel.results = [firstResult, secondResult]
        viewModel.scrollToTopTrigger += 1
        viewModel.selectedGenre = genre
        viewModel.sortOption = .ratingDesc
        viewModel.languageFilters = ["fr-FR"]
        viewModel.yearRangePreset = .classic
        viewModel.isLoadingAI = true
        viewModel.aiError = "No provider is configured for search recommendations."
        viewModel.aiRecommendations = [
            AIMovieRecommendation(
                title: "Arrival",
                year: 2016,
                type: .movie,
                reason: "Matches the current science-fiction lane.",
                tmdbId: 1,
                score: 0.94
            ),
        ]
        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(hosted.host.view.bounds.width > 0)
        #expect(viewModel.explorePhase == .results)
        #expect(viewModel.hasActiveFilters)
    }

    @Test
    func loadingEmptyErrorAndRefreshingStatesHostWithoutNetwork() async throws {
        let database = try DatabaseManager(inMemoryNamed: "search-view-states-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, testHooks: .init())
        let genre = Genre(id: 53, name: "Thriller")
        let retainedResult = Fixtures.mediaPreview(
            id: "movie-retained",
            type: .movie,
            title: "Heat",
            year: 1995,
            tmdbId: 949
        )

        let variants: [(String, SearchViewModel)] = [
            ("blocking skeleton", Self.searchViewModel { model in
                model.isSearching = true
            }),
            ("refreshing retained results", Self.searchViewModel { model in
                model.results = [retainedResult]
                model.aiRecommendations = [Self.recommendation(title: "Collateral", tmdbId: 1538)]
                model.isSearching = true
            }),
            ("empty genre state", Self.searchViewModel { model in
                model.selectedGenre = genre
            }),
            ("error state", Self.searchViewModel { model in
                model.error = .tmdbSetupRequired(feature: "Search")
            }),
        ]

        for (name, viewModel) in variants {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack {
                    SearchView(
                        initialViewModel: viewModel,
                        initialSearchDraft: "",
                        disablesAutomaticTasks: true
                    )
                }
                .environment(appState)
                .frame(width: 980, height: 820)
            )
            let window = hosted.window

            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 140_000_000)

            #expect(hosted.host.view.bounds.width == 980, "\(name) should lay out in the hosted window")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should render a SwiftUI subtree")
            tearDownVisionWindow(window)
        }
    }

    private static func searchViewModel(
        configure: (SearchViewModel) -> Void
    ) -> SearchViewModel {
        let model = SearchViewModel()
        configure(model)
        return model
    }

    private static func recommendation(
        title: String,
        tmdbId: Int
    ) -> AIMovieRecommendation {
        AIMovieRecommendation(
            title: title,
            year: 2004,
            type: .movie,
            reason: "Keeps the visible AI recommendation rail populated.",
            tmdbId: tmdbId,
            score: 0.87
        )
    }
}

@MainActor
private func hostInVisibleVisionWindow<Content: View>(
    _ rootView: Content
) throws -> (host: UIHostingController<AnyView>, window: UIWindow) {
    let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )

    let host = UIHostingController(rootView: AnyView(rootView))
    host.view.backgroundColor = .clear
    let window = UIWindow(windowScene: scene)
    window.rootViewController = host
    window.frame = CGRect(x: 0, y: 0, width: 980, height: 820)
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return (host, window)
}

@MainActor
private func tearDownVisionWindow(_ window: UIWindow) {
    window.endEditing(true)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.10))
    window.isUserInteractionEnabled = false
    window.resignKey()
    window.frame = CGRect(x: -10_000, y: -10_000, width: 1, height: 1)
    window.isHidden = true
    window.rootViewController = nil
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
}
#endif
