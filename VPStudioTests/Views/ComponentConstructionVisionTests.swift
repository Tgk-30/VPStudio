#if os(visionOS)
import SwiftUI
import Testing
import UIKit
@testable import VPStudio

@MainActor
@Suite("Component Construction visionOS", .serialized)
struct ComponentConstructionVisionTests {
    @Test func primaryWindowSurfacesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let movie = makeMediaPreview(id: "vision-discover-movie", title: "Arrival", year: 2016)
        let show = makeMediaPreview(id: "vision-discover-show", type: .series, title: "Severance", year: 2022)
        let discoverViewModel = DiscoverViewModel()
        discoverViewModel.hasPerformedInitialLoad = true
        discoverViewModel.isLoading = false
        discoverViewModel.featuredBackdrops = [movie]
        discoverViewModel.trendingMovies = [movie]
        discoverViewModel.trendingShows = [show]
        discoverViewModel.popularMovies = [movie]
        discoverViewModel.topRatedMovies = [movie]
        discoverViewModel.nowPlayingMovies = [movie]

        let surfaces: [(String, AnyView)] = [
            ("ContentView", AnyView(ContentView().environment(appState))),
            ("SettingsView", AnyView(NavigationStack { SettingsView() }.environment(appState))),
            ("SetupWizardView", AnyView(NavigationStack { SetupWizardView() }.environment(appState))),
            ("SearchView", AnyView(NavigationStack { SearchView() }.environment(appState))),
            ("LibraryView", AnyView(NavigationStack { LibraryView() }.environment(appState))),
            ("DownloadsView", AnyView(NavigationStack { DownloadsView() }.environment(appState))),
            ("DiscoverView", AnyView(NavigationStack { DiscoverView(viewModel: discoverViewModel) }.environment(appState))),
            ("DetailView", AnyView(NavigationStack { DetailView(preview: movie) }.environment(appState))),
        ]

        for (name, surface) in surfaces {
            let hosted = try hostInVisibleVisionWindow(surface.frame(width: 980, height: 820))
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out with a positive width")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out with a positive height")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func contentViewAlternateStatesHostOnVisionOS() throws {
        let movie = makeMediaPreview(id: "vision-content-movie", title: "Arrival", year: 2016)
        let show = makeMediaPreview(id: "vision-content-show", type: .series, title: "Severance", year: 2022)

        func seededDiscoverModel() -> DiscoverViewModel {
            let viewModel = DiscoverViewModel()
            viewModel.hasPerformedInitialLoad = true
            viewModel.isLoading = false
            viewModel.featuredBackdrops = [movie]
            viewModel.trendingMovies = [movie]
            viewModel.trendingShows = [show]
            viewModel.popularMovies = [movie]
            viewModel.topRatedMovies = [movie]
            viewModel.nowPlayingMovies = [movie]
            return viewModel
        }

        let stream = StreamInfo(
            streamURL: URL(string: "https://example.com/vision-content-player.mkv")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Vision.Content.Player.1080p.mkv",
            sizeBytes: 1_024,
            debridService: "fixture"
        )

        let quickStartState = AppState(testHooks: .init())
        quickStartState.isBootstrapping = false
        quickStartState.setupRecommendationNeeded = true
        quickStartState.selectedTab = .discover
        quickStartState.navigationLayout = .bottomTabBar
        quickStartState.activePlayerSession = PlayerSessionRequest(
            stream: stream,
            mediaTitle: "Vision Content Player",
            mediaId: "vision-content-player",
            episodeId: nil
        )
        quickStartState.isMainWindowSuppressedForPlayer = true

        let sidebarState = AppState(testHooks: .init())
        sidebarState.isBootstrapping = false
        sidebarState.selectedTab = .settings
        sidebarState.navigationLayout = .leftSidebar

        let downloadsState = AppState(testHooks: .init())
        downloadsState.isBootstrapping = false
        downloadsState.selectedTab = .downloads
        downloadsState.navigationLayout = .bottomTabBar

        let views: [(String, AppState, ContentView)] = [
            ("Content quick start kills active player", quickStartState, ContentView(
                initialDiscoverViewModel: seededDiscoverModel(),
                initialIsShowingQuickStartPrompt: true,
                initialActiveDownloadCount: 2,
                initialSettingsWarningCount: 3,
                disablesAutomaticTasks: true
            )),
            ("Content sidebar settings", sidebarState, ContentView(
                initialActiveDownloadCount: 0,
                initialSettingsWarningCount: 4,
                disablesAutomaticTasks: true
            )),
            ("Content downloads badges", downloadsState, ContentView(
                initialActiveDownloadCount: 5,
                initialSettingsWarningCount: 0,
                disablesAutomaticTasks: true
            )),
        ]

        for (name, appState, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                view
                    .environment(appState)
                    .frame(width: 980, height: 820)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }

        #expect(quickStartState.activePlayerSession == nil)
        #expect(quickStartState.isMainWindowSuppressedForPlayer == false)
    }

    @Test func searchViewStateSurfacesHostOnVisionOS() async throws {
        let database = try DatabaseManager(inMemoryNamed: "search-state-vision-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())
        let movie = makeMediaPreview(id: "vision-search-movie", title: "Arrival", year: 2016)
        let show = makeMediaPreview(id: "vision-search-show", type: .series, title: "Severance", year: 2022)
        let genre = Genre(id: 878, name: "Science Fiction")

        func stateView(
            _ name: String,
            draft: String = "",
            configure: (SearchViewModel) -> Void
        ) -> (String, AnyView) {
            let viewModel = SearchViewModel()
            configure(viewModel)
            return (
                name,
                AnyView(
                    NavigationStack {
                        SearchView(
                            initialViewModel: viewModel,
                            initialSearchDraft: draft,
                            disablesAutomaticTasks: true
                        )
                    }
                    .environment(appState)
                )
            )
        }

        let views: [(String, AnyView)] = [
            stateView("Search idle with recent searches") { viewModel in
                viewModel.recentSearches = ["Arrival", "Severance"]
            },
            stateView("Search blocking skeleton", draft: "space") { viewModel in
                viewModel.isSearching = true
            },
            stateView("Search empty genre lane") { viewModel in
                viewModel.selectedGenre = genre
            },
            stateView("Search setup error") { viewModel in
                viewModel.error = .tmdbSetupRequired(feature: "Search")
            },
            stateView("Search refreshing retained results", draft: "arrival") { viewModel in
                viewModel.results = [movie]
                viewModel.isSearching = true
            },
            stateView("Search results with filters and AI") { viewModel in
                viewModel.results = [movie, show]
                viewModel.aiRecommendations = [
                    AIMovieRecommendation(
                        title: "Moon",
                        year: 2009,
                        type: .movie,
                        reason: "A focused, cerebral science fiction pick.",
                        tmdbId: 17431,
                        score: 0.92
                    ),
                ]
                viewModel.isLoadingAI = true
                viewModel.aiError = "AI provider unavailable in construction test."
                viewModel.selectedType = .movie
                viewModel.genres = [genre]
                viewModel.selectedGenre = genre
                viewModel.sortOption = .ratingDesc
                viewModel.languageFilters = ["es-ES"]
                viewModel.yearRangePreset = .twenties
                viewModel.yearFilter = 2020
            },
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(view.frame(width: 980, height: 820))
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 80_000_000)

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func libraryViewSeededStatesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let now = Date(timeIntervalSince1970: 1_800)
        let watchlistRoot = makeLibraryFolder(
            id: LibraryFolder.systemFolderID(for: .watchlist),
            name: "Watchlist",
            listType: .watchlist,
            folderKind: .systemRoot,
            isSystem: true
        )
        let favoritesRoot = makeLibraryFolder(
            id: LibraryFolder.systemFolderID(for: .favorites),
            name: "Favorites",
            listType: .favorites,
            folderKind: .systemRoot,
            isSystem: true
        )
        let sciFi = makeLibraryFolder(
            id: "vision-folder-sci-fi",
            name: "Sci-Fi",
            parentId: watchlistRoot.id,
            listType: .watchlist
        )
        let miniseries = makeLibraryFolder(
            id: "vision-folder-miniseries",
            name: "Miniseries",
            parentId: favoritesRoot.id,
            listType: .favorites
        )
        let arrival = makeLibraryMediaItem(id: "vision-library-arrival", title: "Arrival", year: 2016)
        let severance = makeLibraryMediaItem(
            id: "vision-library-severance",
            type: .series,
            title: "Severance",
            year: 2022,
            posterPath: "/severance.jpg"
        )
        let historyItem = makeLibraryMediaItem(
            id: "vision-library-history",
            title: "Dune",
            year: 2021,
            backdropPath: "/dune-backdrop.jpg"
        )
        let mediaItems = [
            arrival.id: arrival,
            severance.id: severance,
            historyItem.id: historyItem,
        ]

        let views: [(String, LibraryView)] = [
            ("Library loading", LibraryView(
                initialIsLoadingSelection: true,
                disablesAutomaticTasks: true
            )),
            ("Library empty favorites", LibraryView(
                initialSelectedList: .favorites,
                initialFolders: [favoritesRoot, miniseries],
                initialStatusMessage: "Import finished: no new library items were added.",
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Library populated watchlist folder", LibraryView(
                initialSelectedList: .watchlist,
                initialSelectedFolderID: sciFi.id,
                initialEntries: [
                    makeLibraryEntry(id: "vision-entry-arrival", mediaId: arrival.id, folderId: sciFi.id, listType: .watchlist, addedAt: now),
                    makeLibraryEntry(id: "vision-entry-severance", mediaId: severance.id, folderId: watchlistRoot.id, listType: .watchlist, addedAt: now.addingTimeInterval(-60)),
                ],
                initialFolders: [watchlistRoot, sciFi],
                initialMediaItems: mediaItems,
                initialUserRatings: [
                    arrival.id: TasteEvent(mediaId: arrival.id, eventType: .rated, feedbackScale: .oneToTen, feedbackValue: 9),
                ],
                initialStatusMessage: "Folder order updated.",
                initialManualFolderOrderIDs: [sciFi.id],
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Library history dedupe", LibraryView(
                initialSelectedList: .history,
                initialHistoryEntries: [
                    makeWatchHistory(id: "vision-history-1", mediaId: historyItem.id, title: historyItem.title, watchedAt: now),
                    makeWatchHistory(id: "vision-history-2", mediaId: historyItem.id, title: historyItem.title, watchedAt: now.addingTimeInterval(-120)),
                ],
                initialMediaItems: mediaItems,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Library action error refreshing", LibraryView(
                initialSelectedList: .watchlist,
                initialFolders: [watchlistRoot],
                initialActionError: .unknown("Could not refresh the library in construction test."),
                initialIsRefreshingTitleDuplicates: true,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Library create folder sheet", LibraryView(
                initialSelectedList: .watchlist,
                initialFolders: [watchlistRoot, sciFi],
                initialIsShowingCreateFolderSheet: true,
                initialCreateFolderListType: .watchlist,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Library CSV import sheet", LibraryView(
                initialSelectedList: .favorites,
                initialFolders: [favoritesRoot, miniseries],
                initialIsShowingCSVImportSheet: true,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Library CSV export sheet", LibraryView(
                initialSelectedList: .history,
                initialHistoryEntries: [
                    makeWatchHistory(id: "vision-export-history", mediaId: historyItem.id, title: historyItem.title, watchedAt: now),
                ],
                initialMediaItems: mediaItems,
                initialIsShowingCSVExportSheet: true,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
            ("Library delete folder dialog", LibraryView(
                initialSelectedList: .watchlist,
                initialSelectedFolderID: sciFi.id,
                initialFolders: [watchlistRoot, sciFi],
                initialFolderPendingDeletion: sciFi,
                initialIsLoadingSelection: false,
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 980, height: 820)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func discoverViewAlternateStatesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let movie = makeMediaPreview(id: "vision-discover-arrival", title: "Arrival", year: 2016)
        let show = makeMediaPreview(id: "vision-discover-show", type: .series, title: "Severance", year: 2022)
        let popular = makeMediaPreview(id: "vision-discover-popular", title: "Dune", year: 2021)
        let topRated = makeMediaPreview(id: "vision-discover-top-rated", title: "Moon", year: 2009)
        let nowPlaying = makeMediaPreview(id: "vision-discover-now-playing", title: "Civil War", year: 2024)
        let history = WatchHistory(
            id: "vision-discover-history",
            mediaId: show.id,
            episodeId: "vision-discover-show-s1e1",
            title: "Severance - Good News About Hell",
            progress: 1_200,
            duration: 3_600,
            watchedAt: Date(timeIntervalSince1970: 2_400),
            isCompleted: false
        )

        func viewModel(_ configure: (DiscoverViewModel) -> Void) -> DiscoverViewModel {
            let model = DiscoverViewModel()
            model.hasPerformedInitialLoad = true
            model.isLoading = false
            configure(model)
            return model
        }

        let recommendations = [
            AIMovieRecommendation(title: "Moon", year: 2009, type: .movie, reason: "Compact, cerebral science fiction.", tmdbId: 17431, score: 0.94),
            AIMovieRecommendation(title: "Devs", year: 2020, type: .series, reason: "A quiet mystery with big ideas.", tmdbId: 81349, score: 0.88),
            AIMovieRecommendation(title: "Primer", year: 2004, type: .movie, reason: "Dense time-loop engineering.", tmdbId: 14337, score: 0.82),
            AIMovieRecommendation(title: "Dark", year: 2017, type: .series, reason: "Layered timelines and family secrets.", tmdbId: 70523, score: 0.8),
        ]

        let views: [(String, DiscoverViewModel)] = [
            ("Discover blocking skeleton", viewModel { model in
                model.isLoading = true
            }),
            ("Discover setup error", viewModel { model in
                model.error = .tmdbSetupRequired(feature: "Discover")
            }),
            ("Discover retained refresh with content", viewModel { model in
                model.isLoading = true
                model.featuredBackdrops = [movie]
                model.continueWatching = [(history, show)]
                model.trendingMovies = [movie]
                model.trendingShows = [show]
                model.popularMovies = [popular]
                model.topRatedMovies = [topRated]
                model.nowPlayingMovies = [nowPlaying]
                model.aiRecommendationsEnabled = true
                model.aiRecommendations = [recommendations[0]]
                model.aiHeroPreview = topRated
            }),
            ("Discover AI loading", viewModel { model in
                model.aiRecommendationsEnabled = true
                model.isLoadingAIRecommendations = true
            }),
            ("Discover AI empty", viewModel { model in
                model.aiRecommendationsEnabled = true
            }),
            ("Discover AI populated", viewModel { model in
                model.aiRecommendationsEnabled = true
                model.aiRecommendations = recommendations
                model.aiHeroPreview = topRated
            }),
            ("Discover all catalog rows", viewModel { model in
                model.trendingMovies = [movie]
                model.trendingShows = [show]
                model.popularMovies = [popular]
                model.topRatedMovies = [topRated]
                model.nowPlayingMovies = [nowPlaying]
            }),
        ]

        for (name, model) in views {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { DiscoverView(viewModel: model) }
                    .environment(appState)
                    .frame(width: 980, height: 900)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func libraryCSVImportSheetSeededStatesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let createNew = LibraryCSVImportSheetPolicy.createNewFolderOption
        let singleSummary = makeLibraryCSVImportSummary(
            rowsRead: 12,
            rowsImported: 10,
            rowsSkipped: 2,
            watchlist: 6,
            favorites: 2,
            history: 0,
            ratings: 8,
            targetFolderName: "Sci-Fi"
        )
        let historySummary = makeLibraryCSVImportSummary(
            rowsRead: 6,
            rowsImported: 5,
            rowsSkipped: 1,
            watchlist: 0,
            favorites: 0,
            history: 5,
            ratings: 0,
            targetFolderName: nil
        )

        let views: [(String, LibraryCSVImportSheet)] = [
            ("Library CSV default auto folders", LibraryCSVImportSheet(
                initialFolderName: "Movie Night",
                initialAutoSubfolderPerFile: false,
                initialExistingFolderOptions: ["Queued", "Sci-Fi"],
                initialSelectedExistingFolderName: createNew,
                disablesAutomaticTasks: true,
                onImportComplete: { _ in }
            )),
            ("Library CSV existing folder summary", LibraryCSVImportSheet(
                initialDestination: .watchlist,
                initialAutoSubfolderPerFile: false,
                initialExistingFolderOptions: ["Sci-Fi", "Watch Later"],
                initialSelectedExistingFolderName: "Sci-Fi",
                initialImportSummary: singleSummary,
                disablesAutomaticTasks: true,
                onImportComplete: { _ in }
            )),
            ("Library CSV history warning", LibraryCSVImportSheet(
                initialDestination: .history,
                initialImportToFolder: true,
                initialImportError: "No CSV files found in the selected folder.",
                initialImportNotice: "Import finished: ratings were imported, but no library rows changed.",
                disablesAutomaticTasks: true,
                onImportComplete: { _ in }
            )),
            ("Library CSV multi results diagnostics", LibraryCSVImportSheet(
                initialImportInFlight: true,
                initialMultiImportSummaries: [singleSummary, historySummary],
                initialImportDiagnostics: [
                    "file=watchlist.csv rows=10/12 skipped=2 W=6 F=2 H=0 R=8",
                    "file=history.csv rows=5/6 skipped=1 W=0 F=0 H=5 R=0",
                ],
                disablesAutomaticTasks: true,
                onImportComplete: { _ in }
            )),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                view
                    .environment(appState)
                    .frame(width: 760, height: 880)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func libraryCSVImportSheetReloadsExistingFolderOptionsFromDatabase() async throws {
        let database = try DatabaseManager(inMemoryNamed: "library-csv-import-sheet-folders-\(UUID().uuidString)")
        try await database.migrate()
        _ = try await database.createLibraryFolder(name: "Sci-Fi", listType: .watchlist)
        _ = try await database.createLibraryFolder(name: "Queued", listType: .watchlist)

        let appState = AppState(database: database, testHooks: .init())
        let probe = FolderOptionsRefreshProbe()
        let createNew = LibraryCSVImportSheetPolicy.createNewFolderOption

        let hosted = try hostInVisibleVisionWindow(
            LibraryCSVImportSheet(
                initialImportToFolder: true,
                initialAutoSubfolderPerFile: false,
                initialSelectedExistingFolderName: createNew,
                disablesAutomaticTasks: false,
                onFolderOptionsRefreshed: { options, selectedName in
                    probe.record(options: options, selectedName: selectedName)
                },
                onImportComplete: { _ in }
            )
            .environment(appState)
            .frame(width: 760, height: 880)
        )
        defer { tearDownVisionWindow(hosted.window) }

        for _ in 0..<20 {
            if probe.snapshot != nil { break }
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        let snapshot = try #require(probe.snapshot)
        #expect(snapshot.options == ["Queued", "Sci-Fi"])
        #expect(snapshot.selectedName == "Queued")
        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test func libraryCSVExportSheetSeededStatesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vpstudio-export-sheet-vision-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: exportDirectory) }
        try "const,Title\n".write(
            to: exportDirectory.appendingPathComponent("Watchlist.csv"),
            atomically: true,
            encoding: .utf8
        )
        try "const,Title\n".write(
            to: exportDirectory.appendingPathComponent("History.csv"),
            atomically: true,
            encoding: .utf8
        )

        let summary = LibraryCSVExportSummary(
            filesWritten: 2,
            totalItemsExported: 14,
            folderNames: ["Watchlist", "History", "Sci-Fi"]
        )

        let views: [(String, LibraryCSVExportSheet)] = [
            ("Library CSV export options", LibraryCSVExportSheet()),
            ("Library CSV export in flight with error", LibraryCSVExportSheet(
                initialIsExporting: true,
                initialErrorMessage: "Export failed because the destination is unavailable."
            )),
            ("Library CSV export result", LibraryCSVExportSheet(
                initialExportSummary: summary,
                initialExportDirectoryURL: exportDirectory
            )),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                view
                    .environment(appState)
                    .frame(width: 760, height: 520)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func settingsDestinationSurfacesHostOnVisionOS() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let database = try DatabaseManager(inMemoryNamed: "settings-vision-\(UUID().uuidString)")
        try await database.migrate()
        try await database.saveEnvironmentAsset(
            EnvironmentAsset(
                id: "vision-bundled-settings",
                name: "Bundled Settings",
                sourceType: .bundled,
                assetPath: "bundle://settings.usdz",
                licenseName: "Bundled",
                isActive: true
            )
        )
        try await database.saveEnvironmentAsset(
            EnvironmentAsset(
                id: "vision-imported-settings",
                name: "Imported Settings",
                sourceType: .imported,
                assetPath: rootDirectory.appendingPathComponent("imported.hdr").path,
                sourceAttributionURL: "https://example.com/environment",
                previewImagePath: nil,
                hdriYawOffset: 0,
                isActive: false
            )
        )
        let appState = AppState(database: database, testHooks: .init())
        appState.isImmersiveSpaceOpen = true
        appState.activeEnvironment = .cinemaEnvironment

        let views: [(String, AnyView)] = [
            ("AISettingsView", AnyView(NavigationStack { AISettingsView() }.environment(appState))),
            ("DebridSettingsView", AnyView(NavigationStack { DebridSettingsView() }.environment(appState))),
            ("EnvironmentSettingsView", AnyView(NavigationStack { EnvironmentSettingsView() }.environment(appState))),
            ("IMDbImportSettingsView", AnyView(NavigationStack { IMDbImportSettingsView() }.environment(appState))),
            ("IndexerSettingsView", AnyView(NavigationStack { IndexerSettingsView() }.environment(appState))),
            ("MetadataSettingsView", AnyView(NavigationStack { MetadataSettingsView() }.environment(appState))),
            ("PlayerSettingsView", AnyView(NavigationStack { PlayerSettingsView() }.environment(appState))),
            ("ResetDataView", AnyView(NavigationStack { ResetDataView() }.environment(appState))),
            ("ResetDataView Second Confirmation", AnyView(NavigationStack {
                ResetDataView(initialStep: .secondConfirmation)
            }.environment(appState))),
            ("ResetDataView Final Confirmation", AnyView(NavigationStack {
                ResetDataView(initialStep: .finalConfirmation)
            }.environment(appState))),
            ("ResetDataView Final Ready", AnyView(NavigationStack {
                ResetDataView(
                    initialStep: .finalConfirmation,
                    initialConfirmationText: ResetDataPolicy.requiredConfirmationPhrase
                )
            }.environment(appState))),
            ("SimklSettingsView", AnyView(NavigationStack { SimklSettingsView() }.environment(appState))),
            ("SubtitleSettingsView", AnyView(NavigationStack { SubtitleSettingsView() }.environment(appState))),
            ("TestModeView", AnyView(NavigationStack { TestModeView() }.environment(appState))),
            ("TraktSettingsView", AnyView(NavigationStack { TraktSettingsView() }.environment(appState))),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(view.frame(width: 720, height: 900))
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 80_000_000)

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func settingsRootAlternateStatesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let configuredStatuses: [SettingsDestination: SettingsDestinationStatus] = [
            .debrid: SettingsDestinationStatus(message: "1 active service", kind: .positive),
            .indexers: SettingsDestinationStatus(message: "2 active indexers", kind: .positive),
            .metadata: SettingsDestinationStatus(message: "API key configured", kind: .positive),
            .ai: SettingsDestinationStatus(message: "OpenRouter configured", kind: .positive),
            .subtitles: SettingsDestinationStatus(message: "API key configured", kind: .positive),
            .player: SettingsDestinationStatus(message: "Built-in player", kind: .neutral),
            .trakt: SettingsDestinationStatus(message: "Credentials saved", kind: .neutral),
        ]
        let warningStatuses: [SettingsDestination: SettingsDestinationStatus] = [
            .debrid: SettingsDestinationStatus(message: "Not configured", kind: .warning),
            .indexers: SettingsDestinationStatus(message: "No active indexers", kind: .warning),
            .metadata: SettingsDestinationStatus(message: "API key required", kind: .warning),
            .ai: SettingsDestinationStatus(message: "Provider key required", kind: .warning),
            .subtitles: SettingsDestinationStatus(message: "Optional", kind: .neutral),
        ]

        let views: [(String, SettingsView)] = [
            ("Settings configured recent", SettingsView(
                initialDestinationStatuses: configuredStatuses,
                initialRecentDestination: .player,
                disablesAutomaticTasks: true
            )),
            ("Settings empty search refreshing", SettingsView(
                initialQuery: "no-such-provider",
                initialDidLoadInitialSearch: true,
                initialIsRefreshingStatuses: true,
                initialDestinationStatuses: warningStatuses,
                disablesAutomaticTasks: true
            )),
            ("Settings reset sheet", SettingsView(
                initialDestinationStatuses: warningStatuses,
                initialIsShowingResetSheet: true,
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 760, height: 900)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func traktSettingsAlternateStatesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let states: [(String, TraktSettingsView)] = [
            ("Connected Trakt", TraktSettingsView(
                initialIsConnected: true,
                initialStatusMessage: "Connected to Trakt.",
                initialAutoScrobble: true,
                initialSyncWatchlist: true,
                initialSyncHistory: true,
                initialSyncRatings: true,
                initialSyncFolders: true,
                initialIsSyncing: true,
                initialLastSyncDate: "2026-05-04T12:00:00Z",
                initialSyncResultMessage: "Synced 12 items.",
                initialShowAdvanced: true,
                initialClientId: "fixture-client-id",
                initialClientSecret: "fixture-client-secret",
                disablesAutomaticReload: true
            )),
            ("Authorizing Trakt", TraktSettingsView(
                initialIsAuthenticating: true,
                initialDeviceUserCode: "ABCD-1234",
                initialDeviceVerificationURL: "https://trakt.tv/activate",
                initialShowAdvanced: true,
                initialClientId: "fixture-client-id",
                initialClientSecret: "fixture-client-secret",
                disablesAutomaticReload: true
            )),
        ]

        for (name, view) in states {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 720, height: 900)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func aiSettingsAlternateStatesHostOnVisionOS() async throws {
        let database = try DatabaseManager(inMemoryNamed: "ai-settings-vision-\(UUID().uuidString)")
        try await database.migrate()
        let appState = AppState(database: database, secretStore: TestSecretStore())
        let usage = AIUsageSummary(
            totalInputTokens: 15_000,
            totalOutputTokens: 4_200,
            totalCostUSD: 0.84,
            byProvider: [
                .openAI: ProviderUsage(inputTokens: 8_000, outputTokens: 2_000, costUSD: 0.42, requestCount: 3),
                .minimax: ProviderUsage(inputTokens: 7_000, outputTokens: 2_200, costUSD: 0.42, requestCount: 2),
            ],
            requestCount: 5
        )
        let localModels = [
            makeAISettingsLocalModel(id: "local-ready", displayName: "Ready Local", status: .downloaded),
            makeAISettingsLocalModel(id: "local-downloading", displayName: "Downloading Local", status: .downloading, progress: 0.42),
            makeAISettingsLocalModel(id: "local-available", displayName: "Available Local", status: .available),
            makeAISettingsLocalModel(id: "local-failed", displayName: "Failed Local", status: .failed),
            makeAISettingsLocalModel(id: "local-paused", displayName: "Paused Local", status: .paused, progress: 0.24),
        ]

        let views: [(String, AISettingsView)] = [
            ("Configured OpenAI provider", AISettingsView(
                initialOpenAIKey: "fixture-openai-key",
                initialSelectedProvider: .openAI,
                initialPreferredProvider: .openAI,
                initialSessionUsage: usage,
                initialLifetimeUsage: usage,
                initialDiscoverAIEnabled: true,
                initialAIAutoGenerate: true,
                initialFeedbackScaleMode: .oneToTen,
                initialLikedTitles: ["Arrival", "Moon"],
                initialDislikedTitles: ["Battlefield Earth"],
                initialRecentRatings: ["Arrival (9/10)", "Moon (8/10)"],
                disablesAutomaticTasks: true
            )),
            ("Cloud provider limit warning", AISettingsView(
                initialAnthropicKey: "fixture-anthropic-key",
                initialOpenAIKey: "fixture-openai-key",
                initialOpenRouterKey: "fixture-openrouter-key",
                initialSelectedProvider: .gemini,
                initialPreferredProvider: .anthropic,
                initialSurfaceError: .unknown("Provider limit reached in construction test."),
                disablesAutomaticTasks: true
            )),
            ("Local model catalog", AISettingsView(
                initialSelectedProvider: .local,
                initialPreferredProvider: .local,
                initialLocalModelEnabled: true,
                initialLocalModelID: "local-ready",
                initialLocalModels: localModels,
                disablesAutomaticTasks: true
            )),
            ("Ollama endpoint warning", AISettingsView(
                initialOllamaURL: "http://example.com:11434",
                initialSelectedProvider: .ollama,
                initialPreferredProvider: .ollama,
                disablesAutomaticTasks: true
            )),
            ("MiniMax configured provider", AISettingsView(
                initialMiniMaxKey: "fixture-minimax-key",
                initialSelectedProvider: .minimax,
                initialPreferredProvider: .minimax,
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 760, height: 980)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 80_000_000)

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func debridSettingsAlternateStatesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let now = Date(timeIntervalSince1970: 1_000)
        let realDebrid = DebridConfig(
            id: "vision-real-debrid",
            serviceType: .realDebrid,
            apiTokenRef: SecretReference.encode(
                key: DebridConfig.secretKey(for: "vision-real-debrid", serviceType: .realDebrid)
            ),
            isActive: true,
            priority: 0,
            createdAt: now,
            updatedAt: now
        )
        let easyNews = DebridConfig(
            id: "vision-easynews",
            serviceType: .easyNews,
            apiTokenRef: SecretReference.encode(
                key: DebridConfig.secretKey(for: "vision-easynews", serviceType: .easyNews)
            ),
            isActive: false,
            priority: 1,
            createdAt: now,
            updatedAt: now
        )

        let views: [(String, DebridSettingsView)] = [
            ("Debrid empty error", DebridSettingsView(
                initialSurfaceError: .unknown("Streaming provider settings failed to load in construction test."),
                disablesAutomaticTasks: true
            )),
            ("Debrid add sheet", DebridSettingsView(
                initialShowingAddSheet: true,
                initialNewServiceType: .realDebrid,
                initialNewApiKey: "fixture-debrid-key",
                disablesAutomaticTasks: true
            )),
            ("Debrid rows validating", DebridSettingsView(
                initialConfigs: [realDebrid, easyNews],
                initialTestingConfigID: realDebrid.id,
                initialUpdatingConfigID: easyNews.id,
                initialValidationSuccessMessagesByConfigID: [
                    realDebrid.id: "Real-Debrid token validated."
                ],
                initialValidationErrorMessagesByConfigID: [
                    easyNews.id: "Easynews is unavailable in this runtime."
                ],
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 760, height: 860)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func indexerSettingsAlternateStatesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let jackett = IndexerConfig(
            id: "vision-jackett",
            name: "Fixture Jackett",
            indexerType: .jackett,
            baseURL: "https://jackett.example",
            apiKey: SecretReference.encode(key: IndexerConfig.secretKey(for: "vision-jackett")),
            isActive: true,
            priority: 0,
            endpointPath: "/api/v2.0/indexers/all/results/torznab/api",
            categoryFilter: "2000,5000",
            apiKeyTransport: .header
        )
        let stremio = IndexerConfig(
            id: "vision-stremio",
            name: "Fixture Stremio",
            indexerType: .stremio,
            baseURL: "https://stremio.example",
            apiKey: nil,
            isActive: false,
            priority: 1,
            endpointPath: "/manifest.json"
        )
        var invalidDraft = IndexerSettingsView.IndexerDraft.new()
        invalidDraft.name = "Fixture Torznab"
        invalidDraft.indexerType = .torznab
        invalidDraft.baseURL = "http://insecure.example"
        invalidDraft.apiKey = ""
        invalidDraft.endpointPath = "torznab/api"

        let views: [(String, IndexerSettingsView)] = [
            ("Indexer empty warning", IndexerSettingsView(
                initialNotice: .warning("No indexer responses are available in construction test."),
                disablesAutomaticTasks: true
            )),
            ("Indexer configured rows", IndexerSettingsView(
                initialConfigs: [jackett, stremio],
                initialNotice: .success("Indexer settings saved."),
                initialTestingConfigID: jackett.id,
                disablesAutomaticTasks: true
            )),
            ("Indexer editor validation", IndexerSettingsView(
                initialIsShowingEditor: true,
                initialDraft: invalidDraft,
                initialSurfaceError: .unknown("Indexer connection failed in construction test."),
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 760, height: 900)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func metadataAndSimklSettingsAlternateStatesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let views: [(String, AnyView)] = [
            ("Metadata saved", AnyView(NavigationStack {
                MetadataSettingsView(
                    initialTMDBApiKey: "fixture-tmdb-key",
                    initialIsSaved: true,
                    initialNotice: .success("TMDB API key saved."),
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
            ("Metadata testing error", AnyView(NavigationStack {
                MetadataSettingsView(
                    initialTMDBApiKey: "fixture-unsaved-key",
                    initialBaselineTMDBApiKey: "fixture-saved-key",
                    initialIsTestingApiKey: true,
                    initialSurfaceError: .unknown("TMDB validation failed in construction test."),
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
            ("Simkl saved authorization", AnyView(NavigationStack {
                SimklSettingsView(
                    initialHasSavedAuthorization: true,
                    initialStatusMessage: "Saved authorization exists, but Simkl remains cleanup-only in this build.",
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
            ("Simkl disconnect confirmation", AnyView(NavigationStack {
                SimklSettingsView(
                    initialHasSavedAuthorization: true,
                    initialIsShowingDisconnectConfirmation: true,
                    initialErrorMessage: "Simkl authorization could not be removed in construction test.",
                    disablesAutomaticTasks: true
                )
            }.environment(appState))),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(view.frame(width: 720, height: 760))
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func playerSettingsAlternateStatesHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let views: [(String, PlayerSettingsView)] = [
            ("Player defaults", PlayerSettingsView(disablesAutomaticTasks: true)),
            ("Player adaptive high fidelity", PlayerSettingsView(
                initialPreferredQuality: .uhd4k,
                initialAutoPlay: false,
                initialHardwareDecoding: false,
                initialPlayerEngineStrategy: .adaptive,
                initialPreferCached: false,
                initialPreferAtmos: true,
                initialHDRPreference: .dolbyVision,
                initialRuntimeDiagnosticsEnabled: true,
                initialNavigationLayout: .leftSidebar,
                disablesAutomaticTasks: true
            )),
            ("Player custom external URL invalid", PlayerSettingsView(
                initialExternalPlayerApp: .custom,
                initialExternalPlayerTemplate: "vlc-x-callback://x-callback-url/stream",
                initialSurfaceError: .unknown("Playback settings could not be saved in construction test."),
                disablesAutomaticTasks: true
            )),
            ("Player external VLC valid", PlayerSettingsView(
                initialPlayerEngineStrategy: .performance,
                initialExternalPlayerApp: .vlc,
                initialExternalPlayerTemplate: "vlc-x-callback://x-callback-url/stream?url={url}",
                initialHDRPreference: .hdr10,
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 760, height: 860)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func imdbCSVImportAndPreviewSheetsHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        var emptyHeaders: [String] = []
        var emptyRows: [[String]] = []
        var emptyMappings: [String: String] = [:]
        var emptyAnalyzing = false
        var emptyAISuggestions: [String: String] = [:]
        var emptyAIError: String?

        var headers = ["const", "primaryTitle", "Your Rating", "Date Rated"]
        var rows = [
            ["tt0111161", "The Shawshank Redemption", "10", "2026-04-26"],
            ["tt0068646", "The Godfather", "9", "2026-04-25"],
        ]
        var mappings = [
            "const": "imdbID",
            "primaryTitle": "title",
            "Your Rating": "userRating",
        ]
        var isAnalyzing = true
        var aiSuggestions = [
            "Date Rated": "date",
        ]
        var aiError: String? = "AI mapping unavailable in construction test."

        let views: [(String, AnyView)] = [
            ("IMDb CSV Import Sheet", AnyView(IMDbCSVImportSheet().environment(appState))),
            ("Empty CSV Header Preview", AnyView(CSVHeaderPreviewSheet(
                headers: Binding(get: { emptyHeaders }, set: { emptyHeaders = $0 }),
                firstRows: Binding(get: { emptyRows }, set: { emptyRows = $0 }),
                detectedMappings: Binding(get: { emptyMappings }, set: { emptyMappings = $0 }),
                isAnalyzing: Binding(get: { emptyAnalyzing }, set: { emptyAnalyzing = $0 }),
                aiSuggestedMappings: Binding(get: { emptyAISuggestions }, set: { emptyAISuggestions = $0 }),
                aiAnalysisError: Binding(get: { emptyAIError }, set: { emptyAIError = $0 })
            ).environment(appState))),
            ("Detected CSV Header Preview", AnyView(CSVHeaderPreviewSheet(
                headers: Binding(get: { headers }, set: { headers = $0 }),
                firstRows: Binding(get: { rows }, set: { rows = $0 }),
                detectedMappings: Binding(get: { mappings }, set: { mappings = $0 }),
                isAnalyzing: Binding(get: { isAnalyzing }, set: { isAnalyzing = $0 }),
                aiSuggestedMappings: Binding(get: { aiSuggestions }, set: { aiSuggestions = $0 }),
                aiAnalysisError: Binding(get: { aiError }, set: { aiError = $0 })
            ).environment(appState))),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(view.frame(width: 760, height: 860))
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }

        #expect(headers.count == 4)
        #expect(rows.count == 2)
        #expect(mappings["const"] == "imdbID")
        #expect(aiSuggestions["Date Rated"] == "date")
    }

    @Test func setupWizardStepsHostOnVisionOS() throws {
        for step in 0..<5 {
            let hosted = try hostInVisibleVisionWindow(
                SetupWizardView(
                    initialStep: step,
                    initialDebridApiKey: "fixture-debrid-key",
                    initialSelectedService: .realDebrid,
                    initialTMDBApiKey: "fixture-tmdb-key",
                    initialSelectedAIProvider: .openRouter,
                    initialAIAPIKey: "fixture-ai-key",
                    initialSelectedQuality: .uhd4k,
                    initialSelectedSubtitleLanguage: .english
                )
                .environment(AppState(testHooks: .init()))
                .frame(width: 760, height: 760)
            )

            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "Setup step \(step) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "Setup step \(step) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "Setup step \(step) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test(arguments: TestScreen.allCases)
    func testModePreviewSheetHostsSurfaceOnVisionOS(screen: TestScreen) throws {
        let appState = AppState(testHooks: .init())

        let hosted = try hostInVisibleVisionWindow(
            TestScreenSheet(screen: screen)
                .environment(appState)
                .frame(width: 920, height: 720)
        )

        #expect(hosted.host.view.bounds.width > 0, "\(screen.title) preview should lay out")
        #expect(hosted.host.view.subviews.isEmpty == false, "\(screen.title) preview should create a SwiftUI host subtree")
        tearDownVisionWindow(hosted.window)
    }

    @Test func detailViewLoadedContentHostsOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let moviePreview = makeMediaPreview(
            id: "vision-loaded-detail-movie",
            title: "Dune",
            year: 2021
        )
        func makeLoadedMovieViewModel(
            feedbackScaleMode: FeedbackScaleMode = .likeDislike,
            currentFeedbackValue: Double? = nil,
            aiAnalysisError: String? = nil
        ) -> DetailViewModel {
            let viewModel = DetailViewModel(appState: appState)
            let movie = makeMediaItem(type: .movie)
            viewModel.mediaItem = movie
            viewModel.viewState = .loaded
            viewModel.feedbackScaleMode = feedbackScaleMode
            viewModel.currentFeedbackValue = currentFeedbackValue
            viewModel.aiAnalysisError = aiAnalysisError
            viewModel.watchHistory = WatchHistory(
                id: "vision-loaded-detail-history",
                mediaId: movie.id,
                title: movie.title,
                progress: 2_400,
                duration: 7_200,
                watchedAt: Date(timeIntervalSince1970: 500),
                isCompleted: false
            )
            viewModel.torrents = [
                TorrentResult.fromSearch(
                    infoHash: "abcdefabcdefabcdefabcdefabcdefabcdefabcd",
                    title: "Dune.2021.1080p.WEB-DL",
                    sizeBytes: 4_200_000_000,
                    seeders: 220,
                    leechers: 14,
                    indexerName: "Fixture"
                )
            ]
            viewModel.didSearch = true
            return viewModel
        }

        let movieViewModel = makeLoadedMovieViewModel()

        let loadingPreview = makeMediaPreview(
            id: "vision-refreshing-detail-movie",
            title: "Arrival",
            year: 2016
        )
        let refreshingViewModel = DetailViewModel(appState: appState)
        refreshingViewModel.mediaItem = makeMediaItem(type: .movie)
        refreshingViewModel.viewState = .loading(.detail)

        let views: [(String, AnyView)] = [
            ("Loaded DetailView", AnyView(NavigationStack {
                DetailView(
                    preview: moviePreview,
                    initialViewModel: movieViewModel,
                    disablesAutomaticLoading: true
                )
            }.environment(appState))),
            ("Refreshing DetailView", AnyView(NavigationStack {
                DetailView(
                    preview: loadingPreview,
                    initialViewModel: refreshingViewModel,
                    disablesAutomaticLoading: true
                )
            }.environment(appState))),
            ("Detail rating sheet", AnyView(NavigationStack {
                DetailView(
                    preview: moviePreview,
                    initialViewModel: makeLoadedMovieViewModel(
                        feedbackScaleMode: .oneToTen,
                        currentFeedbackValue: 7
                    ),
                    initialTMDBApiKey: "test-key",
                    initialIsShowingRatingSheet: true,
                    initialDraftFeedbackValue: 7,
                    disablesAutomaticLoading: true
                )
            }.environment(appState))),
            ("Detail active player toast", AnyView(NavigationStack {
                DetailView(
                    preview: moviePreview,
                    initialViewModel: makeLoadedMovieViewModel(),
                    initialShowActiveSessionToast: true,
                    disablesAutomaticLoading: true
                )
            }.environment(appState))),
            ("Detail player opening error", AnyView(NavigationStack {
                DetailView(
                    preview: moviePreview,
                    initialViewModel: makeLoadedMovieViewModel(aiAnalysisError: "AI provider unavailable."),
                    initialIsPlayerOpening: true,
                    initialPlayerOpeningError: "Could not open stream. Please try another result.",
                    disablesAutomaticLoading: true
                )
            }.environment(appState))),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(view.frame(width: 980, height: 920))
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func seriesDetailLayoutsHostOnVisionOS() throws {
        let appState = AppState(testHooks: .init())
        let seriesViewModel = DetailViewModel(appState: appState)
        let selectedEpisode = Episode(
            id: "vision-series-s01e02",
            mediaId: "vision-series-fixture",
            seasonNumber: 1,
            episodeNumber: 2,
            title: "The Second Signal",
            overview: "The crew follows a signal into a sharper mystery.",
            airDate: "2026-04-26",
            stillPath: nil,
            runtime: 44
        )
        seriesViewModel.mediaItem = makeMediaItem(type: .series)
        seriesViewModel.seasons = [
            Season(id: 1, seasonNumber: 1, name: "Season 1", overview: "Opening run", posterPath: nil, episodeCount: 2, airDate: "2026-01-01"),
            Season(id: 2, seasonNumber: 2, name: "Season 2", overview: nil, posterPath: nil, episodeCount: 1, airDate: nil),
        ]
        seriesViewModel.episodes = [
            Episode(id: "vision-series-s01e01", mediaId: "vision-series-fixture", seasonNumber: 1, episodeNumber: 1, title: "Pilot", overview: nil, airDate: "2026-04-19", stillPath: nil, runtime: 42),
            selectedEpisode,
        ]
        seriesViewModel.selectedSeason = 1
        seriesViewModel.selectedEpisode = selectedEpisode
        seriesViewModel.episodeWatchStates[selectedEpisode.id] = WatchHistory(
            id: "vision-history-\(selectedEpisode.id)",
            mediaId: selectedEpisode.mediaId,
            episodeId: selectedEpisode.id,
            title: selectedEpisode.displayTitle,
            progress: 1,
            duration: 2_640,
            watchedAt: Date(),
            isCompleted: true
        )
        seriesViewModel.aiAnalysis = AIPersonalizedAnalysis(
            personalizedDescription: "Matches the user's preference for thoughtful science fiction.",
            predictedRating: 8.5,
            verdict: .yes,
            reasons: ["Strong continuity", "Clean visual style"]
        )
        seriesViewModel.torrents = [
            TorrentResult.fromSearch(
                infoHash: "abcdef1234567890abcdef1234567890abcdef12",
                title: "The.Expanse.S01E02.1080p.WEB-DL",
                sizeBytes: 2_400_000_000,
                seeders: 120,
                leechers: 8,
                indexerName: "Fixture"
            )
        ]
        seriesViewModel.didSearch = true

        let movieViewModel = DetailViewModel(appState: appState)
        let movie = makeMediaItem(type: .movie)
        movieViewModel.mediaItem = movie
        movieViewModel.watchHistory = WatchHistory(
            id: "vision-history-\(movie.id)",
            mediaId: movie.id,
            title: movie.title,
            progress: 3_600,
            duration: 7_200,
            quality: "1080p",
            debridService: DebridServiceType.realDebrid.rawValue,
            streamURL: "https://cdn.example.com/dune.mp4",
            watchedAt: Date(),
            isCompleted: false
        )
        movieViewModel.aiAnalysisError = "AI provider is not configured."
        movieViewModel.torrents = [
            TorrentResult.fromSearch(
                infoHash: "1234567890abcdef1234567890abcdef12345678",
                title: "Dune.2021.2160p.WEB-DL",
                sizeBytes: 8_000_000_000,
                seeders: 250,
                leechers: 12,
                indexerName: "Fixture"
            )
        ]
        movieViewModel.didSearch = true

        var isPlayerOpening = false
        var playerOpeningError: String?
        var playedTorrent: TorrentResult?
        var castCount = 0
        var ratingSheetCount = 0

        let seriesView = NavigationStack {
            SeriesDetailLayout(
                viewModel: seriesViewModel,
                title: "The Expanse",
                tmdbApiKey: "test-key",
                mediaType: .series,
                streamResultsAnchor: "streams",
                shareItem: "The Expanse",
                isPlayerOpening: Binding(get: { isPlayerOpening }, set: { isPlayerOpening = $0 }),
                playerOpeningError: Binding(get: { playerOpeningError }, set: { playerOpeningError = $0 }),
                onPlayTorrent: { playedTorrent = $0 },
                onCast: { castCount += 1 },
                onShowRatingSheet: { ratingSheetCount += 1 }
            )
            .environment(appState)
        }
        let movieView = NavigationStack {
            SeriesDetailLayout(
                viewModel: movieViewModel,
                title: movie.title,
                tmdbApiKey: "test-key",
                mediaType: .movie,
                streamResultsAnchor: "streams",
                shareItem: movie.title,
                isPlayerOpening: Binding(get: { isPlayerOpening }, set: { isPlayerOpening = $0 }),
                playerOpeningError: Binding(get: { playerOpeningError }, set: { playerOpeningError = $0 }),
                onPlayTorrent: { playedTorrent = $0 },
                onCast: {},
                onShowRatingSheet: {}
            )
            .environment(appState)
        }

        let seriesHost = try hostInVisibleVisionWindow(seriesView.frame(width: 980, height: 1_100))
        tearDownVisionWindow(seriesHost.window)
        let movieHost = try hostInVisibleVisionWindow(movieView.frame(width: 980, height: 920))
        defer { tearDownVisionWindow(movieHost.window) }

        #expect(seriesHost.host.view.subviews.isEmpty == false)
        #expect(movieHost.host.view.subviews.isEmpty == false)
        #expect(playedTorrent == nil)
        #expect(castCount == 0)
        #expect(ratingSheetCount == 0)
    }

    @Test func environmentPreviewCardsHostOnVisionOS() throws {
        let importedHDRI = EnvironmentAsset(
            id: "vision-imported-hdri",
            name: "Imported HDRI",
            sourceType: .imported,
            assetPath: "/tmp/missing-preview.hdr",
            isActive: true
        )
        let bundledScene = EnvironmentAsset(
            id: "vision-bundled-scene",
            name: "Bundled Scene",
            sourceType: .bundled,
            assetPath: "bundle://cinema.usdz",
            isActive: false
        )

        let view = HStack {
            CinemaEnvironmentPreviewCard(isActive: true, isImmersiveOpen: true, onSelect: {})
            EnvironmentPreviewCard(
                asset: importedHDRI,
                isActive: true,
                isImmersiveOpen: true,
                onSelect: {},
                onDelete: {}
            )
            EnvironmentPreviewCard(
                asset: bundledScene,
                isActive: false,
                isImmersiveOpen: false,
                onSelect: {},
                onDelete: nil
            )
        }

        let hosted = try hostInVisibleVisionWindow(view.frame(width: 760, height: 220))
        defer { tearDownVisionWindow(hosted.window) }
        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.bounds.height > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
    }

    @Test func environmentsTabViewSeededStatesHostOnVisionOS() throws {
        let importedHDRI = EnvironmentAsset(
            id: "vision-tab-imported-hdri",
            name: "Imported HDRI",
            sourceType: .imported,
            assetPath: "/tmp/missing-tab-preview.hdr",
            isActive: true
        )
        let bundledScene = EnvironmentAsset(
            id: "vision-tab-bundled-scene",
            name: "Bundled Scene",
            sourceType: .bundled,
            assetPath: "bundle://cinema.usdz",
            isActive: false
        )

        let idleState = AppState(testHooks: .init())
        let activeState = AppState(testHooks: .init())
        activeState.activeEnvironment = .cinemaEnvironment
        activeState.isImmersiveSpaceOpen = true
        activeState.selectedEnvironmentAsset = importedHDRI

        let views: [(String, AppState, EnvironmentsTabView)] = [
            ("Environments loading", idleState, EnvironmentsTabView(
                initialIsLoading: true,
                disablesAutomaticTasks: true
            )),
            ("Environments empty import prompt", idleState, EnvironmentsTabView(
                initialIsLoading: false,
                disablesAutomaticTasks: true
            )),
            ("Environments populated", idleState, EnvironmentsTabView(
                initialEnvironments: [importedHDRI, bundledScene],
                initialIsLoading: false,
                disablesAutomaticTasks: true
            )),
            ("Environments active immersive", activeState, EnvironmentsTabView(
                initialEnvironments: [importedHDRI, bundledScene],
                initialIsLoading: false,
                disablesAutomaticTasks: true
            )),
        ]

        for (name, appState, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 920, height: 780)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func environmentPickerSheetStatesHostOnVisionOS() throws {
        let importedHDRI = EnvironmentAsset(
            id: "vision-picker-imported-hdri",
            name: "Imported Studio HDRI",
            sourceType: .imported,
            assetPath: "/tmp/missing-picker-preview.hdr",
            sourceAttributionURL: "https://example.com/hdri",
            previewImagePath: nil,
            hdriYawOffset: 12,
            isActive: true
        )
        let importedScene = EnvironmentAsset(
            id: "vision-picker-imported-scene",
            name: "Imported Scene",
            sourceType: .imported,
            assetPath: "/tmp/missing-picker-scene.usdz",
            previewImagePath: nil,
            isActive: false
        )
        let bundledScene = EnvironmentAsset(
            id: "vision-picker-bundled-scene",
            name: "Bundled Theater",
            sourceType: .bundled,
            assetPath: "bundle://theater.usdz",
            previewImagePath: nil,
            isActive: false
        )
        let appState = AppState(testHooks: .init())
        appState.activeEnvironment = .cinemaEnvironment
        appState.isImmersiveSpaceOpen = true
        appState.selectedEnvironmentAsset = importedHDRI

        let views: [(String, EnvironmentPickerSheet)] = [
            ("Empty picker with import error", EnvironmentPickerSheet(
                onSelect: { _ in },
                onDismiss: {},
                initialImportError: "Could not import the selected environment.",
                disablesAutomaticTasks: true
            )),
            ("Populated picker with immersive exit", EnvironmentPickerSheet(
                onSelect: { _ in },
                onDismiss: {},
                onSelectCinema: {},
                initialEnvironments: [importedHDRI, importedScene, bundledScene],
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(
                view
                    .environment(appState)
                    .frame(width: 880, height: 780)
            )
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.08))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            tearDownVisionWindow(hosted.window)
        }
    }

    @Test func playerAutoPlayNextPromptHostsCountdownAndResolvingStatesOnVisionOS() throws {
        let nextEpisode = PlayerSessionRequest.NextEpisodeCandidate(
            episodeId: "vision-next-episode",
            seasonNumber: 1,
            episodeNumber: 2,
            title: "The Next Signal"
        )
        var playNowCount = 0
        var cancelCount = 0

        let view = VStack(spacing: 18) {
            PlayerAutoPlayNextPromptView(
                nextEpisode: nextEpisode,
                remainingSeconds: 8,
                isResolving: false,
                onPlayNow: { playNowCount += 1 },
                onCancel: { cancelCount += 1 }
            )

            PlayerAutoPlayNextPromptView(
                nextEpisode: nextEpisode,
                remainingSeconds: 0,
                isResolving: true,
                onPlayNow: { playNowCount += 1 },
                onCancel: { cancelCount += 1 }
            )
        }
        .padding(24)
        .background(Color.black)

        let hosted = try hostInVisibleVisionWindow(view.frame(width: 520, height: 300))
        defer { tearDownVisionWindow(hosted.window) }
        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.bounds.height > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
        #expect(playNowCount == 0)
        #expect(cancelCount == 0)
    }

    @Test func playerStartupStateOverlaysHostOnVisionOS() throws {
        var retryCount = 0
        var nextStreamCount = 0

        let view = ZStack {
            Color.black
            VStack(spacing: 22) {
                PlayerStartupStateOverlayView(
                    playbackState: .failed,
                    title: "Playback Failed",
                    message: "The selected stream stopped responding.",
                    hasPlayedOnce: false,
                    hasNextStream: true,
                    onRetry: { retryCount += 1 },
                    onTryNextStream: { nextStreamCount += 1 }
                )

                PlayerStartupStateOverlayView(
                    playbackState: .preparing,
                    title: "Preparing Playback",
                    message: "Opening stream...",
                    hasPlayedOnce: false,
                    hasNextStream: false,
                    onRetry: { retryCount += 1 },
                    onTryNextStream: { nextStreamCount += 1 }
                )

                PlayerStartupStateOverlayView(
                    playbackState: .buffering,
                    title: "Buffering",
                    message: nil,
                    hasPlayedOnce: true,
                    hasNextStream: false,
                    onRetry: { retryCount += 1 },
                    onTryNextStream: { nextStreamCount += 1 }
                )
            }
            .padding(24)
        }

        let hosted = try hostInVisibleVisionWindow(view.frame(width: 720, height: 620))
        defer { tearDownVisionWindow(hosted.window) }
        hosted.host.view.setNeedsLayout()
        hosted.host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        #expect(hosted.host.view.bounds.width > 0)
        #expect(hosted.host.view.bounds.height > 0)
        #expect(hosted.host.view.subviews.isEmpty == false)
        #expect(retryCount == 0)
        #expect(nextStreamCount == 0)
    }

    @Test func playerViewHostsPreparingSurfaceOnVisionOS() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let streamURL = rootDirectory.appendingPathComponent("vision-player-smoke.mp4")
        try Data("vpstudio-player-smoke".utf8).write(to: streamURL)
        let stream = StreamInfo(
            streamURL: streamURL,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Vision.Player.Smoke.1080p.mp4",
            sizeBytes: 1_024,
            debridService: "fixture"
        )
        let alternate = StreamInfo(
            streamURL: streamURL,
            quality: .hd720p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .sdr,
            fileName: "Vision.Player.Smoke.720p.mp4",
            sizeBytes: 512,
            debridService: "fixture"
        )

        let host = UIHostingController(rootView: AnyView(
            PlayerView(
                stream: stream,
                availableStreams: [alternate, stream],
                mediaTitle: "Vision Player Smoke",
                mediaId: "vision-player-smoke",
                episodeId: nil,
                sessionID: UUID(),
                disablesAutomaticTasks: true
            )
            .environment(AppState(testHooks: .init()))
            .environment(VPPlayerEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 980, height: 620)
        ))
        host.loadViewIfNeeded()

        host.view.frame = CGRect(x: 0, y: 0, width: 980, height: 620)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        #expect(host.view.bounds.width > 0)
        #expect(host.view.bounds.height > 0)
    }

    @Test func playerViewAlternateChromeStatesHostOnVisionOS() throws {
        let primaryStream = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/vision-player-premium-1080p.mp4")!,
            quality: .hd1080p,
            codec: .h264,
            audio: .aac,
            source: .webDL,
            hdr: .hdr10,
            fileName: "Vision.Player.Premium.S01E02.1080p.mp4",
            sizeBytes: 4_200_000_000,
            debridService: "fixture"
        )
        let alternateStream = StreamInfo(
            streamURL: URL(string: "https://cdn.example.com/vision-player-premium-720p.mp4")!,
            quality: .hd720p,
            codec: .h265,
            audio: .eac3,
            source: .bluRay,
            hdr: .sdr,
            fileName: "Vision.Player.Premium.S01E02.720p.mp4",
            sizeBytes: 2_100_000_000,
            debridService: "fixture"
        )
        let nextEpisode = PlayerSessionRequest.NextEpisodeCandidate(
            episodeId: "vision-player-premium-s01e03",
            seasonNumber: 1,
            episodeNumber: 3,
            title: "Episode 3"
        )
        let subtitleCandidate = Subtitle(
            id: "vision-subtitle-open-en",
            language: "en",
            fileName: "vision-player-premium.srt",
            url: "https://subtitles.example.com/vision-player-premium.srt",
            format: .srt,
            fileId: 42,
            rating: 9.2,
            downloadCount: 1_200,
            isHearingImpaired: true,
            source: "OpenSubtitles"
        )
        let environmentAsset = EnvironmentAsset(
            id: "vision-player-hdri",
            name: "Aurora Loft",
            sourceType: .imported,
            assetPath: "/tmp/vision-player-hdri.hdr",
            isActive: false
        )

        func seededEngine() -> VPPlayerEngine {
            let engine = VPPlayerEngine()
            engine.currentSubtitleText = "We are not alone out here."
            engine.currentTime = 3_590
            engine.duration = 3_600
            engine.bufferedPercent = 0.88
            engine.isPlaying = true
            engine.isBuffering = false
            engine.playbackRate = 1.25
            engine.stereoMode = .sideBySide
            engine.subtitlesEnabled = true
            engine.subtitleTracks = [
                VPPlayerEngine.TrackInfo(id: 0, name: "English CC", language: "en", codec: "srt"),
                VPPlayerEngine.TrackInfo(id: 1, name: "French", language: "fr", codec: "vtt"),
            ]
            engine.selectedSubtitleTrack = 0
            engine.loadAudioTracks([
                VPPlayerEngine.TrackInfo(id: 0, name: "Stereo", language: "en", codec: "aac"),
                VPPlayerEngine.TrackInfo(id: 1, name: "Atmos", language: "en", codec: "eac3"),
            ], selectedTrackID: 1)
            engine.chapters = [
                VPPlayerEngine.ChapterInfo(id: 0, title: "Cold Open", startTime: 0, endTime: 600),
                VPPlayerEngine.ChapterInfo(id: 1, title: "Finale", startTime: 3_000, endTime: 3_600),
            ]
            return engine
        }

        func playerView(
            isShowingSubtitlePicker: Bool = false,
            isShowingAudioPicker: Bool = false,
            playbackState: PlayerPlaybackState = .playing,
            playbackError: String? = nil,
            isResolvingNextEpisode: Bool = false
        ) -> some View {
            let appState = AppState(testHooks: .init())
            appState.isImmersiveSpaceOpen = true
            appState.activeEnvironment = .cinemaEnvironment
            appState.selectedEnvironmentAsset = environmentAsset

            return PlayerView(
                stream: primaryStream,
                availableStreams: [primaryStream, alternateStream],
                mediaTitle: "Vision Player Premium",
                mediaId: "vision-player-premium",
                episodeId: "vision-player-premium-s01e02",
                nextEpisode: nextEpisode,
                sessionID: UUID(),
                initialPlaybackState: playbackState,
                initialPlaybackMessage: playbackState == .failed ? "Trying alternate stream..." : "Playing from Real-Debrid",
                initialPlaybackError: playbackError,
                initialActiveEngine: .avPlayer,
                initialIsShowingSubtitlePicker: isShowingSubtitlePicker,
                initialIsShowingAudioPicker: isShowingAudioPicker,
                initialSubtitleFontSize: 30,
                initialCapabilityWarnings: ["HDR fallback active for this display."],
                initialEnvironmentAssets: [environmentAsset],
                initialSubtitleCandidates: [subtitleCandidate],
                initialSubtitleCatalogMessage: "1 subtitle result",
                initialIsDownloadingSubtitle: isShowingSubtitlePicker && isResolvingNextEpisode,
                initialIsShowingAutoPlayNextPrompt: !isShowingSubtitlePicker && !isShowingAudioPicker,
                initialIsResolvingAutoPlayNextEpisode: isResolvingNextEpisode,
                initialAutoPlayNextCountdownRemaining: 6,
                initialAspectRatioSelection: .twentyOneByNine,
                disablesAutomaticTasks: true
            )
            .environment(appState)
            .environment(seededEngine())
            .environment(CinemaSettings(loadPersisted: false))
            .frame(width: 1_020, height: 660)
        }

        let views: [(String, AnyView)] = [
            ("Player chrome with subtitles and autoplay", AnyView(playerView())),
            ("Player subtitle picker with direct and OpenSubtitles tracks", AnyView(playerView(isShowingSubtitlePicker: true))),
            ("Player audio picker with direct tracks", AnyView(playerView(isShowingAudioPicker: true))),
            ("Player failed state warning", AnyView(playerView(
                playbackState: .failed,
                playbackError: "The selected stream stopped responding.",
                isResolvingNextEpisode: true
            ))),
        ]

        for (name, view) in views {
            let hosted = try hostInVisibleVisionWindow(view)
            hosted.host.view.setNeedsLayout()
            hosted.host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.12))

            #expect(hosted.host.view.bounds.width > 0, "\(name) should lay out")
            #expect(hosted.host.view.bounds.height > 0, "\(name) should lay out")
            #expect(hosted.host.view.subviews.isEmpty == false, "\(name) should create a SwiftUI host subtree")
            retainVisibleVisionWindow(hosted.window)
        }
    }

    private func makeMediaItem(type: MediaType = .movie) -> MediaItem {
        MediaItem(
            id: "vision-detail-fixture-\(type.rawValue)",
            type: type,
            title: type == .movie ? "Dune" : "The Expanse",
            year: 2021,
            posterPath: "/poster.jpg",
            backdropPath: "/backdrop.jpg",
            overview: "A compact overview for construction tests.",
            genres: ["Science Fiction", "Drama", "Adventure"],
            imdbRating: 8.2,
            runtime: 155,
            status: "Released",
            tmdbId: 438631
        )
    }

    private func makeMediaPreview(
        id: String,
        type: MediaType = .movie,
        title: String,
        year: Int?
    ) -> MediaPreview {
        MediaPreview(
            id: id,
            type: type,
            title: title,
            year: year,
            posterPath: nil,
            backdropPath: nil,
            imdbRating: 8.2,
            tmdbId: 438631
        )
    }

    private func makeLibraryMediaItem(
        id: String,
        type: MediaType = .movie,
        title: String,
        year: Int?,
        posterPath: String? = nil,
        backdropPath: String? = nil
    ) -> MediaItem {
        MediaItem(
            id: id,
            type: type,
            title: title,
            year: year,
            posterPath: posterPath,
            backdropPath: backdropPath,
            overview: "Library construction fixture.",
            genres: ["Drama"],
            imdbRating: 8.0,
            runtime: 120,
            status: "Released",
            tmdbId: 100
        )
    }

    private func makeLibraryEntry(
        id: String,
        mediaId: String,
        folderId: String,
        listType: UserLibraryEntry.ListType,
        addedAt: Date
    ) -> UserLibraryEntry {
        UserLibraryEntry(
            id: id,
            mediaId: mediaId,
            folderId: folderId,
            listType: listType,
            addedAt: addedAt
        )
    }

    private func makeLibraryFolder(
        id: String,
        name: String,
        parentId: String? = nil,
        listType: UserLibraryEntry.ListType,
        folderKind: LibraryFolder.FolderKind = .manual,
        isSystem: Bool = false
    ) -> LibraryFolder {
        LibraryFolder(
            id: id,
            name: name,
            parentId: parentId,
            listType: listType,
            folderKind: folderKind,
            isSystem: isSystem
        )
    }

    private func makeWatchHistory(
        id: String,
        mediaId: String,
        title: String,
        watchedAt: Date
    ) -> WatchHistory {
        WatchHistory(
            id: id,
            mediaId: mediaId,
            title: title,
            progress: 1_800,
            duration: 7_200,
            watchedAt: watchedAt,
            isCompleted: false
        )
    }

    private func makeLibraryCSVImportSummary(
        rowsRead: Int,
        rowsImported: Int,
        rowsSkipped: Int,
        watchlist: Int,
        favorites: Int,
        history: Int,
        ratings: Int,
        targetFolderName: String?
    ) -> LibraryCSVImportSummary {
        LibraryCSVImportSummary(
            detectedFormat: .generic,
            rowsRead: rowsRead,
            rowsImported: rowsImported,
            rowsSkipped: rowsSkipped,
            mediaItemsCreated: max(watchlist + favorites + history, 0),
            mediaItemsUpdated: 1,
            watchlistImported: watchlist,
            favoritesImported: favorites,
            historyImported: history,
            ratingsImported: ratings,
            targetFolderID: targetFolderName.map { "folder-\($0.lowercased().replacingOccurrences(of: " ", with: "-"))" },
            targetFolderName: targetFolderName
        )
    }

    private func makeAISettingsLocalModel(
        id: String,
        displayName: String,
        status: LocalModelStatus,
        progress: Double = 0
    ) -> LocalModelDescriptor {
        let now = Date(timeIntervalSince1970: 500)
        return LocalModelDescriptor(
            id: id,
            displayName: displayName,
            huggingFaceRepo: id,
            revision: "main",
            parameterCount: "360M",
            quantization: "float16",
            diskSizeMB: 700,
            minMemoryMB: 800,
            expectedFileCount: 5,
            maxContextTokens: 2_048,
            effectivePromptCap: 2_048,
            effectiveOutputCap: 1_024,
            status: status,
            downloadProgress: status == .downloaded ? 1 : progress,
            downloadedBytes: Int64(progress * 700_000_000),
            totalBytes: 700_000_000,
            lastProgressAt: now,
            checksumSHA256: nil,
            validationState: status == .corrupted ? .corrupt : .pending,
            localPath: status == .downloaded ? "/tmp/\(id)" : nil,
            partialDownloadPath: status == .downloading || status == .paused ? "/tmp/\(id).partial" : nil,
            isDefault: status == .downloaded,
            createdAt: now,
            updatedAt: now
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
    VisionWindowHostCache.retain(window, limit: 0)
}

@MainActor
private func retainVisibleVisionWindow(_ window: UIWindow) {
    tearDownVisionWindow(window)
}

@MainActor
private final class FolderOptionsRefreshProbe {
    private(set) var snapshot: (options: [String], selectedName: String)?

    func record(options: [String], selectedName: String) {
        snapshot = (options, selectedName)
    }
}

@MainActor
private enum VisionWindowHostCache {
    static var retainedWindows: [UIWindow] = []

    static func retain(_ window: UIWindow, limit: Int = 12) {
        retainedWindows.append(window)
        while retainedWindows.count > limit {
            let oldWindow = retainedWindows.removeFirst()
            oldWindow.isUserInteractionEnabled = false
            oldWindow.isHidden = true
            oldWindow.rootViewController = nil
        }
    }
}
#endif
